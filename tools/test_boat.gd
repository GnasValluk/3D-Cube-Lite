extends Node3D

## test_boat — Thuyền đánh cá: nổi trên nước, chèo/bẻ lái, mắc cạn,
## lên/xuống thuyền, recipe chế tạo, đặt thuyền chỉ trên nước.
## Chạy qua tools/test_boat.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Boat = preload("res://scripts/items/entities/fishing_boat.gd")
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

## Đặt block tại world position (chunk global = tâm, phủ [-16, +16)).
func _set_world_block(wx: float, wy: float, wz: float, bid: int) -> void:
	var lx: int = int(floor(wx - (_chunk.global_position.x - HALF)))
	var lz: int = int(floor(wz - (_chunk.global_position.z - HALF)))
	var ly: int = _BD.world_y_to_layer(wy)
	if lx < 0 or lx >= SIZE or lz < 0 or lz >= SIZE or ly < 0 or ly >= _BD.CHUNK_H:
		return
	_chunk.block_data.set_block(lx, ly, lz, bid)

## Dựng ao nước rộng 19×19 quanh gốc tọa độ (thuyền dài 3.4m cần khoảng trống
## để chạy thử) + bờ cát xung quanh.
## Xóa sạch các lớp phía trên trước (terrain gốc quanh spawn là đất cao 1.0 —
## nếu không đào sâu thì "ao" sẽ bị chôn dưới lớp cát gốc).
const POND_MIN := 5
const POND_MAX := 27

func _build_pond() -> void:
	for vx in range(0, SIZE):
		for vz in range(0, SIZE):
			var wx: float = _chunk.global_position.x - HALF + float(vx)
			var wz: float = _chunk.global_position.z - HALF + float(vz)
			for ly in range(17, 23):
				_set_world_block(wx, _BD.layer_to_world_y(ly), wz, _D.BlockID.AIR)
			if vx >= POND_MIN and vx <= POND_MAX and vz >= POND_MIN and vz <= POND_MAX:
				_set_world_block(wx, -1.0, wz, _D.BlockID.SAND)
				_set_world_block(wx, -0.5, wz, _D.BlockID.WATER_SOURCE)
				_set_world_block(wx, 0.0, wz, _D.BlockID.WATER_SOURCE)
			else:
				_set_world_block(wx, -0.5, wz, _D.BlockID.SAND)
				_set_world_block(wx, 0.0, wz, _D.BlockID.SAND)

func _ready() -> void:
	WorldSeed.seed_value = SEED
	seed(SEED)

	print("== test_boat: Thuyền đánh cá ==")

	# ── 1. Recipe chế tạo thuyền ───────────────────────────────────────────
	print("-- 1. Recipe chế tạo --")
	_Recipe.ensure()
	_check(_Recipe.recipes.size() == 3, "có 3 recipe (thuyền, cần câu, xô nước)")
	_check(_Recipe.recipes[0].id == "fishing_boat", "recipe[0] = fishing_boat")
	var rb: Dictionary = _Recipe.match_counts({"palm_wood": 6, "coconut": 2, "tropical_seaweed": 2})
	_check(rb.get("id", "") == "fishing_boat", "đủ nguyên liệu → chế được thuyền")
	_check(_Recipe.match_counts({"palm_wood": 5, "coconut": 2, "tropical_seaweed": 1}).is_empty(),
		"thiếu nguyên liệu → không khớp recipe nào")
	_check(_Recipe.match_counts({"palm_wood": 6, "coconut": 3, "tropical_seaweed": 2}).get("id", "") == "fishing_boat",
		"thừa nguyên liệu vẫn khớp recipe")
	var rrod: Dictionary = _Recipe.match_counts({"palm_wood": 3, "tropical_seaweed": 2})
	_check(rrod.get("id", "") == "fishing_rod", "recipe cần câu khớp")
	var rbk: Dictionary = _Recipe.match_counts({"iron_ingot": 2, "palm_wood": 1})
	_check(rbk.get("id", "") == "water_bucket", "recipe xô nước khớp")

	ItemDatabase.ensure_db()
	var boat_def: ItemDef = ItemDatabase.items_db.get("fishing_boat") as ItemDef
	_check(boat_def != null, "item fishing_boat tồn tại trong db")
	_check(boat_def != null and boat_def.type == ItemDef.Type.TOOL, "fishing_boat loại TOOL")
	_check(boat_def != null and not boat_def.stackable, "thuyền không stack")

	# ── 2. Đếm lưới chế tạo ────────────────────────────────────────────────
	print("-- 2. count_grid --")
	var grid: Inventory = Inventory.new(9)
	grid.add_item(ItemDatabase.items_db.get("palm_wood") as ItemDef, 6)
	grid.add_item(ItemDatabase.items_db.get("coconut") as ItemDef, 2)
	grid.add_item(ItemDatabase.items_db.get("tropical_seaweed") as ItemDef, 2)
	var have: Dictionary = _Recipe.count_grid(grid)
	_check(have.get("palm_wood", 0) == 6 and have.get("coconut", 0) == 2 and have.get("tropical_seaweed", 0) == 2,
		"count_grid đếm đúng nguyên liệu")
	_check(_Recipe.match_grid(grid).get("id", "") == "fishing_boat", "match_grid khớp recipe thuyền")

	# ── 3. Chunk + ao nước ─────────────────────────────────────────────────
	print("-- 3. Mực nước --")
	_chunk = _W.new()
	_chunk.name = "BoatChunk"
	add_child(_chunk)
	_chunk.setup(0, 0, SIZE, RW, true)
	_check(_chunk.block_data != null, "chunk setup sync ok")
	# Chunk build gốc đẩy collision qua CollisionQueue (worker thread, async).
	# Nếu không dọn, StaticBody cũ (mặt đất 1.0) sẽ được apply sau khi rebuild
	# và chặn thuyền trong ao. Trình tự: remove pending → đợi queue xả hết
	# → xóa StaticBody3D + prop → mới dựng ao → rebuild.
	CollisionQueue.remove_chunk(_chunk)
	if "_prop_queue" in _chunk:
		_chunk._prop_queue.clear()
		_chunk.set_process(false)
	await _wait_physics(6)
	for ch in _chunk.get_children():
		if ch is StaticBody3D or ch is DestroyableProp or ch is PlantProp:
			ch.queue_free()
	_build_pond()
	_chunk._max_water_ly = maxi(_chunk._max_water_ly, 18)
	_chunk.rebuild_mesh()
	_chunk.rebuild_water_mesh()
	# Worker thread push collision gốc (async) — có thể land sau rebuild.
	# Đợi cho queue xả hết rồi dọn StaticBody3D lần cuối và rebuild lại —
	# kết quả: chỉ còn đúng collision mới.
	CollisionQueue.remove_chunk(_chunk)
	await _wait_physics(12)
	for ch in _chunk.get_children():
		if ch is StaticBody3D:
			ch.queue_free()
	_chunk.rebuild_mesh()
	_chunk.rebuild_water_mesh()

	var boat: Node = _Boat.new()
	boat.name = "TestBoat"
	add_child(boat)
	var surf: float = boat._water_surface_at(0.0, 0.0)
	_check(absf(surf - 0.5) < 0.01, "mực nước ao tại (0,0) = 0.5 (được %s)" % str(surf))
	_check(boat._water_surface_at(-13.0, -13.0) < -900.0, "trên bờ cát không có nước")
	_check(boat._chunk_at(0.0, 0.0) == _chunk, "chunk key world (0,0) → chunk (0,0)")
	_check(boat._chunk_at(-15.0, 0.0) == _chunk, "world x=-15 vẫn thuộc chunk (0,0)")
	_check(boat._chunk_at(-40.0, 0.0) == null, "ngoài phạm vi chunk → null")

	# ── 4. Nổi + không trôi khi không lái ──────────────────────────────────
	print("-- 4. Nổi trên nước --")
	boat.global_position = Vector3(0, 0.5, 0)
	boat.velocity = Vector3.ZERO
	await _wait_physics(120)
	print("  DEBUG y=", boat.global_position.y, " floor=", boat.is_on_floor(),
		" surf=", boat._water_surface_at(0, 0),
		" pos=", boat.global_position,
		" topc=", _chunk._top_ly_cache[16 * SIZE + 16],
		" blk16=", _chunk.block_data.get_block(16, 18, 16),
		" blk15=", _chunk.block_data.get_block(16, 19, 16))
	_check(absf(boat.global_position.y - 0.46) < 0.12, "thuyền nổi quanh mực nước 0.46 (y=%s)" % str(boat.global_position.y))
	var drift: float = Vector2(boat.velocity.x, boat.velocity.z).length()
	_check(drift < 0.05, "không trôi khi đứng yên (speed=%s)" % str(drift))

	# ── 5. Lên thuyền + chèo + bẻ lái ─────────────────────────────────────
	print("-- 5. Lái thuyền --")
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
	driver.global_position = Vector3(2.5, 0.5, 0)
	_check(boat.is_player_nearby(driver), "người chơi gần thuyền → is_player_nearby")
	_check(boat.try_board(driver), "try_board thành công")
	_check(boat.is_driver(driver) and boat.is_driven(), "driver được gán")
	_check(driver.has_meta("driving_boat") and driver.get_meta("driving_boat") == boat,
		"player bị khóa điều khiển (meta)")
	_check(not boat.is_player_nearby(driver), "có tài xế → không cho lên thêm")
	_check(driver.get_node("CollisionShape3D").disabled, "shape người chơi bị tắt khi lên thuyền")
	_check(absf(driver.rotation.y - boat.rotation.y) > 3.0,
		"tài xế quay 180° nhìn về phía mũi (Δ=%s)" % str(absf(driver.rotation.y - boat.rotation.y)))
	await _wait_physics(45)
	_check(boat.global_position.y > 0.30, "có tài xế thuyền không chìm (y=%s)" % str(boat.global_position.y))

	var fwd0: Vector3 = boat.global_position
	Input.action_press("move_forward")
	await _wait_physics(60)
	Input.action_release("move_forward")
	var moved: float = fwd0.distance_to(boat.global_position)
	var fwd_speed: float = -boat.velocity.dot(Vector3(0, 0, 1))
	_check(fwd_speed > 2.0, "chèo tới đạt tốc độ tiến (v=%s)" % str(fwd_speed))
	_check(moved > 1.5, "thuyền di chuyển về phía trước (d=%s)" % str(moved))
	var rot_before: float = boat.rotation.y
	Input.action_press("move_left")
	await _wait_physics(30)
	Input.action_release("move_left")
	var rot_delta: float = absf(boat.rotation.y - rot_before)
	_check(rot_delta > 0.1, "bẻ lái trái khi đang chạy (Δ=%s)" % str(rot_delta))

	boat.try_exit()
	_check(not boat.is_driven(), "try_exit: hết tài xế")
	_check(not driver.has_meta("driving_boat"), "try_exit: nhả khóa điều khiển")
	_check(driver.global_position.distance_to(boat.global_position) < 6.0,
		"try_exit: người chơi đứng cạnh thuyền (d=%s)" % str(driver.global_position.distance_to(boat.global_position)))

	# ── 6. Mắc cạn trên bờ ─────────────────────────────────────────────────
	print("-- 6. Mắc cạn --")
	boat.global_position = Vector3(-13.0, 1.0, -13.0)
	boat.velocity = Vector3.ZERO
	await _wait_physics(60)
	var on_shore_y: float = boat.global_position.y
	_check(on_shore_y > 0.8 and on_shore_y < 1.1, "thuyền nằm trên bờ cát (y=%s)" % str(on_shore_y))
	var shore_speed: float = Vector2(boat.velocity.x, boat.velocity.z).length()
	Input.action_press("move_forward")
	await _wait_physics(45)
	Input.action_release("move_forward")
	var g_speed: float = Vector2(boat.velocity.x, boat.velocity.z).length()
	_check(g_speed < 0.15, "mắc cạn: chèo không đi nổi (speed=%s, trước %s)" % [str(g_speed), str(shore_speed)])

	# ── 7. Ray → mặt nước + đặt thuyền (placement) ────────────────────────
	print("-- 7. Chiếu ray xuống nước + đặt thuyền --")
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

	var wp: Vector3 = ps._ray_to_water_plane(Vector3(0, 5, 0), Vector3(0, -1, 0))
	_check(absf(wp.y - 0.5) < 0.001, "ray hướng xuống → giao mặt nước y=0.5")
	var wp2: Vector3 = ps._ray_to_water_plane(Vector3(0, 5, 0), Vector3(0, 1, 0))
	_check(absf(wp2.y - 5.0) < 0.001, "ray hướng lên → giữ nguyên điểm xuất phát")

	_check(ps._can_place_boat_pos(Vector3(0, 0.5, 0)), "ghost hợp lệ trên ao nước")
	_check(not ps._can_place_boat_pos(Vector3(-13.0, 0.5, -13.0)), "ghost không hợp lệ trên bờ")

	pinv.add_item(boat_def, 1)
	pinv.remove_item_by_id("fishing_boat", 1)
	ps._do_placement("fishing_boat", Vector3(-13.0, 0.5, -13.0))
	_check(world_root.get_node_or_null("FishingBoat") == null, "đặt trên bờ → bị chặn, trả lại item")
	_check(pinv.get_item_count("fishing_boat") == 1, "item thuyền được hoàn lại")

	ps._do_placement("fishing_boat", Vector3(0, 0.5, 0))
	var placed = world_root.get_node_or_null("FishingBoat")
	_check(placed != null, "đặt thuyền xuống ao → tạo entity FishingBoat")
	if placed:
		_check(placed.global_position.distance_to(Vector3(0, 0.5, 0)) < 0.01, "vị trí thuyền đúng điểm đặt")

	# ── 9. Nổi sau khi đặt (chunk lookup trong world thật) ─────────────────
	print("-- 9. Thuyền đặt xong tự nổi --")
	if placed:
		await _wait_physics(90)
		_check(absf(placed.global_position.y - 0.46) < 0.15, "thuyền đặt xuống tự nổi (y=%s)" % str(placed.global_position.y))

	# ── 10. Đèn thuyền: sáng đêm/mưa, tắt ban ngày ─────────────────────────
	print("-- 10. Đèn thuyền sáng đêm/mưa --")
	_check(boat._light_factor(12.0) == 0.0, "ban ngày đèn tắt (t=0)")
	_check(boat._light_factor(21.0) == 1.0, "đêm sâu đèn sáng tối đa (t=1)")
	var dusk_t: float = boat._light_factor(18.0)
	_check(dusk_t > 0.1 and dusk_t < 1.0, "chạng vạng đèn sáng dần (t=%s)" % str(dusk_t))
	var l0: Light3D = boat._boat_lights[0]
	boat._last_light_t = -1.0
	l0.light_energy = 0.0
	TimeSystem.set_hour(22.0)
	boat._update_lights(0.13)
	_check(l0.light_energy > 0.0, "đêm: đèn Omni bật dần (energy=%s)" % str(l0.light_energy))
	boat._last_light_t = 1.0
	l0.light_energy = 2.0
	TimeSystem.set_hour(12.0)
	boat._update_lights(0.13)
	_check(l0.light_energy < 2.0, "ban ngày: đèn Omni tắt dần (energy=%s)" % str(l0.light_energy))
	TimeSystem.force_weather(TimeSystem.Weather.RAIN)
	TimeSystem.set_hour(12.0)
	TimeSystem._weather_intensity = 1.0
	_check(boat._light_factor(12.0) > 0.5, "trời mưa ban ngày đèn bật (t=%s)" % str(boat._light_factor(12.0)))
	TimeSystem.force_weather(TimeSystem.Weather.CLEAR)
	TimeSystem._weather_intensity = 0.0

	# ── 11. Bọt khí chân vịt khi chạy ─────────────────────────────────────
	print("-- 11. Bọt khí chân vịt --")
	boat.global_position = Vector3(0, 0.5, 0)
	boat.velocity = Vector3(0, 0, -3.0)
	await _wait_physics(10)
	_check(boat._bubbles.emitting, "bọt khí phun khi thuyền chạy trên nước")
	boat.velocity = Vector3.ZERO
	await _wait_physics(20)
	_check(not boat._bubbles.emitting, "bọt khí ngừng khi đứng im")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
