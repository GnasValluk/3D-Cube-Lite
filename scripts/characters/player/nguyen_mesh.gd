## NguyenMesh – Bộ đội Việt Nam voxel chibi
## Đồng phục rằn ri, mũ tai bèo xanh lá, giày da nâu đất
## Tỷ lệ chibi giống Cora nhưng thân rộng hơn (vóc nam), không váy/đuôi tóc
extends PlayerMesh
class_name NguyenMesh

# ── Materials ──────────────────────────────────────────────────────────────────
var _sk:   StandardMaterial3D  # da
var _hr:   StandardMaterial3D  # tóc đen
var _hd:   StandardMaterial3D  # tóc tối / lông mày
var _ew:   StandardMaterial3D  # tròng trắng
var _ei:   StandardMaterial3D  # mắt nâu
var _ep:   StandardMaterial3D  # con ngươi
var _eg:   StandardMaterial3D  # điểm sáng
var _bsh:  StandardMaterial3D  # da má
var _cm:   StandardMaterial3D  # camo sáng (áo chính)
var _cmd:  StandardMaterial3D  # camo tối (chi tiết)
var _cmx:  StandardMaterial3D  # camo rất tối (bóng)
var _rd:   StandardMaterial3D  # đỏ phù hiệu / cờ
var _belt: StandardMaterial3D  # thắt lưng xanh tối
var _sho:  StandardMaterial3D  # giày da nâu đất
var _shod: StandardMaterial3D  # đế giày tối
var _hat:  StandardMaterial3D  # mũ tai bèo xanh lá
var _hatd: StandardMaterial3D  # viền mũ tối
var _star: StandardMaterial3D  # ngôi sao vàng
var _skin_dark: StandardMaterial3D  # da tối (cổ)
var _gold: StandardMaterial3D  # khóa vàng / cúc đồng
var _steel: StandardMaterial3D  # thép súng / nút kim loại

# ── Build ──────────────────────────────────────────────────────────────────────
func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = make_rig(root, 0.135)
	_build_legs()
	_build_body()
	_build_arms()
	_build_head()
	_build_face()
	_build_hat()
	_build_backpack()

func _make_materials() -> void:
	_sk   = MeshBuilder.emit_mat(_c("skin",      Color(0.86, 0.68, 0.50)), Color(0,0,0), 0)
	_skin_dark = MeshBuilder.emit_mat(Color(0.74, 0.58, 0.42),             Color(0,0,0), 0)
	_hr   = MeshBuilder.emit_mat(_c("hair",      Color(0.14, 0.12, 0.10)), Color(0,0,0), 0)
	_hd   = MeshBuilder.emit_mat(_c("hair_dark", Color(0.08, 0.07, 0.06)), Color(0,0,0), 0)
	_ew   = MeshBuilder.emit_mat(_c("eye_white", Color(0.98, 0.96, 0.94)), Color(0,0,0), 0)
	_ei   = MeshBuilder.emit_mat(_c("eye_iris",  Color(0.32, 0.20, 0.10)), Color(0,0,0), 0)
	_ep   = MeshBuilder.emit_mat(_c("eye_pupil", Color(0.08, 0.05, 0.04)), Color(0,0,0), 0)
	_eg   = MeshBuilder.emit_mat(_c("eye_glint", Color(1.00, 1.00, 1.00)), Color(1,1,1), 1.2)
	_bsh  = MeshBuilder.emit_mat(_c("blush",     Color(0.80, 0.62, 0.48)), Color(0,0,0), 0)
	_cm   = MeshBuilder.emit_mat(_c("shirt",     Color(0.28, 0.38, 0.20)), Color(0,0,0), 0)
	_cmd  = MeshBuilder.emit_mat(_c("collar",    Color(0.20, 0.28, 0.14)), Color(0,0,0), 0)
	_cmx  = MeshBuilder.emit_mat(Color(0.14, 0.20, 0.09),                  Color(0,0,0), 0)
	_rd   = MeshBuilder.emit_mat(_c("ribbon",    Color(0.82, 0.10, 0.10)), Color(0,0,0), 0)
	_belt = MeshBuilder.emit_mat(_c("hair_tie",  Color(0.22, 0.30, 0.16)), Color(0,0,0), 0)
	_sho  = MeshBuilder.emit_mat(_c("shoes",     Color(0.42, 0.28, 0.16)), Color(0,0,0), 0)
	_shod = MeshBuilder.emit_mat(Color(0.28, 0.18, 0.10),                  Color(0,0,0), 0)
	_hat  = MeshBuilder.emit_mat(Color(0.22, 0.36, 0.16),                  Color(0,0,0), 0)
	_hatd = MeshBuilder.emit_mat(Color(0.16, 0.26, 0.11),                  Color(0,0,0), 0)
	_star = MeshBuilder.emit_mat(Color(0.96, 0.80, 0.10),                  Color(0,0,0), 0)
	_gold = MeshBuilder.emit_mat(Color(0.85, 0.70, 0.20),                  Color(0,0,0), 0)
	_steel = MeshBuilder.emit_mat(Color(0.45, 0.48, 0.52),                 Color(0,0,0), 0)

func apply_palette(palette_new: Dictionary) -> void:
	_palette = palette_new
	_sk .albedo_color = _c("skin",      _sk .albedo_color)
	_hr .albedo_color = _c("hair",      _hr .albedo_color)
	_hd .albedo_color = _c("hair_dark", _hd .albedo_color)
	_ew .albedo_color = _c("eye_white", _ew .albedo_color)
	_ei .albedo_color = _c("eye_iris",  _ei .albedo_color)
	_ep .albedo_color = _c("eye_pupil", _ep .albedo_color)
	_eg .albedo_color = _c("eye_glint", _eg .albedo_color)
	_bsh.albedo_color = _c("blush",     _bsh.albedo_color)
	_cm .albedo_color = _c("shirt",     _cm .albedo_color)
	_cmd.albedo_color = _c("collar",    _cmd.albedo_color)
	_rd .albedo_color = _c("ribbon",    _rd .albedo_color)
	_belt.albedo_color = _c("hair_tie", _belt.albedo_color)
	_sho.albedo_color = _c("shoes",     _sho.albedo_color)

# ── Head – đầu chibi vuông, mặt nam ──────────────────────────────────────────
func _build_head() -> void:
	head = MeshBuilder.pivot(rig, Vector3(0, 0.74, 0))
	# Khối đầu chính
	MeshBuilder.box(head, Vector3(0,  0.00,  0.00), Vector3(0.44, 0.40, 0.38), _sk)
	# Má nhẹ
	MeshBuilder.box(head, Vector3(-0.21, -0.05, 0.06), Vector3(0.06, 0.08, 0.14), _sk)
	MeshBuilder.box(head, Vector3( 0.21, -0.05, 0.06), Vector3(0.06, 0.08, 0.14), _sk)
	# Cằm vuông
	MeshBuilder.box(head, Vector3(0, -0.17, 0.04), Vector3(0.28, 0.06, 0.20), _sk)
	# Cổ
	MeshBuilder.box(head, Vector3(0, -0.28, 0.00), Vector3(0.16, 0.10, 0.16), _skin_dark)
	helmet_pivot = MeshBuilder.pivot(head, Vector3(0, 0.04, 0))
	helmet_pivot.name = "HelmetPivot"
	chestplate_pivot = MeshBuilder.pivot(body, Vector3(0, 0.05, 0))
	chestplate_pivot.name = "ChestplatePivot"

# ── Face – mắt nam, lông mày đậm, mũi nhỏ, miệng ────────────────────────────
func _build_face() -> void:
	var ez: float = 0.20
	hair_pivot = MeshBuilder.pivot(head, Vector3.ZERO)
	hair_pivot.name = "HairPivot"
	tails_pivot = MeshBuilder.pivot(head, Vector3.ZERO)
	tails_pivot.name = "TailsPivot"
	# Tóc ngắn (ẩn dưới mũ)
	MeshBuilder.box(hair_pivot, Vector3(0,  0.22, -0.02), Vector3(0.42, 0.06, 0.34), _hr)
	MeshBuilder.box(hair_pivot, Vector3(0,  0.18,  0.18), Vector3(0.38, 0.06, 0.06), _hr)
	MeshBuilder.box(hair_pivot, Vector3(-0.22, 0.14, 0.02), Vector3(0.05, 0.10, 0.28), _hr)
	MeshBuilder.box(hair_pivot, Vector3( 0.22, 0.14, 0.02), Vector3(0.05, 0.10, 0.28), _hr)
	# Lông mày đậm, rõ
	MeshBuilder.box(head, Vector3(-0.12, 0.10, ez+0.00), Vector3(0.10, 0.025, 0.02), _hd)
	MeshBuilder.box(head, Vector3( 0.12, 0.10, ez+0.00), Vector3(0.10, 0.025, 0.02), _hd)
	# Mắt trái
	MeshBuilder.box(head, Vector3(-0.12, 0.02, ez),      Vector3(0.12, 0.12, 0.02), _ew)
	MeshBuilder.box(head, Vector3(-0.12, 0.01, ez+0.01), Vector3(0.10, 0.10, 0.01), _ei)
	MeshBuilder.box(head, Vector3(-0.12, 0.00, ez+0.02), Vector3(0.07, 0.08, 0.01), _ep)
	MeshBuilder.box(head, Vector3(-0.09, 0.04, ez+0.03), Vector3(0.03, 0.03, 0.01), _eg)
	# Mắt phải
	MeshBuilder.box(head, Vector3( 0.12, 0.02, ez),      Vector3(0.12, 0.12, 0.02), _ew)
	MeshBuilder.box(head, Vector3( 0.12, 0.01, ez+0.01), Vector3(0.10, 0.10, 0.01), _ei)
	MeshBuilder.box(head, Vector3( 0.12, 0.00, ez+0.02), Vector3(0.07, 0.08, 0.01), _ep)
	MeshBuilder.box(head, Vector3( 0.09, 0.04, ez+0.03), Vector3(0.03, 0.03, 0.01), _eg)
	# Má (tông đất nhẹ)
	MeshBuilder.box(head, Vector3(-0.17, -0.03, ez+0.01), Vector3(0.05, 0.03, 0.01), _bsh)
	MeshBuilder.box(head, Vector3( 0.17, -0.03, ez+0.01), Vector3(0.05, 0.03, 0.01), _bsh)
	# Mũi nhỏ
	MeshBuilder.box(head, Vector3(0, -0.04, ez+0.01), Vector3(0.04, 0.04, 0.02), _skin_dark)
	# Cánh mũi
	MeshBuilder.box(head, Vector3(-0.02, -0.05, ez+0.01), Vector3(0.015, 0.015, 0.02), _skin_dark)
	MeshBuilder.box(head, Vector3( 0.02, -0.05, ez+0.01), Vector3(0.015, 0.015, 0.02), _skin_dark)
	# Tai hai bên
	MeshBuilder.box(head, Vector3(-0.23, -0.03, 0.00), Vector3(0.04, 0.10, 0.10), _sk)
	MeshBuilder.box(head, Vector3( 0.23, -0.03, 0.00), Vector3(0.04, 0.10, 0.10), _sk)
	MeshBuilder.box(head, Vector3(-0.24, -0.02, 0.02), Vector3(0.02, 0.06, 0.04), _skin_dark)
	MeshBuilder.box(head, Vector3( 0.24, -0.02, 0.02), Vector3(0.02, 0.06, 0.04), _skin_dark)
	# Miệng mỏng (nét thẳng = biểu cảm nghiêm)
	MeshBuilder.box(head, Vector3(0, -0.11, ez+0.01), Vector3(0.08, 0.018, 0.01), _hd)
	# Quầng thâm nhẹ dưới mắt (nam trưởng thành)
	MeshBuilder.box(head, Vector3(-0.12, -0.04, ez+0.005), Vector3(0.11, 0.015, 0.01), _skin_dark)
	MeshBuilder.box(head, Vector3( 0.12, -0.04, ez+0.005), Vector3(0.11, 0.015, 0.01), _skin_dark)

# ── Mũ tai bèo Việt Nam ────────────────────────────────────────────────────────
## Hình nón dẹt voxel-style: đế rộng, đỉnh tròn, có gù + ngôi sao + viền
func _build_hat() -> void:
	# Thân mũ — 3 tầng voxel tạo dáng nón dẹt (đặt ngay trên đỉnh đầu)
	MeshBuilder.box(head, Vector3(0,  0.22,  0.00), Vector3(0.52, 0.06, 0.50), _hat)
	MeshBuilder.box(head, Vector3(0,  0.28,  0.00), Vector3(0.46, 0.06, 0.44), _hat)
	MeshBuilder.box(head, Vector3(0,  0.34,  0.00), Vector3(0.38, 0.06, 0.36), _hat)
	MeshBuilder.box(head, Vector3(0,  0.40, -0.01), Vector3(0.28, 0.06, 0.26), _hat)
	MeshBuilder.box(head, Vector3(0,  0.45, -0.01), Vector3(0.18, 0.05, 0.16), _hat)
	# Đỉnh mũ tròn
	MeshBuilder.box(head, Vector3(0,  0.49,  0.00), Vector3(0.10, 0.05, 0.10), _hat)
	# Viền đế mũ tối
	MeshBuilder.box(head, Vector3(0,  0.20,  0.00), Vector3(0.54, 0.03, 0.52), _hatd)
	# Viền đế trong sáng hơn (2 lớp)
	MeshBuilder.box(head, Vector3(0,  0.23,  0.00), Vector3(0.50, 0.02, 0.48), _hat)
	# Gù mũ phía trước (dấu hiệu QĐND)
	MeshBuilder.box(head, Vector3(0,  0.36,  0.20), Vector3(0.20, 0.08, 0.04), _hatd)
	# Ngôi sao vàng trên gù — 4 cánh ngang dọc + chéo
	MeshBuilder.box(head, Vector3(0,  0.40,  0.22), Vector3(0.07, 0.06, 0.02), _star)
	MeshBuilder.box(head, Vector3(0,  0.40,  0.22), Vector3(0.03, 0.10, 0.02), _star)
	MeshBuilder.box(head, Vector3(-0.03, 0.38, 0.22), Vector3(0.02, 0.06, 0.02), _star)
	MeshBuilder.box(head, Vector3( 0.03, 0.38, 0.22), Vector3(0.02, 0.06, 0.02), _star)
	MeshBuilder.box(head, Vector3(-0.015, 0.42, 0.22), Vector3(0.015, 0.06, 0.02), _star)
	MeshBuilder.box(head, Vector3( 0.015, 0.42, 0.22), Vector3(0.015, 0.06, 0.02), _star)
	# Vành mũ nhỏ sau đầu
	MeshBuilder.box(head, Vector3(0,  0.20, -0.25), Vector3(0.36, 0.03, 0.06), _hatd)
	# Dây cằm chéo từ vành mũ xuống 2 bên
	MeshBuilder.box(head, Vector3(-0.26, 0.10, -0.06), Vector3(0.03, 0.16, 0.03), _hatd)
	MeshBuilder.box(head, Vector3( 0.26, 0.10, -0.06), Vector3(0.03, 0.16, 0.03), _hatd)

# ── Body – đồng phục rằn ri, thân rộng nam ────────────────────────────────────
func _build_body() -> void:
	body = MeshBuilder.pivot(rig, Vector3(0, 0.45, 0))
	# Cổ da
	MeshBuilder.box(body, Vector3(0,  0.22, 0.00), Vector3(0.16, 0.06, 0.16), _skin_dark)
	torso = MeshBuilder.pivot(body, Vector3.ZERO)
	torso.name = "Torso"
	# Thân áo camo chính (rộng hơn Cora)
	MeshBuilder.box(torso, Vector3(0,  0.10, 0.00), Vector3(0.36, 0.22, 0.24), _cm)
	MeshBuilder.box(torso, Vector3(0, -0.06, 0.00), Vector3(0.34, 0.18, 0.22), _cm)
	# Chi tiết rằn ri voxel (đốm tối ngẫu nhiên)
	MeshBuilder.box(torso, Vector3(-0.12,  0.14, 0.12), Vector3(0.06, 0.06, 0.02), _cmd)
	MeshBuilder.box(torso, Vector3( 0.10,  0.08, 0.12), Vector3(0.08, 0.05, 0.02), _cmx)
	MeshBuilder.box(torso, Vector3(-0.08, -0.02, 0.12), Vector3(0.05, 0.08, 0.02), _cmd)
	MeshBuilder.box(torso, Vector3( 0.14, -0.08, 0.12), Vector3(0.06, 0.06, 0.02), _cmx)
	MeshBuilder.box(torso, Vector3(-0.16, -0.06, 0.12), Vector3(0.06, 0.05, 0.02), _cmd)
	# Cổ áo đứng (kiểu bộ đội)
	MeshBuilder.box(torso, Vector3(0,  0.20, 0.10), Vector3(0.22, 0.04, 0.06), _cmd)
	MeshBuilder.box(torso, Vector3(-0.10, 0.16, 0.10), Vector3(0.04, 0.10, 0.05), _cmd)
	MeshBuilder.box(torso, Vector3( 0.10, 0.16, 0.10), Vector3(0.04, 0.10, 0.05), _cmd)
	# Quân hàm trên vai
	MeshBuilder.box(torso, Vector3(-0.17, 0.18, 0.02), Vector3(0.06, 0.05, 0.10), _cmd)
	MeshBuilder.box(torso, Vector3( 0.17, 0.18, 0.02), Vector3(0.06, 0.05, 0.10), _cmd)
	MeshBuilder.box(torso, Vector3(-0.17, 0.18, 0.04), Vector3(0.03, 0.03, 0.03), _gold)
	MeshBuilder.box(torso, Vector3( 0.17, 0.18, 0.04), Vector3(0.03, 0.03, 0.03), _gold)
	# Túi ngực trái phải
	MeshBuilder.box(torso, Vector3(-0.12, 0.04, 0.125), Vector3(0.10, 0.07, 0.015), _cmd)
	MeshBuilder.box(torso, Vector3( 0.12, 0.04, 0.125), Vector3(0.10, 0.07, 0.015), _cmd)
	MeshBuilder.box(torso, Vector3(-0.12, 0.04, 0.135), Vector3(0.04, 0.02, 0.01), _cmx)
	MeshBuilder.box(torso, Vector3( 0.12, 0.04, 0.135), Vector3(0.04, 0.02, 0.01), _cmx)
	# Cúc đồng dọc ngực
	MeshBuilder.box(torso, Vector3(0, 0.13, 0.125), Vector3(0.025, 0.025, 0.01), _gold)
	MeshBuilder.box(torso, Vector3(0, 0.05, 0.125), Vector3(0.025, 0.025, 0.01), _gold)
	# Phù hiệu cờ đỏ bên ngực trái
	MeshBuilder.box(torso, Vector3(-0.14, 0.08, 0.12), Vector3(0.08, 0.05, 0.02), _rd)
	MeshBuilder.box(torso, Vector3(-0.14, 0.08, 0.13), Vector3(0.04, 0.03, 0.01), _star)
	# Thắt lưng
	MeshBuilder.box(torso, Vector3(0, -0.14, 0.00), Vector3(0.36, 0.04, 0.24), _belt)
	MeshBuilder.box(torso, Vector3(0, -0.14, 0.13), Vector3(0.06, 0.06, 0.02), _shod)  # khóa
	# Dây đai chéo vai phải
	MeshBuilder.box(torso, Vector3(0.10, 0.02, 0.10), Vector3(0.03, 0.30, 0.03), _belt)
	# Áo phần dưới (tucked in)
	MeshBuilder.box(torso, Vector3(0, -0.22, 0.00), Vector3(0.34, 0.10, 0.22), _cm)
	MeshBuilder.box(torso, Vector3(0, -0.28, 0.00), Vector3(0.34, 0.06, 0.22), _cmd)

# ── Arms – tay áo camo dài, bàn tay da ────────────────────────────────────────
func _build_arms() -> void:
	arm_l = MeshBuilder.pivot(rig, Vector3(-0.20, 0.60, 0))
	arm_r = MeshBuilder.pivot(rig, Vector3( 0.20, 0.60, 0))
	for arm in [arm_l, arm_r]:
		# Tay trên (áo camo)
		MeshBuilder.box(arm, Vector3(0,  0.00, 0), Vector3(0.14, 0.18, 0.14), _cm)
		MeshBuilder.box(arm, Vector3(0, -0.14, 0), Vector3(0.13, 0.12, 0.13), _cm)
		# Đốm rằn ri tay
		MeshBuilder.box(arm, Vector3(0.04, -0.06, 0.07), Vector3(0.04, 0.06, 0.02), _cmd)
		MeshBuilder.box(arm, Vector3(-0.04, -0.10, 0.07), Vector3(0.05, 0.05, 0.02), _cmx)
		# Còng tay áo (viền cổ tay)
		MeshBuilder.box(arm, Vector3(0, -0.19, 0), Vector3(0.13, 0.03, 0.13), _cmd)
		MeshBuilder.box(arm, Vector3(0, -0.21, 0.08), Vector3(0.03, 0.03, 0.015), _gold)
		# Cổ tay + bàn tay da
		MeshBuilder.box(arm, Vector3(0, -0.24, 0), Vector3(0.12, 0.06, 0.12), _sk)
		MeshBuilder.box(arm, Vector3(0, -0.30, 0.01), Vector3(0.12, 0.07, 0.10), _sk)
	# Weapon pivot
	weapon_pivot = MeshBuilder.pivot(arm_r, Vector3(0.0, -0.30, 0.0))
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.rotation_degrees = Vector3(90, 0, 0)
	weapon_pivot.scale = Vector3(1.8, 1.8, 1.8)
	gauntlet_l_pivot = MeshBuilder.pivot(arm_l, Vector3(0, -0.18, 0))
	gauntlet_l_pivot.name = "GauntletLPivot"
	gauntlet_l_pivot.scale = Vector3(0.5, 0.5, 0.5)
	gauntlet_r_pivot = MeshBuilder.pivot(arm_r, Vector3(0, -0.18, 0))
	gauntlet_r_pivot.name = "GauntletRPivot"
	gauntlet_r_pivot.scale = Vector3(0.5, 0.5, 0.5)
	ring_pivot = MeshBuilder.pivot(arm_r, Vector3(0, -0.27, 0))
	ring_pivot.name = "RingPivot"
	ring_pivot.scale = Vector3(0.45, 0.45, 0.45)

# ── Legs – quần camo, giày da bộ đội ──────────────────────────────────────────
func _build_legs() -> void:
	leg_l = MeshBuilder.pivot(rig, Vector3(-0.10, 0.16, 0))
	leg_r = MeshBuilder.pivot(rig, Vector3( 0.10, 0.16, 0))
	for leg in [leg_l, leg_r]:
		# Đùi quần camo
		MeshBuilder.box(leg, Vector3(0,  0.04, 0), Vector3(0.15, 0.14, 0.15), _cm)
		# Đốm rằn ri đùi
		MeshBuilder.box(leg, Vector3(0.05, 0.06, 0.08), Vector3(0.04, 0.06, 0.02), _cmd)
		MeshBuilder.box(leg, Vector3(-0.05, 0.00, 0.08), Vector3(0.05, 0.05, 0.02), _cmx)
		# Ống quần
		MeshBuilder.box(leg, Vector3(0, -0.08, 0), Vector3(0.14, 0.16, 0.14), _cm)
		MeshBuilder.box(leg, Vector3(0, -0.18, 0), Vector3(0.13, 0.08, 0.13), _cmd)
		MeshBuilder.box(leg, Vector3(0, -0.20, 0), Vector3(0.13, 0.02, 0.13), _cmd)
		MeshBuilder.box(leg, Vector3(0.05, -0.12, 0.08), Vector3(0.03, 0.10, 0.02), _cmd)
		MeshBuilder.box(leg, Vector3(-0.05, -0.06, 0.08), Vector3(0.03, 0.06, 0.02), _cmx)
		# Giày da bộ đội (cao cổ)
		MeshBuilder.box(leg, Vector3(0, -0.24, 0.00), Vector3(0.14, 0.08, 0.14), _sho)
		MeshBuilder.box(leg, Vector3(0, -0.28, 0.03), Vector3(0.14, 0.04, 0.16), _sho)
		MeshBuilder.box(leg, Vector3(0, -0.30, 0.06), Vector3(0.12, 0.03, 0.13), _shod)  # đế
		MeshBuilder.box(leg, Vector3(0, -0.26, 0.00), Vector3(0.15, 0.02, 0.15), _shod)
		# Khóa giày kim loại
		MeshBuilder.box(leg, Vector3(0, -0.25, 0.08), Vector3(0.05, 0.03, 0.02), _gold)
		# Dây buộc giày (nhỏ)
		MeshBuilder.box(leg, Vector3(0, -0.22, 0.08), Vector3(0.10, 0.02, 0.02), _shod)
		MeshBuilder.box(leg, Vector3(0, -0.23, 0.08), Vector3(0.08, 0.02, 0.02), _shod)
		MeshBuilder.box(leg, Vector3(-0.03, -0.225, 0.08), Vector3(0.02, 0.03, 0.02), _gold)
		MeshBuilder.box(leg, Vector3( 0.03, -0.225, 0.08), Vector3(0.02, 0.03, 0.02), _gold)
	boot_l_pivot = MeshBuilder.pivot(leg_l, Vector3(0, -0.24, 0))
	boot_l_pivot.name = "BootLPivot"
	boot_r_pivot = MeshBuilder.pivot(leg_r, Vector3(0, -0.24, 0))
	boot_r_pivot.name = "BootRPivot"
	leg_armor_l_pivot = MeshBuilder.pivot(leg_l, Vector3(0, -0.06, 0))
	leg_armor_l_pivot.name = "LegArmorLPivot"
	leg_armor_l_pivot.scale = Vector3(0.7, 0.7, 0.7)
	leg_armor_r_pivot = MeshBuilder.pivot(leg_r, Vector3(0, -0.06, 0))
	leg_armor_r_pivot.name = "LegArmorRPivot"
	leg_armor_r_pivot.scale = Vector3(0.7, 0.7, 0.7)

# ── Backpack – ba lô bộ đội (xanh camo, vuông) ───────────────────────────────
func _build_backpack() -> void:
	backpack = MeshBuilder.pivot(rig, Vector3(0, 0.52, -0.02))
	# Thân ba lô vuông xanh camo
	MeshBuilder.box(backpack, Vector3(0,  0.02, -0.14), Vector3(0.24, 0.26, 0.14), _cm)
	MeshBuilder.box(backpack, Vector3(0, -0.06, -0.20), Vector3(0.26, 0.18, 0.06), _cmd)
	# Đốm rằn ri ba lô
	MeshBuilder.box(backpack, Vector3(-0.07, 0.06, -0.16), Vector3(0.05, 0.06, 0.02), _cmd)
	MeshBuilder.box(backpack, Vector3( 0.08, -0.02, -0.16), Vector3(0.06, 0.05, 0.02), _cmx)
	# Nắp ba lô
	MeshBuilder.box(backpack, Vector3(0,  0.12, -0.13), Vector3(0.24, 0.05, 0.12), _cmd)
	MeshBuilder.box(backpack, Vector3(0,  0.14, -0.13), Vector3(0.24, 0.02, 0.10), _cmx)
	# Dây đai ba lô
	MeshBuilder.box(backpack, Vector3(-0.11, 0.06, -0.09), Vector3(0.04, 0.22, 0.04), _belt)
	MeshBuilder.box(backpack, Vector3( 0.11, 0.06, -0.09), Vector3(0.04, 0.22, 0.04), _belt)
	# Khóa kim loại
	MeshBuilder.box(backpack, Vector3(0,  0.00, -0.22), Vector3(0.06, 0.04, 0.03), _shod)
	MeshBuilder.box(backpack, Vector3(0,  0.02, -0.23), Vector3(0.04, 0.02, 0.02), _gold)
	# Túi ngoài nhỏ
	MeshBuilder.box(backpack, Vector3(0, -0.08, -0.22), Vector3(0.16, 0.10, 0.04), _cmd)
	MeshBuilder.box(backpack, Vector3(0, -0.08, -0.24), Vector3(0.05, 0.03, 0.02), _gold)
	# Đinh tán 4 góc túi
	MeshBuilder.box(backpack, Vector3(-0.07, -0.11, -0.24), Vector3(0.02, 0.02, 0.015), _gold)
	MeshBuilder.box(backpack, Vector3( 0.07, -0.11, -0.24), Vector3(0.02, 0.02, 0.015), _gold)
	MeshBuilder.box(backpack, Vector3(-0.07, -0.05, -0.24), Vector3(0.02, 0.02, 0.015), _gold)
	MeshBuilder.box(backpack, Vector3( 0.07, -0.05, -0.24), Vector3(0.02, 0.02, 0.015), _gold)
	back_gear_pivot = MeshBuilder.pivot(rig, Vector3(0, 0.53, -0.20))
	back_gear_pivot.name = "BackGearPivot"
	back_gear_pivot.scale = Vector3(0.85, 0.85, 0.85)
