extends Node3D

## Headless verification: slime nhảy lò cò khi lang thang (không có player gần),
## không chỉ khi đuổi theo player.

const _Slime = preload("res://scripts/characters/slime/slime_character.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_slime_hop_wander: slime nhảy khi lang thang ==")
	ItemDatabase.ensure_db()
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60, 1, 60)
	floor_col.shape = floor_box
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(0, -1.5, 0)
	add_child(floor_body)
	var s := _Slime.new()
	s.global_position = Vector3(0, 3, 0)
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check(s.is_alive, "slime sống")
	for i in range(60):
		await get_tree().physics_frame
		if s.is_on_floor():
			break
	print("DEBUG floor=%s y=%.1f vel=%s" % [s.is_on_floor(), s.global_position.y, s.velocity])
	_check(s.is_on_floor(), "slime đứng trên sàn (wander mode)")

	# Đếm cú nhảy thật bằng vận tốc dương (hop → velocity.y = _jump_v > 1)
	var hop_count := 0
	var in_hop := false
	for i in range(420):
		if s.velocity.y > 1.0 and not in_hop:
			hop_count += 1
			in_hop = true
		elif s.velocity.y <= 0.0:
			in_hop = false
		await get_tree().physics_frame
		if hop_count > 2:
			break

	_check(hop_count > 2, "slime lang thang nhảy lò cò đều (hops=%d)" % hop_count)

	# Kiểm tra không bị đổi hướng đuổi (vẫn quanh spawn, không lao xa một phía)
	var dist := s.global_position.distance_to(Vector3.ZERO)
	_check(dist < 10.0, "slime lang thang quanh spawn, không đi xa (dist=%.1f)" % dist)
	_check(s.move_speed < s._base_move_speed,
		"tốc độ lang thang đã giảm mạnh (move=%.2f base=%.2f)" % [s.move_speed, s._base_move_speed])

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)