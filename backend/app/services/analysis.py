"""
Gameplay analysis service for Ghost Coach.
Converts V-JEPA 2 embeddings into actionable coaching insights 
using unsupervised clustering algorithms and LLM feedback generation.
"""

import logging
import hashlib
import json
import os
from typing import Optional

import numpy as np
import torch
import torch.nn.functional as F
import httpx

logger = logging.getLogger(__name__)


class GameplayAnalyzer:
    """Interprets raw video embeddings into coaching feedback."""

    def __init__(self, gemini_api_key: Optional[str] = None):
        """Initialise the analyzer.
        
        Args:
            gemini_api_key: The Google Gemini API key used for generating actual text.
                If empty, the analyzer falls back to heuristics.
        """
        self.gemini_api_key = gemini_api_key
        self._tip_cache: dict[str, list[str]] = {}

    def compute_cosine_distance(self, a: np.ndarray, b: np.ndarray) -> float:
        """Compute cosine distance (1 - similarity) between two 1D or matched-shape vectors.
        
        Args:
            a: First embedding vector/tensor representation.
            b: Second embedding vector/tensor representation.
            
        Returns:
            Cosine distance as a float in [0.0, 2.0]. Max 0.0 if either vector is zero.
        """
        norm_a = np.linalg.norm(a)
        norm_b = np.linalg.norm(b)
        
        if norm_a == 0.0 or norm_b == 0.0:
            return 0.0
            
        sim = np.dot(a.flatten(), b.flatten()) / (norm_a * norm_b)
        # Numerical stability clamp
        sim = max(-1.0, min(1.0, sim))
        
        return 1.0 - float(sim)

    def detect_key_moments(self, embeddings: np.ndarray, video_duration: float, threshold: float = 0.3) -> list[dict]:
        """Identify critical gameplay events by finding temporal discontinuities.
        
        Args:
            embeddings: Tensor shape (num_frames, embed_dim)
            video_duration: Physical duration of the video in seconds.
            threshold: Minimum cosine distance describing a 'key moment'.
            
        Returns:
            List of dicts formatted as: {"timestamp", "moment_type", "confidence", "description"}
        """
        num_frames = len(embeddings)
        if num_frames < 2 or video_duration <= 0:
            return []

        fps = num_frames / video_duration
        moments = []

        # Apply temporal weighting to de-emphasize celebration peaks in last 20% of video
        # Soccer videos: climax typically in middle 60%, celebrations in last 15-20%
        for i in range(num_frames - 1):
            dist = self.compute_cosine_distance(embeddings[i], embeddings[i+1])
            
            # Calculate temporal position (0 to 1)
            temporal_pos = i / (num_frames - 1)
            
            # Apply temporal weighting
            if temporal_pos < 0.2:
                # First 20%: setup phase, normal weight
                weighted_dist = dist
            elif temporal_pos < 0.8:
                # Middle 60%: climax zone, boost weight
                weighted_dist = dist * 1.5
            else:
                # Last 20%: celebration zone, heavily reduce weight
                weighted_dist = dist * 0.3
            
            # Use weighted distance for threshold comparison
            if weighted_dist > threshold:
                # For moment type classification, use original distance (not weighted)
                if dist > 0.7:
                    m_type = "critical_event"
                    desc = "Major gameplay event detected (e.g., elimination, spawn)."
                elif dist > 0.5:
                    m_type = "significant_action"
                    desc = "Significant gameplay action (e.g., initiating engagement)."
                else:
                    m_type = "notable_change"
                    desc = "Notable shift in gameplay context/scenery."
                    
                confidence = min(1.0, dist / 0.8)
                timestamp = round(i / fps, 2)
                
                moments.append({
                    "timestamp": timestamp,
                    "moment_type": m_type,
                    "confidence": round(confidence, 2),
                    "description": desc
                })

        return sorted(moments, key=lambda x: x["timestamp"])

    def analyze_movement_patterns(self, embeddings: np.ndarray) -> list[dict]:
        """Categorize physical/mechanical gameplay skill using unlabelled PCA and distances.
        
        Args:
            embeddings: Numpy array of structural shape (num_frames, embed_dim)
            
        Returns:
            Exactly 4 movement pattern dictionaries (Consistency, Reaction Speed, Positioning, Decision Quality).
        """
        num_frames = len(embeddings)
        all_distances = []
        
        if num_frames >= 2:
            all_distances = [
                self.compute_cosine_distance(embeddings[i], embeddings[i+1]) 
                for i in range(num_frames - 1)
            ]
            
        # Defaults if insufficient frames
        if not all_distances:
            return [
                {"pattern_name": "consistency", "score": 50.0, "description": "Insufficient data."},
                {"pattern_name": "reaction_speed", "score": 50.0, "description": "Insufficient data."},
                {"pattern_name": "positioning", "score": 50.0, "description": "Insufficient data."},
                {"pattern_name": "decision_quality", "score": 50.0, "description": "Insufficient data."}
            ]

        # ------------------------------------------------------------
        # (A) Consistency
        # ------------------------------------------------------------
        window = max(3, num_frames // 4)
        if len(all_distances) >= window:
            rolling_stds = []
            for i in range(len(all_distances) - window + 1):
                chunk = all_distances[i:i+window]
                rolling_stds.append(np.std(chunk))
            mean_std = float(np.mean(rolling_stds))
        else:
            mean_std = float(np.std(all_distances))
            
        consistency_score = max(0.0, min(100.0, 100.0 * (1.0 - mean_std * 5.0)))
        
        if consistency_score > 80:
            c_desc = "Highly smooth and predictable cursor/camera tracking."
        elif consistency_score > 50:
            c_desc = "Moderate consistency with occasional erratic jitter."
        else:
            c_desc = "Erratic and unpredictable movements detected."

        # ------------------------------------------------------------
        # (B) Reaction Speed
        # ------------------------------------------------------------
        reaction_frames = []
        i = 0
        while i < len(all_distances):
            if all_distances[i] > 0.3:
                # Key moment found — count frames until stability (<0.15)
                # Cap the lookahead locally to prevent infinite while-indexing
                frames_to_stablize = 0
                j = i + 1
                while j < len(all_distances) and all_distances[j] >= 0.15:
                    frames_to_stablize += 1
                    j += 1
                reaction_frames.append(frames_to_stablize)
                i = j  # Jump ahead
            else:
                i += 1
                
        if reaction_frames:
            avg_reaction = float(np.mean(reaction_frames))
            reaction_score = max(0.0, min(100.0, 100.0 - avg_reaction * 15.0))
            if reaction_score > 70:
                r_desc = "Fast stabilization after sudden stimuli."
            elif reaction_score > 40:
                r_desc = "Average reaction and stabilization time."
            else:
                r_desc = "Slow reset/tracking recovery after sudden events."
        else:
            reaction_score = 50.0
            r_desc = "Insufficient disruptive stimuli to calculate reaction time."

        # ------------------------------------------------------------
        # (C) Positioning (Unsupervised PCA)
        # ------------------------------------------------------------
        flat_emb = embeddings.reshape((num_frames, -1))
        
        # Center the data
        centered = flat_emb - np.mean(flat_emb, axis=0)
        
        try:
            # SVD acts as PCA here
            U, S, Vh = np.linalg.svd(centered, full_matrices=False)
            variances = (S ** 2) / max(1, (num_frames - 1))
            total_var = np.sum(variances)
            
            # Use top 2 components as proxy for 'area covered'
            if total_var > 0:
                top_2_var_ratio = np.sum(variances[:2]) / total_var
            else:
                top_2_var_ratio = 0.5
                
            # Optimal variance is an inverted U peaking at 0.5
            pos_score = max(0.0, min(100.0, 100.0 * (1.0 - abs(top_2_var_ratio - 0.5) * 2.0)))
        except np.linalg.LinAlgError:
            # Fallback if SVD fails to converge on edge cases
            pos_score = 50.0
            
        if pos_score > 75:
            p_desc = "Excellent use of the playable area and intelligent framing."
        elif pos_score > 40:
            p_desc = "Standard map traversal and framing execution."
        else:
            p_desc = "Overly stagnant positioning or exclusively manic motion."

        # ------------------------------------------------------------
        # (D) Decision Quality
        # ------------------------------------------------------------
        smooth_count = sum(1 for d in all_distances if d < 0.15)
        sharp_count = sum(1 for d in all_distances if d > 0.4)
        
        ratio = smooth_count / max(1, smooth_count + sharp_count)
        dec_score = max(0.0, min(100.0, ratio * 100.0))
        
        if dec_score > 80:
            d_desc = "Movements appear highly controlled, intentional, and deliberate."
        elif dec_score > 40:
            d_desc = "A mix of intentional setups padded with forced reactive movements."
        else:
            d_desc = "Predominantly reactive, panicked, or uncontrolled transitions."

        return [
            {"pattern_name": "consistency", "score": round(consistency_score, 1), "description": c_desc},
            {"pattern_name": "reaction_speed", "score": round(reaction_score, 1), "description": r_desc},
            {"pattern_name": "positioning", "score": round(pos_score, 1), "description": p_desc},
            {"pattern_name": "decision_quality", "score": round(dec_score, 1), "description": d_desc}
        ]

    def compute_overall_score(self, key_moments: list[dict], movement_patterns: list[dict]) -> float:
        """Combine specific skill metrics and event confidence into a single 0-100 score."""
        weights = {
            "consistency": 0.30, 
            "reaction_speed": 0.20, 
            "positioning": 0.25, 
            "decision_quality": 0.25
        }
        
        pattern_dict = {p["pattern_name"]: p["score"] for p in movement_patterns}
        
        # Handle cases where certain patterns don't exist by redistributing weight
        active_weights = {k: v for k, v in weights.items() if k in pattern_dict}
        weight_sum = sum(active_weights.values())
        
        if weight_sum <= 0:
            return 50.0
            
        normalized_weights = {k: v / weight_sum for k, v in active_weights.items()}
        
        base_score = sum(pattern_dict[k] * normalized_weights[k] for k in normalized_weights)
        
        # Boost based on active engagement
        if len(key_moments) >= 3:
            avg_conf = sum(m["confidence"] for m in key_moments) / len(key_moments)
            if avg_conf > 0.6:
                base_score += 5.0
                
        return min(100.0, max(0.0, round(base_score, 1)))

    def generate_coaching_text(self, analysis_data: dict, game_type: str = "general") -> list[str]:
        """Convert mathematical analysis into plain-text advice.
        
        Uses Gemini API if a key was provided during initialization.
        Otherwise falls back onto a strict heuristic approach string builder.
        """
        # Create a stable hash of the scores for deduplication
        fingerprint_string = (
            f"{analysis_data.get('overall_score', 0)}" + 
            "".join(f"{v:.1f}" for v in analysis_data.get('patterns', {}).values())
        )
        cache_key = hashlib.md5(fingerprint_string.encode('utf-8')).hexdigest()
        
        if cache_key in self._tip_cache:
            return self._tip_cache[cache_key]

        # Try Gemini API if available
        if self.gemini_api_key:
            patterns = analysis_data.get("patterns", {})
            p_cons = patterns.get("consistency", 50)
            p_react = patterns.get("reaction_speed", 50)
            p_pos = patterns.get("positioning", 50)
            p_dec = patterns.get("decision_quality", 50)
            
            prompt = (
                f"You are a concise esports coach. Game: {game_type}. "
                f"Player stats: overall={analysis_data.get('overall_score', 50)}, "
                f"consistency={p_cons}, reaction_speed={p_react}, "
                f"positioning={p_pos}, decision_quality={p_dec}. "
                f"Key moments: {analysis_data.get('key_moment_count', 0)} detected. "
                f"Give exactly 4 actionable one-sentence coaching tips as a JSON array of strings."
            )
            
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={self.gemini_api_key}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {
                    "temperature": 0.4,
                    "maxOutputTokens": 300,
                    "responseMimeType": "application/json"
                }
            }
            
            try:
                responses = httpx.post(url, json=payload, timeout=10.0)
                responses.raise_for_status()
                
                resp_json = responses.json()
                text_content = resp_json["candidates"][0]["content"]["parts"][0]["text"]
                
                # Gemini explicitly asked to return JSON array of strings via mimeType
                tips = json.loads(text_content)
                if isinstance(tips, list) and len(tips) >= 4:
                    out = [str(t) for t in tips[:4]]
                    self._tip_cache[cache_key] = out
                    return out
            except Exception as e:
                logger.warning(f"Gemini API generation failed ({e}). Falling back to heuristics.")
                
        # ------------------------------------------------------------
        # Heuristic fallback
        # ------------------------------------------------------------
        patterns_list = [{"name": k, "score": v} for k, v in analysis_data.get("patterns", {}).items()]
        # If absolutely empty due to malformed input, stub it:
        if not patterns_list:
            patterns_list = [
                {"name": "consistency", "score": 50},
                {"name": "reaction_speed", "score": 50},
                {"name": "positioning", "score": 50},
                {"name": "decision_quality", "score": 50}
            ]
            
        patterns_list.sort(key=lambda x: x["score"])
        
        worst = patterns_list[0]
        second_worst = patterns_list[1]
        best = patterns_list[-1]
        
        tips = []
        overall = analysis_data.get('overall_score', 50)
        
        # Tip 1: Overall summary
        if overall > 80:
            tips.append(f"Outstanding performance overall (Score: {overall}), keep refining your specialized mechanics.")
        elif overall > 50:
            tips.append(f"Solid foundation (Score: {overall}), but there is clear room for mechanical improvement.")
        else:
            tips.append(f"Focus on fundamentals right now; your overall score ({overall}) indicates erratic performance.")
            
        # Tip 2: The Best Pattern (Reinforcement)
        tips.append(f"Your {best['name'].replace('_', ' ')} is great (Score: {best['score']}) — actively rely on it during matches.")
        
        # Tip 3 & 4: Needs Improvement
        improvement_prompts = {
            "consistency": "Work on smooth, predictable camera tracking rather than snapping wildly.",
            "reaction_speed": "You are recovering too slowly after engagements; snap back to neutral faster.",
            "positioning": "You are either sitting too still or moving without purpose; practice framing.",
            "decision_quality": "Stop panic-reacting to stimuli and focus on deliberate, intentional movement."
        }
        
        tips.append(f"Your {worst['name'].replace('_', ' ')} score of {worst['score']} is holding you back: {improvement_prompts.get(worst['name'], '')}")
        tips.append(f"Additionally, regarding {second_worst['name'].replace('_', ' ')} (Score: {second_worst['score']}): {improvement_prompts.get(second_worst['name'], '')}")
        
        # Guarantee 4 strings exactly as requested
        # Even if the logic broke, pad to 4.
        while len(tips) < 4:
            tips.append("Continue practicing consistently to gather more data.")
            
        self._tip_cache[cache_key] = tips[:4]
        return tips[:4]

    def full_analysis(self, embeddings: np.ndarray, video_duration: float, game_type: str = "general") -> dict:
        """Run the full interpretation pipeline wrapping moments, stats, and text generation.
        
        Args:
            embeddings: Tensor representing the full clip representations.
            video_duration: In seconds.
            game_type: Metadata string to guide LLM contextualisation.
            
        Returns:
            Dict containing key_moments, movement_patterns, overall_score, and recommendations.
        """
        # Input validation guard against NaN tensors (recast any NaNs safely to 0 bounds)
        if not isinstance(embeddings, np.ndarray):
            embeddings = np.array(embeddings)
            
        safe_embeddings = np.nan_to_num(embeddings, nan=0.0, posinf=0.0, neginf=0.0)
        
        key_moments = self.detect_key_moments(safe_embeddings, video_duration)
        movement_patterns = self.analyze_movement_patterns(safe_embeddings)
        overall_score = self.compute_overall_score(key_moments, movement_patterns)
        
        analysis_data_context = {
            "overall_score": overall_score,
            "patterns": {p["pattern_name"]: p["score"] for p in movement_patterns},
            "key_moment_count": len(key_moments)
        }
        
        recommendations = self.generate_coaching_text(analysis_data_context, game_type=game_type)
        
        return {
            "key_moments": key_moments,
            "movement_patterns": movement_patterns,
            "overall_score": overall_score,
            "recommendations": recommendations
        }
