import pytest
import pytest_asyncio
import numpy as np
from unittest.mock import MagicMock, AsyncMock
from uuid import uuid4
from datetime import datetime, timezone
from httpx import ASGITransport, AsyncClient

from app.main import app

@pytest.fixture(autouse=True)
def mock_vjepa_engine():
    """Inject a mock VJEPAEngine into app.state for all tests."""
    mock_engine = MagicMock()
    mock_engine.is_loaded = True
    mock_engine.get_health.return_value = {
        "model_loaded": True,
        "device": "cpu",
        "model_name": "vjepa2_vit_large_mock",
    }
    
    fake_embeddings = np.random.randn(16, 768).tolist()
    mock_engine.analyze.return_value = {
        "analysis_id": str(uuid4()),
        "embedding_shape": [1, 16, 768],
        "embeddings_numpy": fake_embeddings,
        "processing_time_seconds": 1.23,
        "inference_device": "cpu",
        "num_frames_processed": 16,
        "video_metadata": {
            "duration": 3.0,
            "fps": 30.0,
            "total_frames": 90,
            "frames_sampled": 16,
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    
    app.state.vjepa_engine = mock_engine
    yield mock_engine
    app.state.vjepa_engine = None
import tempfile
from pathlib import Path
import cv2
import numpy as np

@pytest.fixture
def synthetic_video():
    """Generate a synthetic 3-second test video."""
    path = Path(tempfile.gettempdir()) / "test_pipeline_vid.mp4"
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(path), fourcc, 30.0, (320, 240))
    for i in range(90):
        frame = np.zeros((240, 320, 3), dtype=np.uint8)
        x = int((i / 90) * 280)
        cv2.rectangle(frame, (x, 80), (x + 40, 160), (0, 255, 0), -1)
        writer.write(frame)
    writer.release()
    yield str(path)
    if path.exists():
        path.unlink()
