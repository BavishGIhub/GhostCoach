#!/bin/bash
set -e
echo "🚀 Setting up Ghost Coach backend..."
cd backend
python -m venv .venv
source .venv/bin/activate || .venv\Scripts\activate
pip install --upgrade pip
pip install -r requirements.txt
if [ ! -f .env ]; then
    cp .env.example .env
    echo "📝 Created .env from .env.example — edit it with your settings"
fi
echo "✅ Setup complete! Run: uvicorn app.main:app --host 0.0.0.0 --port 8000"