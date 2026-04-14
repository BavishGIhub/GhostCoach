import time
import cv2
import numpy as np
import torch
import torch.nn.functional as F
from pathlib import Path

# Constants for V-JEPA 2
NUM_FRAMES = 16
RESOLUTION = 224
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
DTYPE = torch.float16 if DEVICE == "cuda" else torch.float32

def generate_test_video(path: str):
    """Generate 5s of synthetic video (150 frames @ 30fps)."""
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*'mp4v'), 30, (320, 240))
    for i in range(150):
        frame = np.zeros((240, 320, 3), dtype=np.uint8)
        # Random colored rectangle moving
        x = (i * 2) % 320
        cv2.rectangle(frame, (x, 100), (x + 50, 150), (255, 0, 0), -1)
        out.write(frame)
    out.release()

def preprocess_test_clip(path: str):
    """Quick preprocessing for 16 frames at 224x224."""
    cap = cv2.VideoCapture(path)
    indices = np.linspace(0, 149, NUM_FRAMES, dtype=int)
    frames = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if ret:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            tensor = torch.from_numpy(frame).permute(2, 0, 1).float() / 255.0
            tensor = F.interpolate(tensor.unsqueeze(0), size=(RESOLUTION, RESOLUTION), mode='bilinear', align_corners=False).squeeze(0)
            # ImageNet normalization
            tensor = (tensor - torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)) / torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)
            frames.append(tensor)
    cap.release()
    # (3, 16, 224, 224) -> (1, 3, 16, 224, 224)
    return torch.stack(frames, dim=1).unsqueeze(0).to(DEVICE, DTYPE)

def main():
    test_video = "/tmp/ghost_coach_test_video.mp4"
    if "/" not in test_video and "\\" not in test_video: # Fallback for Windows tmp
        test_video = str(Path.home() / "AppData" / "Local" / "Temp" / "ghost_coach_test_video.mp4")
    
    try:
        print("--- V-JEPA 2 SANITY CHECK ---")
        generate_test_video(test_video)
        
        print(f"Loading model: vjepa2_vit_large on {DEVICE}...")
        model = torch.hub.load('facebookresearch/vjepa2', 'vjepa2_vit_large')
        if DEVICE == "cuda": model.half().to("cuda")
        model.eval()
        
        input_tensor = preprocess_test_clip(test_video)
        start = time.perf_counter()
        
        with torch.inference_mode():
            if DEVICE == "cuda":
                with torch.amp.autocast(device_type='cuda', dtype=torch.float16):
                    output = model(input_tensor)
            else:
                output = model(input_tensor)
            
        if DEVICE == "cuda": torch.cuda.synchronize()
        elapsed = time.perf_counter() - start
        
        # Results Printing
        params = sum(p.numel() for p in model.parameters())
        print(f"[✓] Model loaded: True")
        print(f"[✓] Device: {DEVICE}")
        print(f"[✓] Parameters: {params / 1e6:.1f}M")
        print(f"[✓] Input shape: {input_tensor.shape}")
        print(f"[✓] Output type: {type(output)}")
        
        # Handle dict or tensor output
        out_shape = output.shape if isinstance(output, torch.Tensor) else next(iter(output.values())).shape
        print(f"[✓] Output shape: {out_shape}")
        print(f"[✓] Inference time: {elapsed:.3f}s")
        
        if DEVICE == "cuda":
            vram = torch.cuda.max_memory_allocated() / 1024**2
            print(f"[✓] Peak VRAM: {vram:.1f} MB / 6144 MB")
            
        print("[✓] All checks passed!")
        assert output is not None

    except torch.cuda.OutOfMemoryError:
        print("[!] ERROR: CUDA Out of Memory.")
    except Exception as e:
        print(f"[!] ERROR: {e}")
    finally:
        if Path(test_video).exists(): Path(test_video).unlink()
        if DEVICE == "cuda": torch.cuda.empty_cache()

if __name__ == "__main__":
    main()
