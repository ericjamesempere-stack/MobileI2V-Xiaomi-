extends RefCounted
class_name SubjectPoseLibrary

# Vector artwork built from distinct geometry per frame. Offline, no API.
# Supports basic vehicles and quadrupeds; it does not reconstruct photos.
static func render_svg(kind: String, action: String, t: float) -> String:
    var artwork := ""
    match kind:
        "vehicle":
            artwork = _vehicle(action, t)
        "animal":
            artwork = _animal(action, t)
        _:
            return ""
    return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="448" viewBox="0 0 256 448"><rect width="256" height="448" fill="#f4f0e7"/><path d="M0 365H256" stroke="#9ba8ad" stroke-width="3"/>' + artwork + '</svg>'

static func _vehicle(action: String, t: float) -> String:
    var offset := t * 45.0
    var lift := 0.0
    var rotation := 0.0
    if action == "jump" or action == "fly":
        lift = -90.0 * sin(PI * t)
    elif action == "fall":
        lift = 85.0 * t
        rotation = t * 25.0
    elif action == "land":
        lift = -75.0 * (1.0 - t)
    elif action == "stop":
        offset = 45.0 * (1.0 - pow(1.0 - t, 3.0))
    var wheel_angle := t * 720.0 if action != "stop" else t * 180.0
    var body := '<rect x="47" y="270" width="164" height="49" rx="13" fill="#d94e3d" stroke="#263746" stroke-width="4"/>'
    body += '<path d="M81 269L106 233H162L190 269Z" fill="#78c5df" stroke="#263746" stroke-width="4"/>'
    for x in [85, 177]:
        body += '<circle cx="%d" cy="320" r="23" fill="#243241" stroke="#121a21" stroke-width="4"/>' % x
        body += '<g transform="rotate(%.2f %d 320)"><path d="M%d 302V338M%d 320H%d" stroke="#e5e8e9" stroke-width="5"/></g>' % [wheel_angle, x, x, x - 18, x + 18]
    return '<g transform="translate(%.2f %.2f) rotate(%.2f 128 290)">' % [offset - 20.0, lift, rotation] + body + '</g>'

static func _animal(action: String, t: float) -> String:
    var phase := t * TAU * 2.0
    var stride := sin(phase)
    var x := 0.0
    var y := 0.0
    var rotation := 0.0
    match action:
        "run":
            x = 50.0 * t
            y = -10.0 * absf(stride)
        "walk":
            x = 30.0 * t
        "jump":
            y = -95.0 * sin(PI * t)
        "fall":
            rotation = 65.0 * t
            y = 50.0 * t
        "dance":
            x = 15.0 * stride
            y = -10.0 * absf(stride)
    var front := 22.0 * stride if action == "run" or action == "walk" else 0.0
    var rear := -front
    var legs := ""
    for leg in [[82, rear], [111, front], [156, rear], [183, front]]:
        legs += '<line x1="%d" y1="301" x2="%.2f" y2="356" stroke="#7b604c" stroke-width="13" stroke-linecap="round"/>' % [leg[0], float(leg[0]) + float(leg[1])]
    var body := legs
    body += '<ellipse cx="132" cy="290" rx="73" ry="37" fill="#a97e60" stroke="#634d3e" stroke-width="4"/>'
    body += '<path d="M182 277Q199 246 216 258L226 282Q218 307 190 306Z" fill="#a97e60" stroke="#634d3e" stroke-width="4"/>'
    body += '<path d="M201 256L202 230L220 252" fill="#a97e60" stroke="#634d3e" stroke-width="4"/>'
    body += '<circle cx="213" cy="274" r="4" fill="#1d252b"/>'
    body += '<path d="M61 281Q37 266 39 241" fill="none" stroke="#7b604c" stroke-width="10" stroke-linecap="round"/>'
    return '<g transform="translate(%.2f %.2f) rotate(%.2f 132 290)">' % [x - 20.0, y, rotation] + body + '</g>'
