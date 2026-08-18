extends Node

## test_mud_crab — Cua Bùn giờ là SINH VẬT (CharacterBase):
##  - HP thấp (5); DAMAGE qua take_damage (nhận damage từ melee/bullet/halberd).
##  - Chân/càng được build + animate (position/rotation thay đổi qua _animate).
## Chạy qua tools/test_mud_crab.tscn (không chạy trực tiếp .gd).

const _Crab = preload("res://scripts/characters/crab/mud_crab_character.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_mud_crab: HP + animation ==")

	# ── 1. HP + damage (take_damage, không còn try_destroy) ──────────────────────
	var crab := _Crab.new()
	add_child(crab)
	crab.set_physics_process(false)  # headlessly chạy trực tiếp _animate, không move_and_slide
	crab.position = Vector3(0, 0.5, 0)
	await get_tree().process_frame
	_check(crab.max_hp == 5, "MAX_HP = 5 (có %d)" % crab.max_hp)
	_check(crab.hp == 5, "sống càn quan: hp = 5")
	_check(crab.hit_radius == 0.5, "hit_radius = 0.5 (ước đường ăn đòn)")
	_check(crab.is_in_group("crab"), "cua vào group 'crab' (sinh vật)")

	var ok := true
	for i in 4:
		crab._invul_timer = 0.0
		crab.take_damage(1, null, 0)
		if not (crab.is_alive and crab.hp > 0 and crab.hp <= 5):
			ok = false
	_check(ok and crab.hp == 1, "4 hit (damage 1) chưa chết (hp = %d)" % crab.hp)
	crab._invul_timer = 0.0
	var died := false
	crab.take_damage(1, null, 0)
	died = not crab.is_alive
	_check(died, "hit thứ 5 → chết (is_alive = false)")

	# ── 2. Animation: chân/càng build + _animate thay đổi position/rotation ──
	print("-- 2. Animation chân/càng --")
	var c2 := _Crab.new()
	add_child(c2)
	c2.set_physics_process(false)
	c2.position = Vector3(2, 0.5, 0)
	await get_tree().process_frame
	# _ready → _build_character gọi _build_crab_mesh → _legs/_claws populated
	_check(c2._legs.size() == 16, "16 chân (4 mỗi bên × 2 khúc × 2) — có %d" % c2._legs.size())
	_check(c2._claws.size() == 4, "4 mũm càng (2 mỗi bên × 2 khúc) — có %d" % c2._claws.size())
	var before_pos: Array[Vector3] = []
	var before_rot: Array[float] = []
	for l in c2._legs:
		before_pos.append(l.position)
		before_rot.append(l.rotation.x)
	for cl in c2._claws:
		before_pos.append(cl.position)
		before_rot.append(cl.rotation.y)
	# Chạy _animate + nhảy khung để thời gian thực tiến → chân/càng thay đổi
	for i in 20:
		c2._animate(1.0 / 60.0)
		await get_tree().process_frame
	if is_instance_valid(c2):
		var moved := false
		var idx := 0
		for l in c2._legs:
			if l.position.distance_squared_to(before_pos[idx]) > 0.0001:
				moved = true
			idx += 1
		for cl in c2._claws:
			if cl.rotation.y > 0.0 or cl.rotation.length() > 0.0:
				moved = true
		_check(moved, "chân/càng thay đổi position/rotation (animation hoạt động)")
		c2.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)