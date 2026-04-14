---
name: ghost-coach-conventions
description: "Project conventions for Ghost Coach. Activates for ALL code in this workspace. Defines architecture, naming, API format, and constraints for Python backend + Flutter frontend."
---

# Ghost Coach Project Conventions

## Architecture
- Backend: Python 3.11+ / FastAPI / PyTorch at backend/
- Frontend: Flutter/Dart at ghost_coach_app/
- ML Model: V-JEPA 2 ViT-L (300M params) via torch.hub

## Hardware Constraint
- GTX 1660 Ti: 6GB VRAM, Turing architecture
- ALWAYS use FP16 (torch.float16), never FP32 for model inference
- ALWAYS use torch.inference_mode(), never torch.no_grad()
- Max batch size: 1. Max frames: 16. Resolution: 224x224
- Call torch.cuda.empty_cache() after every inference

## Python Backend Rules (UNCHANGED from Phase 1-2)
- Pydantic v2 syntax ONLY (BaseModel, model_validator, SettingsConfigDict)
- NEVER use deprecated: @validator, @root_validator, schema_extra, orm_mode
- FastAPI lifespan context manager, NEVER @app.on_event
- Type hints on ALL functions. Docstrings on ALL public methods.
- logging module. NEVER print(). f-strings. pathlib.Path.

## Flutter/Dart Rules
- Architecture: Clean Architecture with feature-first directory structure
- State management: Riverpod (riverpod + flutter_riverpod + riverpod_annotation)
- Routing: GoRouter (go_router package)
- HTTP: Dio package with interceptors (NOT http package)
- JSON: freezed + json_serializable for immutable data classes
- Local storage: drift (SQLite) for analysis history
- Video player: video_player or chewie package
- Image loading: cached_network_image
- Theming: Material3 with dark gaming theme
- Null safety: strict, no dynamic types, no force unwrapping
- Use const constructors wherever possible
- Separate presentation, domain, and data layers
- File naming: snake_case for files, PascalCase for classes
- Tests: flutter_test + mocktail for mocking

## API Integration
- Backend URL: configurable, default http://10.0.2.2:8000 (Android emulator) or http://localhost:8000
- All API responses follow: {"status": str, "analysis_id": str, ...}
- Endpoints: POST /api/v1/analyze, GET /api/v1/analysis/{id}, GET /api/v1/health

## Do not use
- GetX (too magical, hard to test)
- Provider (use Riverpod instead)
- http package (use Dio)
- Gson or manual JSON parsing (use freezed)
- print() in backend (use logging)
- FP32 for model inference
