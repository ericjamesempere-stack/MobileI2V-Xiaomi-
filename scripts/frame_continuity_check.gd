extends RefCounted
# Quality metrics for a series of generated frames. Diagnostic only:
# no claim that pixel differences measure semantic/anatomical correctness.
static func inspect(frames: Array, loop_requested: bool = false) -> Dictionary:
 if frames.size() < 2:
  return {"ok": false, "reason": "Au moins deux images necessaires", "pairs": []}
 var pairs: Array[Dictionary] = []
 var max_change := 0.0
 var sum_change := 0.0
 var compare_count := frames.size() if loop_requested else frames.size() - 1
 for i in range(compare_count):
  var a: Image = _image(frames[i])
  var b: Image = _image(frames[(i + 1) % frames.size()])
  if a == null or b == null:
   return {"ok": false, "reason": "Image absente a l'index %d" % i, "pairs": pairs}
  var change := _difference(a, b)
  pairs.append({"from": i, "to": (i + 1) % frames.size(), "difference": change})
  max_change = maxf(max_change, change)
  sum_change += change
 return {"ok": true, "pairs": pairs, "average_difference": sum_change / float(compare_count), "maximum_difference": max_change, "loop_checked": loop_requested}

static func _image(value: Variant) -> Image:
 if value is Image:
  return value
 if value is Texture2D:
  return (value as Texture2D).get_image()
 return null

static func _difference(a: Image, b: Image) -> float:
 var w := mini(a.get_width(), b.get_width())
 var h := mini(a.get_height(), b.get_height())
 if w < 1 or h < 1:
  return 1.0
 var total := 0.0
 var count := 0
 for y in range(0, h, maxi(1, h / 32)):
  for x in range(0, w, maxi(1, w / 32)):
   var ca := a.get_pixel(x, y)
   var cb := b.get_pixel(x, y)
   total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
   count += 1
 return total / float(maxi(1, count))
