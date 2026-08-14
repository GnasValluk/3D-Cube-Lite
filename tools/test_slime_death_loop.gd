extends Node3D

## Reproduce bug thật: slime KHÔNG bị free sau khi giết player (khác với
## test_slime_kill_respawn). Player respawn về (0,3,0) ngay cạnh slime còn sống.
## Kiểm tra: sau respawn player phải được miễn nhiễm (i-frame) để không bị
## slime đang đứng sát giết lại ngay = death loop.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_slime_death_loop: i-frame sau respawn chặn death loop ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	for i in range(300):
		await get_tree().process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return

	player.global_position = Vector3(0, 3, 0)
	await get_tree().physics_frame

	# Slime sống đứng sát điểm respawn, sát thương lớn.
	var slime := load("res://scripts/characters/slime/slime_character.gd").new() as CharacterBase
	slime.global_position = player.global_position + Vector3(0.6, 0, 0)
	world.add_child(slime)
	slime._player = player
	slime.attack_power = 999
	slime._attack_cd = 0.0
	await get_tree().physics_frame

	# Lần chết đầu
	player.take_damage(9999, slime)
	_check(not player.is_alive, "player chết lần 1")
	_check(slime.is_alive, "slime VẪN SỐNG (khác test cũ)")

	# Không free slime. Chờ đến đúng frame player respawn (is_alive chuyển true
	# sau khi hết death_timer 1.8s), đo invul ngay tại thời điểm đó.
	var respawn_found := false
	var respawn_invul: float = -1.0
	for i in range(250):
		await get_tree().physics_frame
		if player.is_alive:
			respawn_found = true
			respawn_invul = player._invul_timer
			break
	_check(respawn_found, "player respawn được (is_alive=true)")
	print("DEBUG invul ngay sau respawn = ", respawn_invul)
	_check(respawn_invul > 0.0, "có i-frame ngay sau respawn (invul=%.2f)" % respawn_invul)

	# Trong cửa sổ i-frame, player phải SỐNG dù slime đứng sát (cửa sổ này
	# thực tế ~invul giây vì timer bị trừ ở cả _process lẫn _physics_process).
	var survived := true
	var died_frame: int = -1
	for i in range(60):
		await get_tree().physics_frame
		if not player.is_alive:
			survived = false
			died_frame = i
			break
	if survived:
		_check(true, "i-frame giữ player sống trọn cửa sổ 60 frame sau respawn")
	else:
		_check(false, "player chết lại trong cửa sổ i-frame (frame %d)" % died_frame)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)