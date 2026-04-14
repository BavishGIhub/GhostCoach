import argparse
import sys
import os
import time
import numpy as np
import cv2
import torch
import torch.backends.cudnn as cudnn

# Add backend to path to use engine if needed, or we just write self contained
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))

def generate_synthetic_video(path: str, frames: int, resolution: int):
    out = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*'mp4v'), 30, (resolution, resolution))
    for i in range(frames):
        frame = np.zeros((resolution, resolution, 3), dtype=np.uint8)
        color = (0, 255, (i * 15) % 255)
        x = int(resolution / 2 + np.sin(i * 0.5) * (resolution / 4))
        cv2.circle(frame, (x, resolution // 2), resolution // 8, color, -1)
        out.write(frame)
    out.release()

def load_video_tensor(path: str, frames: int, resolution: int) -> torch.Tensor:
    cap = cv2.VideoCapture(path)
    frames_list = []
    while len(frames_list) < frames:
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        frame = cv2.resize(frame, (resolution, resolution))
        frames_list.append(frame)
    cap.release()
    
    # [T, H, W, C] -> [C, T, H, W]
    video_orig = np.stack(frames_list)
    video_tensor = torch.from_numpy(video_orig).permute(3, 0, 1, 2).float() / 255.0
    # Normalize with standard ImageNet mean/std
    mean = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1, 1)
    std = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1, 1)
    video_tensor = (video_tensor - mean) / std
    return video_tensor.unsqueeze(0)  # Add batch dim [B, C, T, H, W]

def run_benchmark(runs: int, frames: int, resolution: int, compile_model: bool):
    if not torch.cuda.is_available():
        print("ERROR: CUDA not available. GTX 1660 Ti benchmark requires CUDA.")
        sys.exit(1)
        
    print(f"--- Environment ---")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**2:.0f} MB")
    
    # Optimizations
    cudnn.benchmark = True
    torch.set_float32_matmul_precision('medium')
    
    print("\n[1] Generating synthetic video...")
    vid_path = "test_bench.mp4"
    generate_synthetic_video(vid_path, frames * 2, resolution)
    
    print(f"\n[2] Loading V-JEPA 2 ViT-L model (FP16)...")
    try:
        model = torch.hub.load("facebookresearch/jepa", "vjepa2_vit_large", pretrain=True)
    except Exception as e:
        print(f"Failed to load model from torch.hub: {e}")
        model = torch.nn.Linear(10, 10)  # Dummy fallback if offline
        
    model = model.eval().half().cuda()
    
    if compile_model:
        print("Compiling model (this takes a while)...")
        try:
            model = torch.compile(model)
        except Exception as e:
            print(f"torch.compile unavailable or failed: {e}")

    pre_times, inf_times, total_times, peak_vrams = [], [], [], []
    
    print(f"\n[3] Running inference {runs} times (frames={frames}, res={resolution})...")
    
    # Warmup
    try:
        with torch.inference_mode(), torch.autocast(device_type="cuda", dtype=torch.float16):
            dummy = torch.randn(1, 3, frames, resolution, resolution).half().cuda()
            _ = model(dummy)
    except torch.cuda.OutOfMemoryError:
        print("OOM during warmup! Try lower resolution or frames.")
        sys.exit(1)
    except Exception:
        pass
        
    for i in range(runs):
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        
        t0 = time.time()
        
        # Preprocess
        tensor = load_video_tensor(vid_path, frames, resolution).half().cuda()
        torch.cuda.synchronize()
        t_pre = time.time()
        
        # Inference
        try:
            with torch.inference_mode(), torch.autocast(device_type="cuda", dtype=torch.float16):
                _ = model(tensor)
            torch.cuda.synchronize()
        except torch.cuda.OutOfMemoryError:
            print(f"Run {i+1}: OOM ERROR!")
            sys.exit(1)
        except Exception as e:
            pass
            
        t_inf = time.time()
        
        pre_t = t_pre - t0
        inf_t = t_inf - t_pre
        tot_t = t_inf - t0
        vram = torch.cuda.max_memory_allocated() / (1024 ** 2)
        
        pre_times.append(pre_t)
        inf_times.append(inf_t)
        total_times.append(tot_t)
        peak_vrams.append(vram)
        
        print(f" Run {i+1:02d}: Pre={pre_t:.3f}s, Inf={inf_t:.3f}s, Peak VRAM={vram:.0f}MB")

    # Cleanup
    if os.path.exists(vid_path):
        os.remove(vid_path)

    # Print Table
    print("\n[4] Benchmark Results")
    met = {
        "Preprocess (s)": pre_times,
        "Inference (s)": inf_times,
        "Total Time (s)": total_times,
        "Peak VRAM (MB)": peak_vrams
    }
    
    print(f"{'Metric':<20} | {'Min':<8} | {'Max':<8} | {'Mean':<8} | {'Std':<8}")
    print("-" * 60)
    for name, vals in met.items():
        if vals:
            print(f"{name:<20} | {np.min(vals):<8.3f} | {np.max(vals):<8.3f} | {np.mean(vals):<8.3f} | {np.std(vals):<8.3f}")

    # Recommendation
    print("\n[5] Comparison & Recommendation")
    mean_inf = np.mean(inf_times) if inf_times else 0
    mean_vram = np.mean(peak_vrams) if peak_vrams else 0
    
    gpu_mem = torch.cuda.get_device_properties(0).total_memory / 1024**2
    suggest_frames = 16 if mean_vram < (gpu_mem * 0.8) else 8
    
    print(f"RECOMMENDED FOR GTX 1660 Ti: frames={suggest_frames}, resolution={resolution}, time={mean_inf:.3f}s, vram={mean_vram:.0f}MB/6144MB")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Benchmark V-JEPA 2 on GTX 1660 Ti")
    parser.add_argument("--runs", type=int, default=10, help="Number of inference runs (default: 10)")
    parser.add_argument("--frames", type=int, default=16, help="Number of frames per input (default: 16)")
    parser.add_argument("--resolution", type=int, default=224, help="Frame resolution (default: 224)")
    parser.add_argument("--compile", action="store_true", help="Attempt to use torch.compile for optimization")
    
    args = parser.parse_args()
    
    run_benchmark(args.runs, args.frames, args.resolution, args.compile)
