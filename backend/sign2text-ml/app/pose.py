from __future__ import annotations

import base64
import io
from dataclasses import dataclass
from pathlib import Path
from threading import Lock
from typing import Dict, List

import numpy as np
from PIL import Image

from .config import Settings
from .keypoints import FULL_HRNET_KEYPOINT_COUNT
from .session import FramePayload, KeypointPayload, SessionState


class PoseDependencyError(RuntimeError):
    pass


@dataclass
class PoseExtractionSummary:
    extracted_frame_indices: List[int]
    zero_filled_frame_indices: List[int]


def _decode_base64_image_uint8(image_jpeg_base64: str) -> np.ndarray:
    payload = image_jpeg_base64.split(",", 1)[-1]
    image_bytes = base64.b64decode(payload)
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    return np.asarray(image, dtype=np.uint8)


def _resolve_openmmlab_config(module, relative_path: str) -> str:
    package_dir = Path(module.__path__[0])
    relative = Path(relative_path)
    candidates = [
        package_dir / ".mim" / relative,
        package_dir.parent / ".mim" / relative,
        package_dir / relative,
        package_dir.parent / relative,
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return str(candidates[0])


class WholeBodyPoseExtractor:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._lock = Lock()
        self._loaded = False
        self._detector = None
        self._pose_model = None
        self._inference_detector = None
        self._inference_top_down_pose_model = None

    @property
    def loaded(self) -> bool:
        return self._loaded

    def load(self) -> None:
        with self._lock:
            if self._loaded:
                return

            try:
                import torch
                import mmdet
                import mmpose
                from mmdet.apis import inference_detector, init_detector
                from mmpose.apis import inference_top_down_pose_model, init_pose_model
            except (ImportError, ModuleNotFoundError) as exc:
                raise PoseDependencyError(
                    "Server-side pose extraction requires mmdet and mmpose in the slrt_legacy environment"
                ) from exc

            resolved_device = self._settings.device
            if resolved_device == "cuda" and not torch.cuda.is_available():
                resolved_device = "cpu"

            det_config = self._settings.pose_det_config or (
                _resolve_openmmlab_config(
                    mmdet,
                    "configs/faster_rcnn/faster_rcnn_r50_caffe_fpn_mstrain_1x_coco-person.py",
                )
            )
            pose_config = self._settings.pose_model_config or (
                _resolve_openmmlab_config(
                    mmpose,
                    "configs/wholebody/2d_kpt_sview_rgb_img/topdown_heatmap/"
                    "coco-wholebody/hrnet_w48_coco_wholebody_384x288_dark_plus.py",
                )
            )

            self._detector = init_detector(det_config, self._settings.pose_det_ckpt, device=resolved_device)
            self._pose_model = init_pose_model(pose_config, self._settings.pose_model_ckpt, device=resolved_device)
            self._inference_detector = inference_detector
            self._inference_top_down_pose_model = inference_top_down_pose_model
            self._loaded = True

    def extract_to_session(self, session: SessionState) -> PoseExtractionSummary:
        missing_frames = [frame for frame in session.frames if frame.frame_index not in session.keypoints]
        if not missing_frames:
            return PoseExtractionSummary(extracted_frame_indices=[], zero_filled_frame_indices=[])

        self.load()

        extracted_frame_indices: List[int] = []
        zero_filled_frame_indices: List[int] = []

        for frame in missing_frames:
            keypoints = self._extract_frame_keypoints(frame)
            if float(np.max(keypoints[:, 2])) <= 0.0:
                zero_filled_frame_indices.append(frame.frame_index)
            extracted_frame_indices.append(frame.frame_index)
            session.add_keypoints(
                KeypointPayload(
                    frame_index=frame.frame_index,
                    timestamp_ms=frame.timestamp_ms,
                    keypoints=keypoints.tolist(),
                )
            )

        return PoseExtractionSummary(
            extracted_frame_indices=extracted_frame_indices,
            zero_filled_frame_indices=zero_filled_frame_indices,
        )

    def _extract_frame_keypoints(self, frame: FramePayload) -> np.ndarray:
        image = _decode_base64_image_uint8(frame.image_jpeg_base64)
        det_results = self._inference_detector(self._detector, image)
        person_boxes = det_results[0]

        if len(person_boxes) > 0:
            person_boxes = person_boxes[person_boxes[:, 4] >= self._settings.pose_det_score_thr]
            if len(person_boxes) > 0:
                areas = (person_boxes[:, 2] - person_boxes[:, 0]) * (person_boxes[:, 3] - person_boxes[:, 1])
                person_boxes = person_boxes[areas >= self._settings.pose_det_area_thr]

        if len(person_boxes) == 0:
            person_boxes = np.asarray([[0, 0, image.shape[1] - 1, image.shape[0] - 1, 1.0]], dtype=np.float32)

        detections = [dict(bbox=bbox) for bbox in person_boxes]
        pose_results = self._inference_top_down_pose_model(self._pose_model, image, detections, format="xyxy")[0]
        if not pose_results:
            return np.zeros((FULL_HRNET_KEYPOINT_COUNT, 3), dtype=np.float32)

        best_pose = max(pose_results, key=lambda item: float(item.get("bbox", [0, 0, 0, 0, 0])[-1]))
        keypoints = np.asarray(best_pose["keypoints"], dtype=np.float32)
        if keypoints.shape != (FULL_HRNET_KEYPOINT_COUNT, 3):
            raise ValueError(
                f"Pose extractor returned unexpected keypoint shape {keypoints.shape}, expected ({FULL_HRNET_KEYPOINT_COUNT}, 3)"
            )
        return keypoints