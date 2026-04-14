---
name: vjepa2-inference
description: "V-JEPA 2 model inference patterns. Activates when working with video embeddings, PyTorch GPU optimization, VJEPAEngine class, or model loading. Do not use for general Python or Android tasks."
---

# V-JEPA 2 Inference Skill

## Model Loading
- Load via: torch.hub.load('facebookresearch/vjepa2', 'vjepa2_vit_large')
- Convert: model.half().eval().to('cuda')
- Singleton pattern — load once at FastAPI lifespan startup
- Warmup with dummy tensor after loading to trigger CUDA kernel compilation

## Input Format
- Tensor shape: (1, 3, num_frames, 224, 224) in float16
- Normalize: mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
- Video divided into 3D tubelets: 2 frames x 16x16 pixels
- Max 16 frames at 224x224 on 6GB VRAM

## Memory Safety
- ALWAYS torch.inference_mode() context manager
- ALWAYS torch.cuda.empty_cache() immediately after inference
- If CUDA OOM: catch RuntimeError, reduce to 8 frames, retry ONCE, then CPU fallback
- Monitor via torch.cuda.memory_allocated() and torch.cuda.max_memory_allocated()
- NEVER batch_size > 1 on 6GB VRAM
- Use torch.cuda.synchronize() before timing measurements

## CPU Fallback
- If torch.cuda.is_available() returns False, use CPU with warning log
- Set inference_device field in API response to indicate device used

## Do not use
- For general Python coding
- For Android/Kotlin code  
- For FastAPI routing logic
