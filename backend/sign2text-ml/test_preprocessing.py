import base64
import io
import unittest

import numpy as np
from PIL import Image

from app.preprocessing import build_tensors_from_session
from app.session import FramePayload, KeypointPayload, SessionState


def jpeg_base64(width: int, height: int) -> str:
    image = Image.fromarray(np.full((height, width, 3), 127, dtype=np.uint8))
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG")
    return base64.b64encode(buffer.getvalue()).decode()


def make_session(width: int, height: int, keypoint: list[float]) -> SessionState:
    session = SessionState(session_id="test", metadata={}, max_buffer_frames=4)
    session.add_frame(
        FramePayload(
            frame_index=0,
            timestamp_ms=0,
            image_jpeg_base64=jpeg_base64(width, height),
            image_width=width,
            image_height=height,
        )
    )
    session.add_keypoints(KeypointPayload(frame_index=0, timestamp_ms=0, keypoints=[keypoint]))
    return session


class LivePreprocessingTest(unittest.TestCase):
    def test_csl_dataset_frame_keeps_raw_keypoint_coordinates(self):
        session = make_session(512, 512, [256.0, 128.0, 0.9])
        batch = build_tensors_from_session(
            session,
            expected_keypoint_count=1,
            rgb_target_size=(320, 320),
            keypoint_target_size=(512, 512),
        )
        self.assertEqual(tuple(batch.video_tensor.shape), (1, 1, 3, 320, 320))
        np.testing.assert_allclose(batch.keypoint_tensor.numpy()[0, 0, 0], [256.0, 128.0, 0.9])

    def test_ios_frame_scales_csl_keypoints_to_training_coordinates(self):
        session = make_session(240, 320, [120.0, 160.0, 0.8])
        batch = build_tensors_from_session(
            session,
            expected_keypoint_count=1,
            rgb_target_size=(320, 320),
            keypoint_target_size=(512, 512),
        )
        self.assertEqual(tuple(batch.video_tensor.shape), (1, 1, 3, 320, 320))
        np.testing.assert_allclose(batch.keypoint_tensor.numpy()[0, 0, 0], [256.0, 256.0, 0.8])

    def test_ios_frame_scales_phoenix_rgb_and_keypoints(self):
        session = make_session(320, 240, [160.0, 120.0, 0.7])
        batch = build_tensors_from_session(
            session,
            expected_keypoint_count=1,
            rgb_target_size=(210, 260),
            keypoint_target_size=(210, 260),
        )
        self.assertEqual(tuple(batch.video_tensor.shape), (1, 1, 3, 260, 210))
        np.testing.assert_allclose(batch.keypoint_tensor.numpy()[0, 0, 0], [105.0, 130.0, 0.7])


if __name__ == "__main__":
    unittest.main()
