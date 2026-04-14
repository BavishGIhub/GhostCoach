# Roo Code (DeepSeek v3.2) Prompt for Ghost Coach Phase 2 Polish

Copy and paste the entire block below into Roo Code to continue Phase 2:

***

**Role & Context:**
You are an expert full-stack developer continuing the "Phase 2" development of the "Ghost Coach" app. The tech stack is a Flutter/Riverpod frontend and a Python/FastAPI backend (running on Kaggle, utilizing YOLOv8 and V-JEPA). 
Recently, we successfully integrated a "Visual Storyboard" and fixed the frame-index mapping for the Annotated Key Moments.

**CRITICAL RULE - USE DART MCP:**
You have the `dart-mcp-server` configured. You **MUST** use it actively! Do not guess Dart syntax or imports. 
- Use the dart MCP tools to `analyze_files` or format code.
- If you make changes to Flutter files, explicitly verify them using the Dart MCP server or running `flutter analyze` via terminal.

**Your Objective:**
Fix the following 3 specific UX and logic issues that were identified in the latest test of an Eden Hazard solo-goal clip.

### Task 1: Auto-Scroll to Video Player on Tap (Flutter)
**Issue:** When a user taps on a Key Moment or a Visual Storyboard card, the video seeks to the timestamp correctly, but the user is scrolled down the page and has to manually scroll back up to see the video play.
**Action:**
1. Open `ghost_coach_app/lib/features/analysis/presentation/results_screen.dart`.
2. Introduce a `ScrollController` to the `SingleChildScrollView` inside `_buildBody`.
3. Inside the `seekToTimestamp` function (or the `onTap` callbacks for `_MomentTile` and `_StoryboardCard`), instruct the `ScrollController` to smoothly animate to the top (offset `0.0`) so the video player comes immediately into view:
   `_scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);`
4. Make sure to properly initialize and dispose of the `ScrollController` in the `_ResultsScreenState`.

### Task 2: Storyboard Timestamps are Slightly Off (Backend)
**Issue:** The storyboard image timestamps seem off by a few seconds compared to the actual video progression.
**Action:**
1. Open `backend/server.py` and find the `generate_storyboard` function.
2. The current logic uses `np.linspace` to pick evenly spaced frames from `raw_frames` (which contains exactly 16 frames uniformly sampled from the video). 
3. The timestamp calculation is `ts = round(frame_idx / max(n - 1, 1) * duration, 1)`. 
4. **Fix:** Improve this logic. Ensure the duration maps perfectly to the 16 extracted frames. Consider that if 16 frames are extracted at equal intervals, the first frame is at `t=0` and the last is at `t=duration`. If the frames are offset, adjust the `ts` math so the overlay timestamp perfectly matches the *actual* video timestamp of that specific frame index.

### Task 3: "Critical Event" is Picking the Celebration (Backend)
**Issue:** Because V-JEPA looks at pixel/motion changes, the highest intensity peak in a soccer video is often the camera panning wildly and players celebrating *after* the goal, rather than the goal itself. 
**Action:**
1. Open `backend/server.py` and locate the peak-finding logic inside `analyze_embeddings()`: `peaks, properties = find_peaks(combined_change, distance=...)`.
2. **Fix:** Apply a temporal weighting/decay function to the `combined_change` array *before* finding peaks. 
3. Soccer highlights usually have the climax happening in the middle 60% of the video. The final 15-20% is almost always celebration/replays. 
4. Multiply the `combined_change` array by a "focus window" mask (e.g., tapering off the intensity heavily in the last 15% of the array) so that peaks happening at the very end of the video are penalized and the *actual* goal/action in the middle forms the highest peak (the Critical Event).

**Execution Plan:**
- Process these tasks one by one.
- Read `server.py` and `results_screen.dart` to understand the current implementation.
- Use terminal commands to run Python's syntax checker (`python -m py_compile server.py`) and Flutter's analyzer (`flutter analyze`) to ensure zero regressions.
- Only report success once all three tasks are complete.
