extends RefCounted
# CPU-only global motion-compensated interpolation for drawn keyframes.
# Suitable for modest camera/subject translations; not dense optical flow.
func estimate_shift(a: Image, b: Image, max_shift: int = 18) -> Vector2i:
    var w: int = mini(a.get_width(), b.get_width())
    var h: int = mini(a.get_height(), b.get_height())
    var stride: int = maxi(4, mini(w, h) / 40)
    var best_score: float = INF
    var best := Vector2i.ZERO
    for dy in range(-max_shift, max_shift + 1, 3):
        for dx in range(-max_shift, max_shift + 1, 3):
            var error: float = 0.0
            var samples: int = 0
            for y in range(maxi(0, -dy), mini(h, h - dy), stride):
                for x in range(maxi(0, -dx), mini(w, w - dx), stride):
                    var ca: Color = a.get_pixel(x, y)
                    var cb: Color = b.get_pixel(x + dx, y + dy)
                    error += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
                    samples += 1
            if samples > 0:
                var score: float = error / samples + 0.0004 * (abs(dx) + abs(dy))
                if score < best_score:
                    best_score = score
                    best = Vector2i(dx, dy)
    return best

func blend(a: Image, b: Image, t: float, shift: Vector2i = Vector2i.ZERO) -> Image:
    var w: int = a.get_width()
    var h: int = a.get_height()
    var result: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
    var p: float = clampf(t, 0.0, 1.0)
    for y in range(h):
        for x in range(w):
            var ax: int = clampi(roundi(x - float(shift.x) * p), 0, w - 1)
            var ay: int = clampi(roundi(y - float(shift.y) * p), 0, h - 1)
            var bx: int = clampi(roundi(x + float(shift.x) * (1.0 - p)), 0, w - 1)
            var by: int = clampi(roundi(y + float(shift.y) * (1.0 - p)), 0, h - 1)
            result.set_pixel(x, y, a.get_pixel(ax, ay).lerp(b.get_pixel(bx, by), p))
    return result

# Local block motion field: tracks independently moving regions of a drawing.
# More expensive than a global shift, so compute once per keyframe pair.
func estimate_blocks(a: Image, b: Image, block_size: int = 32, radius: int = 8) -> Dictionary:
    var w: int = mini(a.get_width(), b.get_width())
    var h: int = mini(a.get_height(), b.get_height())
    var cell: int = maxi(8, block_size)
    radius = clampi(radius, 0, 24)
    var cols: int = ceili(float(w) / cell)
    var rows: int = ceili(float(h) / cell)
    var shifts: Array = []
    for cy in range(rows):
        for cx in range(cols):
            var x0: int = cx * cell
            var y0: int = cy * cell
            var x1: int = mini(w, x0 + cell)
            var y1: int = mini(h, y0 + cell)
            var best := Vector2i.ZERO
            var best_error: float = INF
            for dy in range(-radius, radius + 1, 2):
                for dx in range(-radius, radius + 1, 2):
                    var error: float = 0.0
                    var count: int = 0
                    for y in range(y0, y1, 4):
                        for x in range(x0, x1, 4):
                            var bx: int = x + dx
                            var by: int = y + dy
                            if bx < 0 or by < 0 or bx >= w or by >= h:
                                continue
                            var ca: Color = a.get_pixel(x, y)
                            var cb: Color = b.get_pixel(bx, by)
                            error += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
                            count += 1
                    if count > 0:
                        var score: float = error / count + 0.001 * (abs(dx) + abs(dy))
                        if score < best_error:
                            best_error = score
                            best = Vector2i(dx, dy)
            shifts.append(best)
    return {"cell": cell, "cols": cols, "rows": rows, "shifts": shifts}

func blend_blocks(a: Image, b: Image, t: float, field: Dictionary) -> Image:
    var w: int = a.get_width()
    var h: int = a.get_height()
    var cell: int = maxi(1, int(field.get("cell", 32)))
    var cols: int = maxi(1, int(field.get("cols", 1)))
    var shifts: Array = field.get("shifts", [])
    var p: float = clampf(t, 0.0, 1.0)
    var result: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
    for y in range(h):
        for x in range(w):
            # Bilinear interpolation of neighboring block motion vectors removes
            # hard displacement discontinuities at cell boundaries.
            var gx: float = float(x) / float(cell) - 0.5
            var gy: float = float(y) / float(cell) - 0.5
            var x0: int = clampi(floori(gx), 0, cols - 1)
            var x1: int = clampi(x0 + 1, 0, cols - 1)
            var rows: int = maxi(1, int(field.get("rows", 1)))
            var y0: int = clampi(floori(gy), 0, rows - 1)
            var y1: int = clampi(y0 + 1, 0, rows - 1)
            var fx: float = clampf(gx - floorf(gx), 0.0, 1.0)
            var fy: float = clampf(gy - floorf(gy), 0.0, 1.0)
            var v00: Vector2 = Vector2(shifts[y0 * cols + x0]) if y0 * cols + x0 < shifts.size() else Vector2.ZERO
            var v10: Vector2 = Vector2(shifts[y0 * cols + x1]) if y0 * cols + x1 < shifts.size() else Vector2.ZERO
            var v01: Vector2 = Vector2(shifts[y1 * cols + x0]) if y1 * cols + x0 < shifts.size() else Vector2.ZERO
            var v11: Vector2 = Vector2(shifts[y1 * cols + x1]) if y1 * cols + x1 < shifts.size() else Vector2.ZERO
            var shift: Vector2 = v00.lerp(v10, fx).lerp(v01.lerp(v11, fx), fy)
            var ax: int = clampi(roundi(x - shift.x * p), 0, w - 1)
            var ay: int = clampi(roundi(y - shift.y * p), 0, h - 1)
            var bx: int = clampi(roundi(x + shift.x * (1.0 - p)), 0, w - 1)
            var by: int = clampi(roundi(y + shift.y * (1.0 - p)), 0, h - 1)
            result.set_pixel(x, y, a.get_pixel(ax, ay).lerp(b.get_pixel(bx, by), p))
    return result
