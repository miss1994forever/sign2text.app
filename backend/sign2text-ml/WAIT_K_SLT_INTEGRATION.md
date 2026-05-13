# Wait-k SLT Integration Guide

This document describes the practical steps required to extend the current Sign2Text backend from gloss-only Online CSLR output to real wait-k sign language translation text output.

Current state:

- the app streams RGB frames to `sign2text-ml`
- the backend preprocesses the buffered session into Online CSLR tensors
- the backend runs the Online CSLR model and returns gloss-like text in `response.text`
- the backend does not yet invoke the Online SLT wait-k gloss-to-text model

Target state:

- keep the existing live RGB to CSLR preprocessing path
- decode gloss hypotheses from the Online CSLR runtime
- feed those gloss hypotheses into the Online SLT wait-k model
- return natural-language translation text to the app
- optionally keep both fields available: `glossText` and `translationText`

## 1. Confirm Required SLT Assets

Before wiring code, verify that the Online SLT runtime assets exist.

Required inputs from the original SLRT repo:

- SLT config: `/home/haojun/projects/SLRT/Online/SLT/configs/g2t_wait2.yaml`
- Phoenix Online gloss predictions format reference: `/home/haojun/projects/SLRT/Online/SLT/configs/g2t_wait2.yaml`
- tokenizer and embedding assets under `/home/haojun/projects/models/pretrained_models/mBart_de`
- a trained wait-k checkpoint under the SLT results directory, expected by the chosen config

Useful verification commands:

```bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate slrt_legacy

ls /home/haojun/projects/SLRT/Online/SLT/configs
ls /home/haojun/projects/models/pretrained_models/mBart_de
find /home/haojun/projects/SLRT/Online/SLT/results -maxdepth 3 -type f | head
```

If the wait-k checkpoint is missing, the integration should stop here. The rest of the backend can be prepared, but real translation cannot run without that checkpoint.

## 2. Keep The Runtime Split Clear

Do not merge CSLR and SLT logic into one large runtime class.

Recommended structure:

- keep `app/runtime.py` focused on Online CSLR tensor inference
- add a new `app/slt_runtime.py` for wait-k gloss-to-text inference
- keep request orchestration in `app/server.py`
- keep per-session latest outputs in `app/session.py`

Why this split matters:

- CSLR consumes live tensors from buffered frames and keypoints
- SLT consumes decoded gloss sequences, not raw video tensors
- load failures, checkpoint paths, and validation rules differ between the two models

## 3. Add SLT Runtime Configuration

Extend `app/config.py` with explicit SLT settings instead of hardcoding paths in the runtime.

Recommended new settings:

- `slt_root`: `/home/haojun/projects/SLRT/Online/SLT`
- `slt_config_path`: default to `/home/haojun/projects/SLRT/Online/SLT/configs/g2t_wait2.yaml`
- `slt_checkpoint_path`: environment override for the trained wait-k checkpoint
- `enable_slt`: boolean flag to allow booting backend in gloss-only mode

Use environment variables so the service can still run when SLT is unavailable:

```text
SLRT_SLT_ROOT
SLRT_SLT_CONFIG
SLRT_SLT_CKPT
SIGN2TEXT_ENABLE_SLT
```

## 4. Implement A Dedicated Wait-k Runtime

Create `app/slt_runtime.py` with a small surface area.

Suggested methods:

- `load()`
- `translate_gloss_text(gloss_text: str) -> dict`
- `loaded` property

Expected input:

- one decoded gloss sequence string, for example `JETZT WETTER MORGEN`

Expected output shape:

```python
{
    "text": "und nun die wettervorhersage fuer morgen",
    "glossText": "JETZT WETTER MORGEN",
    "decodeMethod": "wait_k_2",
    "notes": ["Translated from online CSLR gloss sequence."]
}
```

Implementation notes:

- mirror the model-loading conventions already used in `app/runtime.py`
- load the wait-k config from `g2t_wait2.yaml`
- load the SLT checkpoint once and reuse it across requests
- keep the API synchronous at first; do not introduce background jobs until the direct path works

The first version can translate only the best gloss string from CSLR. Do not try to support beam reranking or candidate fusion in the first pass.

## 5. Decide The Handoff Format From CSLR To SLT

The current backend returns a dictionary from `OnlineCSLRRuntime.infer_live_tensors()` with:

- `text`: currently a gloss string
- `decodeMethod`
- `candidates`: gloss candidates with `glossText`

For wait-k integration, keep the CSLR result intact and add a second stage:

1. run CSLR inference exactly as today
2. pick the current best gloss candidate
3. send that gloss string into the new wait-k runtime
4. place the translated sentence into a separate response field

Recommended rule for v1:

- use the current `best_method` gloss candidate from CSLR as the sole SLT input

Do not overwrite gloss data too early. Keep both representations available for debugging.

## 6. Extend Session State

Update `app/session.py` so a session can store both recognition and translation outputs.

Recommended new fields:

- `latest_gloss_text`
- `latest_translation_text`
- `latest_slt_decode_method`

Recommended update flow:

- CSLR inference updates `latest_gloss_text`
- SLT inference updates `latest_translation_text`
- the backend response exposes both, even if one is missing

This avoids the current ambiguity where `latest_text` sometimes means gloss and is labeled as translation.

## 7. Extend Response Schemas

Update `app/schemas.py` so the API can distinguish recognition output from translation output.

Recommended additions to `TranslationEventResponse`:

- `glossText: Optional[str]`
- `translationText: Optional[str]`
- `translationModelLoaded: bool`
- optional `translationNotes: List[str]`

Recommended compatibility rule:

- keep `text` temporarily for the app
- set `text` to `translationText` when SLT is enabled and successful
- otherwise fall back to `glossText`

This preserves app behavior while allowing a gradual migration.

## 8. Update The Session Inference Endpoint

The main integration point is `POST /api/v1/translation/session/{sessionId}/infer` in `app/server.py`.

Recommended sequence inside that endpoint:

1. run the existing session-to-tensors preprocessing
2. run Online CSLR inference
3. extract the best gloss string
4. if SLT is enabled and loaded, run wait-k translation on that gloss string
5. store both results in session state
6. build the response with explicit `glossText` and `translationText`

Suggested first-pass failure policy:

- if CSLR fails: return an error as today
- if CSLR succeeds but SLT fails: still return success with `glossText`, plus a note that translation failed

That keeps the app usable while SLT bring-up is still unstable.

## 9. Add Separate Load And Health Signals

The health endpoint should expose SLT status independently from CSLR status.

Recommended health fields:

- `modelLoaded`: existing CSLR load state
- `translationModelLoaded`: new SLT load state
- `poseExtractorLoaded`: existing pose extractor state

Also add a startup or manual load path for SLT, following the pattern already used for CSLR.

## 10. Update The iOS Contract Carefully

The iOS app currently renders `response.text` as if it were final translation text.

Recommended migration path:

Phase 1:

- backend returns both `glossText` and `translationText`
- backend keeps `text = translationText if available else glossText`
- app UI works without changes

Phase 2:

- update `TranslationService.swift` to decode the new fields explicitly
- optionally surface a debug view that shows both gloss and final translation

Phase 3:

- rename UI labels so they stop calling gloss output "translation"

## 11. Validate With Offline Probes Before Live App Testing

Do not start by testing only through the iPhone app.

Recommended validation order:

1. load the SLT runtime in a small Python probe
2. feed a known Phoenix gloss string into wait-k translation
3. confirm the runtime returns a sentence-like German text output
4. connect the same call inside FastAPI
5. test the backend with a fixed buffered session
6. only then test live camera streaming from the app

Useful intermediate probe idea:

- add a temporary debug endpoint that accepts a plain gloss string and returns wait-k text

Example contract:

```json
{
  "glossText": "JETZT WETTER MORGEN DONNERSTAG"
}
```

Example response:

```json
{
  "glossText": "JETZT WETTER MORGEN DONNERSTAG",
  "translationText": "und nun die wettervorhersage fuer morgen donnerstag"
}
```

This isolates SLT debugging from camera, JPEG encoding, pose extraction, and tensor alignment.

## 12. Use The Original SLT Code Path Instead Of Reimplementing Wait-k Logic

Avoid rebuilding the wait-k model from scratch inside the backend.

Reuse the original Online SLT implementation as much as possible:

- config loading from `SLRT/Online/SLT/configs/g2t_wait2.yaml`
- tokenizer assets from `models/pretrained_models/mBart_de`
- generation path equivalent to the original `generate_txt` usage in `SLRT/Online/SLT/prediction.py`

The backend wrapper should adapt inputs and outputs, not invent a new translation model.

## 13. First Minimal Milestone

The smallest useful milestone is not full live wait-k streaming.

It is this:

- keep current live CSLR session inference unchanged
- add one server-side SLT runtime wrapper
- translate only the current best gloss string after each `/infer`
- return both gloss and translation in the API response

Once that works, you can decide whether to invest in:

- incremental wait-k state across requests
- candidate reranking across multiple CSLR decodes
- UI rendering of partial gloss versus partial translation

## 14. Files Likely To Change

Expected backend file changes:

- `app/config.py`
- `app/server.py`
- `app/session.py`
- `app/schemas.py`
- `app/runtime.py` or its call sites
- new `app/slt_runtime.py`

Possible app-side follow-up changes:

- `apps/ios-native/sign2text-app/TranslationService.swift`
- `apps/ios-native/sign2text-app/ContentView.swift`

## 15. Definition Of Done

Treat the integration as complete only when all of the following are true:

- the backend can load both CSLR and SLT models in the `slrt_legacy` environment
- `/infer` returns separate `glossText` and `translationText`
- `translationText` is sentence-like natural language, not gloss labels
- the iOS app displays translated text during live testing
- if SLT fails, the backend still returns gloss output with a clear note

## 16. Common Failure Modes

Watch for these specific issues during bring-up:

- missing wait-k checkpoint
- wrong tokenizer or embedding paths under `mBart_de`
- mismatch between gloss token formatting expected by SLT and gloss strings emitted by CSLR
- importing SLT modules with incompatible relative paths
- loading the backend in an environment that has CSLR dependencies but not the SLT text-generation stack
- UI still showing `text` while backend silently keeps sending gloss fallback

If translation quality looks suspiciously like gloss labels, log both `glossText` and `translationText` side by side before debugging anything else.