extends RefCounted
# Reprojects the actual pixels of a painted limb along a two-bone IK chain.
# Input artwork stays intact; no solid-color replacement or rectangle copying.
# This is a prototype for pre-separated transparent limb layers.

func draw_segment(dst: Image, artwork: Image, source_a: Vector2, source_b: Vector2, target_a: Vector2, target_b: Vector2, half_width: float) -> void:
    var source_axis: Vector2 = source_b - source_a
    var target_axis: Vector2 = target_b - target_a
    var source_length: float = source_axis.length()
    var target_length: float = target_axis.length()
    if source_length < 1.0 or target_length < 1.0 or half_width <= 0.0:
        return
    var source_forward: Vector2 = source_axis / source_length
    var source_side := Vector2(-source_forward.y, source_forward.x)
    var target_forward: Vector2 = target_axis / target_length
    var target_side := Vector2(-target_forward.y, target_forward.x)
    var left: int = maxi(0, floori(minf(target_a.x, target_b.x) - half_width - 2.0))
    var right: int = mini(dst.get_width() - 1, ceili(maxf(target_a.x, target_b.x) + half_width + 2.0))
    var top: int = maxi(0, floori(minf(target_a.y, target_b.y) - half_width - 2.0))
    var bottom: int = mini(dst.get_height() - 1, ceili(maxf(target_a.y, target_b.y) + half_width + 2.0))
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            var relative := Vector2(float(x), float(y)) - target_a
            var along: float = relative.dot(target_forward)
            var side: float = relative.dot(target_side)
            if along < -half_width or along > target_length + half_width or absf(side) > half_width:
                continue
            var source_point := source_a + source_forward * (along / target_length * source_length) + source_side * side
            # Bilinear alpha-aware sampling avoids hard nearest-neighbour
            # pixel staircases along rotated clothing and silhouette edges.
            var sx: int = floori(source_point.x)
            var sy: int = floori(source_point.y)
            var tx: float = source_point.x - float(sx)
            var ty: float = source_point.y - float(sy)
            var weighted_alpha: float = 0.0
            var premultiplied := Vector3.ZERO
            for oy in range(2):
                for ox in range(2):
                    var px: int = sx + ox
                    var py: int = sy + oy
                    if px < 0 or py < 0 or px >= artwork.get_width() or py >= artwork.get_height():
                        continue
                    var weight: float = (tx if ox == 1 else 1.0 - tx) * (ty if oy == 1 else 1.0 - ty)
                    var sample: Color = artwork.get_pixel(px, py)
                    var contribution: float = weight * sample.a
                    weighted_alpha += contribution
                    premultiplied += Vector3(sample.r, sample.g, sample.b) * contribution
            if weighted_alpha <= 0.001:
                continue
            var pigment_rgb: Vector3 = premultiplied / weighted_alpha
            var opacity: float = weighted_alpha * clampf(half_width + 0.5 - absf(side), 0.0, 1.0)
            var original: Color = dst.get_pixel(x, y)
            dst.set_pixel(x, y, original.lerp(Color(pigment_rgb.x, pigment_rgb.y, pigment_rgb.z, 1.0), opacity))
