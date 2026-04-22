from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from threading import Lock
from typing import Deque, Dict, List, Optional
from uuid import uuid4


def utc_now_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


@dataclass
class FramePayload:
    frame_index: int
    timestamp_ms: int
    image_jpeg_base64: str
    image_width: int
    image_height: int


@dataclass
class KeypointPayload:
    frame_index: int
    timestamp_ms: int
    keypoints: List[List[float]]


@dataclass
class SessionState:
    session_id: str
    metadata: Dict[str, str]
    max_buffer_frames: int
    created_at: str = field(default_factory=utc_now_iso)
    updated_at: str = field(default_factory=utc_now_iso)
    frames: Deque[FramePayload] = field(init=False)
    keypoints: Dict[int, KeypointPayload] = field(default_factory=dict)
    latest_text: Optional[str] = None
    latest_gloss_text: Optional[str] = None
    latest_translation_text: Optional[str] = None
    latest_decode_method: Optional[str] = None
    latest_candidates: List[Dict[str, str]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.frames = deque(maxlen=self.max_buffer_frames)

    def touch(self) -> None:
        self.updated_at = utc_now_iso()

    def add_frame(self, payload: FramePayload) -> None:
        self.frames.append(payload)
        self.touch()

    def add_keypoints(self, payload: KeypointPayload) -> None:
        self.keypoints[payload.frame_index] = payload
        self.touch()

    def latest_skeleton_frame(self) -> Optional[tuple[FramePayload, KeypointPayload]]:
        for frame in reversed(self.frames):
            keypoint_payload = self.keypoints.get(frame.frame_index)
            if keypoint_payload is not None:
                return frame, keypoint_payload
        return None

    @property
    def frame_count(self) -> int:
        return len(self.frames)

    @property
    def keypoint_count(self) -> int:
        return len(self.keypoints)

    def update_result(
        self,
        gloss_text: str,
        decode_method: str,
        candidates: List[Dict[str, str]],
        translation_text: Optional[str] = None,
    ) -> None:
        self.latest_gloss_text = gloss_text
        self.latest_translation_text = translation_text
        self.latest_text = translation_text or gloss_text
        self.latest_decode_method = decode_method
        self.latest_candidates = candidates
        self.touch()


class SessionManager:
    def __init__(self, max_buffer_frames: int) -> None:
        self._max_buffer_frames = max_buffer_frames
        self._sessions: Dict[str, SessionState] = {}
        self._lock = Lock()

    def create(self, metadata: Optional[Dict[str, str]] = None) -> SessionState:
        session = SessionState(
            session_id=str(uuid4()),
            metadata=metadata or {},
            max_buffer_frames=self._max_buffer_frames,
        )
        with self._lock:
            self._sessions[session.session_id] = session
        return session

    def get(self, session_id: str) -> Optional[SessionState]:
        with self._lock:
            return self._sessions.get(session_id)

    def require(self, session_id: str) -> SessionState:
        session = self.get(session_id)
        if session is None:
            raise KeyError(session_id)
        return session

    def delete(self, session_id: str) -> None:
        with self._lock:
            self._sessions.pop(session_id, None)

    def count(self) -> int:
        with self._lock:
            return len(self._sessions)