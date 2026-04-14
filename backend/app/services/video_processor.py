"""
Video preprocessing service for Ghost Coach.
Handles file validation, frame extraction, and tensor preparation for V-JEPA 2.
"""

import logging
from pathlib import Path
from typing import Any
from uuid import uuid4

import cv2
import numpy as np
import torch
import torchvision.transforms.functional as TF

logger = logging.getLogger(__name__)

SUPPORTED_FORMATS = {".mp4", ".mkv", ".webm", ".avi", ".mov"}
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


class VideoProcessor:
    """Preprocesses gameplay videos before V-JEPA 2 inference."""

    @staticmethod
    def validate_video(
        file_path: str, max_duration_seconds: int = 30, max_size_mb: int = 100
    ) -> dict[str, Any]:
        """Validate an uploaded video file against size, format, and structure constraints.

        Args:
            file_path: Absolute or relative path to the video file.
            max_duration_seconds: Maximum allowed video length in seconds.
            max_size_mb: Maximum allowed file size in megabytes.

        Returns:
            A dictionary with:
                - is_valid (bool): True if validations pass, False otherwise.
                - error (str | None): Description of the error if invalid.
                - metadata (dict): Video specs (duration, fps, width, height, etc.).
        """
        path = Path(file_path)
        metadata = {
            "duration": 0.0,
            "fps": 0.0,
            "width": 0,
            "height": 0,
            "total_frames": 0,
            "file_size_mb": 0.0,
        }
        res = {"is_valid": False, "error": None, "metadata": metadata}

        if not path.is_file():
            res["error"] = "File does not exist."
            return res

        size_mb = path.stat().st_size / (1024 * 1024)
        metadata["file_size_mb"] = round(size_mb, 2)

        if size_mb > max_size_mb:
            res["error"] = f"File size ({size_mb:.1f}MB) exceeds {max_size_mb}MB limit."
            return res

        if path.suffix.lower() not in SUPPORTED_FORMATS:
            res["error"] = f"Unsupported format: {path.suffix}. Must be one of {SUPPORTED_FORMATS}."
            return res

        cap = cv2.VideoCapture(str(path))
        try:
            if not cap.isOpened():
                res["error"] = "Failed to open video file (corrupt or unsupported codec)."
                return res

            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            fps = cap.get(cv2.CAP_PROP_FPS)
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            
            if fps <= 0 or total_frames <= 0:
                res["error"] = "Video contains no readable frames or invalid FPS."
                return res
                
            duration = total_frames / fps
            
            metadata["duration"] = round(duration, 2)
            metadata["fps"] = round(fps, 2)
            metadata["width"] = width
            metadata["height"] = height
            metadata["total_frames"] = total_frames

            if duration > max_duration_seconds:
                res["error"] = f"Video duration ({duration:.1f}s) exceeds {max_duration_seconds}s limit."
                return res

            res["is_valid"] = True

        except Exception as e:
            res["error"] = f"Unexpected error while validating video: {e}"
            return res
        finally:
            cap.release()

        return res

    @staticmethod
    def extract_frames(file_path: str, num_frames: int = 16) -> list[np.ndarray]:
        """Uniformly sample frames from a video file.

        Args:
            file_path: Path to the video file.
            num_frames: Number of frames to extract.

        Returns:
            A list of ``num_frames`` numpy arrays of shape (H, W, 3) in RGB format.

        Raises:
            FileNotFoundError: If the file does not exist.
            ValueError: If the file cannot be opened or contains fewer readable
                frames than requested, or 0 frames.
        """
        path = Path(file_path)
        if not path.is_file():
            raise FileNotFoundError(f"File not found: {path}")

        cap = cv2.VideoCapture(str(path))
        try:
            if not cap.isOpened():
                raise ValueError("cv2 failed to open video file (corrupt or codec error).")

            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            if total_frames <= 0:
                raise ValueError("Video contains 0 frames.")

            if total_frames < num_frames:
                raise ValueError(
                    f"Video has {total_frames} frames, but {num_frames} were requested."
                )

            indices = np.linspace(0, total_frames - 1, num_frames, dtype=int)
            frames = []

            for idx in indices:
                cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
                ret, frame = cap.read()
                if ret:
                    # Convert BGR (OpenCV default) to RGB
                    frames.append(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                elif frames:
                    logger.warning(
                        f"Failed to read frame at idx {idx}. Duplicating previous frame."
                    )
                    frames.append(frames[-1].copy())
                else:
                    raise ValueError(
                        f"Failed to read the very first frame at index {idx}."
                    )
                    
            if not frames:
                raise ValueError("Successfully opened video, but 0 frames were read.")

            return frames

        finally:
            cap.release()

    @staticmethod
    def prepare_tensor(
        frames: list[np.ndarray], resolution: int = 224, dtype: torch.dtype = torch.float16
    ) -> torch.Tensor:
        """Process extracted RGB frames into a correctly shaped model input tensor.

        Operations per frame:
            1. Convert np.uint8 (H,W,C) to torch.float32 (C,H,W) in range [0, 1].
            2. Resize to (resolution, resolution) using antialiasing.
            3. Center crop to (resolution, resolution).
            4. Normalize with ImageNet mean and std.
        The frames are then stacked and permuted to the shape:
        (1, 3, num_frames, resolution, resolution).

        Args:
            frames: List of extracted numpy frames.
            resolution: Expected spatial dimension (H and W).
            dtype: Target torch data type (e.g. torch.float16 or torch.float32).

        Returns:
            A tensor on the CPU prepared for inference.

        Raises:
            ValueError: If the frames list is empty.
        """
        if not frames:
            raise ValueError("Input frames list is empty.")

        processed: list[torch.Tensor] = []
        for frame in frames:
            # frame is HWC uint8
            # Convert to CHW float32 in [0, 1]
            tensor = torch.from_numpy(frame).permute(2, 0, 1).float() / 255.0
            
            # Resize
            tensor = TF.resize(tensor, [resolution, resolution], antialias=True)
            
            # Center crop
            tensor = TF.center_crop(tensor, [resolution, resolution])
            
            # Normalize
            tensor = TF.normalize(tensor, mean=IMAGENET_MEAN, std=IMAGENET_STD)
            
            processed.append(tensor)

        # Stack to shape (num_frames, 3, H, W)
        stacked = torch.stack(processed, dim=0)
        
        # Permute to (3, num_frames, H, W)
        permuted = stacked.permute(1, 0, 2, 3)
        
        # Unsqueeze batch dimension: (1, 3, num_frames, H, W)
        batched = permuted.unsqueeze(0)
        
        # Cast to final dtype
        final_tensor = batched.to(dtype=dtype)
        
        return final_tensor

    @staticmethod
    def save_upload(
        file_content: bytes,
        upload_dir: str = "/tmp/ghost_coach",
        original_filename: str = "video.mp4"
    ) -> str:
        """Write an uploaded file's bytes to a temporarily generated file path.

        Creates a unique filename using a UUID4 prefix to prevent collisions.

        Args:
            file_content: The raw bytes to save.
            upload_dir: Destination directory. Will be created if it doesn't exist.
            original_filename: The original filename or base name.

        Returns:
            The absolute path to the saved file as a string.
        """
        directory = Path(upload_dir)
        directory.mkdir(parents=True, exist_ok=True)

        prefix = uuid4().hex[:12]
        full_path = directory / f"{prefix}_{original_filename}"

        with full_path.open("wb") as f:
            f.write(file_content)

        size_mb = len(file_content) / (1024 * 1024)
        logger.info(f"Saved uploaded video to {full_path} ({size_mb:.2f} MB)")

        return str(full_path.absolute())

    @staticmethod
    def cleanup(file_path: str) -> None:
        """Silently delete a file to clean up local storage.

        Args:
            file_path: Path to the file to delete.
        """
        try:
            path = Path(file_path)
            if path.exists() and path.is_file():
                path.unlink()
                logger.info(f"Deleted temporary file: {path}")
            else:
                logger.warning(f"Cleanup failed, file not found: {path}")
        except Exception as e:
            logger.warning(f"Failed to cleanly delete {file_path}: {e}")
