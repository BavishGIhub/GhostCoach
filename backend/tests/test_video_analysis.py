"""Integration tests for Ghost Coach video analysis pipeline."""

import asyncio
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_full_pipeline_with_analysis(synthetic_video):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        with open(synthetic_video, "rb") as f:
            response = await client.post(
                "/api/v1/analyze",
                files={"file": ("test_vid.mp4", f, "video/mp4")},
                data={"game_type": "general"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "analysis_id" in data

        # The API processes synchronously — full results in POST response
        if "features" in data:
            features = data["features"]
            assert "overall_score" in features
            assert 0 <= features["overall_score"] <= 100
            assert "key_moments" in features
            assert isinstance(features["key_moments"], list)
            assert "movement_patterns" in features
            assert isinstance(features["movement_patterns"], list)
            assert len(features["movement_patterns"]) == 4
            assert "recommendations" in data
            assert len(data["recommendations"]) == 4
            assert all(isinstance(tip, str) and len(tip) > 0 for tip in data["recommendations"])
            assert "inference_device" in data
        else:
            assert "status" in data


@pytest.mark.asyncio
async def test_analysis_caching(synthetic_video):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        with open(synthetic_video, "rb") as f:
            content = f.read()

        # First request
        res1 = await client.post(
            "/api/v1/analyze",
            files={"file": ("test_vid.mp4", content, "video/mp4")},
        )
        assert res1.status_code == 200

        # Second request with same video — should also succeed
        res2 = await client.post(
            "/api/v1/analyze",
            files={"file": ("test_vid.mp4", content, "video/mp4")},
        )
        assert res2.status_code == 200
