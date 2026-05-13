from __future__ import annotations

import sys
import types
from pathlib import Path
from typing import Any, Dict, Optional


class WaitKSLTRuntimeError(RuntimeError):
    pass


class WaitKSLTRuntime:
    def __init__(self, settings) -> None:
        self.settings = settings
        self._torch = None
        self._load_config = None
        self._make_logger = None
        self._model = None
        self._cfg: Optional[Dict[str, Any]] = None
        self._generate_cfg: Dict[str, Any] = {}
        self._checkpoint_path: Optional[Path] = None

    @property
    def loaded(self) -> bool:
        return self._model is not None

    def load(self) -> None:
        if self.loaded:
            return

        if not self.settings.enable_slt:
            raise WaitKSLTRuntimeError("wait-k SLT is disabled")

        self._bootstrap_imports()

        slt_config_path = self.settings.slt_config_path
        if not slt_config_path.exists():
            raise WaitKSLTRuntimeError(f"SLT config not found: {slt_config_path}")

        cfg = self._load_config(str(slt_config_path))
        cfg["device"] = self._torch.device(self.settings.device)
        translation_cfg = cfg["model"]["TranslationNetwork"]
        self._resolve_translation_paths(translation_cfg)

        checkpoint_path = self._resolve_checkpoint_path(cfg)
        if checkpoint_path is None:
            raise WaitKSLTRuntimeError(
                "no wait-k checkpoint found; set SLRT_SLT_CHECKPOINT or place a checkpoint under the SLT results directory"
            )

        model = self._TranslationNetwork(input_type="gloss", cfg=translation_cfg, task=cfg["task"])
        model.load_from_pretrained_ckpt(str(checkpoint_path))
        model = model.to(cfg["device"])
        model.eval()

        self._cfg = cfg
        self._generate_cfg = dict(cfg.get("testing", {}).get("cfg", {}).get("translation", {}))
        self._model = model
        self._checkpoint_path = checkpoint_path

    def translate_gloss_text(self, gloss_text: str) -> Dict[str, Optional[str]]:
        normalized = " ".join(gloss_text.split())
        if not normalized:
            raise WaitKSLTRuntimeError("cannot translate an empty gloss string")

        if not self.loaded:
            self.load()

        assert self._model is not None
        assert self._torch is not None

        tokenized = self._model.gloss_tokenizer([normalized])
        input_ids = tokenized["input_ids"].to(self._cfg["device"])
        attention_mask = tokenized["attention_mask"].to(self._cfg["device"])
        inputs_embeds = self._model.prepare_gloss_inputs(input_ids)

        with self._torch.no_grad():
            output = self._model.generate(
                inputs_embeds=inputs_embeds,
                attention_mask=attention_mask,
                **self._generate_cfg,
            )

        decoded_sequences = output.get("decoded_sequences", [])
        translation_text = decoded_sequences[0].strip() if decoded_sequences else ""
        wait_k = self._cfg["model"]["TranslationNetwork"].get("overwrite_cfg", {}).get("wait_k")
        decode_method = f"wait_k_{wait_k}" if wait_k is not None else "wait_k"
        return {
            "glossText": normalized,
            "translationText": translation_text or None,
            "decodeMethod": decode_method,
        }

    def _bootstrap_imports(self) -> None:
        slt_root = str(self.settings.slt_root)
        if slt_root not in sys.path:
            sys.path.insert(0, slt_root)

        # CSLR and SLT reuse top-level package names like `modelling` and `utils`.
        # Clear previously imported CSLR modules so SLT resolves its own package tree.
        for module_name in list(sys.modules):
            if module_name == "modelling" or module_name.startswith("modelling."):
                sys.modules.pop(module_name, None)
            if module_name == "utils" or module_name.startswith("utils."):
                sys.modules.pop(module_name, None)

        # The vendored transformers fork ships a dependency checker that cannot parse
        # compound version specs like `tokenizers>=0.10.1,<0.11` in this environment.
        # Stub it out here so we can import the runtime without patching the upstream tree.
        dependency_check_name = "transformers_cust.dependency_versions_check"
        if dependency_check_name not in sys.modules:
            sys.modules[dependency_check_name] = types.ModuleType(dependency_check_name)

        try:
            import distutils.version  # noqa: F401
            from utils.misc import load_config, make_logger  # type: ignore
            from modelling.translation import TranslationNetwork  # type: ignore
            import torch
        except Exception as exc:
            raise WaitKSLTRuntimeError(f"failed to import Online SLT modules: {exc}") from exc

        backend_root = Path(__file__).resolve().parents[1]
        make_logger(str(backend_root), log_file="wait_k_slt.log")

        self._load_config = load_config
        self._make_logger = make_logger
        self._TranslationNetwork = TranslationNetwork
        self._torch = torch

    def _resolve_translation_paths(self, translation_cfg: Dict[str, Any]) -> None:
        translation_cfg["pretrained_model_name_or_path"] = self._resolve_path_string(
            translation_cfg.get("pretrained_model_name_or_path")
        )

        text_tokenizer_cfg = translation_cfg.get("TextTokenizer", {})
        text_tokenizer_cfg["pretrained_model_name_or_path"] = self._resolve_path_string(
            text_tokenizer_cfg.get("pretrained_model_name_or_path")
        )
        text_tokenizer_cfg["pruneids_file"] = self._resolve_path_string(text_tokenizer_cfg.get("pruneids_file"))

        gloss_tokenizer_cfg = translation_cfg.get("GlossTokenizer", {})
        gloss_tokenizer_cfg["gloss2id_file"] = self._resolve_path_string(gloss_tokenizer_cfg.get("gloss2id_file"))

        gloss_embedding_cfg = translation_cfg.get("GlossEmbedding", {})
        gloss_embedding_cfg["gloss2embed_file"] = self._resolve_path_string(gloss_embedding_cfg.get("gloss2embed_file"))

    def _resolve_path_string(self, value: Optional[str]) -> Optional[str]:
        if not value:
            return value
        path = Path(value)
        if path.is_absolute():
            return str(path)
        return str((self.settings.slt_root / path).resolve())

    def _resolve_checkpoint_path(self, cfg: Dict[str, Any]) -> Optional[Path]:
        candidates = []
        if self.settings.slt_checkpoint_path:
            candidates.append(Path(self.settings.slt_checkpoint_path))

        model_dir = Path(cfg["training"]["model_dir"])
        if not model_dir.is_absolute():
            model_dir = (self.settings.slt_root / model_dir).resolve()
        candidates.extend(
            [
                model_dir / "ckpts" / "best.ckpt",
                model_dir / "ckpts" / "phoenix_best.ckpt",
                model_dir / "ckpts" / "last.ckpt",
            ]
        )

        for candidate in candidates:
            if candidate.exists():
                return candidate
        return None