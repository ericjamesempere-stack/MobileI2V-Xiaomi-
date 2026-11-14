extends RefCounted
# Segmentation locale du fond par connexite depuis les bords.
# Appropriee aux photos avec fond relativement uniforme; pas un modele IA.
static func extract(image: Image, tolerance: float = 0.12) -> Image:
 if image == null or image.is_empty():
  return null
 var img := image.duplicate()
 img.convert(Image.FORMAT_RGBA8)
 var w := img.get_width()
 var h := img.get_height()
 var count := w * h
 if count > 4000000:
  var scale: float = minf(1600.0 / float(w), 1600.0 / float(h))
  img.resize(maxi(1, roundi(w * scale)), maxi(1, roundi(h * scale)), Image.INTERPOLATE_LANCZOS)
  w = img.get_width()
  h = img.get_height()
  count = w * h
 var seen := PackedByteArray()
 seen.resize(count)
 var queue := PackedInt32Array()
 var corners := [img.get_pixel(0, 0), img.get_pixel(w-1, 0), img.get_pixel(0, h-1), img.get_pixel(w-1, h-1)]
 var bg := Color(0, 0, 0, 0)
 for c in corners:
  bg += c
 bg /= 4.0
 var threshold := tolerance * tolerance * 3.0
 for x in range(w):
  _seed(img, x, 0, w, seen, queue, bg, threshold)
  _seed(img, x, h-1, w, seen, queue, bg, threshold)
 for y in range(h):
  _seed(img, 0, y, w, seen, queue, bg, threshold)
  _seed(img, w-1, y, w, seen, queue, bg, threshold)
 var cursor := 0
 while cursor < queue.size():
  var index := queue[cursor]
  cursor += 1
  var x := index % w
  var y: int = int(index / w)
  if x > 0:
   _seed(img, x-1, y, w, seen, queue, bg, threshold)
  if x+1 < w:
   _seed(img, x+1, y, w, seen, queue, bg, threshold)
  if y > 0:
   _seed(img, x, y-1, w, seen, queue, bg, threshold)
  if y+1 < h:
   _seed(img, x, y+1, w, seen, queue, bg, threshold)
 for index in queue:
  var x := index % w
  var y := index / w
  var pixel := img.get_pixel(x, y)
  pixel.a = 0.0
  img.set_pixel(x, y, pixel)
 return img

static func _seed(img: Image, x: int, y: int, w: int, seen: PackedByteArray, queue: PackedInt32Array, bg: Color, threshold: float) -> void:
 var idx := y * w + x
 if seen[idx] != 0:
  return
 seen[idx] = 1
 var c := img.get_pixel(x, y)
 var d := c.r-bg.r
 var e := c.g-bg.g
 var f := c.b-bg.b
 if d*d+e*e+f*f <= threshold:
  queue.append(idx)
