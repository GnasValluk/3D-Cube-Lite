extends Node3D
## test_falling_damage — Rơi xuống đất từ cao → chịu sát thương rơi; ngược lại,
## bước xuống xe (có enable_exit_grace) không gây sát thương. Headless — không render.

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")

const FLOOR_Y: float = 0.0        # mặt đất (top của hộp va chạm)
const SAFE_Y: float = 0.55        # global_position.y khi đứng trên mặt đất (capsule center)
const FALL_FROM: float = 8.55     # 8m so với mặt đất → rơi ~8m

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _make_floor() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1.0, 40)
	col.shape = box
	body.add_child(col)
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector3(0, FLOOR_Y - 0.5, 0)
	add_child(body)


func _new_player() -> PlayerCharacter:
	var p := _PlayerChar.new()
	add_child(p)
	return p


func _wait_settled(p: PlayerCharacter) -> void:
	# Đặt ngay trên mặt đất, chờ vận tốc bề mặt ổn định.
	p.global_position = Vector3(0, SAFE_Y, 0)
	p.velocity = Vector3.ZERO
	for _i in range(30):
		await get_tree().physics_frame


func _drop_and_land(p: PlayerCharacter, use_grace: bool) -> int:
	p.global_position = Vector3(0, FALL_FROM, 0)
	p.velocity = Vector3.ZERO
	if use_grace:
		p.enable_exit_grace(2.0)
	var hp0: int = p.hp
	for _i in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(p):
			break
	return p.hp - hp0


func _ready() -> void:
	print("== test_falling_damage: rơi từ cao + xe grace ==")
	_make_floor()
	await get_tree().physics_frame

	# ── 1. Rơi 8m không grace → mất HP (≤4 giảm) ─────────────────────────────────
	var p := _new_player()
	await get_tree().process_frame
	await get_tree().physics_frame
	await _wait_settled(p)
	var lost := await _drop_and_land(p, false)
	_check(p.is_alive, "rơi 8m: vẫn sống (hp=%d)" % p.hp)
	_check(lost < 0, "rơi 8m: mất HP từ sát thương rơi (lost=%d)" % lost)
	_check(absi(lost) <= 5, "rơi 8m: sát thương hợp lý (lost=%d)" % lost)

	# Sanity: rơi nhẹ (1.5m) không mất HP.
	p.hp = p.max_hp
	p.global_position = Vector3(0, SAFE_Y + 1.5, 0)
	p.velocity = Vector3.ZERO
	for _i in range(60):
		await get_tree().physics_frame
	_check(p.hp == p.max_hp, "rơi 1.5m: không mất HP (hp=%d)" % p.hp)

	# ── 2. Rơi 8m nhưng có exit grace → không mất HP ─────────────────────────────
	p.hp = p.max_hp
	p.global_position = Vector3(0, SAFE_Y, 0)
	p.velocity = Vector3.ZERO
	for _i in range(30):
		await get_tree().physics_frame
	lost = await _drop_and_land(p, true)
	_check(p.hp == p.max_hp, "bước xuống xe grace + rơi 8m: không mất HP (lost=%d)" % lost)

	p.queue_free()
	get_tree().quit(0 if _failures == 0 else 1)
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
