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
export SLRT_CSLR_CHECKPOINT="${SLRT_CSLR_CHECKPOINT:-$WORKSPACE_ROOT/models/checkpoints/online_slrt/cslr_best.ckpt}"
export SIGN2TEXT_ENABLE_SLT="${SIGN2TEXT_ENABLE_SLT:-0}"
PORT="${PORT:-6006}"

cd "$SCRIPT_DIR"
python -m uvicorn app.server:app --host 0.0.0.0 --port "${PORT}"