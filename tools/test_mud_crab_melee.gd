extends Node

## test_mud_crab_melee — cua bùn có nhận sát thương từ đòn melee player không?
## Repro lỗi "cua bùn không nhận sát thương": spawn cua bùn trước mặt player
## trong CharacterManager, gọi _do_melee_hit() → kiểm tra hp giảm.
## Chạy qua tools/test_mud_crab_melee.tscn.

const _Crab = preload("res://scripts/characters/crab/mud_crab_character.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260817)
	print("== test_mud_crab_melee: cua bùn nhận sát thương melee ==")
	ItemDatabase.ensure_db()

	var mgr := CharacterManager.new()
	mgr.name = "CharacterManager"
	add_child(mgr)
	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/characters/player/player_character.gd"))
	player.set("_is_player", true)
	player.name = "Player"
	mgr.add_child(player)
	player.set_physics_process(false)

	# Player cầm kiếm sắt (atk_bonus > 0) để chắc chắn có sát thương
	if player.equipped_weapon == null:
		player.equipped_weapon = ItemDatabase.items_db.get("iron_sword")

	# Cua bùn ngay trước mặt player (cùng mực Y, hướng +Z)
	var crab := _Crab.new()
	add_child(crab)
	crab.set_physics_process(false)
	crab.position = player.global_position + Vector3(0, 0, 1.0)
	await get_tree().process_frame
	_check(crab.hp > 0 and crab.hp <= crab.max_hp, "cua ban đầu hp = %d" % crab.hp)
	_check(absf(crab.hit_radius - 0.5) < 0.001, "cua hit_radius = 0.5 (có %s)" % crab.hit_radius)

	var hp0: int = crab.hp
	player.rotation.y = 0.0
	player._do_melee_hit()
	_check(crab.hp < hp0, "melee gây sát thương cua bùn (%d → %d)" % [hp0, crab.hp])

	# ── Bỏ vũ khí (tay không): melee_range 2.2 → với hit_radius ăn được ở ~2.6m ──
	player.equipped_weapon = null
	var crab_far := _Crab.new()
	add_child(crab_far)
	crab_far.set_physics_process(false)
	crab_far.position = player.global_position + Vector3(0, 0, 2.6)
	await get_tree().process_frame
	player.rotation.y = 0.0
	var hp_far: int = crab_far.hp
	player._do_melee_hit()
	_check(crab_far.hp < hp_far, "melee trúng cua cách 2.6m (hit_radius ăn theo) (%d → %d)" % [hp_far, crab_far.hp])

	# ── Đòn chết: cua mới, tay không (dmg 1) → vài đòn là chết ──
	var crab2 := _Crab.new()
	add_child(crab2)
	crab2.set_physics_process(false)
	crab2.position = player.global_position + Vector3(0, 0, 0.8)
	await get_tree().process_frame
	var guard := 0
	var last_hp2: int = crab2.hp
	while last_hp2 > 0 and guard < 10 and is_instance_valid(crab2):
		if is_instance_valid(crab2):
			crab2._invul_timer = 0.0
		player._do_melee_hit()
		guard += 1
		last_hp2 = crab2.hp if is_instance_valid(crab2) else 0
	_check(guard < 10 and (last_hp2 <= 0 or not is_instance_valid(crab2)), "cua chết sau %d đòn (hp cuối=%d)" % [guard, last_hp2])
	if is_instance_valid(crab2):
		crab2.queue_free()

	if is_instance_valid(crab_far):
		crab_far.queue_free()
	if is_instance_valid(crab):
		crab.queue_free()
	player.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)