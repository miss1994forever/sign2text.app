# iOS-to-CSLR input validation — 2026-09-29

## Scope and frozen predictor

This validation changes only the live input adapter. The main-test predictor remains frozen:

- CSL-Daily checkpoint: `models/checkpoints/online_slrt/csl_daily_cslr_best.ckpt`
- source: `ensemble`
- window: 16 frames
- stride: fixed 1; adaptive stride disabled
- span-weighted voting disabled
- selected decoder: `window_greedy_13`

No checkpoint, fusion weight, window, stride, candidate decoder, voting rule, or controller was changed.

## Input adapter

The offline CSL-Daily loader reads 512-by-512 source frames, resizes RGB to 320-by-320, and retains keypoints in the configured 512-by-512 raw heatmap coordinate system. The iOS client uploads JPEG frames whose longest dimension is at most 320 pixels. Whole-body keypoints extracted from those uploads are therefore expressed in uploaded-frame coordinates.

The live adapter now:

1. resizes RGB to the dataset's canonical RGB dimensions;
2. scales keypoint x/y coordinates from the decoded upload dimensions to the model's configured `heatmap_cfg.raw_size`;
3. leaves confidence values and predictor behavior unchanged.

For Phoenix, the same mechanism maps live RGB and keypoints to its configured 210-by-260 coordinate space.

## Replays

All measurements below are CPU-only server diagnostics. They exclude camera, Wi-Fi, SSH tunnel, and iOS UI latency. Translation was disabled except in the earlier stage-isolation check, so CSLR errors could not be hidden by wait-k.

| Sample / variant | Frames | Reference | Final gloss | Exact | CPU time |
|---|---:|---|---|---:|---:|
| `S000020_P0000_T00`, raw dataset frames + canonical adapter | 54 | `他 今天 年龄 4` | `他 今天 年龄 4` | yes | 228.50 s |
| `S003131_P0000_T00`, raw dataset frames + canonical adapter | 49 | `我 看 你 想 呕吐` | `我 看 你 想 呕吐` | yes | 230.34 s |
| `S003850_P0002_T00`, raw dataset frames + canonical adapter | 49 | `请 保持 安静` | `请 保持 安静` | yes | 221.83 s |
| `S000020_P0000_T00`, iOS-like 320 JPEG quality 55 + canonical adapter | 54 | `他 今天 年龄 4` | `他 今天 年龄 4` | yes | 234.83 s |
| `S000020_P0000_T00`, same iOS-like input without coordinate adapter | 54 | `他 今天 年龄 4` | empty (`naive: 送 请 大概`) | no | 219.64 s |

The controlled iOS-like comparison changes only coordinate normalization. It demonstrates that the adapter is causal for this sample rather than an incidental improvement.

An earlier 47-frame replay returned `他 今天 年龄`. That run used a stale local metadata file. The active configured dev manifest defines the sample as 54 frames; the omitted final seven frames contain the final sign `4`. Tests must use the manifest selected by the active runtime config.

## Current best supported setting

With the frozen predictor, the best setting supported by current evidence is:

- preserve the iOS client's 320-pixel upload limit and JPEG quality 0.55;
- canonicalize RGB to the selected dataset's expected input dimensions;
- rescale keypoints from decoded upload dimensions to the selected model's raw heatmap coordinate space;
- use frame counts and utterance boundaries from the active manifest for replay evaluation;
- keep CSLR gloss output separate from wait-k text during recognition evaluation.

## Remaining validation

- Run a larger frozen CSL-Daily dev subset on GPU; CPU throughput is roughly 220–235 seconds per 49–54-frame sentence and is not suitable for broader sweeps.
- Measure GPU cold load, warm CSLR, pose extraction, queueing, and end-to-end latency separately.
- Validate automatic utterance boundary handling for live camera input, where no manifest frame count exists.
- Install on a physical iPhone or iPad and measure camera-to-display latency over the actual tunnel.
- Run the Phoenix iOS-like controlled replay; unit coverage confirms its size/coordinate conversion, but no Phoenix model replay was performed in this CPU pass.
