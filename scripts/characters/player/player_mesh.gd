## PlayerMesh – Block-out siêu chi tiết phong cách soulslike (gần voxel).
## Cơ thể = ~170 khối BoxMesh + ~74 xương Node3D theo hierarchy:
##   Pelvis→Spine_01/02/03→Neck_01/02→Head (jaw/eye/lid/brow/cheek/lip/ear)
##   Clavicle→UpperArm→Forearm→Hand→14 đốt ngón (thumb×2 + 4 ngón×3)
##   Thigh→Calf→Foot→Toe ; Cape_01..06 (chuỗi vật lý sau lưng)
## Pivot cũ (weapon/helmet/armor...) giữ tên để hệ equipment chạy nguyên vẹn.
class_name PlayerMesh

var _palette: Dictionary = {}

var bones: Dictionary = {}

var ground_anchor: Node3D
var rig:     Node3D
var head:    Node3D
var body:    Node3D
var torso:   Node3D
var backpack: Node3D
var arm_l:   Node3D
var arm_r:   Node3D
var leg_l:   Node3D
var leg_r:   Node3D
var weapon_pivot:      Node3D
var helmet_pivot:      Node3D
var hair_pivot:        Node3D
var tails_pivot:       Node3D
var chestplate_pivot:  Node3D
var gauntlet_l_pivot:  Node3D
var gauntlet_r_pivot:  Node3D
var leg_armor_l_pivot: Node3D
var leg_armor_r_pivot: Node3D
var boot_l_pivot:      Node3D
var boot_r_pivot:      Node3D
var ring_pivot:        Node3D
var back_gear_pivot:   Node3D

var box_count: int = 0

## ── Palette helpers ────────────────────────────────────────────────────────
func set_palette(palette: Dictionary) -> void:
	_palette = palette

func _c(key: String, fallback: Color) -> Color:
	return _palette.get(key, fallback)

func apply_palette(palette_new: Dictionary) -> void:
	_palette = palette_new
	for key in _mats:
		if _palette.has(key):
			_mats[key].albedo_color = _palette[key]

## ── Node builders ──────────────────────────────────────────────────────────
func make_rig(root: Node3D, lift: float = 0.0) -> Node3D:
	ground_anchor = MeshBuilder.pivot(root, Vector3(0, lift, 0))
	ground_anchor.name = "GroundAnchor"
	rig = MeshBuilder.pivot(ground_anchor, Vector3(0, 0.02, 0))
	rig.name = "PlayerRig"
	return rig

func _bone(parent: Node3D, bone_name: String, pos: Vector3) -> Node3D:
	var n := MeshBuilder.pivot(parent, pos)
	n.name = bone_name
	bones[bone_name] = n
	return n

func _box(parent: Node3D, pos: Vector3, sz: Vector3,
		  mat: StandardMaterial3D) -> MeshInstance3D:
	box_count += 1
	return MeshBuilder.box(parent, pos, sz, mat)

func _sphere(parent: Node3D, pos: Vector3, r: float,
			 mat: StandardMaterial3D) -> MeshInstance3D:
	box_count += 1
	return MeshBuilder.sphere(parent, pos, r, mat)

## ── Build toàn bộ ──────────────────────────────────────────────────────────
func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = make_rig(root, 0.12)
	_build_skeleton()
	_build_pelvis_legs()
	_build_torso()
	_build_arms()
	_build_head_face()
	_build_cape()
	_build_armor()

# ── Materials ──────────────────────────────────────────────────────────────
var _mats: Dictionary = {}
var _sk:  StandardMaterial3D
var _hr:  StandardMaterial3D
var _hd:  StandardMaterial3D
var _ew:  StandardMaterial3D
var _ei:  StandardMaterial3D
var _ep:  StandardMaterial3D
var _eg:  StandardMaterial3D
var _br:  StandardMaterial3D
var _mth: StandardMaterial3D
var _cl:  StandardMaterial3D
var _cld: StandardMaterial3D
var _le:  StandardMaterial3D
var _led: StandardMaterial3D
var _me:  StandardMaterial3D
var _med: StandardMaterial3D
var _mel: StandardMaterial3D
var _gd:  StandardMaterial3D
var _cp:  StandardMaterial3D
var _cpd: StandardMaterial3D
var _sol: StandardMaterial3D

func _make_materials() -> void:
	_sk  = MeshBuilder.emit_mat(_c("skin", Color(0.92, 0.80, 0.70)), Color(0,0,0), 0)
	_hr  = MeshBuilder.emit_mat(_c("hair", Color(0.35, 0.26, 0.18)), Color(0,0,0), 0)
	_hd  = MeshBuilder.emit_mat(_c("hair_dark", Color(0.22, 0.16, 0.10)), Color(0,0,0), 0)
	_ew  = MeshBuilder.emit_mat(_c("eye_white", Color(1.00, 1.00, 1.00)), Color(0,0,0), 0)
	_ei  = MeshBuilder.emit_mat(_c("eye_iris", Color(0.42, 0.55, 0.62)), Color(0,0,0), 0)
	_ep  = MeshBuilder.emit_mat(_c("eye_pupil", Color(0.06, 0.05, 0.05)), Color(0,0,0), 0)
	_eg  = MeshBuilder.emit_mat(_c("eye_glint", Color(1.00, 1.00, 1.00)), Color(1,1,1), 1.5)
	_br  = MeshBuilder.emit_mat(_c("brow", Color(0.30, 0.22, 0.15)), Color(0,0,0), 0)
	_mth = MeshBuilder.emit_mat(_c("mouth", Color(0.62, 0.35, 0.32)), Color(0,0,0), 0)
	_cl  = MeshBuilder.emit_mat(_c("cloth", Color(0.34, 0.36, 0.32)), Color(0,0,0), 0)
	_cld = MeshBuilder.emit_mat(_c("cloth_dark", Color(0.24, 0.26, 0.22)), Color(0,0,0), 0)
	_le  = MeshBuilder.emit_mat(_c("leather", Color(0.42, 0.30, 0.20)), Color(0,0,0), 0)
	_led = MeshBuilder.emit_mat(_c("leather_dark", Color(0.30, 0.21, 0.14)), Color(0,0,0), 0)
	_me  = MeshBuilder.emit_mat(_c("metal", Color(0.62, 0.64, 0.66)), Color(0,0,0), 0)
	_med = MeshBuilder.emit_mat(_c("metal_dark", Color(0.42, 0.44, 0.47)), Color(0,0,0), 0)
	_mel = MeshBuilder.emit_mat(_c("metal_light", Color(0.78, 0.80, 0.83)), Color(0,0,0), 0)
	_gd  = MeshBuilder.emit_mat(_c("gold", Color(0.85, 0.66, 0.30)), Color(0,0,0), 0)
	_cp  = MeshBuilder.emit_mat(_c("cape", Color(0.55, 0.10, 0.10)), Color(0,0,0), 0)
	_cpd = MeshBuilder.emit_mat(_c("cape_dark", Color(0.38, 0.07, 0.07)), Color(0,0,0), 0)
	_sol = MeshBuilder.emit_mat(_c("sole", Color(0.22, 0.16, 0.12)), Color(0,0,0), 0)
	_mats = {
		"skin": _sk, "hair": _hr, "hair_dark": _hd, "eye_white": _ew,
		"eye_iris": _ei, "eye_pupil": _ep, "eye_glint": _eg, "brow": _br,
		"mouth": _mth, "cloth": _cl, "cloth_dark": _cld, "leather": _le,
		"leather_dark": _led, "metal": _me, "metal_dark": _med,
		"metal_light": _mel, "gold": _gd, "cape": _cp, "cape_dark": _cpd,
		"sole": _sol,
	}

# ── Skeleton hierarchy ─────────────────────────────────────────────────────
var pelvis:    Node3D
var spine_01:  Node3D
var spine_02:  Node3D
var spine_03:  Node3D
var neck_01:   Node3D
var neck_02:   Node3D
var jaw:       Node3D
var elbow_l:   Node3D
var elbow_r:   Node3D
var knee_l:    Node3D
var knee_r:    Node3D

func _build_skeleton() -> void:
	pelvis = _bone(rig, "pelvis", Vector3(0, 0.92, 0))
	spine_01 = _bone(pelvis, "spine_01", Vector3(0, 0.07, 0))
	spine_02 = _bone(spine_01, "spine_02", Vector3(0, 0.09, 0))
	spine_03 = _bone(spine_02, "spine_03", Vector3(0, 0.10, 0))
	body = spine_03
	neck_01 = _bone(spine_03, "neck_01", Vector3(0, 0.07, 0))
	neck_02 = _bone(neck_01, "neck_02", Vector3(0, 0.055, 0))
	head = _bone(neck_02, "head", Vector3(0, 0.08, 0))
	jaw = _bone(head, "jaw", Vector3(0, -0.155, -0.03))
	# Mặt (facial rig)
	_bone(head, "eye_l",  Vector3(-0.105, 0.01, -0.165))
	_bone(head, "eye_r",  Vector3( 0.105, 0.01, -0.165))
	_bone(head, "eyelid_up_l",   Vector3(-0.105, 0.075, -0.16))
	_bone(head, "eyelid_low_l",  Vector3(-0.105, -0.055, -0.16))
	_bone(head, "eyelid_up_r",   Vector3( 0.105, 0.075, -0.16))
	_bone(head, "eyelid_low_r",  Vector3( 0.105, -0.055, -0.16))
	_bone(head, "brow_in_l",  Vector3(-0.075, 0.105, -0.165))
	_bone(head, "brow_out_l", Vector3(-0.135, 0.105, -0.165))
	_bone(head, "brow_in_r",  Vector3( 0.075, 0.105, -0.165))
	_bone(head, "brow_out_r", Vector3( 0.135, 0.105, -0.165))
	_bone(head, "cheek_l", Vector3(-0.155, -0.06, -0.10))
	_bone(head, "cheek_r", Vector3( 0.155, -0.06, -0.10))
	_bone(head, "lip_corner_l", Vector3(-0.095, -0.115, -0.185))
	_bone(head, "lip_corner_r", Vector3( 0.095, -0.115, -0.185))
	_bone(head, "lip_up",  Vector3(0, -0.095, -0.195))
	_bone(head, "lip_low", Vector3(0, -0.125, -0.185))
	_bone(head, "ear_l", Vector3(-0.21, 0.0, -0.01))
	_bone(head, "ear_r", Vector3( 0.21, 0.0, -0.01))
	# Tay
	arm_l = _bone(spine_03, "clavicle_l", Vector3(-0.20, 0.025, 0))
	_build_arm_chain(arm_l, "l")
	arm_r = _bone(spine_03, "clavicle_r", Vector3( 0.20, 0.025, 0))
	_build_arm_chain(arm_r, "r")
	# Chân
	leg_l = _bone(pelvis, "thigh_l", Vector3(-0.10, -0.045, 0))
	_build_leg_chain(leg_l, "l")
	leg_r = _bone(pelvis, "thigh_r", Vector3( 0.10, -0.045, 0))
	_build_leg_chain(leg_r, "r")
	# Cape chain (vật lý sau lưng)
	var cape_prev: Node3D = spine_03
	for i in range(6):
		var cn := "cape_%02d" % (i + 1)
		cape_prev = _bone(cape_prev, cn, Vector3(-0.04, -0.06, -0.14))
	# Pivot thiết bị (compat) — weapon theo tay phải, ring theo tay trái
	weapon_pivot = MeshBuilder.pivot(bones["hand_r"], Vector3(0.02, -0.04, 0.10))
	weapon_pivot.name = "WeaponPivot"
	ring_pivot = MeshBuilder.pivot(bones["hand_l"], Vector3(0.02, -0.04, 0.02))
	ring_pivot.name = "RingPivot"
	helmet_pivot = MeshBuilder.pivot(head, Vector3(0, 0.05, 0))
	helmet_pivot.name = "HelmetPivot"
	hair_pivot = MeshBuilder.pivot(head, Vector3(0, 0.02, 0))
	hair_pivot.name = "HairPivot"
	tails_pivot = MeshBuilder.pivot(head, Vector3(0, 0.02, -0.02))
	tails_pivot.name = "TailsPivot"
	chestplate_pivot = MeshBuilder.pivot(spine_02, Vector3(0, 0.02, 0.05))
	chestplate_pivot.name = "ChestplatePivot"
	back_gear_pivot = MeshBuilder.pivot(spine_02, Vector3(0, 0.0, -0.16))
	back_gear_pivot.name = "BackGearPivot"
	backpack = MeshBuilder.pivot(spine_02, Vector3(0, 0.01, -0.17))
	backpack.name = "Backpack"

func _build_arm_chain(parent: Node3D, side: String) -> void:
	var up := _bone(parent, "upper_arm_%s" % side, Vector3(0, -0.07, 0))
	var fo := _bone(up, "forearm_%s" % side, Vector3(0, -0.30, 0))
	var ha := _bone(fo, "hand_%s" % side, Vector3(0, -0.26, 0))
	if side == "l":
		elbow_l = fo
	else:
		elbow_r = fo
	_build_finger(ha, side, "thumb", 2)
	_build_finger(ha, side, "index", 3)
	_build_finger(ha, side, "middle", 3)
	_build_finger(ha, side, "ring", 3)
	_build_finger(ha, side, "pinky", 3)
	var g_pivot := MeshBuilder.pivot(fo, Vector3(0, -0.04, 0))
	g_pivot.name = "Gauntlet%sPivot" % ("L" if side == "l" else "R")
	if side == "l":
		gauntlet_l_pivot = g_pivot
	else:
		gauntlet_r_pivot = g_pivot

func _build_finger(hand: Node3D, side: String, fname: String, segs: int) -> void:
	var p: Node3D = hand
	for s in range(segs):
		var bn := "%s_%02d_%s" % [fname, s + 1, side]
		p = _bone(p, bn, Vector3(0, -0.05, 0.025))

func _build_leg_chain(parent: Node3D, side: String) -> void:
	var ca := _bone(parent, "calf_%s" % side, Vector3(0, -0.33, 0))
	if side == "l":
		knee_l = ca
	else:
		knee_r = ca
	var fo := _bone(ca, "foot_%s" % side, Vector3(0, -0.30, 0))
	_bone(fo, "toe_%s" % side, Vector3(0, -0.035, 0.14))
	var l_pivot := MeshBuilder.pivot(parent, Vector3(0, -0.05, -0.02))
	l_pivot.name = "LegArmor%sPivot" % ("L" if side == "l" else "R")
	var b_pivot := MeshBuilder.pivot(fo, Vector3(0, -0.02, 0.02))
	b_pivot.name = "Boot%sPivot" % ("L" if side == "l" else "R")
	if side == "l":
		leg_armor_l_pivot = l_pivot
		boot_l_pivot = b_pivot
	else:
		leg_armor_r_pivot = l_pivot
		boot_r_pivot = b_pivot

# __CHUNK_SKELETON_END__

# ── Geometry: chậu + chân ──────────────────────────────────────────────────
func _build_pelvis_legs() -> void:
	_box(pelvis, Vector3(0, -0.02, 0),    Vector3(0.30, 0.13, 0.20), _le)
	_box(pelvis, Vector3(-0.11, -0.05, -0.11), Vector3(0.12, 0.11, 0.06), _me)
	_box(pelvis, Vector3( 0.11, -0.05, -0.11), Vector3(0.12, 0.11, 0.06), _me)
	_box(pelvis, Vector3(0, 0.035, -0.10), Vector3(0.13, 0.08, 0.09), _led)
	# Đùi trước/sau/trong/ngoài
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var th: Node3D = bones["thigh_%s" % side]
		_box(th, Vector3(0, -0.14, 0.035),  Vector3(0.155, 0.28, 0.09), _le)
		_box(th, Vector3(0, -0.15, -0.045), Vector3(0.155, 0.25, 0.09), _led)
		_box(th, Vector3(sx * -0.045, -0.15, 0), Vector3(0.07, 0.27, 0.15), _le)
		_box(th, Vector3(sx * 0.055, -0.15, 0),  Vector3(0.07, 0.27, 0.15), _led)
		_box(th, Vector3(0, -0.32, 0.03),  Vector3(0.125, 0.05, 0.115), _mel)
		var ca: Node3D = bones["calf_%s" % side]
		_box(ca, Vector3(0, -0.13, -0.04), Vector3(0.135, 0.27, 0.075), _led)
		_box(ca, Vector3(0, -0.13,  0.045), Vector3(0.135, 0.27, 0.085), _le)
		_box(ca, Vector3(0, -0.27, 0.0),   Vector3(0.115, 0.06, 0.115), _mel)
		var fo: Node3D = bones["foot_%s" % side]
		_box(fo, Vector3(0, -0.02, -0.03), Vector3(0.155, 0.11, 0.17), _med)
		_box(fo, Vector3(0, -0.065, 0.065), Vector3(0.16, 0.07, 0.13), _led)
		_box(fo, Vector3(0, -0.115, 0.03), Vector3(0.165, 0.03, 0.23), _sol)
		_box(fo, Vector3(0, -0.045, 0.15), Vector3(0.16, 0.07, 0.09), _me)
		var to: Node3D = bones["toe_%s" % side]
		_box(to, Vector3(0, -0.02, 0.02), Vector3(0.145, 0.06, 0.09), _med)

# ── Geometry: thân trên ────────────────────────────────────────────────────
func _build_torso() -> void:
	torso = MeshBuilder.pivot(spine_01, Vector3(0, 0.0, 0))
	torso.name = "Torso"
	# Ngực
	_box(torso, Vector3(0, 0.21, 0.02),  Vector3(0.32, 0.17, 0.19), _cl)
	_box(torso, Vector3(0, 0.08, 0.03),  Vector3(0.30, 0.16, 0.18), _cl)
	_box(torso, Vector3(0, 0.16, 0.13),  Vector3(0.09, 0.13, 0.06), _cld)
	# Sườn T/P ×2
	_box(torso, Vector3(-0.20, 0.13, 0.0), Vector3(0.08, 0.09, 0.15), _cld)
	_box(torso, Vector3(-0.20, 0.03, 0.0), Vector3(0.08, 0.09, 0.15), _cld)
	_box(torso, Vector3( 0.20, 0.13, 0.0), Vector3(0.08, 0.09, 0.15), _cld)
	_box(torso, Vector3( 0.20, 0.03, 0.0), Vector3(0.08, 0.09, 0.15), _cld)
	# Bụng
	_box(torso, Vector3(0, -0.10, 0.03), Vector3(0.29, 0.15, 0.18), _cl)
	_box(torso, Vector3(0, -0.22, 0.03), Vector3(0.28, 0.14, 0.18), _cl)
	_box(torso, Vector3(0, -0.14, 0.12), Vector3(0.045, 0.03, 0.035), _led)
	_box(torso, Vector3(-0.18, -0.16, 0.02), Vector3(0.06, 0.11, 0.17), _le)
	_box(torso, Vector3( 0.18, -0.16, 0.02), Vector3(0.06, 0.11, 0.17), _le)
	# Lưng
	_box(torso, Vector3(0, 0.19, -0.13), Vector3(0.29, 0.15, 0.07), _cld)
	_box(torso, Vector3(0, 0.05, -0.14), Vector3(0.28, 0.14, 0.08), _cld)
	_box(torso, Vector3(0, -0.13, -0.13), Vector3(0.27, 0.13, 0.08), _cld)
	_box(torso, Vector3(0, -0.23, -0.11), Vector3(0.24, 0.09, 0.06), _led)
	# Vai — cầu khớp
	_sphere(spine_03, Vector3(-0.22, 0.0, 0.02), 0.065, _me)
	_sphere(spine_03, Vector3( 0.22, 0.0, 0.02), 0.065, _me)
	# Thắt lưng + khóa
	_box(spine_01, Vector3(0, 0.02, 0.01), Vector3(0.30, 0.05, 0.20), _led)
	_box(spine_01, Vector3(0, 0.02, 0.115), Vector3(0.06, 0.045, 0.02), _gd)

# ── Geometry: tay ──────────────────────────────────────────────────────────
func _build_arms() -> void:
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var up: Node3D = bones["upper_arm_%s" % side]
		_box(up, Vector3(0, -0.11, 0.02),  Vector3(0.135, 0.22, 0.11), _le)
		_box(up, Vector3(0, -0.145, -0.045), Vector3(0.125, 0.19, 0.10), _led)
		_box(up, Vector3(0, -0.26, 0.005), Vector3(0.105, 0.07, 0.105), _mel)
		var fo: Node3D = bones["forearm_%s" % side]
		_box(fo, Vector3(0, -0.10, 0.02),  Vector3(0.115, 0.21, 0.095), _le)
		_box(fo, Vector3(0, -0.17, -0.03), Vector3(0.105, 0.17, 0.085), _led)
		var ha: Node3D = bones["hand_%s" % side]
		_box(ha, Vector3(0, -0.015, 0.025), Vector3(0.135, 0.09, 0.145), _sk)
		_box(ha, Vector3(0, -0.05, -0.055), Vector3(0.125, 0.07, 0.07), _led)
		_build_finger_blocks(ha, side)

func _build_finger_blocks(hand: Node3D, side: String) -> void:
	var specs := {
		"thumb":  {"segs": 2, "sz": Vector3(0.032, 0.065, 0.038), "x": 0.055},
		"index":  {"segs": 3, "sz": Vector3(0.034, 0.075, 0.034), "x": -0.038},
		"middle": {"segs": 3, "sz": Vector3(0.034, 0.08, 0.034), "x": -0.013},
		"ring":   {"segs": 3, "sz": Vector3(0.032, 0.075, 0.032), "x": 0.013},
		"pinky":  {"segs": 3, "sz": Vector3(0.028, 0.065, 0.028), "x": 0.038},
	}
	for fname in specs:
		var sp: Dictionary = specs[fname]
		var sz: Vector3 = sp["sz"]
		var xo: float = sp["x"]
		for s in range(int(sp["segs"])):
			var bn := "%s_%02d_%s" % [fname, s + 1, side]
			var bone_n: Node3D = bones.get(bn)
			if bone_n == null:
				continue
			var py: float = -0.025 + s * -0.045
			var pz: float = 0.03 - s * 0.008
			_box(bone_n, Vector3(xo, py, pz), sz, _sk)

# __CHUNK_GEOM_END__

# ── Geometry: đầu + mặt ────────────────────────────────────────────────────
func _build_head_face() -> void:
	# Hộp sọ / trán / thái dương / gò má
	_box(head, Vector3(0, 0.02, -0.01),  Vector3(0.40, 0.37, 0.34), _sk)
	_box(head, Vector3(0, 0.16, -0.04),  Vector3(0.30, 0.12, 0.26), _sk)
	_box(head, Vector3(-0.20, 0.0, 0.02), Vector3(0.05, 0.13, 0.20), _sk)
	_box(head, Vector3( 0.20, 0.0, 0.02), Vector3(0.05, 0.13, 0.20), _sk)
	_box(head, Vector3(0, -0.05, 0.13),  Vector3(0.24, 0.08, 0.08), _sk)
	_box(head, Vector3(-0.12, -0.13, 0.10), Vector3(0.10, 0.16, 0.23), _sk)
	_box(head, Vector3( 0.12, -0.13, 0.10), Vector3(0.10, 0.16, 0.23), _sk)
	# Mũi
	_box(head, Vector3(0, 0.05, 0.175), Vector3(0.055, 0.10, 0.045), _sk)
	_box(head, Vector3(0, -0.015, 0.185), Vector3(0.07, 0.055, 0.035), _sk)
	_box(head, Vector3(-0.03, 0.0, 0.19), Vector3(0.03, 0.02, 0.02), _hd)
	_box(head, Vector3( 0.03, 0.0, 0.19), Vector3(0.03, 0.02, 0.02), _hd)
	# Mắt (white/iris/pupil/glint)
	for side in [[-1, "l"], [1, "r"]]:
		var sx: float = side[0]
		var sg: String = side[1]
		var ey: Node3D = bones["eye_%s" % sg]
		_box(ey, Vector3(0, 0.0, 0.0), Vector3(0.085, 0.09, 0.03), _ew)
		_box(ey, Vector3(0, 0.0, 0.012), Vector3(0.055, 0.065, 0.015), _ei)
		_box(ey, Vector3(0, 0.0, 0.022), Vector3(0.03, 0.04, 0.01), _ep)
		_box(ey, Vector3(0.012, 0.012, 0.028), Vector3(0.02, 0.02, 0.008), _eg)
		# Mí trên/dưới
		var ul: Node3D = bones["eyelid_up_%s" % sg]
		var ll: Node3D = bones["eyelid_low_%s" % sg]
		_box(ul, Vector3(0, 0.005, 0.0), Vector3(0.09, 0.025, 0.03), _sk)
		_box(ll, Vector3(0, -0.005, 0.0), Vector3(0.08, 0.02, 0.03), _sk)
		# Lông mày trong/ngoài
		var bi: Node3D = bones["brow_in_%s" % sg]
		var bo: Node3D = bones["brow_out_%s" % sg]
		_box(bi, Vector3(0, 0.0, 0.0), Vector3(0.075, 0.022, 0.02), _hd)
		_box(bo, Vector3(0, 0.0, 0.0), Vector3(0.075, 0.022, 0.02), _hd)
		# Má
		var ch: Node3D = bones["cheek_%s" % sg]
		_box(ch, Vector3(0, 0.0, -0.02), Vector3(0.06, 0.075, 0.05), _sk)
		# Tai
		var er: Node3D = bones["ear_%s" % sg]
		_box(er, Vector3(0, 0.0, 0.0), Vector3(0.045, 0.10, 0.06), _sk)
	# Miệng: môi trên/dưới + khóe
	var lu: Node3D = bones["lip_up"]
	var llw: Node3D = bones["lip_low"]
	_box(lu, Vector3(0, 0.0, 0.0), Vector3(0.10, 0.022, 0.02), _mth)
	_box(llw, Vector3(0, 0.0, 0.0), Vector3(0.09, 0.02, 0.02), _mth)
	_box(bones["lip_corner_l"], Vector3(0, 0.0, 0.0), Vector3(0.025, 0.02, 0.015), _mth)
	_box(bones["lip_corner_r"], Vector3(0, 0.0, 0.0), Vector3(0.025, 0.02, 0.015), _mth)
	# Hàm dưới (mandible tách — mở/đóng miệng)
	_box(jaw, Vector3(0, 0.0, 0.04), Vector3(0.21, 0.07, 0.13), _sk)
	_box(jaw, Vector3(0, 0.02, 0.07), Vector3(0.10, 0.02, 0.035), _mth)
	_box(jaw, Vector3(0, -0.05, 0.03), Vector3(0.13, 0.05, 0.07), _sk)
	# Cằm
	_box(head, Vector3(0, -0.17, 0.09), Vector3(0.11, 0.055, 0.07), _sk)
	# Cổ
	_box(neck_01, Vector3(0, 0.0, 0.01), Vector3(0.135, 0.08, 0.135), _sk)
	_box(neck_02, Vector3(0, 0.0, 0.005), Vector3(0.125, 0.075, 0.125), _sk)
	_box(neck_02, Vector3(0, 0.0, 0.035), Vector3(0.09, 0.035, 0.035), _hd)

# ── Geometry: cape ─────────────────────────────────────────────────────────
func _build_cape() -> void:
	for i in range(6):
		var bn: Node3D = bones.get("cape_%02d" % (i + 1))
		if bn == null:
			continue
		var scale_f: float = 1.0 - i * 0.05
		var w: float = 0.40 * scale_f
		var dark := i % 2 == 1
		var mat := _cpd if dark else _cp
		_box(bn, Vector3(0.10, 0.0, 0.0), Vector3(0.20 * scale_f, 0.055, 0.030), mat)
		_box(bn, Vector3(-0.10, 0.0, 0.0), Vector3(0.20 * scale_f, 0.055, 0.030), mat)
		_box(bn, Vector3(0, 0.0, -0.02), Vector3(0.40 * scale_f, 0.035, 0.022), _cpd)

# ── Geometry: giáp trụ ─────────────────────────────────────────────────────
func _build_armor() -> void:
	# Mũ giáp (trên helmet_pivot — ẩn khi đội mũ equipment)
	_box(helmet_pivot, Vector3(0, 0.03, -0.02), Vector3(0.42, 0.14, 0.36), _med)
	_box(helmet_pivot, Vector3(0, 0.02, -0.19), Vector3(0.34, 0.10, 0.06), _mel)
	_box(helmet_pivot, Vector3(0, -0.09, 0.0), Vector3(0.38, 0.07, 0.32), _med)
	_box(helmet_pivot, Vector3(0, -0.10, -0.10), Vector3(0.30, 0.055, 0.09), _mel)
	_box(helmet_pivot, Vector3(0, 0.12, -0.03), Vector3(0.08, 0.05, 0.18), _gd)
	# Pauldron T/P — 2 lớp (trong cố định, ngoài xoay theo vai)
	for side in [[-1, "l"], [1, "r"]]:
		var sx: float = side[0]
		var sg: String = side[1]
		_box(bones["upper_arm_%s" % sg], Vector3(0, -0.02, 0.0), Vector3(0.20, 0.10, 0.19), _me)
		_box(bones["upper_arm_%s" % sg], Vector3(0, 0.02, -0.02), Vector3(0.24, 0.07, 0.23), _med)
	# Giáp ngực + mảnh bụng rời
	_box(chestplate_pivot, Vector3(0, 0.06, -0.02), Vector3(0.31, 0.13, 0.05), _me)
	_box(chestplate_pivot, Vector3(0, -0.05, -0.01), Vector3(0.27, 0.08, 0.04), _med)
	# Bracer tay
	for side in ["l", "r"]:
		var fo: Node3D = bones["forearm_%s" % side]
		_box(fo, Vector3(0, -0.03, 0.0), Vector3(0.12, 0.07, 0.105), _med)
		_box(fo, Vector3(0, -0.13, 0.0), Vector3(0.11, 0.06, 0.095), _mel)
	# Giáp đùi / đầu gối / ống chân / giày
	for side in ["l", "r"]:
		var th: Node3D = bones["thigh_%s" % side]
		var ca: Node3D = bones["calf_%s" % side]
		var fo: Node3D = bones["foot_%s" % side]
		_box(th, Vector3(0, -0.06, -0.02), Vector3(0.16, 0.15, 0.16), _med)
		_box(ca, Vector3(0, -0.01, -0.055), Vector3(0.14, 0.075, 0.055), _me)
		_box(ca, Vector3(0, -0.14, 0.035), Vector3(0.13, 0.09, 0.05), _med)
		_box(fo, Vector3(0, -0.02, 0.08), Vector3(0.16, 0.09, 0.10), _me)
		_box(fo, Vector3(0, -0.10, -0.09), Vector3(0.15, 0.07, 0.07), _mel)

# __CHUNK_FACE_END__