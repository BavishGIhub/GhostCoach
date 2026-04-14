"""
V-JEPA 2 Inference Engine for Ghost Coach.
Handles model loading, video preprocessing, and feature extraction
optimized for GTX 1660 Ti (6GB VRAM) with FP16 precision.
"""

import logging
import time
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import uuid4

import cv2
import numpy as np
import torch
import torchvision.transforms.functional as TF

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
_MAX_VIDEO_DURATION_SECONDS: int = 30
_HASH_READ_BYTES: int = 1_048_576  # 1 MB for file-hash computation
_MIN_RETRY_FRAMES: int = 8


class VJEPAEngine:
    """Production inference wrapper around Meta V-JEPA 2 ViT-L.

    Designed for constrained VRAM environments (≤ 6 GB).  All inference
    runs in FP16 on CUDA with automatic OOM recovery (reduce frames →
    CPU fallback).  Results are cached by SHA-256 of the first 1 MB of
    the source video file.
    """

    # ------------------------------------------------------------------
    # Initialisation
    # ------------------------------------------------------------------
    def __init__(
        self,
        model_name: str = "vjepa2_vit_large",
        device: str = "auto",
        num_frames: int = 16,
        resolution: int = 224,
    ) -> None:
        """Initialise the engine **without** loading the model.

        Args:
            model_name: ``torch.hub`` entry-point name.
            device: ``"cuda"``, ``"cpu"``, or ``"auto"`` (default).
            num_frames: Number of uniformly-sampled frames per clip.
            resolution: Spatial resolution (H=W) for each frame.
        """
        # Device selection ------------------------------------------------
        if device == "auto":
            self.device: str = "cuda" if torch.cuda.is_available() else "cpu"
        else:
            self.device = device

        if self.device == "cpu":
            logger.warning(
                "Running on CPU — inference will be significantly slower "
                "than CUDA.  Consider using a CUDA-capable GPU."
            )

        self.model_name: str = model_name
        self.num_frames: int = num_frames
        self.resolution: int = resolution
        self.dtype: torch.dtype = (
            torch.float16 if self.device == "cuda" else torch.float32
        )

        # Internal state --------------------------------------------------
        self._model: Optional[torch.nn.Module] = None
        self._is_loaded: bool = False
        self._results_cache: dict[str, dict] = {}

        # ImageNet normalisation constants --------------------------------
        self.imagenet_mean: list[float] = [0.485, 0.456, 0.406]
        self.imagenet_std: list[float] = [0.229, 0.224, 0.225]

        logger.info(
            "VJEPAEngine initialised — model=%s  device=%s  dtype=%s  "
            "frames=%d  resolution=%d",
            self.model_name,
            self.device,
            self.dtype,
            self.num_frames,
            self.resolution,
        )

    # ------------------------------------------------------------------
    # Model loading
    # ------------------------------------------------------------------
    def load_model(self) -> None:
        """Download (or locate cached) V-JEPA 2 weights and prepare for inference.

        On CUDA the model is converted to FP16 and a warm-up forward
        pass is executed to trigger kernel compilation.  If a CUDA OOM
        occurs during loading the engine transparently falls back to CPU.
        """
        logger.info(
            "Loading V-JEPA 2 model: %s on %s …", self.model_name, self.device
        )

        try:
            self._model = torch.hub.load(
                "facebookresearch/vjepa2", self.model_name
            )
            self._model.eval()

            if self.device == "cuda":
                self._model.half().to(self.device)
            else:
                self._model.to(self.device)

            param_count: int = sum(
                p.numel() for p in self._model.parameters()
            )
            logger.info(
                "Model loaded.  Parameters: %.1fM", param_count / 1e6
            )

            # Warm-up pass ------------------------------------------------
            self._warmup()

            if self.device == "cuda":
                mem_mb: float = torch.cuda.memory_allocated() / 1024**2
                logger.info("GPU memory after warmup: %.1f MB", mem_mb)

            self._is_loaded = True

        except torch.cuda.OutOfMemoryError:
            logger.error(
                "CUDA OOM during model loading.  Falling back to CPU."
            )
            torch.cuda.empty_cache()
            self.device = "cpu"
            self.dtype = torch.float32
            # Retry on CPU
            self._model = torch.hub.load(
                "facebookresearch/vjepa2", self.model_name
            )
            self._model.eval().to(self.device)
            self._warmup()
            self._is_loaded = True
            logger.info("Model loaded on CPU after CUDA OOM fallback.")

        except Exception as exc:
            logger.exception("Failed to load V-JEPA 2 model.")
            raise RuntimeError(f"Failed to load V-JEPA 2: {exc}") from exc

    def _warmup(self) -> None:
        """Run a single dummy forward pass to compile CUDA kernels."""
        logger.info("Running warm-up inference …")
        dummy = torch.zeros(
            1,
            3,
            self.num_frames,
            self.resolution,
            self.resolution,
            dtype=self.dtype,
            device=self.device,
        )
        with torch.inference_mode():
            output = self._model(dummy)
        del dummy, output
        if self.device == "cuda":
            torch.cuda.empty_cache()
        logger.info("Warm-up complete.")

    # ------------------------------------------------------------------
    # File hashing (for result caching)
    # ------------------------------------------------------------------
    def _compute_file_hash(self, file_path: str) -> str:
        """Return the SHA-256 hex digest of the first 1 MB of *file_path*.

        Args:
            file_path: Absolute or relative path to the video file.

        Returns:
            Hex-encoded SHA-256 hash string.

        Raises:
            FileNotFoundError: If the file does not exist.
        """
        path = Path(file_path)
        if not path.is_file():
            raise FileNotFoundError(f"Video file not found: {path}")
        sha = hashlib.sha256()
        with path.open("rb") as fh:
            sha.update(fh.read(_HASH_READ_BYTES))
        return sha.hexdigest()

    # ------------------------------------------------------------------
    # Video preprocessing
    # ------------------------------------------------------------------
    def preprocess_video(
        self, video_path: str
    ) -> tuple[torch.Tensor, dict]:
        """Read a video file, sample frames, and build a normalised tensor.

        Args:
            video_path: Path to the source video.

        Returns:
            A tuple of ``(video_tensor, metadata)`` where
            ``video_tensor`` has shape ``(1, 3, num_frames, H, W)`` in
            ``self.dtype`` on CPU, and ``metadata`` is a dict describing
            the source clip.

        Raises:
            FileNotFoundError: If the path does not exist.
            ValueError: If the video exceeds the duration limit or has
                fewer frames than ``self.num_frames``.
        """
        path = Path(video_path)
        if not path.is_file():
            raise FileNotFoundError(f"Video file not found: {path}")

        cap = cv2.VideoCapture(str(path))
        try:
            total_frames: int = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            fps: float = cap.get(cv2.CAP_PROP_FPS) or 30.0
            duration: float = total_frames / fps if fps > 0 else 0.0

            if duration > _MAX_VIDEO_DURATION_SECONDS:
                raise ValueError(
                    f"Video duration {duration:.1f}s exceeds the "
                    f"{_MAX_VIDEO_DURATION_SECONDS}s limit."
                )
            if total_frames < self.num_frames:
                raise ValueError(
                    f"Video has {total_frames} frames but at least "
                    f"{self.num_frames} are required."
                )

            # Uniform temporal sampling -----------------------------------
            frame_indices: np.ndarray = np.linspace(
                0, total_frames - 1, self.num_frames, dtype=int
            )

            frames: list[np.ndarray] = []
            for idx in frame_indices:
                cap.set(cv2.CAP_PROP_POS_FRAMES, int(idx))
                ret, frame = cap.read()
                if ret:
                    # BGR → RGB
                    frames.append(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                elif frames:
                    # Duplicate the last valid frame as a fallback
                    logger.warning(
                        "Could not read frame %d — duplicating previous frame.",
                        idx,
                    )
                    frames.append(frames[-1].copy())
                else:
                    raise RuntimeError(
                        f"Failed to read the very first sampled frame "
                        f"(index {idx}) from {path}."
                    )
        finally:
            cap.release()

        # Spatial transforms per frame ------------------------------------
        processed: list[torch.Tensor] = []
        for frame in frames:
            # HWC uint8 → CHW float32 in [0, 1]
            tensor = torch.from_numpy(frame).permute(2, 0, 1).float() / 255.0
            # Resize so the shorter side == resolution, then centre crop
            tensor = TF.resize(
                tensor,
                [self.resolution, self.resolution],
                antialias=True,
            )
            tensor = TF.center_crop(tensor, [self.resolution, self.resolution])
            # ImageNet normalisation
            tensor = TF.normalize(
                tensor, mean=self.imagenet_mean, std=self.imagenet_std
            )
            processed.append(tensor)

        # (num_frames, 3, H, W) → (3, num_frames, H, W) → (1, 3, T, H, W)
        stacked = torch.stack(processed, dim=0)  # (T, 3, H, W)
        video_tensor = stacked.permute(1, 0, 2, 3).unsqueeze(0)  # (1,3,T,H,W)
        video_tensor = video_tensor.to(dtype=self.dtype)

        metadata: dict = {
            "duration": round(duration, 2),
            "fps": round(fps, 1),
            "total_frames": total_frames,
            "frames_sampled": self.num_frames,
        }
        logger.info("Video preprocessed — %s", metadata)
        return video_tensor, metadata

    # ------------------------------------------------------------------
    # Feature extraction
    # ------------------------------------------------------------------
    def extract_features(self, video_tensor: torch.Tensor) -> torch.Tensor:
        """Run V-JEPA 2 forward pass and return embeddings on CPU.

        Includes automatic OOM recovery: first retries with 8 frames,
        then falls back to CPU inference.

        Args:
            video_tensor: Tensor of shape ``(1, 3, T, H, W)``.

        Returns:
            Embedding tensor on CPU (detached from the compute graph).

        Raises:
            RuntimeError: If the model is not loaded or an unrecoverable
                error occurs.
            TypeError: If the model returns an unexpected output type.
        """
        if not self._is_loaded:
            raise RuntimeError(
                "Model is not loaded. Call load_model() first."
            )
        if video_tensor.ndim != 5 or video_tensor.shape[0] != 1:
            raise ValueError(
                f"Expected tensor of shape (1, 3, T, H, W), "
                f"got {video_tensor.shape}."
            )

        video_tensor = video_tensor.to(device=self.device, dtype=self.dtype)
        start: float = time.perf_counter()

        try:
            with torch.inference_mode():
                if self.device == "cuda":
                    with torch.amp.autocast(
                        device_type="cuda", dtype=torch.float16
                    ):
                        output = self._model(video_tensor)
                else:
                    output = self._model(video_tensor)

            if self.device == "cuda":
                torch.cuda.synchronize()

            elapsed: float = time.perf_counter() - start

            if self.device == "cuda":
                torch.cuda.empty_cache()

            # Normalise model output --------------------------------------
            embeddings = self._unwrap_output(output)

            logger.info(
                "Inference done in %.3fs.  Output shape: %s",
                elapsed,
                list(embeddings.shape),
            )
            if self.device == "cuda":
                peak_mb: float = torch.cuda.max_memory_allocated() / 1024**2
                logger.info("Peak VRAM usage: %.1f MB", peak_mb)

            return embeddings.detach().cpu()

        except RuntimeError as exc:
            return self._handle_inference_oom(exc, video_tensor)

    # ------------------------------------------------------------------
    # OOM recovery helpers
    # ------------------------------------------------------------------
    def _handle_inference_oom(
        self, exc: RuntimeError, video_tensor: torch.Tensor
    ) -> torch.Tensor:
        """Handle CUDA OOM during feature extraction.

        Strategy:
        1. If current frame count > 8 → retry with 8 frames.
        2. If already at ≤ 8 frames  → fall back to CPU.
        3. For non-OOM errors        → re-raise immediately.
        """
        if "out of memory" not in str(exc).lower():
            raise exc

        current_frames: int = video_tensor.shape[2]

        if current_frames > _MIN_RETRY_FRAMES:
            logger.warning(
                "CUDA OOM with %d frames.  Retrying with %d frames …",
                current_frames,
                _MIN_RETRY_FRAMES,
            )
            torch.cuda.empty_cache()
            reduced = video_tensor[:, :, :_MIN_RETRY_FRAMES, :, :]
            return self.extract_features(reduced)

        # Already at minimum — move everything to CPU
        logger.error(
            "CUDA OOM even at %d frames.  Falling back to CPU.",
            current_frames,
        )
        torch.cuda.empty_cache()
        self.device = "cpu"
        self.dtype = torch.float32
        self._model.float().to("cpu")
        video_tensor = video_tensor.float().to("cpu")

        with torch.inference_mode():
            output = self._model(video_tensor)

        embeddings = self._unwrap_output(output)
        return embeddings.detach()

    @staticmethod
    def _unwrap_output(output: object) -> torch.Tensor:
        """Extract the embedding tensor from whatever the model returns.

        Args:
            output: Raw model output (``Tensor``, ``dict``, or similar).

        Returns:
            The embedding ``Tensor``.

        Raises:
            TypeError: If the output type is not recognised.
        """
        if isinstance(output, torch.Tensor):
            return output
        if isinstance(output, dict):
            for key in ("x", "encoder_out"):
                if key in output:
                    return output[key]
            # Fall through to the first value
            return next(iter(output.values()))
        raise TypeError(f"Unexpected model output type: {type(output)}")

    # ------------------------------------------------------------------
    # Full analysis pipeline
    # ------------------------------------------------------------------
    def analyze(self, video_path: str) -> dict:
        """Run the end-to-end analysis on a single video file.

        Results are cached by file hash so repeated calls on the same
        file are essentially free.

        Args:
            video_path: Path to the source video.

        Returns:
            A dict containing analysis_id, embedding_shape,
            processing_time_seconds, inference_device, video_metadata,
            and a UTC ISO-8601 timestamp.
        """
        file_hash: str = self._compute_file_hash(video_path)

        if file_hash in self._results_cache:
            logger.info("Cache hit for %s", file_hash[:12])
            return self._results_cache[file_hash]

        start: float = time.perf_counter()
        video_tensor, metadata = self.preprocess_video(video_path)
        embeddings = self.extract_features(video_tensor)
        elapsed: float = round(time.perf_counter() - start, 3)

        result: dict = {
            "analysis_id": str(uuid4()),
            "embedding_shape": list(embeddings.shape),
            "embeddings_numpy": embeddings.numpy().tolist(),
            "processing_time_seconds": elapsed,
            "inference_device": str(self.device),
            "num_frames_processed": metadata["frames_sampled"],
            "video_metadata": metadata,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        self._results_cache[file_hash] = result
        logger.info(
            "Analysis complete in %ss on %s", elapsed, self.device
        )
        return result

    # ------------------------------------------------------------------
    # Health / readiness
    # ------------------------------------------------------------------
    def get_health(self) -> dict:
        """Return a health-check dict suitable for the ``/health`` endpoint.

        Returns:
            A dict with model_loaded, device, model_name, and optional
            GPU memory statistics when running on CUDA.
        """
        health: dict = {
            "model_loaded": self._is_loaded,
            "device": str(self.device),
            "model_name": self.model_name,
        }
        if torch.cuda.is_available() and self._is_loaded:
            health["gpu_memory_used_mb"] = round(
                torch.cuda.memory_allocated() / 1024**2, 1
            )
            health["gpu_memory_total_mb"] = round(
                torch.cuda.get_device_properties(0).total_mem / 1024**2, 1
            )
        return health

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------
    @property
    def is_loaded(self) -> bool:
        """Whether the model has been successfully loaded and is ready."""
        return self._is_loaded
