## CoraMesh – Voxel Chibi Anime Style (skin Cora mặc định)
## Tỷ lệ chibi: đầu to (~45% chiều cao), thân ngắn, chân ngắn
## Màu pastel hồng, đồng phục học sinh sailor
extends PlayerMesh
class_name CoraMesh

# ── Materials ─────────────────────────────────────────────────────────────────
var _sk:  StandardMaterial3D  # da mặt / tay / chân
var _hr:  StandardMaterial3D  # tóc chính
var _hd:  StandardMaterial3D  # tóc tối
var _ew:  StandardMaterial3D  # tròng trắng
var _ei:  StandardMaterial3D  # tròng màu
var _ep:  StandardMaterial3D  # con ngươi
var _eg:  StandardMaterial3D  # điểm sáng mắt
var _bsh: StandardMaterial3D  # má hồng
var _wh:  StandardMaterial3D  # áo trắng
var _col: StandardMaterial3D  # cổ áo navy
var _rb:  StandardMaterial3D  # nơ đỏ
var _sk2: StandardMaterial3D  # váy hồng
var _sk3: StandardMaterial3D  # viền váy tối
var _sox: StandardMaterial3D  # tất
var _sho: StandardMaterial3D  # giày
var _htr: StandardMaterial3D  # buộc tóc

# ── Build ─────────────────────────────────────────────────────────────────────
func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = make_rig(root, 0.08)
	_build_legs()
	_build_body()
	_build_arms()
	_build_head()
	_build_hair()
	_build_face()
	_build_twin_tails()
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
	_wh  = MeshBuilder.emit_mat(_c("shirt",      Color(0.97, 0.96, 0.98)), Color(0,0,0), 0)
	_col = MeshBuilder.emit_mat(_c("collar",     Color(0.35, 0.42, 0.72)), Color(0,0,0), 0)
	_rb  = MeshBuilder.emit_mat(_c("ribbon",     Color(0.92, 0.22, 0.35)), Color(0,0,0), 0)
	_sk2 = MeshBuilder.emit_mat(_c("skirt",      Color(0.98, 0.72, 0.82)), Color(0,0,0), 0)
	_sk3 = MeshBuilder.emit_mat(_c("skirt_dark", Color(0.88, 0.55, 0.68)), Color(0,0,0), 0)
	_sox = MeshBuilder.emit_mat(_c("socks",      Color(0.96, 0.94, 0.96)), Color(0,0,0), 0)
	_sho = MeshBuilder.emit_mat(_c("shoes",      Color(0.30, 0.20, 0.16)), Color(0,0,0), 0)
	_htr = MeshBuilder.emit_mat(_c("hair_tie",   Color(0.96, 0.28, 0.42)), Color(0,0,0), 0)

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
	_wh .albedo_color = _c("shirt",      _wh .albedo_color)
	_col.albedo_color = _c("collar",     _col.albedo_color)
	_rb .albedo_color = _c("ribbon",     _rb .albedo_color)
	_sk2.albedo_color = _c("skirt",      _sk2.albedo_color)
	_sk3.albedo_color = _c("skirt_dark", _sk3.albedo_color)
	_sox.albedo_color = _c("socks",      _sox.albedo_color)
	_sho.albedo_color = _c("shoes",      _sho.albedo_color)
	_htr.albedo_color = _c("hair_tie",   _htr.albedo_color)

# ── Head ──────────────────────────────────────────────────────────────────────
func _build_head() -> void:
	head = MeshBuilder.pivot(rig, Vector3(0, 0.72, 0))
	MeshBuilder.box(head, Vector3(0, 0.00,  0.00), Vector3(0.46, 0.42, 0.40), _sk)
	MeshBuilder.box(head, Vector3(-0.22, -0.06, 0.08), Vector3(0.06, 0.10, 0.16), _sk)
	MeshBuilder.box(head, Vector3( 0.22, -0.06, 0.08), Vector3(0.06, 0.10, 0.16), _sk)
	MeshBuilder.box(head, Vector3(0, -0.18, 0.06), Vector3(0.24, 0.06, 0.22), _sk)
	helmet_pivot = MeshBuilder.pivot(head, Vector3(0, 0.02, 0))
	helmet_pivot.name = "HelmetPivot"
	chestplate_pivot = MeshBuilder.pivot(body, Vector3(0, 0.05, 0))
	chestplate_pivot.name = "ChestplatePivot"

# ── Face ──────────────────────────────────────────────────────────────────────
func _build_face() -> void:
	var ez: float = 0.21
	MeshBuilder.box(head, Vector3(-0.11, 0.03, ez),      Vector3(0.13, 0.14, 0.02), _ew)
	MeshBuilder.box(head, Vector3(-0.11, 0.02, ez+0.01), Vector3(0.11, 0.12, 0.01), _ei)
	MeshBuilder.box(head, Vector3(-0.11, 0.01, ez+0.02), Vector3(0.07, 0.10, 0.01), _ep)
	MeshBuilder.box(head, Vector3(-0.08, 0.05, ez+0.03), Vector3(0.03, 0.03, 0.01), _eg)
	MeshBuilder.box(head, Vector3(-0.11, 0.10, ez-0.01), Vector3(0.08, 0.02, 0.02), _hd)
	MeshBuilder.box(head, Vector3( 0.11, 0.03, ez),      Vector3(0.13, 0.14, 0.02), _ew)
	MeshBuilder.box(head, Vector3( 0.11, 0.02, ez+0.01), Vector3(0.11, 0.12, 0.01), _ei)
	MeshBuilder.box(head, Vector3( 0.11, 0.01, ez+0.02), Vector3(0.07, 0.10, 0.01), _ep)
	MeshBuilder.box(head, Vector3( 0.08, 0.05, ez+0.03), Vector3(0.03, 0.03, 0.01), _eg)
	MeshBuilder.box(head, Vector3( 0.11, 0.10, ez-0.01), Vector3(0.08, 0.02, 0.02), _hd)
	MeshBuilder.box(head, Vector3(-0.16, -0.04, ez+0.01), Vector3(0.06, 0.04, 0.01), _bsh)
	MeshBuilder.box(head, Vector3( 0.16, -0.04, ez+0.01), Vector3(0.06, 0.04, 0.01), _bsh)
	MeshBuilder.box(head, Vector3(-0.02, -0.10, ez+0.01), Vector3(0.02, 0.02, 0.01), _hd)
	MeshBuilder.box(head, Vector3( 0.02, -0.10, ez+0.01), Vector3(0.02, 0.02, 0.01), _hd)
	MeshBuilder.box(head, Vector3( 0.00, -0.11, ez+0.01), Vector3(0.04, 0.02, 0.01), _hd)

# ── Hair ──────────────────────────────────────────────────────────────────────
func _build_hair() -> void:
	hair_pivot = MeshBuilder.pivot(head, Vector3.ZERO)
	hair_pivot.name = "HairPivot"
	MeshBuilder.box(hair_pivot, Vector3(0,  0.22, -0.02), Vector3(0.48, 0.08, 0.36), _hr)
	MeshBuilder.box(hair_pivot, Vector3(0,  0.28,  0.00), Vector3(0.44, 0.06, 0.32), _hr)
	MeshBuilder.box(hair_pivot, Vector3(0,  0.34,  0.02), Vector3(0.38, 0.06, 0.26), _hr)
	MeshBuilder.box(hair_pivot, Vector3(0,  0.38,  0.04), Vector3(0.28, 0.06, 0.18), _hr)
	MeshBuilder.box(hair_pivot, Vector3(-0.24, 0.18, 0.02), Vector3(0.06, 0.10, 0.30), _hr)
	MeshBuilder.box(hair_pivot, Vector3( 0.24, 0.18, 0.02), Vector3(0.06, 0.10, 0.30), _hr)
	MeshBuilder.box(hair_pivot, Vector3(-0.06, 0.16, 0.20), Vector3(0.20, 0.08, 0.06), _hr)
	MeshBuilder.box(hair_pivot, Vector3(-0.10, 0.10, 0.22), Vector3(0.14, 0.06, 0.04), _hr)
	MeshBuilder.box(hair_pivot, Vector3( 0.08, 0.16, 0.20), Vector3(0.10, 0.06, 0.06), _hd)
	MeshBuilder.box(hair_pivot, Vector3(0, 0.04, -0.21),  Vector3(0.40, 0.28, 0.04), _hr)
	MeshBuilder.box(hair_pivot, Vector3(0, -0.06, -0.21), Vector3(0.36, 0.18, 0.04), _hr)

# ── Twin Tails ────────────────────────────────────────────────────────────────
func _build_twin_tails() -> void:
	tails_pivot = MeshBuilder.pivot(head, Vector3.ZERO)
	tails_pivot.name = "TailsPivot"
	var tie_l := MeshBuilder.pivot(tails_pivot, Vector3(-0.22, 0.28, 0.02))
	MeshBuilder.box(tie_l, Vector3(0, 0, 0), Vector3(0.07, 0.07, 0.07), _htr)
	MeshBuilder.box(tie_l, Vector3(0, -0.08,  0.00), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_l, Vector3(0, -0.18,  0.02), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_l, Vector3(0, -0.28,  0.00), Vector3(0.10, 0.10, 0.10), _hr)
	MeshBuilder.box(tie_l, Vector3(0, -0.38, -0.02), Vector3(0.10, 0.10, 0.10), _hd)
	MeshBuilder.box(tie_l, Vector3(0, -0.48, -0.02), Vector3(0.08, 0.10, 0.08), _hd)
	MeshBuilder.box(tie_l, Vector3(0, -0.56, -0.04), Vector3(0.06, 0.08, 0.06), _hr)
	var tie_r := MeshBuilder.pivot(tails_pivot, Vector3( 0.22, 0.28, 0.02))
	MeshBuilder.box(tie_r, Vector3(0, 0, 0), Vector3(0.07, 0.07, 0.07), _htr)
	MeshBuilder.box(tie_r, Vector3(0, -0.08,  0.00), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_r, Vector3(0, -0.18,  0.02), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_r, Vector3(0, -0.28,  0.00), Vector3(0.10, 0.10, 0.10), _hr)
	MeshBuilder.box(tie_r, Vector3(0, -0.38, -0.02), Vector3(0.10, 0.10, 0.10), _hd)
	MeshBuilder.box(tie_r, Vector3(0, -0.48, -0.02), Vector3(0.08, 0.10, 0.08), _hd)
	MeshBuilder.box(tie_r, Vector3(0, -0.56, -0.04), Vector3(0.06, 0.08, 0.06), _hr)

# ── Body ──────────────────────────────────────────────────────────────────────
func _build_body() -> void:
	body = MeshBuilder.pivot(rig, Vector3(0, 0.45, 0))
	MeshBuilder.box(body, Vector3(0, 0.20, 0.00), Vector3(0.14, 0.08, 0.14), _sk)
	torso = MeshBuilder.pivot(body, Vector3.ZERO)
	torso.name = "Torso"
	MeshBuilder.box(torso, Vector3(0,  0.08, 0.00), Vector3(0.32, 0.20, 0.22), _wh)
	MeshBuilder.box(torso, Vector3(0, -0.06, 0.00), Vector3(0.30, 0.14, 0.20), _wh)
	MeshBuilder.box(torso, Vector3( 0.00, 0.14, 0.10), Vector3(0.24, 0.06, 0.04), _col)
	MeshBuilder.box(torso, Vector3(-0.08, 0.10, 0.08), Vector3(0.06, 0.10, 0.04), _col)
	MeshBuilder.box(torso, Vector3( 0.08, 0.10, 0.08), Vector3(0.06, 0.10, 0.04), _col)
	MeshBuilder.box(torso, Vector3( 0.00, 0.18, 0.09), Vector3(0.22, 0.02, 0.03), _wh)
	MeshBuilder.box(torso, Vector3( 0.00, 0.06, 0.11), Vector3(0.08, 0.06, 0.02), _rb)
	MeshBuilder.box(torso, Vector3(-0.06, 0.06, 0.11), Vector3(0.06, 0.04, 0.02), _rb)
	MeshBuilder.box(torso, Vector3( 0.06, 0.06, 0.11), Vector3(0.06, 0.04, 0.02), _rb)
	MeshBuilder.box(torso, Vector3( 0.00, 0.02, 0.11), Vector3(0.02, 0.04, 0.02), _rb)
	MeshBuilder.box(torso, Vector3(0, -0.14, 0.00), Vector3(0.34, 0.10, 0.24), _sk2)
	MeshBuilder.box(torso, Vector3(0, -0.20, 0.00), Vector3(0.36, 0.06, 0.26), _sk2)
	MeshBuilder.box(torso, Vector3(0, -0.26, 0.00), Vector3(0.38, 0.06, 0.28), _sk2)
	MeshBuilder.box(torso, Vector3(0, -0.30, 0.00), Vector3(0.38, 0.02, 0.28), _sk3)

# ── Arms ──────────────────────────────────────────────────────────────────────
func _build_arms() -> void:
	arm_l = MeshBuilder.pivot(rig, Vector3(-0.18, 0.60, 0))
	arm_r = MeshBuilder.pivot(rig, Vector3( 0.18, 0.60, 0))
	for arm in [arm_l, arm_r]:
		MeshBuilder.box(arm, Vector3(0,  0.00, 0), Vector3(0.12, 0.16, 0.12), _wh)
		MeshBuilder.box(arm, Vector3(0, -0.12, 0), Vector3(0.12, 0.10, 0.12), _wh)
		MeshBuilder.box(arm, Vector3(0, -0.20, 0), Vector3(0.10, 0.06, 0.10), _sk)
		MeshBuilder.box(arm, Vector3(0, -0.26, 0), Vector3(0.10, 0.06, 0.08), _sk)
	weapon_pivot = MeshBuilder.pivot(arm_r, Vector3(0.0, -0.28, 0.0))
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.rotation_degrees = Vector3(90, 0, 0)
	weapon_pivot.scale = Vector3(1.8, 1.8, 1.8)
	gauntlet_l_pivot = MeshBuilder.pivot(arm_l, Vector3(0, -0.16, 0))
	gauntlet_l_pivot.name = "GauntletLPivot"
	gauntlet_l_pivot.scale = Vector3(0.5, 0.5, 0.5)
	gauntlet_r_pivot = MeshBuilder.pivot(arm_r, Vector3(0, -0.16, 0))
	gauntlet_r_pivot.name = "GauntletRPivot"
	gauntlet_r_pivot.scale = Vector3(0.5, 0.5, 0.5)
	ring_pivot = MeshBuilder.pivot(arm_r, Vector3(0, -0.25, 0))
	ring_pivot.name = "RingPivot"
	ring_pivot.scale = Vector3(0.45, 0.45, 0.45)

# ── Legs ──────────────────────────────────────────────────────────────────────
func _build_legs() -> void:
	leg_l = MeshBuilder.pivot(rig, Vector3(-0.09, 0.16, 0))
	leg_r = MeshBuilder.pivot(rig, Vector3( 0.09, 0.16, 0))
	for leg in [leg_l, leg_r]:
		MeshBuilder.box(leg, Vector3(0,  0.04, 0), Vector3(0.13, 0.12, 0.13), _sk)
		MeshBuilder.box(leg, Vector3(0, -0.06, 0), Vector3(0.12, 0.14, 0.12), _sox)
		MeshBuilder.box(leg, Vector3(0, -0.16, 0), Vector3(0.11, 0.08, 0.11), _sox)
		MeshBuilder.box(leg, Vector3(0, -0.22,  0.02), Vector3(0.13, 0.06, 0.16), _sho)
		MeshBuilder.box(leg, Vector3(0, -0.24,  0.06), Vector3(0.11, 0.04, 0.12), _sho)
	boot_l_pivot = MeshBuilder.pivot(leg_l, Vector3(0, -0.22, 0))
	boot_l_pivot.name = "BootLPivot"
	boot_r_pivot = MeshBuilder.pivot(leg_r, Vector3(0, -0.22, 0))
	boot_r_pivot.name = "BootRPivot"
	leg_armor_l_pivot = MeshBuilder.pivot(leg_l, Vector3(0, -0.06, 0))
	leg_armor_l_pivot.name = "LegArmorLPivot"
	leg_armor_l_pivot.scale = Vector3(0.7, 0.7, 0.7)
	leg_armor_r_pivot = MeshBuilder.pivot(leg_r, Vector3(0, -0.06, 0))
	leg_armor_r_pivot.name = "LegArmorRPivot"
	leg_armor_r_pivot.scale = Vector3(0.7, 0.7, 0.7)

# ── Backpack ──────────────────────────────────────────────────────────────────
func _build_backpack() -> void:
	backpack = MeshBuilder.pivot(rig, Vector3(0, 0.54, -0.02))
	MeshBuilder.box(backpack, Vector3(0,  0.00, -0.13), Vector3(0.20, 0.22, 0.12), _sk2)
	MeshBuilder.box(backpack, Vector3(0, -0.06, -0.18), Vector3(0.22, 0.16, 0.06), _sk2)
	MeshBuilder.box(backpack, Vector3(0, -0.02, -0.20), Vector3(0.14, 0.10, 0.04), _sk3)
	MeshBuilder.box(backpack, Vector3(0,  0.06, -0.20), Vector3(0.04, 0.04, 0.03), _rb)
	MeshBuilder.box(backpack, Vector3(-0.09, 0.06, -0.08), Vector3(0.03, 0.18, 0.03), _sk3)
	MeshBuilder.box(backpack, Vector3( 0.09, 0.06, -0.08), Vector3(0.03, 0.18, 0.03), _sk3)
	back_gear_pivot = MeshBuilder.pivot(rig, Vector3(0, 0.53, -0.18))
	back_gear_pivot.name = "BackGearPivot"
	back_gear_pivot.scale = Vector3(0.85, 0.85, 0.85)
