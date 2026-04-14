"""Pydantic v2 schemas for API request/response models."""

from pydantic import BaseModel, Field
from typing import Optional


class VideoUploadResponse(BaseModel):
    status: str
    analysis_id: str
    message: str


class KeyMoment(BaseModel):
    timestamp: float
    moment_type: str
    confidence: float = Field(ge=0, le=1)
    description: str


class MovementPattern(BaseModel):
    pattern_name: str
    score: float = Field(ge=0, le=100)
    description: str


class AnalysisFeatures(BaseModel):
    embedding_shape: list[int]
    key_moments: list[KeyMoment]
    movement_patterns: list[MovementPattern]
    overall_score: float = Field(ge=0, le=100)


class AnalysisResult(BaseModel):
    status: str
    analysis_id: str
    processing_time_seconds: float
    features: AnalysisFeatures
    recommendations: list[str]
    inference_device: str
    timestamp: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    device: str
    gpu_memory_used_mb: Optional[float] = None
    gpu_memory_total_mb: Optional[float] = None


class ErrorResponse(BaseModel):
    status: str = "error"
    message: str
    detail: Optional[str] = None