"""Ghost Coach FastAPI Application."""

import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import video, health
from app.core.config import get_settings
from app.core.vjepa_engine import VJEPAEngine

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize V-JEPA 2 engine on startup, cleanup on shutdown."""
    settings = get_settings()
    logger.info(f"Starting {settings.APP_NAME}...")
    
    engine = VJEPAEngine(
        model_name=settings.VJEPA_MODEL_NAME,
        device=settings.DEVICE,
    )
    
    try:
        engine.load_model()
        app.state.vjepa_engine = engine
        logger.info("V-JEPA 2 engine loaded successfully.")
    except Exception as e:
        logger.error(f"Failed to load V-JEPA 2 engine: {e}")
        app.state.vjepa_engine = None
    
    yield
    
    logger.info("Shutting down Ghost Coach...")

app = FastAPI(
    title="Ghost Coach API",
    description="AI-powered gameplay video analysis",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    duration = round((time.perf_counter() - start) * 1000, 2)
    logger.info(f"{request.method} {request.url.path} → {response.status_code} ({duration}ms)")
    return response

app.include_router(health.router)
app.include_router(video.router)
