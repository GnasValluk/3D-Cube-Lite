extends Node3D

## Reproduce faithfully: night + real SlimeSpawner + real slime packs tấn công.
## Chạy trong environment thật: world là current_scene (để slime tìm player qua
## CharacterManager), TimeSystem là autoload nên đọc trực tiếp.
## Mục tiêu: phát hiện player bị KẸT CHẾT (không respawn, physics tắt) vô hạn.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_slime_spawner_respawn: night + spawner thật, không kẹt chết ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	var tree := get_tree()
	# World phải là current_scene để slime _find_player() hoạt động
	tree.root.add_child(world)
	tree.current_scene = world
	for i in range(300):
		await tree.process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(tree)
		tree.quit(1)
		return

	# Ép giờ đêm 20h để SlimeSpawner hoạt động (17h-6h)
	TimeSystem.set_hour(20.0)
	print("DEBUG hour=", TimeSystem.get_hour())

	# Ép spawner chạy ngay nhiều vòng để tạo đủ pack quanh player.
	var spawner: Node = world.get_node_or_null("SlimeSpawner")
	_check(spawner != null, "world có SlimeSpawner")
	if spawner:
		spawner._timer = 999.0
	for i in range(180):
		await tree.process_frame
	var alive_slimes := 0
	if spawner:
		for p in spawner._packs:
			alive_slimes += p.alive_count()
	print("DEBUG pack_count=", spawner._packs.size() if spawner else -1,
		" alive=", alive_slimes)
	_check(alive_slimes > 0, "slime pack đã spawn (alive=%d)" % alive_slimes)

	# Đưa player về spawn rồi ép chết liên tục; slime thật trong world tấn công.
	player.global_position = Vector3(0, 3, 0)
	var deaths := 0
	var stuck_seconds := 0.0
	var alive_seconds := 0.0
	var never_respawned := false
	player.take_damage(9999, null)
	_check(not player.is_alive, "player chết lần đầu")

	for i in range(2400):
		await tree.physics_frame
		if not player.is_alive:
			if alive_seconds > 1.5:
				deaths += 1
			alive_seconds = 0.0
			stuck_seconds += 1.0 / 60.0
			if stuck_seconds > 10.0:
				never_respawned = true
				print("DEBUG STUCK: is_alive=", player.is_alive,
					" active=", player._active,
					" physics=", player.is_physics_processing(),
					" dtimer=", player._death_timer,
					" state=", player._state)
				break
		else:
			stuck_seconds = 0.0
			alive_seconds += 1.0 / 60.0
			if deaths >= 1 and alive_seconds >= 5.0:
				break
	print("DEBUG deaths=%d stuck=%.2fs alive_final=%.2fs" % [deaths, stuck_seconds, alive_seconds])

	_check(not never_respawned, "player KHÔNG bị kẹt chết >10s")
	_check(player._active, "player active cuối (_active=%s)" % player._active)
	_check(player.is_physics_processing(), "physics còn chạy cuối")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(tree)
	tree.quit(0 if _failures == 0 else 1)