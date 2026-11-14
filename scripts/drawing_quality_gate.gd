extends RefCounted
# Checks that real rendered keyframes are fit for image-sequence animation.
# Quantitative image checks do not substitute for human review.
func inspect(image: Image, previous: Image = null) -> Dictionary:
    if image == null or image.is_empty():
        return {"ok": false, "issues": ["empty_image"]}
    var w: int = image.get_width()
    var h: int = image.get_height()
    var samples: int = 0
    var min_l: float = 1.0
    var max_l: float = 0.0
    var sum_l: float = 0.0
    var sum_sq: float = 0.0
    var difference: float = 0.0
    for y in range(0, h, maxi(1, h / 32)):
        for x in range(0, w, maxi(1, w / 32)):
            var c: Color = image.get_pixel(x, y)
            var l: float = (c.r + c.g + c.b) / 3.0
            min_l = minf(min_l, l)
            max_l = maxf(max_l, l)
            sum_l += l
            sum_sq += l * l
            if previous != null and not previous.is_empty():
                var px: int = clampi(roundi(float(x) / maxi(1, w - 1) * (previous.get_width() - 1)), 0, previous.get_width() - 1)
                var py: int = clampi(roundi(float(y) / maxi(1, h - 1) * (previous.get_height() - 1)), 0, previous.get_height() - 1)
                var old: Color = previous.get_pixel(px, py)
                difference += (absf(c.r - old.r) + absf(c.g - old.g) + absf(c.b - old.b)) / 3.0
            samples += 1
    var mean: float = sum_l / maxi(1, samples)
    var variance: float = sum_sq / maxi(1, samples) - mean * mean
    var issues: Array[String] = []
    if variance < 0.0005 or max_l - min_l < 0.05:
        issues.append("flat_or_blank_frame")
    if previous != null and not previous.is_empty():
        var average_change: float = difference / maxi(1, samples)
        if average_change > 0.55:
            issues.append("possible_scene_jump")
    return {"ok": issues.is_empty(), "issues": issues, "brightness": mean, "variance": variance}
