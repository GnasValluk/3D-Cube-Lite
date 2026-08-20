## player_block_mesh.gd
## PlayerBlockMesh – rig khối khớp cho nhân vật player.
## Gồm đủ khớp theo yêu cầu: khối đầu / khớp cổ / thân / 2 khớp vai /
## 2 khớp khuỷu tay / khớp xương chậu / 2 khối đùi / 2 khớp đầu gối /
## 2 khối cẳng chân / khớp cổ chân / 2 bàn chân.
## Vẫn giữ đủ pivot cũ (weapon/helmet/armor...) để hệ thống trang bị + vũ khí hoạt động.
extends PlayerMesh
class_name PlayerBlockMesh

# ── Materials ─────────────────────────────────────────────────────────────────
var _sk:  StandardMaterial3D  # da
var _hr:  StandardMaterial3D  # tóc
var _hd:  StandardMaterial3D  # tóc tối
var _ew:  StandardMaterial3D  # tròng trắng
var _ei:  StandardMaterial3D  # tròng màu
var _ep:  StandardMaterial3D  # con ngươi
var _eg:  StandardMaterial3D  # điểm sáng mắt
var _bsh: StandardMaterial3D  # má hồng
var _sh:  StandardMaterial3D  # áo thân
var _col: StandardMaterial3D  # cổ áo
var _rb:  StandardMaterial3D  # viền/điểm nhấn đỏ
var _sk2: StandardMaterial3D  # quần/đùi
var _sk3: StandardMaterial3D  # cẳng chân
var _sox: StandardMaterial3D  # tất
var _sho: StandardMaterial3D  # giày
var _sol: StandardMaterial3D  # đế giày
var _blt: StandardMaterial3D  # đai lưng
var _mth: StandardMaterial3D  # miệng
var _kny: StandardMaterial3D  # khuy/chi tiết sáng

var _mats: Array[StandardMaterial3D] = []

# ── Build ─────────────────────────────────────────────────────────────────────
func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = make_rig(root, 0.08)
	_build_pelvis()
	_build_legs()
	_build_body()
	_build_arms()
	_build_face()
	_build_hair()
	_build_backpack()

func _make_materials() -> void:
	_sk  = MeshBuilder.emit_mat(_c("skin",       Color(0.99, 0.84, 0.72)), Color(0,0,0), 0)
	_hr  = MeshBuilder.emit_mat(_c("hair",       Color(0.98, 0.62, 0.65)), Color(0,0,0), 0)
	_hd  = MeshBuilder.emit_mat(_c("hair_dark",  Color(0.88, 0.45, 0.52)), Color(0,0,0), 0)
	_ew  = MeshBuilder.emit_mat(_c("eye_white",  Color(1.00, 1.00, 1.00)), Color(0,0,0), 0)
	_ei  = MeshBuilder.emit_mat(_c("eye_iris",   Color(0.95, 0.40, 0.65)), Color(0,0,0), 0)
	_ep  = MeshBuilder.emit_mat(_c("eye_pupil",  Color(0.10, 0.06, 0.12)), Color(0,0,0), 0)
	_eg  = MeshBuilder.emit_mat(_c("eye_glint",  Color(1.00, 1.00, 1.00)), Color(1,1,1), 1.5)
	_bsh = MeshBuilder.emit_mat(_c("blush",      Color(0.98, 0.70, 0.72)), Color(0,0,0), 0)
	_sh  = MeshBuilder.emit_mat(_c("shirt",      Color(0.97, 0.96, 0.98)), Color(0,0,0), 0)
	_col = MeshBuilder.emit_mat(_c("collar",     Color(0.35, 0.42, 0.72)), Color(0,0,0), 0)
	_rb  = MeshBuilder.emit_mat(_c("ribbon",     Color(0.92, 0.22, 0.35)), Color(0,0,0), 0)
	_sk2 = MeshBuilder.emit_mat(_c("skirt",      Color(0.98, 0.72, 0.82)), Color(0,0,0), 0)
	_sk3 = MeshBuilder.emit_mat(_c("skirt_dark", Color(0.88, 0.55, 0.68)), Color(0,0,0), 0)
	_sox = MeshBuilder.emit_mat(_c("socks",      Color(0.96, 0.94, 0.96)), Color(0,0,0), 0)
	_sho = MeshBuilder.emit_mat(_c("shoes",      Color(0.30, 0.20, 0.16)), Color(0,0,0), 0)
	_sol = MeshBuilder.emit_mat(_c("shoe_sole",  Color(0.98, 0.96, 0.95)), Color(0,0,0), 0)
	_blt = MeshBuilder.emit_mat(_c("belt",       Color(0.30, 0.36, 0.62)), Color(0,0,0), 0)
	_mth = MeshBuilder.emit_mat(_c("mouth",      Color(0.90, 0.45, 0.55)), Color(0,0,0), 0)
	_kny = MeshBuilder.emit_mat(_c("button",     Color(1.00, 0.98, 0.96)), Color(0,0,0), 0)
	_mats = [_sk, _hr, _hd, _ew, _ei, _ep, _eg, _bsh, _sh, _col, _rb, _sk2, _sk3, _sox, _sho, _sol, _blt, _mth, _kny]

func apply_palette(palette_new: Dictionary) -> void:
	_palette = palette_new
	_sk .albedo_color = _c("skin",       _sk .albedo_color)
	_hr .albedo_color = _c("hair",       _hr .albedo_color)
	_hd .albedo_color = _c("hair_dark",  _hd .albedo_color)
	_ew .albedo_color = _c("eye_white",  _ew .albedo_color)
	_ei .albedo_color = _c("eye_iris",   _ei .albedo_color)
	_ep .albedo_color = _c("eye_pupil",  _ep .albedo_color)
	_eg .albedo_color = _c("eye_glint",  _eg .albedo_color)
	_bsh.albedo_color = _c("blush",      _bsh.albedo_color)
	_sh .albedo_color = _c("shirt",      _sh .albedo_color)
	_col.albedo_color = _c("collar",     _col.albedo_color)
	_rb .albedo_color = _c("ribbon",     _rb .albedo_color)
	_sk2.albedo_color = _c("skirt",      _sk2.albedo_color)
	_sk3.albedo_color = _c("skirt_dark", _sk3.albedo_color)
	_sox.albedo_color = _c("socks",      _sox.albedo_color)
	_sho.albedo_color = _c("shoes",      _sho.albedo_color)
	_sol.albedo_color = _c("shoe_sole",  _sol.albedo_color)
	_blt.albedo_color = _c("belt",       _blt.albedo_color)
	_mth.albedo_color = _c("mouth",      _mth.albedo_color)
	_kny.albedo_color = _c("button",     _kny.albedo_color)

# ── Xương chậu ────────────────────────────────────────────────────────────────
func _build_pelvis() -> void:
	pelvis = MeshBuilder.pivot(rig, Vector3(0, 0.47, 0))
	pelvis.name = "PelvisJoint"
	# Khối xương chậu / đai hông
	MeshBuilder.box(pelvis, Vector3(0, -0.02, 0), Vector3(0.30, 0.12, 0.20), _sk2)
	MeshBuilder.box(pelvis, Vector3(0, -0.02, 0.105), Vector3(0.08, 0.05, 0.02), _blt)
	MeshBuilder.box(pelvis, Vector3(0, -0.06, 0), Vector3(0.16, 0.04, 0.22), _sho)

# ── Body (phần thân trên) ─────────────────────────────────────────────────────
func _build_body() -> void:
	body = MeshBuilder.pivot(pelvis, Vector3(0, 0.20, 0))
	body.name = "Body"
	torso = MeshBuilder.pivot(body, Vector3(0, 0.06, 0))
	torso.name = "Torso"
	# Khối thân (áo)
	MeshBuilder.box(torso, Vector3(0, 0.00, 0), Vector3(0.34, 0.28, 0.22), _sh)
	MeshBuilder.box(torso, Vector3(0, 0.13, 0), Vector3(0.28, 0.06, 0.18), _col)
	MeshBuilder.box(torso, Vector3(0, 0.10, 0.11), Vector3(0.10, 0.04, 0.02), _kny)
	# Đai lưng
	MeshBuilder.box(torso, Vector3(0, -0.12, 0), Vector3(0.30, 0.05, 0.20), _blt)
	MeshBuilder.box(torso, Vector3(0, -0.12, 0.11), Vector3(0.06, 0.06, 0.02), _kny)
	# Váy/quần phần dưới hông
	MeshBuilder.box(torso, Vector3(0, -0.17, 0), Vector3(0.32, 0.04, 0.22), _sk3)
	chestplate_pivot = MeshBuilder.pivot(body, Vector3(0, 0.08, 0))
	chestplate_pivot.name = "ChestplatePivot"
	back_gear_pivot = MeshBuilder.pivot(body, Vector3(0, 0.10, -0.13))
	back_gear_pivot.name = "BackGearPivot"

	# ── Cổ ────────────────────────────────────────────────────────────────
	neck = MeshBuilder.pivot(torso, Vector3(0, 0.19, 0))
	neck.name = "NeckJoint"
	MeshBuilder.box(neck, Vector3(0, 0.0, 0), Vector3(0.14, 0.08, 0.14), _sk)

	# ── Đầu ───────────────────────────────────────────────────────────────
	head = MeshBuilder.pivot(neck, Vector3(0, 0.10, 0))
	head.name = "Head"
	MeshBuilder.box(head, Vector3(0, 0.00, 0), Vector3(0.32, 0.24, 0.26), _sk)
	MeshBuilder.box(head, Vector3(0, -0.12, 0), Vector3(0.14, 0.05, 0.26), _sk)
	helmet_pivot = MeshBuilder.pivot(head, Vector3(0, 0.02, 0))
	helmet_pivot.name = "HelmetPivot"
	hair_pivot = MeshBuilder.pivot(head, Vector3.ZERO)
	hair_pivot.name = "HairPivot"
	tails_pivot = MeshBuilder.pivot(head, Vector3.ZERO)
	tails_pivot.name = "TailsPivot"

# ── Khuôn mặt ────────────────────────────────────────────────────────────────
func _build_face() -> void:
	var ez: float = 0.13
	MeshBuilder.box(head, Vector3(-0.08, 0.03, ez),      Vector3(0.10, 0.10, 0.02), _ew)
	MeshBuilder.box(head, Vector3(-0.08, 0.02, ez+0.01), Vector3(0.08, 0.08, 0.01), _ei)
	MeshBuilder.box(head, Vector3(-0.08, 0.01, ez+0.02), Vector3(0.05, 0.07, 0.01), _ep)
	MeshBuilder.box(head, Vector3(-0.06, 0.04, ez+0.03), Vector3(0.02, 0.02, 0.01), _eg)
	MeshBuilder.box(head, Vector3(-0.08, 0.09, ez),      Vector3(0.07, 0.02, 0.01), _hd)
	MeshBuilder.box(head, Vector3( 0.08, 0.03, ez),      Vector3(0.10, 0.10, 0.02), _ew)
	MeshBuilder.box(head, Vector3( 0.08, 0.02, ez+0.01), Vector3(0.08, 0.08, 0.01), _ei)
	MeshBuilder.box(head, Vector3( 0.08, 0.01, ez+0.02), Vector3(0.05, 0.07, 0.01), _ep)
	MeshBuilder.box(head, Vector3( 0.06, 0.04, ez+0.03), Vector3(0.02, 0.02, 0.01), _eg)
	MeshBuilder.box(head, Vector3( 0.08, 0.09, ez),      Vector3(0.07, 0.02, 0.01), _hd)
	MeshBuilder.box(head, Vector3(-0.11, -0.03, ez+0.01), Vector3(0.05, 0.03, 0.01), _bsh)
	MeshBuilder.box(head, Vector3( 0.11, -0.03, ez+0.01), Vector3(0.05, 0.03, 0.01), _bsh)
	MeshBuilder.box(head, Vector3( 0.00, -0.04, ez+0.02), Vector3(0.02, 0.02, 0.01), _sk)
	MeshBuilder.box(head, Vector3( 0.00, -0.08, ez+0.02), Vector3(0.05, 0.015, 0.01), _mth)

# ── Tóc ──────────────────────────────────────────────────────────────────────
func _build_hair() -> void:
	MeshBuilder.box(hair_pivot, Vector3(0,  0.13, -0.01), Vector3(0.34, 0.06, 0.26), _hr)
	MeshBuilder.box(hair_pivot, Vector3(0,  0.10,  0.00), Vector3(0.30, 0.06, 0.20), _hr)
	MeshBuilder.box(hair_pivot, Vector3(-0.16, 0.10, 0.02), Vector3(0.05, 0.09, 0.22), _hr)
	MeshBuilder.box(hair_pivot, Vector3( 0.16, 0.10, 0.02), Vector3(0.05, 0.09, 0.22), _hr)
	MeshBuilder.box(hair_pivot, Vector3(-0.10, 0.12, 0.13), Vector3(0.14, 0.04, 0.03), _hr)
	MeshBuilder.box(hair_pivot, Vector3(0, 0.08, -0.13),   Vector3(0.30, 0.10, 0.03), _hd)
	MeshBuilder.box(hair_pivot, Vector3(0, -0.06, -0.12),  Vector3(0.26, 0.14, 0.04), _hr)

# ── Chân ─────────────────────────────────────────────────────────────────────
func _build_legs() -> void:
	# Hip joint — đùi, gối, cẳng chân, cổ chân, bàn chân
	leg_l = MeshBuilder.pivot(pelvis, Vector3(-0.09, -0.02, 0))
	leg_l.name = "LegL"  # khớp hông trái / khối đùi
	_build_leg(leg_l, true)
	leg_r = MeshBuilder.pivot(pelvis, Vector3( 0.09, -0.02, 0))
	leg_r.name = "LegR"
	_build_leg(leg_r, false)

func _build_leg(hip: Node3D, left: bool) -> void:
	# Khối đùi
	MeshBuilder.box(hip, Vector3(0, -0.17, 0), Vector3(0.15, 0.32, 0.15), _sk2)
	var knee := MeshBuilder.pivot(hip, Vector3(0, -0.34, 0))
	knee.name = "KneeL" if left else "KneeR"
	if left: knee_l = knee
	else:    knee_r = knee
	# Núm gối
	MeshBuilder.box(knee, Vector3(0, 0.0, 0), Vector3(0.16, 0.05, 0.16), _sk3)

	# Cẳng chân (giữa gối và cổ chân)
	var shin := MeshBuilder.pivot(knee, Vector3(0, -0.05, 0))
	shin.name = "ShinL" if left else "ShinR"
	if left: shin_l = shin
	else:    shin_r = shin
	MeshBuilder.box(shin, Vector3(0, -0.11, 0), Vector3(0.13, 0.26, 0.13), _sk3)

	# Khớp cổ chân
	var ankle := MeshBuilder.pivot(shin, Vector3(0, -0.26, 0))
	ankle.name = "AnkleL" if left else "AnkleR"
	if left: ankle_l = ankle
	else:    ankle_r = ankle

	# Bàn chân
	var foot := MeshBuilder.pivot(ankle, Vector3(0, -0.02, 0.02))
	foot.name = "FootL" if left else "FootR"
	if left: foot_l = foot
	else:    foot_r = foot
	MeshBuilder.box(foot, Vector3(0, -0.02, 0.02), Vector3(0.15, 0.07, 0.24), _sho)
	MeshBuilder.box(foot, Vector3(0, -0.05, 0.02), Vector3(0.16, 0.02, 0.26), _sol)
	MeshBuilder.box(foot, Vector3(0, -0.00, 0.10), Vector3(0.13, 0.03, 0.03), _rb)

	var boot := MeshBuilder.pivot(foot, Vector3(0, 0.0, 0.02))
	boot.name = "BootLPivot" if left else "BootRPivot"
	if left: boot_l_pivot = boot
	else:    boot_r_pivot = boot
	var armor := MeshBuilder.pivot(hip, Vector3(0, -0.14, 0))
	armor.name = "LegArmorLPivot" if left else "LegArmorRPivot"
	armor.scale = Vector3(0.65, 0.65, 0.65)
	if left: leg_armor_l_pivot = armor
	else:    leg_armor_r_pivot = armor

# ── Tay ──────────────────────────────────────────────────────────────────────
func _build_arms() -> void:
	# Khớp vai
	arm_l = MeshBuilder.pivot(body, Vector3(-0.21, 0.15, 0))
	arm_l.name = "ArmL"
	_build_arm(arm_l, true)
	arm_r = MeshBuilder.pivot(body, Vector3( 0.21, 0.15, 0))
	arm_r.name = "ArmR"
	_build_arm(arm_r, false)

func _build_arm(shoulder: Node3D, left: bool) -> void:
	# Bắp tay trên
	MeshBuilder.box(shoulder, Vector3(0, -0.12, 0), Vector3(0.12, 0.24, 0.12), _sh)
	# Khớp khuỷu tay
	var elbow := MeshBuilder.pivot(shoulder, Vector3(0, -0.26, 0))
	elbow.name = "ElbowL" if left else "ElbowR"
	if left: elbow_l = elbow
	else:    elbow_r = elbow
	# Cẳng tay
	MeshBuilder.box(elbow, Vector3(0, -0.11, 0), Vector3(0.11, 0.22, 0.11), _sh)
	# Bàn tay
	MeshBuilder.box(elbow, Vector3(0, -0.22, 0), Vector3(0.10, 0.09, 0.10), _sk)

	if left:
		gauntlet_l_pivot = MeshBuilder.pivot(elbow, Vector3(0, -0.18, 0))
		gauntlet_l_pivot.name = "GauntletLPivot"
		gauntlet_l_pivot.scale = Vector3(0.5, 0.5, 0.5)
	else:
		gauntlet_r_pivot = MeshBuilder.pivot(elbow, Vector3(0, -0.18, 0))
		gauntlet_r_pivot.name = "GauntletRPivot"
		gauntlet_r_pivot.scale = Vector3(0.5, 0.5, 0.5)
		ring_pivot = MeshBuilder.pivot(elbow, Vector3(0, -0.25, 0))
		ring_pivot.name = "RingPivot"
		ring_pivot.scale = Vector3(0.45, 0.45, 0.45)
		weapon_pivot = MeshBuilder.pivot(elbow, Vector3(0, -0.24, 0.02))
		weapon_pivot.name = "WeaponPivot"
		weapon_pivot.rotation_degrees = Vector3(90, 0, 0)
		weapon_pivot.scale = Vector3(1.5, 1.5, 1.5)

# ── Ba lô ────────────────────────────────────────────────────────────────────
func _build_backpack() -> void:
	backpack = MeshBuilder.pivot(body, Vector3(0, 0.10, -0.13))
	backpack.name = "Backpack"
	MeshBuilder.box(backpack, Vector3(0,  0.00, 0.00), Vector3(0.20, 0.20, 0.10), _sk2)
	MeshBuilder.box(backpack, Vector3(0, -0.06, -0.03), Vector3(0.22, 0.14, 0.06), _sk3)
	MeshBuilder.box(backpack, Vector3(0,  0.06, -0.03), Vector3(0.04, 0.04, 0.03), _rb)