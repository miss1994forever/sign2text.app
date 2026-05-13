from __future__ import annotations

import json
import os
import pickle
import sys
from contextlib import contextmanager
from pathlib import Path
from threading import Lock
from typing import Dict, List

from .config import Settings
from .keypoints import get_expected_keypoint_count


class OnlineCSLRRuntime:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._lock = Lock()
        self._loaded = False
        self._torch = None
        self._cfg = None
        self._model = None
        self._vocab = None
        self._prediction_slide = None
        self._use_keypoints: List[str] = []
        self._expected_keypoint_count = 0

    @property
    def loaded(self) -> bool:
        return self._loaded

    @property
    def use_keypoints(self) -> List[str]:
        return list(self._use_keypoints)

    @property
    def expected_keypoint_count(self) -> int:
        return self._expected_keypoint_count

    def _bootstrap_imports(self) -> None:
        cslr_root = str(self.settings.cslr_root)
        if cslr_root not in sys.path:
            sys.path.insert(0, cslr_root)

    def _resolve_checkpoint_path(self) -> Path:
        candidates = [
            self.settings.checkpoint_path,
            self.settings.workspace_root / "models/checkpoints/online_slrt/best.ckpt",
            self.settings.workspace_root / "models/checkpoints/online_slrt/cslr_best.ckpt",
        ]
        for candidate in candidates:
            if candidate.is_file():
                return candidate
        raise FileNotFoundError(
            "Checkpoint not found. Checked: " + ", ".join(str(candidate) for candidate in candidates)
        )

    def _load_vocab(self, vocab_path: str) -> List[str]:
        path = Path(vocab_path)
        if not path.exists():
            raise FileNotFoundError(f"Vocabulary file not found: {path}")

        if path.suffix == ".pkl":
            with open(path, "rb") as handle:
                gloss2ids = pickle.load(handle)
            if not isinstance(gloss2ids, dict):
                raise ValueError(f"Pickle vocabulary must contain a token-to-id mapping: {path}")
            return [token for token, _ in sorted(gloss2ids.items(), key=lambda item: item[1])]

        with open(path, "r", encoding="utf-8") as handle:
            vocab = json.load(handle)
        if not isinstance(vocab, list):
            raise ValueError(f"JSON vocabulary must be a token list: {path}")
        return vocab

    @contextmanager
    def _cslr_working_directory(self):
        original_cwd = Path.cwd()
        os.chdir(self.settings.cslr_root)
        try:
            yield
        finally:
            os.chdir(original_cwd)

    def load(self) -> None:
        with self._lock:
            if self._loaded:
                return

            self._bootstrap_imports()

            with self._cslr_working_directory():
                # Torch 1.x tensorboard helper expects distutils.version to be importable.
                import distutils.version  # noqa: F401
                import torch
                from modelling.model import build_model
                from prediction_slide import index2token, pad_tensor, sliding_windows
                from utils.misc import load_config, make_logger, neq_load_customized, set_seed

                self._torch = torch
                self._prediction_slide = {
                    "index2token": index2token,
                    "pad_tensor": pad_tensor,
                    "sliding_windows": sliding_windows,
                }

                cfg = load_config(str(self.settings.config_path))
                resolved_device = self.settings.device
                if resolved_device == "cuda" and not torch.cuda.is_available():
                    resolved_device = "cpu"
                cfg["device"] = torch.device(resolved_device)

                set_seed(seed=cfg["training"].get("random_seed", 42))

                vocab = self._load_vocab(cfg["data"]["vocab_file"])

                cls_num = len(vocab)
                model_dir = Path(cfg["training"]["model_dir"]).resolve()
                model_dir.mkdir(parents=True, exist_ok=True)
                make_logger(model_dir=str(model_dir), log_file=self.settings.service_log_file)

                model = build_model(cfg, cls_num, word_emb_tab=None)
                checkpoint_path = self._resolve_checkpoint_path()

                state_dict = torch.load(str(checkpoint_path), map_location=cfg["device"])
                neq_load_customized(model, state_dict["model_state"], verbose=True)
                model.eval()

            self._cfg = cfg
            self._model = model
            self._vocab = vocab
            self._use_keypoints = list(cfg["data"].get("use_keypoints", []))
            self._expected_keypoint_count = get_expected_keypoint_count(self._use_keypoints)
            self._loaded = True

    def _ensure_loaded(self) -> None:
        if not self._loaded:
            self.load()

    def infer_from_tensors(self, video_tensor, keypoint_tensor, pred_src: str = "ensemble") -> Dict[str, object]:
        self._ensure_loaded()

        torch = self._torch
        cfg = self._cfg
        model = self._model
        vocab = list(self._vocab)
        helpers = self._prediction_slide

        if video_tensor.ndim == 4:
            video_tensor = video_tensor.unsqueeze(0)
        if keypoint_tensor.ndim == 3:
            keypoint_tensor = keypoint_tensor.unsqueeze(0)

        if video_tensor.ndim != 5:
            raise ValueError("video tensor must have shape [1, T, C, H, W] or [T, C, H, W]")
        if keypoint_tensor.ndim != 4:
            raise ValueError("keypoint tensor must have shape [1, T, K, 3] or [T, K, 3]")

        video_tensor = video_tensor.to(cfg["device"])
        keypoint_tensor = keypoint_tensor.to(cfg["device"])

        dataset_name = cfg["data"]["dataset_name"]
        if "<blank>" in vocab:
            blank_id = vocab.index("<blank>")
        else:
            blank_id = len(vocab)
            vocab.append("<blank>")

        win_size = cfg["data"].get("win_size", 16)
        stride = cfg["data"].get("stride", 1)
        split_size = self.settings.split_size
        threshold_candidates = cfg["data"].get("prob_thr", [-1])
        threshold = threshold_candidates[-1] if threshold_candidates else -1

        sliding_windows = helpers["sliding_windows"]
        index2token = helpers["index2token"]
        pad_tensor = helpers["pad_tensor"]

        with torch.no_grad():
            video_windows, keypoint_windows = sliding_windows(
                video_tensor,
                keypoint_tensor,
                win_size=win_size,
                stride=stride,
                save_fea=False,
            )
            video_splits = video_windows.split(split_size, dim=0)
            keypoint_splits = keypoint_windows.split(split_size, dim=0)

            final_decode_ops = []
            all_decode_ops = []
            final_gloss_logits = []
            all_gloss_logits = []

            for video_split, keypoint_split in zip(video_splits, keypoint_splits):
                labels = torch.zeros(video_split.size(0), dtype=torch.long, device=cfg["device"])
                if len(cfg["data"]["input_streams"]) == 2:
                    sgn_videos = [video_split]
                    sgn_keypoints = [keypoint_split]
                elif len(cfg["data"]["input_streams"]) == 4:
                    sgn_videos = [video_split]
                    sgn_videos.append(video_split[:, win_size // 4 : win_size // 4 + win_size // 2, ...].contiguous())
                    sgn_keypoints = [keypoint_split]
                    sgn_keypoints.append(
                        keypoint_split[:, win_size // 4 : win_size // 4 + win_size // 2, ...].contiguous()
                    )
                else:
                    raise ValueError("Unexpected number of input streams in CSLR config")

                forward_output = model(
                    is_train=False,
                    labels=labels,
                    sgn_videos=sgn_videos,
                    sgn_keypoints=sgn_keypoints,
                    epoch=0,
                )

                if pred_src == "ensemble":
                    gloss_logits = forward_output["ensemble_last_gloss_logits"]
                elif pred_src == "fuse":
                    gloss_logits = forward_output["fuse_gloss_logits"]
                else:
                    raise ValueError(f"Unsupported pred_src: {pred_src}")

                gloss_prob = gloss_logits.softmax(dim=-1)
                max_prob = gloss_prob.amax(dim=-1)
                decode_output = model.predict_gloss_from_logits(gloss_logits=gloss_logits, k=10)
                if threshold <= 0.2 or torch.sum(max_prob > threshold).item() > 0:
                    final_decode_ops.append(decode_output[max_prob > threshold])
                    final_gloss_logits.append(gloss_logits[max_prob > threshold])
                all_decode_ops.append(decode_output)
                all_gloss_logits.append(gloss_logits)

            if final_decode_ops:
                final_decode = torch.cat(final_decode_ops, dim=0)
                final_logits = torch.cat(final_gloss_logits, dim=0)
            else:
                final_decode = torch.cat(all_decode_ops, dim=0)
                final_logits = torch.cat(all_gloss_logits, dim=0)

            candidates: List[Dict[str, str]] = []

            naive_index = final_decode[:, 0].detach().cpu().numpy()
            filtered_naive = []
            for token_id in naive_index:
                if not filtered_naive or token_id != filtered_naive[-1]:
                    filtered_naive.append(token_id)
            filtered_naive = [token_id for token_id in filtered_naive if token_id != blank_id]
            naive_text = " ".join(index2token(filtered_naive, vocab, dataset_name))
            candidates.append({"decodeMethod": "naive_greedy", "glossText": naive_text})

            for decode_window_size in [3, 5, 7, 9, 11, 13]:
                index = final_decode[:, 0].detach().cpu().numpy()
                left_pad = index[0]
                right_pad = index[-1]
                index = list(index)
                index = [left_pad] * (decode_window_size // 2) + index + [right_pad] * (decode_window_size // 2)
                padded_logits = pad_tensor(final_logits, decode_window_size // 2, decode_window_size // 2)

                win_index = []
                for start in range(len(index) - decode_window_size + 1):
                    current_window = index[start : start + decode_window_size]
                    logits = padded_logits[start : start + decode_window_size]
                    _ = logits.softmax(dim=-1).mean(dim=0)
                    unique_tokens = {}
                    for token_id in current_window:
                        unique_tokens[token_id] = unique_tokens.get(token_id, 0) + 1
                    majority = [token_id for token_id, count in unique_tokens.items() if count > decode_window_size // 2]
                    win_index.append(majority[0] if majority else blank_id)

                filtered_window = []
                for token_id in win_index:
                    if not filtered_window or token_id != filtered_window[-1]:
                        filtered_window.append(token_id)
                filtered_window = [token_id for token_id in filtered_window if token_id != blank_id]
                gloss_text = " ".join(index2token(filtered_window, vocab, dataset_name))
                candidates.append({"decodeMethod": f"window_greedy_{decode_window_size}", "glossText": gloss_text})

            best_method = "window_greedy_7"
            best_text = next(
                (candidate["glossText"] for candidate in candidates if candidate["decodeMethod"] == best_method),
                naive_text,
            )

            return {
                "text": best_text,
                "glossText": best_text,
                "translationText": None,
                "decodeMethod": best_method,
                "candidates": candidates,
                "windowSize": win_size,
                "stride": stride,
                "predSrc": pred_src,
            }

    def infer_from_tensor_paths(self, video_tensor_path: str, keypoint_tensor_path: str, pred_src: str = "ensemble") -> Dict[str, object]:
        self._ensure_loaded()
        torch = self._torch
        video_tensor = torch.load(video_tensor_path, map_location=self._cfg["device"])
        keypoint_tensor = torch.load(keypoint_tensor_path, map_location=self._cfg["device"])
        return self.infer_from_tensors(video_tensor=video_tensor, keypoint_tensor=keypoint_tensor, pred_src=pred_src)

    def infer_live_tensors(self, video_tensor, keypoint_tensor, pred_src: str = "ensemble") -> Dict[str, object]:
        return self.infer_from_tensors(video_tensor=video_tensor, keypoint_tensor=keypoint_tensor, pred_src=pred_src)