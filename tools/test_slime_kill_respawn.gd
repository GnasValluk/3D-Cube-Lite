extends Node3D

## Reproduce: slime giết player trong world thật → player phải hồi sinh.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_slime_kill_respawn: slime giết player → hồi sinh ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	for i in range(300):
		await get_tree().process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có node Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return

	# Đặt slime ngay cạnh player, buff sát thương cực lớn để giết nhanh
	var slime := load("res://scripts/characters/slime/slime_character.gd").new() as CharacterBase
	slime.global_position = player.global_position + Vector3(0.6, 0, 0)
	world.add_child(slime)
	slime._player = player
	slime.attack_power = 999
	slime._attack_cd = 0.0
	await get_tree().physics_frame
	_check(slime.is_alive, "slime sống")
	print("DEBUG player pos=", player.global_position, " slime pos=", slime.global_position)

	var died := false
	for i in range(300):
		await get_tree().physics_frame
		if not player.is_alive:
			died = true
			print("DEBUG player died at frame", i, " state=", player._state,
				" dtimer=", player._death_timer, " chest=", player._death_chest_spawned)
			break
	_check(died, "player bị slime giết")
	if not died:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return

	# Loại bỏ slime ngay sau khi giết → không re-kill sau khi hồi sinh
	if is_instance_valid(slime):
		slime.queue_free()
	await get_tree().physics_frame

	# Chờ qua death_timer 1.8s + margin
	for i in range(150):
		await get_tree().physics_frame

	_check(player.is_alive, "player hồi sinh lại sau khi bị slime giết (is_alive=%s)" % player.is_alive)
	_check(player._active, "player active lại (_active=%s)" % player._active)
	_check(player.is_physics_processing(), "physics bật lại sau hồi sinh")
	_check(player.is_processing_unhandled_input(), "input bật lại sau hồi sinh")

	var chest: Node = get_tree().current_scene.get_node_or_null("DeathChest")
	_check(chest != null, "rương đồ spawn tại điểm chết")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
