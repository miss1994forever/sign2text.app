#!/usr/bin/env bash

set -euo pipefail

source /root/miniconda3/etc/profile.d/conda.sh
conda activate slrt_legacy
export OMP_NUM_THREADS=1
export SLRT_DATASET_PRESET="${SLRT_DATASET_PRESET:-csl-daily}"
export SLRT_CSLR_CHECKPOINT="${SLRT_CSLR_CHECKPOINT:-/root/autodl-tmp/models/checkpoints/online_slrt/cslr_best.ckpt}"
export SIGN2TEXT_ENABLE_SLT="${SIGN2TEXT_ENABLE_SLT:-0}"
PORT="${PORT:-6006}"

cd /root/autodl-tmp/sign2text.app/backend/sign2text-ml
python -m uvicorn app.server:app --host 0.0.0.0 --port "${PORT}"