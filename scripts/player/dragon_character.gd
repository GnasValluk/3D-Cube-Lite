## dragon_character.gd – Rồng Neon (Nhân vật 2)
## Extends CharacterBase. Bốn chân, hai cánh lớn, đầu rồng, đuôi 8 đoạn.
## Màu sắc: tím-đỏ neon rực rỡ.

extends CharacterBase
class_name DragonCharacter

# ── Animation params ──────────────────────────────────────────────────────────
@export var walk_cycle_speed:   float = 7.0
@export var sprint_cycle_mult:  float = 1.8
@export var idle_breathe_spd:   float = 0.9
@export var tail_wave_speed:    float = 2.8
@export var wing_flap_idle_spd: float = 1.4
@export var wing_flap_run_spd:  float = 3.2

# ── Rig refs ──────────────────────────────────────────────────────────────────
var _neck:        Node3D   # pivot cổ
var _neck2:       Node3D   # pivot giữa cổ (cổ 2 đoạn)
var _head_pivot:  Node3D   # pivot đầu
var _jaw:         Node3D   # hàm dưới pivot
var _horn_l:      Node3D
var _horn_r:      Node3D
# Chân trước
var _fl_thigh:    Node3D   # front-left thigh
var _fl_shin:     Node3D
var _fl_foot:     Node3D
var _fr_thigh:    Node3D   # front-right
var _fr_shin:     Node3D
var _fr_foot:     Node3D
# Chân sau
var _bl_thigh:    Node3D   # back-left
var _bl_shin:     Node3D
var _bl_foot:     Node3D
var _br_thigh:    Node3D   # back-right
var _br_shin:     Node3D
var _br_foot:     Node3D
# Cánh
var _wing_l:      Node3D   # shoulder pivot left
var _wing_l2:     Node3D   # elbow pivot left
var _wing_l3:     Node3D   # wrist/tip pivot left
var _wing_r:      Node3D
var _wing_r2:     Node3D
var _wing_r3:     Node3D
# Đuôi (8 đoạn)
var _tail:        Array[Node3D] = []
# Vây lưng
var _spine_fins:  Array[Node3D] = []

# ── Materials ─────────────────────────────────────────────────────────────────
var _mat_body:   StandardMaterial3D  # tím đậm
var _mat_scale:  StandardMaterial3D  # tím sáng – vảy
var _mat_belly:  StandardMaterial3D  # hồng nhạt – bụng
var _mat_wing:   StandardMaterial3D  # đỏ-cam mỏng – màng cánh
var _mat_horn:   StandardMaterial3D  # trắng neon – sừng/răng
var _mat_eye:    StandardMaterial3D  # vàng cam rực – mắt
var _mat_claw:   StandardMaterial3D  # tím đen – móng vuốt
var _mat_glow:   StandardMaterial3D  # đỏ phát sáng – các chi tiết phát quang

# ─────────────────────────────────────────────────────────────────────────────
func _build_character() -> void:
	move_speed    = 4.8
	sprint_speed  = 8.5
	jump_height   = 1.8
	dash_speed    = 16.0
	attack_duration = 0.55

	# Collision – rồng to hơn raptor
	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.42; cs.height = 1.30
	col.shape = cs; col.position = Vector3(0, 0.65, 0)
	add_child(col)

	_rig = Node3D.new(); _rig.name = "DragonRig"
	_rig.position = Vector3(0, 0.10, 0)
	add_child(_rig)

	_build_dragon_materials()
	_build_dragon_torso()
	_build_dragon_neck_head()
	_build_dragon_front_legs()
	_build_dragon_back_legs()
	_build_dragon_wings()
	_build_dragon_tail()

# ── Materials ─────────────────────────────────────────────────────────────────
func _build_dragon_materials() -> void:
	_mat_body  = _emit_mat(Color(0.35,0.05,0.55), Color(0.55,0.05,0.90), 1.8)
	_mat_scale = _emit_mat(Color(0.55,0.10,0.80), Color(0.75,0.20,1.00), 2.4)
	_mat_belly = _emit_mat(Color(0.70,0.30,0.60), Color(0.90,0.40,0.80), 1.4)
	_mat_wing  = _emit_mat(Color(0.60,0.05,0.15), Color(0.95,0.10,0.30), 2.0)
	_mat_horn  = _emit_mat(Color(0.90,0.95,1.00), Color(0.70,0.90,1.00), 3.0)
	_mat_eye   = _emit_mat(Color(1.00,0.70,0.10), Color(1.00,0.60,0.00), 4.0)
	_mat_claw  = _emit_mat(Color(0.12,0.02,0.20), Color(0.30,0.05,0.50), 1.0)
	_mat_glow  = _emit_mat(Color(1.00,0.20,0.40), Color(1.00,0.10,0.30), 3.5)

# ── Torso ─────────────────────────────────────────────────────────────────────
func _build_dragon_torso() -> void:
	# Thân chính – hình oval dẹt, to và chắc
	_box(_rig, Vector3(0, 0.75,  0.00), Vector3(0.72, 0.42, 1.10), _mat_body)  # main barrel
	_box(_rig, Vector3(0, 0.68,  0.42), Vector3(0.60, 0.34, 0.32), _mat_body)  # chest bulge
	_box(_rig, Vector3(0, 0.70, -0.42), Vector3(0.58, 0.36, 0.36), _mat_body)  # hip block
	# Bụng – dải sáng hơn
	_box(_rig, Vector3(0, 0.52,  0.10), Vector3(0.44, 0.20, 0.80), _mat_belly)
	for i in range(5):  # vảy bụng
		_box(_rig, Vector3(0, 0.42, 0.38-float(i)*0.18),
			 Vector3(0.38, 0.06, 0.10), _mat_belly)
	# Vảy hông – hai bên
	for i in range(3):
		_box(_rig, Vector3(-0.38, 0.80+float(i)*0.08, -float(i)*0.10),
			 Vector3(0.08, 0.14, 0.18), _mat_scale)
		_box(_rig, Vector3( 0.38, 0.80+float(i)*0.08, -float(i)*0.10),
			 Vector3(0.08, 0.14, 0.18), _mat_scale)
	# Vây lưng (spine fins) – 7 chiếc tăng dần rồi giảm
	_spine_fins.clear()
	var fin_h: Array[float] = [0.10,0.16,0.22,0.28,0.24,0.18,0.12]
	var fin_z: Array[float] = [0.38,0.22,0.06,-0.10,-0.24,-0.36,-0.46]
	for i in range(7):
		var fp: Node3D = _pivot(_rig, Vector3(0, 0.96, fin_z[i]))
		_box(fp, Vector3(0, fin_h[i]*0.5, 0),
			 Vector3(0.06, fin_h[i], 0.07), _mat_glow)
		# Viền sáng mỗi vây
		_box(fp, Vector3(0, fin_h[i], 0),
			 Vector3(0.03, 0.04, 0.04), _mat_horn)
		_spine_fins.append(fp)
	# Vai – khối nối cổ và cánh
	_box(_rig, Vector3(-0.36, 0.90, 0.32), Vector3(0.20, 0.24, 0.28), _mat_scale)
	_box(_rig, Vector3( 0.36, 0.90, 0.32), Vector3(0.20, 0.24, 0.28), _mat_scale)

# ── Neck + Head ───────────────────────────────────────────────────────────────
func _build_dragon_neck_head() -> void:
	# Cổ – 2 đoạn cong
	_neck = _pivot(_rig, Vector3(0, 0.94, 0.48))
	_neck.rotation.x = -0.30
	_box(_neck, Vector3(0, 0.08, 0.06), Vector3(0.26, 0.24, 0.32), _mat_body)
	_box(_neck, Vector3(0, 0.16, 0.10), Vector3(0.22, 0.20, 0.24), _mat_body)
	# Vảy cổ
	for i in range(3):
		_box(_neck, Vector3(0, 0.22+float(i)*0.08, 0.04+float(i)*0.04),
			 Vector3(0.06, 0.10, 0.06), _mat_glow)

	_neck2 = _pivot(_neck, Vector3(0, 0.28, 0.20))
	_neck2.rotation.x = -0.20
	_box(_neck2, Vector3(0, 0.06, 0.08), Vector3(0.22, 0.20, 0.28), _mat_body)
	_box(_neck2, Vector3(0, 0.12, 0.14), Vector3(0.18, 0.16, 0.20), _mat_body)
	# Bướu hầu
	_box(_neck2, Vector3(0, -0.04, 0.14), Vector3(0.18, 0.10, 0.22), _mat_belly)

	# Head pivot
	_head_pivot = _pivot(_neck2, Vector3(0, 0.22, 0.22))
	# Hộp sọ chính
	_box(_head_pivot, Vector3(0,  0.06,  0.00), Vector3(0.36, 0.30, 0.44), _mat_body)
	# Mõm trên (snout)
	_box(_head_pivot, Vector3(0, -0.02,  0.22), Vector3(0.28, 0.18, 0.30), _mat_body)
	_box(_head_pivot, Vector3(0, -0.04,  0.38), Vector3(0.22, 0.14, 0.18), _mat_body)
	# Lỗ mũi phát sáng
	_box(_head_pivot, Vector3(-0.08, -0.02, 0.46), Vector3(0.06, 0.05, 0.04), _mat_glow)
	_box(_head_pivot, Vector3( 0.08, -0.02, 0.46), Vector3(0.06, 0.05, 0.04), _mat_glow)
	# Hàm dưới pivot
	_jaw = _pivot(_head_pivot, Vector3(0, -0.06, 0.10))
	_box(_jaw, Vector3(0, -0.04, 0.20), Vector3(0.24, 0.10, 0.34), _mat_body)
	_box(_jaw, Vector3(0, -0.06, 0.38), Vector3(0.18, 0.08, 0.18), _mat_body)
	# Răng – hàng trên
	for ti in range(5):
		_box(_head_pivot, Vector3(-0.08+float(ti)*0.04, -0.10, 0.30+float(ti)*0.01),
			 Vector3(0.03, 0.06, 0.03), _mat_horn)
	# Răng – hàm dưới
	for ti in range(4):
		_box(_jaw, Vector3(-0.06+float(ti)*0.04, 0.02, 0.22+float(ti)*0.01),
			 Vector3(0.03, 0.06, 0.03), _mat_horn)
	# Mắt lớn
	_sphere(_head_pivot, Vector3(-0.16, 0.08, 0.08), 0.065, _mat_eye)
	_sphere(_head_pivot, Vector3( 0.16, 0.08, 0.08), 0.065, _mat_eye)
	# Pupil dọc
	_box(_head_pivot, Vector3(-0.16, 0.08, 0.14), Vector3(0.025, 0.060, 0.020), _mat_claw)
	_box(_head_pivot, Vector3( 0.16, 0.08, 0.14), Vector3(0.025, 0.060, 0.020), _mat_claw)
	# Gờ mắt
	_box(_head_pivot, Vector3(-0.16, 0.14, 0.10), Vector3(0.10, 0.05, 0.06), _mat_scale)
	_box(_head_pivot, Vector3( 0.16, 0.14, 0.10), Vector3(0.10, 0.05, 0.06), _mat_scale)
	# Sừng – 2 chiếc cong ra sau
	_horn_l = _pivot(_head_pivot, Vector3(-0.14, 0.18, -0.06))
	_horn_l.rotation.z =  0.35; _horn_l.rotation.x = -0.40
	_box(_horn_l, Vector3(0, 0.10, 0), Vector3(0.06, 0.22, 0.05), _mat_horn)
	_box(_horn_l, Vector3(0, 0.26, -0.04), Vector3(0.04, 0.16, 0.04), _mat_horn)
	_box(_horn_l, Vector3(0, 0.38, -0.08), Vector3(0.03, 0.12, 0.03), _mat_horn)
	_horn_r = _pivot(_head_pivot, Vector3( 0.14, 0.18, -0.06))
	_horn_r.rotation.z = -0.35; _horn_r.rotation.x = -0.40
	_box(_horn_r, Vector3(0, 0.10, 0), Vector3(0.06, 0.22, 0.05), _mat_horn)
	_box(_horn_r, Vector3(0, 0.26, -0.04), Vector3(0.04, 0.16, 0.04), _mat_horn)
	_box(_horn_r, Vector3(0, 0.38, -0.08), Vector3(0.03, 0.12, 0.03), _mat_horn)
	# Vương miện gai nhỏ phía sau đầu
	for ci in range(4):
		_box(_head_pivot, Vector3(-0.06+float(ci)*0.04, 0.22, -0.14-float(ci)*0.02),
			 Vector3(0.04, 0.08+float(ci)*0.02, 0.04), _mat_scale)

# ── Front Legs ────────────────────────────────────────────────────────────────
func _build_dragon_front_legs() -> void:
	_fl_thigh = _pivot(_rig, Vector3(-0.32, 0.72, 0.36))
	var fl: Array[Node3D] = _build_dragon_leg(_fl_thigh, -1.0, true)
	_fl_shin = fl[0]; _fl_foot = fl[1]

	_fr_thigh = _pivot(_rig, Vector3( 0.32, 0.72, 0.36))
	var fr: Array[Node3D] = _build_dragon_leg(_fr_thigh,  1.0, true)
	_fr_shin = fr[0]; _fr_foot = fr[1]

# ── Back Legs ─────────────────────────────────────────────────────────────────
func _build_dragon_back_legs() -> void:
	_bl_thigh = _pivot(_rig, Vector3(-0.30, 0.70, -0.34))
	var bl: Array[Node3D] = _build_dragon_leg(_bl_thigh, -1.0, false)
	_bl_shin = bl[0]; _bl_foot = bl[1]

	_br_thigh = _pivot(_rig, Vector3( 0.30, 0.70, -0.34))
	var br: Array[Node3D] = _build_dragon_leg(_br_thigh,  1.0, false)
	_br_shin = br[0]; _br_foot = br[1]

func _build_dragon_leg(tp: Node3D, side: float, _is_front: bool) -> Array[Node3D]:
	# Đùi to – rồng có cơ bắp
	_box(tp, Vector3(0, -0.16, 0.02), Vector3(0.20, 0.34, 0.22), _mat_body)
	# Khuỷu nổi bật
	_sphere(tp, Vector3(0, -0.34, 0.06), 0.08, _mat_scale)
	# Cẳng chân
	var shin: Node3D = _pivot(tp, Vector3(0, -0.36, 0.06))
	_box(shin, Vector3(0, -0.14, -0.02), Vector3(0.14, 0.28, 0.16), _mat_body)
	# Mắt cá chân
	_sphere(shin, Vector3(0, -0.28, 0.00), 0.06, _mat_scale)
	# Bàn chân rộng
	var foot: Node3D = _pivot(shin, Vector3(0, -0.30, -0.02))
	_box(foot, Vector3(0, -0.04, 0.08), Vector3(0.18, 0.08, 0.28), _mat_body)
	# Lòng bàn chân
	_box(foot, Vector3(0, -0.08, 0.06), Vector3(0.14, 0.04, 0.22), _mat_belly)
	# 4 ngón với móng vuốt (rồng có 4 ngón)
	for tt in range(4):
		var tx: float = (-0.09+float(tt)*0.06) * side
		# Đốt ngón
		_box(foot, Vector3(tx, -0.04, 0.18+float(tt)*0.01), Vector3(0.04, 0.06, 0.14), _mat_body)
		_box(foot, Vector3(tx, -0.04, 0.30+float(tt)*0.01), Vector3(0.035,0.05, 0.10), _mat_body)
		# Móng vuốt – nhọn, phát sáng
		_box(foot, Vector3(tx, -0.07, 0.37+float(tt)*0.01), Vector3(0.028,0.04, 0.08), _mat_claw)
	# Cựa sau (dewclaw)
	_box(foot, Vector3(0.0, 0.02, -0.06), Vector3(0.06, 0.10, 0.05), _mat_claw)
	# Vảy chân – 3 miếng
	for sc in range(3):
		_box(tp, Vector3(side*0.10, -0.08-float(sc)*0.08, 0.08),
			 Vector3(0.06, 0.06, 0.10), _mat_scale)
	var r: Array[Node3D] = [shin, foot]; return r

# ── Wings ─────────────────────────────────────────────────────────────────────
# Cánh rồng hoành tráng: sải cánh ~3.6u mỗi bên, 5 ngón dài, màng 3 lớp,
# gân phát sáng, móng vuốt, patagium lớn nối thân.
func _build_dragon_wings() -> void:
	_build_single_wing(-1.0)   # trái
	_build_single_wing( 1.0)   # phải

func _build_single_wing(side: float) -> void:
	var sx := side  # -1 = trái, +1 = phải

	# ── Pivot vai – gốc của toàn cánh ────────────────────────────────────────
	var shoulder: Node3D = _pivot(_rig, Vector3(sx * 0.42, 0.96, 0.22))
	shoulder.rotation.z = sx * 0.18

	# Khớp vai – sphere to
	_sphere(shoulder, Vector3(0, 0, 0), 0.095, _mat_scale)

	# ── Xương cánh trên (humerus) – dày, khỏe ────────────────────────────────
	# Chạy ngang ra ngoài rồi hơi chúc xuống
	_box(shoulder, Vector3(sx*0.28, -0.04, 0.0), Vector3(0.58, 0.13, 0.15), _mat_body)
	_box(shoulder, Vector3(sx*0.28, -0.02, 0.0), Vector3(0.54, 0.08, 0.10), _mat_scale)  # viền vảy

	# Khớp khuỷu – sphere nổi bật
	var elbow: Node3D = _pivot(shoulder, Vector3(sx * 0.60, -0.06, 0.0))
	_sphere(elbow, Vector3(0, 0, 0), 0.085, _mat_scale)

	# ── Xương cánh giữa (radius) – pivot khuỷu ───────────────────────────────
	if sx < 0.0:
		_wing_l2 = elbow
	else:
		_wing_r2 = elbow

	_box(elbow, Vector3(sx*0.32, 0.0, 0.0), Vector3(0.66, 0.10, 0.12), _mat_body)
	_box(elbow, Vector3(sx*0.32, 0.02, 0.0), Vector3(0.62, 0.06, 0.08), _mat_scale)

	# Khớp cổ tay
	var wrist: Node3D = _pivot(elbow, Vector3(sx * 0.66, 0.0, 0.0))
	_sphere(wrist, Vector3(0, 0, 0), 0.072, _mat_scale)

	if sx < 0.0:
		_wing_l3 = wrist
	else:
		_wing_r3 = wrist

	# ── 5 ngón cánh (finger rays) dài dần từ trước ra sau ────────────────────
	# Ngón 0 = ngón cái ngắn nhất, ngón 4 = dài nhất phía sau
	var finger_len: Array[float] = [0.55, 0.85, 1.05, 1.20, 1.10]
	var finger_z:   Array[float] = [-0.08, 0.04, 0.16, 0.28, 0.40]

	for fi in range(5):
		var flen: float = finger_len[fi]
		var fz:   float = finger_z[fi]
		var fbase: Node3D = _pivot(wrist, Vector3(0, 0, fz))

		# Phalange 1 – đốt gốc dày
		_box(fbase, Vector3(sx*flen*0.28, 0.0, 0.0),
			 Vector3(flen*0.56, 0.055, 0.055), _mat_body)
		# Phalange 2 – đốt giữa mảnh hơn
		var fmid: Node3D = _pivot(fbase, Vector3(sx*flen*0.56, 0.0, 0.0))
		_box(fmid, Vector3(sx*flen*0.22, 0.0, 0.0),
			 Vector3(flen*0.44, 0.040, 0.040), _mat_body)
		# Móng vuốt đầu ngón – nhọn, phát sáng
		var ftip: Node3D = _pivot(fmid, Vector3(sx*flen*0.44, 0.0, 0.0))
		_box(ftip, Vector3(sx*0.06, -0.02, 0.0), Vector3(0.12, 0.05, 0.04), _mat_claw)
		# Gân ngón cánh – đường neon mỏng chạy dọc
		_box(fbase, Vector3(sx*flen*0.28, 0.02, 0.0),
			 Vector3(flen*0.56, 0.015, 0.015), _mat_glow)

	# Móng cái (thumb claw) – nổi bật, cong ra trước
	_box(wrist, Vector3(sx*0.08, 0.10, -0.18), Vector3(0.07, 0.18, 0.07), _mat_claw)
	_box(wrist, Vector3(sx*0.08, 0.20, -0.22), Vector3(0.05, 0.14, 0.05), _mat_claw)

	# ── Màng cánh – 3 lớp tạo chiều sâu ─────────────────────────────────────
	# Lớp chính (giữa) – màu đỏ wing
	_box(shoulder, Vector3(sx*0.28, -0.08, 0.18), Vector3(0.58, 0.05, 0.52), _mat_wing)
	_box(elbow,    Vector3(sx*0.32, -0.06, 0.22), Vector3(0.66, 0.05, 0.56), _mat_wing)
	_box(wrist,    Vector3(sx*0.20, -0.05, 0.24), Vector3(0.42, 0.04, 0.52), _mat_wing)

	# Lớp trước (phía trước thân) – mỏng hơn
	_box(shoulder, Vector3(sx*0.28, -0.06, -0.06), Vector3(0.58, 0.04, 0.20), _mat_wing)
	_box(elbow,    Vector3(sx*0.32, -0.05, -0.06), Vector3(0.66, 0.04, 0.18), _mat_wing)

	# Lớp sau phủ tới ngón xa nhất – semi-transparent feel (dùng mat_wing nhạt hơn)
	_box(wrist, Vector3(sx*0.20, -0.04, 0.52), Vector3(0.42, 0.035, 0.48), _mat_wing)

	# ── Gân màng cánh – các đường neon chạy từ cổ tay ra ngón ────────────────
	for gi in range(4):
		var gz: float = 0.06 + float(gi) * 0.14
		_box(wrist, Vector3(sx*0.20, -0.025, gz),
			 Vector3(0.40, 0.018, 0.018), _mat_glow)

	# ── Patagium lớn – màng nối thân đến vai ─────────────────────────────────
	_box(_rig, Vector3(sx*0.68, 0.82, 0.18), Vector3(0.26, 0.05, 0.56), _mat_wing)
	_box(_rig, Vector3(sx*0.55, 0.88, 0.06), Vector3(0.16, 0.04, 0.32), _mat_wing)
	# Gân patagium
	_box(_rig, Vector3(sx*0.62, 0.85, 0.20), Vector3(0.24, 0.018, 0.018), _mat_glow)
	_box(_rig, Vector3(sx*0.62, 0.85, 0.32), Vector3(0.24, 0.018, 0.018), _mat_glow)

	# ── Gán ref pivot cho animation ──────────────────────────────────────────
	if sx < 0.0:
		_wing_l  = shoulder
	else:
		_wing_r  = shoulder

# ── Tail (8 đoạn, giảm dần, cuối có vây hình thoi) ───────────────────────────
func _build_dragon_tail() -> void:
	_tail.clear()
	var tsz: Array[Vector3] = [
		Vector3(0.38,0.30,0.28), Vector3(0.32,0.26,0.26),
		Vector3(0.26,0.22,0.24), Vector3(0.20,0.18,0.22),
		Vector3(0.16,0.14,0.20), Vector3(0.12,0.10,0.18),
		Vector3(0.08,0.07,0.16), Vector3(0.05,0.05,0.14)]
	var tp2: Node3D = _rig
	for i in range(8):
		var off: Vector3
		if i == 0:
			off = Vector3(0, 0.68, -0.52)
		else:
			off = Vector3(0, 0, -tsz[i-1].z)
		var tp: Node3D = _pivot(tp2, off)
		# Đốt đuôi chính
		_box(tp, Vector3(0, 0, -tsz[i].z * 0.5), tsz[i], _mat_body)
		# Vảy lưng đuôi (trên)
		if i < 6:
			var fin_h: float = 0.18 - float(i) * 0.02
			_box(tp, Vector3(0, tsz[i].y * 0.55, -tsz[i].z * 0.4),
				 Vector3(0.05, fin_h, 0.06), _mat_glow)
		# Vảy hông đuôi (hai bên) – chỉ 4 đoạn đầu
		if i < 4:
			_box(tp, Vector3(-tsz[i].x*0.55, 0.0, -tsz[i].z*0.4),
				 Vector3(0.04, tsz[i].y*0.6, 0.06), _mat_scale)
			_box(tp, Vector3( tsz[i].x*0.55, 0.0, -tsz[i].z*0.4),
				 Vector3(0.04, tsz[i].y*0.6, 0.06), _mat_scale)
		_tail.append(tp)
		tp2 = tp
	# Mũi đuôi – vây hình thoi lớn (tail blade)
	_box(tp2, Vector3(0,  0.10, -0.14), Vector3(0.04, 0.22, 0.14), _mat_glow)  # vây trên
	_box(tp2, Vector3(0, -0.06, -0.14), Vector3(0.04, 0.12, 0.14), _mat_glow)  # vây dưới
	_box(tp2, Vector3(-0.10, 0.02, -0.14), Vector3(0.20, 0.04, 0.14), _mat_glow)  # vây ngang

# ═════════════════════════════════════════════════════════════════════════════
# ANIMATION
# ═════════════════════════════════════════════════════════════════════════════
func _animate(delta: float) -> void:
	var t := _time
	match _state:
		State.IDLE:   _danim_idle(delta, t)
		State.WALK:   _danim_walk(delta, t, 1.0)
		State.SPRINT: _danim_walk(delta, t, sprint_cycle_mult)
		State.CROUCH: _danim_crouch(delta, t)
		State.DASH:   _danim_dash(delta, t)
		State.ATTACK: _danim_attack(delta, t)
		State.JUMP:   _danim_air(delta, t)
		State.FALL:   _danim_air(delta, t)

# ── IDLE ──────────────────────────────────────────────────────────────────────
func _danim_idle(delta: float, t: float) -> void:
	var b := sin(t * idle_breathe_spd)            # thở
	var bw := sin(t * wing_flap_idle_spd * 0.5)   # nhịp cánh idle

	# Thân thở nhẹ
	_rig.position.y = lerp(_rig.position.y, 0.10 + b*0.015, delta*6.0)
	_rig.rotation.x = lerp(_rig.rotation.x, 0.0,  delta*8.0)
	_rig.rotation.z = b * 0.008

	# Cổ ngẩng cao, đầu nhìn xung quanh chậm
	_neck.rotation.x  = lerp(_neck.rotation.x,  -0.35 + b*0.04, delta*4.0)
	_neck.rotation.y  = sin(t * 0.5) * 0.08
	_neck2.rotation.x = lerp(_neck2.rotation.x, -0.25 + b*0.03, delta*4.0)
	_head_pivot.rotation.y = sin(t * 0.4) * 0.12
	# Hàm hơi mở lúc thở
	_jaw.rotation.x = lerp(_jaw.rotation.x, 0.04 + b*0.02, delta*5.0)

	# Cánh – idle: nhịp thở nhẹ, cánh gập lên trên thoải mái
	var wa_idle: float = 0.28 + bw * 0.08   # biên độ vai
	_wing_l.rotation.z  = lerp(_wing_l.rotation.z,   wa_idle,        delta*3.0)
	_wing_l.rotation.x  = lerp(_wing_l.rotation.x,   0.10 + b*0.04,  delta*3.0)
	_wing_l2.rotation.z = lerp(_wing_l2.rotation.z,  0.35 + bw*0.10, delta*3.0)
	_wing_l2.rotation.x = lerp(_wing_l2.rotation.x,  0.06,           delta*3.0)
	_wing_l3.rotation.x = lerp(_wing_l3.rotation.x,  0.12 + bw*0.06, delta*3.0)
	_wing_r.rotation.z  = lerp(_wing_r.rotation.z,  -wa_idle,        delta*3.0)
	_wing_r.rotation.x  = lerp(_wing_r.rotation.x,   0.10 + b*0.04,  delta*3.0)
	_wing_r2.rotation.z = lerp(_wing_r2.rotation.z, -0.35 - bw*0.10, delta*3.0)
	_wing_r2.rotation.x = lerp(_wing_r2.rotation.x,  0.06,           delta*3.0)
	_wing_r3.rotation.x = lerp(_wing_r3.rotation.x,  0.12 + bw*0.06, delta*3.0)

	# Chân đứng thư giãn
	_fl_thigh.rotation.x = lerp(_fl_thigh.rotation.x, 0.10, delta*5.0)
	_fl_shin.rotation.x  = lerp(_fl_shin.rotation.x,  0.25, delta*5.0)
	_fr_thigh.rotation.x = lerp(_fr_thigh.rotation.x, 0.10, delta*5.0)
	_fr_shin.rotation.x  = lerp(_fr_shin.rotation.x,  0.25, delta*5.0)
	_bl_thigh.rotation.x = lerp(_bl_thigh.rotation.x, 0.18, delta*5.0)
	_bl_shin.rotation.x  = lerp(_bl_shin.rotation.x,  0.32, delta*5.0)
	_br_thigh.rotation.x = lerp(_br_thigh.rotation.x, 0.18, delta*5.0)
	_br_shin.rotation.x  = lerp(_br_shin.rotation.x,  0.32, delta*5.0)

	# Vây lưng rung nhẹ
	for i in range(_spine_fins.size()):
		_spine_fins[i].rotation.z = sin(t*1.2 + float(i)*0.4) * 0.06

	# Đuôi lắc lư lười biếng
	for i in range(_tail.size()):
		_tail[i].rotation.y = sin(t*tail_wave_speed*0.35 + float(i)*0.7) * (0.10+float(i)*0.05)
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, 0.05+float(i)*0.02, delta*2.5)

# ── WALK / SPRINT ─────────────────────────────────────────────────────────────
func _danim_walk(delta: float, t: float, speed_mult: float) -> void:
	var cyc  := t * walk_cycle_speed * speed_mult
	var cyc2 := cyc + PI    # phase đảo – chân đối diện

	# Thân nhún nhảy nhẹ theo bước
	_rig.position.y = 0.10 + abs(sin(cyc * 2.0)) * (0.025 + speed_mult*0.015)
	_rig.rotation.x = lerp(_rig.rotation.x, -0.06 * speed_mult, delta*8.0)
	_rig.rotation.z = sin(cyc) * (0.025 + speed_mult*0.010)

	# Cổ lắc nhẹ theo nhịp bước
	_neck.rotation.x  = lerp(_neck.rotation.x,  -0.28 + sin(cyc)*0.05, delta*6.0)
	_neck2.rotation.x = lerp(_neck2.rotation.x, -0.20 + sin(cyc)*0.04, delta*6.0)
	_neck.rotation.y  = sin(cyc*0.5) * 0.06
	_head_pivot.rotation.x = lerp(_head_pivot.rotation.x, 0.0, delta*5.0)
	_jaw.rotation.x = lerp(_jaw.rotation.x, 0.0, delta*8.0)

	# Cánh vỗ mạnh theo nhịp bước – shoulder lên/xuống, elbow gập theo
	var wf := sin(cyc * wing_flap_run_spd / walk_cycle_speed)
	var wa := 0.22 + speed_mult * 0.14          # góc vai base
	var we := 0.28 + speed_mult * 0.12 + wf * 0.18  # góc khuỷu
	# Shoulder (wing_l/r): xoay Z = vỗ lên/xuống, xoay X = mở ra
	_wing_l.rotation.z  = lerp(_wing_l.rotation.z,   wa - wf * 0.35, delta*7.0)
	_wing_l.rotation.x  = lerp(_wing_l.rotation.x,   0.08 - wf*0.06, delta*6.0)
	_wing_l2.rotation.z = lerp(_wing_l2.rotation.z,  we,              delta*6.0)
	_wing_l2.rotation.x = lerp(_wing_l2.rotation.x,  0.04 + wf*0.08, delta*5.0)
	_wing_l3.rotation.x = lerp(_wing_l3.rotation.x,  0.10 + wf*0.12, delta*4.0)
	_wing_r.rotation.z  = lerp(_wing_r.rotation.z,  -(wa - wf * 0.35), delta*7.0)
	_wing_r.rotation.x  = lerp(_wing_r.rotation.x,   0.08 - wf*0.06, delta*6.0)
	_wing_r2.rotation.z = lerp(_wing_r2.rotation.z, -we,              delta*6.0)
	_wing_r2.rotation.x = lerp(_wing_r2.rotation.x,  0.04 + wf*0.08, delta*5.0)
	_wing_r3.rotation.x = lerp(_wing_r3.rotation.x,  0.10 + wf*0.12, delta*4.0)

	# 4 chân – diagonal gait (FL+BR đồng pha, FR+BL đồng pha)
	_fl_thigh.rotation.x =  sin(cyc)  * 0.48
	_fl_shin.rotation.x  =  abs(sin(cyc))  * 0.60
	_fl_foot.rotation.x  = -abs(sin(cyc))  * 0.25
	_fr_thigh.rotation.x =  sin(cyc2) * 0.48
	_fr_shin.rotation.x  =  abs(sin(cyc2)) * 0.60
	_fr_foot.rotation.x  = -abs(sin(cyc2)) * 0.25

	_bl_thigh.rotation.x =  sin(cyc2) * 0.52
	_bl_shin.rotation.x  =  abs(sin(cyc2)) * 0.65
	_bl_foot.rotation.x  = -abs(sin(cyc2)) * 0.28
	_br_thigh.rotation.x =  sin(cyc)  * 0.52
	_br_shin.rotation.x  =  abs(sin(cyc))  * 0.65
	_br_foot.rotation.x  = -abs(sin(cyc))  * 0.28

	# Đuôi sóng từ gốc ra ngọn
	for i in range(_tail.size()):
		var lag: float = float(i) * 0.55
		_tail[i].rotation.y = sin(t*tail_wave_speed + lag) * (0.18+float(i)*0.07) * speed_mult
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, 0.04+float(i)*0.03, delta*4.0)

	# Vây lưng rung theo nhịp
	for i in range(_spine_fins.size()):
		_spine_fins[i].rotation.z = sin(cyc + float(i)*0.3) * (0.05 + speed_mult*0.04)

# ── CROUCH ────────────────────────────────────────────────────────────────────
func _danim_crouch(delta: float, t: float) -> void:
	# Rồng phục xuống – tư thế chuẩn bị tấn công
	_rig.position.y = lerp(_rig.position.y, -0.18, delta*8.0)
	_rig.rotation.x = lerp(_rig.rotation.x,  0.28, delta*7.0)

	# Cổ vươn ra trước thấp, đầu cúi
	_neck.rotation.x  = lerp(_neck.rotation.x,   0.15, delta*6.0)
	_neck2.rotation.x = lerp(_neck2.rotation.x,  0.10, delta*6.0)
	_head_pivot.rotation.x = lerp(_head_pivot.rotation.x, 0.10, delta*5.0)
	_jaw.rotation.x = lerp(_jaw.rotation.x, 0.05, delta*5.0)

	# Cánh gập sát thân khi phục
	_wing_l.rotation.z  = lerp(_wing_l.rotation.z,   0.72, delta*7.0)
	_wing_l.rotation.x  = lerp(_wing_l.rotation.x,  -0.15, delta*6.0)
	_wing_l2.rotation.z = lerp(_wing_l2.rotation.z,  1.05, delta*7.0)
	_wing_l2.rotation.x = lerp(_wing_l2.rotation.x,   0.20, delta*6.0)
	_wing_l3.rotation.x = lerp(_wing_l3.rotation.x,   0.30, delta*5.0)
	_wing_r.rotation.z  = lerp(_wing_r.rotation.z,  -0.72, delta*7.0)
	_wing_r.rotation.x  = lerp(_wing_r.rotation.x,  -0.15, delta*6.0)
	_wing_r2.rotation.z = lerp(_wing_r2.rotation.z, -1.05, delta*7.0)
	_wing_r2.rotation.x = lerp(_wing_r2.rotation.x,   0.20, delta*6.0)
	_wing_r3.rotation.x = lerp(_wing_r3.rotation.x,   0.30, delta*5.0)

	# 4 chân gập xuống sâu
	_fl_thigh.rotation.x = lerp(_fl_thigh.rotation.x,  0.55, delta*8.0)
	_fl_shin.rotation.x  = lerp(_fl_shin.rotation.x,   0.80, delta*8.0)
	_fl_foot.rotation.x  = lerp(_fl_foot.rotation.x,  -0.35, delta*8.0)
	_fr_thigh.rotation.x = lerp(_fr_thigh.rotation.x,  0.55, delta*8.0)
	_fr_shin.rotation.x  = lerp(_fr_shin.rotation.x,   0.80, delta*8.0)
	_fr_foot.rotation.x  = lerp(_fr_foot.rotation.x,  -0.35, delta*8.0)
	_bl_thigh.rotation.x = lerp(_bl_thigh.rotation.x,  0.65, delta*8.0)
	_bl_shin.rotation.x  = lerp(_bl_shin.rotation.x,   0.90, delta*8.0)
	_bl_foot.rotation.x  = lerp(_bl_foot.rotation.x,  -0.40, delta*8.0)
	_br_thigh.rotation.x = lerp(_br_thigh.rotation.x,  0.65, delta*8.0)
	_br_shin.rotation.x  = lerp(_br_shin.rotation.x,   0.90, delta*8.0)
	_br_foot.rotation.x  = lerp(_br_foot.rotation.x,  -0.40, delta*8.0)

	# Đuôi dang ra hai bên, giữ thăng bằng
	for i in range(_tail.size()):
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, -0.08+float(i)*0.02, delta*5.0)
		_tail[i].rotation.y = sin(t*tail_wave_speed*0.25+float(i)*0.5) * (0.06+float(i)*0.03)

# ── DASH ──────────────────────────────────────────────────────────────────────
func _danim_dash(delta: float, _t: float) -> void:
	# Rồng lao như tên bắn – cánh xoè rộng, thân thẳng ngang
	_rig.position.y = lerp(_rig.position.y,  0.04, delta*22.0)
	_rig.rotation.x = lerp(_rig.rotation.x,  0.40, delta*22.0)

	_neck.rotation.x  = lerp(_neck.rotation.x,   0.20, delta*18.0)
	_neck2.rotation.x = lerp(_neck2.rotation.x,  0.15, delta*18.0)
	_jaw.rotation.x   = lerp(_jaw.rotation.x,    0.18, delta*18.0)  # há miệng khi lao

	# Cánh xoè phẳng hoàn toàn khi dash – tư thế lướt khí động học
	_wing_l.rotation.z  = lerp(_wing_l.rotation.z,  -0.05, delta*22.0)
	_wing_l.rotation.x  = lerp(_wing_l.rotation.x,  -0.08, delta*20.0)
	_wing_l2.rotation.z = lerp(_wing_l2.rotation.z,  0.06, delta*20.0)
	_wing_l2.rotation.x = lerp(_wing_l2.rotation.x, -0.04, delta*18.0)
	_wing_l3.rotation.x = lerp(_wing_l3.rotation.x, -0.06, delta*16.0)
	_wing_r.rotation.z  = lerp(_wing_r.rotation.z,   0.05, delta*22.0)
	_wing_r.rotation.x  = lerp(_wing_r.rotation.x,  -0.08, delta*20.0)
	_wing_r2.rotation.z = lerp(_wing_r2.rotation.z, -0.06, delta*20.0)
	_wing_r2.rotation.x = lerp(_wing_r2.rotation.x, -0.04, delta*18.0)
	_wing_r3.rotation.x = lerp(_wing_r3.rotation.x, -0.06, delta*16.0)

	# Chân duỗi ra sau gọn
	_fl_thigh.rotation.x = lerp(_fl_thigh.rotation.x, -0.45, delta*20.0)
	_fl_shin.rotation.x  = lerp(_fl_shin.rotation.x,   0.20, delta*20.0)
	_fr_thigh.rotation.x = lerp(_fr_thigh.rotation.x, -0.45, delta*20.0)
	_fr_shin.rotation.x  = lerp(_fr_shin.rotation.x,   0.20, delta*20.0)
	_bl_thigh.rotation.x = lerp(_bl_thigh.rotation.x, -0.55, delta*20.0)
	_bl_shin.rotation.x  = lerp(_bl_shin.rotation.x,   0.18, delta*20.0)
	_br_thigh.rotation.x = lerp(_br_thigh.rotation.x, -0.55, delta*20.0)
	_br_shin.rotation.x  = lerp(_br_shin.rotation.x,   0.18, delta*20.0)

	# Đuôi duỗi thẳng ra sau
	for i in range(_tail.size()):
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, -0.12, delta*20.0)
		_tail[i].rotation.y = lerp(_tail[i].rotation.y,  0.0,  delta*20.0)

# ── ATTACK ────────────────────────────────────────────────────────────────────
func _danim_attack(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (_attack_timer / attack_duration)
	if prog < 0.35:
		# Phase 1: Windup – cổ lùi, cánh bung, thân nạp năng lượng
		_neck.rotation.x  = lerp(_neck.rotation.x,   0.35, delta*20.0)
		_neck2.rotation.x = lerp(_neck2.rotation.x,  0.25, delta*20.0)
		_head_pivot.rotation.x = lerp(_head_pivot.rotation.x, 0.20, delta*20.0)
		_jaw.rotation.x   = lerp(_jaw.rotation.x,    0.0,  delta*15.0)
		_rig.rotation.x   = lerp(_rig.rotation.x,   -0.15, delta*14.0)
		# Cánh bung mạnh lên trên – windup
		_wing_l.rotation.z  = lerp(_wing_l.rotation.z,  -0.55, delta*24.0)
		_wing_l.rotation.x  = lerp(_wing_l.rotation.x,  -0.20, delta*22.0)
		_wing_l2.rotation.z = lerp(_wing_l2.rotation.z, -0.15, delta*22.0)
		_wing_l2.rotation.x = lerp(_wing_l2.rotation.x, -0.10, delta*20.0)
		_wing_r.rotation.z  = lerp(_wing_r.rotation.z,   0.55, delta*24.0)
		_wing_r.rotation.x  = lerp(_wing_r.rotation.x,  -0.20, delta*22.0)
		_wing_r2.rotation.z = lerp(_wing_r2.rotation.z,  0.15, delta*22.0)
		_wing_r2.rotation.x = lerp(_wing_r2.rotation.x, -0.10, delta*20.0)
		# Chân trước co lên
		_fl_thigh.rotation.x = lerp(_fl_thigh.rotation.x, -0.60, delta*20.0)
		_fr_thigh.rotation.x = lerp(_fr_thigh.rotation.x, -0.60, delta*20.0)
		_fl_shin.rotation.x  = lerp(_fl_shin.rotation.x,   0.80, delta*20.0)
		_fr_shin.rotation.x  = lerp(_fr_shin.rotation.x,   0.80, delta*20.0)
	else:
		# Phase 2: Strike – đầu phóng ra trước, há hàm, chân bổ xuống, cánh đập
		_neck.rotation.x  = lerp(_neck.rotation.x,  -0.65, delta*35.0)
		_neck2.rotation.x = lerp(_neck2.rotation.x, -0.45, delta*35.0)
		_head_pivot.rotation.x = lerp(_head_pivot.rotation.x, -0.20, delta*35.0)
		_jaw.rotation.x   = lerp(_jaw.rotation.x,    0.45, delta*35.0)  # há hàm rộng
		_rig.rotation.x   = lerp(_rig.rotation.x,    0.20, delta*25.0)
		# Cánh đập xuống mạnh – strike
		_wing_l.rotation.z  = lerp(_wing_l.rotation.z,   0.70, delta*32.0)
		_wing_l.rotation.x  = lerp(_wing_l.rotation.x,   0.18, delta*30.0)
		_wing_l2.rotation.z = lerp(_wing_l2.rotation.z,  0.85, delta*30.0)
		_wing_l2.rotation.x = lerp(_wing_l2.rotation.x,  0.22, delta*28.0)
		_wing_l3.rotation.x = lerp(_wing_l3.rotation.x,  0.30, delta*25.0)
		_wing_r.rotation.z  = lerp(_wing_r.rotation.z,  -0.70, delta*32.0)
		_wing_r.rotation.x  = lerp(_wing_r.rotation.x,   0.18, delta*30.0)
		_wing_r2.rotation.z = lerp(_wing_r2.rotation.z, -0.85, delta*30.0)
		_wing_r2.rotation.x = lerp(_wing_r2.rotation.x,  0.22, delta*28.0)
		_wing_r3.rotation.x = lerp(_wing_r3.rotation.x,  0.30, delta*25.0)
		# Chân trước bổ xuống (cào)
		_fl_thigh.rotation.x = lerp(_fl_thigh.rotation.x,  0.65, delta*32.0)
		_fr_thigh.rotation.x = lerp(_fr_thigh.rotation.x,  0.65, delta*32.0)
		_fl_shin.rotation.x  = lerp(_fl_shin.rotation.x,   0.20, delta*30.0)
		_fr_shin.rotation.x  = lerp(_fr_shin.rotation.x,   0.20, delta*30.0)
		# Đuôi vút lên để tạo đòn bẩy
		for i in range(_tail.size()):
			_tail[i].rotation.x = lerp(_tail[i].rotation.x,
				0.25+float(i)*0.08, delta*25.0)
	# Chân sau đứng vững suốt
	_bl_thigh.rotation.x = lerp(_bl_thigh.rotation.x,  0.30, delta*8.0)
	_bl_shin.rotation.x  = lerp(_bl_shin.rotation.x,   0.45, delta*8.0)
	_br_thigh.rotation.x = lerp(_br_thigh.rotation.x,  0.30, delta*8.0)
	_br_shin.rotation.x  = lerp(_br_shin.rotation.x,   0.45, delta*8.0)

# ── AIR (JUMP + FALL) ─────────────────────────────────────────────────────────
func _danim_air(delta: float, _t: float) -> void:
	_rig.position.y = lerp(_rig.position.y, 0.10, delta*5.0)
	var rising := _state == State.JUMP
	var tuck: float
	if rising: tuck = clamp(velocity.y / _jump_v, 0.0, 1.0)
	else:      tuck = clamp(1.0 + velocity.y / _jump_v, 0.0, 1.0) * 0.4

	# Cánh xoè rộng khi nhảy/rơi – dang hết để lướt + tạo hiệu ứng hoành tráng
	var wing_spread: float = 0.15 if rising else 0.08
	var wing_droop:  float = tuck * 0.25
	_wing_l.rotation.z  = lerp(_wing_l.rotation.z,   wing_spread - wing_droop, delta*8.0)
	_wing_l.rotation.x  = lerp(_wing_l.rotation.x,  -0.12 + tuck*0.08,        delta*7.0)
	_wing_l2.rotation.z = lerp(_wing_l2.rotation.z,  0.10 + wing_droop*0.5,   delta*7.0)
	_wing_l2.rotation.x = lerp(_wing_l2.rotation.x, -0.06,                    delta*6.0)
	_wing_l3.rotation.x = lerp(_wing_l3.rotation.x, -0.08 + tuck*0.15,        delta*5.0)
	_wing_r.rotation.z  = lerp(_wing_r.rotation.z,  -(wing_spread - wing_droop), delta*8.0)
	_wing_r.rotation.x  = lerp(_wing_r.rotation.x,  -0.12 + tuck*0.08,        delta*7.0)
	_wing_r2.rotation.z = lerp(_wing_r2.rotation.z, -(0.10 + wing_droop*0.5), delta*7.0)
	_wing_r2.rotation.x = lerp(_wing_r2.rotation.x, -0.06,                    delta*6.0)
	_wing_r3.rotation.x = lerp(_wing_r3.rotation.x, -0.08 + tuck*0.15,        delta*5.0)

	# Cổ và đầu
	var fall_t: float = clamp(-velocity.y / 7.0, 0.0, 1.0)
	_neck.rotation.x  = lerp(_neck.rotation.x,  -0.40 + fall_t*0.25, delta*7.0)
	_neck2.rotation.x = lerp(_neck2.rotation.x, -0.30 + fall_t*0.20, delta*7.0)
	_jaw.rotation.x   = lerp(_jaw.rotation.x,    0.0,                 delta*6.0)
	_rig.rotation.x   = lerp(_rig.rotation.x,    0.0,                 delta*8.0)

	# 4 chân co lên / duỗi ra
	_fl_thigh.rotation.x = lerp(_fl_thigh.rotation.x, -0.28-tuck*0.45, delta*10.0)
	_fl_shin.rotation.x  = lerp(_fl_shin.rotation.x,   0.55+tuck*0.50, delta*10.0)
	_fr_thigh.rotation.x = lerp(_fr_thigh.rotation.x, -0.28-tuck*0.45, delta*10.0)
	_fr_shin.rotation.x  = lerp(_fr_shin.rotation.x,   0.55+tuck*0.50, delta*10.0)
	_bl_thigh.rotation.x = lerp(_bl_thigh.rotation.x, -0.35-tuck*0.40, delta*10.0)
	_bl_shin.rotation.x  = lerp(_bl_shin.rotation.x,   0.60+tuck*0.45, delta*10.0)
	_br_thigh.rotation.x = lerp(_br_thigh.rotation.x, -0.35-tuck*0.40, delta*10.0)
	_br_shin.rotation.x  = lerp(_br_shin.rotation.x,   0.60+tuck*0.45, delta*10.0)

	# Đuôi dang ra giữ thăng bằng
	for i in range(_tail.size()):
		var droop: float = (0.10+float(i)*0.06) if not rising else -0.08
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, droop, delta*5.0)
		_tail[i].rotation.y = lerp(_tail[i].rotation.y, 0.0,   delta*4.0)

	# Vây lưng rung theo gió
	for i in range(_spine_fins.size()):
		_spine_fins[i].rotation.z = sin(_time * 4.0 + float(i)*0.5) * 0.08
