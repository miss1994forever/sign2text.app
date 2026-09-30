#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source /opt/miniconda3/etc/profile.d/conda.sh
conda activate slrt_legacy
export OMP_NUM_THREADS=1
export WORKSPACE_ROOT
export SLRT_ROOT="${SLRT_ROOT:-$WORKSPACE_ROOT/SLRT}"
export SLRT_CSLR_ROOT="${SLRT_CSLR_ROOT:-$SLRT_ROOT/Online/CSLR}"
export SLRT_SLT_ROOT="${SLRT_SLT_ROOT:-$SLRT_ROOT/Online/SLT}"
export SLRT_DATASET_PRESET="${SLRT_DATASET_PRESET:-csl-daily}"

if [[ -z "${SLRT_CSLR_CHECKPOINT:-}" ]]; then
  if [[ "$SLRT_DATASET_PRESET" == "phoenix" ]]; then
    export SLRT_CSLR_CHECKPOINT="$WORKSPACE_ROOT/models/checkpoints/online_slrt/phoenix_2014t_islr_best.ckpt"
  else
    export SLRT_CSLR_CHECKPOINT="$WORKSPACE_ROOT/models/checkpoints/online_slrt/csl_daily_cslr_best.ckpt"
  fi
fi

if [[ -z "${SLRT_SLT_CHECKPOINT:-}" ]]; then
  if [[ "$SLRT_DATASET_PRESET" == "phoenix" ]]; then
    export SLRT_SLT_CHECKPOINT="$SLRT_SLT_ROOT/results/g2t_wait2/ckpts/best.ckpt"
  else
    csl_g2t_candidates=(
      "$SLRT_SLT_ROOT/results/g2t_wait2_csl_retrain_k2_20260920/ckpts/csl_best.ckpt"
      "$WORKSPACE_ROOT/models/checkpoints/online_slrt/csl_daily_g2t_best.ckpt"
      "$WORKSPACE_ROOT/models/checkpoints/online_slrt/csl_daily_g2t.ckpt"
      "$SLRT_SLT_ROOT/results/g2t_wait2_csl/ckpts/best.ckpt"
      "$SLRT_SLT_ROOT/results/g2t_wait2_csl/ckpts/step_1000.ckpt"
      "$SLRT_SLT_ROOT/results/csl-daily_g2t/ckpts/step_1000.ckpt"
      "$SLRT_SLT_ROOT/results/g2t_wait2_csl_top800_smoke_debug/ckpts/csl_best.ckpt"
    )
    for candidate in "${csl_g2t_candidates[@]}"; do
      if [[ -f "$candidate" ]]; then
        export SLRT_SLT_CHECKPOINT="$candidate"
        break
      fi
    done
  fi
fi

if [[ -z "${SLRT_SLT_CONFIG:-}" && "$SLRT_DATASET_PRESET" == "csl-daily" && \
      "${SLRT_SLT_CHECKPOINT:-}" == *g2t_wait2_csl_retrain_k2_20260920* ]]; then
  export SLRT_SLT_CONFIG="$SLRT_SLT_ROOT/configs/g2t_wait2_csl_retrain_k2_20260920.yaml"
fi

if [[ -z "${SIGN2TEXT_ENABLE_SLT:-}" ]]; then
  if [[ "$SLRT_DATASET_PRESET" == "phoenix" ]]; then
    export SIGN2TEXT_ENABLE_SLT=1
  elif [[ -n "${SLRT_SLT_CHECKPOINT:-}" && "$SLRT_SLT_CHECKPOINT" != *smoke* ]]; then
    export SIGN2TEXT_ENABLE_SLT=1
  else
    export SIGN2TEXT_ENABLE_SLT=0
  fi
fi
PORT="${PORT:-6006}"

cd "$SCRIPT_DIR"
python -m uvicorn app.server:app --host 0.0.0.0 --port "${PORT}"
