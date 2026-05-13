from __future__ import annotations

from typing import Iterable, List

import numpy as np


FULL_HRNET_KEYPOINT_COUNT = 133

HRNET_PART_TO_INDEX = {
    "pose": list(range(11)),
    "hand": list(range(91, 133)),
    "mouth": list(range(71, 91)),
    "face_others": list(range(23, 71)),
}

for part_name in ["mouth", "face_others", "hand"]:
    HRNET_PART_TO_INDEX[f"{part_name}_half"] = HRNET_PART_TO_INDEX[part_name][::2]
    HRNET_PART_TO_INDEX[f"{part_name}_1_3"] = HRNET_PART_TO_INDEX[part_name][::3]


def get_selected_indices(use_keypoints: Iterable[str]) -> List[int]:
    indices: List[int] = []
    for part_name in sorted(use_keypoints):
        if part_name not in HRNET_PART_TO_INDEX:
            raise ValueError(f"Unsupported keypoint group: {part_name}")
        indices.extend(HRNET_PART_TO_INDEX[part_name])
    return indices


def get_expected_keypoint_count(use_keypoints: Iterable[str]) -> int:
    return len(get_selected_indices(use_keypoints))


def select_hrnet_keypoints(keypoints: np.ndarray, use_keypoints: Iterable[str]) -> np.ndarray:
    indices = get_selected_indices(use_keypoints)
    if keypoints.ndim == 2:
        if keypoints.shape[0] != FULL_HRNET_KEYPOINT_COUNT:
            raise ValueError(
                f"Expected full HRNet whole-body keypoints with {FULL_HRNET_KEYPOINT_COUNT} points, got {keypoints.shape[0]}"
            )
        return keypoints[indices]

    if keypoints.ndim == 3:
        if keypoints.shape[1] != FULL_HRNET_KEYPOINT_COUNT:
            raise ValueError(
                f"Expected full HRNet whole-body keypoints with {FULL_HRNET_KEYPOINT_COUNT} points, got {keypoints.shape[1]}"
            )
        return keypoints[:, indices]

    raise ValueError("Keypoints array must have shape [K, C] or [T, K, C]")