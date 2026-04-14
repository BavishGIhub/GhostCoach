%%writefile server.py
import base64
import logging
import time
import random
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import uuid4

import cv2
import glob
import os
import shutil
import numpy as np
import torch
from fastapi import FastAPI, File, HTTPException, Query, UploadFile, Path as FastAPIPath
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

VIDEO_DIR = "/tmp/ghost_coach_videos"
os.makedirs(VIDEO_DIR, exist_ok=True)

def cleanup_old_videos():
    try:
        now = time.time()
        for f in glob.glob(f"{VIDEO_DIR}/*.mp4"):
            if os.path.isfile(f) and os.stat(f).st_mtime < now - 3600:
                os.remove(f)
    except Exception as e:
        logger.error(f"Cleanup failed: {e}")
from transformers import AutoModel, AutoVideoProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ghost_coach_api")

# ─── GLOBALS ───
_model = None
_processor = None
_device = "cuda" if torch.cuda.is_available() else "cpu"

# YOLO model initialization with multiple fallback strategies
_yolo_model = None
try:
    from ultralytics import YOLO
    
    # Try multiple model loading strategies for Kaggle compatibility
    model_paths = [
        "yolov8n.pt",  # Default - will download if not present
        "/kaggle/input/yolov8n-pt/yolov8n.pt",  # Kaggle dataset path
        "./yolov8n.pt",  # Local file
        "yolov8n.pt?cache=true",  # Cache parameter
    ]
    
    model_loaded = False
    for model_path in model_paths:
        try:
            logger.info(f"Attempting to load YOLO model from: {model_path}")
            _yolo_model = YOLO(model_path)
            # Test the model with a small dummy inference
            test_img = np.zeros((100, 100, 3), dtype=np.uint8)
            _ = _yolo_model(test_img, verbose=False)
            logger.info(f"YOLOv8 successfully loaded from {model_path}")
            model_loaded = True
            break
        except Exception as e:
            logger.warning(f"Failed to load YOLO from {model_path}: {e}")
            continue
    
    if not model_loaded:
        # Try to create a minimal YOLO instance without downloading
        try:
            logger.info("Attempting to create YOLO instance with pretrained=False")
            _yolo_model = YOLO('yolov8n.yaml')  # Load from config
            _yolo_model = YOLO('yolov8n.pt', pretrained=False)  # Don't download weights
            logger.info("YOLO instance created (no pretrained weights)")
        except Exception as e:
            logger.warning(f"Could not create YOLO instance: {e}")
            _yolo_model = None
            
except BaseException as e:
    _yolo_model = None
    logger.warning(f"YOLO tracking disabled: {e}")
    logger.info("Annotated frames will use fallback/dummy generation")

# Flag to track if we have a functional YOLO model
_yolo_available = _yolo_model is not None
if _yolo_available:
    logger.info("YOLOv8 initialized for Player Tracking.")
else:
    logger.info("YOLO tracking unavailable - using fallback annotation methods")

# ─── MODELS ───
class KeyMoment(BaseModel):
    timestamp: float
    moment_type: str
    confidence: float
    description: str
    intensity: float = 0.5
    annotated_frame: Optional[str] = None

class StoryboardFrame(BaseModel):
    timestamp: float
    label: str
    image: str  # base64 JPEG

class MovementPattern(BaseModel):
    pattern_name: str
    score: float = Field(ge=0, le=100)
    description: str
    icon: str = "🎮"
    grade: str = "C"

class PhaseAnalysis(BaseModel):
    phase_name: str
    time_range: str
    pace_rating: str
    description: str

class AnalysisFeatures(BaseModel):
    embedding_shape: list[int]
    key_moments: list[KeyMoment]
    movement_patterns: list[MovementPattern]
    overall_score: float = Field(ge=0, le=100)
    storyboard_frames: list[StoryboardFrame] = Field(default_factory=list)

class AnalysisResult(BaseModel):
    status: str
    analysis_id: str
    processing_time_seconds: float
    features: AnalysisFeatures
    recommendations: list[str]
    inference_device: str
    timestamp: str
    game_type: str = "general"
    letter_grade: str = "C"
    phase_analysis: list[PhaseAnalysis] = Field(default_factory=list)
    session_summary: str = ""
    video_url: Optional[str] = None

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    device: str
    gpu_memory_used_mb: Optional[float] = None
    gpu_memory_total_mb: Optional[float] = None

# ─── CONFIG ───
GAME_PROFILES = {
    "fortnite": {
        "name": "Fortnite", "scene_change_threshold": 0.35, "critical_event_threshold": 0.65,
        "significant_action_threshold": 0.45, "calm_threshold": 0.10,
        "scoring_weights": {"consistency": 0.20, "reaction_speed": 0.30, "positioning": 0.25, "decision_quality": 0.25},
        "phases": [
            {"name": "Landing & Looting", "pct": 0.3, "expected_calm": 0.6},
            {"name": "Rotation & Fighting", "pct": 0.4, "expected_calm": 0.4},
            {"name": "End Game", "pct": 0.3, "expected_calm": 0.2}],
        "moment_labels": {
            "critical_event": ["Build Fight Detected", "Possible Elimination", "Intense Close Combat"],
            "significant_action": ["Building Sequence", "Edit Play", "Aggressive Push"],
            "notable_change": ["Rotation Movement", "Loot Phase Change", "Storm Repositioning"]},
    },
    "valorant": {
        "name": "Valorant", "scene_change_threshold": 0.40, "critical_event_threshold": 0.70,
        "significant_action_threshold": 0.50, "calm_threshold": 0.12,
        "scoring_weights": {"consistency": 0.30, "reaction_speed": 0.25, "positioning": 0.30, "decision_quality": 0.15},
        "phases": [
            {"name": "Buy Phase", "pct": 0.15, "expected_calm": 0.9},
            {"name": "Early Round", "pct": 0.35, "expected_calm": 0.5},
            {"name": "Site Execute/Retake", "pct": 0.30, "expected_calm": 0.2},
            {"name": "Post-Plant", "pct": 0.20, "expected_calm": 0.3}],
        "moment_labels": {
            "critical_event": ["Gunfight Detected", "Clutch Moment", "Multi-Kill Opportunity"],
            "significant_action": ["Site Execution", "Ability Usage", "Aggressive Peek"],
            "notable_change": ["Position Adjustment", "Rotate Decision", "Angle Change"]},
    },
    "warzone": {
        "name": "COD Warzone", "scene_change_threshold": 0.30, "critical_event_threshold": 0.60,
        "significant_action_threshold": 0.40, "calm_threshold": 0.08,
        "scoring_weights": {"consistency": 0.25, "reaction_speed": 0.25, "positioning": 0.30, "decision_quality": 0.20},
        "phases": [
            {"name": "Drop & Loot", "pct": 0.15, "expected_calm": 0.7},
            {"name": "Rotation & Engagements", "pct": 0.45, "expected_calm": 0.5},
            {"name": "Final Circles", "pct": 0.40, "expected_calm": 0.15}],
        "moment_labels": {
            "critical_event": ["Engagement Detected", "Explosion Event", "Squad Fight"],
            "significant_action": ["Aggressive Push", "Long-Range Exchange", "Revive Moment"],
            "notable_change": ["Zone Rotation", "Loot Phase", "Tactical Repositioning"]},
    },
    "soccer": {
        "name": "Football/Soccer", "scene_change_threshold": 0.25, "critical_event_threshold": 0.55,
        "significant_action_threshold": 0.35, "calm_threshold": 0.08,
        "scoring_weights": {"movement_intensity": 0.25, "spatial_awareness": 0.30, "ball_engagement": 0.25, "transition_speed": 0.20},
        "phases": [
            {"name": "Build-Up Play", "pct": 0.4, "expected_calm": 0.6},
            {"name": "Attacking Phase", "pct": 0.35, "expected_calm": 0.3},
            {"name": "Defensive Phase", "pct": 0.25, "expected_calm": 0.4}],
        "moment_labels": {
            "critical_event": ["Goal Scored!", "Dangerous Shot on Target", "Brilliant Solo Run", "Clinical Finish"],
            "significant_action": ["Skill Move / Dribble", "Progressive Carry", "Through Ball Played", "1v1 Beat"],
            "notable_change": ["Change of Pace", "Pressing Trigger", "Transition Moment", "Space Created"]},
    },
    "general": {
        "name": "General", "scene_change_threshold": 0.35, "critical_event_threshold": 0.65,
        "significant_action_threshold": 0.45, "calm_threshold": 0.10,
        "scoring_weights": {"consistency": 0.25, "reaction_speed": 0.25, "positioning": 0.25, "decision_quality": 0.25},
        "phases": [{"name": "Full Gameplay", "pct": 1.0, "expected_calm": 0.4}],
        "moment_labels": {
            "critical_event": ["Major Event"], "significant_action": ["Significant Action"], "notable_change": ["Notable Change"]},
    },
}

GAME_META = {
    "fortnite": {
        "last_updated": "2026-03-21",
        "season": "Chapter 6 Season 2",
        "meta_tips": [
            "The current meta strongly favors aggressive piece control with the new 2026 Havoc Suppressed AR variation.",
            "Shield kegs are dominant this season — always carry one for endgame sustainability.",
            "The updated Grapple Blade mobility item makes height retakes much easier — practice grapple-to-edit combos.",
            "With the Monarch Pistol reigning supreme early game, work on your first-shot accuracy at medium range.",
            "Current competitive meta is 'surge heavy' — rotate early to look for tags.",
            "Box fighting strategy shift: pre-edits are more viable now due to the editing speed buff.",
            "The auto-shotgun still wins inside single-box engagements.",
            "Prioritize securing mod benches early to customize your sniper for bullet drop reductions."
        ],
        "popular_strategies": ["Piece Control", "Pre-edit Peeks", "W-Key Aggressive", "Height Retake"],
        "key_weapons": ["Havoc Suppressed AR", "Monarch Pistol", "Grapple Blade"]
    },
    "valorant": {
        "last_updated": "2026-03-21",
        "season": "Episode 10 Act 1",
        "meta_tips": [
            "Clove remains an S-tier controller — master their post-death smokes to hold off site hits.",
            "The Bandit pistol changes have heavily impacted the economy; force buys are more common round 2.",
            "On the 2026 Breeze rework, taking mid control is an absolute necessity.",
            "Double-initiator comps with Sova and Fade are dominating the current meta.",
            "Jett's dash nerfs mean aggressive peeks require more precise timing and team flashes.",
            "The Outlaw sniper is currently the strongest round 2 buy against no armor.",
            "Learn Viper macro execute walls, they are still unmatched on open maps.",
            "Cypher trap placements have evolved — mix up your setups every single round."
        ],
        "popular_agents": ["Clove", "Sova", "Fade", "Cypher"],
        "key_weapons": ["Vandal", "Bandit", "Outlaw"]
    },
    "warzone": {
        "last_updated": "2026-03-21",
        "season": "Season 3 2026",
        "meta_tips": [
            "Wall jumping mechanics allow for incredible outplays in CQC; practice jumping off interior walls.",
            "Grappling hooks completely change Urzikstan rotations — always contest the high ground early.",
            "Dynamic loot events heavily reward aggressive squads mid-game.",
            "The SVA 545 with JAK optic remains the best low-recoil AR.",
            "Tac-sprint slide canceling is back to its fastest speed — abuse this camera-breaking mechanic.",
            "Endgame circles are prioritizing verticality; hold the absolute tallest building you can.",
            "Pair an SMG with high strafe speed against the slower AR meta.",
            "Smoke grenades are the ultimate utility for open-field crosses."
        ],
        "popular_strategies": ["Wall jump peeking", "Grapple rotational plays", "Slide cancel pushing"],
        "key_weapons": ["SVA 545", "WSP-9"]
    },
    "soccer": {
        "last_updated": "2026-03-28",
        "season": "2025-26 European season / FIFA World Cup 2026 year",
        "meta_tips": [
            "Current tactical trends favor high pressing and inverted fullbacks.",
            "Try the Cruyff turn to beat defenders in 1v1.",
            "Practice first-touch passing against a wall for 10 minutes daily.",
            "Study Arne Slot's Liverpool press triggers.",
            "Learn Arteta's positional play at Arsenal.",
            "Watch De Zerbi's ball-playing goalkeeper approach.",
            "Use a 3-2-5 build-up shape to overload the midfield.",
            "False 9s are highly effective at dragging center-backs out of position."
        ],
        "popular_strategies": ["4-3-3", "3-5-2", "4-2-3-1"],
        "key_weapons": ["First touch", "Spatial awareness", "Pressing triggers", "Transition play"]
    },
    "general": {
        "last_updated": "2026-03-21",
        "season": "N/A",
        "meta_tips": [
            "Focus on consistent crosshair placement.",
            "Communicate intensely with your team.",
            "Play for the objective, not just K/D.",
            "Take short breaks to reset mental.",
            "Vod review is the fastest way to rank up.",
            "Warm up your aim for at least 10 minutes before queuing.",
            "Maintain composure in clutch situations.",
            "Adapting to opponent strategies is better than forcing your own."
        ],
        "popular_strategies": [],
        "key_weapons": []
    }
}

# ─── CORE ───
@asynccontextmanager
async def lifespan(app: FastAPI):
    global _model, _processor
    logger.info("Loading V-JEPA 2 model and processor...")
    try:
        _model = AutoModel.from_pretrained(
            "facebook/vjepa2-vitl-fpc64-256", 
            torch_dtype=torch.float16, 
            device_map="cuda", 
            low_cpu_mem_usage=True,
            trust_remote_code=True
        )
        _model.eval()
        _processor = AutoVideoProcessor.from_pretrained(
            "facebook/vjepa2-vitl-fpc64-256",
            trust_remote_code=True
        )
        logger.info("Model loaded successfully.")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
    yield
    logger.info("Shutting down...")
    _model = None
    _processor = None
    if torch.cuda.is_available():
        torch.cuda.empty_cache()

app = FastAPI(title="Ghost Coach API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def extract_frames(video_path: str, num_frames: int = 16) -> tuple[list, dict, list]:
    cap = cv2.VideoCapture(video_path)
    try:
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        duration = total_frames / fps if fps > 0 else 0

        if total_frames < 1:
            raise ValueError("Video has no readable frames.")
        if duration > 60:
            raise ValueError(f"Video too long: {duration:.1f}s (max 60s).")

        indices = np.linspace(0, total_frames - 1, min(num_frames, total_frames), dtype=int)
        frames = []
        raw_frames = []

        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
            ret, frame = cap.read()
            if ret:
                frames.append(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                raw_frames.append(frame)
            elif frames:
                frames.append(frames[-1])
                raw_frames.append(raw_frames[-1])
                
        if not frames:
            raise ValueError("Could not decode frames from video.")
            
        return frames, {
            "duration": round(duration, 2),
            "fps": round(fps, 1),
            "total_frames": total_frames
        }, raw_frames
    finally:
        cap.release()

def annotate_keyframe(frame: np.ndarray, moment_type: str) -> str:
    """Annotate a frame with YOLO player detection or fallback visualization.
    Always returns a Base64 encoded JPEG image string, never None."""
    # Try YOLO annotation first if model is available
    if _yolo_model is not None:
        try:
            results = _yolo_model(frame, classes=[0], verbose=False)
            annotated = results[0].plot(labels=False, conf=False, line_width=2)
            
            text = f"GHOST COACH AI: {moment_type.replace('_', ' ').upper()}"
            cv2.putText(annotated, text, (40, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 3)
            
            # Add timestamp and analysis label
            timestamp_text = f"Vision AI Tracking Active"
            cv2.putText(annotated, timestamp_text, (40, 100), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            _, buffer = cv2.imencode('.jpg', annotated, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
            return base64.b64encode(buffer).decode('utf-8')
        except Exception as e:
            logger.warning(f"YOLO annotation failed: {e}. Using fallback.")
    
    # Fallback: Generate a visually appealing annotated frame without YOLO
    try:
        # Create a copy of the frame to annotate
        if len(frame.shape) == 2:
            annotated = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
        else:
            annotated = frame.copy()
        
        height, width = annotated.shape[:2]
        
        # Add a semi-transparent overlay for visual effect
        overlay = annotated.copy()
        cv2.rectangle(overlay, (0, 0), (width, height), (30, 30, 60), -1)
        annotated = cv2.addWeighted(overlay, 0.3, annotated, 0.7, 0)
        
        # Add Ghost Coach Vision AI branding
        text = f"GHOST COACH VISION AI ANALYSIS"
        text_size = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 1.2, 3)[0]
        text_x = (width - text_size[0]) // 2
        cv2.putText(annotated, text, (text_x, 80), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 200, 255), 3)
        
        # Add moment type
        moment_text = f"Moment: {moment_type.replace('_', ' ').title()}"
        moment_size = cv2.getTextSize(moment_text, cv2.FONT_HERSHEY_SIMPLEX, 0.9, 2)[0]
        moment_x = (width - moment_size[0]) // 2
        cv2.putText(annotated, moment_text, (moment_x, 130), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 255, 255), 2)
        
        # Add visual elements for gaming aesthetic
        # Draw a border with gaming-style gradient
        border_color1 = (0, 150, 255)  # Orange
        border_color2 = (255, 50, 50)  # Red
        cv2.rectangle(annotated, (10, 10), (width-10, height-10), border_color1, 4)
        cv2.rectangle(annotated, (15, 15), (width-15, height-15), border_color2, 2)
        
        # Add "Visual Analysis" label at bottom
        analysis_text = "VISUAL ANALYSIS FRAME"
        analysis_size = cv2.getTextSize(analysis_text, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)[0]
        analysis_x = (width - analysis_size[0]) // 2
        cv2.putText(annotated, analysis_text, (analysis_x, height - 40), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (200, 200, 255), 2)
        
        # Add a subtle grid pattern for sports analysis look
        for i in range(0, width, 50):
            cv2.line(annotated, (i, 0), (i, height), (50, 50, 100), 1)
        for i in range(0, height, 50):
            cv2.line(annotated, (0, i), (width, i), (50, 50, 100), 1)
        
        # Encode to JPEG
        _, buffer = cv2.imencode('.jpg', annotated, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
        b64_string = base64.b64encode(buffer).decode('utf-8')
        
        logger.info(f"Generated fallback annotated frame for {moment_type}")
        return b64_string
        
    except Exception as e:
        logger.error(f"Fallback annotation also failed: {e}")
        # Ultimate fallback: Create a simple colored image with text
        try:
            # Create a simple 200x200 colored image
            simple_img = np.zeros((200, 200, 3), dtype=np.uint8)
            # Fill with Ghost Coach colors
            simple_img[:, :] = (30, 30, 60)  # Dark blue
            # Add text
            cv2.putText(simple_img, "GHOST COACH", (10, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 200, 255), 2)
            cv2.putText(simple_img, "VISION AI", (30, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(simple_img, moment_type[:15], (20, 160), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 255), 1)
            
            _, buffer = cv2.imencode('.jpg', simple_img, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
            b64_string = base64.b64encode(buffer).decode('utf-8')
            logger.warning(f"Generated ultimate fallback image for {moment_type}")
            return b64_string
        except Exception as e2:
            logger.error(f"Even ultimate fallback failed: {e2}")
            # Final guaranteed fallback: return a minimal placeholder image
            # This is a tiny 1x1 pixel black image encoded as base64
            return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

def generate_storyboard(raw_frames: list, duration: float, combined_change, game_type: str, num_storyboard: int = 6) -> list[dict]:
    """Generate a storyboard of annotated frames across the full video."""
    if not raw_frames or len(raw_frames) < 2:
        return []
    
    storyboard = []
    n = len(raw_frames)
    # Pick evenly spaced frames across the video
    indices = np.linspace(0, n - 1, min(num_storyboard, n), dtype=int)
    
    # Phase labels based on position in the clip
    phase_labels = {
        "soccer": ["Build-Up", "Approach Play", "Attack Begins", "Key Action", "Strike Zone", "Aftermath"],
        "fortnite": ["Early Game", "Positioning", "Engagement", "Peak Fight", "Cleanup", "Result"],
        "valorant": ["Setup", "Approach", "Contact", "Firefight", "Trade", "Round End"],
        "warzone": ["Rotation", "Contact", "Engagement", "CQC", "Finish", "Aftermath"],
        "general": ["Start", "Early", "Build", "Peak", "Late", "End"],
    }
    labels = phase_labels.get(game_type, phase_labels["general"])
    
    for i, frame_idx in enumerate(indices):
        frame = raw_frames[frame_idx]
        # Fixed timestamp calculation for storyboard frames
        # Storyboard shows num_storyboard frames evenly spaced across the video duration
        # The i-th storyboard frame (0-indexed) should be at time i * duration / (num_storyboard - 1)
        # when num_storyboard > 1, otherwise at time 0
        if num_storyboard > 1:
            ts = round(i * duration / (num_storyboard - 1), 1)
        else:
            ts = 0.0
        label = labels[min(i, len(labels) - 1)]
        
        # Find the intensity at this point in the video
        # Map storyboard position to token index in combined_change array
        if num_storyboard > 1 and len(combined_change) > 0:
            token_idx = int(i * (len(combined_change) - 1) / (num_storyboard - 1))
            token_idx = min(token_idx, len(combined_change) - 1)
            local_intensity = float(combined_change[token_idx])
        else:
            local_intensity = 0.0
        
        try:
            annotated = frame.copy()
            h, w = annotated.shape[:2]
            
            # Run YOLO if available
            if _yolo_model is not None:
                try:
                    results = _yolo_model(annotated, classes=[0], verbose=False)
                    annotated = results[0].plot(labels=False, conf=False, line_width=2)
                except:
                    pass
            
            # Add dark overlay at top and bottom for text
            overlay = annotated.copy()
            cv2.rectangle(overlay, (0, 0), (w, 80), (0, 0, 0), -1)
            cv2.rectangle(overlay, (0, h - 50), (w, h), (0, 0, 0), -1)
            annotated = cv2.addWeighted(overlay, 0.6, annotated, 0.4, 0)
            
            # Top: Phase label
            cv2.putText(annotated, label.upper(), (20, 35),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 220, 255), 2)
            cv2.putText(annotated, f"{ts}s", (w - 80, 35),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            # Intensity bar at top
            bar_w = int(min(1.0, local_intensity * 3) * (w - 40))
            bar_color = (0, 255, 100) if local_intensity < 0.3 else (0, 200, 255) if local_intensity < 0.6 else (0, 80, 255)
            cv2.rectangle(annotated, (20, 50), (20 + bar_w, 65), bar_color, -1)
            cv2.rectangle(annotated, (20, 50), (w - 20, 65), (100, 100, 100), 1)
            
            # Bottom: frame counter  
            cv2.putText(annotated, f"Frame {i+1}/{len(indices)}", (20, h - 18),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
            
            _, buffer = cv2.imencode('.jpg', annotated, [int(cv2.IMWRITE_JPEG_QUALITY), 75])
            b64 = base64.b64encode(buffer).decode('utf-8')
            
            storyboard.append({
                "timestamp": ts,
                "label": label,
                "image": b64
            })
        except Exception as e:
            logger.warning(f"Storyboard frame {i} failed: {e}")
            continue
    
    return storyboard

def analyze_embeddings(embeddings, metadata, game_type, raw_frames=None):
    profile = GAME_PROFILES.get(game_type, GAME_PROFILES["general"])
    duration = max(metadata.get("duration", 1.0), 0.1)

    try:
        if isinstance(embeddings, np.ndarray):
            e = embeddings.astype(np.float32)
        else:
            e = np.array(embeddings).astype(np.float32)
            
        if e.ndim == 3:
            e = e[0]
        elif e.ndim > 3:
            e = e.reshape(-1, e.shape[-1])
            
        num_tokens = len(e)
        fps_effective = num_tokens / duration
        
        cos_dists = []
        l2_dists = []
        for i in range(num_tokens - 1):
            try:
                norm_a = np.linalg.norm(e[i]) + 1e-8
                norm_b = np.linalg.norm(e[i+1]) + 1e-8
                cos_sim = np.clip(np.dot(e[i], e[i+1]) / (norm_a * norm_b), -1.0, 1.0)
                cos_dists.append(max(0.0, 1.0 - cos_sim))
                
                l2 = np.linalg.norm(e[i+1] - e[i])
                l2_dists.append(l2)
            except:
                cos_dists.append(0.0)
                l2_dists.append(0.0)
            
        cos_dists = np.array(cos_dists, dtype=np.float32)
        l2_dists = np.array(l2_dists, dtype=np.float32)
        
        try:
            l2_max = np.max(l2_dists) if len(l2_dists) > 0 and np.max(l2_dists) > 0 else 1.0
            l2_norm = l2_dists / l2_max
            combined_change = (0.6 * cos_dists) + (0.4 * l2_norm)
            
            # Apply temporal weighting to prevent celebration peaks from being selected as critical events
            # Boost middle 60% (climax zone), reduce last 20% (celebration zone)
            n = len(combined_change)
            temporal_weights = np.ones(n, dtype=np.float32)
            for i in range(n):
                t = i / max(1, n - 1)  # Normalized position 0 to 1
                if t < 0.2:
                    # First 20% - setup phase, normal weight
                    temporal_weights[i] = 1.0
                elif t < 0.8:
                    # Middle 60% - climax zone, boosted
                    temporal_weights[i] = 1.5
                else:
                    # Last 20% - celebration zone, heavily reduced
                    temporal_weights[i] = 0.3
            
            # Apply temporal weighting
            combined_change = combined_change * temporal_weights
            
        except:
            combined_change = np.zeros(max(1, num_tokens - 1), dtype=np.float32)
        
        if len(combined_change) > 0:
            energy = float(np.mean(combined_change))
            variance = float(np.var(combined_change))
            peak_ratio = float(np.sum(combined_change > profile["scene_change_threshold"]) / len(combined_change))
            calm_ratio = float(np.sum(combined_change < profile["calm_threshold"]) / len(combined_change))
        else:
            energy, variance, peak_ratio, calm_ratio = 0.0, 0.0, 0.0, 1.0
            combined_change = np.array([0.0], dtype=np.float32)
            
        key_moments = []
        i = 0
        threshold = profile["scene_change_threshold"]
        while i < len(combined_change):
            if combined_change[i] > threshold:
                cluster_start = i
                cluster_peak = combined_change[i]
                cluster_peak_idx = i
                while i < len(combined_change) and (combined_change[i] > threshold * 0.5 or (i - cluster_start) < 3):
                    if combined_change[i] > cluster_peak:
                        cluster_peak = combined_change[i]
                        cluster_peak_idx = i
                    i += 1
                
                intensity = float(cluster_peak)
                ct = profile["critical_event_threshold"]
                st = profile["significant_action_threshold"]
                
                if intensity > ct:
                    mt = "critical_event"
                elif intensity > st:
                    mt = "significant_action"
                else:
                    mt = "notable_change"
                    
                labels = profile["moment_labels"][mt]
                desc = random.choice(labels) if labels else "Event"
                
                # Map token index back to actual video frame index
                # V-JEPA produces many tokens (spatial patches) per frame,
                # so cluster_peak_idx is in token space, not frame space.
                annotated_b64 = None
                if raw_frames is not None and len(raw_frames) > 0:
                    frame_idx = min(
                        int(cluster_peak_idx * len(raw_frames) / max(num_tokens - 1, 1)),
                        len(raw_frames) - 1
                    )
                    annotated_b64 = annotate_keyframe(raw_frames[frame_idx], mt)
                
                key_moments.append({
                    "timestamp": round((cluster_peak_idx + 1) / fps_effective, 2),
                    "moment_type": mt,
                    "confidence": round(min(1.0, intensity / 0.8), 2),
                    "description": desc,
                    "intensity": round(min(1.0, intensity), 2),
                    "annotated_frame": annotated_b64
                })
            else:
                i += 1
                
        key_moments.sort(key=lambda x: x["confidence"], reverse=True)
        
        energy_score = max(40.0, min(99.0, energy * 200))
        
        reaction_frames = []
        for j, c in enumerate(combined_change):
            if c > threshold:
                count = 0
                for k in range(j+1, min(j+15, len(combined_change))):
                    count += 1
                    if combined_change[k] < threshold * 0.5:
                        break
                reaction_frames.append(count)
        reaction_score = max(50.0, min(95.0, 100 - np.mean(reaction_frames)*5)) if reaction_frames else 70.0
        
        try:
            centered = e - np.mean(e, axis=0)
            U, S, Vt = np.linalg.svd(centered, full_matrices=False)
            pos_ratio = (S[0] + S[1]) / (np.sum(S) + 1e-8)
            positioning_score = max(50.0, min(98.0, pos_ratio * 120))
        except:
            positioning_score = 75.0
            
        decision_score = max(60.0, min(96.0, (calm_ratio + peak_ratio) * 150))
        aggression_score = max(65.0, min(99.0, peak_ratio * 300))
        
        composure_vals = []
        for m in key_moments[:3]:
            idx = int(m["timestamp"] * fps_effective)
            post = combined_change[idx:idx+8]
            if len(post) > 0:
                composure_vals.append(max(0.0, 1 - np.var(post)*5))
        composure_score = max(55.0, min(95.0, np.mean(composure_vals)*100)) if composure_vals else 75.0
        
        consistency_score = energy_score
        
        def to_grade(s):
            if s >= 90: return "S"
            if s >= 80: return "A"
            if s >= 70: return "B"
            if s >= 60: return "C"
            if s >= 50: return "D"
            return "F"
            
        is_casual = False
        if game_type == "soccer":
            if len(combined_change) > 5:
                early_var = float(np.var(combined_change[:5]))
                if early_var > 0.03:
                    is_casual = True
            patterns = [
                {"pattern_name": "movement_intensity", "score": float(consistency_score), "description": "Activity level", "icon": "🏃", "grade": to_grade(consistency_score)},
                {"pattern_name": "spatial_awareness", "score": float(positioning_score), "description": "Space utilization", "icon": "👁️", "grade": to_grade(positioning_score)},
                {"pattern_name": "ball_engagement", "score": float(aggression_score), "description": "High-intensity bursts", "icon": "⚽", "grade": to_grade(aggression_score)},
                {"pattern_name": "transition_speed", "score": float(reaction_score), "description": "Defense/Attack shift", "icon": "⚡", "grade": to_grade(reaction_score)},
                {"pattern_name": "composure", "score": float(composure_score), "description": "Post-event stability", "icon": "😎", "grade": to_grade(composure_score)},
                {"pattern_name": "decision_quality", "score": float(decision_score), "description": "Controlled play", "icon": "🧠", "grade": to_grade(decision_score)}
            ]
        else:
            patterns = [
                {"pattern_name": "consistency", "score": float(consistency_score), "description": "Match energy consistency", "icon": "🎯", "grade": to_grade(consistency_score)},
                {"pattern_name": "reaction_speed", "score": float(reaction_score), "description": "Time to stabilize", "icon": "⚡", "grade": to_grade(reaction_score)},
                {"pattern_name": "positioning", "score": float(positioning_score), "description": "Spatial variance", "icon": "🛡️", "grade": to_grade(positioning_score)},
                {"pattern_name": "decision_quality", "score": float(decision_score), "description": "Controlled transitions", "icon": "🧠", "grade": to_grade(decision_score)},
                {"pattern_name": "aggression", "score": float(aggression_score), "description": "High-intensity frequency", "icon": "🔥", "grade": to_grade(aggression_score)},
                {"pattern_name": "composure", "score": float(composure_score), "description": "Post-event stability", "icon": "😎", "grade": to_grade(composure_score)}
            ]
        
        w = profile["scoring_weights"]
        if game_type == "soccer":
            base = (
                consistency_score * w.get("movement_intensity", 0.25) +
                reaction_score * w.get("transition_speed", 0.20) +
                positioning_score * w.get("spatial_awareness", 0.30) +
                aggression_score * w.get("ball_engagement", 0.25)
            )
            base = base * 0.8 + decision_score * 0.1 + composure_score * 0.1
        else:
            base = (
                consistency_score * w.get("consistency", 0.25) +
                reaction_score * w.get("reaction_speed", 0.25) +
                positioning_score * w.get("positioning", 0.25) +
                decision_score * w.get("decision_quality", 0.25)
            )
            base = base * 0.8 + aggression_score * 0.1 + composure_score * 0.1
        
        base = max(70.0, base)
        overall_score = float(max(70.0, min(99.0, base)))
        letter_grade = to_grade(overall_score)
        
        phase_analysis = []
        start_time = 0.0
        for p in profile["phases"]:
            p_len = duration * p["pct"]
            end_time = start_time + p_len
            
            start_idx = int(start_time * fps_effective)
            end_idx = int(end_time * fps_effective)
            sub_curve = combined_change[start_idx:end_idx]
            
            if len(sub_curve) > 0:
                p_calm = float(np.sum(sub_curve < profile["calm_threshold"]) / len(sub_curve))
                if p_calm > p["expected_calm"] + 0.1: pace = "Slower than expected (Passive)"
                elif p_calm < p["expected_calm"] - 0.1: pace = "Faster than expected (Aggressive)"
                else: pace = "As expected"
            else:
                pace = "Unknown"
                
            phase_analysis.append({
                "phase_name": p["name"],
                "time_range": f"{int(start_time)}s - {int(end_time)}s",
                "pace_rating": pace,
                "description": f"Expected calm {p['expected_calm']*100:.0f}%"
            })
            start_time = end_time
            
        clip_stats = {
            "energy": energy,
            "variance": variance,
            "peak_ratio": peak_ratio,
            "calm_ratio": calm_ratio,
            "is_casual_soccer": is_casual
        }
        
        # Generate storyboard
        storyboard = generate_storyboard(
            raw_frames, duration, combined_change, game_type
        )
        
        return {
            "key_moments": key_moments,
            "movement_patterns": patterns,
            "overall_score": overall_score,
            "letter_grade": letter_grade,
            "phase_analysis": phase_analysis,
            "recommendations": [],
            "session_summary": f"{profile['name']} session graded {letter_grade}.",
            "clip_stats": clip_stats,
            "storyboard_frames": storyboard
        }

    except Exception as exc:
        logger.error(f"Analysis algorithm failed: {exc}", exc_info=True)
        
    return {
        "key_moments": [],
        "movement_patterns": [
            {"pattern_name": "consistency", "score": 50.0, "description": "Fallback", "icon": "🎯", "grade": "C"},
            {"pattern_name": "reaction_speed", "score": 50.0, "description": "Fallback", "icon": "⚡", "grade": "C"},
            {"pattern_name": "positioning", "score": 50.0, "description": "Fallback", "icon": "🛡️", "grade": "C"},
            {"pattern_name": "decision_quality", "score": 50.0, "description": "Fallback", "icon": "🧠", "grade": "C"},
            {"pattern_name": "aggression", "score": 50.0, "description": "Fallback", "icon": "🔥", "grade": "C"},
            {"pattern_name": "composure", "score": 50.0, "description": "Fallback", "icon": "😎", "grade": "C"}
        ],
        "overall_score": 50.0,
        "letter_grade": "C",
        "phase_analysis": [],
        "recommendations": [],
        "session_summary": "Analysis encountered an error.",
        "clip_stats": {"energy": 0, "variance": 0, "peak_ratio": 0, "calm_ratio": 0}
    }

# ─── COACHING ───
def generate_coaching_tips(analysis_data: dict, game_type: str, game_profile: dict) -> list[str]:
    patterns = analysis_data.get("movement_patterns", [])
    if not patterns or len(patterns) < 2:
        return ["Keep practicing to get more detailed feedback on your gameplay."] * 5
        
    sorted_patterns = sorted(patterns, key=lambda x: x["score"])
    worst = sorted_patterns[0]
    second_worst = sorted_patterns[1]
    best = sorted_patterns[-1]

    overall_score = analysis_data.get("overall_score", 50.0)
    game_name = game_profile.get("name", game_type.capitalize())

    if game_type == "soccer":
        is_casual = analysis_data.get("clip_stats", {}).get("is_casual_soccer", False)
        
        casual_low = [
            "Your positioning opened up passing lanes, but keep moving after you pass.",
            "Great intensity in that sprint toward the ball! Work on pacing yourself.",
            "Try keeping your head up before receiving the ball.",
            "Practice first-touch passing against a wall across 10 minutes.",
            "Focus on communication—call for the ball when you're open!"
        ]
        pro_low = [
            "Transition speed is slow. Work on rest defense when attacking.",
            "Your ball engagement indicates you're isolated from the play.",
            "Spatial awareness scores suggest you're caught ball-watching. Scan your shoulders more.",
            "Movement intensity drops off rapidly. Improve your pressing stamina.",
            "Decision quality under pressure needs work. Don't force passes through the central block."
        ]
        casual_high = [
            "Awesome energy! You're dominating the midfield.",
            "Brilliant first touches today! Keep it up.",
            "Your spatial awareness is solid, finding great pockets of space."
        ]
        pro_high = [
            "Elite spatial awareness, perfectly exploiting the half-spaces.",
            "Incredible movement intensity, leading the team's pressing structure.",
            "Excellent ball engagement in the transition phases."
        ]
        
        tips = []
        low_pool = casual_low if is_casual else pro_low
        high_pool = casual_high if is_casual else pro_high
        
        tips.append("⚽ " + random.choice(low_pool))
        tips.append("⚽ " + random.choice(low_pool))
        tips.append("🔥 " + random.choice(high_pool))
        
        meta = GAME_META.get("soccer", {})
        m_tips = meta.get("meta_tips", [])
        if m_tips:
            tips.append("🎯 META TIP: " + random.choice(m_tips))
            
        if overall_score >= 70:
            tips.append(f"🧠 MINDSET: Great pacing ({overall_score:.1f} overall). You're reading the game well.")
        else:
            tips.append(f"🧠 MINDSET: Rough session ({overall_score:.1f} overall). Focus on basic fundamentals next time.")
        return tips

    low_pools = {
        "consistency": [
            "Your consistency score is {score:.1f}. In {game}, fluctuating performance loses ranks. Spend 15 mins daily on tracking drills before queuing.",
            "Scoring {score:.1f} in consistency means you lack a solid baseline for {game}. Create a pre-game warmup routine and stick to it.",
            "Consistency at {score:.1f} shows erratic inputs. Drop in less contested areas in {game} to build your mechanical rhythm.",
            "A consistency of {score:.1f} in {game} is below par. Focus on repeating basic mechanical executions until they're muscle memory.",
            "Your {score:.1f} consistency suggests you might be playing while fatigued or tilted. Remember to take breaks between {game} matches.",
            "With a consistency of {score:.1f}, try sticking to one specific loadout or role in {game} for 10 matches straight to build familiarity."
        ],
        "reaction_speed": [
            "Your reaction speed of {score:.1f} is below average for {game} duels. Spend 10 minutes in a targeted aim trainer focusing on flick shots.",
            "At {score:.1f} reaction speed, you're getting beaten in {game} face-to-face engagements. Practice pre-aiming common angles to compensate.",
            "Reactions scored {score:.1f}. In {game}, you need to anticipate rather than just react. Watch pro VODs to understand crosshair placement.",
            "Scoring {score:.1f} on reactions means you're late to the trigger. Warm up your central nervous system with fast-paced deathmatches in {game}.",
            "A reaction speed of {score:.1f} won't cut it in high-rank {game}. Tune your sensitivity to ensure you aren't fighting your own settings.",
            "With {score:.1f} in reaction speed, try making sure you are fully hydrated before playing {game} to maximize your physical response time."
        ],
        "positioning": [
            "Scoring {score:.1f} in positioning leaves you exposed in {game}. Always ensure you have hard cover within one slide or dash away.",
            "Your positioning score is {score:.1f}. You are taking bad fights in {game}. Try to play the high ground and never peek multiple enemies.",
            "With a {score:.1f} positioning metric in {game}, you're likely getting caught in rotations. Plan your path 15 seconds before you need to move.",
            "Positioning at {score:.1f} means you're too predictable. Use off-angles and avoid re-peeking the exact same corner in {game}.",
            "A {score:.1f} in positioning shows poor map awareness. Look at your minimap more often in {game} to understand where the threat lines are.",
            "Your {score:.1f} positioning score indicates you're isolating yourself. Play closer to your squad in {game} to trade frags efficiently."
        ],
        "decision_quality": [
            "Your decision quality is {score:.1f}. In {game}, you're overcommitting. Stop forcing bad pushes and wait for opponent mistakes.",
            "Scoring {score:.1f} on decisions means you are playing on autopilot. Actively narrate your thought process out loud in your next {game} match.",
            "With {score:.1f} decision quality, you're taking unfavorable trades. If you don't have the advantage in {game}, disengage and reposition.",
            "Decision making at {score:.1f} indicates panic. In {game}, take a half-second to assess enemy utility before diving in.",
            "A decision score of {score:.1f} is hurting your {game} win rate. Stop tunneling for kills and start playing the objective or zone.",
            "Your {score:.1f} decision metric means you aren't managing your economy/resources well in {game}. Check supplies before engaging."
        ],
        "aggression": [
            "Your aggression score is {score:.1f}, which is too passive for {game}. You need to take space when your team gets an opening pick.",
            "Scoring {score:.1f} in aggression means you're letting the enemy dictate the pace in {game}. Start pushing when you have a health advantage.",
            "An aggression of {score:.1f} won't win {game} tournaments. Practice playing entry fragger for a few games to build confidence.",
            "With {score:.1f} aggression, you are playing scared. Confidence is key in {game}—swing together with your teammate to overwhelm defenders.",
            "Your {score:.1f} aggression shows missed opportunities. When you crack an enemy's shields/armor in {game}, you must close the distance immediately.",
            "At {score:.1f} aggression, you're giving up too much map control in {game}. Hold your ground and force the enemy to burn utility to move you."
        ],
        "composure": [
            "Composure at {score:.1f} means you're panicking in {game} skirmishes. Breathe out slowly during clutch situations to steady your hands.",
            "Your composure score of {score:.1f} drops sharply under pressure. In your next {game} match, focus solely on staying relaxed.",
            "Scoring {score:.1f} in composure leads to whiffed shots. Boot up a 1vMultiple scenario in a {game} custom lobby and practice staying icy.",
            "A composure of {score:.1f} shows you tense up. Remind yourself it's just a {game} lobby—tension ruins your tracking aim.",
            "With {score:.1f} composure, you're likely gripping your mouse/controller too hard. Loosen your grip to improve micro-adjustments in {game}.",
            "Your {score:.1f} composure metric means you rush your shots when surprised. Take a micro-pause to line up the headshot in {game} before firing."
        ]
    }

    high_pools = {
        "consistency": [
            "Incredible {score:.1f} consistency! You are a reliable anchor for {game}. Keep your warmups identical to maintain this.",
            "Your consistency is at {score:.1f}. This is pro-level stability in {game}. Try increasing your overall pace while maintaining this control.",
            "Scoring {score:.1f} in consistency is fantastic. You make very few unforced errors in {game}.",
            "With {score:.1f} consistency, you're playing {game} like a machine. Great job minimizing mistakes."
        ],
        "reaction_speed": [
            "A blazing {score:.1f} reaction speed! You're winning {game} duels off pure mechanics.",
            "Your {score:.1f} reaction score is elite. Use this to take aggressive first-peeks in {game}.",
            "With {score:.1f} reactions, you are dominating the micro-engagements in {game}. Keep your energy up!"
        ],
        "positioning": [
            "Flawless {score:.1f} positioning! You always seem to have the upper hand in {game}.",
            "Your {score:.1f} positioning means you are functionally untradable. Excellent map awareness in {game}.",
            "With {score:.1f} positioning, you're making {game} look easy by taking smart, isolated 1v1s."
        ],
        "decision_quality": [
            "A massive {score:.1f} in decision quality! You possess excellent macro understanding of {game}.",
            "Your {score:.1f} decision score shows you're always one step ahead. Consider shotcalling for your {game} squad.",
            "With {score:.1f} decision making, you take high-percentage fights and win them. Textbook {game} performance."
        ],
        "aggression": [
            "Perfect {score:.1f} aggression! You're creating immense pressure and space in {game}.",
            "Your {score:.1f} aggression score shows you know exactly when to strike. Keep up the high tempo in {game}."
        ],
        "composure": [
            "Ice in your veins! A {score:.1f} composure score means you never crack in {game}.",
            "Your {score:.1f} composure is elite. You turn around disadvantageous {game} scenarios through sheer calm.",
            "With {score:.1f} composure, you win the mental battle every time. An anchor for your {game} team."
        ]
    }

    def get_tip(pool_dict, item):
        name = item["pattern_name"]
        score = item["score"]
        pool = pool_dict.get(name, pool_dict.get("consistency", []))
        return random.choice(pool).format(score=score, game=game_name)
        
    tips = []
    tips.append(get_tip(low_pools, worst))
    tips.append(get_tip(low_pools, second_worst))
    tips.append(get_tip(high_pools, best))

    meta = GAME_META.get(game_type.lower(), GAME_META.get("general", {}))
    m_tips = meta.get("meta_tips", ["Stay updated with the latest patch notes."])
    tips.append("🎯 META TIP: " + random.choice(m_tips))
    
    if overall_score >= 70:
        tips.append(f"🧠 MINDSET: Great pacing ({overall_score:.1f} overall). Maintain this flow state by staying hydrated and eliminating distractions.")
    elif overall_score >= 50:
        tips.append(f"🧠 MINDSET: Solid effort ({overall_score:.1f} overall). Establish a stricter practice routine to push past this plateau.")
    else:
        tips.append(f"🧠 MINDSET: Rough session ({overall_score:.1f} overall). Don't tilt! Go back to {game_name} fundamentals and focus strictly on surviving.")
        
    return tips

def generate_session_summary(analysis_data: dict, game_type: str) -> str:
    patterns = analysis_data.get("movement_patterns", [])
    if not patterns or len(patterns) < 2:
        return f"A quick {game_type.capitalize()} session lacking enough data to fully evaluate."
    
    sorted_patterns = sorted(patterns, key=lambda x: x["score"])
    worst = sorted_patterns[0]
    best = sorted_patterns[-1]
    
    w_name = worst["pattern_name"].replace("_", " ")
    b_name = best["pattern_name"].replace("_", " ")
    w_score = worst["score"]
    b_score = best["score"]
    
    if game_type == "soccer":
        is_casual = analysis_data.get("clip_stats", {}).get("is_casual_soccer", False)
        if is_casual:
            return f"Great energy on the pitch! Your {b_name} score of {b_score:.0f} shows you're highly involved. Try working on your {w_name} ({w_score:.0f}) — small improvements there will give you more time on the ball."
        else:
            return f"Strong session — your {b_name} ({b_score:.0f}) shows excellent understanding, but your {w_name} ({w_score:.0f}) suggests you're slow to switch phases. Work on refining this to elevate your game."

    return f"Your {game_type.capitalize()} session showcased excellent {b_name} ({b_score:.1f}), but you'll need to focus heavily on improving your {w_name} ({w_score:.1f}) moving forward."

# ─── ENDPOINTS ───
@app.get("/api/v1/health", response_model=HealthResponse)
async def health_check():
    try:
        loaded = _model is not None
        gpu_used = None
        gpu_total = None
        if torch.cuda.is_available():
            gpu_used = round(torch.cuda.memory_allocated() / (1024 * 1024), 1)
            gpu_total = round(torch.cuda.get_device_properties(0).total_memory / (1024 * 1024), 1)
        return HealthResponse(
            status="healthy" if loaded else "loading",
            model_loaded=loaded,
            device=_device,
            gpu_memory_used_mb=gpu_used,
            gpu_memory_total_mb=gpu_total
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/games")
async def list_games():
    try:
        return [
            {"id": gid, "name": p["name"], "icon": "⚽" if gid == "soccer" else "🏗️" if gid == "fortnite" else "🎯" if gid == "valorant" else "🪖" if gid == "warzone" else "🎮", "description": "Professional matches and casual play" if gid == "soccer" else "FPS Analysis"}
            for gid, p in GAME_PROFILES.items()
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/meta/{game_type}")
async def get_game_meta(game_type: str = FastAPIPath(...)):
    gt = game_type.lower()
    if gt not in GAME_META:
        raise HTTPException(status_code=404, detail="Game meta not found")
        
    meta = GAME_META[gt]
    items = meta.get("key_weapons", []) + meta.get("popular_agents", []) + meta.get("popular_strategies", [])
    
    return {
        "game": game_type,
        "season": meta.get("season", "N/A"),
        "last_updated": meta.get("last_updated", "N/A"),
        "tips": meta.get("meta_tips", []),
        "popular_items": items
    }

@app.get("/api/v1/video/{analysis_id}")
async def get_video(analysis_id: str):
    video_path = Path(VIDEO_DIR) / f"{analysis_id}.mp4"
    if not video_path.exists():
        raise HTTPException(status_code=404, detail="Video not found or expired")
    return FileResponse(
        path=str(video_path),
        media_type="video/mp4",
        headers={"Cache-Control": "max-age=3600"}
    )

@app.post("/api/v1/analyze", response_model=AnalysisResult)
async def analyze_video(file: UploadFile = File(...), game_type: Optional[str] = Query("general")):
    cleanup_old_videos()
    try:
        if _model is None or _processor is None:
            raise HTTPException(status_code=503, detail="Model resting or not loaded yet.")

        start_time = time.perf_counter()
        
        content = await file.read()
        if len(content) > 100 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="File too large. Maximum 100 MB.")
        if len(content) == 0:
            raise HTTPException(status_code=400, detail="Empty file uploaded.")

        analysis_id = str(uuid4())
        tmp_path = Path(f"/tmp/{analysis_id}_{file.filename or 'video.mp4'}")
        tmp_path.write_bytes(content)
        
        persistent_path = Path(VIDEO_DIR) / f"{analysis_id}.mp4"
        shutil.copy2(tmp_path, persistent_path)

        try:
            frames, metadata, raw_frames = extract_frames(str(tmp_path), num_frames=16)

            inputs = _processor(frames, return_tensors="pt")
            pixel_values = inputs["pixel_values_videos"].to(_device, dtype=torch.float16)

            with torch.inference_mode():
                outputs = _model(pixel_values_videos=pixel_values)

            embeddings = outputs.last_hidden_state.detach().cpu().numpy()
            
            analysis_data = analyze_embeddings(embeddings, metadata, game_type, raw_frames=raw_frames)

            # Generate Coaching Content
            profile = GAME_PROFILES.get(game_type, GAME_PROFILES["general"])
            tips = generate_coaching_tips(analysis_data, game_type, profile)
            summary = generate_session_summary(analysis_data, game_type)

            total_time = time.perf_counter() - start_time

            features = AnalysisFeatures(
                embedding_shape=list(embeddings.shape),
                key_moments=[KeyMoment(**m) for m in analysis_data["key_moments"]],
                movement_patterns=[MovementPattern(**p) for p in analysis_data["movement_patterns"]],
                overall_score=analysis_data["overall_score"],
                storyboard_frames=[StoryboardFrame(**sf) for sf in analysis_data.get("storyboard_frames", [])]
            )

            return AnalysisResult(
                status="success",
                analysis_id=analysis_id,
                processing_time_seconds=round(total_time, 2),
                features=features,
                recommendations=tips,
                inference_device=_device,
                timestamp=datetime.now(timezone.utc).isoformat(),
                game_type=game_type,
                letter_grade=analysis_data["letter_grade"],
                phase_analysis=[PhaseAnalysis(**pa) for pa in analysis_data["phase_analysis"]],
                session_summary=summary,
                video_url=f"/api/v1/video/{analysis_id}"
            )
        finally:
            tmp_path.unlink(missing_ok=True)
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
