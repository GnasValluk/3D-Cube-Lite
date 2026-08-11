## rescue_helicopter.gd — Trực thăng cứu hộ & đa năng (voxel HD).
## Dáng Airbus H145 / Bell 206: mũi vòm kính xanh, thân đỏ cứu hộ + trắng ngà,
## đuôi thon sọc đỏ-trắng, cánh quạt 4 lá đen-carbon đầu vàng quay nhanh (motion
## blur disc), cánh đuôi fenestron, càng đáp chữ V, đèn beacon đỏ nhấp nháy,
## đèn định vị xanh/đỏ, spotlight rọi xuống, tời cứu hộ cáp móc.
## Điều khiển: W/S = tiến/lùi, A/D = bẻ lái, SPACE = bay lên, SHIFT = bay xuống,
## F = lên/xuống. Đứng yên thì treo lơ lửng (hover).
extends CharacterBody3D
class_name RescueHelicopter

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")

# ── Kích thước (m) ────────────────────────────────────────────────────────────
const BODY_LEN: float = 3.3
const BODY_WID: float = 0.95
const CABIN_H: float = 0.85
const TAIL_LEN: float = 2.6
const RIDE_HEIGHT: float = 0.9
const DRIVER_SEAT := Vector3(0, 1.15, 0.25)
const BOARD_RANGE: float = 3.5

# ── Vật lý bay (m/s) ─────────────────────────────────────────────────────────
const MAX_SPEED: float = 15.0
const MAX_CLIMB: float = 6.0
const ACCEL: float = 6.5
const CLIMB_ACCEL: float = 9.0
const YAW_RATE: float = 1.6
const HOVER_DAMP: float = 3.2
const PITCH_TILT_MAX: float = 0.16
const ROLL_TILT_MAX: float = 0.12

# ── Đèn ───────────────────────────────────────────────────────────────────────
const LIGHT_MAX_ENERGY: float = 2.6
const DUSK_START: float = 17.0
const DUSK_END: float = 19.0
const DAWN_START: float = 5.0
const DAWN_END: float = 7.0

var _driver: Node3D = null
var _time: float = 0.0
var _beacon_state: bool = false
var _beacon_timer: float = 0.0
var _fwd_speed: float = 0.0
var _last_light_t: float = -1.0
var _fx_timer: float = 0.0

var max_hp: int = 220
var hp: int
var weapon_requirement: int = DestructibleEntity.WeaponReq.HEAVY
var drop_item_id: String = "rescue_helicopter"
var _destroyed: bool = false

var _rig: Node3D = null
var _rotor_hub: Node3D = null
var _rotor_blades: Node3D = null
var _tail_rotor: Node3D = null
var _spotlight: SpotLight3D = null
var _beacon_mat: StandardMaterial3D = null
var _beacon_mat2: StandardMaterial3D = null
var _nav_mat: StandardMaterial3D = null
var _dust: CPUParticles3D = null
var _exhaust: CPUParticles3D = null

func _ready() -> void:
	hp = max_hp
	add_to_group("destroyable_props")
	_build_mesh()
	_build_lights()
	_build_particles()
	_build_collision()

# ── Tương tác (F) ─────────────────────────────────────────────────────────────
func is_player_nearby(player: Node3D) -> bool:
	if _driver != null:
		return false
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= BOARD_RANGE

func is_driver(player: Node3D) -> bool:
	return _driver == player

func try_board(player: Node3D) -> bool:
	if _driver != null:
		return false
	if player == null or not is_instance_valid(player):
		return false
	if not is_player_nearby(player):
		return false
	_driver = player
	player.set_meta("driving_vehicle", self)
	if "velocity" in player and player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	_disable_driver_collision(player, true)
	_sync_driver()
	return true

func try_exit() -> void:
	if _driver == null:
		return
	var player: Node3D = _driver
	_driver = null
	if is_instance_valid(player):
		player.remove_meta("driving_vehicle")
	_disable_driver_collision(player, false)
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	var spot := _find_exit_spot()
	player.global_position = spot
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO

func is_driven() -> bool:
	return _driver != null and is_instance_valid(_driver)

func get_driver() -> Node3D:
	return _driver

func _disable_driver_collision(player: Node3D, disabled: bool) -> void:
	for ch in player.get_children():
		if ch is CollisionShape3D:
			ch.disabled = disabled

func _find_exit_spot() -> Vector3:
	var base := global_position
	var rt := global_transform.basis.x
	var candidates: Array[Vector3] = [
		base + rt * (BODY_WID * 0.5 + 0.9),
		base - rt * (BODY_WID * 0.5 + 0.9),
		base + Vector3(0, 0, 1.5),
		base - Vector3(0, 0, 1.2),
	]
	for c in candidates:
		var h := _ground_height_at(c.x, c.z)
		if h > -900.0:
			return Vector3(c.x, h, c.z)
	return base + rt * (BODY_WID * 0.5 + 1.0)

## Độ cao mặt đất (top block rắn) tại (wx, wz). -900 = không tìm thấy.
func _ground_height_at(wx: float, wz: float) -> float:
	var chunk := _chunk_at(wx, wz)
	if chunk == null or chunk.block_data == null:
		return -999.0
	var half: float = float(chunk._size) * 0.5
	var vx: int = int((wx - (chunk.global_position.x - half)) / _Data.VOXEL)
	var vz: int = int((wz - (chunk.global_position.z - half)) / _Data.VOXEL)
	if vx < 0 or vx >= chunk._cols or vz < 0 or vz >= chunk._cols:
		return -999.0
	for layer in range(_BlockData.CHUNK_H - 1, -1, -1):
		var bid: int = chunk.block_data.get_block(vx, layer, vz)
		if bid != _Data.BlockID.AIR and not _Data.is_water(bid):
			return _BlockData.layer_to_world_y(layer) + _BlockData.SLAB_HEIGHT * 0.5
	return -999.0

func _chunk_at(wx: float, wz: float) -> Node:
	var half: float = 32.0 * 0.5
	var cx: int = int(floor((wx + half) / 32.0))
	var cz: int = int(floor((wz + half) / 32.0))
	return WorldChunk.get_chunk(cx, cz, _Data._Dim.DimensionID.REAL_WORLD)

# ── Vật lý bay ────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_time += delta

	if _driver != null and (not is_instance_valid(_driver) or not _driver.is_inside_tree() \
			or (_driver.get("is_alive") != null and not bool(_driver.get("is_alive")))):
		_driver.remove_meta("driving_vehicle")
		_driver = null

	var fwd := -global_transform.basis.z
	var rt := global_transform.basis.x

	# Điều khiển
	var throttle := 0.0
	var yaw_cmd := 0.0
	var climb := 0.0
	if is_driven() and _driver.get("_is_player") == true:
		if Input.is_action_pressed("move_forward"):
			throttle = 1.0
		elif Input.is_action_pressed("move_back"):
			throttle = -1.0
		if Input.is_action_pressed("move_left"):
			yaw_cmd = 1.0
		elif Input.is_action_pressed("move_right"):
			yaw_cmd = -1.0
		if Input.is_action_pressed("jump"):
			climb = 1.0
		elif Input.is_action_pressed("crouch"):
			climb = -1.0

	# Xoay hướng
	rotation.y += yaw_cmd * YAW_RATE * delta

	# Độ cao: hover khi không nhấn, lên/xuống khi có input. Khi không có người
	# lái, đáp nhẹ xuống đất.
	if is_driven():
		var target_v_y := climb * MAX_CLIMB
		velocity.y = move_toward(velocity.y, target_v_y, CLIMB_ACCEL * delta)
	else:
		velocity.y -= 26.0 * delta
		velocity.y = minf(velocity.y, 0.0)

	# Tịnh tiến
	fwd.y = 0.0
	fwd = fwd.normalized()
	var target_speed := throttle * MAX_SPEED
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var fwd_v := horiz.dot(fwd)
	horiz += fwd * clampf(target_speed - fwd_v, -ACCEL * delta, ACCEL * delta)
	# Cản khi thả ga
	if throttle == 0.0 and is_driven():
		horiz = horiz.lerp(Vector3.ZERO, HOVER_DAMP * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	move_and_slide()
	_fwd_speed = velocity.dot(-global_transform.basis.z)

	# Nghiêng theo chuyển động (động cơ quán tính)
	if _rig:
		var tilt_x := clampf(_fwd_speed / MAX_SPEED, -1.0, 1.0) * PITCH_TILT_MAX
		var tilt_z := clampf(horiz.dot(rt) / MAX_SPEED, -1.0, 1.0) * ROLL_TILT_MAX
		_rig.rotation.x = lerp_angle(_rig.rotation.x, tilt_x, delta * 4.0)
		_rig.rotation.z = lerp_angle(_rig.rotation.z, tilt_z, delta * 4.0)

	# Cánh quạt quay (đứng im cũng quay khi có người lái)
	var spin: float = 0.0
	if _rotor_hub:
		spin = (12.0 + absf(_fwd_speed) * 0.35 + climb * 2.0) * delta * 60.0
		_rotor_hub.rotation.y += spin
	if _tail_rotor:
		_tail_rotor.rotation.z -= spin * 4.0

	# Bụi rotor wash khi bay thấp gần đất
	if _dust:
		var g := _ground_height_at(global_position.x, global_position.z)
		var near_ground: bool = g > -900.0 and global_position.y - g < 5.0
		_dust.emitting = is_driven() and near_ground

	if is_driven():
		_sync_driver()

func _sync_driver() -> void:
	if _driver == null:
		return
	_driver.global_position = global_transform * DRIVER_SEAT
	_driver.rotation.y = rotation.y + PI
	if _driver is CharacterBody3D:
		_driver.velocity = Vector3.ZERO

func _process(delta: float) -> void:
	_update_lights(delta)
	_update_particles(delta)

# ── Vẽ (meshes gộp theo material) ─────────────────────────────────────────────
func _make_mat(color: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = opts.get("metallic", 0.0)
	m.roughness = opts.get("roughness", 0.85)
	if opts.get("vertex_color", true):
		m.vertex_color_use_as_albedo = true
	if opts.get("emissive", false):
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = opts.get("energy", 1.8)
	if opts.get("transparent", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _add_v(sts: Dictionary, mat_id: String, pos: Vector3, size: Vector3,
		rot: Vector3 = Vector3.ZERO, alpha: float = 1.0) -> void:
	var st: SurfaceTool = sts.get(mat_id) as SurfaceTool
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[mat_id] = st
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var b := Basis.from_euler(rot)
	var tint := 0.94 + fmod(absf(pos.x * 7.13 + pos.y * 5.17 + pos.z * 3.71), 1.0) * 0.12
	var faces: Array = [
		[Vector3(0, 1, 0), Vector3(hx, 0, 0), Vector3(0, 0, hz)],
		[Vector3(0, -1, 0), Vector3(hx, 0, 0), Vector3(0, 0, -hz)],
		[Vector3(1, 0, 0), Vector3(0, hy, 0), Vector3(0, 0, hz)],
		[Vector3(-1, 0, 0), Vector3(0, hy, 0), Vector3(0, 0, -hz)],
		[Vector3(0, 0, 1), Vector3(hx, 0, 0), Vector3(0, hy, 0)],
		[Vector3(0, 0, -1), Vector3(hx, 0, 0), Vector3(0, -hy, 0)],
	]
	for f in faces:
		var n: Vector3 = b * f[0]
		var u: Vector3 = b * f[1]
		var v: Vector3 = b * f[2]
		var mul: float = 0.72
		if absf(n.y) > 0.9:
			mul = 1.0 if n.y > 0.0 else 0.5
		var c := Color(mul * tint, mul * tint, mul * tint, alpha)
		st.set_normal(n)
		st.set_color(c)
		st.add_vertex(pos + (-u - v))
		st.add_vertex(pos + (u - v))
		st.add_vertex(pos + (u + v))
		st.add_vertex(pos + (-u - v))
		st.add_vertex(pos + (u + v))
		st.add_vertex(pos + (-u + v))

func _commit_meshes(rig: Node3D, sts: Dictionary, mat_map: Dictionary) -> void:
	for id in sts:
		var st: SurfaceTool = sts[id] as SurfaceTool
		var mesh := st.commit()
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat: StandardMaterial3D = mat_map[id]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rig.add_child(mi)

func _build_mesh() -> void:
	var rig := Node3D.new()
	rig.name = "_Rig"
	add_child(rig)
	_rig = rig

	var mats := {
		"red": _make_mat(Color(0.78, 0.14, 0.10)),
		"red_dark": _make_mat(Color(0.52, 0.07, 0.06)),
		"red_light": _make_mat(Color(0.88, 0.24, 0.16)),
		"white": _make_mat(Color(0.94, 0.92, 0.88)),
		"white_d": _make_mat(Color(0.72, 0.70, 0.66)),
		"black": _make_mat(Color(0.06, 0.06, 0.07)),
		"steel": _make_mat(Color(0.34, 0.35, 0.38)),
		"steel_d": _make_mat(Color(0.16, 0.17, 0.19)),
		"carbon": _make_mat(Color(0.10, 0.10, 0.11)),
		"yellow": _make_mat(Color(0.98, 0.78, 0.12)),
		"glass": _make_mat(Color(0.55, 0.72, 0.88, 0.85), {"transparent": true, "vertex_color": false, "roughness": 0.15, "metallic": 0.4}),
		"glass_dark": _make_mat(Color(0.20, 0.30, 0.42, 0.9), {"transparent": true, "vertex_color": false, "roughness": 0.2, "metallic": 0.3}),
		"blur": _make_mat(Color(0.60, 0.62, 0.66, 0.35), {"transparent": true, "vertex_color": false}),
		"beacon": _make_mat(Color(1.0, 0.20, 0.10), {"emissive": true, "energy": 3.0}),
		"beacon2": _make_mat(Color(1.0, 0.30, 0.12), {"emissive": true, "energy": 2.0}),
		"nav_green": _make_mat(Color(0.20, 1.0, 0.40), {"emissive": true, "energy": 2.6}),
		"nav_red": _make_mat(Color(1.0, 0.15, 0.20), {"emissive": true, "energy": 2.6}),
		"dash_green": _make_mat(Color(0.30, 1.0, 0.50), {"emissive": true, "energy": 2.0}),
		"dash_red": _make_mat(Color(1.0, 0.30, 0.25), {"emissive": true, "energy": 2.0}),
		"dash_amber": _make_mat(Color(1.0, 0.62, 0.20), {"emissive": true, "energy": 2.0}),
		"cross": _make_mat(Color(1.0, 1.0, 1.0)),
		"wood": _make_mat(Color(0.62, 0.44, 0.26)),
	}
	var sts: Dictionary = {}
	var b: Callable = func(pos: Vector3, size: Vector3, mat_id: String,
			rot: Vector3 = Vector3.ZERO) -> void:
		_add_v(sts, mat_id, pos, size, rot)

	# ═══ THÂN CHÍNH ═══════════════════════════════════════════════════════════
	# Sàn + vỏ dưới (đỏ)
	b.call(Vector3(0, 0.30, 0.35), Vector3(BODY_WID * 0.9, 0.28, 2.6), "red_dark")
	b.call(Vector3(0, 0.46, 0.35), Vector3(BODY_WID, 0.34, 2.6), "red")
	# Thân giữa bo cong (nhiều lớp nhỏ tạo dáng mềm)
	for i in 4:
		var t: float = float(i) / 3.0
		var w: float = BODY_WID * (0.72 + 0.28 * (1.0 - t))
		b.call(Vector3(0, 0.72 + t * 0.32, 0.55), Vector3(w, 0.20, 2.3 - t * 0.4), "red")
	# Trần
	b.call(Vector3(0, 1.02, 0.45), Vector3(BODY_WID * 0.7, 0.10, 2.0), "white")

	# ── Mũi & kính vòm ──
	# Mũi nhọn dần
	b.call(Vector3(0, 0.62, -1.45), Vector3(BODY_WID * 0.55, 0.5, 0.55), "red")
	b.call(Vector3(0, 0.70, -1.82), Vector3(BODY_WID * 0.34, 0.44, 0.40), "red")
	# Vòm kính (2 lớp để có đường cong)
	b.call(Vector3(0, 0.92, -1.30), Vector3(BODY_WID * 0.72, 0.44, 0.85), "glass")
	b.call(Vector3(0, 1.06, -1.22), Vector3(BODY_WID * 0.58, 0.32, 0.66), "glass")
	# Khung kính đen (dải ôm mũi)
	b.call(Vector3(0, 0.72, -1.30), Vector3(BODY_WID * 0.78, 0.06, 0.92), "black")
	b.call(Vector3(0, 1.16, -1.22), Vector3(BODY_WID * 0.62, 0.05, 0.70), "black")
	b.call(Vector3(0, 0.94, -1.62), Vector3(BODY_WID * 0.42, 0.05, 0.10), "black")

	# ── Nội thất ca-bin (nhìn xuyên kính) ──
	# Dashboard phát sáng
	b.call(Vector3(0, 0.78, -1.02), Vector3(0.70, 0.10, 0.18), "black")
	b.call(Vector3(0.16, 0.82, -1.04), Vector3(0.20, 0.04, 0.05), "dash_green")
	b.call(Vector3(-0.08, 0.82, -1.04), Vector3(0.10, 0.04, 0.04), "dash_red")
	b.call(Vector3(-0.24, 0.82, -1.04), Vector3(0.08, 0.04, 0.04), "dash_amber")
	# 2 ghế phi công đen
	for s in [1.0, -1.0]:
		b.call(Vector3(0.22 * s, 0.60, -0.55), Vector3(0.22, 0.16, 0.26), "black")
		b.call(Vector3(0.22 * s, 0.72, -0.60), Vector3(0.18, 0.22, 0.16), "black")
		# Cần lái
		b.call(Vector3(0.20 * s, 0.52, -0.92), Vector3(0.03, 0.26, 0.03), "steel")

	# ── Cửa trượt 2 bên (mở hé) ──
	for s in [1.0, -1.0]:
		# Ô cửa
		b.call(Vector3((BODY_WID * 0.5 + 0.02) * s, 0.80, 0.25), Vector3(0.05, 0.55, 0.95), "red_dark")
		# Cửa trượt hé
		b.call(Vector3((BODY_WID * 0.5 + 0.09) * s, 0.80, 0.55), Vector3(0.03, 0.50, 0.80), "white")
		# Tay nắm
		b.call(Vector3((BODY_WID * 0.5 + 0.02) * s, 0.78, 0.45), Vector3(0.05, 0.04, 0.28), "black")

	# ── Khoang sau: băng ca + hộp sơ cứu ──
	# Băng ca cứu thương (trắng, nằm)
	b.call(Vector3(-0.30, 0.56, 0.55), Vector3(0.30, 0.08, 1.05), "white")
	b.call(Vector3(-0.30, 0.62, 0.35), Vector3(0.26, 0.10, 0.30), "white_d")
	# Hộp sơ cứu đỏ + chữ thập trắng
	b.call(Vector3(0.28, 0.60, 0.55), Vector3(0.26, 0.22, 0.30), "red")
	b.call(Vector3(0.28, 0.60, 0.62), Vector3(0.08, 0.20, 0.04), "cross")
	b.call(Vector3(0.28, 0.66, 0.55), Vector3(0.26, 0.05, 0.30), "cross")
	# Cuộn dây thừng đay
	b.call(Vector3(0.30, 0.52, 0.95), Vector3(0.18, 0.20, 0.18), "wood")

	# ── Tời cứu hộ (phía trên cửa phải) ──
	b.call(Vector3(0.42, 1.05, 0.75), Vector3(0.10, 0.10, 0.24), "steel_d")
	b.call(Vector3(0.44, 1.02, 0.86), Vector3(0.04, 0.04, 0.20), "steel")
	# Cáp + móc rủ xuống
	b.call(Vector3(0.44, 0.62, 0.86), Vector3(0.02, 0.80, 0.02), "steel")
	b.call(Vector3(0.44, 0.56, 0.86), Vector3(0.10, 0.06, 0.08), "steel_d")

	# ═══ ĐUÔI ═════════════════════════════════════════════════════════════════
	# Ống đuôi thon dài
	for i in 5:
		var t: float = float(i) / 4.0
		var w: float = BODY_WID * 0.34 * (1.0 - t * 0.55)
		var z: float = 1.6 + t * 1.4
		b.call(Vector3(0, 0.70 + t * 0.16, z), Vector3(w, 0.36 - t * 0.12, 1.15), "red" if i % 2 == 0 else "white")
	# Sọc thể thao dọc đuôi
	for i in 3:
		b.call(Vector3(0, 0.78, 1.75 + i * 0.55), Vector3(BODY_WID * 0.30, 0.10, 0.28), "red" if i % 2 == 1 else "white")
	# Chóp đuôi
	b.call(Vector3(0, 0.92, 3.30), Vector3(BODY_WID * 0.16, 0.30, 0.30), "white")
	# Đèn định vị đuôi (trắng)
	b.call(Vector3(0, 0.95, 3.42), Vector3(0.06, 0.06, 0.06), "nav_red")

	# ═══ CÁNH QUẠT CHÍNH ══════════════════════════════════════════════════════
	# Trục + hub (trên trần)
	b.call(Vector3(0, 1.14, 0.45), Vector3(0.14, 0.14, 0.14), "steel_d")
	b.call(Vector3(0, 1.22, 0.45), Vector3(0.20, 0.08, 0.20), "steel")
	b.call(Vector3(0, 1.30, 0.45), Vector3(0.12, 0.06, 0.12), "black")
	# Động cơ + lưới tản nhiệt (dưới hub)
	b.call(Vector3(0, 0.95, 0.35), Vector3(0.50, 0.30, 0.55), "steel")
	for gx in [-0.16, -0.05, 0.06, 0.17]:
		b.call(Vector3(gx, 0.98, 0.62), Vector3(0.05, 0.16, 0.03), "black")
	# Ống xả đôi bạc
	for s in [0.28, -0.28]:
		b.call(Vector3(s, 0.78, 0.78), Vector3(0.06, 0.08, 0.20), "steel")
		b.call(Vector3(s, 0.78, 0.90), Vector3(0.07, 0.09, 0.06), "black")

	# Cánh quạt (rotor hub xoay — 4 lá + đầu vàng)
	_rotor_hub = Node3D.new()
	_rotor_hub.name = "_RotorHub"
	_rotor_hub.position = Vector3(0, 1.34, 0.45)
	rig.add_child(_rotor_hub)
	var r_sts: Dictionary = {}
	var rb: Callable = func(pos: Vector3, size: Vector3, mat_id: String,
			rot: Vector3 = Vector3.ZERO) -> void:
		_add_v(r_sts, mat_id, pos, size, rot)
	for i in 4:
		var ang: float = float(i) / 4.0 * TAU
		rb.call(Vector3(0, 0, 0), Vector3(0.03, 0.05, 2.35), "carbon", Vector3(0, ang, 0))
		rb.call(Vector3(0, 0, 2.05), Vector3(0.05, 0.05, 0.28), "yellow", Vector3(0, ang, 0))
	rb.call(Vector3(0, 0, 0), Vector3(0.16, 0.05, 0.16), "black")
	_commit_meshes(_rotor_hub, r_sts, mats)
	_rotor_blades = _rotor_hub

	# Motion blur disc (đĩa mờ khi quay)
	var disc_sts: Dictionary = {}
	_add_v(disc_sts, "blur", Vector3(0, 1.34, 0.45), Vector3(2.55, 0.01, 2.55), Vector3(PI * 0.5, 0, 0))
	_commit_meshes(rig, disc_sts, mats)

	# ═══ CÁNH QUẠT ĐUÔI (fenestron) ═══════════════════════════════════════════
	# Khung vòng bảo vệ
	b.call(Vector3(0, 0.98, 3.42), Vector3(0.36, 0.40, 0.10), "white")
	b.call(Vector3(0, 0.98, 3.42), Vector3(0.42, 0.08, 0.12), "red")
	_tail_rotor = Node3D.new()
	_tail_rotor.name = "_TailRotor"
	_tail_rotor.position = Vector3(0, 0.98, 3.42)
	rig.add_child(_tail_rotor)
	var t_sts: Dictionary = {}
	var tb: Callable = func(pos: Vector3, size: Vector3, mat_id: String,
			rot: Vector3 = Vector3.ZERO) -> void:
		_add_v(t_sts, mat_id, pos, size, rot)
	for i in 4:
		var ang: float = float(i) / 4.0 * TAU
		tb.call(Vector3(0, 0, 0), Vector3(0.16, 0.16, 0.03), "carbon", Vector3(ang, 0, 0))
	tb.call(Vector3(0, 0, 0), Vector3(0.08, 0.08, 0.06), "black")
	_commit_meshes(_tail_rotor, t_sts, mats)

	# ═══ CÀNG ĐÁP (skids) ═════════════════════════════════════════════════════
	# 2 thanh dọc đen
	for s in [1.0, -1.0]:
		b.call(Vector3((BODY_WID * 0.62) * s, 0.10, 0.45), Vector3(0.10, 0.08, 2.9), "black")
	# 4 chân chống chữ V
	for s in [1.0, -1.0]:
		for z in [-0.65, 1.45]:
			b.call(Vector3((BODY_WID * 0.42) * s, 0.34, z), Vector3(0.06, 0.52, 0.06), "black", Vector3(0, 0, -0.35 * s))
			b.call(Vector3((BODY_WID * 0.46) * s, 0.26, z), Vector3(0.05, 0.36, 0.05), "steel_d", Vector3(0, 0, 0.35 * s))

	# ═══ ĐÈN ══════════════════════════════════════════════════════════════════
	# Beacon đỏ trên đỉnh hub (nhấp nháy)
	_beacon_mat = mats["beacon"] as StandardMaterial3D
	_beacon_mat2 = mats["beacon2"] as StandardMaterial3D
	b.call(Vector3(0, 1.44, 0.45), Vector3(0.08, 0.10, 0.08), "beacon")
	# Beacon bụng
	b.call(Vector3(0, 0.20, 0.45), Vector3(0.07, 0.06, 0.07), "beacon2")
	# Đèn định vị hông
	_nav_mat = mats["nav_red"] as StandardMaterial3D
	b.call(Vector3((BODY_WID * 0.5 + 0.02), 0.72, -0.25), Vector3(0.05, 0.05, 0.05), "nav_red")
	b.call(Vector3(-(BODY_WID * 0.5 + 0.02), 0.72, -0.25), Vector3(0.05, 0.05, 0.05), "nav_green")
	# Spotlight dưới mũi
	b.call(Vector3(0, 0.28, -1.30), Vector3(0.16, 0.10, 0.20), "steel_d")
	b.call(Vector3(0, 0.22, -1.30), Vector3(0.12, 0.05, 0.16), "dash_amber")

	_commit_meshes(rig, sts, mats)

# ── Đèn thực tế ───────────────────────────────────────────────────────────────
func _build_lights() -> void:
	if _rig == null:
		return
	var spot := SpotLight3D.new()
	spot.light_energy = 0.0
	spot.light_color = Color(1.0, 0.93, 0.78)
	spot.spot_range = 14.0
	spot.spot_angle = 30.0
	spot.spot_attenuation = 1.1
	spot.shadow_enabled = false
	spot.position = Vector3(0, -0.1, -1.3)
	spot.rotation.x = deg_to_rad(90.0)
	_rig.add_child(spot)
	_spotlight = spot

func _update_lights(delta: float) -> void:
	var t := _light_factor(TimeSystem.get_hour() if TimeSystem else 12.0)
	if _spotlight:
		var target := t * LIGHT_MAX_ENERGY
		_spotlight.light_energy = lerp(_spotlight.light_energy, target, delta * 3.0)
	# Beacon nhấp nháy
	_beacon_timer -= delta
	if _beacon_timer <= 0.0:
		_beacon_timer = 0.55
		_beacon_state = not _beacon_state
		var e := 3.0 if _beacon_state else 0.4
		if _beacon_mat:
			_beacon_mat.emission_energy_multiplier = e
		if _beacon_mat2:
			_beacon_mat2.emission_energy_multiplier = 3.0 if _beacon_state else 0.3

func _light_factor(h: float) -> float:
	var night_t: float
	if h >= DAWN_END and h <= DUSK_START:
		night_t = 0.0
	elif h >= DUSK_END or h < DAWN_START:
		night_t = 1.0
	elif h >= DUSK_START and h < DUSK_END:
		night_t = smoothstep(0.0, 1.0, (h - DUSK_START) / (DUSK_END - DUSK_START))
	else:
		night_t = smoothstep(0.0, 1.0, 1.0 - (h - DAWN_START) / (DAWN_END - DAWN_START))
	var rain_t := 0.0
	if TimeSystem:
		rain_t = smoothstep(0.3, 1.0, TimeSystem.get_weather_intensity())
	return maxf(night_t, rain_t)

# ── Particles ─────────────────────────────────────────────────────────────────
func _build_particles() -> void:
	if _rig == null:
		return
	# Bụi rotor wash (bay thấp)
	var d := CPUParticles3D.new()
	d.name = "_RotorWash"
	d.amount = 40
	d.lifetime = 1.1
	d.one_shot = false
	d.emitting = false
	d.direction = Vector3(0, 1, 0)
	d.spread = 25.0
	d.gravity = Vector3(0, 0, 0)
	d.initial_velocity_min = 0.6
	d.initial_velocity_max = 1.4
	var sph := SphereMesh.new()
	sph.radius = 0.4
	sph.height = 0.8
	sph.radial_segments = 8
	sph.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	sph.material = m
	d.mesh = sph
	d.scale_amount_min = 0.35
	d.scale_amount_max = 0.7
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.55, 0.42, 0.5))
	ramp.set_color(1, Color(0.62, 0.55, 0.42, 0.0))
	d.color_ramp = ramp
	d.position = Vector3(0, -0.2, 0.45)
	_rig.add_child(d)
	_dust = d

	# Khói ống xả
	var p := CPUParticles3D.new()
	p.name = "_Exhaust"
	p.amount = 12
	p.lifetime = 0.9
	p.one_shot = false
	p.emitting = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 10.0
	p.gravity = Vector3(0, 0.2, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.6
	p.mesh = sph
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	var eramp := Gradient.new()
	eramp.set_color(0, Color(0.9, 0.9, 0.9, 0.4))
	eramp.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	p.color_ramp = eramp
	p.position = Vector3(0.28, 0.8, 1.0)
	_rig.add_child(p)
	_exhaust = p

func _update_particles(delta: float) -> void:
	_fx_timer -= delta
	if _fx_timer <= 0.0:
		_fx_timer = 0.18
		if _exhaust:
			_exhaust.emitting = is_driven()

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.7, 4.6)
	col.shape = box
	col.position = Vector3(0, 0.75, 0.4)
	add_child(col)

# ── Phá huỷ ───────────────────────────────────────────────────────────────────
func try_destroy(weapon_id: String, damage: int = 1) -> bool:
	if _destroyed or not _weapon_allowed(weapon_id):
		return false
	hp -= damage
	if hp > 0:
		_hit_flash()
		_spawn_damage_number(damage)
		SFXManager.play_hurt()
	else:
		_spawn_damage_number(damage)
		SFXManager.play_block_break()
		_die()
	return true

func _weapon_allowed(weapon_id: String) -> bool:
	match weapon_requirement:
		DestructibleEntity.WeaponReq.NONE:     return true
		DestructibleEntity.WeaponReq.AXE:      return weapon_id == "axe" or weapon_id == "iron_greatsword"
		DestructibleEntity.WeaponReq.SWORD:    return weapon_id == "iron_sword" or weapon_id == "iron_greatsword"
		DestructibleEntity.WeaponReq.PICKAXE:  return weapon_id == "pickaxe"
		DestructibleEntity.WeaponReq.HEAVY:    return weapon_id == "axe" or weapon_id == "pickaxe" \
			or weapon_id == "hoe" or weapon_id == "iron_greatsword"
	return false

func _hit_flash() -> void:
	for mi in _get_mesh_instances():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var orig := mi.material_override
		mi.material_override = mat
		var tween := create_tween()
		tween.tween_interval(0.08)
		tween.tween_callback(func():
			if is_instance_valid(mi):
				mi.material_override = orig
		)

func _get_mesh_instances() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for ch in get_children(true):
		if ch is MeshInstance3D:
			result.append(ch)
		_collect_mi(ch, result)
	return result

static func _collect_mi(node: Node, result: Array[MeshInstance3D]) -> void:
	for ch in node.get_children(true):
		if ch is MeshInstance3D:
			result.append(ch)
		_collect_mi(ch, result)

func _spawn_damage_number(dmg: int) -> void:
	var world := get_tree().current_scene if get_tree() else null
	if world == null:
		return
	var dn := FloatingDamage.new()
	world.add_child(dn)
	dn.setup(dmg, global_position + Vector3(0, 1.6, 0), Color.WHITE)

func _die() -> void:
	_destroyed = true
	spawn_drop()
	_on_destroy()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y + 0.5, 0.25)
	tween.tween_interval(0.3)
	tween.tween_callback(queue_free)

func _spawn_drop_velocity() -> Vector3:
	return Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 3.5), randf_range(-1.5, 1.5))

func spawn_drop() -> void:
	if drop_item_id == "":
		return
	var world := _find_world_manager()
	if world == null:
		return
	ItemDatabase.ensure_db()
	var def: ItemDef = ItemDatabase.items_db.get(drop_item_id)
	if def != null:
		DroppedItem.spawn(world, def, global_position, 1, _spawn_drop_velocity(), global_position.y)

func _on_destroy() -> void:
	if _driver != null:
		try_exit()

func _find_world_manager() -> Node3D:
	var p := get_parent()
	while p != null:
		if p is OpenWorldManager:
			return p
		p = p.get_parent()
	var scene := get_tree().current_scene if get_tree() else null
	if scene is Node3D:
		return scene
	return null
