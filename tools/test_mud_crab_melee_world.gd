extends Node

## test_mud_crab_melee_world — cua bùn spawn trong world thật có nhận sát thương?
## Spawn cua theo cách chunk pipeline (ở đây spawn trực tiếp cạnh player trong
## world thật), player cầm kiếm sắt melee → phải giảm hp.

const _Crab = preload("res://scripts/world/props/mud_crab_prop.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260817)
	print("== test_mud_crab_melee_world ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	for i in range(240):
		await get_tree().process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có node Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return

	if player.equipped_weapon == null:
		player.equipped_weapon = ItemDatabase.items_db.get("iron_sword")

	var crab := _Crab.new(_Crab.MAX_HP, _Crab.WeaponReq.NONE, "mud_crab")
	world.add_child(crab)
	crab.global_position = player.global_position + Vector3(0, 0, 1.0)
	await get_tree().physics_frame
	_check(crab.is_in_group("destroyable_props"), "cua vào group destroyable_props")
	var hp0: int = crab.hp
	player.rotation.y = 0.0
	# ── Đánh theo đúng luồng ATTACK thật (không gọi _do_melee_hit trực tiếp) ──
	player._state = player.State.ATTACK
	player.attack_duration = 0.5
	player._melee_hit_progress = 0.25
	player._attack_timer = 0.5
	player._melee_hit_once = false
	for i in 15:
		await get_tree().physics_frame
	_check(crab.hp < hp0, "melee trong world thật gây sát thương cua (%d → %d)" % [hp0, crab.hp])

	if is_instance_valid(crab):
		crab.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)