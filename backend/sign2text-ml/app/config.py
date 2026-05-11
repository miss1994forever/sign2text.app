from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


VALID_DATASET_PRESETS = ("csl-daily", "phoenix")


def normalize_dataset_preset(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in VALID_DATASET_PRESETS:
        raise ValueError(
            f"Unsupported dataset preset: {value}. Expected one of {', '.join(VALID_DATASET_PRESETS)}"
        )
    return normalized


def _default_dataset_preset() -> str:
    return normalize_dataset_preset(os.getenv("SLRT_DATASET_PRESET", "csl-daily"))


def _default_cslr_config(dataset_preset: str | None = None) -> Path:
    configured = os.getenv("SLRT_CSLR_CONFIG")
    if configured:
        return Path(configured)

    if (dataset_preset or _default_dataset_preset()) == "csl-daily":
        return Path("/root/autodl-tmp/sign2text.app/backend/sign2text-ml/configs/slide_csl-daily_runtime.yaml")

    return Path("/root/autodl-tmp/SLRT/Online/CSLR/configs/slide_phoenix-2014t.yaml")


def _default_cslr_checkpoint(dataset_preset: str | None = None) -> Path:
    configured = os.getenv("SLRT_CSLR_CHECKPOINT")
    if configured:
        return Path(configured)

    if (dataset_preset or _default_dataset_preset()) == "csl-daily":
        return Path("/root/autodl-tmp/models/checkpoints/online_slrt/cslr_best.ckpt")

    return Path("/root/autodl-tmp/models/checkpoints/online_slrt/best.ckpt")


def _default_slt_config(dataset_preset: str | None = None) -> Path:
    configured = os.getenv("SLRT_SLT_CONFIG")
    if configured:
        return Path(configured)

    if (dataset_preset or _default_dataset_preset()) == "csl-daily":
        return Path("/root/autodl-tmp/SLRT/Online/SLT/configs/g2t_wait2_csl.yaml")

    return Path("/root/autodl-tmp/SLRT/Online/SLT/configs/g2t_wait2.yaml")


def _default_enable_slt(dataset_preset: str | None = None) -> bool:
    configured = os.getenv("SIGN2TEXT_ENABLE_SLT")
    if configured:
        return configured == "1"
    return (dataset_preset or _default_dataset_preset()) != "csl-daily"


@dataclass(frozen=True)
class Settings:
    workspace_root: Path = field(default_factory=lambda: Path(os.getenv("WORKSPACE_ROOT", "/root/autodl-tmp")))
    slrt_root: Path = field(default_factory=lambda: Path(os.getenv("SLRT_ROOT", "/root/autodl-tmp/SLRT")))
    cslr_root: Path = field(default_factory=lambda: Path(os.getenv("SLRT_CSLR_ROOT", "/root/autodl-tmp/SLRT/Online/CSLR")))
    slt_root: Path = field(default_factory=lambda: Path(os.getenv("SLRT_SLT_ROOT", "/root/autodl-tmp/SLRT/Online/SLT")))
    dataset_preset: str = field(default_factory=_default_dataset_preset)
    config_path: Path = field(default_factory=_default_cslr_config)
    checkpoint_path: Path = field(default_factory=_default_cslr_checkpoint)
    slt_config_path: Path = field(default_factory=_default_slt_config)
    slt_checkpoint_path: str = field(default_factory=lambda: os.getenv("SLRT_SLT_CHECKPOINT", ""))
    device: str = field(default_factory=lambda: os.getenv("SLRT_DEVICE", "cuda"))
    pred_src: str = field(default_factory=lambda: os.getenv("SLRT_PRED_SRC", "ensemble"))
    split_size: int = field(default_factory=lambda: int(os.getenv("SLRT_SPLIT_SIZE", "8")))
    max_buffer_frames: int = field(default_factory=lambda: int(os.getenv("SLRT_MAX_BUFFER_FRAMES", "96")))
    session_timeout_seconds: int = field(default_factory=lambda: int(os.getenv("SLRT_SESSION_TIMEOUT_SECONDS", "1800")))
    eager_load: bool = field(default_factory=lambda: os.getenv("SLRT_EAGER_LOAD", "0") == "1")
    enable_slt: bool = field(default_factory=_default_enable_slt)
    slt_eager_load: bool = field(default_factory=lambda: os.getenv("SLRT_SLT_EAGER_LOAD", "0") == "1")
    service_log_file: str = field(default_factory=lambda: os.getenv("SLRT_SERVICE_LOG_FILE", "sign2text_service.log"))
    pose_det_config: str = field(default_factory=lambda: os.getenv("SLRT_POSE_DET_CONFIG", ""))
    pose_det_ckpt: str = field(
        default_factory=lambda: os.getenv(
            "SLRT_POSE_DET_CKPT",
            "https://download.openmmlab.com/mmdetection/v2.0/faster_rcnn/"
            "faster_rcnn_r50_fpn_1x_coco-person/"
            "faster_rcnn_r50_fpn_1x_coco-person_20201216_175929-d022e227.pth",
        )
    )
    pose_model_config: str = field(default_factory=lambda: os.getenv("SLRT_POSE_MODEL_CONFIG", ""))
    pose_model_ckpt: str = field(
        default_factory=lambda: os.getenv(
            "SLRT_POSE_MODEL_CKPT",
            "https://download.openmmlab.com/mmpose/top_down/hrnet/"
            "hrnet_w48_coco_wholebody_384x288_dark-f5726563_20200918.pth",
        )
    )
    pose_det_score_thr: float = field(default_factory=lambda: float(os.getenv("SLRT_POSE_DET_SCORE_THR", "0.5")))
    pose_det_area_thr: float = field(default_factory=lambda: float(os.getenv("SLRT_POSE_DET_AREA_THR", "1600")))
    pose_eager_load: bool = field(default_factory=lambda: os.getenv("SLRT_POSE_EAGER_LOAD", "0") == "1")


def build_settings(dataset_preset: str | None = None, enable_slt: bool | None = None) -> Settings:
    resolved_dataset = normalize_dataset_preset(dataset_preset) if dataset_preset is not None else _default_dataset_preset()
    resolved_enable_slt = _default_enable_slt(resolved_dataset) if enable_slt is None else enable_slt

    return Settings(
        dataset_preset=resolved_dataset,
        config_path=_default_cslr_config(resolved_dataset),
        checkpoint_path=_default_cslr_checkpoint(resolved_dataset),
        slt_config_path=_default_slt_config(resolved_dataset),
        enable_slt=resolved_enable_slt,
    )


settings = build_settings()