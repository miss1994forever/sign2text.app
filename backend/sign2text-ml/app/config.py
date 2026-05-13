from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[4]


def _workspace_root() -> Path:
    return Path(os.getenv("WORKSPACE_ROOT", str(_repo_root())))


def _slrt_root() -> Path:
    return Path(os.getenv("SLRT_ROOT", str(_workspace_root() / "SLRT")))


def _cslr_root() -> Path:
    return Path(os.getenv("SLRT_CSLR_ROOT", str(_slrt_root() / "Online/CSLR")))


def _slt_root() -> Path:
    return Path(os.getenv("SLRT_SLT_ROOT", str(_slrt_root() / "Online/SLT")))


def _default_dataset_preset() -> str:
    return os.getenv("SLRT_DATASET_PRESET", "csl-daily").strip().lower()


def _default_cslr_config() -> Path:
    configured = os.getenv("SLRT_CSLR_CONFIG")
    if configured:
        return Path(configured)

    if _default_dataset_preset() == "csl-daily":
        return _workspace_root() / "sign2text.app/backend/sign2text-ml/configs/slide_csl-daily_runtime.yaml"

    return _cslr_root() / "configs/slide_phoenix-2014t.yaml"


def _default_cslr_checkpoint() -> Path:
    configured = os.getenv("SLRT_CSLR_CHECKPOINT")
    if configured:
        return Path(configured)

    if _default_dataset_preset() == "csl-daily":
        return _workspace_root() / "models/checkpoints/online_slrt/cslr_best.ckpt"

    return _workspace_root() / "models/checkpoints/online_slrt/best.ckpt"


def _default_slt_config() -> Path:
    configured = os.getenv("SLRT_SLT_CONFIG")
    if configured:
        return Path(configured)

    if _default_dataset_preset() == "csl-daily":
        return _slt_root() / "configs/g2t_wait2_csl.yaml"

    return _slt_root() / "configs/g2t_wait2.yaml"


def _default_enable_slt() -> bool:
    configured = os.getenv("SIGN2TEXT_ENABLE_SLT")
    if configured:
        return configured == "1"
    return _default_dataset_preset() != "csl-daily"


@dataclass(frozen=True)
class Settings:
    workspace_root: Path = _workspace_root()
    slrt_root: Path = _slrt_root()
    cslr_root: Path = _cslr_root()
    slt_root: Path = _slt_root()
    dataset_preset: str = _default_dataset_preset()
    config_path: Path = _default_cslr_config()
    checkpoint_path: Path = _default_cslr_checkpoint()
    slt_config_path: Path = _default_slt_config()
    slt_checkpoint_path: str = os.getenv("SLRT_SLT_CHECKPOINT", "")
    device: str = os.getenv("SLRT_DEVICE", "cuda")
    pred_src: str = os.getenv("SLRT_PRED_SRC", "ensemble")
    split_size: int = int(os.getenv("SLRT_SPLIT_SIZE", "8"))
    max_buffer_frames: int = int(os.getenv("SLRT_MAX_BUFFER_FRAMES", "96"))
    session_timeout_seconds: int = int(os.getenv("SLRT_SESSION_TIMEOUT_SECONDS", "1800"))
    eager_load: bool = os.getenv("SLRT_EAGER_LOAD", "0") == "1"
    enable_slt: bool = _default_enable_slt()
    slt_eager_load: bool = os.getenv("SLRT_SLT_EAGER_LOAD", "0") == "1"
    service_log_file: str = os.getenv("SLRT_SERVICE_LOG_FILE", "sign2text_service.log")
    pose_det_config: str = os.getenv("SLRT_POSE_DET_CONFIG", "")
    pose_det_ckpt: str = os.getenv(
        "SLRT_POSE_DET_CKPT",
        "https://download.openmmlab.com/mmdetection/v2.0/faster_rcnn/"
        "faster_rcnn_r50_fpn_1x_coco-person/"
        "faster_rcnn_r50_fpn_1x_coco-person_20201216_175929-d022e227.pth",
    )
    pose_model_config: str = os.getenv("SLRT_POSE_MODEL_CONFIG", "")
    pose_model_ckpt: str = os.getenv(
        "SLRT_POSE_MODEL_CKPT",
        "https://download.openmmlab.com/mmpose/top_down/hrnet/"
        "hrnet_w48_coco_wholebody_384x288_dark-f5726563_20200918.pth",
    )
    pose_det_score_thr: float = float(os.getenv("SLRT_POSE_DET_SCORE_THR", "0.5"))
    pose_det_area_thr: float = float(os.getenv("SLRT_POSE_DET_AREA_THR", "1600"))
    pose_eager_load: bool = os.getenv("SLRT_POSE_EAGER_LOAD", "0") == "1"


settings = Settings()