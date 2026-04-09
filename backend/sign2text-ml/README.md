# Sign2Text ML Service

This folder contains a backend service skeleton for connecting the app to the working SLRT Online CSLR runtime.

Canonical path:
- `/root/autodl-tmp/sign2text.app/backend/sign2text-ml`

Compatibility path:
- `/root/autodl-tmp/sign2text.app/sign2text-ml`

## What This Skeleton Does

- defines a FastAPI service with health, session, and WebSocket endpoints
- wraps the working CSLR model/config/checkpoint loading path
- keeps per-session frame and keypoint buffers in memory
- exposes a tensor-based debug inference endpoint that uses the real SLRT Online model runtime
- converts aligned buffered JPEG frames plus keypoints into live CSLR tensors for session inference
- extracts missing whole-body keypoints on the server from RGB frames during session inference

## What This Skeleton Does Not Do Yet

- it does not yet connect CSLR output to the Online SLT text model

That means the service is a real backend scaffold, not a finished realtime translation server.

## Layout

- `app/server.py`: FastAPI app and endpoints
- `app/runtime.py`: CSLR model runtime wrapper
- `app/session.py`: in-memory session manager
- `app/schemas.py`: request and response schemas
- `app/config.py`: runtime settings and paths
- `run_server.sh`: startup helper using the known-good conda env

## Start The Service

```bash
cd /root/autodl-tmp/sign2text.app/backend/sign2text-ml
bash run_server.sh
```

By default the service listens on `0.0.0.0:6006`.

You can override the port if needed:

```bash
PORT=8000 bash run_server.sh
```

## Recommended AutoDL Device Access

For AutoDL plus a physical iPhone, the recommended development path is:

1. run the backend on port `6006`
2. create an SSH tunnel from the AutoDL instance to your Mac
3. point the iPhone app at your Mac's LAN IP on port `6006`

Example SSH tunnel command on your Mac:

```bash
ssh -CNg -L 6006:127.0.0.1:6006 root@connect.nmb2.seetacloud.com -p <your-ssh-port>
```

If you want the iPhone to reach the tunnel through your Mac on the local network, use a bind address that is not loopback, for example:

```bash
ssh -CNg -L 0.0.0.0:6006:127.0.0.1:6006 root@connect.nmb2.seetacloud.com -p <your-ssh-port>
```

Then set the native app backend URL to:

```text
http://<your-mac-lan-ip>:6006
```

Do not use `http://127.0.0.1:6006` on a physical iPhone. That only points back to the phone itself.

## Key Endpoints

- `GET /api/v1/health`
- `POST /api/v1/runtime/load`
- `POST /api/v1/translation/session`
- `GET /api/v1/translation/session/{sessionId}`
- `POST /api/v1/translation/session/{sessionId}/frame`
- `POST /api/v1/translation/session/{sessionId}/keypoints`
- `POST /api/v1/translation/session/{sessionId}/infer`
- `POST /api/v1/translation/session/{sessionId}/finish`
- `POST /api/v1/debug/infer-tensors`
- `WS /api/v1/translation/session/{sessionId}/stream`

## Debug Inference Endpoint

`/api/v1/debug/infer-tensors` is the endpoint that already wraps the real CSLR runtime.

It expects paths to prebuilt `.pt` tensors:

- `videoTensorPath`: tensor shaped like `1 x T x C x H x W`
- `keypointTensorPath`: tensor shaped like `1 x T x K x 3`

This is useful for backend bring-up before realtime frame preprocessing is implemented.

## Live Session Inference

`POST /api/v1/translation/session/{sessionId}/infer` now performs live preprocessing for buffered session data:

- decodes buffered JPEG frames from base64
- extracts missing whole-body keypoints on the server with MMPose HRNet
- aligns them by `frameIndex` with buffered or extracted keypoints
- builds tensors shaped for the CSLR runtime
- runs real CSLR inference on the aligned buffer

Current constraints:

- the server-side extractor expects `mmdet` and `mmpose` in the `slrt_legacy` env
- extracted keypoints are converted from full 133-point HRNet whole-body output into the exact subset required by the CSLR config
- all keypoint payloads in a session must resolve to the same model-expected number of points
- frame images should have a consistent resolution within a session

What is still missing:

- temporal smoothing logic beyond the current CSLR decode output
- Online SLT text generation from gloss predictions

## Install Notes

This service is intended to run in the same `slrt_legacy` environment used for the verified Online CSLR test.

If the service dependencies are not installed in that env, install them with:

```bash
pip install fastapi uvicorn pydantic numpy Pillow
```

For server-side pose extraction, the tested package set in `slrt_legacy` is:

```bash
pip install fastapi uvicorn pydantic numpy Pillow
pip install setuptools wheel
pip install --no-build-isolation mmcv==1.7.0
pip install pycocotools terminaltables matplotlib json_tricks munkres
pip install --no-build-isolation chumpy==0.70
pip install --no-deps mmdet==2.28.2
pip install --no-deps mmpose==0.29.0
pip install xtcocotools
```

This exact stack was validated by loading the detector and HRNet whole-body pose model in the backend service.