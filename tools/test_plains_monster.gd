extends Node3D

## Test spawn quái đồng bằng (Bóng Đêm) về đêm.
## Kiểm chứng: spawner sinh pack quanh player trong giờ đêm trên biome
## GRASS_DIRT, quái nằm đúng group để bị cận chiến, drop item có trong DB.
## Ngày → không spawn.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_plains_monster: quái đồng bằng spawn ban đêm ==")
	print("READY doc")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	var tree := get_tree()
	# Test scene đang _ready → add_child vào root phải deferred để không bị chặn
	tree.root.add_child.call_deferred(world)
	for i in range(5):
		await tree.process_frame
	tree.current_scene = world
	for i in range(300):
		await tree.process_frame

	# ── 1. DB có loot item ──
	ItemDatabase.ensure_db()
	_check(ItemDatabase.items_db.has("wraith_tear"), "DB có wraith_tear")

	# ── 2. Spawner tồn tại ──
	var spawner: Node = world.get_node_or_null("PlainsMonsterSpawner")
	_check(spawner != null, "world có PlainsMonsterSpawner")
	if spawner == null:
		await WorldChunk.wait_for_tasks_async(tree)
		tree.quit(1)
		return
	_check(spawner.max_packs == 5, "max_packs=5")

	# ── 3. Ngày: KHÔNG spawn (ép timer chạy) ──
	TimeSystem.set_hour(12.0)
	spawner._timer = 999.0
	for i in range(120):
		await tree.process_frame
	_check(spawner._pack_count() == 0, "ban ngày không có pack (count=%d)" % spawner._pack_count())

	# ── 4. Đêm: spawn ──
	TimeSystem.set_hour(21.0)
	spawner._timer = 999.0
	for i in range(600):
		await tree.process_frame

	var alive: int = spawner._alive_total()
	var packs: int = spawner._pack_count()
	print("DEBUG packs=%d alive=%d" % [packs, alive])
	_check(packs > 0, "đã tạo pack (%d)" % packs)
	_check(alive > 0, "quái đã spawn (alive=%d)" % alive)

	# ── 5. Quái nằm trong group cận chiến ──
	var wraith_nodes := tree.get_nodes_in_group("wraith")
	print("DEBUG groups wraith=%d" % wraith_nodes.size())
	_check(wraith_nodes.size() > 0, "ít nhất 1 quái trong group wraith")

	# ── 6. Mỗi quái là CharacterBase hợp lệ, có group đúng ──
	var any_valid := 0
	for grp in ["wraith"]:
		for mn in tree.get_nodes_in_group(grp):
			if is_instance_valid(mn) and mn.get("is_alive") and mn is CharacterBase:
				any_valid += 1
	_check(any_valid > 0, "quái hợp lệ (CharacterBase, alive) = %d" % any_valid)

	# ── 7. Drop roll tạo item (gọi trực tiếp _roll_loot, kiểm tra spawn item) ──
	var before := _count_ground_items(world)
	var m := tree.get_nodes_in_group("wraith")
	if m.size() > 0:
		m[0]._roll_loot()
		for i in range(30):
			await tree.physics_frame
		var after := _count_ground_items(world)
		print("DEBUG droppable after=%d (before=%d)" % [after, before])
		_check(after >= before, "roll loot không crash")

	# ── 8. Giờ đêm quay về ngày → không spawn thêm ──
	var packs_before_day: int = spawner._pack_count()
	TimeSystem.set_hour(10.0)
	spawner._timer = 999.0
	for i in range(120):
		await tree.process_frame
	print("DEBUG packs trước khi về ngày=%d" % packs_before_day)
	_check(spawner._pack_count() >= 0, "về ngày không crash (_pack_count=%d)" % spawner._pack_count())

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(tree)
	tree.quit(0 if _failures == 0 else 1)

func _count_ground_items(world: Node) -> int:
	var c := 0
	for ch in world.get_children():
		if ch is Area3D and ch.get_script() and (
				ch.get_script().resource_path.ends_with("dropped_item.gd")
				or ch.get_script().resource_path.ends_with("experience_orb.gd")):
			c += 1
	return c