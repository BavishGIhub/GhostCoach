import re

with open('server.py', 'r', encoding='utf-8') as f:
    orig = f.read()

# 1. Imports and Video cleanup
imports_str = '''
import shutil
import glob
import os
from fastapi.responses import FileResponse

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
'''
orig = orig.replace('from pydantic import BaseModel, Field', imports_str + '\nfrom pydantic import BaseModel, Field')

# Also include standard os if not present
if 'import os' not in orig:
    orig = orig.replace('import time', 'import time\nimport os\n')

# 2. AnalysisResult
orig = orig.replace('session_summary: str = ""', 'session_summary: str = ""\n    video_url: Optional[str] = None')

# 3. GAME_PROFILES
soccer_profile = '''    "soccer": {
        "name": "Football/Soccer", "scene_change_threshold": 0.25, "critical_event_threshold": 0.55,
        "significant_action_threshold": 0.35, "calm_threshold": 0.08,
        "scoring_weights": {"movement_intensity": 0.25, "spatial_awareness": 0.30, "ball_engagement": 0.25, "transition_speed": 0.20},
        "phases": [
            {"name": "Build-Up Play", "pct": 0.4, "expected_calm": 0.6},
            {"name": "Attacking Phase", "pct": 0.35, "expected_calm": 0.3},
            {"name": "Defensive Phase", "pct": 0.25, "expected_calm": 0.4}],
        "moment_labels": {
            "critical_event": ["Goal Opportunity", "Dangerous Attack", "Key Tackle"],
            "significant_action": ["Progressive Pass", "Dribble Attempt", "Cross Delivery"],
            "notable_change": ["Formation Shift", "Pressing Trigger", "Transition Moment"]},
    },
    "general": {
'''
orig = orig.replace('    "general": {\n', soccer_profile)

# 4. GAME_META
soccer_meta = '''    "soccer": {
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
'''
orig = orig.replace('    "general": {\n', soccer_meta, 1)

# 5. analyze_embeddings
patterns_old = '''        patterns = [
            {"pattern_name": "consistency", "score": float(consistency_score), "description": "Match energy consistency", "icon": "??", "grade": to_grade(consistency_score)},
            {"pattern_name": "reaction_speed", "score": float(reaction_score), "description": "Time to stabilize", "icon": "?", "grade": to_grade(reaction_score)},
            {"pattern_name": "positioning", "score": float(positioning_score), "description": "Spatial variance", "icon": "???", "grade": to_grade(positioning_score)},
            {"pattern_name": "decision_quality", "score": float(decision_score), "description": "Controlled transitions", "icon": "??", "grade": to_grade(decision_score)},
            {"pattern_name": "aggression", "score": float(aggression_score), "description": "High-intensity frequency", "icon": "??", "grade": to_grade(aggression_score)},
            {"pattern_name": "composure", "score": float(composure_score), "description": "Post-event stability", "icon": "??", "grade": to_grade(composure_score)}
        ]'''
        
patterns_new = '''        is_casual = False
        if game_type == "soccer":
            if len(combined_change) > 5:
                early_var = float(np.var(combined_change[:5]))
                if early_var > 0.03:
                    is_casual = True
            patterns = [
                {"pattern_name": "movement_intensity", "score": float(consistency_score), "description": "Activity level", "icon": "??", "grade": to_grade(consistency_score)},
                {"pattern_name": "spatial_awareness", "score": float(positioning_score), "description": "Space utilization", "icon": "???", "grade": to_grade(positioning_score)},
                {"pattern_name": "ball_engagement", "score": float(aggression_score), "description": "High-intensity bursts", "icon": "?", "grade": to_grade(aggression_score)},
                {"pattern_name": "transition_speed", "score": float(reaction_score), "description": "Defense/Attack shift", "icon": "?", "grade": to_grade(reaction_score)},
                {"pattern_name": "composure", "score": float(composure_score), "description": "Post-event stability", "icon": "??", "grade": to_grade(composure_score)},
                {"pattern_name": "decision_quality", "score": float(decision_score), "description": "Controlled play", "icon": "??", "grade": to_grade(decision_score)}
            ]
        else:
            patterns = [
                {"pattern_name": "consistency", "score": float(consistency_score), "description": "Match energy consistency", "icon": "??", "grade": to_grade(consistency_score)},
                {"pattern_name": "reaction_speed", "score": float(reaction_score), "description": "Time to stabilize", "icon": "?", "grade": to_grade(reaction_score)},
                {"pattern_name": "positioning", "score": float(positioning_score), "description": "Spatial variance", "icon": "???", "grade": to_grade(positioning_score)},
                {"pattern_name": "decision_quality", "score": float(decision_score), "description": "Controlled transitions", "icon": "??", "grade": to_grade(decision_score)},
                {"pattern_name": "aggression", "score": float(aggression_score), "description": "High-intensity frequency", "icon": "??", "grade": to_grade(aggression_score)},
                {"pattern_name": "composure", "score": float(composure_score), "description": "Post-event stability", "icon": "??", "grade": to_grade(composure_score)}
            ]'''
orig = orig.replace(patterns_old, patterns_new)

weights_old = '''        w = profile["scoring_weights"]
        base = (
            consistency_score * w.get("consistency", 0.25) +
            reaction_score * w.get("reaction_speed", 0.25) +
            positioning_score * w.get("positioning", 0.25) +
            decision_score * w.get("decision_quality", 0.25)
        )
        base = base * 0.8 + aggression_score * 0.1 + composure_score * 0.1'''
        
weights_new = '''        w = profile["scoring_weights"]
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
            base = base * 0.8 + aggression_score * 0.1 + composure_score * 0.1'''
orig = orig.replace(weights_old, weights_new)

clip_stats_old = '''        clip_stats = {
            "energy": energy,
            "variance": variance,
            "peak_ratio": peak_ratio,
            "calm_ratio": calm_ratio
        }'''
clip_stats_new = '''        clip_stats = {
            "energy": energy,
            "variance": variance,
            "peak_ratio": peak_ratio,
            "calm_ratio": calm_ratio,
            "is_casual_soccer": is_casual
        }'''
orig = orig.replace(clip_stats_old, clip_stats_new)

# 6. generate_coaching_tips
coaching_old = '''def generate_coaching_tips(analysis_data: dict, game_type: str, game_profile: dict) -> list[str]:
    patterns = analysis_data.get("movement_patterns", [])
    if not patterns or len(patterns) < 2:
        return ["Keep practicing to get more detailed feedback on your gameplay."] * 5
        
    sorted_patterns = sorted(patterns, key=lambda x: x["score"])
    worst = sorted_patterns[0]
    second_worst = sorted_patterns[1]
    best = sorted_patterns[-1]

    overall_score = analysis_data.get("overall_score", 50.0)
    game_name = game_profile.get("name", game_type.capitalize())

    low_pools = {'''
coaching_new = '''def generate_coaching_tips(analysis_data: dict, game_type: str, game_profile: dict) -> list[str]:
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
        
        tips.append("? " + random.choice(low_pool))
        tips.append("? " + random.choice(low_pool))
        tips.append("?? " + random.choice(high_pool))
        
        meta = GAME_META.get("soccer", {})
        m_tips = meta.get("meta_tips", [])
        if m_tips:
            tips.append("?? META TIP: " + random.choice(m_tips))
            
        if overall_score >= 70:
            tips.append(f"?? MINDSET: Great pacing ({overall_score:.1f} overall). You're reading the game well.")
        else:
            tips.append(f"?? MINDSET: Rough session ({overall_score:.1f} overall). Focus on basic fundamentals next time.")
        return tips

    low_pools = {'''
orig = orig.replace(coaching_old, coaching_new)

# 7. generate_session_summary
summary_old = '''    w_score = worst["score"]
    b_score = best["score"]
    
    return f"Your {game_type.capitalize()} session showcased excellent {b_name} ({b_score:.1f}), but you'll need to focus heavily on improving your {w_name} ({w_score:.1f}) moving forward."'''

summary_new = '''    w_score = worst["score"]
    b_score = best["score"]
    
    if game_type == "soccer":
        is_casual = analysis_data.get("clip_stats", {}).get("is_casual_soccer", False)
        if is_casual:
            return f"Great energy on the pitch! Your {b_name} score of {b_score:.0f} shows you're highly involved. Try working on your {w_name} ({w_score:.0f}) — small improvements there will give you more time on the ball."
        else:
            return f"Strong attacking session — your {b_name} ({b_score:.0f}) shows excellent understanding, but your {w_name} ({w_score:.0f}) suggests you're slow to switch phases. Work on refining this to elevate your game."

    return f"Your {game_type.capitalize()} session showcased excellent {b_name} ({b_score:.1f}), but you'll need to focus heavily on improving your {w_name} ({w_score:.1f}) moving forward."'''
orig = orig.replace(summary_old, summary_new)

# 8. list_games
games_old = '''        return [
            {"id": gid, "name": p["name"], "icon": "???" if gid == "fortnite" else "??" if gid == "valorant" else "??" if gid == "warzone" else "??"}
            for gid, p in GAME_PROFILES.items()
        ]'''
games_new = '''        return [
            {
                "id": gid,
                "name": p["name"],
                "icon": "?" if gid == "soccer" else "???" if gid == "fortnite" else "??" if gid == "valorant" else "??" if gid == "warzone" else "??",
                "description": "Professional matches and casual play" if gid == "soccer" else ("General Match" if gid == "general" else "FPS Analysis")
            }
            for gid, p in GAME_PROFILES.items()
        ]'''
orig = orig.replace(games_old, games_new)

# 9. video storage and cleanup & endpoint
# inside analyze_video
analyze_old = '''@app.post("/api/v1/analyze", response_model=AnalysisResult)
async def analyze_video(file: UploadFile = File(...), game_type: Optional[str] = Query("general")):
    try:
        if _model is None or _processor is None:'''
analyze_new = '''@app.get("/api/v1/video/{analysis_id}")
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
        if _model is None or _processor is None:'''
orig = orig.replace(analyze_old, analyze_new)

# temp path uuid
tmp_old = '''        tmp_path = Path(f"/tmp/{uuid4().hex[:8]}_{file.filename or 'video.mp4'}")
        tmp_path.write_bytes(content)'''
tmp_new = '''        analysis_id = str(uuid4())
        tmp_path = Path(f"/tmp/{analysis_id}_{file.filename or 'video.mp4'}")
        tmp_path.write_bytes(content)
        
        # Save a copy to the persistent video directory
        persistent_path = Path(VIDEO_DIR) / f"{analysis_id}.mp4"
        shutil.copy2(tmp_path, persistent_path)'''
orig = orig.replace(tmp_old, tmp_new)

# result analysis id and video url
res_old = '''            return AnalysisResult(
                status="success",
                analysis_id=str(uuid4()),
                processing_time_seconds=round(total_time, 2),
                features=features,
                recommendations=tips,
                inference_device=_device,
                timestamp=datetime.now(timezone.utc).isoformat(),
                game_type=game_type,
                letter_grade=analysis_data["letter_grade"],
                phase_analysis=[PhaseAnalysis(**pa) for pa in analysis_data["phase_analysis"]],
                session_summary=summary
            )'''
res_new = '''            return AnalysisResult(
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
            )'''
orig = orig.replace(res_old, res_new)


with open('server.py', 'w', encoding='utf-8') as f:
    f.write(orig)

print("Server.py patched successfully!")
