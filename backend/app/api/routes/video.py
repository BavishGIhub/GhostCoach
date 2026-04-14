import asyncio
import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, File, HTTPException, Query, Request, UploadFile
from fastapi.responses import JSONResponse

from app.core.config import get_settings
import numpy as np

from app.core.vjepa_engine import VJEPAEngine
from app.models.schemas import AnalysisFeatures, AnalysisResult, ErrorResponse, KeyMoment, MovementPattern, VideoUploadResponse
from app.services.analysis import GameplayAnalyzer
from app.services.video_processor import VideoProcessor

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["analysis"])
_analysis_cache: dict[str, dict] = {}
_gpu_semaphore = asyncio.Semaphore(1)


def _get_engine(request: Request) -> VJEPAEngine:
    engine = getattr(request.app.state, "vjepa_engine", None)
    if engine is None or not getattr(engine, "is_loaded", False):
        raise HTTPException(status_code=503, detail="V-JEPA 2 model is not loaded yet.")
    return engine


@router.post(
    "/analyze",
    response_model=VideoUploadResponse,
    responses={
        400: {"model": ErrorResponse},
        413: {"model": ErrorResponse},
        503: {"model": ErrorResponse},
    },
)
async def analyze_video(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    game_type: Optional[str] = Query(None),
    num_frames: int = Query(16, ge=4, le=32),
):
    """Upload a gameplay video and enqueue it for background analysis via V-JEPA 2."""
    settings = get_settings()
    engine = _get_engine(request)

    content = await file.read()
    max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024

    if len(content) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"File size exceeds maximum allowed size of {settings.MAX_FILE_SIZE_MB}MB.",
        )

    # Save temp processing copy
    try:
        path = VideoProcessor.save_upload(
            content, settings.UPLOAD_DIR, file.filename or "video.mp4"
        )
    except Exception as e:
        logger.error(f"Failed to save upload: {e}")
        raise HTTPException(status_code=500, detail="Failed to save video to disk.")

    # Validate the uploaded video structure and metadata
    validation_result = VideoProcessor.validate_video(
        path, settings.MAX_VIDEO_DURATION_SECONDS, settings.MAX_FILE_SIZE_MB
    )

    if not validation_result.get("is_valid", False):
        VideoProcessor.cleanup(path)
        raise HTTPException(
            status_code=400,
            detail=validation_result.get("error", "Unknown validation error."),
        )

    analysis_id = str(uuid4())
    _analysis_cache[analysis_id] = {"status": "processing", "analysis_id": analysis_id}

    background_tasks.add_task(
        _run_analysis, analysis_id, path, engine, num_frames, game_type
    )

    return VideoUploadResponse(
        status="processing",
        analysis_id=analysis_id,
        message="Analysis queued. Poll GET /api/v1/analysis/{id} for results.",
    )


async def _run_analysis(
    analysis_id: str,
    video_path: str,
    engine: VJEPAEngine,
    num_frames: int,
    game_type: Optional[str],
):
    """Background task to extract features with V-JEPA 2 and perform placeholder analysis."""
    async with _gpu_semaphore:
        loop = asyncio.get_event_loop()
        try:
            # Block the background executor to run the PyTorch forward pass cleanly
            res = await loop.run_in_executor(None, engine.analyze, video_path)

            embeddings = np.array(res["embeddings_numpy"])
            video_duration = res["video_metadata"]["duration"]
            
            settings = get_settings()
            analyzer = GameplayAnalyzer(gemini_api_key=settings.GEMINI_API_KEY)
            
            analysis = analyzer.full_analysis(embeddings, video_duration, game_type or "general")
            
            features = AnalysisFeatures(
                embedding_shape=res["embedding_shape"],
                key_moments=[KeyMoment(**m) for m in analysis["key_moments"]],
                movement_patterns=[MovementPattern(**p) for p in analysis["movement_patterns"]],
                overall_score=analysis["overall_score"]
            )
            
            analysis_result = AnalysisResult(
                status="completed",
                analysis_id=analysis_id,
                processing_time_seconds=res["processing_time_seconds"],
                features=features,
                recommendations=analysis["recommendations"],
                inference_device=res["inference_device"],
                timestamp=res["timestamp"]
            )

            _analysis_cache[analysis_id] = analysis_result.model_dump()

        except Exception as e:
            logger.exception(f"Error during background analysis for {analysis_id}")
            _analysis_cache[analysis_id] = {
                "status": "error",
                "message": str(e),
                "analysis_id": analysis_id,
            }
        finally:
            VideoProcessor.cleanup(video_path)


@router.get(
    "/analysis/{analysis_id}",
    response_model=AnalysisResult,
    responses={
        202: {"description": "Still processing"},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def get_analysis(analysis_id: str):
    """Retrieve an analysis result by ID from the cache."""
    if analysis_id not in _analysis_cache:
        raise HTTPException(status_code=404, detail="Analysis ID not found.")

    entry = _analysis_cache[analysis_id]

    status = entry.get("status")
    if status == "processing":
        return JSONResponse(
            status_code=202,
            content={
                "status": "processing",
                "analysis_id": analysis_id,
                "message": "Still processing. Retry shortly.",
            },
        )

    if status == "error":
        raise HTTPException(
            status_code=500, detail=entry.get("message", "Unknown error during analysis.")
        )

    return AnalysisResult.model_validate(entry)
