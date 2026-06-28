## dragon/dragon_mesh.gd
## Xây dựng toàn bộ mesh procedural của Dragon.
## Không extends Node – được tạo và gọi từ dragon_character.gd.

class_name DragonMesh

# ── Pivot refs cho Animator ───────────────────────────────────────────────────
var rig:        Node3D
var neck:       Node3D
var neck2:      Node3D
var head_pivot: Node3D
var jaw:        Node3D
var horn_l:     Node3D
var horn_r:     Node3D
var fl_thigh:   Node3D;  var fl_shin: Node3D;  var fl_foot: Node3D
var fr_thigh:   Node3D;  var fr_shin: Node3D;  var fr_foot: Node3D
var bl_thigh:   Node3D;  var bl_shin: Node3D;  var bl_foot: Node3D
var br_thigh:   Node3D;  var br_shin: Node3D;  var br_foot: Node3D
var wing_l:     Node3D;  var wing_l2: Node3D;  var wing_l3: Node3D
var wing_r:     Node3D;  var wing_r2: Node3D;  var wing_r3: Node3D
var tail:       Array[Node3D] = []
var spine_fins: Array[Node3D] = []

# ── Materials ─────────────────────────────────────────────────────────────────
var _mb:        StandardMaterial3D  # body
var _ms:        StandardMaterial3D  # scale
var _mbelly:    StandardMaterial3D  # belly
var _mwing:     StandardMaterial3D  # wing membrane
var _mhorn:     StandardMaterial3D  # horn / teeth
var _meye:      StandardMaterial3D  # eye
var _mclaw:     StandardMaterial3D  # claw
var _mglow:     StandardMaterial3D  # glow accent

# Shorthand
func B() -> StandardMaterial3D: return _mb
func S() -> StandardMaterial3D: return _ms
func V() -> StandardMaterial3D: return _mbelly
func W() -> StandardMaterial3D: return _mwing
func H() -> StandardMaterial3D: return _mhorn
func E() -> StandardMaterial3D: return _meye
func C() -> StandardMaterial3D: return _mclaw
func G() -> StandardMaterial3D: return _mglow

# ── Entry ─────────────────────────────────────────────────────────────────────
func build(root: CharacterBody3D) -> void:
	_make_mats()
	rig      = MeshBuilder.pivot(root, Vector3(0, 0.10, 0))
	rig.name = "DragonRig"
	_torso()
	_neck_head()
	_front_legs()
	_back_legs()
	_wings()
	_tail()

func _make_mats() -> void:
	_mb    = MeshBuilder.emit_mat(Color(0.35,0.05,0.55), Color(0,0,0), 0.0)
	_ms    = MeshBuilder.emit_mat(Color(0.55,0.10,0.80), Color(0,0,0), 0.0)
	_mbelly= MeshBuilder.emit_mat(Color(0.70,0.30,0.60), Color(0,0,0), 0.0)
	_mwing = MeshBuilder.emit_mat(Color(0.60,0.05,0.15), Color(0,0,0), 0.0)
	_mhorn = MeshBuilder.emit_mat(Color(0.90,0.95,1.00), Color(0,0,0), 0.0)
	_meye  = MeshBuilder.emit_mat(Color(1.00,0.70,0.10), Color(0,0,0), 0.0)
	_mclaw = MeshBuilder.emit_mat(Color(0.12,0.02,0.20), Color(0,0,0), 0.0)
	_mglow = MeshBuilder.emit_mat(Color(1.00,0.20,0.40), Color(0,0,0), 0.0)

# ── Torso ─────────────────────────────────────────────────────────────────────
func _torso() -> void:
	MeshBuilder.box(rig, Vector3(0,0.75, 0.00), Vector3(0.72,0.42,1.10), B())
	MeshBuilder.box(rig, Vector3(0,0.68, 0.42), Vector3(0.60,0.34,0.32), B())
	MeshBuilder.box(rig, Vector3(0,0.70,-0.42), Vector3(0.58,0.36,0.36), B())
	MeshBuilder.box(rig, Vector3(0,0.52, 0.10), Vector3(0.44,0.20,0.80), V())
	for i in range(5):
		MeshBuilder.box(rig, Vector3(0,0.42,0.38-float(i)*0.18), Vector3(0.38,0.06,0.10), V())
	for i in range(3):
		MeshBuilder.box(rig, Vector3(-0.38,0.80+float(i)*0.08,-float(i)*0.10), Vector3(0.08,0.14,0.18), S())
		MeshBuilder.box(rig, Vector3( 0.38,0.80+float(i)*0.08,-float(i)*0.10), Vector3(0.08,0.14,0.18), S())
	spine_fins.clear()
	var fh: Array[float] = [0.10,0.16,0.22,0.28,0.24,0.18,0.12]
	var fz: Array[float] = [0.38,0.22,0.06,-0.10,-0.24,-0.36,-0.46]
	for i in range(7):
		var fp: Node3D = MeshBuilder.pivot(rig, Vector3(0,0.96,fz[i]))
		MeshBuilder.box(fp, Vector3(0,fh[i]*0.5,0), Vector3(0.06,fh[i],0.07), G())
		MeshBuilder.box(fp, Vector3(0,fh[i],0),      Vector3(0.03,0.04,0.04), H())
		spine_fins.append(fp)
	MeshBuilder.box(rig, Vector3(-0.36,0.90,0.32), Vector3(0.20,0.24,0.28), S())
	MeshBuilder.box(rig, Vector3( 0.36,0.90,0.32), Vector3(0.20,0.24,0.28), S())

# ── Neck + Head ───────────────────────────────────────────────────────────────
func _neck_head() -> void:
	neck = MeshBuilder.pivot(rig, Vector3(0,0.94,0.48))
	neck.rotation.x = -0.30
	MeshBuilder.box(neck, Vector3(0,0.08,0.06), Vector3(0.26,0.24,0.32), B())
	MeshBuilder.box(neck, Vector3(0,0.16,0.10), Vector3(0.22,0.20,0.24), B())
	for i in range(3):
		MeshBuilder.box(neck, Vector3(0,0.22+float(i)*0.08,0.04+float(i)*0.04), Vector3(0.06,0.10,0.06), G())

	neck2 = MeshBuilder.pivot(neck, Vector3(0,0.28,0.20))
	neck2.rotation.x = -0.20
	MeshBuilder.box(neck2, Vector3(0, 0.06, 0.08), Vector3(0.22,0.20,0.28), B())
	MeshBuilder.box(neck2, Vector3(0, 0.12, 0.14), Vector3(0.18,0.16,0.20), B())
	MeshBuilder.box(neck2, Vector3(0,-0.04, 0.14), Vector3(0.18,0.10,0.22), V())

	head_pivot = MeshBuilder.pivot(neck2, Vector3(0,0.22,0.22))
	MeshBuilder.box(head_pivot, Vector3(0, 0.06, 0.00), Vector3(0.36,0.30,0.44), B())
	MeshBuilder.box(head_pivot, Vector3(0,-0.02, 0.22), Vector3(0.28,0.18,0.30), B())
	MeshBuilder.box(head_pivot, Vector3(0,-0.04, 0.38), Vector3(0.22,0.14,0.18), B())
	MeshBuilder.box(head_pivot, Vector3(-0.08,-0.02,0.46), Vector3(0.06,0.05,0.04), G())
	MeshBuilder.box(head_pivot, Vector3( 0.08,-0.02,0.46), Vector3(0.06,0.05,0.04), G())

	jaw = MeshBuilder.pivot(head_pivot, Vector3(0,-0.06,0.10))
	MeshBuilder.box(jaw, Vector3(0,-0.04,0.20), Vector3(0.24,0.10,0.34), B())
	MeshBuilder.box(jaw, Vector3(0,-0.06,0.38), Vector3(0.18,0.08,0.18), B())
	for ti in range(5):
		MeshBuilder.box(head_pivot, Vector3(-0.08+float(ti)*0.04,-0.10,0.30+float(ti)*0.01), Vector3(0.03,0.06,0.03), H())
	for ti in range(4):
		MeshBuilder.box(jaw, Vector3(-0.06+float(ti)*0.04,0.02,0.22+float(ti)*0.01), Vector3(0.03,0.06,0.03), H())
	MeshBuilder.sphere(head_pivot, Vector3(-0.16,0.08,0.08), 0.065, E())
	MeshBuilder.sphere(head_pivot, Vector3( 0.16,0.08,0.08), 0.065, E())
	MeshBuilder.box(head_pivot, Vector3(-0.16,0.08,0.14), Vector3(0.025,0.060,0.020), C())
	MeshBuilder.box(head_pivot, Vector3( 0.16,0.08,0.14), Vector3(0.025,0.060,0.020), C())
	MeshBuilder.box(head_pivot, Vector3(-0.16,0.14,0.10), Vector3(0.10,0.05,0.06), S())
	MeshBuilder.box(head_pivot, Vector3( 0.16,0.14,0.10), Vector3(0.10,0.05,0.06), S())

	horn_l = MeshBuilder.pivot(head_pivot, Vector3(-0.14,0.18,-0.06))
	horn_l.rotation.z =  0.35; horn_l.rotation.x = -0.40
	MeshBuilder.box(horn_l, Vector3(0,0.10, 0),    Vector3(0.06,0.22,0.05), H())
	MeshBuilder.box(horn_l, Vector3(0,0.26,-0.04), Vector3(0.04,0.16,0.04), H())
	MeshBuilder.box(horn_l, Vector3(0,0.38,-0.08), Vector3(0.03,0.12,0.03), H())
	horn_r = MeshBuilder.pivot(head_pivot, Vector3( 0.14,0.18,-0.06))
	horn_r.rotation.z = -0.35; horn_r.rotation.x = -0.40
	MeshBuilder.box(horn_r, Vector3(0,0.10, 0),    Vector3(0.06,0.22,0.05), H())
	MeshBuilder.box(horn_r, Vector3(0,0.26,-0.04), Vector3(0.04,0.16,0.04), H())
	MeshBuilder.box(horn_r, Vector3(0,0.38,-0.08), Vector3(0.03,0.12,0.03), H())
	for ci in range(4):
		MeshBuilder.box(head_pivot, Vector3(-0.06+float(ci)*0.04,0.22,-0.14-float(ci)*0.02), Vector3(0.04,0.08+float(ci)*0.02,0.04), S())

# ── Legs ──────────────────────────────────────────────────────────────────────
func _front_legs() -> void:
	fl_thigh = MeshBuilder.pivot(rig, Vector3(-0.32,0.72, 0.36))
	var fl: Array[Node3D] = _leg(fl_thigh,-1.0); fl_shin=fl[0]; fl_foot=fl[1]
	fr_thigh = MeshBuilder.pivot(rig, Vector3( 0.32,0.72, 0.36))
	var fr: Array[Node3D] = _leg(fr_thigh, 1.0); fr_shin=fr[0]; fr_foot=fr[1]

func _back_legs() -> void:
	bl_thigh = MeshBuilder.pivot(rig, Vector3(-0.30,0.70,-0.34))
	var bl: Array[Node3D] = _leg(bl_thigh,-1.0); bl_shin=bl[0]; bl_foot=bl[1]
	br_thigh = MeshBuilder.pivot(rig, Vector3( 0.30,0.70,-0.34))
	var br: Array[Node3D] = _leg(br_thigh, 1.0); br_shin=br[0]; br_foot=br[1]

func _leg(tp: Node3D, side: float) -> Array[Node3D]:
	MeshBuilder.box(tp, Vector3(0,-0.16,0.02), Vector3(0.20,0.34,0.22), B())
	MeshBuilder.sphere(tp, Vector3(0,-0.34,0.06), 0.08, S())
	var shin: Node3D = MeshBuilder.pivot(tp, Vector3(0,-0.36,0.06))
	MeshBuilder.box(shin, Vector3(0,-0.14,-0.02), Vector3(0.14,0.28,0.16), B())
	MeshBuilder.sphere(shin, Vector3(0,-0.28,0.00), 0.06, S())
	var foot: Node3D = MeshBuilder.pivot(shin, Vector3(0,-0.30,-0.02))
	MeshBuilder.box(foot, Vector3(0,-0.04,0.08), Vector3(0.18,0.08,0.28), B())
	MeshBuilder.box(foot, Vector3(0,-0.08,0.06), Vector3(0.14,0.04,0.22), V())
	for tt in range(4):
		var tx: float = (-0.09+float(tt)*0.06)*side
		MeshBuilder.box(foot, Vector3(tx,-0.04,0.18+float(tt)*0.01), Vector3(0.04,0.06,0.14), B())
		MeshBuilder.box(foot, Vector3(tx,-0.04,0.30+float(tt)*0.01), Vector3(0.035,0.05,0.10), B())
		MeshBuilder.box(foot, Vector3(tx,-0.07,0.37+float(tt)*0.01), Vector3(0.028,0.04,0.08), C())
	MeshBuilder.box(foot, Vector3(0,0.02,-0.06), Vector3(0.06,0.10,0.05), C())
	for sc in range(3):
		MeshBuilder.box(tp, Vector3(side*0.10,-0.08-float(sc)*0.08,0.08), Vector3(0.06,0.06,0.10), S())
	return [shin, foot]

# ── Wings ─────────────────────────────────────────────────────────────────────
func _wings() -> void:
	_single_wing(-1.0)
	_single_wing( 1.0)

func _single_wing(sx: float) -> void:
	var shoulder: Node3D = MeshBuilder.pivot(rig, Vector3(sx*0.42,0.96,0.22))
	shoulder.rotation.z = sx * 0.18
	MeshBuilder.sphere(shoulder, Vector3(0,0,0), 0.095, S())
	MeshBuilder.box(shoulder, Vector3(sx*0.28,-0.04,0.0), Vector3(0.58,0.13,0.15), B())
	MeshBuilder.box(shoulder, Vector3(sx*0.28,-0.02,0.0), Vector3(0.54,0.08,0.10), S())

	var elbow: Node3D = MeshBuilder.pivot(shoulder, Vector3(sx*0.60,-0.06,0.0))
	MeshBuilder.sphere(elbow, Vector3(0,0,0), 0.085, S())
	MeshBuilder.box(elbow, Vector3(sx*0.32,0.0,0.0),  Vector3(0.66,0.10,0.12), B())
	MeshBuilder.box(elbow, Vector3(sx*0.32,0.02,0.0), Vector3(0.62,0.06,0.08), S())
	if sx < 0.0: wing_l2 = elbow
	else:        wing_r2 = elbow

	var wrist: Node3D = MeshBuilder.pivot(elbow, Vector3(sx*0.66,0.0,0.0))
	MeshBuilder.sphere(wrist, Vector3(0,0,0), 0.072, S())
	if sx < 0.0: wing_l3 = wrist
	else:        wing_r3 = wrist

	var flen: Array[float] = [0.55,0.85,1.05,1.20,1.10]
	var fz_arr: Array[float] = [-0.08,0.04,0.16,0.28,0.40]
	for fi in range(5):
		var fl: float = flen[fi]; var fz: float = fz_arr[fi]
		var fb: Node3D = MeshBuilder.pivot(wrist, Vector3(0,0,fz))
		MeshBuilder.box(fb, Vector3(sx*fl*0.28,0.0,0.0),  Vector3(fl*0.56,0.055,0.055), B())
		MeshBuilder.box(fb, Vector3(sx*fl*0.28,0.02,0.0), Vector3(fl*0.56,0.015,0.015), G())
		var fm: Node3D = MeshBuilder.pivot(fb, Vector3(sx*fl*0.56,0.0,0.0))
		MeshBuilder.box(fm, Vector3(sx*fl*0.22,0.0,0.0), Vector3(fl*0.44,0.040,0.040), B())
		var ft: Node3D = MeshBuilder.pivot(fm, Vector3(sx*fl*0.44,0.0,0.0))
		MeshBuilder.box(ft, Vector3(sx*0.06,-0.02,0.0), Vector3(0.12,0.05,0.04), C())

	MeshBuilder.box(wrist, Vector3(sx*0.08, 0.10,-0.18), Vector3(0.07,0.18,0.07), C())
	MeshBuilder.box(wrist, Vector3(sx*0.08, 0.20,-0.22), Vector3(0.05,0.14,0.05), C())
	MeshBuilder.box(shoulder, Vector3(sx*0.28,-0.08, 0.18), Vector3(0.58,0.05,0.52), W())
	MeshBuilder.box(elbow,    Vector3(sx*0.32,-0.06, 0.22), Vector3(0.66,0.05,0.56), W())
	MeshBuilder.box(wrist,    Vector3(sx*0.20,-0.05, 0.24), Vector3(0.42,0.04,0.52), W())
	MeshBuilder.box(shoulder, Vector3(sx*0.28,-0.06,-0.06), Vector3(0.58,0.04,0.20), W())
	MeshBuilder.box(elbow,    Vector3(sx*0.32,-0.05,-0.06), Vector3(0.66,0.04,0.18), W())
	MeshBuilder.box(wrist,    Vector3(sx*0.20,-0.04, 0.52), Vector3(0.42,0.035,0.48), W())
	for gi in range(4):
		MeshBuilder.box(wrist, Vector3(sx*0.20,-0.025,0.06+float(gi)*0.14), Vector3(0.40,0.018,0.018), G())
	MeshBuilder.box(rig, Vector3(sx*0.68,0.82,0.18), Vector3(0.26,0.05,0.56), W())
	MeshBuilder.box(rig, Vector3(sx*0.55,0.88,0.06), Vector3(0.16,0.04,0.32), W())
	MeshBuilder.box(rig, Vector3(sx*0.62,0.85,0.20), Vector3(0.24,0.018,0.018), G())
	MeshBuilder.box(rig, Vector3(sx*0.62,0.85,0.32), Vector3(0.24,0.018,0.018), G())

	if sx < 0.0: wing_l = shoulder
	else:        wing_r = shoulder

# ── Tail ──────────────────────────────────────────────────────────────────────
func _tail() -> void:
	tail.clear()
	var tsz: Array[Vector3] = [
		Vector3(0.38,0.30,0.28),Vector3(0.32,0.26,0.26),Vector3(0.26,0.22,0.24),
		Vector3(0.20,0.18,0.22),Vector3(0.16,0.14,0.20),Vector3(0.12,0.10,0.18),
		Vector3(0.08,0.07,0.16),Vector3(0.05,0.05,0.14)]
	var tp2: Node3D = rig
	for i in range(8):
		var off: Vector3 = Vector3(0,0.68,-0.52) if i==0 else Vector3(0,0,-tsz[i-1].z)
		var tp: Node3D = MeshBuilder.pivot(tp2, off)
		MeshBuilder.box(tp, Vector3(0,0,-tsz[i].z*0.5), tsz[i], B())
		if i < 6:
			var fh: float = 0.18 - float(i)*0.02
			MeshBuilder.box(tp, Vector3(0,tsz[i].y*0.55,-tsz[i].z*0.4), Vector3(0.05,fh,0.06), G())
		if i < 4:
			MeshBuilder.box(tp, Vector3(-tsz[i].x*0.55,0,-tsz[i].z*0.4), Vector3(0.04,tsz[i].y*0.6,0.06), S())
			MeshBuilder.box(tp, Vector3( tsz[i].x*0.55,0,-tsz[i].z*0.4), Vector3(0.04,tsz[i].y*0.6,0.06), S())
		tail.append(tp); tp2 = tp
	MeshBuilder.box(tp2, Vector3(0, 0.10,-0.14), Vector3(0.04,0.22,0.14), G())
	MeshBuilder.box(tp2, Vector3(0,-0.06,-0.14), Vector3(0.04,0.12,0.14), G())
	MeshBuilder.box(tp2, Vector3(-0.10,0.02,-0.14), Vector3(0.20,0.04,0.14), G())
