#!/usr/bin/env bash

set -euo pipefail

source /root/miniconda3/etc/profile.d/conda.sh
conda activate slrt_legacy
export OMP_NUM_THREADS=1

cd /root/autodl-tmp/sign2text.app/backend/sign2text-ml
python -m uvicorn app.server:app --host 0.0.0.0 --port 8000