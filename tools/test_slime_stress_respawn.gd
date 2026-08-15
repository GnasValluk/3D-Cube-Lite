extends Node3D

## Stress: bầy slime CỠ LỚN tấn công liên tục quanh điểm spawn:
## player chết rồi respawn ngay tại điểm bầy canh → chết lại ngay.
## Mục tiêu phát hiện TRẠNG THÁI KẸT: player chết nhưng KHÔNG bao giờ respawn
## (is_alive=false kéo dài, _death_timer đứng im, không qua _do_respawn).

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _spawn_pack(world: Node, player: Node3D, count: int, dmg: int) -> void:
	var slime_script := load("res://scripts/characters/slime/slime_character.gd")
	for i in range(count):
		var slime := slime_script.new() as CharacterBase
		slime.set("slime_size", 2)  # LARGE — attack_power cao
		slime.set("attack_power", dmg)
		slime.global_position = Vector3(0, 3, 0) + Vector3(0.6 + i * 0.4, 0, 0.4 if i % 2 == 0 else -0.4)
		world.add_child(slime)
		slime._player = player
		slime._attack_cd = 0.0
		await get_tree().physics_frame

func _ready() -> void:
	print("== test_slime_stress_respawn: bầy slime LỚN canh spawn — phát hiện KẸT DEAD ==")
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

	# Player yếu: 1-2 đòn là chết — mô phỏng đang bị bầy vây.
	player.max_hp = 20
	player.hp = 20

	await _spawn_pack(world, player, 10, 12)

	player.global_position = Vector3(0, 3, 0)

	var deaths := 0
	var respawns := 0
	var stuck := 0.0          # thời gian liên tục is_alive=false mà _death_timer KHÔNG giảm
	var last_stuck_dt := -1.0 # lần đo _death_timer trước khi kẹt
	var ever_respawned := false
	var max_stuck := 0.0
	var max_dead_span := 0.0
	var dead_span := 0.0
	var prev_alive := true

	for i in range(3600):
		await tree.physics_frame
		var alive: bool = player.is_alive
		if not alive:
			dead_span += 1.0 / 60.0
			max_dead_span = max(max_dead_span, dead_span)
			if prev_alive:
				deaths += 1
				if deaths <= 3:
					print("DEBUG chet lan %d tai frame %d state=%d dt=%.2f" % [deaths, i, player._state, player._death_timer])
			# Phát hiện kẹt: _death_timer phải GIẢM mỗi frame khi _state==DEAD.
			# Nếu nó không đổi (hoặc tăng) > 3s → _state bị đè, không bao giờ respawn.
			if last_stuck_dt < 0.0:
				last_stuck_dt = player._death_timer
				stuck = 0.0
			else:
				if player._death_timer >= last_stuck_dt:
					stuck += 1.0 / 60.0
				else:
					stuck = 0.0
				last_stuck_dt = player._death_timer
			max_stuck = max(max_stuck, stuck)
		else:
			if not prev_alive:
				respawns += 1
				ever_respawned = true
				if respawns <= 3:
					print("DEBUG respawn #%d tai frame %d state=%d" % [respawns, i, player._state])
			dead_span = 0.0
			last_stuck_dt = -1.0
			stuck = 0.0
		prev_alive = alive

	print("DEBUG respawns=%d max_dead_span=%.2fs max_stuck=%.2fs" % [respawns, max_dead_span, max_stuck])

	_check(ever_respawned, "player vẫn RESPAWN được dưới bầy tấn công liên tục")
	_check(max_dead_span < 5.0, "không có lần chết nào kẹt >5s (max_dead_span=%.2f)" % max_dead_span)
	_check(max_stuck < 2.0, "_death_timer không bị kẹt dừng giảm (max_stuck=%.2f)" % max_stuck)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(tree)
	tree.quit(0 if _failures == 0 else 1)