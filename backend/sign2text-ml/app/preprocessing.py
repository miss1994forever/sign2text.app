from __future__ import annotations

import base64
import io
from dataclasses import dataclass
from typing import List

import numpy as np
import torch
from PIL import Image

from .keypoints import FULL_HRNET_KEYPOINT_COUNT, select_hrnet_keypoints
from .session import SessionState


@dataclass
class PreprocessedSessionBatch:
    video_tensor: torch.Tensor
    keypoint_tensor: torch.Tensor
    frame_indices: List[int]
    dropped_frame_indices: List[int]


def _decode_base64_image(image_jpeg_base64: str) -> np.ndarray:
    payload = image_jpeg_base64.split(",", 1)[-1]
    image_bytes = base64.b64decode(payload)
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    return np.asarray(image, dtype=np.float32) / 255.0


def _normalize_keypoints(
    keypoints: List[List[float]],
    use_keypoints: List[str] | None = None,
    expected_keypoint_count: int | None = None,
) -> np.ndarray:
    array = np.asarray(keypoints, dtype=np.float32)
    if array.ndim != 2:
        raise ValueError("keypoints payload must be a 2D list with shape [K, 2] or [K, 3]")
    if array.shape[1] == 2:
        confidence = np.ones((array.shape[0], 1), dtype=np.float32)
        array = np.concatenate([array, confidence], axis=1)
    elif array.shape[1] != 3:
        raise ValueError("keypoints payload must contain 2 or 3 values per point")

    if expected_keypoint_count is not None:
        if array.shape[0] == FULL_HRNET_KEYPOINT_COUNT and use_keypoints:
            array = select_hrnet_keypoints(array, use_keypoints)
        elif array.shape[0] != expected_keypoint_count:
            raise ValueError(
                f"Expected {expected_keypoint_count} keypoints for the configured CSLR model, got {array.shape[0]}"
            )
    return array


def build_tensors_from_session(
    session: SessionState,
    use_keypoints: List[str] | None = None,
    expected_keypoint_count: int | None = None,
) -> PreprocessedSessionBatch:
    usable_frames = []
    dropped_frame_indices: List[int] = []

    for frame in session.frames:
        keypoint_payload = session.keypoints.get(frame.frame_index)
        if keypoint_payload is None:
            dropped_frame_indices.append(frame.frame_index)
            continue
        usable_frames.append((frame, keypoint_payload))

    if not usable_frames:
        raise ValueError("No aligned frame/keypoint pairs are available in the session buffer")

    reference_keypoint_count = None
    video_frames = []
    keypoint_frames = []
    frame_indices = []
    reference_height = None
    reference_width = None

    for frame_payload, keypoint_payload in usable_frames:
        frame_array = _decode_base64_image(frame_payload.image_jpeg_base64)
        if frame_array.ndim != 3 or frame_array.shape[2] != 3:
            raise ValueError("Decoded frame must have shape [H, W, 3]")

        if reference_height is None:
            reference_height, reference_width = frame_array.shape[:2]
        elif frame_array.shape[:2] != (reference_height, reference_width):
            image = Image.fromarray((frame_array * 255.0).astype(np.uint8))
            image = image.resize((reference_width, reference_height))
            frame_array = np.asarray(image, dtype=np.float32) / 255.0

        keypoint_array = _normalize_keypoints(
            keypoint_payload.keypoints,
            use_keypoints=use_keypoints,
            expected_keypoint_count=expected_keypoint_count,
        )
        if reference_keypoint_count is None:
            reference_keypoint_count = keypoint_array.shape[0]
        elif keypoint_array.shape[0] != reference_keypoint_count:
            raise ValueError(
                f"Inconsistent keypoint count across buffered frames: expected {reference_keypoint_count}, got {keypoint_array.shape[0]}"
            )

        video_frames.append(torch.from_numpy(frame_array).permute(2, 0, 1).contiguous())
        keypoint_frames.append(torch.from_numpy(keypoint_array))
        frame_indices.append(frame_payload.frame_index)

    video_tensor = torch.stack(video_frames, dim=0).unsqueeze(0)
    keypoint_tensor = torch.stack(keypoint_frames, dim=0).unsqueeze(0)

    return PreprocessedSessionBatch(
        video_tensor=video_tensor,
        keypoint_tensor=keypoint_tensor,
        frame_indices=frame_indices,
        dropped_frame_indices=dropped_frame_indices,
    )