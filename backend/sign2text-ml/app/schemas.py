from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str
    modelLoaded: bool
    translationModelLoaded: bool
    poseExtractorLoaded: bool
    device: str
    activeSessions: int
    configPath: str
    checkpointPath: str


class SessionCreateRequest(BaseModel):
    metadata: Dict[str, str] = Field(default_factory=dict)


class SessionCreateResponse(BaseModel):
    sessionId: str
    createdAt: str
    status: str


class FrameUploadRequest(BaseModel):
    frameIndex: int
    timestampMs: int
    imageJpegBase64: str
    imageWidth: int
    imageHeight: int


class KeypointUploadRequest(BaseModel):
    frameIndex: int
    timestampMs: int
    keypoints: List[List[float]]


class InferenceRequest(BaseModel):
    predSrc: Literal["ensemble", "fuse"] = "ensemble"


class TensorInferenceRequest(BaseModel):
    videoTensorPath: str
    keypointTensorPath: str
    predSrc: Literal["ensemble", "fuse"] = "ensemble"


class TranslationCandidate(BaseModel):
    decodeMethod: str
    glossText: str


class FrameSizeResponse(BaseModel):
    width: int
    height: int


class SkeletonFrameResponse(BaseModel):
    frameIndex: int
    timestampMs: int
    sourceSize: FrameSizeResponse
    keypoints: List[List[float]]


class TranslationEventResponse(BaseModel):
    sessionId: str
    type: str
    status: str
    frameCount: int
    keypointCount: int
    modelLoaded: bool
    text: Optional[str] = None
    glossText: Optional[str] = None
    translationText: Optional[str] = None
    decodeMethod: Optional[str] = None
    candidates: List[TranslationCandidate] = Field(default_factory=list)
    notes: List[str] = Field(default_factory=list)
    metadata: Dict[str, str] = Field(default_factory=dict)
    skeletonFrame: Optional[SkeletonFrameResponse] = None


class WebSocketEnvelope(BaseModel):
    type: Literal["ping", "frame", "keypoints", "infer"]
    payload: Dict[str, Any] = Field(default_factory=dict)