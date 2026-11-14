extends RefCounted
# Offline reference-color extraction for transparent character drawings.
# Appearance guidance only: not identity preservation or generative redrawing.
func extract(source: Image) -> Dictionary:
    if source == null or source.is_empty():
        return {"ok": false, "reason": "empty_reference"}
    var img: Image = source.duplicate()
    img.convert(Image.FORMAT_RGBA8)
    var colors: Array[Color] = []
    var histogram: Dictionary = {}
    var total: int = 0
    var step: int = maxi(1, mini(img.get_width(), img.get_height()) / 160)
    for y in range(0, img.get_height(), step):
        for x in range(0, img.get_width(), step):
            var c: Color = img.get_pixel(x, y)
            if c.a < 0.5:
                continue
            total += 1
            var r: int = clampi(roundi(c.r * 7.0), 0, 7)
            var g: int = clampi(roundi(c.g * 7.0), 0, 7)
            var b: int = clampi(roundi(c.b * 7.0), 0, 7)
            var key: int = r * 64 + g * 8 + b
            histogram[key] = int(histogram.get(key, 0)) + 1
    if total < 16:
        return {"ok": false, "reason": "insufficient_visible_pixels"}
    var ranked: Array = histogram.keys()
    ranked.sort_custom(func(a, b): return int(histogram[a]) > int(histogram[b]))
    for i in range(mini(6, ranked.size())):
        var key: int = int(ranked[i])
        colors.append(Color(float(key / 64) / 7.0, float((key / 8) % 8) / 7.0, float(key % 8) / 7.0))
    return {"ok": true, "palette": colors, "visible_samples": total, "method": "offline_color_histogram", "generative_redraw": false}
