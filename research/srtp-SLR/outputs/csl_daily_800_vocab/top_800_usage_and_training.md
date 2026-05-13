# CSL-Daily top-800 vocabulary package

## Files

- `target_glosses_top_800.txt`: full ranked 800-gloss vocabulary, one gloss per line.
- `target_glosses_top_200_core.txt`: the highest-frequency 200-gloss core.
- `target_glosses_top_201_500_expand.txt`: the next 300 glosses used for expansion.
- `target_glosses_top_501_800_tail.txt`: the last 300 glosses used for tail coverage.
- `../csl_daily_200_vocab/top_800_vocab.csv`: full frequency table with train/dev/test counts.
- `../csl_daily_200_vocab/report_top_800_vocab.md`: exact coverage report.

## What this 800-word set buys you

This vocabulary is the first CSL-Daily size that is genuinely practical for a closed-vocabulary recognizer.

- Train token coverage: 89.30%
- Dev token coverage: 87.97%
- Test token coverage: 87.92%
- Train exact closed-vocabulary sentence coverage: 49.92%
- Dev exact closed-vocabulary sentence coverage: 33.43%
- Test exact closed-vocabulary sentence coverage: 34.01%

Interpretation:

- It is strong enough for a constrained recognizer, online assistant, or phrase-level interaction system.
- It is still not a full replacement for the original 2000-gloss open-vocabulary CSL-Daily task.
- If you need most held-out sentences to remain fully usable, move to 1000 or 1200 glosses.

## Recommended usage scenarios

### 1. Closed-vocabulary daily communication recognizer

Best fit when the product interaction is naturally constrained and the user intent lives in common daily expressions.

- Example products: sign-to-text chat helper, front-desk assistant, kiosk, hospital intake helper, classroom helper.
- Why 800 works: coverage is high enough that most token mass is retained, and about one third of dev/test full sentences stay fully in-vocabulary.
- Recommended task form: gloss recognition first, text generation second.

### 2. Online incremental recognition for practical prompts

Best fit when you want low-latency recognition and can bias the prompt space toward common phrases.

- Example products: live assistant with predefined prompt families, interaction menus, guided data collection app.
- Why 800 works: the head 200 and mid 300 provide strong support for common phrases, while the tail 300 reduces obvious blind spots.
- Recommended task form: sliding-window ISLR or online CSLR with a constrained decoder.

### 3. Curriculum stage before full-vocabulary training

Best fit when the final target is still the full CSL-Daily vocabulary, but you want a more stable first stage.

- Example products: research model pretraining, student model distillation, low-resource adaptation.
- Why 800 works: it is large enough to preserve realistic sentence structure while still removing a large amount of long-tail label noise.
- Recommended task form: pretrain on 200 -> 500 -> 800, then optionally expand to 2000 plus `<unk>`.

## Recommended training tracks

### Track A: strict 800-word closed-vocabulary sentence recognizer

This is the cleanest benchmark if you want to evaluate an 800-word system honestly.

- Base config anchor: `SLRT/Online/CTC_fusion/configs/csl-daily_s2g.yaml`
- Data rule: keep only samples whose full gloss sequence stays inside the 800-gloss set.
- Public-label exact retained subset size: 9185 train / 360 dev / 400 test.
- Objective: sign-to-gloss sequence recognition.
- Decoder: keep beam search small, beam size 5 is reasonable.
- Why this track: it matches the vocabulary constraint exactly and avoids OOV leakage at evaluation time.

Recommended setup:

- Use the 800-word vocabulary as the decoder vocabulary.
- Keep RGB + keypoint dual-stream input.
- Start from the existing S2G recipe rather than direct text translation.
- Early stop on dev WER because the strict dev set is only 360 samples.

### Track B: 800-word online command or prompt recognizer

This is the practical product track if latency matters more than unconstrained sentence coverage.

- Base config anchors: `SLRT/Online/CSLR/configs/slide_csl-daily.yaml` and `sign2text.app/backend/sign2text-ml/configs/slide_csl-daily_runtime.yaml`
- Objective: window-based or segment-based gloss recognition over the 800-word vocabulary.
- Why this track: it aligns better with live sign interaction than full sentence translation.

Recommended setup:

- Use the top-200 core as the always-on stable layer.
- Add 201-500 as the general daily expansion layer.
- Add 501-800 only after the model stabilizes, because this band is substantially more imbalanced.

### Track C: curriculum pretraining for a later larger model

This is the safest research path if you expect to scale beyond 800.

- Stage 1 learns robust motion primitives on the core glosses.
- Stage 2 adds more combinatorial coverage without immediately exposing the model to the full long tail.
- Stage 3 adds the tail 300 glosses and teaches the model to keep head-class accuracy while broadening coverage.

## Concrete training plan for the 800-word system

### Phase 0: data and vocabulary preparation

- Use `target_glosses_top_800.txt` as the canonical vocabulary file.
- Use `top_800_vocab.csv` to compute sampling weights from `train_token_count`.
- Prefer a strict `match-mode all` subset for benchmark training.
- Keep a second exploratory `match-mode any` subset only for analysis or weak supervision, not for final closed-vocabulary evaluation.

Note:

- The workspace already contains a subset builder at `build_csl_daily_subset.py`.
- In the default workspace Python, building from the local `csl-daily.train/dev/test` pickles currently fails because those pickles reference `torch` during unpickling.
- Run that builder inside the same Python environment as SLRT, with `torch` installed, when materializing the final training subset.

### Phase 1: core stabilization on the top 200 glosses

Goal: lock in the highest-frequency signs and stabilize the shared visual encoder.

- Vocabulary: `target_glosses_top_200_core.txt`
- Epochs: 8 to 12
- Learning rate: start close to the existing recipe, but reduce aggressive updates once validation stops improving
- Freezing policy: keep the lowest visual block partially frozen at the start if training is unstable
- Sampling: balanced or square-root reweighted sampling is enough here

Success criterion:

- head-class confusion decreases quickly
- dev loss stabilizes without overfitting in the first few epochs

### Phase 2: expand to 500 glosses

Goal: add common daily composition without immediately exposing the entire tail.

- Vocabulary: top 500 glosses
- Initialization: load the Phase 1 checkpoint
- Epochs: 12 to 20
- Learning rate: about one third to one half of Phase 1
- Sampling: class-balanced sampling becomes important here

Success criterion:

- token-level recall improves on medium-frequency glosses
- head 200 accuracy does not collapse when the extra 300 glosses are introduced

### Phase 3: full 800-gloss fine-tuning

Goal: reach the practical operating point with the full 800-word vocabulary.

- Vocabulary: `target_glosses_top_800.txt`
- Initialization: load the Phase 2 checkpoint
- Epochs: 15 to 25
- Learning rate: lower again for consolidation
- Decoder: keep constrained decoding over the 800-word vocabulary

Critical details:

- The tail 300 glosses are much rarer, so do not train with naive uniform sentence sampling.
- Use frequency-aware loss weights, for example inverse-square-root or effective-number weighting.
- Mix batches so that each epoch still contains a non-trivial share of tail examples.
- Track both macro gloss accuracy and WER, not only aggregate loss.

### Phase 4: optional product fine-tuning

Goal: adapt the 800-word model to the real usage surface.

- If the target app is guided interaction, fine-tune on scenario-specific prompts.
- If the target app is online recognition, fine-tune with shorter temporal windows and latency-aware decoding.
- If the target app is triage or service dialog, bias sampling toward the required domains instead of trying to keep the whole 800 set perfectly uniform.

## Losses, sampling, and evaluation recommendations

### Loss

- For sequence gloss recognition, stay with a CTC-oriented S2G objective first.
- For window-based online recognition, use closed-vocabulary classification.
- Do not start with direct sign-to-text generation as the primary objective for this 800-word setup.

### Sampling

- Split monitoring by three bands: 1-200, 201-500, 501-800.
- Use a weighted sampler so the tail 300 glosses appear more often than raw frequency would allow.
- Keep an eye on false positives from head glosses overwhelming tail glosses.

### Metrics

- Closed-vocabulary sequence track: WER, gloss accuracy, macro gloss recall.
- Online classification track: top-1 accuracy, top-5 accuracy, per-band recall.
- Product track: intent success rate or prompt-family accuracy, not just token accuracy.

## What not to do

- Do not report results on the full original dev/test splits as if the task were still closed-vocabulary; use the strict retained subset for honest evaluation.
- Do not jump directly from 200 to 800 with uniform sampling if the model is unstable; the tail imbalance is large enough to slow convergence.
- Do not treat this 800-word system as a full open-vocabulary translation model; it is better framed as a constrained recognizer or a curriculum stage.

## Default recommendation

If the goal is a practical first deployable model, use this recipe:

1. Train a strict 800-word S2G recognizer with curriculum `200 -> 500 -> 800`.
2. Keep RGB + keypoint fusion from the existing SLRT recipe.
3. Evaluate only on the strict retained 800-word dev/test subsets.
4. If downstream text output is needed, map recognized glosses to templated text or add a lightweight second-stage text module.