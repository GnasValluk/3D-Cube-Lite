## fishing_boat.gd — Thuyền đánh cá + cơ chế lái thuyền.
## Vật lý nước thực tế: lực nổi (spring-damper quanh mực nước + sóng),
## lực cản nước (drag tuyến tính + bậc 2), sức cản thân tàu ngang,
## lái bằng bánh lái (tốc độ quay tỷ lệ với tốc độ tiến — đứng im không quay),
## lắc ngang/dọc theo mặt nước, mắc cạn thì không đi nổi, có thể chèo ra khỏi bãi.
extends CharacterBody3D
class_name FishingBoat

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")

# ── Kích thước thân ──────────────────────────────────────────────────────────
const HULL_LEN: float = 3.4
const HULL_WID: float = 1.4
const HULL_BOTTOM: float = -0.45   # đáy thuyền (so với origin)
const HULL_DEP: float = 0.95       # độ cao thân
const MODEL_SCALE: float = 1.35    # model đồ họa lớn hơn physics cho vừa dáng người
const FLOAT_OFFSET: float = -0.02  # origin nằm dưới mặt nước bao nhiêu khi nổi

# ── Vật lý (đơn vị: m, s) ────────────────────────────────────────────────────
const GRAVITY: float = 26.0
const BUOY_STIFF: float = 24.0     # độ cứng lực nổi (nổi cao hơn, đỡ lún khi có tài xế)
const BUOY_DAMP: float = 4.8       # giảm chấn nước (hệ số ζ ≈ 0.49 — bồng bềnh nhẹ)
const THRUST_ACCEL: float = 7.0    # gia tốc tối đa khi chèo tới (m/s²)
const REVERSE_ACCEL: float = 3.0   # chèo lùi
const LINEAR_DRAG: float = 0.25    # cản nhớt tuyến tính (1/s)
const QUAD_DRAG: float = 0.10      # cản bậc 2 theo tốc độ (1/m)
const LATERAL_DRAG: float = 1.8    # thân tàu chống trượt ngang
const STEER_RATE: float = 1.35     # rad/s ở tốc độ tối đa
const STEER_SPEED_BAND: float = 3.0  # tốc độ để quay hết lái
const GROUND_FRICTION: float = 7.0   # ma sát khi mắc cạn
const CURRENT_GAIN: float = 1.2      # dòng chảy theo độ dốc mặt nước
const CURRENT_MAX: float = 0.9

const DRIVER_SEAT := Vector3(0, 0.42, 0.30)   # chân tài xế đứng sát sàn (sàn scaled ≈ 0.32)
const BOARD_RANGE: float = 3.2

# ── Đèn thuyền: tự sáng khi đêm hoặc mưa, tắt khi trời sáng ──────────────────
const LIGHT_MAX_ENERGY: float = 2.6
const LIGHT_UPDATE_INTERVAL: float = 0.12
const DUSK_START: float = 17.0
const DUSK_END: float = 19.0
const DAWN_START: float = 5.0
const DAWN_END: float = 7.0

var _driver: Node3D = null
var _time: float = 0.0
var _prev_fwd_speed: float = 0.0
var _tilt_pitch: float = 0.0
var _tilt_roll: float = 0.0
var _last_chunk: Node = null
var _last_cx: int = 99999
var _last_cz: int = 99999

# ── Phá huỷ: thuyền có máu như cây, đòn heavy phá được, rớt lại vật phẩm ─────
var max_hp: int = 120
var hp: int
var weapon_requirement: int = DestructibleEntity.WeaponReq.HEAVY
var drop_item_id: String = "fishing_boat"
var _destroyed: bool = false

# ── Model: rig + đèn + khói ống xả + bọt/té nước chân vịt ───────────────────
var _rig: Node3D = null
var _boat_lights: Array[Light3D] = []
var _lamp_mat: StandardMaterial3D = null
var _bubbles: CPUParticles3D = null
var _splash: CPUParticles3D = null
var _smoke: CPUParticles3D = null
var _light_timer: float = 0.0
var _last_light_t: float = -1.0
var _fx_timer: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("destroyable_props")
	_build_mesh()
	_build_lights()
	_build_bubbles()
	_build_smoke()
	_build_collision()

# ── Tương tác ────────────────────────────────────────────────────────────────
func is_player_nearby(player: Node3D) -> bool:
	if _driver != null:
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
	player.set_meta("driving_boat", self)
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
		player.remove_meta("driving_boat")
	_disable_driver_collision(player, false)
	if player == null or not is_instance_valid(player):
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
	var fwd := -global_transform.basis.z
	var rt := global_transform.basis.x
	var candidates: Array[Vector3] = [
		base + rt * (HULL_WID * 0.5 + 0.9),
		base - rt * (HULL_WID * 0.5 + 0.9),
		base + fwd * (HULL_LEN * 0.5 + 0.8),
		base - fwd * (HULL_LEN * 0.5 + 0.8),
	]
	for c in candidates:
		var h := _ground_height_at(c.x, c.z)
		if h > -900.0:
			return Vector3(c.x, h, c.z)
	return base + rt * (HULL_WID * 0.5 + 1.0)

## Mặt đứng vững: mặt đất (khô) hoặc mặt nước.
func _ground_height_at(wx: float, wz: float) -> float:
	var surf := _water_surface_at(wx, wz)
	if surf > -900.0:
		return surf
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

# ── Tìm mực nước thế giới ────────────────────────────────────────────────────
## Mực nước (top block nước cao nhất) tại (wx, wz). < -900 = không có nước.
func _water_surface_at(wx: float, wz: float) -> float:
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
		if _Data.is_water(bid):
			var top: float = _BlockData.layer_to_world_y(layer) + _BlockData.SLAB_HEIGHT * 0.5
			var lvl: int = _Data.water_level(bid)
			return top - (8 - lvl) * 0.0625
	return -999.0

## Chunk chứa tọa độ world (cache theo chunk key để không phải quét lại mỗi frame).
## Quy ước world: chunk (cx,cz) nằm tại global (cx*32, cz*32), phủ [-16, +16) quanh đó
## (khớp OpenWorldManager.get_chunk_at / is_water_at).
func _chunk_at(wx: float, wz: float) -> Node:
	var half: float = 32.0 * 0.5
	var cx: int = int(floor((wx + half) / 32.0))
	var cz: int = int(floor((wz + half) / 32.0))
	if cx == _last_cx and cz == _last_cz and _last_chunk != null and is_instance_valid(_last_chunk):
		return _last_chunk
	_last_chunk = null
	_last_cx = cx
	_last_cz = cz
	var root := get_tree().current_scene if get_tree() != null else null
	if root == null:
		return null
	var found := _find_chunk_recursive(root, cx, cz)
	if found == null:
		return null
	_last_chunk = found
	return found

func _find_chunk_recursive(node: Node, cx: int, cz: int) -> Node:
	if node is WorldChunk and "_cx" in node and node._cx == cx and node._cz == cz:
		return node
	for ch in node.get_children():
		var r := _find_chunk_recursive(ch, cx, cz)
		if r != null:
			return r
	return null

# ── Vật lý ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_time += delta

	# Tài xế chết/biến mất → tự xuống
	if _driver != null and (not is_instance_valid(_driver) or not _driver.is_inside_tree() \
			or (_driver.get("is_alive") != null and not bool(_driver.get("is_alive")))):
		_driver.remove_meta("driving_boat")
		_driver = null

	var cx := global_position
	var fwd := -global_transform.basis.z
	var rt := global_transform.basis.x
	fwd.y = 0.0; fwd = fwd.normalized()
	rt.y = 0.0; rt = rt.normalized()

	# ── Mực nước + sóng tại mũi/đuôi/trái/phải ──
	var surf_c := _water_surface_at(cx.x, cx.z)
	var surf_f := _water_surface_at(cx.x + fwd.x * 1.2, cx.z + fwd.z * 1.2)
	var surf_b := _water_surface_at(cx.x - fwd.x * 1.2, cx.z - fwd.z * 1.2)
	var surf_r := _water_surface_at(cx.x + rt.x * 0.8, cx.z + rt.z * 0.8)
	var surf_l := _water_surface_at(cx.x - rt.x * 0.8, cx.z - rt.z * 0.8)

	var wave := sin(_time * 1.5 + cx.x * 0.35 + cx.z * 0.22) * 0.045 \
		+ sin(_time * 2.1 - cx.x * 0.28 + cx.z * 0.19 + 1.3) * 0.030
	var in_water: bool = surf_c > -900.0

	# ── Lực nổi (spring-damper quanh mực nước + sóng) ──
	if in_water:
		var target_y: float = surf_c + wave + FLOAT_OFFSET
		var err := target_y - global_position.y
		velocity.y += (err * BUOY_STIFF - velocity.y * BUOY_DAMP) * delta
		velocity.y = clampf(velocity.y, -4.0, 4.0)
	else:
		velocity.y -= GRAVITY * delta

	# ── Độ nổi của đáy thuyền (0 = mắc cạn, 1 = nổi hẳn) ──
	var float_frac: float = 0.0
	if in_water:
		float_frac = clampf((surf_c + wave - (global_position.y + HULL_BOTTOM)) / 0.4, 0.0, 1.0)
	else:
		float_frac = 0.0

	# ── Lái: chỉ khi có tài xế (W/S = chèo, A/D = bẻ lái) ──
	var throttle := 0.0
	var rudder := 0.0
	if is_driven() and _driver.get("_is_player") == true:
		if Input.is_action_pressed("move_forward"):
			throttle = 1.0
		elif Input.is_action_pressed("move_back"):
			throttle = -0.5
		if Input.is_action_pressed("move_left"):
			rudder = 1.0
		elif Input.is_action_pressed("move_right"):
			rudder = -1.0

	var vh := Vector3(velocity.x, 0.0, velocity.z)
	var fwd_v := vh.dot(fwd)
	var lat_v := vh - fwd * fwd_v

	# ── Lực cản nước: nhớt + bậc 2 + cản thân ngang ──
	var speed := vh.length()
	var drag := -vh * (LINEAR_DRAG + QUAD_DRAG * speed) - lat_v * LATERAL_DRAG
	velocity.x += drag.x * delta
	velocity.z += drag.z * delta

	# ── Hiệu ứng: khói ống xả + bọt/té nước chân vịt ─────────────────────────
	# (không đổi amount runtime — đổi amount làm CPUParticles reset, phun giật)
	_fx_timer -= delta
	if _fx_timer <= 0.0:
		_fx_timer = 0.2
		if _smoke:
			_smoke.emitting = is_driven()
		if _bubbles:
			_bubbles.emitting = in_water and speed > 0.35
		if _splash:
			_splash.emitting = in_water and speed > 0.8

	# ── Chèo ──
	if throttle != 0.0 and float_frac > 0.02:
		var accel: float = THRUST_ACCEL if throttle > 0.0 else REVERSE_ACCEL
		velocity += fwd * (accel * throttle) * delta

	# ── Dòng chảy: chảy xuôi theo độ dốc mặt nước ──
	if in_water:
		var gx: float = surf_r - surf_l
		var gz: float = surf_f - surf_b
		if gx * gx + gz * gz > 0.000001:
			var grad := Vector3(gx * 0.5, 0.0, gz * 0.5)
			var cur := -grad * CURRENT_GAIN
			if cur.length() > CURRENT_MAX:
				cur = cur.normalized() * CURRENT_MAX
			velocity.x += cur.x * delta
			velocity.z += cur.z * delta

	# ── Quay bánh lái: tỷ lệ với tốc độ tiến (đứng im không quay) ──
	var steer_speed := clampf(absf(fwd_v) / STEER_SPEED_BAND, 0.0, 1.0)
	if rudder != 0.0 and steer_speed > 0.01:
		var steer: float = rudder * (1.0 if fwd_v >= 0.0 else -1.0)
		rotation.y += steer * STEER_RATE * steer_speed * delta

	# ── Ma sát khi mắc cạn ──
	var grounded := is_on_floor()
	if grounded and float_frac < 0.25:
		var f: float = GROUND_FRICTION * (1.0 - float_frac)
		velocity.x = move_toward(velocity.x, 0.0, f * delta)
		velocity.z = move_toward(velocity.z, 0.0, f * delta)

	# ── Tàu xuyên qua cá (bỏ va chạm; cá vẫn né theo khoảng cách) ──
	for f in get_tree().get_nodes_in_group("fish"):
		if f is PhysicsBody3D:
			add_collision_exception_with(f)

	move_and_slide()

	# ── Nghiêng thân theo gia tốc + lái + độ dốc sóng (chỉ hình ảnh) ──
	var accel_fwd: float = (fwd_v - _prev_fwd_speed) / maxf(delta, 0.001)
	_prev_fwd_speed = fwd_v
	var pitch_tgt: float = clampf(-accel_fwd * 0.012, -0.09, 0.09)
	var roll_tgt: float = clampf(rudder * steer_speed * 0.055, -0.11, 0.11)
	if in_water:
		pitch_tgt += (surf_f - surf_b) * 0.06
		roll_tgt += (surf_r - surf_l) * 0.06
	_tilt_pitch = lerp_angle(_tilt_pitch, pitch_tgt, delta * 3.0)
	_tilt_roll = lerp_angle(_tilt_roll, roll_tgt, delta * 3.0)

	# ── Đồng bộ tài xế ──
	if is_driven():
		_sync_driver()

func _sync_driver() -> void:
	if _driver == null:
		return
	_driver.global_position = global_transform * DRIVER_SEAT
	# Mặt người chơi hướng +Z — quay 180° để nhìn về phía mũi thuyền (-Z)
	_driver.rotation.y = rotation.y + PI
	if _driver is CharacterBody3D:
		_driver.velocity = Vector3.ZERO

func _process(delta: float) -> void:
	# Lắc nghiêng hình ảnh (thân thuyền) — vẽ trong _physics_process qua biến
	if _rig:
		_rig.rotation.x = _tilt_pitch
		_rig.rotation.z = _tilt_roll
	_update_lights(delta)

# ── Hình ảnh: thuyền đánh cá vỏ gỗ Việt Nam (voxel HD, vật liệu shaded) ──────
## Model chi tiết: mũi nhọn nhô cao + mắt ghe + cọc neo, vỏ 2 tông (xanh ngọc
## trên mấn nước, đỏ gạch chìm dưới nước kèm rêu/hàu), ván ghép có đinh tán,
## sơn tróc, ca-bin vàng kem 4 cửa kính, anten + cờ Tổ quốc + phao cứu sinh,
## bánh lái + radio bên trong, dàn đèn dụ cá 2 bên, lưới + phao + tời + thùng
## cá đá, ống xả khói, chân vịt đồng + bánh lái đỏ, can dầu/xô/đèn bão.
## Toàn bộ box được gộp vào ArrayMesh theo từng material (giảm draw call).

func _make_mat(color: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = opts.get("metallic", 0.0)
	m.roughness = opts.get("roughness", 0.85)
	# Màu theo đỉnh: mỗi mặt box tô đậm/nhạt riêng → nhìn như khối voxel thật
	m.vertex_color_use_as_albedo = true
	if opts.get("emissive", false):
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = opts.get("energy", 1.8)
	if opts.get("transparent", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## Gộp 1 hộp (6 mặt) vào SurfaceTool theo material id — sau đó commit 1 mesh/material.
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
	# Sắc thái nhẹ theo vị trí — mỗi khối hơi khác nhau như voxel thật
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
		# Đổ bóng theo hướng mặt như terrain: đỉnh sáng, cạnh tối, đáy tối nhất
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

func _build_mesh() -> void:
	var rig := Node3D.new()
	rig.name = "_Rig"
	rig.scale = Vector3.ONE * MODEL_SCALE
	add_child(rig)
	_rig = rig

	var mats := {
		"wood": _make_mat(Color(0.46, 0.30, 0.15)),
		"wood_dark": _make_mat(Color(0.33, 0.20, 0.09)),
		"wood_med": _make_mat(Color(0.41, 0.27, 0.13)),
		"wood_light": _make_mat(Color(0.58, 0.42, 0.24)),
		"hull": _make_mat(Color(0.20, 0.52, 0.66)),
		"hull_dark": _make_mat(Color(0.12, 0.34, 0.47)),
		"hull_patch": _make_mat(Color(0.44, 0.30, 0.16)),
		"navy": _make_mat(Color(0.10, 0.17, 0.35)),
		"red_under": _make_mat(Color(0.55, 0.16, 0.13)),
		"red_dark": _make_mat(Color(0.42, 0.12, 0.10)),
		"moss": _make_mat(Color(0.38, 0.50, 0.22)),
		"barnacle": _make_mat(Color(0.82, 0.84, 0.86)),
		"trim_red": _make_mat(Color(0.80, 0.12, 0.10)),
		"trim_white": _make_mat(Color(0.93, 0.93, 0.90)),
		"rope": _make_mat(Color(0.66, 0.52, 0.34)),
		"iron": _make_mat(Color(0.26, 0.27, 0.30)),
		"iron_dark": _make_mat(Color(0.15, 0.16, 0.18)),
		"rust": _make_mat(Color(0.46, 0.28, 0.17)),
		"black": _make_mat(Color(0.07, 0.07, 0.08)),
		"white": _make_mat(Color(0.96, 0.96, 0.95)),
		"eye_white": _make_mat(Color(0.96, 0.94, 0.84)),
		"cream": _make_mat(Color(0.85, 0.79, 0.60)),
		"orange": _make_mat(Color(0.92, 0.46, 0.12)),
		"green": _make_mat(Color(0.25, 0.55, 0.30)),
		"net": _make_mat(Color(0.15, 0.33, 0.20)),
		"net_dark": _make_mat(Color(0.09, 0.24, 0.15)),
		"yellow": _make_mat(Color(0.92, 0.78, 0.20)),
		"flag_red": _make_mat(Color(0.85, 0.10, 0.10)),
		"flag_yellow": _make_mat(Color(0.97, 0.78, 0.10)),
		"glass": _make_mat(Color(0.62, 0.78, 0.88), {"transparent": true}),
		"smoke": _make_mat(Color(0.55, 0.55, 0.56), {"transparent": true}),
		"ice": _make_mat(Color(0.88, 0.93, 0.97), {"transparent": true}),
		"lamp": _make_mat(Color(1.00, 0.85, 0.42), {"emissive": true, "energy": 2.2}),
		"led_red": _make_mat(Color(0.95, 0.15, 0.12), {"emissive": true, "energy": 2.5}),
		"led_green": _make_mat(Color(0.15, 0.85, 0.30), {"emissive": true, "energy": 2.5}),
		"brass": _make_mat(Color(0.82, 0.66, 0.28), {"metallic": 1.0, "roughness": 0.3}),
		"fish": _make_mat(Color(0.68, 0.72, 0.78), {"metallic": 0.85, "roughness": 0.35}),
	}
	var sts: Dictionary = {}
	var b: Callable = func(pos: Vector3, size: Vector3, mat_id: String,
			rot: Vector3 = Vector3.ZERO) -> void:
		_add_v(sts, mat_id, pos, size, rot)

	# ── Vỏ thuyền: dưới mấn nước đỏ gạch, trên xanh ngọc ────────────────────
	b.call(Vector3(0, -0.28, 0), Vector3(1.5, 0.5, 2.45), "red_under")
	b.call(Vector3(0, -0.26, -1.38), Vector3(1.2, 0.44, 0.85), "red_under")
	b.call(Vector3(0, -0.24, 1.32), Vector3(1.05, 0.4, 0.8), "red_under")
	b.call(Vector3(0, 0.05, 0), Vector3(1.42, 0.2, 2.35), "hull")
	b.call(Vector3(0, -0.02, -1.38), Vector3(1.15, 0.22, 0.8), "hull")
	b.call(Vector3(0, 0.0, 1.32), Vector3(1.0, 0.2, 0.75), "hull")
	b.call(Vector3(0, 0.0, -1.8), Vector3(0.75, 0.28, 0.35), "hull")
	b.call(Vector3(0, 0.05, 1.74), Vector3(0.6, 0.3, 0.35), "hull")
	b.call(Vector3(0, -0.47, 0), Vector3(0.14, 0.06, 2.5), "trim_red")
	# Đường mấn nước + đường ván ghép thụt-nhô
	b.call(Vector3(0, -0.035, 0), Vector3(1.5, 0.04, 2.45), "trim_white")
	b.call(Vector3(0, 0.08, 0), Vector3(1.46, 0.02, 2.4), "hull_dark")
	b.call(Vector3(0, -0.12, 0), Vector3(1.52, 0.02, 2.46), "red_dark")
	# Đinh tán kim loại trên đường ván
	for rz in [-0.9, -0.3, 0.4, 1.0]:
		b.call(Vector3(0.735, 0.08, rz), Vector3(0.02, 0.02, 0.02), "iron")
		b.call(Vector3(-0.735, 0.08, rz), Vector3(0.02, 0.02, 0.02), "iron")
	# Viền mạn (đỏ + trắng trong) + viền mũi/đuôi
	b.call(Vector3(0, 0.17, 0), Vector3(1.48, 0.06, 2.5), "trim_red")
	b.call(Vector3(0, 0.19, 0), Vector3(1.42, 0.02, 2.42), "trim_white")
	b.call(Vector3(0, 0.13, -1.45), Vector3(1.15, 0.06, 0.6), "trim_red")
	b.call(Vector3(0, 0.14, 1.4), Vector3(1.0, 0.06, 0.55), "trim_red")
	# Sơn tróc + vệt ố màu trên vỏ
	b.call(Vector3(0.72, 0.02, -0.4), Vector3(0.1, 0.14, 0.2), "hull_patch")
	b.call(Vector3(-0.72, 0.05, 0.6), Vector3(0.09, 0.12, 0.18), "hull_patch")
	b.call(Vector3(0.72, -0.02, 0.9), Vector3(0.08, 0.1, 0.22), "navy")
	b.call(Vector3(-0.73, 0.0, -0.7), Vector3(0.08, 0.11, 0.16), "navy")
	b.call(Vector3(0.71, -0.04, 0.3), Vector3(0.07, 0.09, 0.12), "hull_patch")
	b.call(Vector3(-0.72, 0.08, 0.0), Vector3(0.09, 0.1, 0.14), "hull_patch")
	# Rêu + hàu bám phần chìm
	b.call(Vector3(0.77, -0.28, 0.55), Vector3(0.1, 0.06, 0.16), "moss")
	b.call(Vector3(-0.77, -0.32, -0.7), Vector3(0.12, 0.06, 0.13), "moss")
	b.call(Vector3(0.76, -0.35, -0.9), Vector3(0.09, 0.05, 0.12), "moss")
	b.call(Vector3(-0.76, -0.25, 1.0), Vector3(0.11, 0.06, 0.14), "moss")
	for bc in [Vector3(0.78, -0.2, 0.2), Vector3(-0.78, -0.18, -0.2),
			Vector3(0.77, -0.24, -0.4), Vector3(-0.77, -0.28, 0.7),
			Vector3(0.76, -0.3, 1.2), Vector3(-0.75, -0.35, -1.0)]:
		b.call(bc, Vector3(0.04, 0.03, 0.03), "barnacle")

	# ── Mũi: mắt ghe + cọc neo + dây thừng + neo treo ───────────────────────
	b.call(Vector3(0.585, -0.06, -1.28), Vector3(0.15, 0.17, 0.04), "trim_red")
	b.call(Vector3(-0.585, -0.06, -1.28), Vector3(0.15, 0.17, 0.04), "trim_red")
	b.call(Vector3(0.585, -0.06, -1.25), Vector3(0.09, 0.11, 0.04), "eye_white")
	b.call(Vector3(-0.585, -0.06, -1.25), Vector3(0.09, 0.11, 0.04), "eye_white")
	b.call(Vector3(0.6, -0.045, -1.235), Vector3(0.04, 0.06, 0.04), "black")
	b.call(Vector3(-0.57, -0.045, -1.235), Vector3(0.04, 0.06, 0.04), "black")
	b.call(Vector3(0.4, 0.14, -1.55), Vector3(0.07, 0.3, 0.07), "wood_dark")
	b.call(Vector3(-0.4, 0.14, -1.55), Vector3(0.07, 0.3, 0.07), "wood_dark")
	b.call(Vector3(0, 0.1, -1.38), Vector3(0.34, 0.05, 0.34), "rope")
	b.call(Vector3(0, 0.15, -1.38), Vector3(0.34, 0.04, 0.34), "rope", Vector3(0, 0.4, 0))
	b.call(Vector3(0, 0.19, -1.38), Vector3(0.3, 0.04, 0.3), "rope", Vector3(0, 0.2, 0))
	b.call(Vector3(0, 0.22, -1.38), Vector3(0.14, 0.02, 0.14), "rope")
	b.call(Vector3(0.9, 0.1, -0.95), Vector3(0.03, 0.14, 0.03), "iron_dark")
	b.call(Vector3(0.9, -0.02, -0.95), Vector3(0.03, 0.14, 0.03), "iron_dark")
	b.call(Vector3(0.9, -0.16, -0.95), Vector3(0.05, 0.16, 0.05), "iron")
	b.call(Vector3(0.9, -0.02, -0.95), Vector3(0.1, 0.1, 0.04), "iron_dark")
	b.call(Vector3(0.9, -0.25, -0.95), Vector3(0.3, 0.05, 0.05), "iron")
	b.call(Vector3(0.9, -0.28, -0.95), Vector3(0.06, 0.06, 0.05), "iron")
	b.call(Vector3(0.9, -0.28, -0.9), Vector3(0.06, 0.06, 0.05), "iron")

	# ── Sàn ván + ghế + lan can ─────────────────────────────────────────────
	b.call(Vector3(0, 0.21, 0.1), Vector3(1.26, 0.06, 2.35), "wood_med")
	b.call(Vector3(0, 0.21, -1.5), Vector3(0.7, 0.05, 0.55), "wood_med")
	b.call(Vector3(0, 0.21, 1.5), Vector3(0.6, 0.05, 0.5), "wood_med")
	b.call(Vector3(0.42, 0.245, 0.1), Vector3(0.02, 0.01, 2.3), "wood_dark")
	b.call(Vector3(-0.42, 0.245, 0.1), Vector3(0.02, 0.01, 2.3), "wood_dark")
	b.call(Vector3(0.0, 0.245, 0.1), Vector3(0.015, 0.01, 2.3), "wood_dark")
	b.call(Vector3(0, 0.3, -0.8), Vector3(1.15, 0.06, 0.14), "wood")
	b.call(Vector3(0, 0.3, 0.3), Vector3(1.15, 0.06, 0.14), "wood")
	for pz in [-1.2, -0.7, -0.2, 0.35]:
		b.call(Vector3(0.69, 0.33, pz), Vector3(0.035, 0.28, 0.035), "trim_white")
		b.call(Vector3(-0.69, 0.33, pz), Vector3(0.035, 0.28, 0.035), "trim_white")
	b.call(Vector3(0.69, 0.46, -0.3), Vector3(0.04, 0.035, 1.5), "trim_red")
	b.call(Vector3(-0.69, 0.46, -0.3), Vector3(0.04, 0.035, 1.5), "trim_red")
	b.call(Vector3(0.69, 0.4, -1.35), Vector3(0.04, 0.035, 0.7), "trim_red", Vector3(-0.25, 0, 0))
	b.call(Vector3(-0.69, 0.4, -1.35), Vector3(0.04, 0.035, 0.7), "trim_red", Vector3(-0.25, 0, 0))

	# ── Ca-bin (2/3 thân phía đuôi) ─────────────────────────────────────────
	b.call(Vector3(0, 0.55, 0.95), Vector3(1.3, 0.5, 0.85), "cream")
	for wx in [-0.34, -0.12, 0.12, 0.34]:
		b.call(Vector3(wx, 0.55, 0.53), Vector3(0.14, 0.18, 0.03), "glass")
	b.call(Vector3(0.0, 0.55, 0.55), Vector3(0.06, 0.24, 0.035), "wood_dark")
	b.call(Vector3(-0.23, 0.55, 0.55), Vector3(0.05, 0.24, 0.035), "wood_dark")
	b.call(Vector3(0.23, 0.55, 0.55), Vector3(0.05, 0.24, 0.035), "wood_dark")
	b.call(Vector3(0.0, 0.645, 0.55), Vector3(1.3, 0.05, 0.035), "wood_dark")
	b.call(Vector3(0.0, 0.455, 0.55), Vector3(1.3, 0.05, 0.035), "wood_dark")
	b.call(Vector3(0.66, 0.55, 1.0), Vector3(0.03, 0.16, 0.2), "glass")
	b.call(Vector3(-0.66, 0.55, 1.0), Vector3(0.03, 0.16, 0.2), "glass")
	b.call(Vector3(0, 0.82, 0.95), Vector3(1.38, 0.08, 0.92), "wood_dark")
	b.call(Vector3(0, 0.86, 0.95), Vector3(1.44, 0.03, 0.96), "wood_light")
	# Bên trong: bánh lái gỗ + đài radio có đèn báo
	b.call(Vector3(0, 0.44, 1.1), Vector3(0.03, 0.14, 0.03), "iron_dark")
	b.call(Vector3(0, 0.53, 1.1), Vector3(0.05, 0.05, 0.05), "wood_dark")
	b.call(Vector3(0, 0.53, 1.1), Vector3(0.025, 0.11, 0.025), "wood_dark", Vector3(0, 0, 0))
	b.call(Vector3(0, 0.53, 1.1), Vector3(0.025, 0.11, 0.025), "wood_dark", Vector3(0, 0, 2.09))
	b.call(Vector3(0, 0.53, 1.1), Vector3(0.025, 0.11, 0.025), "wood_dark", Vector3(0, 0, 4.19))
	b.call(Vector3(0.35, 0.52, 0.56), Vector3(0.12, 0.1, 0.04), "black")
	b.call(Vector3(0.39, 0.545, 0.58), Vector3(0.015, 0.015, 0.015), "led_red")
	b.call(Vector3(0.42, 0.545, 0.58), Vector3(0.015, 0.015, 0.015), "led_green")
	# Anten + cờ Tổ quốc (buông thẳng đứng, vẫy nhẹ)
	b.call(Vector3(0.28, 1.15, 0.75), Vector3(0.025, 0.6, 0.025), "iron")
	b.call(Vector3(0.28, 1.45, 0.75), Vector3(0.03, 0.03, 0.03), "iron_dark")
	b.call(Vector3(0.32, 1.33, 0.74), Vector3(0.02, 0.22, 0.17), "flag_red", Vector3(0, 0, 0.1))
	b.call(Vector3(0.32, 1.28, 0.85), Vector3(0.02, 0.15, 0.1), "flag_red", Vector3(0, 0, -0.18))
	b.call(Vector3(0.33, 1.33, 0.73), Vector3(0.013, 0.09, 0.04), "flag_yellow")
	b.call(Vector3(0.33, 1.33, 0.73), Vector3(0.013, 0.04, 0.09), "flag_yellow")
	# Phao cứu sinh treo hông ca-bin
	b.call(Vector3(0.78, 0.575, 1.1), Vector3(0.16, 0.05, 0.16), "orange")
	b.call(Vector3(0.78, 0.425, 1.1), Vector3(0.16, 0.05, 0.16), "orange")
	b.call(Vector3(0.7, 0.5, 1.1), Vector3(0.05, 0.16, 0.16), "orange")
	b.call(Vector3(0.86, 0.5, 1.1), Vector3(0.05, 0.16, 0.16), "orange")
	b.call(Vector3(0.78, 0.575, 1.05), Vector3(0.05, 0.05, 0.05), "white")
	b.call(Vector3(0.78, 0.425, 1.15), Vector3(0.05, 0.05, 0.05), "white")
	b.call(Vector3(0.78, 0.62, 1.1), Vector3(0.02, 0.06, 0.02), "rope")

	# ── Dàn đèn dụ cá 2 bên ──────────────────────────────────────────────────
	for s in [1.0, -1.0]:
		b.call(Vector3(1.15 * s, 1.0, 1.0), Vector3(0.05, 0.9, 0.05), "iron")
		b.call(Vector3(0.9 * s, 0.6, 1.0), Vector3(0.04, 0.04, 0.55), "iron", Vector3(0, 0, -0.5 * s))
		b.call(Vector3(1.03 * s, 1.3, 1.0), Vector3(0.62, 0.04, 0.04), "iron")
		b.call(Vector3(1.03 * s, 1.0, 1.0), Vector3(0.62, 0.04, 0.04), "iron")
		b.call(Vector3(1.03 * s, 1.265, 1.0), Vector3(0.6, 0.015, 0.015), "black")
		for lx in [0.78, 0.9, 1.02, 1.14, 1.26]:
			b.call(Vector3(lx * s, 1.24, 1.0), Vector3(0.09, 0.09, 0.09), "lamp")
			b.call(Vector3(lx * s, 1.285, 1.0), Vector3(0.045, 0.045, 0.045), "black")
		b.call(Vector3(0.95 * s, 0.96, 1.0), Vector3(0.09, 0.09, 0.09), "lamp")
		b.call(Vector3(0.95 * s, 1.005, 1.0), Vector3(0.045, 0.045, 0.045), "black")

	# ── Tời kéo lưới giữa sàn ───────────────────────────────────────────────
	b.call(Vector3(0, 0.27, 0.55), Vector3(0.4, 0.05, 0.25), "rust")
	b.call(Vector3(-0.11, 0.45, 0.55), Vector3(0.04, 0.42, 0.04), "rust", Vector3(0, 0, 0.35))
	b.call(Vector3(0.11, 0.45, 0.55), Vector3(0.04, 0.42, 0.04), "rust", Vector3(0, 0, -0.35))
	b.call(Vector3(0, 0.65, 0.55), Vector3(0.32, 0.04, 0.04), "rust")
	b.call(Vector3(0, 0.62, 0.55), Vector3(0.14, 0.12, 0.18), "iron_dark")
	b.call(Vector3(0, 0.62, 0.55), Vector3(0.1, 0.09, 0.09), "black")
	b.call(Vector3(0, 0.17, 0.55), Vector3(0.05, 0.05, 0.2), "trim_red")

	# ── Đèn pha mũi (chiếu về phía trước) + đèn giữa tàu ───────────────────
	b.call(Vector3(0, 0.32, -1.55), Vector3(0.04, 0.3, 0.04), "iron_dark")
	b.call(Vector3(0, 0.52, -1.57), Vector3(0.1, 0.08, 0.06), "lamp")
	b.call(Vector3(0, 0.52, -1.62), Vector3(0.08, 0.06, 0.02), "glass")
	b.call(Vector3(0, 0.7, 0.55), Vector3(0.03, 0.08, 0.03), "iron_dark")
	b.call(Vector3(0, 0.76, 0.55), Vector3(0.12, 0.08, 0.12), "lamp")
	b.call(Vector3(0, 0.81, 0.55), Vector3(0.05, 0.03, 0.05), "iron_dark")

	# ── Lưới + phao chất đống đuôi tàu ──────────────────────────────────────
	b.call(Vector3(0, 0.3, 1.55), Vector3(0.55, 0.14, 0.5), "net", Vector3(0, 0.3, 0))
	b.call(Vector3(0.08, 0.42, 1.6), Vector3(0.45, 0.12, 0.45), "net_dark", Vector3(0, -0.25, 0))
	b.call(Vector3(-0.15, 0.4, 1.48), Vector3(0.4, 0.1, 0.42), "net", Vector3(0, 0.15, 0))
	b.call(Vector3(0, 0.5, 1.62), Vector3(0.3, 0.1, 0.3), "net_dark", Vector3(0, 0.5, 0))
	b.call(Vector3(-0.3, 0.34, 1.68), Vector3(0.3, 0.12, 0.3), "net", Vector3(0, -0.4, 0))
	for fz in [Vector3(0.35, 0.32, 1.4), Vector3(-0.35, 0.32, 1.5),
			Vector3(0.2, 0.46, 1.4), Vector3(-0.1, 0.44, 1.6),
			Vector3(0.4, 0.36, 1.65), Vector3(-0.4, 0.4, 1.6),
			Vector3(0.0, 0.52, 1.5), Vector3(0.25, 0.52, 1.72),
			Vector3(-0.25, 0.5, 1.7), Vector3(0.45, 0.42, 1.5)]:
		b.call(fz, Vector3(0.05, 0.05, 0.05), "orange" if fz.x >= 0.0 else "trim_red")

	# ── Thùng ướp đá + cá tươi ──────────────────────────────────────────────
	b.call(Vector3(0.55, 0.28, -0.45), Vector3(0.3, 0.28, 0.3), "orange")
	b.call(Vector3(0.55, 0.42, -0.45), Vector3(0.3, 0.04, 0.3), "orange")
	b.call(Vector3(0.55, 0.44, -0.45), Vector3(0.14, 0.02, 0.02), "black")
	b.call(Vector3(-0.5, 0.27, -0.6), Vector3(0.26, 0.26, 0.26), "green")
	b.call(Vector3(-0.5, 0.4, -0.6), Vector3(0.26, 0.04, 0.26), "green")
	b.call(Vector3(0.55, 0.2, 0.15), Vector3(0.3, 0.05, 0.3), "orange")
	b.call(Vector3(0.55, 0.34, 0.0), Vector3(0.3, 0.24, 0.05), "orange")
	b.call(Vector3(0.55, 0.34, 0.3), Vector3(0.3, 0.24, 0.05), "orange")
	b.call(Vector3(0.4, 0.34, 0.15), Vector3(0.05, 0.24, 0.3), "orange")
	b.call(Vector3(0.7, 0.34, 0.15), Vector3(0.05, 0.24, 0.3), "orange")
	b.call(Vector3(0.5, 0.36, 0.12), Vector3(0.08, 0.05, 0.08), "ice")
	b.call(Vector3(0.62, 0.37, 0.18), Vector3(0.07, 0.05, 0.07), "ice")
	b.call(Vector3(0.55, 0.39, 0.1), Vector3(0.06, 0.04, 0.06), "ice")
	b.call(Vector3(0.47, 0.38, 0.2), Vector3(0.06, 0.04, 0.06), "ice")
	b.call(Vector3(0.47, 0.32, 0.12), Vector3(0.05, 0.05, 0.24), "fish", Vector3(0, 0.35, 0))
	b.call(Vector3(0.63, 0.33, 0.2), Vector3(0.05, 0.05, 0.22), "fish", Vector3(0, -0.4, 0))
	b.call(Vector3(0.47, 0.32, 0.24), Vector3(0.03, 0.03, 0.05), "black")
	b.call(Vector3(0.63, 0.33, 0.31), Vector3(0.03, 0.03, 0.05), "black")

	# ── Đuôi: ống xả + khói + chân vịt đồng + bánh lái ──────────────────────
	b.call(Vector3(0, 0.95, 1.05), Vector3(0.07, 0.5, 0.07), "iron_dark")
	b.call(Vector3(0, 1.2, 1.05), Vector3(0.1, 0.07, 0.1), "black")
	b.call(Vector3(0, 1.32, 1.05), Vector3(0.12, 0.08, 0.12), "smoke")
	b.call(Vector3(0.03, 1.42, 1.08), Vector3(0.1, 0.08, 0.1), "smoke")
	b.call(Vector3(0.07, 1.52, 1.11), Vector3(0.09, 0.08, 0.09), "smoke")
	b.call(Vector3(0, -0.42, 1.95), Vector3(0.06, 0.06, 0.06), "brass")
	b.call(Vector3(0, -0.42, 1.95), Vector3(0.04, 0.2, 0.03), "brass", Vector3(0, 0, 0))
	b.call(Vector3(0, -0.42, 1.95), Vector3(0.04, 0.2, 0.03), "brass", Vector3(0, 0, 2.09))
	b.call(Vector3(0, -0.42, 1.95), Vector3(0.04, 0.2, 0.03), "brass", Vector3(0, 0, 4.19))
	b.call(Vector3(0, -0.28, 2.0), Vector3(0.36, 0.4, 0.06), "trim_red")
	b.call(Vector3(0, -0.05, 1.96), Vector3(0.05, 0.42, 0.05), "iron_dark")

	# ── Phụ kiện nhỏ: can dầu, xô nhựa, đèn bão ─────────────────────────────
	b.call(Vector3(0.75, 0.25, 1.25), Vector3(0.15, 0.26, 0.13), "yellow")
	b.call(Vector3(0.75, 0.39, 1.25), Vector3(0.04, 0.04, 0.04), "trim_red")
	b.call(Vector3(0.75, 0.4, 1.25), Vector3(0.09, 0.02, 0.02), "black")
	b.call(Vector3(-0.62, 0.15, 1.35), Vector3(0.18, 0.18, 0.18), "trim_red")
	b.call(Vector3(-0.62, 0.25, 1.35), Vector3(0.2, 0.03, 0.2), "trim_red")
	b.call(Vector3(-0.62, 0.2, 1.35), Vector3(0.09, 0.03, 0.09), "rope")
	b.call(Vector3(-0.62, 0.33, 1.35), Vector3(0.04, 0.06, 0.02), "iron")
	b.call(Vector3(-0.45, 0.72, 1.45), Vector3(0.02, 0.05, 0.02), "iron")
	b.call(Vector3(-0.45, 0.66, 1.45), Vector3(0.07, 0.02, 0.07), "brass")
	b.call(Vector3(-0.45, 0.6, 1.45), Vector3(0.06, 0.1, 0.06), "brass")
	b.call(Vector3(-0.45, 0.59, 1.45), Vector3(0.045, 0.08, 0.045), "lamp")
	b.call(Vector3(-0.45, 0.54, 1.45), Vector3(0.08, 0.02, 0.08), "brass")

	_commit_meshes(rig, sts, mats)
	_lamp_mat = mats["lamp"] as StandardMaterial3D

# ── Đèn thuyền ───────────────────────────────────────────────────────────────
func _build_lights() -> void:
	if _rig == null:
		return
	var mk := func(lpos: Vector3, range_m: float) -> void:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.light_color = Color(1.0, 0.82, 0.45)
		l.omni_range = range_m
		l.shadow_enabled = false
		l.position = lpos
		_rig.add_child(l)
		_boat_lights.append(l)
	# Dàn đèn dụ cá 2 bên: 5 bóng lớn trên xà + 1 bóng thấp mỗi bên
	for s in [1.0, -1.0]:
		for lx in [0.78, 0.9, 1.02, 1.14, 1.26]:
			mk.call(Vector3(lx * s, 1.24, 1.0), 1.9)
		mk.call(Vector3(0.95 * s, 0.96, 1.0), 1.2)
	# Đèn pha mũi — SpotLight chiếu về phía trước (mặc định hướng -Z)
	var spot := SpotLight3D.new()
	spot.light_energy = 0.0
	spot.light_color = Color(1.0, 0.92, 0.75)
	spot.spot_range = 8.0
	spot.spot_angle = 32.0
	spot.spot_attenuation = 1.0
	spot.shadow_enabled = false
	spot.position = Vector3(0, 0.52, -1.62)
	_rig.add_child(spot)
	_boat_lights.append(spot)
	# Đèn giữa tàu treo trên tời
	mk.call(Vector3(0, 0.76, 0.55), 2.5)
	# Đèn bão treo đuôi
	mk.call(Vector3(-0.45, 0.59, 1.45), 1.1)

# ── Bọt nước + tia té nước tại chân vịt khi chạy ────────────────────────────
## Gắn mesh cầu (sphere) + material trong suốt unshaded cho particle — mesh
## phẳng (quad) nhìn mỏng từ hông; mesh cầu 3D hiển thị đều từ mọi góc.
func _config_particles(p: CPUParticles3D, base_size: float) -> void:
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
	m.albedo_color = Color.WHITE
	sph.material = m
	p.mesh = sph
	p.scale_amount_min = base_size * 0.7
	p.scale_amount_max = base_size * 1.3

func _build_bubbles() -> void:
	if _rig == null:
		return
	var p := CPUParticles3D.new()
	p.name = "_PropBubbles"
	p.amount = 36
	p.lifetime = 1.1
	p.one_shot = false
	p.emitting = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.gravity = Vector3(0, -1.4, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.85
	p.color = Color(0.92, 0.96, 1.0, 0.8)
	p.position = Vector3(0, -0.42, 1.95)
	_config_particles(p, 0.22)
	_rig.add_child(p)
	_bubbles = p
	# Tia té nước trắng ngay mặt nước phía chân vịt
	var sp := CPUParticles3D.new()
	sp.name = "_PropSplash"
	sp.amount = 28
	sp.lifetime = 0.5
	sp.one_shot = false
	sp.emitting = false
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 75.0
	sp.gravity = Vector3(0, -9.5, 0)
	sp.initial_velocity_min = 1.2
	sp.initial_velocity_max = 2.8
	sp.color = Color(0.95, 0.98, 1.0, 0.9)
	sp.position = Vector3(0, -0.08, 1.95)
	_config_particles(sp, 0.28)
	_rig.add_child(sp)
	_splash = sp

# ── Khói trắng từ ống xả (máy nổ khi có tài xế) ─────────────────────────────
func _build_smoke() -> void:
	if _rig == null:
		return
	var p := CPUParticles3D.new()
	p.name = "_ExhaustSmoke"
	p.amount = 24
	p.lifetime = 2.0
	p.one_shot = false
	p.emitting = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 16.0
	p.gravity = Vector3(0, 0.7, 0)
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.75
	_config_particles(p, 0.34)
	var grow := Curve.new()
	grow.add_point(Vector2(0, 1.0))
	grow.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.95, 0.95, 0.55))
	ramp.set_color(0.6, Color(0.92, 0.92, 0.92, 0.25))
	ramp.set_color(1, Color(0.90, 0.90, 0.90, 0.0))
	p.color_ramp = ramp
	p.position = Vector3(0, 1.55, 1.05)
	_rig.add_child(p)
	_smoke = p

## Cập nhật đèn theo đêm/mưa (interval để đỡ tốn CPU).
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
	for l in _boat_lights:
		if is_instance_valid(l):
			l.light_energy = lerp(l.light_energy, t * LIGHT_MAX_ENERGY, spd)
	if _lamp_mat:
		var cur: float = _lamp_mat.emission_energy_multiplier
		_lamp_mat.emission_energy_multiplier = lerp(cur, t * 2.2, spd)

## 0 = tắt (ban ngày), 1 = sáng tối đa (đêm sâu / mưa nặng).
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
	box.size = Vector3(HULL_WID, HULL_DEP, HULL_LEN)
	col.shape = box
	col.position = Vector3(0, HULL_BOTTOM + HULL_DEP * 0.5, 0)
	add_child(col)

# ── Bị phá huỷ bởi đòn heavy (rìu/cúp/cuốc/đại kiếm) ─────────────────────────
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
	dn.setup(dmg, global_position + Vector3(0, 1.5, 0), Color.WHITE)

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

## Thuyền vỡ: tài xế bị đá xuống nước (trả meta + va chạm + vị trí an toàn).
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
