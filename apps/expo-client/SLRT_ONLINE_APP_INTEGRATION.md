# Connect Sign2Text App To SLRT Online

This guide explains how to connect the current app in `/home/haojun/projects/sign2text.app/apps/expo-client` to the working SLRT Online inference pipeline in `/home/haojun/projects/SLRT/Online` so the product can translate real-time sign language video to text.

## 1. What Works Today

Confirmed working backend-side command:

```bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate slrt_legacy
export OMP_NUM_THREADS=1
cd /home/haojun/projects/SLRT/Online/CSLR
python -m torch.distributed.run \
  --nproc_per_node 1 \
  --master_port 29997 \
  prediction_slide.py \
  --config=configs/slide_phoenix-2014t.yaml \
  --save_fea 0
```

This proves the Online CSLR model can run in the current workspace.

## 2. What Does Not Exist Yet

The app is not directly connected to SLRT Online.

The current app code is built around single-frame polling:

- `components/CameraView.tsx` uses `takePictureAsync()`
- `components/CameraView.tsx` captures at a fixed interval
- `services/signLanguageService.ts` sends one image per request
- `services/signLanguageService.ts` expects Roboflow-style single-response output

That is not the same problem as Online SLRT.

## 3. Non-Negotiable Architecture Constraint

You should not call `prediction_slide.py` directly from the app.

Why:

- `prediction_slide.py` is dataset-driven, not session-driven
- it expects data loaders and batch structures built from prepared dataset files
- it loads the model from Python in a GPU environment
- the app cannot realistically host the full PyTorch/MMCV runtime on-device in the current setup

The right architecture is:

`iOS App -> Realtime Inference Backend -> SLRT Online Models -> Text back to App`

## 4. Recommended End-to-End Architecture

### 4.1 App Layer

The app should:

- capture front-camera frames continuously
- send frames to a backend session over HTTP or WebSocket
- receive partial and final text updates
- display translation state, connectivity state, and latency state

### 4.2 Backend Session Layer

The backend should:

- keep one session per active user/device
- receive timestamped frames
- maintain a rolling frame buffer
- run sliding-window inference every few new frames
- keep and smooth partial gloss hypotheses
- optionally pass stable glosses into an Online SLT stage to produce text

### 4.3 Model Layer

Use two model stages:

1. Online CSLR
   - input: streaming video frames plus corresponding keypoints
   - output: gloss sequence or partial gloss hypotheses

2. Online SLT
   - input: gloss stream or stabilized gloss chunks
   - output: natural-language text

Important: CSLR alone gives glosses, not final user-facing text. If you want actual translated text, you need the SLT stage or an equivalent gloss-to-text layer.

## 5. The Biggest Technical Gap

SLRT Online expects both RGB and keypoint information.

Your current app only sends RGB still images.

You need one of these strategies:

### Option A. Server-side keypoint extraction

Recommended first.

- app streams RGB frames only
- backend runs pose/keypoint extraction per frame
- backend converts pose outputs into the keypoint tensor format expected by the model

This is easier to control and keeps all ML-heavy dependencies on the GPU machine.

### Option B. On-device keypoint extraction

More complex.

- app extracts pose keypoints on-device
- app sends keypoints plus optionally compressed RGB frames
- backend skips part of the preprocessing work

This reduces bandwidth but increases mobile complexity.

For the current project, Option A is the correct first implementation.

## 6. Recommended Delivery Path

Do this in phases.

### Phase 1. Build a backend wrapper around the already-working Online test

Goal:
- turn the working offline test code into a reusable Python service

Current scaffold location in this workspace:

- `/home/haojun/projects/sign2text.app/backend/sign2text-ml`

Current scaffold contents:

- FastAPI service skeleton
- session manager
- CSLR runtime loader tied to the working config and checkpoint
- debug endpoint for tensor-based inference
- WebSocket/session API skeleton for app integration

Implementation steps:

1. Create service code under the canonical backend folder, for example:
  - `/home/haojun/projects/sign2text.app/backend/sign2text-ml/app`
  - or under `/home/haojun/projects/SLRT/Online/service` if you later decide to move it closer to SLRT

2. Refactor model loading out of `prediction_slide.py` into a reusable runtime class.

Suggested shape:

```python
class OnlineCSLRSession:
    def __init__(self, config_path, checkpoint_path, device='cuda'):
        ...

    def push_frame(self, rgb_frame, timestamp_ms):
        ...

    def push_keypoints(self, keypoints):
        ...

    def infer_partial(self):
        return {
            'gloss_text': '...',
            'confidence': 0.0,
            'window_index': 0,
        }
```

3. Extract reusable logic from `prediction_slide.py`:
   - model loading
   - `sliding_windows`
   - decode logic
   - hypothesis smoothing

4. Replace dataset-loader usage with live session buffers.

The backend session should build tensors from incoming live frames instead of reading from dataset files.

### Phase 2. Add an Online SLT stage

Goal:
- convert glosses into user-facing text

Implementation steps:

1. Load the Online SLT model in the same service process or in a second worker.
2. Feed stabilized gloss chunks into the SLT model.
3. Return partial text updates and final text updates separately.

Suggested backend output contract:

```json
{
  "type": "partial_translation",
  "sessionId": "abc123",
  "gloss": "ICH WOHNEN ...",
  "text": "I live ...",
  "isFinal": false,
  "latencyMs": 420
}
```

### Phase 3. Replace app image polling with streaming capture

Goal:
- make the UI behave like real-time translation, not repeated photo upload

The current `expo-camera` polling approach is acceptable for a prototype smoke test, but not for true real-time sign recognition.

For true real-time behavior, use one of these routes:

1. Expo dev build plus a camera stack that supports frame processing
2. Native iOS capture path using AVFoundation
3. Short-clip upload prototype if you only need near-real-time, not low-latency streaming

The current app can serve as a UI shell, but its camera/service contract needs to change.

## 7. Concrete Backend API Design

Use WebSocket for partial updates.

### 7.1 Session lifecycle

Recommended endpoints:

- `POST /api/v1/translation/session`
  - create session
- `WS /api/v1/translation/session/{sessionId}/stream`
  - stream frames in, stream partial translations out
- `POST /api/v1/translation/session/{sessionId}/finish`
  - end session and flush final text
- `GET /api/v1/health`
  - health check

### 7.2 Message types

App to backend:

```json
{
  "type": "frame",
  "sessionId": "abc123",
  "timestampMs": 1710000000000,
  "frameIndex": 42,
  "imageJpegBase64": "..."
}
```

Backend to app:

```json
{
  "type": "partial_translation",
  "sessionId": "abc123",
  "gloss": "ICH",
  "text": "I",
  "confidence": 0.82,
  "isFinal": false
}
```

Final response:

```json
{
  "type": "final_translation",
  "sessionId": "abc123",
  "gloss": "ICH WOHNEN HIER",
  "text": "I live here",
  "isFinal": true
}
```

## 8. Exact App Files To Change

### `components/CameraView.tsx`

Current problem:
- takes one photo at a time
- uses `setInterval()` polling

Required change:
- replace still-photo polling with continuous frame streaming or clip capture
- emit frames with timestamps, not one-off base64 photos intended for image classification

### `components/SignLanguageDetector.tsx`

Current problem:
- assumes `processFrame(base64)` returns immediate text

Required change:
- manage session start/stop
- open WebSocket connection
- push frames continuously
- render partial and final translation states
- display backend health, buffering state, and latency

### `services/signLanguageService.ts`

Current problem:
- hardcoded Roboflow-style API
- one request per image
- response parsing designed for object detection output

Required change:
- replace with a realtime translation client
- support session creation
- support WebSocket streaming
- support partial/final translation callbacks

### `services/types.ts`

Current problem:
- interface only models one-shot `processFrame`

Required change:
- replace with a session-oriented contract, for example:

```ts
export interface IRealtimeTranslationService {
  startSession(onUpdate: (event: TranslationEvent) => void): Promise<void>;
  sendFrame(frame: CapturedFrame): Promise<void>;
  stopSession(): Promise<void>;
  clear(): void;
}
```

### `services/apiConfig.ts`

Required change:
- point to your backend base URL
- add WebSocket URL
- add timeouts and retry policy suitable for streaming

## 9. Recommended App Service Contract

Use these client-side types:

```ts
export type CapturedFrame = {
  sessionId: string;
  frameIndex: number;
  timestampMs: number;
  jpegBase64: string;
};

export type TranslationEvent = {
  type: 'partial_translation' | 'final_translation' | 'status' | 'error';
  text?: string;
  gloss?: string;
  confidence?: number;
  isFinal?: boolean;
  message?: string;
};
```

## 10. Realtime Capture Guidance

### Prototype mode

Fastest path:

- keep the Expo UI
- send a low-rate frame every 300 to 500 ms
- accept that latency and accuracy will be worse than a true streaming pipeline

This is good for proving app-to-backend integration.

### Real-time mode

Better path:

- move to a frame-processing camera solution
- target 8 to 12 fps initially
- batch small JPEGs or use efficient transport over WebSocket
- smooth partial outputs on the backend before showing them in the UI

Do not call `takePictureAsync()` once per second and expect production-quality online sign translation.

## 11. Backend Runtime Checklist

The backend server should run in the same environment that already works for Online CSLR:

```bash
source /root/miniconda3/etc/profile.d/conda.sh
conda activate slrt_legacy
export OMP_NUM_THREADS=1
```

Backend process responsibilities:

- preload model weights once at startup
- reuse GPU model instances across sessions
- avoid reloading checkpoints per request
- maintain per-session buffers in memory
- log latency for pose extraction, CSLR inference, and SLT inference separately

## 12. Suggested Milestones

### Milestone 1. Backend smoke test

- wrap CSLR inference in a Python service
- send prerecorded frames from a script
- return partial gloss output

### Milestone 2. App-to-backend prototype

- connect the Expo app to the backend
- stream low-rate frames
- display partial glosses and partial text

### Milestone 3. True translation path

- integrate Online SLT after CSLR
- display natural-language text instead of gloss-only output

### Milestone 4. Realtime quality improvement

- improve capture FPS
- reduce transport overhead
- improve session smoothing and latency

## 13. What I Recommend You Build Next

1. A Python backend service that wraps the already-working CSLR command as a long-lived model runtime
2. A session-based WebSocket API for frame streaming and partial text updates
3. A new app service layer that replaces the current Roboflow-style `processFrame()` call pattern
4. A later SLT stage so the product returns actual text instead of glosses

## 14. Short Version

If your goal is real-time sign-language-video-to-text:

- keep the app as UI and camera shell
- do not run SLRT inside the app
- run SLRT Online on the GPU backend
- refactor SLRT from dataset script into a session service
- stream frames from the app to the backend
- run CSLR first, then SLT for text

That is the correct technical path for this repository.