from __future__ import annotations

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect

from .config import settings
from .pose import PoseDependencyError, WholeBodyPoseExtractor
from .preprocessing import build_tensors_from_session
from .runtime import OnlineCSLRRuntime
from .schemas import (
    FrameUploadRequest,
    HealthResponse,
    InferenceRequest,
    KeypointUploadRequest,
    SessionCreateRequest,
    SessionCreateResponse,
    TensorInferenceRequest,
    TranslationCandidate,
    TranslationEventResponse,
    WebSocketEnvelope,
)
from .session import FramePayload, KeypointPayload, SessionManager


app = FastAPI(title="Sign2Text SLRT Service", version="0.1.0")
runtime = OnlineCSLRRuntime(settings)
pose_extractor = WholeBodyPoseExtractor(settings)
session_manager = SessionManager(max_buffer_frames=settings.max_buffer_frames)


@app.on_event("startup")
def startup() -> None:
    if settings.eager_load:
        runtime.load()
    if settings.pose_eager_load:
        pose_extractor.load()


def build_health_response() -> HealthResponse:
    return HealthResponse(
        status="ok",
        modelLoaded=runtime.loaded,
        poseExtractorLoaded=pose_extractor.loaded,
        device=settings.device,
        activeSessions=session_manager.count(),
        configPath=str(settings.config_path),
        checkpointPath=str(settings.checkpoint_path),
    )


def serialize_response(response) -> dict:
    if hasattr(response, "model_dump"):
        return response.model_dump()
    return response.dict()


def build_session_response(session_id: str, response_type: str, status: str, notes: list[str]) -> TranslationEventResponse:
    try:
        session = session_manager.require(session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"Unknown session: {session_id}") from exc

    return TranslationEventResponse(
        sessionId=session.session_id,
        type=response_type,
        status=status,
        frameCount=session.frame_count,
        keypointCount=session.keypoint_count,
        modelLoaded=runtime.loaded,
        text=session.latest_text,
        decodeMethod=session.latest_decode_method,
        candidates=[TranslationCandidate(**candidate) for candidate in session.latest_candidates],
        notes=notes,
        metadata=session.metadata,
    )


@app.get("/api/v1/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return build_health_response()


@app.post("/api/v1/runtime/load", response_model=HealthResponse)
def load_runtime() -> HealthResponse:
    runtime.load()
    return build_health_response()


@app.post("/api/v1/translation/session", response_model=SessionCreateResponse)
def create_session(request: SessionCreateRequest) -> SessionCreateResponse:
    session = session_manager.create(metadata=request.metadata)
    return SessionCreateResponse(sessionId=session.session_id, createdAt=session.created_at, status="created")


@app.get("/api/v1/translation/session/{session_id}", response_model=TranslationEventResponse)
def get_session(session_id: str) -> TranslationEventResponse:
    return build_session_response(session_id, response_type="status", status="ready", notes=[])


@app.post("/api/v1/translation/session/{session_id}/frame", response_model=TranslationEventResponse)
def push_frame(session_id: str, request: FrameUploadRequest) -> TranslationEventResponse:
    try:
        session = session_manager.require(session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"Unknown session: {session_id}") from exc

    session.add_frame(
        FramePayload(
            frame_index=request.frameIndex,
            timestamp_ms=request.timestampMs,
            image_jpeg_base64=request.imageJpegBase64,
        )
    )
    return build_session_response(
        session_id,
        response_type="frame_buffered",
        status="buffering",
        notes=[
            "Frame buffered.",
            "Server-side pose extraction will run automatically during inference when keypoints are missing.",
        ],
    )


@app.post("/api/v1/translation/session/{session_id}/keypoints", response_model=TranslationEventResponse)
def push_keypoints(session_id: str, request: KeypointUploadRequest) -> TranslationEventResponse:
    try:
        session = session_manager.require(session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"Unknown session: {session_id}") from exc

    session.add_keypoints(
        KeypointPayload(
            frame_index=request.frameIndex,
            timestamp_ms=request.timestampMs,
            keypoints=request.keypoints,
        )
    )
    return build_session_response(
        session_id,
        response_type="keypoints_buffered",
        status="buffering",
        notes=["Keypoints buffered."],
    )


@app.post("/api/v1/translation/session/{session_id}/infer", response_model=TranslationEventResponse)
def infer_session(session_id: str, request: InferenceRequest) -> TranslationEventResponse:
    try:
        session = session_manager.require(session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"Unknown session: {session_id}") from exc

    if session.frame_count == 0:
        return build_session_response(
            session_id,
            response_type="partial_translation",
            status="buffering",
            notes=["No frames buffered yet."],
        )

    extraction_notes = []
    if session.keypoint_count < session.frame_count:
        try:
            extraction_summary = pose_extractor.extract_to_session(session)
        except PoseDependencyError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Pose extraction failed: {exc}") from exc

        if extraction_summary.extracted_frame_indices:
            extraction_notes.append(
                f"Extracted server-side whole-body keypoints for {len(extraction_summary.extracted_frame_indices)} buffered frames."
            )
        if extraction_summary.zero_filled_frame_indices:
            extraction_notes.append(
                "Pose extraction fell back to zero-filled keypoints for frames: "
                + ", ".join(str(frame_index) for frame_index in extraction_summary.zero_filled_frame_indices[:10])
                + (" ..." if len(extraction_summary.zero_filled_frame_indices) > 10 else "")
            )

    runtime.load()

    try:
        batch = build_tensors_from_session(
            session,
            use_keypoints=runtime.use_keypoints,
            expected_keypoint_count=runtime.expected_keypoint_count,
        )
        result = runtime.infer_live_tensors(
            video_tensor=batch.video_tensor,
            keypoint_tensor=batch.keypoint_tensor,
            pred_src=request.predSrc,
        )
    except ValueError as exc:
        return build_session_response(
            session_id,
            response_type="partial_translation",
            status="buffering",
            notes=[str(exc)],
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Live inference failed: {exc}") from exc

    session.update_result(
        text=result["text"],
        decode_method=result["decodeMethod"],
        candidates=result["candidates"],
    )

    notes = extraction_notes + [
        f"Ran live CSLR inference on {len(batch.frame_indices)} aligned frames.",
        f"Using decode method {result['decodeMethod']}",
    ]
    if batch.dropped_frame_indices:
        notes.append(
            "Dropped frames without aligned keypoints: "
            + ", ".join(str(frame_index) for frame_index in batch.dropped_frame_indices[:10])
            + (" ..." if len(batch.dropped_frame_indices) > 10 else "")
        )

    return build_session_response(
        session_id,
        response_type="partial_translation",
        status="ok",
        notes=notes,
    )


@app.post("/api/v1/debug/infer-tensors", response_model=TranslationEventResponse)
def infer_tensors(request: TensorInferenceRequest) -> TranslationEventResponse:
    result = runtime.infer_from_tensor_paths(
        video_tensor_path=request.videoTensorPath,
        keypoint_tensor_path=request.keypointTensorPath,
        pred_src=request.predSrc,
    )
    return TranslationEventResponse(
        sessionId="debug",
        type="partial_translation",
        status="ok",
        frameCount=0,
        keypointCount=0,
        modelLoaded=runtime.loaded,
        text=result["text"],
        decodeMethod=result["decodeMethod"],
        candidates=[TranslationCandidate(**candidate) for candidate in result["candidates"]],
        notes=["Inference completed using prebuilt tensors and the real CSLR runtime."],
        metadata={},
    )


@app.post("/api/v1/translation/session/{session_id}/finish", response_model=TranslationEventResponse)
def finish_session(session_id: str) -> TranslationEventResponse:
    response = build_session_response(session_id, response_type="final_translation", status="finished", notes=[])
    session_manager.delete(session_id)
    return response


@app.websocket("/api/v1/translation/session/{session_id}/stream")
async def translation_stream(session_id: str, websocket: WebSocket) -> None:
    try:
        session_manager.require(session_id)
    except KeyError:
        await websocket.close(code=4404)
        return

    await websocket.accept()
    await websocket.send_json(serialize_response(build_session_response(session_id, "status", "connected", ["WebSocket connected."])))

    try:
        while True:
            message = WebSocketEnvelope(**await websocket.receive_json())

            if message.type == "ping":
                await websocket.send_json(serialize_response(build_session_response(session_id, "status", "connected", ["pong"])))
                continue

            if message.type == "frame":
                payload = FrameUploadRequest(**message.payload)
                push_frame(session_id, payload)
                await websocket.send_json(
                    serialize_response(build_session_response(
                        session_id,
                        "frame_buffered",
                        "buffering",
                        ["Frame buffered over WebSocket. Server-side pose extraction will run during inference if needed."],
                    ))
                )
                continue

            if message.type == "keypoints":
                payload = KeypointUploadRequest(**message.payload)
                push_keypoints(session_id, payload)
                await websocket.send_json(
                    serialize_response(build_session_response(
                        session_id,
                        "keypoints_buffered",
                        "buffering",
                        ["Keypoints buffered over WebSocket."],
                    ))
                )
                continue

            if message.type == "infer":
                payload = InferenceRequest(**message.payload)
                response = infer_session(session_id, payload)
                await websocket.send_json(serialize_response(response))
                continue

    except WebSocketDisconnect:
        return