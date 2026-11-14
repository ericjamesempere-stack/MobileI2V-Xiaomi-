"""Optional model-backed storyboard renderer, using real generated frames.

Uses existing I2VGenXL backend. Each model invocation generates a *batch*
of distinct illustrated frames, not transformed copies of one still image.
A new batch uses the previous batch's final frame as motion context. The
original reference remains available and is never silently replaced.
GPU/model weights required; no claim of Android on-device inference.
"""
from PIL import Image, ImageOps
from .animate_anything import generate_video_frames
from .drawing_generator import FrameRequest

class VideoModelStoryboardRenderer:
    def __init__(self, style="anime", seed=1234, batch_size=16, provider=None):
        if style not in {"manga", "bd", "cartoon", "anime", "natural", "cinema"}:
            raise ValueError("Unsupported drawing style")
        if not 2 <= batch_size <= 32:
            raise ValueError("Invalid batch size")
        self.style = style
        self.seed = seed
        self.batch_size = batch_size
        self.provider = provider or generate_video_frames
        self._batch = []
        self._next = 0
        self._scene = -1
        self._previous = None
        self._reference = None

    def __call__(self, request: FrameRequest) -> Image.Image:
        if request.frame_index != self._next:
            raise ValueError("Frame requests must be sequential")
        if request.scene_index != self._scene:
            self._scene = request.scene_index
            self._batch = []
            # A new scene reanchors on the original image rather than
            # allowing identity drift to accumulate indefinitely.
            self._previous = None
        if self._reference is None:
            self._reference = request.reference.copy()
        if not self._batch:
            # First batch is conditioned on original image. Subsequent batches
            # use last accepted frame for local motion continuity.
            source = self._reference if self._previous is None else self._previous
            prompt = request.scene_instruction
            batch = self.provider(source, prompt, self.style,
                                  self.seed + request.frame_index)
            if not isinstance(batch, (list, tuple)) or len(batch) < 2:
                raise RuntimeError("Video model did not generate a frame sequence")
            self._batch = list(batch[:self.batch_size])
        image = self._batch.pop(0)
        if not isinstance(image, Image.Image):
            raise RuntimeError("Video model returned invalid frame")
        # Pad to target canvas: no stretching of faces, people or objects.
        image = ImageOps.pad(image.convert("RGB"),
                             (request.width, request.height),
                             method=Image.Resampling.LANCZOS,
                             color=(0, 0, 0), centering=(0.5, 0.5))
        self._previous = image.copy()
        self._next += 1
        return image
