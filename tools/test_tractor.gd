extends Node3D

## test_tractor — Máy kéo nông nghiệp + rơ-moóc: đứng trên mặt đất, lái
## (ga/phanh/bẻ lái), bánh xe quay + rơ-moóc lệch khớp, lên/xuống xe (F),
## khói ống xả khi nổ máy, đèn pha sáng đêm/mưa, recipe + đặt xe lên đất.
## Chạy qua tools/test_tractor.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Tractor = preload("res://scripts/items/entities/tractor.gd")
const _Recipe = preload("res://scripts/items/core/recipe_database.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD
const SEED := 20260806
const HALF := 16.0

var _failures: int = 0
var _chunk: Node = null

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _wait_physics(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame

func _clear_all() -> void:
	for vx in range(0, SIZE):
		for vz in range(0, SIZE):
			for ly in range(0, _BD.CHUNK_H):
				_chunk.block_data.set_block(vx, ly, vz, _D.BlockID.AIR)

func _rebuild_chunk() -> void:
	_chunk.rebuild_mesh()
	CollisionQueue.remove_chunk(_chunk)
	await _wait_physics(6)
	for ch in _chunk.get_children():
		if ch is StaticBody3D:
			ch.queue_free()
	_chunk.rebuild_mesh()
	await _wait_physics(8)

func _set_world_block(wx: float, wy: float, wz: float, bid: int) -> void:
	var lx: int = int(floor(wx - (_chunk.global_position.x - HALF)))
	var lz: int = int(floor(wz - (_chunk.global_position.z - HALF)))
	var ly: int = _BD.world_y_to_layer(wy)
	if lx < 0 or lx >= SIZE or lz < 0 or lz >= SIZE or ly < 0 or ly >= _BD.CHUNK_H:
		return
	_chunk.block_data.set_block(lx, ly, lz, bid)

## Đồng bằng cát phẳng: mặt đất top = 0.5 quanh toàn bộ chunk (máy kéo chạy
## trên đất liền, không cần nước). Dọn trước lớp trên để dựng lại mặt phẳng.
func _build_plain() -> void:
	for vx in range(0, SIZE):
		for vz in range(0, SIZE):
			var wx: float = _chunk.global_position.x - HALF + float(vx)
			var wz: float = _chunk.global_position.z - HALF + float(vz)
			for ly in range(17, 23):
				_set_world_block(wx, _BD.layer_to_world_y(ly), wz, _D.BlockID.AIR)
			_set_world_block(wx, -0.5, wz, _D.BlockID.SAND)
			_set_world_block(wx, 0.0, wz, _D.BlockID.SAND)

func _ready() -> void:
	WorldSeed.seed_value = SEED
	seed(SEED)

	print("== test_tractor: Máy kéo nông nghiệp ==")

	# ── 1. Item + recipe ────────────────────────────────────────────────────
	print("-- 1. Item + recipe --")
	ItemDatabase.ensure_db()
	var tr_def: ItemDef = ItemDatabase.items_db.get("tractor") as ItemDef
	_check(tr_def != null, "item tractor tồn tại trong db")
	_check(tr_def != null and tr_def.type == ItemDef.Type.TOOL, "tractor loại TOOL")
	_check(tr_def != null and not tr_def.stackable, "máy kéo không stack")
	_Recipe.ensure()
	_check(_Recipe.recipes.is_empty(), "toàn bộ công thức chế tạo đã bị xoá (còn %d)" % _Recipe.recipes.size())
	var rt: Dictionary = _Recipe.match_counts({"steel_ingot": 6, "iron_ingot": 8, "palm_wood": 10})
	_check(rt.is_empty(), "không còn recipe máy kéo (đã xoá)")

	# ── 2. Chunk + mặt đất ──────────────────────────────────────────────────
	print("-- 2. Mặt đất --")
	_chunk = _W.new()
	_chunk.name = "TractorChunk"
	add_child(_chunk)
	_chunk.setup(0, 0, SIZE, RW, true)
	_check(_chunk.block_data != null, "chunk setup sync ok")
	CollisionQueue.remove_chunk(_chunk)
	if "_prop_queue" in _chunk:
		_chunk._prop_queue.clear()
		_chunk.set_process(false)
	await _wait_physics(6)
	for ch in _chunk.get_children():
		if ch is StaticBody3D or ch is DestroyableProp or ch is PlantProp:
			ch.queue_free()
	_build_plain()
	_chunk.rebuild_mesh()
	CollisionQueue.remove_chunk(_chunk)
	await _wait_physics(12)
	for ch in _chunk.get_children():
		if ch is StaticBody3D:
			ch.queue_free()
	_chunk.rebuild_mesh()

	var tr: Node = _Tractor.new()
	tr.name = "TestTractor"
	add_child(tr)
	var g0: float = tr._ground_height_at(0.0, 0.0)
	_check(absf(g0 - 0.5) < 0.01, "mặt đất tại (0,0) = 0.5 (được %s)" % str(g0))
	_check(tr._chunk_at(0.0, 0.0) == _chunk, "chunk key world (0,0) → chunk (0,0)")
	_check(tr._chunk_at(-40.0, 0.0) == null, "ngoài phạm vi chunk → null")

	# ── 3. Đứng vững trên mặt đất ──────────────────────────────────────────
	print("-- 3. Đứng vững --")
	tr.global_position = Vector3(0, 0.6, 0)
	tr.velocity = Vector3.ZERO
	await _wait_physics(90)
	print("  DEBUG y=", tr.global_position.y, " vel=", tr.velocity, " pos=", tr.global_position)
	_check(absf(tr.global_position.y - 0.5) < 0.15, "máy kéo đứng trên mặt đất (y=%s)" % str(tr.global_position.y))
	var idle_drift: float = Vector2(tr.velocity.x, tr.velocity.z).length()
	_check(idle_drift < 0.05, "không tự trôi khi đứng yên (speed=%s)" % str(idle_drift))

	# ── 4. Lên xe + lái (ga/bẻ lái) ────────────────────────────────────────
	print("-- 4. Lên xe + lái --")
	var dscript := GDScript.new()
	dscript.source_code = "extends CharacterBody3D\nvar _is_player := true\n"
	dscript.reload()
	var driver := CharacterBody3D.new()
	driver.name = "DriverStub"
	driver.set_script(dscript)
	var dshape := CollisionShape3D.new()
	dshape.name = "CollisionShape3D"
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(0.6, 1.8, 0.6)
	dshape.shape = dbox
	driver.add_child(dshape)
	add_child(driver)
	driver.global_position = Vector3(2.2, 0.5, 0.4)
	_check(tr.is_player_nearby(driver), "người chơi gần xe → is_player_nearby")
	_check(tr.try_board(driver), "try_board thành công")
	_check(tr.is_driver(driver) and tr.is_driven(), "driver được gán")
	_check(driver.has_meta("driving_vehicle") and driver.get_meta("driving_vehicle") == tr,
		"player bị khóa điều khiển (meta driving_vehicle)")
	_check(driver.get_node("CollisionShape3D").disabled, "shape người chơi bị tắt khi lên xe")
	await _wait_physics(30)
	_check(tr.global_position.y > 0.30, "có tài xế xe không lún (y=%s)" % str(tr.global_position.y))

	var fwd0: Vector3 = tr.global_position
	Input.action_press("move_forward")
	await _wait_physics(60)
	Input.action_release("move_forward")
	var moved: float = fwd0.distance_to(tr.global_position)
	var fwd_speed: float = -tr.velocity.dot(Vector3(0, 0, 1))
	_check(fwd_speed > 2.0, "ga tới đạt tốc độ tiến (v=%s)" % str(fwd_speed))
	_check(moved > 1.0, "máy kéo di chuyển về phía trước (d=%s)" % str(moved))
	_check(tr._wheel_angle != 0.0, "bánh xe đã quay (angle=%s)" % str(tr._wheel_angle))
	_check(tr._smoke.emitting, "khói ống xả phun khi nổ máy")

	var rot_before: float = tr.rotation.y
	Input.action_press("move_left")
	await _wait_physics(30)
	Input.action_release("move_left")
	var rot_delta: float = absf(tr.rotation.y - rot_before)
	_check(rot_delta > 0.05, "bẻ lái trái khi đang chạy (Δ=%s)" % str(rot_delta))
	_check(tr._trailer_yaw != 0.0, "rơ-moọc lệch khớp xoay khi bẻ lái (yaw=%s)" % str(tr._trailer_yaw))

	# ── 5. Xuống xe ─────────────────────────────────────────────────────────
	print("-- 5. Xuống xe --")
	tr.try_exit()
	_check(not tr.is_driven(), "try_exit: hết tài xế")
	_check(not driver.has_meta("driving_vehicle"), "try_exit: nhả khóa điều khiển")
	_check(driver.global_position.distance_to(tr.global_position) < 7.0,
		"try_exit: người chơi đứng gần xe (d=%s)" % str(driver.global_position.distance_to(tr.global_position)))
	await _wait_physics(20)
	_check(not tr._smoke.emitting, "khói tắt khi tài xế rời")

	# ── 6. Phanh khi không ga ───────────────────────────────────────────────
	print("-- 6. Trôi và dừng --")
	tr.velocity = Vector3(0, 0, -4.0)
	await _wait_physics(150)
	var stop_speed: float = Vector2(tr.velocity.x, tr.velocity.z).length()
	_check(stop_speed < 0.8, "máy kéo trượt dừng dần khi hết ga (speed=%s)" % str(stop_speed))

	# ── 7. Đặt xe qua placement ─────────────────────────────────────────────
	print("-- 7. Placement --")
	var wscript := GDScript.new()
	wscript.source_code = "\nextends Node\n" \
		+ "var _c: Node = null\n" \
		+ "func get_block(wx: float, wy: float, wz: float) -> int:\n" \
		+ "\tvar cx := int(floor((wx + 16.0) / 32.0))\n" \
		+ "\tvar cz := int(floor((wz + 16.0) / 32.0))\n" \
		+ "\tif _c == null or _c._cx != cx or _c._cz != cz: return 0\n" \
		+ "\tvar lx := int(floor(wx - (_c.global_position.x - 16.0)))\n" \
		+ "\tvar lz := int(floor(wz - (_c.global_position.z - 16.0)))\n" \
		+ "\tvar ly := int(floor(wy / 0.5)) + 18\n" \
		+ "\tif lx < 0 or lx >= 32 or lz < 0 or lz >= 32 or ly < 0 or ly >= 69: return 0\n" \
		+ "\treturn _c.block_data.get_block(lx, ly, lz)\n"
	wscript.reload()
	var world_root := Node.new()
	world_root.name = "WorldRoot"
	add_child(world_root)
	var wm := Node.new()
	wm.name = "WorldManager"
	wm.set_script(wscript)
	wm._c = _chunk
	world_root.add_child(wm)
	var ps := _Placement.new()
	world_root.add_child(ps)
	var pinv: Inventory = Inventory.new(36)
	ps.set_player_inventory(pinv)

	pinv.add_item(tr_def, 1)
	pinv.remove_item_by_id("tractor", 1)
	ps._do_placement("tractor", Vector3(3.0, 0.5, 3.0))
	var placed = world_root.get_node_or_null("Tractor")
	_check(placed != null, "đặt máy kéo lên đất → tạo entity Tractor")
	if placed:
		_check(placed.global_position.distance_to(Vector3(3.0, 0.5, 3.0)) < 0.01, "vị trí xe đúng điểm đặt")
		await _wait_physics(60)
		_check(absf(placed.global_position.y - 0.5) < 0.15, "xe đặt xuống đứng vững trên đất (y=%s)" % str(placed.global_position.y))
	_check(pinv.get_item_count("tractor") == 0, "item tiêu thụ sau khi đặt")

	# ── 8. Đèn pha sáng đêm/mưa, tắt ban ngày ──────────────────────────────
	print("-- 8. Đèn pha --")
	_check(tr._light_factor(12.0) == 0.0, "ban ngày đèn tắt (t=0)")
	_check(tr._light_factor(21.0) == 1.0, "đêm sâu đèn sáng tối đa (t=1)")
	var dusk_t: float = tr._light_factor(18.0)
	_check(dusk_t > 0.1 and dusk_t < 1.0, "chạng vạng đèn sáng dần (t=%s)" % str(dusk_t))
	var l0: Light3D = tr._spotlights[0]
	tr._last_light_t = -1.0
	l0.light_energy = 0.0
	TimeSystem.set_hour(22.0)
	tr._update_lights(0.13)
	_check(l0.light_energy > 0.0, "đêm: đèn pha Omni/Spot bật dần (energy=%s)" % str(l0.light_energy))
	TimeSystem.set_hour(12.0)
	tr._last_light_t = 1.0
	l0.light_energy = 2.0
	tr._update_lights(0.13)
	_check(l0.light_energy < 2.0, "ban ngày: đèn pha tắt dần (energy=%s)" % str(l0.light_energy))

	# ── 9. Model + khói có mesh + vật phẩm model đầy đủ ─────────────────────
	print("-- 9. Model + VFX --")
	_check(tr._rig != null and tr._trailer_pivot != null, "rig đầu kéo + pivot rơ-moọc tồn tại")
	_check(tr._wheels_tractor.size() == 4 and tr._wheels_trailer.size() == 2,
		"4 bánh đầu kéo + 2 bánh rơ-moọc (tractor=%d trailer=%d)" % [tr._wheels_tractor.size(), tr._wheels_trailer.size()])
	_check(tr._smoke != null and tr._smoke.mesh != null, "khói có mesh")
	_check(tr._smoke.scale_amount_max >= 0.2, "kích thước khói nhìn thấy được (>=0.2)")
	var meshes: int = 0
	for ch in tr._rig.get_children():
		if ch is MeshInstance3D:
			meshes += 1
	_check(meshes >= 2, "mesh gộp đầu kéo hiển thị (rig children=%d)" % meshes)
	var mini := Node3D.new()
	ItemMesh.build(mini, "tractor")
	_check(mini.get_child_count() > 0, "item tractor có mini model cầm tay (%d boxes)" % mini.get_child_count())
	mini.queue_free()

	# ── 10. Phá huỷ bằng đòn heavy → rớt lại item ──────────────────────────
	print("-- 10. Phá huỷ --")
	if placed:
		_check(not placed.try_destroy("iron_sword"), "kiếm thường không phá được máy kéo")
		var hp_before: int = placed.hp
		_check(placed.try_destroy("axe"), "rìu (heavy) phá được máy kéo")
		_check(placed.hp < hp_before, "hp giảm sau đòn heavy")

	# ── 11. Leo bậc 1 block ────────────────────────────────────────────────
	print("-- 11. Leo bậc 1 block --")
	if placed:
		placed.queue_free()
		placed = null
	await _wait_physics(10)
	_clear_all()
	_build_plain()
	# Bậc +1.0m cho vùng local vz 0..9 (world z < -6): đất phẳng top 0.5 → 1.5.
	for vx in range(0, SIZE):
		for vz in range(0, 10):
			var wx: float = _chunk.global_position.x - HALF + float(vx)
			var wz: float = _chunk.global_position.z - HALF + float(vz)
			_set_world_block(wx, 0.5, wz, _D.BlockID.SAND)
			_set_world_block(wx, 1.0, wz, _D.BlockID.SAND)
	_rebuild_chunk()
	_check(absf(tr._ground_height_at(0.0, -8.0) - 1.5) < 0.01,
		"vùng bậc: đất top=1.5 (được %s)" % str(tr._ground_height_at(0.0, -8.0)))
	_check(absf(tr._ground_height_at(0.0, 2.0) - 0.5) < 0.01,
		"vùng thấp: đất top=0.5 (được %s)" % str(tr._ground_height_at(0.0, 2.0)))
	tr.global_position = Vector3(0, 0.6, 2.0)
	tr.rotation.y = 0.0
	tr.velocity = Vector3.ZERO
	driver.global_position = tr.global_position + Vector3(1.5, 0, 0.5)
	_check(tr.try_board(driver), "leo bậc: lên xe lại")
	Input.action_press("move_forward")
	await _wait_physics(260)
	Input.action_release("move_forward")
	print("  DEBUG climb y=", tr.global_position.y, " z=", tr.global_position.z)
	_check(tr.global_position.z < -6.0, "máy kéo vượt qua chân bậc (z=%s)" % str(tr.global_position.z))
	_check(tr.global_position.y > 1.0, "máy kéo đã lên đỉnh bậc cao 1 block (y=%s)" % str(tr.global_position.y))
	tr.try_exit()

	# ── 12. Chìm xuống nước ────────────────────────────────────────────────
	print("-- 12. Chìm xuống nước --")
	_clear_all()
	# Hồ nước vùng local vz 0..15: đáy SAND top -1.5, nước phủ tới mặt 0.5.
	for vx in range(0, SIZE):
		for vz in range(0, 16):
			var wx: float = _chunk.global_position.x - HALF + float(vx)
			var wz: float = _chunk.global_position.z - HALF + float(vz)
			_set_world_block(wx, -2.0, wz, _D.BlockID.SAND)
			_set_world_block(wx, -1.5, wz, _D.BlockID.WATER)
			_set_world_block(wx, -1.0, wz, _D.BlockID.WATER)
			_set_world_block(wx, -0.5, wz, _D.BlockID.WATER)
			_set_world_block(wx, 0.0, wz, _D.BlockID.WATER)
	_rebuild_chunk()
	_check(absf(tr._ground_height_at(0.0, -10.0) - (-1.5)) < 0.01,
		"vùng hồ: đáy top=-1.5 (được %s)" % str(tr._ground_height_at(0.0, -10.0)))
	tr.global_position = Vector3(0, 0.6, -10.0)
	tr.velocity = Vector3.ZERO
	tr.rotation.y = 0.0
	await _wait_physics(120)
	print("  DEBUG water y=", tr.global_position.y, " pos=", tr.global_position)
	_check(tr.global_position.y < 0.0, "máy kéo CHÌM xuống dưới mặt nước 0.5 (y=%s)" % str(tr.global_position.y))
	_check(tr.global_position.y > -3.0, "không rơi xuyên đáy hồ (y=%s)" % str(tr.global_position.y))

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)