import pytest
import numpy as np
from app.services.analysis import GameplayAnalyzer

def test_full_analysis_pipeline():
    analyzer = GameplayAnalyzer(gemini_api_key="dummy_key")
    
    # Create realistic embeddings: 16 frames, 1024-dim
    embeddings = np.zeros((16, 1024), dtype=np.float32)
    # 2 sudden changes
    embeddings[5] = np.random.rand(1024).astype(np.float32) * 5
    embeddings[12] = np.random.rand(1024).astype(np.float32) * -5
    
    result = analyzer.full_analysis(embeddings, video_duration=5.0, game_type="general")
    
    assert "key_moments" in result
    assert "movement_patterns" in result
    assert "overall_score" in result
    assert "recommendations" in result
    
    assert len(result["movement_patterns"]) == 4
    assert 0 <= result["overall_score"] <= 100
    assert len(result["recommendations"]) == 4

def test_gemini_api_fallback():
    # Invalid key so it should fall back to heuristics
    analyzer = GameplayAnalyzer(gemini_api_key="invalid")
    
    # Simple steady embeddings
    embeddings = np.random.rand(16, 1024).astype(np.float32)
    
    result = analyzer.full_analysis(embeddings, video_duration=5.0, game_type="general")
    
    # Verify we still got 4 tips exactly from the fallback heuristics
    assert len(result["recommendations"]) == 4
    assert isinstance(result["recommendations"][0], str)
    assert len(result["recommendations"][0]) > 0
