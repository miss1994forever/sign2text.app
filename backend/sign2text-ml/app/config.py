from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    workspace_root: Path = Path(os.getenv("WORKSPACE_ROOT", "/root/autodl-tmp"))
    slrt_root: Path = Path(os.getenv("SLRT_ROOT", "/root/autodl-tmp/SLRT"))
    cslr_root: Path = Path(os.getenv("SLRT_CSLR_ROOT", "/root/autodl-tmp/SLRT/Online/CSLR"))
    config_path: Path = Path(
        os.getenv(
            "SLRT_CSLR_CONFIG",
            "/root/autodl-tmp/SLRT/Online/CSLR/configs/slide_phoenix-2014t.yaml",
        )
    )
    checkpoint_path: Path = Path(
        os.getenv(
            "SLRT_CSLR_CHECKPOINT",
            "/root/autodl-tmp/SLRT/Online/CSLR/results/phoenix-2014t_ISLR/ckpts/best.ckpt",
        )
    )
    device: str = os.getenv("SLRT_DEVICE", "cuda")
    pred_src: str = os.getenv("SLRT_PRED_SRC", "ensemble")
    split_size: int = int(os.getenv("SLRT_SPLIT_SIZE", "8"))
    max_buffer_frames: int = int(os.getenv("SLRT_MAX_BUFFER_FRAMES", "96"))
    session_timeout_seconds: int = int(os.getenv("SLRT_SESSION_TIMEOUT_SECONDS", "1800"))
    eager_load: bool = os.getenv("SLRT_EAGER_LOAD", "0") == "1"
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