# Sign2Text ML Service

This folder contains a backend service skeleton for connecting the app to the working SLRT Online CSLR runtime.

Canonical path:
- `/home/haojun/projects/sign2text.app/backend/sign2text-ml`

Compatibility path:
- `/home/haojun/projects/sign2text.app/sign2text-ml`

## What The Service Does

- defines a FastAPI service with health, session, and WebSocket endpoints
- wraps the working CSLR model/config/checkpoint loading path
- keeps per-session frame and keypoint buffers in memory
- exposes a tensor-based debug inference endpoint that uses the real SLRT Online model runtime
- converts aligned buffered JPEG frames plus keypoints into live CSLR tensors for session inference
- extracts missing whole-body keypoints on the server from RGB frames during session inference
- feeds the best decoded gloss sequence into the Online SLT wait-k G2T model
- returns separate `glossText` and natural-language `translationText` fields
- keeps `text` as a compatibility field (`translationText` first, then `glossText`)

Both production translation paths have full dev/test evaluations. PHOENIX uses the German
wait-k=2 checkpoint. CSL-Daily defaults to the locally trained Chinese wait-k=2 checkpoint
(`results/g2t_wait2_csl_retrain_k2_20260920/ckpts/csl_best.ckpt`), which scored BLEU-4
20.16 on dev and 20.17 on test. The published standard beam-search CSL-Daily checkpoint
remains available as an explicit fallback and scored BLEU-4 23.22/22.88.

## Layout

- `app/server.py`: FastAPI app and endpoints
- `app/runtime.py`: CSLR model runtime wrapper
- `app/session.py`: in-memory session manager
- `app/schemas.py`: request and response schemas
- `app/config.py`: runtime settings and paths
- `run_server.sh`: startup helper using the known-good conda env

## Start The Service

```bash
cd /home/haojun/projects/sign2text.app/backend/sign2text-ml
bash run_server.sh
```

By default the service listens on `0.0.0.0:6006` and starts in CSL-Daily full-vocabulary CSLR mode.

Default runtime behavior:

- expects the CSL-Daily Online CSLR checkpoint at `/home/haojun/projects/models/checkpoints/online_slrt/csl_daily_cslr_best.ckpt`
- does not substitute the legacy `cslr_best.ckpt`, because the artifact previously stored under that name is a PHOENIX checkpoint (1116 output classes), not a CSL-Daily checkpoint
- uses the processed CSL-Daily full gloss vocabulary from `/home/haojun/projects/SLRT/TwoStreamNetwork/data/csl-daily/gloss2ids.pkl`

In this workspace, `run_server.sh` derives the workspace root from its own location and exports matching `WORKSPACE_ROOT`, `SLRT_ROOT`, `SLRT_CSLR_ROOT`, and `SLRT_SLT_ROOT` values automatically.
- enables CSL-Daily SLT and selects the trained wait-k=2 checkpoint/config pair by default
- selects the PHOENIX wait-k=2 checkpoint/config pair when `SLRT_DATASET_PRESET=phoenix`

You can override the port if needed:

```bash
PORT=8000 bash run_server.sh
```

You can switch back to the Phoenix preset if needed:

```bash
SLRT_DATASET_PRESET=phoenix SIGN2TEXT_ENABLE_SLT=1 bash run_server.sh
```

## Start Commands For The iOS App

The startup command is the same entrypoint for both presets: `bash run_server.sh`.
What changes is the environment.

CSL-Daily backend:

```bash
cd /home/haojun/projects/sign2text.app/backend/sign2text-ml
CUDA_VISIBLE_DEVICES=0 \
PORT=6006 \
SLRT_DATASET_PRESET=csl-daily \
SIGN2TEXT_ENABLE_SLT=1 \
bash run_server.sh
```

PHOENIX backend:

```bash
cd /home/haojun/projects/sign2text.app/backend/sign2text-ml
CUDA_VISIBLE_DEVICES=0 \
PORT=6007 \
SLRT_DATASET_PRESET=phoenix \
SIGN2TEXT_ENABLE_SLT=1 \
bash run_server.sh
```

The PHOENIX command auto-selects
`SLRT/Online/SLT/results/g2t_wait2/ckpts/best.ckpt`. If your shell already exports an old
`SLRT_SLT_CHECKPOINT`, unset it or set the correct path explicitly.

The CSL-Daily command automatically selects this matched pair:

- config: `SLRT/Online/SLT/configs/g2t_wait2_csl_retrain_k2_20260920.yaml`
- checkpoint: `SLRT/Online/SLT/results/g2t_wait2_csl_retrain_k2_20260920/ckpts/csl_best.ckpt`

To use the published standard beam-search model instead, set both
`SLRT_SLT_CHECKPOINT=models/checkpoints/online_slrt/csl_daily_g2t_best.ckpt` and
`SLRT_SLT_CONFIG=SLRT/Online/SLT/configs/g2t_csl.yaml`. The service also recognizes
the original MMTLB-style paths `results/g2t_wait2_csl/ckpts/{best,step_1000}.ckpt` and
`results/csl-daily_g2t/ckpts/step_1000.ckpt`.

The local `downloads/manual_slrt/wait_k_slt/mBart_zh_t2g/text_embeddings.bin`
matches the checkpoint's entire 6308-by-1024 text embedding matrix byte for byte.
`g2t_csl.yaml` therefore uses this downloaded text tokenizer package. Its separate
2009-entry gloss tokenizer is not used: the checkpoint requires the 2004-entry
`models/checkpoints/online_slrt/csl_daily_g2t_gloss2ids.pkl`, recovered by exact embedding-row matches for all 2000 lexical glosses,
with EOS/language/UNK/PAD roles assigned for the four special entries. The SLR gloss
map has a different ordering and must not be used for G2T. Trained gloss embeddings are restored
from the checkpoint. Directory names alone do not establish model compatibility.

If you run only one backend at a time, the commands are effectively the same except for `SLRT_DATASET_PRESET`, `SIGN2TEXT_ENABLE_SLT`, and optionally `PORT`.

If you want the iOS app to switch between CSL-Daily and PHOENIX without changing the backend URL manually each time, run both processes at the same time on different ports, for example `6006` and `6007`.

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
- `POST /api/v1/debug/translate-gloss`
- `WS /api/v1/translation/session/{sessionId}/stream`

## Debug Inference Endpoint

`/api/v1/debug/infer-tensors` is the endpoint that already wraps the real CSLR runtime.

It expects paths to prebuilt `.pt` tensors:

- `videoTensorPath`: tensor shaped like `1 x T x C x H x W`
- `keypointTensorPath`: tensor shaped like `1 x T x K x 3`

This is useful for backend bring-up before realtime frame preprocessing is implemented.

To validate only the G2T stage, without camera, pose, or CSLR inference:

```bash
curl -X POST http://127.0.0.1:6007/api/v1/debug/translate-gloss \
  -H 'content-type: application/json' \
  -d '{"glossText":"JETZT WETTER MORGEN DONNERSTAG"}'
```

The validated PHOENIX model returns a sentence such as
`und nun die wettervorhersage für morgen donnerstag den sechzehnten juli .`.

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
- persistent cross-request decoder state for token-by-token wait-k streaming; the current
  endpoint reruns wait-k decoding on the latest complete gloss hypothesis

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
