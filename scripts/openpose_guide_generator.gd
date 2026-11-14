extends RefCounted
# OpenPose BODY_18 colored skeleton guide for SD1.5 OpenPose ControlNet.
# This is a deterministic motion planner output, not pose detection.
# 0 nose, 1 neck, 2 R shoulder, 3 R elbow, 4 R wrist,
# 5 L shoulder, 6 L elbow, 7 L wrist, 8 R hip, 9 R knee,
# 10 R ankle, 11 L hip, 12 L knee, 13 L ankle,
# 14 R eye, 15 L eye, 16 R ear, 17 L ear.
const COLORS := [
 Color8(255,0,0), Color8(255,85,0), Color8(255,170,0),
 Color8(255,255,0), Color8(170,255,0), Color8(85,255,0),
 Color8(0,255,0), Color8(0,255,85), Color8(0,255,170),
 Color8(0,255,255), Color8(0,170,255), Color8(0,85,255),
 Color8(0,0,255), Color8(85,0,255), Color8(170,0,255),
 Color8(255,0,255), Color8(255,0,170)
]
const LIMBS := [
 [1,2],[2,3],[3,4],[1,5],[5,6],[6,7],[1,8],
 [8,9],[9,10],[1,11],[11,12],[12,13],
 [1,0],[0,14],[14,16],[0,15],[15,17]
]

func render(_description: String, phase: float = 0.0, size: Vector2i = Vector2i(384,512), action: String = "course") -> Image:
 var img := Image.create(size.x,size.y,false,Image.FORMAT_RGB8)
 img.fill(Color.BLACK)
 var s: float = minf(float(size.x)/360.0,float(size.y)/480.0)
 var cx: float = size.x * 0.5
 var floor_y: float = size.y * 0.87
 var cyc: float = phase * TAU
 var stride: float = 48.0 if action == "course" else 24.0
 var rise: float = 40.0 if action == "course" else 15.0
 var progress: float = 0.0
 if action == "chute" or action == "trebuche":
  progress = clampf(phase,0.0,1.0)
 elif action == "releve":
  progress = 1.0 - clampf(phase,0.0,1.0)
 var hip := Vector2(cx,floor_y-108*s)
 var neck := Vector2(cx,floor_y-215*s)
 hip = hip.lerp(Vector2(cx-35*s,floor_y-32*s),progress)
 neck = neck.lerp(Vector2(cx+86*s,floor_y-38*s),progress)
 var lf := Vector2(cx-28*s,floor_y)
 var rf := Vector2(cx+28*s,floor_y)
 if action == "course" or action == "marche":
  lf = Vector2(cx-18*s+sin(cyc)*stride*s,floor_y-maxf(0.0,cos(cyc))*rise*s)
  rf = Vector2(cx+18*s-sin(cyc)*stride*s,floor_y-maxf(0.0,-cos(cyc))*rise*s)
 elif action == "saut":
  var jump: float = absf(sin(phase*PI))*65*s
  hip.y -= jump
  neck.y -= jump
  lf.y -= jump
  rf.y -= jump
 lf = lf.lerp(Vector2(cx-118*s,floor_y-8*s),progress)
 rf = rf.lerp(Vector2(cx-68*s,floor_y-8*s),progress)
 var rk := hip.lerp(rf,0.53)+Vector2(13,-13)*s
 var lk := hip.lerp(lf,0.53)+Vector2(-13,-13)*s
 var rs := neck+Vector2(22,6)*s
 var ls := neck+Vector2(-22,6)*s
 var rh := neck+Vector2(68-20*sin(cyc),70-30*sin(cyc))*s
 var lh := neck+Vector2(-68-20*sin(cyc),70+30*sin(cyc))*s
 rh = rh.lerp(Vector2(cx+115*s,floor_y-12*s),progress)
 lh = lh.lerp(Vector2(cx+12*s,floor_y-12*s),progress)
 if action == "salut":
  rh = neck+Vector2(65,-65)*s
 var re := rs.lerp(rh,0.48)+Vector2(13,-13)*s
 var le := ls.lerp(lh,0.48)+Vector2(-13,-13)*s
 var nose := neck+Vector2(0,-49)*s
 nose = nose.lerp(neck+Vector2(43,-4)*s,progress)
 var points := [
  nose,neck,rs,re,rh,ls,le,lh,
  hip+Vector2(13,0)*s,rk,rf,hip+Vector2(-13,0)*s,lk,lf,
  nose+Vector2(9,-4)*s,nose+Vector2(-9,-4)*s,
  nose+Vector2(18,1)*s,nose+Vector2(-18,1)*s
 ]
 for i in range(LIMBS.size()):
  var pair: Array = LIMBS[i]
  _line(img,points[pair[0]],points[pair[1]],COLORS[i],maxi(2,roundi(4*s)))
 for i in range(points.size()):
  _dot(img,points[i],Color8(255,255,255),maxi(2,roundi(4*s)))
 return img

func _dot(img: Image,p: Vector2,c: Color,r: int) -> void:
 for y in range(maxi(0,int(p.y)-r),mini(img.get_height(),int(p.y)+r+1)):
  for x in range(maxi(0,int(p.x)-r),mini(img.get_width(),int(p.x)+r+1)):
   if Vector2(x,y).distance_squared_to(p)<=r*r:
    img.set_pixel(x,y,c)

func _line(img: Image,a: Vector2,b: Vector2,c: Color,width: int) -> void:
 var steps: int = maxi(1,ceili(a.distance_to(b)))
 for i in range(steps+1):
  _dot(img,a.lerp(b,float(i)/steps),c,width)
