extends Node3D

## test_helicopter — Trực thăng cứu hộ: model voxel đỏ-trắng, bay được
## (W/S/A/D + SPACE/SHIFT), hover khi đứng yên, đèn beacon nhấp nháy,
## đặt xuống đất qua placement, phá huỷ bằng đòn heavy → rớt lại item.
## Chạy qua tools/test_helicopter.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Heli = preload("res://scripts/items/entities/rescue_helicopter.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD
const SEED := 20260811
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

## Đồng bằng cát phẳng: mặt đất top = 0.5 quanh toàn bộ chunk.
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

	print("== test_helicopter: Trực thăng cứu hộ ==")

	# ── 1. Item (không recipe — chỉ có ở thư viện vật phẩm) ─────────────────
	print("-- 1. Item --")
	ItemDatabase.ensure_db()
	var heli_def: ItemDef = ItemDatabase.items_db.get("rescue_helicopter") as ItemDef
	_check(heli_def != null, "item rescue_helicopter tồn tại trong db")
	_check(heli_def != null and heli_def.type == ItemDef.Type.TOOL, "trực thăng loại TOOL")
	_check(heli_def != null and not heli_def.stackable, "trực thăng không stack")

	# ── 2. Chunk + mặt đất ──────────────────────────────────────────────────
	print("-- 2. Mặt đất --")
	_chunk = _W.new()
	_chunk.name = "HeliChunk"
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

	var heli: Node = _Heli.new()
	heli.name = "TestHeli"
	add_child(heli)
	var g0: float = heli._ground_height_at(0.0, 0.0)
	_check(absf(g0 - 0.5) < 0.01, "mặt đất tại (0,0) = 0.5 (được %s)" % str(g0))
	_check(heli._chunk_at(0.0, 0.0) == _chunk, "chunk key world (0,0) → chunk (0,0)")

	# ── 3. Model ─────────────────────────────────────────────────────────────
	print("-- 3. Model --")
	_check(heli._rig != null, "rig chính tồn tại")
	_check(heli._rotor_hub != null, "hub cánh quạt tồn tại")
	_check(heli._tail_rotor != null, "cánh đuôi fenestron tồn tại")
	_check(heli._spotlight != null, "spotlight tồn tại")
	var rig_meshes: int = 0
	for ch in heli._rig.get_children():
		if ch is MeshInstance3D:
			rig_meshes += 1
	_check(rig_meshes >= 3, "mesh gộp theo material hiển thị (rig meshes=%d)" % rig_meshes)
	var rotor_children: int = 0
	for ch in heli._rotor_hub.get_children():
		if ch is MeshInstance3D:
			rotor_children += 1
	_check(rotor_children >= 2, "cánh quạt chính có mesh (meshes=%d)" % rotor_children)
	_check(heli._beacon_mat != null and heli._beacon_mat.emission_enabled, "beacon đỏ phát sáng")
	var mini := Node3D.new()
	ItemMesh.build(mini, "rescue_helicopter")
	_check(mini.get_child_count() > 0, "item có mini model cầm tay (%d boxes)" % mini.get_child_count())
	mini.queue_free()

	# ── 4. Không người lái → đáp nhẹ xuống đất ──────────────────────────────
	print("-- 4. Đáp đất --")
	heli.global_position = Vector3(0, 3.0, 0)
	heli.velocity = Vector3.ZERO
	await _wait_physics(90)
	print("  DEBUG hover y=", heli.global_position.y, " vel=", heli.velocity, " pos=", heli.global_position)
	_check(heli.global_position.y < 2.0, "không người lái → đáp nhẹ xuống (y=%s)" % str(heli.global_position.y))

	# ── 5. Lên lái + bay ────────────────────────────────────────────────────
	print("-- 5. Bay --")
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
	driver.global_position = heli.global_position + Vector3(2.0, 0, 0)
	_check(heli.is_player_nearby(driver), "người chơi gần máy bay → is_player_nearby")
	_check(heli.try_board(driver), "try_board thành công")
	_check(heli.is_driver(driver) and heli.is_driven(), "driver được gán")
	_check(driver.has_meta("driving_vehicle") and driver.get_meta("driving_vehicle") == heli,
		"player bị khóa điều khiển (meta driving_vehicle)")
	_check(driver.get_node("CollisionShape3D").disabled, "shape người chơi bị tắt khi lên máy bay")

	var y0: float = heli.global_position.y
	Input.action_press("jump")
	await _wait_physics(60)
	Input.action_release("jump")
	_check(heli.global_position.y > y0 + 1.0, "SPACE bay lên cao (Δy=%s)" % str(heli.global_position.y - y0))

	var pos0: Vector3 = heli.global_position
	Input.action_press("move_forward")
	await _wait_physics(60)
	Input.action_release("move_forward")
	var moved: float = pos0.distance_to(heli.global_position)
	var fwd_speed: float = heli._fwd_speed
	_check(fwd_speed > 2.0, "W tiến đạt tốc độ (v=%s)" % str(fwd_speed))
	_check(moved > 1.0, "trực thăng di chuyển về phía trước (d=%s)" % str(moved))

	var rot_before: float = heli.rotation.y
	Input.action_press("move_left")
	await _wait_physics(30)
	Input.action_release("move_left")
	var rot_delta: float = absf(heli.rotation.y - rot_before)
	_check(rot_delta > 0.05, "A bẻ lái xoay máy bay (Δ=%s)" % str(rot_delta))

	var y_top: float = heli.global_position.y
	Input.action_press("crouch")
	await _wait_physics(60)
	Input.action_release("crouch")
	_check(heli.global_position.y < y_top - 0.5, "SHIFT hạ độ cao (Δy=%s)" % str(heli.global_position.y - y_top))

	# ── 6. Xuống máy bay ────────────────────────────────────────────────────
	print("-- 6. Xuống --")
	heli.try_exit()
	_check(not heli.is_driven(), "try_exit: hết tài xế")
	_check(not driver.has_meta("driving_vehicle"), "try_exit: nhả khóa điều khiển")
	_check(driver.global_position.distance_to(heli.global_position) < 7.0,
		"try_exit: người chơi đứng gần máy bay (d=%s)" % str(driver.global_position.distance_to(heli.global_position)))
	await _wait_physics(60)
	_check(heli.global_position.y < 2.5, "không người lái → đáp xuống đất (y=%s)" % str(heli.global_position.y))

	# ── 7. Đèn beacon + spotlight theo giờ ──────────────────────────────────
	print("-- 7. Đèn --")
	_check(heli._light_factor(12.0) == 0.0, "ban ngày đèn tắt (t=0)")
	_check(heli._light_factor(21.0) == 1.0, "đêm sâu đèn sáng tối đa (t=1)")
	var dusk_t: float = heli._light_factor(18.0)
	_check(dusk_t > 0.1 and dusk_t < 1.0, "chạng vạng đèn sáng dần (t=%s)" % str(dusk_t))
	heli._spotlight.light_energy = 0.0
	heli._last_light_t = -1.0
	TimeSystem.set_hour(22.0)
	heli._update_lights(0.13)
	_check(heli._spotlight.light_energy > 0.0, "đêm: spotlight bật dần (energy=%s)" % str(heli._spotlight.light_energy))
	heli._beacon_timer = 0.0
	var e0: float = heli._beacon_mat.emission_energy_multiplier
	heli._update_lights(0.6)
	_check(heli._beacon_mat.emission_energy_multiplier != e0, "beacon đỏ nhấp nháy đổi cường độ (%s→%s)" % [str(e0), str(heli._beacon_mat.emission_energy_multiplier)])
	TimeSystem.set_hour(12.0)

	# ── 8. Đặt máy bay qua placement ────────────────────────────────────────
	print("-- 8. Placement --")
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

	pinv.add_item(heli_def, 1)
	pinv.remove_item_by_id("rescue_helicopter", 1)
	ps._do_placement("rescue_helicopter", Vector3(3.0, 0.5, 3.0))
	var placed = world_root.get_node_or_null("RescueHelicopter")
	_check(placed != null, "đặt trực thăng lên đất → tạo entity RescueHelicopter")
	if placed:
		_check(placed.global_position.distance_to(Vector3(3.0, 0.5, 3.0)) < 0.01, "vị trí đúng điểm đặt")
		_check(placed._rig != null, "entity đặt xuống có model")
	_check(pinv.get_item_count("rescue_helicopter") == 0, "item tiêu thụ sau khi đặt")

	# ── 9. Phá huỷ bằng đòn heavy ───────────────────────────────────────────
	print("-- 9. Phá huỷ --")
	if placed:
		_check(not placed.try_destroy("iron_sword"), "kiếm thường không phá được trực thăng")
		var hp_before: int = placed.hp
		_check(placed.try_destroy("axe"), "rìu (heavy) phá được trực thăng")
		_check(placed.hp < hp_before, "hp giảm sau đòn heavy")

	# ── 10. Entry point placement (UI): hud + build menu ────────────────────
	print("-- 10. Entry point placement --")
	var hud_script := load("res://scripts/ui/hud/hud.gd")
	var hud = hud_script.new()
	_check(hud._is_building_item(heli_def), "hud nhận trực thăng là item đặt được")
	_check(hud._is_building_item(ItemDatabase.items_db.get("tractor") as ItemDef),
		"hud vẫn nhận tractor là item đặt được")
	_check(not hud._is_building_item(ItemDatabase.items_db.get("axe") as ItemDef),
		"hud không nhận công cụ thường là item đặt được")
	hud.queue_free()
	var bm_script := load("res://scripts/building/build_menu.gd")
	var bm = bm_script.new()
	bm._setup_categories()
	var cat0: Array = bm._categories[0].ids
	_check("rescue_helicopter" in cat0, "build menu Công Trình có trực thăng")
	_check("tractor" in cat0 and "fishing_boat" in cat0, "build menu vẫn giữ các xe cũ")
	bm.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
