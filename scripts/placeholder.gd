extends RefCounted
# V50 : placeholders proceduraux remplacant les assets binaires manquants.
const W: int = 270
const H: int = 360

static func _line(img: Image, a: Vector2, b: Vector2, col: Color, thick: int = 5) -> void:
    var steps: int = int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
    for i in range(steps + 1):
        var t: float = float(i) / float(maxi(steps, 1))
        var p: Vector2 = a.lerp(b, t)
        for dy in range(-thick / 2, thick / 2 + 1):
            for dx in range(-thick / 2, thick / 2 + 1):
                var x: int = int(p.x) + dx
                var y: int = int(p.y) + dy
                if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
                    img.set_pixel(x, y, col)

static func _stick_frame(img: Image, phase: float) -> void:
    var bg: Color = Color("25364a")
    var body: Color = Color("f2eee7")
    var ink: Color = Color("172536")
    img.fill(bg)
    var s: float = sin(phase)
    var c: float = cos(phase)
    var bounce: float = 8.0 * absf(sin(phase * 0.5))
    var hip: Vector2 = Vector2(W * 0.5 + 18.0 * s, H * 0.55 - bounce)
    var chest: Vector2 = hip + Vector2(8.0 * c, -H * 0.22)
    var head: Vector2 = chest + Vector2(4.0 * s, -34.0)
    var knee_l: Vector2 = hip + Vector2(-30.0 + 22.0 * s, H * 0.17)
    var knee_r: Vector2 = hip + Vector2(30.0 - 22.0 * s, H * 0.17)
    var ankle_l: Vector2 = Vector2(knee_l.x - 10.0 * s, H * 0.92)
    var ankle_r: Vector2 = Vector2(knee_r.x + 10.0 * s, H * 0.92)
    var elbow_l: Vector2 = chest + Vector2(-38.0 - 16.0 * c, 44.0 + 14.0 * s)
    var elbow_r: Vector2 = chest + Vector2(38.0 + 16.0 * c, 44.0 - 14.0 * s)
    var wrist_l: Vector2 = elbow_l + Vector2(-16.0 + 20.0 * s, 34.0 - 24.0 * c)
    var wrist_r: Vector2 = elbow_r + Vector2(16.0 - 20.0 * s, 34.0 + 24.0 * c)
    _line(img, Vector2(30, H * 0.92), Vector2(W - 30, H * 0.92), Color("66788b"), 3)
    _line(img, hip, knee_l, ink, 9)
    _line(img, knee_l, ankle_l, ink, 9)
    _line(img, hip, knee_r, ink, 9)
    _line(img, knee_r, ankle_r, ink, 9)
    _line(img, chest, hip, body, 12)
    _line(img, chest + Vector2(-30, 0), chest + Vector2(30, 0), body, 10)
    _line(img, chest + Vector2(-30, 0), elbow_l, body, 8)
    _line(img, elbow_l, wrist_l, body, 7)
    _line(img, chest + Vector2(30, 0), elbow_r, body, 8)
    _line(img, elbow_r, wrist_r, body, 7)
    for dy in range(-16, 17):
        for dx in range(-16, 17):
            if dx * dx + dy * dy <= 256:
                var x: int = int(head.x) + dx
                var y: int = int(head.y) + dy
                if x >= 0 and y >= 0 and x < W and y < H:
                    img.set_pixel(x, y, Color("c38b6c"))

static func portrait_placeholder(label_index: int) -> ImageTexture:
    var img: Image = Image.create(W, H, false, Image.FORMAT_RGB8)
    _stick_frame(img, float(label_index) * 0.7)
    return ImageTexture.create_from_image(img)

static func pose_placeholder(index: int) -> ImageTexture:
    var img: Image = Image.create(W, H, false, Image.FORMAT_RGB8)
    _stick_frame(img, float(index) / 16.0 * TAU)
    return ImageTexture.create_from_image(img)

static func mid_placeholder(index: int) -> ImageTexture:
    var img: Image = Image.create(W, H, false, Image.FORMAT_RGB8)
    _stick_frame(img, (float(index) + 0.5) / 16.0 * TAU)
    return ImageTexture.create_from_image(img)