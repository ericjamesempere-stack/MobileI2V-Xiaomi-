from PIL import Image
import pytest
from ai_redraw.drawing_generator import FrameRequest
from ai_redraw.model_storyboard_renderer import VideoModelStoryboardRenderer

def make_request(index, scene=0):
    return FrameRequest(index, scene, "A dog runs.", 0.0, 8, 128, 128,
                        Image.new("RGB", (80, 50), "red"), None)

def test_model_batches_are_used_as_real_frames():
    calls = []
    def provider(source, prompt, style, seed):
        calls.append((source.size, prompt, style, seed))
        return [Image.new("RGB", (64, 32), (i * 30, 20, 20)) for i in range(4)]
    renderer = VideoModelStoryboardRenderer(provider=provider)
    frames = [renderer(make_request(i)) for i in range(6)]
    assert len(calls) == 2
    assert all(frame.size == (128, 128) for frame in frames)
    assert frames[0].tobytes() != frames[1].tobytes()

def test_out_of_order_request_is_rejected():
    renderer = VideoModelStoryboardRenderer(provider=lambda *_: [
        Image.new("RGB", (128, 128)), Image.new("RGB", (128, 128))])
    with pytest.raises(ValueError, match="sequential"):
        renderer(make_request(2))

def test_empty_model_result_is_rejected():
    renderer = VideoModelStoryboardRenderer(provider=lambda *_: [])
    with pytest.raises(RuntimeError, match="sequence"):
        renderer(make_request(0))
