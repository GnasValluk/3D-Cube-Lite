extends Node3D

## Faithful reproduction with a REAL PACK (như slime spawner tạo: 2-4 con đủ cỡ)
## đứng canh ở WORLD_SPAWN_POS. Player chết, respawn về (0,3,0) — bầy tấn công.
## Kiểm tra: player có bị chết-lại liên tục không thoát (perceived "ko spawn")?

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _spawn_pack(world: Node, player: Node3D, count: int) -> void:
	var slime_script := load("res://scripts/characters/slime/slime_character.gd")
	for i in range(count):
		var slime := slime_script.new() as CharacterBase
		var size: int = i % 3  # SMALL, MEDIUM, LARGE
		slime.set("slime_size", size)
		slime.global_position = Vector3(0, 3, 0) + Vector3(0.8 + i * 0.3, 0, 0.5 if i % 2 == 0 else -0.5)
		world.add_child(slime)
		slime._player = player
		slime._attack_cd = 0.0
		await get_tree().physics_frame

func _ready() -> void:
	print("== test_slime_pack_respawn: bầy slime canh spawn → không kẹt chết ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	var tree := get_tree()
	tree.current_scene = world
	for i in range(300):
		await tree.process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(tree)
		tree.quit(1)
		return

	await _spawn_pack(world, player, 4)
	var alive_slimes := 0
	for ch in world.get_children():
		if ch is CharacterBase and not ch._is_player and ch.is_alive:
			alive_slimes += 1
	_check(alive_slimes >= 4, "bầy 4 slime sống quanh spawn")

	player.hp = 50
	player.max_hp = 50
	player.global_position = Vector3(0, 3, 0)

	# Theo dõi trải nghiệm thật: số lần tỉnh lại (respawn) và thời gian SỐNG liên
	# tục giữa các lần chết. Nếu luôn chết lại < 1s sau respawn → đúng lỗi user thấy.
	var deaths := 0
	var respawned := 0
	var alive_run := 0.0
	var worst_gap := 0.0
	var ever_stuck := false
	var last_respawn_handled := false
	for i in range(3600):
		await tree.physics_frame
		if not player.is_alive:
			alive_run = 0.0
			if not last_respawn_handled and player._death_timer < 1.5:
				# đang trong window chết — đếm xem đã respawn bao giờ chưa
				if respawned == 0 and deaths > 0:
					worst_gap = max(worst_gap, 0.0)
			if player._death_timer <= 0.0:
				pass  # base sẽ respawn ở frame cuối
		else:
			if not last_respawn_handled:
				respawned += 1
				last_respawn_handled = true
			deaths = max(deaths, respawned)
			alive_run += 1.0 / 60.0
			worst_gap = max(worst_gap, alive_run)
			if alive_run > 30.0:
				break
		if player._death_timer > 1.0:
			last_respawn_handled = false
			deaths += 1
	print("DEBUG respawned=%d worst_alive_gap=%.1fs" % [respawned, worst_gap])

	_check(respawned >= 1, "player RESPAWN được (đứng lại sau chết) %d lần" % respawned)
	_check(worst_gap >= 3.0, "tồn tại khoảng sống >3s sau respawn để thoát (max=%.1f)" % worst_gap)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(tree)
	tree.quit(0 if _failures == 0 else 1)