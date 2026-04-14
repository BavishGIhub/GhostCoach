import logging

import torch
from fastapi import APIRouter, Request

from app.models.schemas import HealthResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["health"])

@router.get("/health", response_model=HealthResponse)
async def get_health(request: Request) -> HealthResponse:
    """Check the health status of the API and the V-JEPA 2 model."""
    engine = getattr(request.app.state, "vjepa_engine", None)
    
    if engine is None:
        return HealthResponse(
            status="starting",
            model_loaded=False,
            device="unknown",
            gpu_memory_used_mb=None,
            gpu_memory_total_mb=None
        )
        
    try:
        health_data = engine.get_health()
        status = "healthy" if health_data.get("model_loaded") else "loading"
        return HealthResponse(status=status, **health_data)
    except Exception as e:
        logger.error(f"Error fetching health via engine: {e}")
        # Graceful fallback if checking health fails
        return HealthResponse(
            status="error",
            model_loaded=False,
            device="unknown",
            gpu_memory_used_mb=None,
            gpu_memory_total_mb=None
        )
