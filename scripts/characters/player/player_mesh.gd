## PlayerMesh – Voxel Chibi Anime Style
## Tỷ lệ chibi: đầu to (~45% chiều cao), thân ngắn, chân ngắn
## Màu pastel hồng, đồng phục học sinh sailor
class_name PlayerMesh

var rig:     Node3D
var head:    Node3D
var body:    Node3D
var backpack: Node3D
var arm_l:   Node3D
var arm_r:   Node3D
var leg_l:   Node3D
var leg_r:   Node3D

# ── Materials ─────────────────────────────────────────────────────────────────
## Skin
var _sk:  StandardMaterial3D  # da mặt / tay / chân
## Hair
var _hr:  StandardMaterial3D  # tóc chính (hồng đào sáng)
var _hd:  StandardMaterial3D  # tóc tối (highlight bóng)
## Eyes
var _ew:  StandardMaterial3D  # tròng trắng
var _ei:  StandardMaterial3D  # tròng màu (hồng fuchsia)
var _ep:  StandardMaterial3D  # con ngươi đen
var _eg:  StandardMaterial3D  # điểm sáng mắt
## Face blush
var _bsh: StandardMaterial3D  # má hồng
## Uniform – áo trắng sailor
var _wh:  StandardMaterial3D  # trắng áo
var _col: StandardMaterial3D  # cổ áo xanh navy
var _rb:  StandardMaterial3D  # nơ đỏ / ribbon
## Uniform – váy hồng
var _sk2: StandardMaterial3D  # váy hồng pastel
var _sk3: StandardMaterial3D  # viền váy hồng tối
## Socks & shoes
var _sox: StandardMaterial3D  # tất trắng
var _sho: StandardMaterial3D  # giày nâu
## Hair tie / ribbon
var _htr: StandardMaterial3D  # buộc tóc đỏ/hồng tươi

# ── Build ─────────────────────────────────────────────────────────────────────
func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = MeshBuilder.pivot(root, Vector3(0, 0.02, 0))
	rig.name = "PlayerRig"
	_build_legs()
	_build_body()
	_build_arms()
	_build_head()
	_build_hair()
	_build_face()
	_build_twin_tails()
	_build_backpack()

# ── Materials ─────────────────────────────────────────────────────────────────
func _make_materials() -> void:
	# Skin – tông đào nhạt ấm
	_sk  = MeshBuilder.emit_mat(Color(0.99, 0.84, 0.72), Color(0,0,0), 0)
	# Hair – hồng đào sáng
	_hr  = MeshBuilder.emit_mat(Color(0.98, 0.62, 0.65), Color(0,0,0), 0)
	_hd  = MeshBuilder.emit_mat(Color(0.88, 0.45, 0.52), Color(0,0,0), 0)
	# Eyes
	_ew  = MeshBuilder.emit_mat(Color(1.00, 1.00, 1.00), Color(0,0,0), 0)
	_ei  = MeshBuilder.emit_mat(Color(0.95, 0.40, 0.65), Color(0,0,0), 0)   # hồng fuchsia
	_ep  = MeshBuilder.emit_mat(Color(0.10, 0.06, 0.12), Color(0,0,0), 0)   # đen
	_eg  = MeshBuilder.emit_mat(Color(1.00, 1.00, 1.00), Color(1,1,1), 1.5) # điểm sáng
	# Blush
	_bsh = MeshBuilder.emit_mat(Color(0.98, 0.70, 0.72), Color(0,0,0), 0)
	# Uniform
	_wh  = MeshBuilder.emit_mat(Color(0.97, 0.96, 0.98), Color(0,0,0), 0)   # áo trắng
	_col = MeshBuilder.emit_mat(Color(0.35, 0.42, 0.72), Color(0,0,0), 0)   # cổ navy
	_rb  = MeshBuilder.emit_mat(Color(0.92, 0.22, 0.35), Color(0,0,0), 0)   # nơ đỏ
	# Skirt
	_sk2 = MeshBuilder.emit_mat(Color(0.98, 0.72, 0.82), Color(0,0,0), 0)   # váy hồng
	_sk3 = MeshBuilder.emit_mat(Color(0.88, 0.55, 0.68), Color(0,0,0), 0)   # viền váy
	# Socks & shoes
	_sox = MeshBuilder.emit_mat(Color(0.96, 0.94, 0.96), Color(0,0,0), 0)   # tất trắng
	_sho = MeshBuilder.emit_mat(Color(0.30, 0.20, 0.16), Color(0,0,0), 0)   # giày nâu tối
	# Hair tie
	_htr = MeshBuilder.emit_mat(Color(0.96, 0.28, 0.42), Color(0,0,0), 0)

# ── Head (chibi: rộng, cao, hơi vuông góc mềm) ───────────────────────────────
func _build_head() -> void:
	# Pivot đầu ở cao (thân thấp, đầu chiếm nửa chiều cao)
	head = MeshBuilder.pivot(rig, Vector3(0, 0.72, 0))

	# Khối đầu chính – hình khối voxel to rộng
	MeshBuilder.box(head, Vector3(0, 0.00,  0.00), Vector3(0.46, 0.42, 0.40), _sk)
	# Má phồng hai bên (chibi)
	MeshBuilder.box(head, Vector3(-0.22, -0.06, 0.08), Vector3(0.06, 0.10, 0.16), _sk)
	MeshBuilder.box(head, Vector3( 0.22, -0.06, 0.08), Vector3(0.06, 0.10, 0.16), _sk)
	# Cằm nhỏ nhô ra
	MeshBuilder.box(head, Vector3(0, -0.18, 0.06), Vector3(0.24, 0.06, 0.22), _sk)

# ── Face ──────────────────────────────────────────────────────────────────────
func _build_face() -> void:
	var ez: float = 0.21  # mặt trước

	# ── Mắt trái ──
	# Tròng trắng (to)
	MeshBuilder.box(head, Vector3(-0.11, 0.03, ez),      Vector3(0.13, 0.14, 0.02), _ew)
	# Tròng màu hồng
	MeshBuilder.box(head, Vector3(-0.11, 0.02, ez+0.01), Vector3(0.11, 0.12, 0.01), _ei)
	# Con ngươi đen
	MeshBuilder.box(head, Vector3(-0.11, 0.01, ez+0.02), Vector3(0.07, 0.10, 0.01), _ep)
	# Điểm sáng
	MeshBuilder.box(head, Vector3(-0.08, 0.05, ez+0.03), Vector3(0.03, 0.03, 0.01), _eg)
	# Lông mày (nâu nhỏ)
	MeshBuilder.box(head, Vector3(-0.11, 0.10, ez-0.01), Vector3(0.08, 0.02, 0.02), _hd)

	# ── Mắt phải ──
	MeshBuilder.box(head, Vector3( 0.11, 0.03, ez),      Vector3(0.13, 0.14, 0.02), _ew)
	MeshBuilder.box(head, Vector3( 0.11, 0.02, ez+0.01), Vector3(0.11, 0.12, 0.01), _ei)
	MeshBuilder.box(head, Vector3( 0.11, 0.01, ez+0.02), Vector3(0.07, 0.10, 0.01), _ep)
	MeshBuilder.box(head, Vector3( 0.08, 0.05, ez+0.03), Vector3(0.03, 0.03, 0.01), _eg)
	MeshBuilder.box(head, Vector3( 0.11, 0.10, ez-0.01), Vector3(0.08, 0.02, 0.02), _hd)

	# ── Má hồng (chibi blush) ──
	MeshBuilder.box(head, Vector3(-0.16, -0.04, ez+0.01), Vector3(0.06, 0.04, 0.01), _bsh)
	MeshBuilder.box(head, Vector3( 0.16, -0.04, ez+0.01), Vector3(0.06, 0.04, 0.01), _bsh)

	# ── Miệng nhỏ (hình chữ U) ──
	MeshBuilder.box(head, Vector3(-0.02, -0.10, ez+0.01), Vector3(0.02, 0.02, 0.01), _hd)
	MeshBuilder.box(head, Vector3( 0.02, -0.10, ez+0.01), Vector3(0.02, 0.02, 0.01), _hd)
	MeshBuilder.box(head, Vector3( 0.00, -0.11, ez+0.01), Vector3(0.04, 0.02, 0.01), _hd)

# ── Hair – phần chính phủ đỉnh đầu ──────────────────────────────────────────
func _build_hair() -> void:
	# Tầng tóc trên đỉnh (to + rộng voxel-style)
	MeshBuilder.box(head, Vector3(0,  0.22, -0.02), Vector3(0.48, 0.08, 0.36), _hr)
	MeshBuilder.box(head, Vector3(0,  0.28,  0.00), Vector3(0.44, 0.06, 0.32), _hr)
	MeshBuilder.box(head, Vector3(0,  0.34,  0.02), Vector3(0.38, 0.06, 0.26), _hr)
	MeshBuilder.box(head, Vector3(0,  0.38,  0.04), Vector3(0.28, 0.06, 0.18), _hr)
	# Tóc phủ hai bên đầu
	MeshBuilder.box(head, Vector3(-0.24, 0.18, 0.02), Vector3(0.06, 0.10, 0.30), _hr)
	MeshBuilder.box(head, Vector3( 0.24, 0.18, 0.02), Vector3(0.06, 0.10, 0.30), _hr)
	# Tóc phủ trán (mái) – lệch nhẹ sang trái
	MeshBuilder.box(head, Vector3(-0.06, 0.16, 0.20), Vector3(0.20, 0.08, 0.06), _hr)
	MeshBuilder.box(head, Vector3(-0.10, 0.10, 0.22), Vector3(0.14, 0.06, 0.04), _hr)
	MeshBuilder.box(head, Vector3( 0.08, 0.16, 0.20), Vector3(0.10, 0.06, 0.06), _hd)
	# Tóc phủ sau đầu
	MeshBuilder.box(head, Vector3(0, 0.04, -0.21),  Vector3(0.40, 0.28, 0.04), _hr)
	MeshBuilder.box(head, Vector3(0, -0.06, -0.21), Vector3(0.36, 0.18, 0.04), _hr)

# ── Twin Tails – hai đuôi tóc buộc cao ───────────────────────────────────────
func _build_twin_tails() -> void:
	# Buộc tóc trái (gần đỉnh)
	var tie_l := MeshBuilder.pivot(head, Vector3(-0.22, 0.28, 0.02))
	MeshBuilder.box(tie_l, Vector3(0, 0, 0), Vector3(0.07, 0.07, 0.07), _htr)

	# Đuôi tóc trái – thả xuống theo bậc voxel
	MeshBuilder.box(tie_l, Vector3(0, -0.08,  0.00), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_l, Vector3(0, -0.18,  0.02), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_l, Vector3(0, -0.28,  0.00), Vector3(0.10, 0.10, 0.10), _hr)
	MeshBuilder.box(tie_l, Vector3(0, -0.38, -0.02), Vector3(0.10, 0.10, 0.10), _hd)
	MeshBuilder.box(tie_l, Vector3(0, -0.48, -0.02), Vector3(0.08, 0.10, 0.08), _hd)
	MeshBuilder.box(tie_l, Vector3(0, -0.56, -0.04), Vector3(0.06, 0.08, 0.06), _hr)

	# Buộc tóc phải
	var tie_r := MeshBuilder.pivot(head, Vector3( 0.22, 0.28, 0.02))
	MeshBuilder.box(tie_r, Vector3(0, 0, 0), Vector3(0.07, 0.07, 0.07), _htr)

	# Đuôi tóc phải
	MeshBuilder.box(tie_r, Vector3(0, -0.08,  0.00), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_r, Vector3(0, -0.18,  0.02), Vector3(0.12, 0.10, 0.12), _hr)
	MeshBuilder.box(tie_r, Vector3(0, -0.28,  0.00), Vector3(0.10, 0.10, 0.10), _hr)
	MeshBuilder.box(tie_r, Vector3(0, -0.38, -0.02), Vector3(0.10, 0.10, 0.10), _hd)
	MeshBuilder.box(tie_r, Vector3(0, -0.48, -0.02), Vector3(0.08, 0.10, 0.08), _hd)
	MeshBuilder.box(tie_r, Vector3(0, -0.56, -0.04), Vector3(0.06, 0.08, 0.06), _hr)

# ── Body – áo sailor ngắn chibi ───────────────────────────────────────────────
func _build_body() -> void:
	body = MeshBuilder.pivot(rig, Vector3(0, 0.45, 0))

	# Cổ da
	MeshBuilder.box(body, Vector3(0,  0.20, 0.00), Vector3(0.14, 0.08, 0.14), _sk)

	# Thân áo trắng (ngắn chibi)
	MeshBuilder.box(body, Vector3(0,  0.08,  0.00), Vector3(0.32, 0.20, 0.22), _wh)
	MeshBuilder.box(body, Vector3(0, -0.06,  0.00), Vector3(0.30, 0.14, 0.20), _wh)

	# Cổ áo sailor (V-shape navy)
	MeshBuilder.box(body, Vector3( 0.00, 0.14,  0.10), Vector3(0.24, 0.06, 0.04), _col)
	MeshBuilder.box(body, Vector3(-0.08, 0.10,  0.08), Vector3(0.06, 0.10, 0.04), _col)
	MeshBuilder.box(body, Vector3( 0.08, 0.10,  0.08), Vector3(0.06, 0.10, 0.04), _col)
	# Viền cổ dưới (stripe trắng)
	MeshBuilder.box(body, Vector3( 0.00, 0.18,  0.09), Vector3(0.22, 0.02, 0.03), _wh)

	# Nơ đỏ chính giữa ngực
	MeshBuilder.box(body, Vector3( 0.00, 0.06,  0.11), Vector3(0.08, 0.06, 0.02), _rb)  # nút nơ
	MeshBuilder.box(body, Vector3(-0.06, 0.06,  0.11), Vector3(0.06, 0.04, 0.02), _rb)  # cánh trái
	MeshBuilder.box(body, Vector3( 0.06, 0.06,  0.11), Vector3(0.06, 0.04, 0.02), _rb)  # cánh phải
	MeshBuilder.box(body, Vector3( 0.00, 0.02,  0.11), Vector3(0.02, 0.04, 0.02), _rb)  # đuôi nơ

	# Váy hồng (flare nhẹ)
	MeshBuilder.box(body, Vector3(0, -0.14, 0.00), Vector3(0.34, 0.10, 0.24), _sk2)
	MeshBuilder.box(body, Vector3(0, -0.20, 0.00), Vector3(0.36, 0.06, 0.26), _sk2)
	MeshBuilder.box(body, Vector3(0, -0.26, 0.00), Vector3(0.38, 0.06, 0.28), _sk2)
	# Viền váy tối
	MeshBuilder.box(body, Vector3(0, -0.30, 0.00), Vector3(0.38, 0.02, 0.28), _sk3)

# ── Arms – tay nhỏ chibi ──────────────────────────────────────────────────────
func _build_arms() -> void:
	arm_l = MeshBuilder.pivot(rig, Vector3(-0.18, 0.60, 0))
	arm_r = MeshBuilder.pivot(rig, Vector3( 0.18, 0.60, 0))

	for arm in [arm_l, arm_r]:
		# Tay trên (áo trắng)
		MeshBuilder.box(arm, Vector3(0,  0.00, 0), Vector3(0.12, 0.16, 0.12), _wh)
		MeshBuilder.box(arm, Vector3(0, -0.12, 0), Vector3(0.12, 0.10, 0.12), _wh)
		# Cổ tay da
		MeshBuilder.box(arm, Vector3(0, -0.20, 0), Vector3(0.10, 0.06, 0.10), _sk)
		# Bàn tay
		MeshBuilder.box(arm, Vector3(0, -0.26, 0), Vector3(0.10, 0.06, 0.08), _sk)

# ── Legs – chân ngắn chibi + tất trắng + giày ────────────────────────────────
func _build_legs() -> void:
	leg_l = MeshBuilder.pivot(rig, Vector3(-0.09, 0.16, 0))
	leg_r = MeshBuilder.pivot(rig, Vector3( 0.09, 0.16, 0))

	for leg in [leg_l, leg_r]:
		# Đùi da
		MeshBuilder.box(leg, Vector3(0,  0.04, 0), Vector3(0.13, 0.12, 0.13), _sk)
		# Tất trắng (phần ống chân)
		MeshBuilder.box(leg, Vector3(0, -0.06, 0), Vector3(0.12, 0.14, 0.12), _sox)
		MeshBuilder.box(leg, Vector3(0, -0.16, 0), Vector3(0.11, 0.08, 0.11), _sox)
		# Giày nâu tối
		MeshBuilder.box(leg, Vector3(0, -0.22,  0.02), Vector3(0.13, 0.06, 0.16), _sho)
		MeshBuilder.box(leg, Vector3(0, -0.24,  0.06), Vector3(0.11, 0.04, 0.12), _sho)

# ── Backpack (nhỏ gọn, hình túi học sinh) ────────────────────────────────────
func _build_backpack() -> void:
	backpack = MeshBuilder.pivot(rig, Vector3(0, 0.54, -0.02))
	# Thân túi hồng nhạt
	MeshBuilder.box(backpack, Vector3(0, 0.00, -0.13), Vector3(0.20, 0.22, 0.12), _sk2)
	MeshBuilder.box(backpack, Vector3(0, -0.06, -0.18), Vector3(0.22, 0.16, 0.06), _sk2)
	# Ngăn túi
	MeshBuilder.box(backpack, Vector3(0, -0.02, -0.20), Vector3(0.14, 0.10, 0.04), _sk3)
	# Khoá kim loại nhỏ
	MeshBuilder.box(backpack, Vector3(0,  0.06, -0.20), Vector3(0.04, 0.04, 0.03), _rb)
	# Dây đeo
	MeshBuilder.box(backpack, Vector3(-0.09, 0.06, -0.08), Vector3(0.03, 0.18, 0.03), _sk3)
	MeshBuilder.box(backpack, Vector3( 0.09, 0.06, -0.08), Vector3(0.03, 0.18, 0.03), _sk3)
