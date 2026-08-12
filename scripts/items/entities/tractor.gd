## tractor.gd — Máy kéo nông nghiệp + rơ-moóc chở hàng + cơ chế lái trên đất.
## Vật lý mặt đất: bám sát địa hình (spring-damper quanh độ cao mặt đất, nhìn
## mặt trước để leo bậc), không nổi trên nước, W/S = ga/phanh, A/D = bẻ lái,
## bánh sau to + gai lốp nhô 2 lớp, bánh trước xoay hướng, lồng bảo vệ ca-bin
## hở + ghế da nâu + vô-lăng, ống xả khói khi nổ máy, đèn pha sáng đêm/mưa.
## Rơ-moọc thùng gỗ 3 mặt vách + thành sau hạ, nối khớp xoay lệch khi bẻ lái.
extends CharacterBody3D
class_name Tractor

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")

# ── Kích thước ────────────────────────────────────────────────────────────────
const BODY_WID: float = 1.05
const FRONT_AXLE_Z: float = -0.95
const REAR_AXLE_Z: float = 0.80
const FRONT_AXLE_Y: float = 0.32
const REAR_AXLE_Y: float = 0.52
const REAR_WHEEL_R: float = 0.55
const FRONT_WHEEL_R: float = 0.34
const TRAILER_WHEEL_R: float = 0.40
const HITCH_Z: float = 1.05
const TRAILER_BED_LEN: float = 2.2
const TRAILER_BED_WID: float = 1.1
const TRAILER_FLOOR_Y: float = 0.44
const RIDE_HEIGHT: float = 0.0
const DRIVER_SEAT := Vector3(0, 1.02, 0.2)
const BOARD_RANGE: float = 3.2

# ── Vật lý (m, s) ─────────────────────────────────────────────────────────────
const GRAVITY: float = 26.0
const TERRAIN_STIFF: float = 28.0
const TERRAIN_DAMP: float = 6.2
const ACCEL_FWD: float = 8.0
const ACCEL_REV: float = 5.0
const TOP_SPEED: float = 8.5
const REV_SPEED_MAX: float = 4.0
const LINEAR_DRAG: float = 0.85
const QUAD_DRAG: float = 0.18
const LATERAL_GRIP: float = 3.4
const STEER_RATE: float = 1.10
const STEER_SPEED_BAND: float = 4.0
const STEER_ANGLE_MAX: float = 0.42
const TRAILER_YAW_MAX: float = 0.34
# ── Leo bậc ──────────────────────────────────────────────────────────────────
const STEP_PROBE_DIST: float = 1.4
const STEP_UP_MIN: float = 0.16
const STEP_UP_MAX: float = 1.15
const STEP_UP_PUSH: float = 9.0

# ── Đèn ───────────────────────────────────────────────────────────────────────
const LIGHT_MAX_ENERGY: float = 2.6
const LIGHT_UPDATE_INTERVAL: float = 0.12
const DUSK_START: float = 17.0
const DUSK_END: float = 19.0
const DAWN_START: float = 5.0
const DAWN_END: float = 7.0

var _driver: Node3D = null
var _time: float = 0.0
var _prev_fwd_speed: float = 0.0
var _wheel_angle: float = 0.0
var _steer_cmd: float = 0.0
var _steer_angle: float = 0.0
var _trailer_yaw: float = 0.0
var _tilt_pitch: float = 0.0
var _tilt_roll: float = 0.0
var _last_chunk: Node = null
var _last_cx: int = 99999
var _last_cz: int = 99999

var max_hp: int = 150
var hp: int
var weapon_requirement: int = DestructibleEntity.WeaponReq.HEAVY
var drop_item_id: String = "tractor"
var _destroyed: bool = false

var _rig: Node3D = null
var _trailer_pivot: Node3D = null
var _front_steer: Node3D = null
var _wheels_tractor: Array[Node3D] = []
var _wheels_trailer: Array[Node3D] = []
var _spotlights: Array[Light3D] = []
var _lamp_mat: StandardMaterial3D = null
var _smoke: CPUParticles3D = null
var _light_timer: float = 0.0
var _last_light_t: float = -1.0
var _fx_timer: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("destroyable_props")
	_build_mesh()
	_build_lights()
	_build_smoke()
	_build_collision()

# ── Tương tác (F để lên/xuống) ────────────────────────────────────────────────
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
	spot.y = max(spot.y, global_position.y - 0.5)
	player.global_position = spot
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	if player.has_method("enable_exit_grace"):
		player.enable_exit_grace(0.5)

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
	var fwd := -global_transform.basis.z
	var rt := global_transform.basis.x
	var candidates: Array[Vector3] = [
		base + rt * (BODY_WID * 0.5 + 0.8),
		base - rt * (BODY_WID * 0.5 + 0.8),
		base + fwd * (absf(FRONT_AXLE_Z) + 1.2),
		base - fwd * (HITCH_Z + TRAILER_BED_LEN + 0.8),
	]
	for c in candidates:
		var h := _ground_height_at(c.x, c.z)
		if h > -900.0:
			return Vector3(c.x, h, c.z)
	return base + rt * (BODY_WID * 0.5 + 1.0)

## Độ cao mặt đất (top block bất kỳ không-không-khí) tại (wx, wz). -900 = rơi tự do.
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
		# Bỏ qua nước — máy kéo phải CHÌM xuống đáy (seabed) thay vì nổi trên
		# mặt như thuyền. Cột toàn nước → rơi tự do tới khi gặp đất rắn.
		if bid != _Data.BlockID.AIR and not _Data.is_water(bid):
			return _BlockData.layer_to_world_y(layer) + _BlockData.SLAB_HEIGHT * 0.5
	return -999.0

func _chunk_at(wx: float, wz: float) -> Node:
	var half: float = 32.0 * 0.5
	var cx: int = int(floor((wx + half) / 32.0))
	var cz: int = int(floor((wz + half) / 32.0))
	if cx == _last_cx and cz == _last_cz and _last_chunk != null and is_instance_valid(_last_chunk):
		return _last_chunk
	_last_chunk = null
	_last_cx = cx
	_last_cz = cz
	# Tra cứu O(1) qua registry của WorldChunk — thay cho _find_chunk_recursive
	# (đệ quy quét cả scene tree gây lag ~400ms mỗi lần đổi chunk).
	var found := WorldChunk.get_chunk(cx, cz, _Data._Dim.DimensionID.REAL_WORLD)
	if found == null:
		return null
	_last_chunk = found
	return found

# ── Vật lý ────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_time += delta

	if _driver != null and (not is_instance_valid(_driver) or not _driver.is_inside_tree() \
			or (_driver.get("is_alive") != null and not bool(_driver.get("is_alive")))):
		_driver.remove_meta("driving_vehicle")
		_driver = null

	var cx := global_position
	var fwd := -global_transform.basis.z
	var rt := global_transform.basis.x
	fwd.y = 0.0; fwd = fwd.normalized()
	rt.y = 0.0; rt = rt.normalized()

	var g_f := _ground_height_at(cx.x + fwd.x * 0.7, cx.z + fwd.z * 0.7)
	var g_b := _ground_height_at(cx.x - fwd.x * 0.7, cx.z - fwd.z * 0.7)
	var g_r := _ground_height_at(cx.x + rt.x * 0.6, cx.z + rt.z * 0.6)
	var g_l := _ground_height_at(cx.x - rt.x * 0.6, cx.z - rt.z * 0.6)
	var g_cv := _ground_height_at(cx.x, cx.z)
	var on_ground: bool = g_cv > -900.0

	if on_ground:
		var target_y: float = maxf(maxf(g_cv, g_f), maxf(g_r, g_l)) + RIDE_HEIGHT
		var err := target_y - global_position.y
		velocity.y += (err * TERRAIN_STIFF - velocity.y * TERRAIN_DAMP) * delta
		velocity.y = clampf(velocity.y, -6.0, 6.0)
	else:
		velocity.y -= GRAVITY * delta

	var throttle := 0.0
	var steer_cmd := 0.0
	if is_driven() and _driver.get("_is_player") == true:
		if Input.is_action_pressed("move_forward"):
			throttle = 1.0
		elif Input.is_action_pressed("move_back"):
			throttle = -1.0
		if Input.is_action_pressed("move_left"):
			steer_cmd = 1.0
		elif Input.is_action_pressed("move_right"):
			steer_cmd = -1.0
	_steer_cmd = steer_cmd

	var vh := Vector3(velocity.x, 0.0, velocity.z)
	var fwd_v := vh.dot(fwd)
	var lat_v := vh - fwd * fwd_v

	# Leo bậc: thăm dò đất phía trước xa hơn collider (1.4m) — khi tiến vào bậc
	# cao ≤1 block, đẩy thẳng đứng để khối collider vượt mép thay vì bị tường
	# bậc chặn ngang (fwd_v ≈ 0 lúc áp tường nên gate theo INPUT throttle).
	if on_ground and throttle > 0.0:
		var probe: float = _ground_height_at(cx.x + fwd.x * STEP_PROBE_DIST, cx.z + fwd.z * STEP_PROBE_DIST)
		var step_h: float = probe - g_cv
		if step_h > STEP_UP_MIN and step_h <= STEP_UP_MAX:
			velocity.y = maxf(velocity.y, minf(step_h * STEP_UP_PUSH, 6.0))

	# Chìm dưới nước: thêm cản để đi chậm hơn dưới mặt nước.
	if global_position.y < _Data.WATER_Y:
		velocity.x *= maxf(1.0 - 1.8 * delta, 0.0)
		velocity.z *= maxf(1.0 - 1.8 * delta, 0.0)

	# Ma sát + cản + bám ngang
	var speed := vh.length()
	var drag := -vh * (LINEAR_DRAG + QUAD_DRAG * speed) - lat_v * LATERAL_GRIP
	velocity.x += drag.x * delta
	velocity.z += drag.z * delta

	# Lực đẩy
	if throttle != 0.0 and on_ground:
		var accel := ACCEL_FWD if throttle > 0.0 else ACCEL_REV
		var max_s := TOP_SPEED if throttle > 0.0 else REV_SPEED_MAX
		if (throttle > 0.0 and fwd_v < max_s) or (throttle < 0.0 and fwd_v > -max_s):
			velocity += fwd * (accel * throttle) * delta

	# Bẻ lái
	var steer_speed := clampf(absf(fwd_v) / STEER_SPEED_BAND, 0.0, 1.0)
	_steer_angle = move_toward(_steer_angle, steer_cmd * STEER_ANGLE_MAX, delta * 3.2)
	if steer_speed > 0.01:
		var steer: float = _steer_angle * (1.0 if fwd_v >= 0.0 else -1.0)
		rotation.y += steer * STEER_RATE * steer_speed * delta

	# Rơ-moọc lệch theo quán tính: xe tiến bẻ trái thì thùng văng về phải (ngược
	# hướng cua) — khớp xoay phía sau kéo theo trễ. Dấu + cũ làm thùng lắc CÙNG
	# hướng cua = ngược quán tính. Chỉ tiến đổi dấu; lùi giữ nguyên (đã đúng).
	var target_trailer: float = steer_cmd * TRAILER_YAW_MAX * steer_speed * (-1.0 if fwd_v >= 0.0 else 1.0)
	_trailer_yaw = lerp_angle(_trailer_yaw, target_trailer, delta * 4.2)
	if _trailer_pivot:
		_trailer_pivot.rotation.y = _trailer_yaw

	# Bánh xe quay + bánh trước xoay hướng
	# Chiều quay: tiến (fwd_v>0) thì rotation.x phải GIẢM — đỉnh lốp đi về -Z
	# (trước), tiếp điểm dưới đứng yên trên mặt đất. Dấu + cũ làm đỉnh lốp đi
	# +Z → bánh quay NGƯỢC hướng di chuyển.
	var roll_speed: float = fwd_v / (REAR_WHEEL_R * 0.85)
	_wheel_angle -= roll_speed * delta
	for w in _wheels_tractor:
		w.rotation.x = _wheel_angle
	for w in _wheels_trailer:
		w.rotation.x = _wheel_angle
	if _front_steer:
		_front_steer.rotation.y = _steer_angle

	move_and_slide()

	# Nghiêng theo độ dốc
	if on_ground:
		var pitch_tgt: float = clampf((g_f - g_b) * 0.5, -0.25, 0.25)
		var roll_tgt: float = clampf((g_r - g_l) * 0.5, -0.25, 0.25)
		_tilt_pitch = lerp_angle(_tilt_pitch, pitch_tgt, delta * 6.0)
		_tilt_roll = lerp_angle(_tilt_roll, roll_tgt, delta * 6.0)

	_fx_timer -= delta
	if _fx_timer <= 0.0:
		_fx_timer = 0.16
		if _smoke:
			_smoke.emitting = is_driven()

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
	if _rig:
		_rig.rotation.x = _tilt_pitch
		_rig.rotation.z = _tilt_roll
	_update_lights(delta)

# ── Vẽ (meshes gộp theo material) ─────────────────────────────────────────────
func _make_mat(color: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = opts.get("metallic", 0.0)
	m.roughness = opts.get("roughness", 0.85)
	m.vertex_color_use_as_albedo = true
	if opts.get("emissive", false):
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = opts.get("energy", 1.8)
	if opts.get("transparent", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _add_v(sts: Dictionary, mat_id: String, pos: Vector3, size: Vector3,
		rot: Vector3 = Vector3.ZERO) -> void:
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
		var c := Color(mul * tint, mul * tint, mul * tint, 1.0)
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

## Bánh xe voxel: vòng lốp (mặt phẳng YZ — trục quay X) + gai nhô 2 lớp + mâm.
func _build_wheel(r: float, w: float) -> Node3D:
	var root := Node3D.new()
	var sts: Dictionary = {}
	var b: Callable = func(pos: Vector3, size: Vector3, mid: String, rot: Vector3 = Vector3.ZERO) -> void:
		_add_v(sts, mid, pos, size, rot)
	var radial: int = 8
	for i in range(radial):
		var ang: float = float(i) / float(radial) * TAU
		var dir := Vector3(0, cos(ang), sin(ang))
		b.call(dir * (r - 0.02), Vector3(0.035, 0.12, w), "tire", Vector3(ang, 0, 0))
		if i % 2 == 0:
			b.call(dir * (r + 0.05), Vector3(0.045, 0.07, w * 0.72), "tire", Vector3(ang, 0, 0))
	# Mâm vàng (2 vòng so le)
	var rim_r: float = r * 0.55
	var hub_r: float = r * 0.3
	for i in range(6):
		var ang: float = float(i) / 6.0 * TAU
		var dir := Vector3(0, cos(ang), sin(ang))
		b.call(dir * rim_r, Vector3(0.18, 0.09, w * 0.62), "cream", Vector3(ang, 0, 0))
		b.call(dir * hub_r, Vector3(0.2, 0.08, w * 0.5), "steel", Vector3(ang, 0, 0))
	# Trục sáng xuyên qua
	b.call(Vector3.ZERO, Vector3(w + 0.06, 0.07, 0.07), "iron_dark")
	_commit_meshes(root, sts, {
		"tire": _make_mat(Color(0.07, 0.07, 0.08)),
		"cream": _make_mat(Color(0.84, 0.78, 0.58)),
		"steel": _make_mat(Color(0.36, 0.37, 0.40)),
		"iron_dark": _make_mat(Color(0.14, 0.15, 0.17), {"metallic": 0.6, "roughness": 0.4}),
	})
	return root

func _build_mesh() -> void:
	var rig := Node3D.new()
	rig.name = "_Rig"
	rig.scale = Vector3.ONE
	add_child(rig)
	_rig = rig

	var mats := {
		"red": _make_mat(Color(0.70, 0.10, 0.08)),
		"red_dark": _make_mat(Color(0.46, 0.06, 0.05)),
		"red_light": _make_mat(Color(0.78, 0.18, 0.12)),
		"green": _make_mat(Color(0.22, 0.40, 0.21)),
		"green_dark": _make_mat(Color(0.15, 0.28, 0.15)),
		"steel": _make_mat(Color(0.30, 0.31, 0.34)),
		"steel_dark": _make_mat(Color(0.16, 0.17, 0.19)),
		"iron": _make_mat(Color(0.40, 0.27, 0.17)),
		"iron_dark": _make_mat(Color(0.13, 0.14, 0.16)),
		"rust": _make_mat(Color(0.42, 0.25, 0.14)),
		"black": _make_mat(Color(0.06, 0.06, 0.07)),
		"cream": _make_mat(Color(0.84, 0.78, 0.58)),
		"wood": _make_mat(Color(0.60, 0.40, 0.18)),
		"wood_dark": _make_mat(Color(0.44, 0.29, 0.13)),
		"wood_light": _make_mat(Color(0.70, 0.52, 0.30)),
		"glass": _make_mat(Color(0.62, 0.78, 0.88), {"transparent": true}),
		"smoke": _make_mat(Color(0.55, 0.55, 0.56), {"transparent": true}),
		"lamp": _make_mat(Color(1.00, 0.88, 0.50), {"emissive": true, "energy": 2.4}),
		"led_red": _make_mat(Color(0.95, 0.15, 0.12), {"emissive": true, "energy": 2.4}),
		"burlap": _make_mat(Color(0.66, 0.55, 0.40)),
		"burlap_d": _make_mat(Color(0.54, 0.42, 0.28)),
		"straw": _make_mat(Color(0.85, 0.73, 0.34)),
		"straw_d": _make_mat(Color(0.70, 0.58, 0.26)),
		"pump_orange": _make_mat(Color(0.88, 0.45, 0.10)),
		"pump_groove": _make_mat(Color(0.62, 0.28, 0.06)),
		"waterm": _make_mat(Color(0.16, 0.50, 0.20)),
		"waterm_d": _make_mat(Color(0.10, 0.33, 0.13)),
		"stem": _make_mat(Color(0.32, 0.42, 0.16)),
	}
	var sts: Dictionary = {}
	var b: Callable = func(pos: Vector3, size: Vector3, mat_id: String,
			rot: Vector3 = Vector3.ZERO) -> void:
		_add_v(sts, mat_id, pos, size, rot)

	# ═══ ĐẦU KÉO ══════════════════════════════════════════════════════════════
	# Khung đáy
	b.call(Vector3(0, 0.46, -0.2), Vector3(0.88, 0.2, 2.0), "steel_dark")
	b.call(Vector3(0, 0.58, -0.15), Vector3(0.8, 0.14, 1.6), "steel")
	# Cánh chắn bùn phía sau (bánh to)
	for s in [1.0, -1.0]:
		b.call(Vector3(0.62 * s, 0.72, 0.78), Vector3(0.16, 0.12, 0.95), "red_dark")
		b.call(Vector3(0.58 * s, 0.6, 0.78), Vector3(0.12, 0.05, 1.0), "steel_dark")
	# Khối thân giữa (buồng lái + hộp máy)
	b.call(Vector3(0, 0.7, 0.28), Vector3(0.86, 0.5, 1.05), "red_dark")
	b.call(Vector3(0, 0.84, 0.32), Vector3(0.8, 0.24, 0.75), "red")
	# Nắp capo phía trước (hood) — máy kéo đỏ
	b.call(Vector3(0, 0.78, -0.52), Vector3(0.78, 0.4, 0.72), "red_light")
	b.call(Vector3(0, 0.97, -0.52), Vector3(0.86, 0.1, 0.82), "red")
	b.call(Vector3(0, 0.68, -0.52), Vector3(0.66, 0.16, 0.72), "red_dark")
	# Lưới hẻm trước (grille) — dải thép dọc
	b.call(Vector3(0, 0.8, -0.92), Vector3(0.6, 0.42, 0.04), "steel_dark")
	for gz in [-0.93, -0.945]:
		for gx in [-0.22, -0.12, -0.02, 0.08, 0.18]:
			b.call(Vector3(gx, 0.8, gz), Vector3(0.03, 0.3, 0.03), "steel")
	# Đèn pha vàng (glow) 2 bên
	for s in [1.0, -1.0]:
		b.call(Vector3(0.34 * s, 0.86, -0.9), Vector3(0.18, 0.14, 0.06), "steel_dark")
		b.call(Vector3(0.34 * s, 0.86, -0.94), Vector3(0.14, 0.1, 0.05), "lamp")
		b.call(Vector3(0.34 * s, 0.86, -0.96), Vector3(0.12, 0.08, 0.03), "glass")
	# Đèn gầm vàng
	b.call(Vector3(0, 0.62, -0.32), Vector3(0.4, 0.06, 0.06), "lamp")
	# Mặt trước dứa + cản
	b.call(Vector3(0, 0.62, -0.92), Vector3(0.7, 0.2, 0.08), "steel")

	# ── Ca-bin hờ + lồng bảo vệ ──
	# Ghế da nâu (đệnh + tựa)
	b.call(Vector3(0, 0.98, 0.78), Vector3(0.52, 0.14, 0.3), "wood_light")
	b.call(Vector3(0, 1.1, 0.85), Vector3(0.48, 0.22, 0.28), "wood")
	b.call(Vector3(0, 1.02, 0.4), Vector3(0.5, 0.06, 0.32), "iron_dark")
	# Vô-lăng tròn + cột
	b.call(Vector3(0, 1.2, 0.16), Vector3(0.62, 0.03, 0.62), "steel", Vector3(0, 0.4, 0))
	b.call(Vector3(0, 1.2, 0.16), Vector3(0.62, 0.03, 0.62), "steel", Vector3(0.4, 0, 0))
	b.call(Vector3(0, 1.02, 0.44), Vector3(0.05, 0.36, 0.05), "steel_dark")
	b.call(Vector3(0, 1.16, 0.0), Vector3(0.1, 0.08, 0.05), "steel")
	# Định sĩ + cần số
	b.call(Vector3(0.32, 1.06, 0.7), Vector3(0.03, 0.4, 0.03), "steel")
	b.call(Vector3(0.34, 1.26, 0.68), Vector3(0.08, 0.04, 0.08), "iron")
	# Bảng đồng hồ mini
	b.call(Vector3(0.55, 1.22, 0.1), Vector3(0.01, 0.06, 0.14), "iron_dark")
	b.call(Vector3(0.55, 1.23, 0.08), Vector3(0.01, 0.03, 0.08), "lamp")
	# Lồng bảo vệ 4 cột + thanh trần
	for sx in [1.0, -1.0]:
		b.call(Vector3(0.52 * sx, 1.35, 0.02), Vector3(0.045, 0.9, 0.045), "steel")
		b.call(Vector3(0.52 * sx, 1.35, 1.02), Vector3(0.045, 0.9, 0.045), "steel")
	for sx in [1.0, -1.0]:
		b.call(Vector3(0.52 * sx, 1.8, 0.5), Vector3(0.045, 0.05, 1.08), "steel")
	b.call(Vector3(0, 1.8, 0.02), Vector3(1.12, 0.05, 0.05), "steel")
	b.call(Vector3(0, 1.8, 0.98), Vector3(1.12, 0.05, 0.05), "steel")
	# Lưng sau đóng kín (che máy)
	b.call(Vector3(0, 1.15, 1.06), Vector3(0.78, 0.6, 0.08), "red_dark")
	b.call(Vector3(0, 0.9, 1.06), Vector3(0.66, 0.44, 0.04), "red")

	# ── Bánh sau TO (2/3 thân) ──
	for s in [1.0, -1.0]:
		var w := _build_wheel(REAR_WHEEL_R, 0.3)
		w.position = Vector3(0.6 * s, REAR_AXLE_Y, REAR_AXLE_Z)
		rig.add_child(w)
		_wheels_tractor.append(w)

	# Bánh trước NHỎ (đặt trong pivot bẻ lái)
	_front_steer = Node3D.new()
	_front_steer.name = "_FrontSteer"
	rig.add_child(_front_steer)
	for s in [1.0, -1.0]:
		var w := _build_wheel(FRONT_WHEEL_R, 0.24)
		w.position = Vector3(0.5 * s, FRONT_AXLE_Y, FRONT_AXLE_Z)
		_front_steer.add_child(w)
		_wheels_tractor.append(w)

	# ── Ống xả + khói ──
	b.call(Vector3(0.5, 0.9, 0.85), Vector3(0.06, 0.85, 0.06), "iron_dark")
	b.call(Vector3(0.5, 1.32, 0.85), Vector3(0.1, 0.08, 0.1), "steel_dark")
	b.call(Vector3(0.5, 1.42, 0.85), Vector3(0.13, 0.08, 0.13), "smoke")

	# ── Đuôi: thanh kéo + móc khớp nối ──
	b.call(Vector3(0, 0.5, 1.1), Vector3(0.32, 0.1, 0.16), "iron")
	b.call(Vector3(0, 0.66, 1.12), Vector3(0.09, 0.34, 0.09), "iron_dark")
	b.call(Vector3(0, 0.74, 1.14), Vector3(0.12, 0.12, 0.12), "iron")
	b.call(Vector3(0, 0.66, 1.2), Vector3(0.05, 0.24, 0.05), "rust")
	b.call(Vector3(0, 0.86, 1.06), Vector3(0.05, 0.08, 0.05), "led_red")

	# ═══ RƠ-MOỌC (con của _trailer_pivot — khớp xoay tại HITCH_Z) ═════════
	_trailer_pivot = Node3D.new()
	_trailer_pivot.name = "_TrailerPivot"
	_trailer_pivot.position = Vector3(0, 0.0, HITCH_Z)
	rig.add_child(_trailer_pivot)

	_build_trailer(sts, mats, b)

	_commit_meshes(rig, sts, mats)
	_lamp_mat = mats["lamp"] as StandardMaterial3D

## Thùng gỗ + hàng hoá: xây dựng trong toạ độ của _trailer_pivot (+Z phía sau).
## Mesh riêng gắn vào pivot để khớp xoay quay toàn bộ rơ-moọc.
func _build_trailer(sts_ignored: Dictionary, mats: Dictionary, b_ignored: Callable) -> void:
	var t_sts: Dictionary = {}
	var b: Callable = func(pos: Vector3, size: Vector3, mat_id: String,
			rot: Vector3 = Vector3.ZERO) -> void:
		_add_v(t_sts, mat_id, pos, size, rot)
	var L: float = TRAILER_BED_LEN
	var W: float = TRAILER_BED_WID
	var tz := 0.15   # lệch để trước xe không trùm lên máy kéo

	# Xe con lăn kéo: khung nối
	b.call(Vector3(0, 0.28, 0.55 + tz), Vector3(0.32, 0.12, 0.5), "iron")
	# Dầm xương sống kéo xuống bed
	b.call(Vector3(0, 0.5, 0.72 + tz), Vector3(0.1, 0.28, 0.6), "steel_dark")
	# Sàn ván gỗ
	b.call(Vector3(0, 0.44, 1.5 + tz), Vector3(W, 0.08, L), "wood")
	b.call(Vector3(0, 0.42, 0.5 + tz), Vector3(0.5, 0.06, 0.5), "wood")
	# Khay đỡ sàn
	for sx in [1.0, -1.0]:
		b.call(Vector3(0.44 * sx, 0.32, 1.5 + tz), Vector3(0.08, 0.25, L - 0.2), "steel_dark")
	# Vách trước thùng
	b.call(Vector3(0, 0.8, 0.42 + tz), Vector3(W, 0.62, 0.06), "wood_dark")
	b.call(Vector3(0, 1.06, 0.42 + tz), Vector3(W, 0.14, 0.07), "steel")
	# Hai bên thành: tấm gỗ + thanh
	for sx in [1.0, -1.0]:
		b.call(Vector3((W * 0.5 + 0.02) * sx, 0.86, 1.45 + tz), Vector3(0.06, 0.7, L - 0.4), "wood")
		b.call(Vector3((W * 0.5 + 0.03) * sx, 1.12, 1.45 + tz), Vector3(0.07, 0.12, L - 0.4), "steel")
		b.call(Vector3((W * 0.5 + 0.0) * sx, 0.32, 1.45 + tz), Vector3(0.1, 0.1, L - 0.4), "rust")
	# Cọc bên ngoài
	for sx in [1.0, -1.0]:
		for pz in [0.6, 1.45, 2.3]:
			b.call(Vector3((W * 0.5 + 0.08) * sx, 0.8, pz + tz), Vector3(0.05, 0.9, 0.05), "wood_dark")
	# Thành sau bản lề — đã hạ xuống (3 ván nằm chéo phía sau đuôi)
	b.call(Vector3(0, 0.22, 2.6 + tz), Vector3(W + 0.14, 0.05, 0.34), "wood", Vector3(-0.22, 0, 0))
	b.call(Vector3(0, 0.16, 2.72 + tz), Vector3(W + 0.12, 0.05, 0.3), "wood", Vector3(-0.18, 0, 0))
	b.call(Vector3(0, 0.1, 2.84 + tz), Vector3(W + 0.1, 0.05, 0.28), "wood", Vector3(-0.12, 0, 0))
	# Bánh rơ-moọc (2 bánh to)
	for s in [1.0, -1.0]:
		var w := _build_wheel(TRAILER_WHEEL_R, 0.26)
		w.position = Vector3(0.54 * s, 0.36, 1.28 + tz)
		_trailer_pivot.add_child(w)
		_wheels_trailer.append(w)

	# ═══ HÀNG HOÁ trên thùng ═════════════════════════════════════════════════
	_build_cargo(t_sts, mats, b, 1.5 + tz)
	_commit_meshes(_trailer_pivot, t_sts, mats)

func _build_cargo(sts: Dictionary, mats: Dictionary, b: Callable, cz: float) -> void:
	var fy: float = TRAILER_FLOOR_Y + 0.06
	# 2 trái bí đỏ (cam cháy, múi rãnh)
	for c in [Vector3(-0.24, fy, cz - 0.55), Vector3(0.3, fy, cz + 0.05)]:
		b.call(c, Vector3(0.34, 0.34, 0.34), "pump_orange")
		b.call(c + Vector3(0, 0.2, 0), Vector3(0.28, 0.1, 0.3), "pump_orange")
		b.call(c + Vector3(0.17, 0.0, 0.0), Vector3(0.06, 0.32, 0.34), "pump_groove")
		b.call(c + Vector3(-0.17, 0.0, 0.0), Vector3(0.06, 0.32, 0.34), "pump_groove")
		b.call(c + Vector3(0.0, 0.0, 0.18), Vector3(0.34, 0.3, 0.06), "pump_groove")
		b.call(c + Vector3(0.0, 0.0, -0.18), Vector3(0.34, 0.3, 0.06), "pump_groove")
		b.call(c + Vector3(0.0, 0.24, 0.0), Vector3(0.1, 0.12, 0.1), "stem")
	# 1 quả dưa hấu cầu + vằn đen (vặn nằm ngang cạnh bí)
	var wm := Vector3(-0.05, fy + 0.18, cz + 0.5)
	b.call(wm, Vector3(0.38, 0.38, 0.38), "waterm")
	b.call(wm + Vector3(0, 0.2, 0), Vector3(0.32, 0.14, 0.32), "waterm")
	b.call(wm + Vector3(0.16, 0.0, 0.0), Vector3(0.08, 0.36, 0.36), "waterm_d")
	b.call(wm + Vector3(-0.16, 0.0, 0.0), Vector3(0.08, 0.36, 0.36), "waterm_d")
	b.call(wm + Vector3(0.0, 0.0, 0.18), Vector3(0.38, 0.34, 0.08), "waterm_d")
	b.call(wm + Vector3(0.0, 0.24, 0.0), Vector3(0.1, 0.08, 0.1), "stem")
	# 2 bao tải đay hạt giống (dựng/ap)
	for sck in [Vector3(-0.3, fy + 0.2, cz + 0.62), Vector3(0.02, fy + 0.18, cz + 0.8)]:
		b.call(sck, Vector3(0.34, 0.4, 0.2), "burlap")
		b.call(sck + Vector3(0, 0.22, 0), Vector3(0.3, 0.1, 0.18), "burlap_d")
		b.call(sck + Vector3(0, 0.32, 0), Vector3(0.2, 0.08, 0.12), "burlap")
		b.call(sck + Vector3(0, 0.26, 0.0), Vector3(0.18, 0.05, 0.03), "stem")
	# Rơm vàng rơi vãi trên nền (vài cụm nhỏ)
	for rn in [Vector3(-0.08, fy + 0.06, cz - 0.5), Vector3(0.1, fy + 0.08, cz + 0.35),
			Vector3(-0.32, fy + 0.05, cz + 0.15), Vector3(0.2, fy + 0.06, cz + 0.68)]:
		b.call(rn, Vector3(0.18, 0.06, 0.18), "straw")
		b.call(rn + Vector3(0.05, 0.02, -0.05), Vector3(0.1, 0.05, 0.1), "straw_d")
		b.call(rn + Vector3(-0.06, 0.0, 0.03), Vector3(0.08, 0.03, 0.08), "straw")

# ── Đèn pha ───────────────────────────────────────────────────────────────────
func _build_lights() -> void:
	if _rig == null:
		return
	for s in [1.0, -1.0]:
		var spot := SpotLight3D.new()
		spot.light_energy = 0.0
		spot.light_color = Color(1.0, 0.92, 0.75)
		spot.spot_range = 9.0
		spot.spot_angle = 25.0
		spot.spot_attenuation = 1.2
		spot.shadow_enabled = false
		spot.position = Vector3(0.34 * s, 0.86, -0.98)
		_rig.add_child(spot)
		_spotlights.append(spot)

# ── Khói ống xả ───────────────────────────────────────────────────────────────
func _build_smoke() -> void:
	if _rig == null:
		return
	var p := CPUParticles3D.new()
	p.name = "_ExhaustSmoke"
	p.amount = 26
	p.lifetime = 1.8
	p.one_shot = false
	p.emitting = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 14.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.8
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 10
	sph.rings = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	sph.material = m
	p.mesh = sph
	p.scale_amount_min = 0.16
	p.scale_amount_max = 0.3
	var grow := Curve.new()
	grow.add_point(Vector2(0, 1.0))
	grow.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.95, 0.95, 0.55))
	ramp.set_color(0.6, Color(0.90, 0.90, 0.90, 0.24))
	ramp.set_color(1, Color(0.88, 0.88, 0.88, 0.0))
	p.color_ramp = ramp
	p.position = Vector3(0.5, 1.5, 0.85)
	_rig.add_child(p)
	_smoke = p

# ── Cập nhật đèn theo đêm/mưa ─────────────────────────────────────────────────
func _update_lights(delta: float) -> void:
	_light_timer += delta
	if _light_timer < LIGHT_UPDATE_INTERVAL:
		return
	_light_timer = 0.0
	var t := _light_factor(TimeSystem.get_hour() if TimeSystem else 12.0)
	if absf(t - _last_light_t) < 0.003:
		return
	_last_light_t = t
	var spd: float = LIGHT_UPDATE_INTERVAL * 0.8
	for l in _spotlights:
		if is_instance_valid(l):
			l.light_energy = lerp(l.light_energy, t * LIGHT_MAX_ENERGY, spd)
	if _lamp_mat:
		var cur: float = _lamp_mat.emission_energy_multiplier
		_lamp_mat.emission_energy_multiplier = lerp(cur, t * 2.2, spd)

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

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 1.35, 2.1)
	col.shape = box
	col.position = Vector3(0, 0.75, -0.05)
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