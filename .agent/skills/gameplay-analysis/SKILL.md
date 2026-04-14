---
name: gameplay-analysis
description: "Gameplay video analysis logic. Activates when implementing key moment detection, movement pattern analysis, coaching text generation, or embedding similarity computation. Do not use for model inference or Android UI."
---

# Gameplay Analysis Pipeline

## Steps
1. V-JEPA 2 extracts per-frame embeddings -> numpy array of shape (num_frames, embed_dim)
2. Key moments: cosine distance between consecutive frame embeddings > threshold (0.3)
3. Classify moments by magnitude: >0.7 critical_event, >0.5 significant_action, >0.3 notable_change
4. Movement patterns: rolling std of embedding trajectory (smooth = consistent, erratic = poor)
5. Overall score: consistency 30% + reaction_speed 20% + positioning 25% + decision_quality 25%
6. Coaching text: Gemini 2.5 Flash API, prompt under 500 tokens, exactly 4 tips
7. Cache results by SHA-256 hash of video file (first 1MB)
8. If no Gemini API key, generate heuristic tips based on scores

## Do not use
- For V-JEPA 2 model loading or inference (use vjepa2-inference skill)
- For Android UI components
