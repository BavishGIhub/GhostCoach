#!/bin/bash
set -e
cd backend
source .venv/bin/activate 2>/dev/null || source .venv/Scripts/activate 2>/dev/null
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
export CUDA_LAUNCH_BLOCKING=0
echo "🚀 Starting Ghost Coach API server..."
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1 --log-level info