extends Node3D

## Faithful reproduction: slime TỰ tấn công (qua _animate) giết player, KHÔNG free,
## liên tục nhiều chu kỳ chết → respawn → chết. Kiểm tra player KHÔNG BAO GIỜ bị
## kẹt chết vô hạn (is_alive=false + _death_timer không giảm = không respawn).

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_slime_autonomous_kill: slime tự tấn công → respawn liên tục ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	var tree := get_tree()
	# current_scene là world để mọi thứ trong world tìm đúng player
	tree.current_scene = world
	for i in range(300):
		await tree.process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(tree)
		tree.quit(1)
		return

	# Slime đặt tại đúng WORLD_SPAWN_POS — nó sẽ tự _animate tấn công.
	var slime := load("res://scripts/characters/slime/slime_character.gd").new() as CharacterBase
	slime.global_position = Vector3(0, 3, 0) + Vector3(0.8, 0, 0)
	world.add_child(slime)
	slime._player = player
	slime.attack_power = 8   # giết dần như slime LỚN thật
	slime._attack_cd = 0.0
	await tree.physics_frame
	_check(slime._player == player, "slime giữ ref player")

	# Giảm HP sao cho ~6 đòn tấn công là chết, đợi slime tự đánh.
	player.hp = 50
	player.max_hp = 50

	var deaths := 0
	var stuck := 0.0
	var max_alive := 0.0
	var ever_stuck := false
	for i in range(3600):   # ~60s game thật
		await tree.physics_frame
		if not player.is_alive:
			stuck += 1.0 / 60.0
			if stuck > 6.0:
				ever_stuck = true
				print("DEBUG STUCK chết vô hạn: dtimer=", player._death_timer,
					" physics=", player.is_physics_processing(),
					" active=", player._active)
				break
			# Phát hiện respawn: dtimer hết → respawn, is_alive true lại
		else:
			if stuck > 1.2 and deaths < 10:
				deaths += 1
			elif stuck <= 1.2:
				max_alive = max(max_alive, stuck)
			stuck = 0.0
			max_alive += 1.0 / 60.0
			if max_alive > 60.0:
				break  # sống quá lâu, kết thúc
	print("DEBUG deaths=%d max_alive=%.1fs ever_stuck=%s" % [deaths, max_alive, ever_stuck])

	_check(not ever_stuck, "player KHÔNG bị kẹt chết vô hạn (đã respawn %d lần)" % deaths)
	_check(deaths >= 1, "slime đã tự giết và player respawn lại (%d lần)" % deaths)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(tree)
	tree.quit(0 if _failures == 0 else 1)