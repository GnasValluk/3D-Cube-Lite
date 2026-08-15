extends Node

## Probe: đo offset hitbox của mũi tên so với bề mặt thật.
## Đặt 1 mặt đất box (top = y=0.25), bắn mũi tên từ trên xuống,
## ghi lại Y tại đó mũi tên báo đã dính (so với mặt đất thật).

const PROBE_TIME := 4.0

var _failures: int = 0
var _hit_pos: Vector3 = Vector3.ZERO
var _timed_out: bool = false

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== probe hitbox mũi tên: bề mặt box ai đúng? ==")

	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.5, 6)
	cs.shape = box
	ground.add_child(cs)
	add_child(ground)

	var arrow := ArrowProjectile.new()
	arrow.arrow_hit.connect(_on_arrow_hit)
	add_child(arrow)
	arrow.setup(Vector3.DOWN, 10, 30.0, 50.0, self)
	arrow.global_position = Vector3(0, 5.0, 0)

	# Chờ cho đến khi mũi tên dính hoặc hết giờ
	var t := 0.0
	while t < PROBE_TIME and _hit_pos == Vector3.ZERO and not _timed_out:
		await get_tree().physics_frame
		t += 1.0 / 60.0

	if _hit_pos != Vector3.ZERO:
		print("DEBUG hit_y=%.3f (mặt đất top=0.25)" % _hit_pos.y)
		_check(_hit_pos.y > 0.25, "mũi tên dừng TRÊN mặt đất (không ăn sâu)")
		_check(absf(_hit_pos.y - 0.25) <= 0.5, "offset ≤ nửa block (0.5)")
	else:
		print("DEBUG không dính (timeout)")
		_check(false, "mũi tên đã dính vào mặt đất")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _on_arrow_hit(pos: Vector3) -> void:
	_hit_pos = pos