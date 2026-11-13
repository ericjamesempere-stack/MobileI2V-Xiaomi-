extends RefCounted
# Fast offline flat-background separation for cartoons.
# Does not replace semantic person detection or MediaPipe.
func separate(source: Image, tolerance: float = 0.12) -> Dictionary:
    var w: int = source.get_width()
    var h: int = source.get_height()
    if w < 3 or h < 3:
        return {"ok": false, "reason": "Image too small"}
    var image: Image = source.duplicate()
    image.convert(Image.FORMAT_RGBA8)
    var corner: Color = image.get_pixel(0, 0)
    var corners: Array[Color] = [corner, image.get_pixel(w - 1, 0), image.get_pixel(0, h - 1), image.get_pixel(w - 1, h - 1)]
    for c in corners:
        if _distance(c, corner) > tolerance:
            return {"ok": false, "reason": "Complex border background: automatic flat-background separation unavailable"}
    var visited := PackedByteArray()
    visited.resize(w * h)
    visited.fill(0)
    var queue := PackedInt32Array()
    for y in range(h):
        for x in [0, w - 1]:
            var index: int = y * w + x
            if visited[index] == 0 and _distance(image.get_pixel(x, y), corner) <= tolerance:
                visited[index] = 1
                queue.append(index)
    for x in range(w):
        for y in [0, h - 1]:
            var index: int = y * w + x
            if visited[index] == 0 and _distance(image.get_pixel(x, y), corner) <= tolerance:
                visited[index] = 1
                queue.append(index)
    var head: int = 0
    while head < queue.size():
        var index: int = queue[head]
        head += 1
        var x: int = index % w
        var y: int = index / w
        for neighbor in [index - 1 if x > 0 else -1, index + 1 if x < w - 1 else -1, index - w if y > 0 else -1, index + w if y < h - 1 else -1]:
            if neighbor < 0 or visited[neighbor] != 0:
                continue
            var nx: int = neighbor % w
            var ny: int = neighbor / w
            if _distance(image.get_pixel(nx, ny), corner) <= tolerance:
                visited[neighbor] = 1
                queue.append(neighbor)
    var subject_pixels: int = 0
    for y in range(h):
        for x in range(w):
            if visited[y * w + x] != 0:
                var color: Color = image.get_pixel(x, y)
                color.a = 0.0
                image.set_pixel(x, y, color)
            else:
                subject_pixels += 1
    var coverage: float = float(subject_pixels) / float(w * h)
    if coverage < 0.015 or coverage > 0.92:
        return {"ok": false, "reason": "No reliable isolated subject", "coverage": coverage}
    return {"ok": true, "foreground": image, "coverage": coverage}

func _distance(a: Color, b: Color) -> float:
    return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
