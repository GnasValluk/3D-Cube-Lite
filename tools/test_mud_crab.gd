extends Node3D

## test_mud_crab — Cua bùn rừng ngập mặn: HP thấp (damage rõ rệt) + animation
## chân/càng sống động.
##  - MudCrabProp.MAX_HP = 5; mỗi hit (damage=1) giảm 1 HP; chết ở đúng 5 hit.
##  - chân/càng được build + animate (rotation/position thay đổi trong _process).
## Chạy qua tools/test_mud_crab.tscn (không chạy trực tiếp .gd).

const _Crab = preload("res://scripts/world/props/mud_crab_prop.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_mud_crab: HP + animation ==")

	# ── 1. HP + damage ──────────────────────────────────────────────────────
	print("-- 1. HP thấp: damage rõ rệt --")
	var crab := _Crab.new(_Crab.MAX_HP, _Crab.WeaponReq.NONE, "mud_crab")
	add_child(crab)
	crab.position = Vector3(0, 0.5, 0)
	_check(crab.max_hp == 5 and crab.max_hp == _Crab.MAX_HP, "MAX_HP = 5 (có %d)" % crab.max_hp)
	_check(crab.hp == 5, "sống càn quan: hp = 5")
	_check(crab.weapon_requirement == _Crab.WeaponReq.NONE, "yêu cầu vũ khí: NONE (chặt bằng bất kỳ)")

	var hits := 0
	var ok := true
	for i in 4:
		if not crab.try_destroy("iron_sword", 1):
			ok = false
	hits = 4
	_check(ok, "4 hit (damage 1) chưa chết")
	_check(crab.hp == 1, "sau 4 hit: hp = 1 (có %d)" % crab.hp)
	if crab.try_destroy("iron_sword", 1):
		_check(true, "hit thứ 5 → chết (try_destroy trả về true)")
	else:
		_check(false, "hit thứ 5 → chết (try_destroy trả về true)")
	_check(crab.hp == 0, "chết: hp = 0 (có %d)" % crab.hp)
	if is_instance_valid(crab):
		crab.queue_free()

	# ── 2. Animation: chân/càng được build + tham gia _process ─────────────
	print("-- 2. Animation chân/càng --")
	var c2 := _Crab.new(_Crab.MAX_HP, _Crab.WeaponReq.NONE, "mud_crab")
	add_child(c2)
	c2.position = Vector3(2, 0.5, 0)
	# _ready đã gọi _build_crab → _legs/_claws populated
	_check(c2._legs.size() == 16, "16 chân (4 mỗi bên × 2 khúc × 2) — có %d" % c2._legs.size())
	_check(c2._claws.size() == 4, "4 mũm càng (2 mỗi bên × 2 khúc) — có %d" % c2._claws.size())
	# Snapshot vị trí chân/càng ban đầu
	var before_pos := []
	var before_rot := []
	for l in c2._legs:
		before_pos.append(l.position)
		before_rot.append(l.rotation)
	for cl in c2._claws:
		before_pos.append(cl.position)
		before_rot.append(cl.rotation)
	# Bước một khung thời gian để _process chạy
	var t0 := Time.get_ticks_usec()
	var advanced := false
	var steps := 0
	while not advanced and steps < 1200:
		await get_tree().process_frame
		steps += 1
		if Time.get_ticks_usec() - t0 > 0.1:
			advanced = true
	_check(advanced, "_process chạy ≥0.1s")
	# Kiểm tra chân/càng thay đổi (animation sống động)
	var moved := false
	var idx := 0
	for l in c2._legs:
		if l.position.distance_squared_to(before_pos[idx]) > 0.0001:
			moved = true
	idx = 0
	for cl in c2._claws:
		if cl.rotation.length() > 0.0:
			moved = true
		idx += 1
	_check(moved, "chân/càng thay đổi position/rotation (animation hoạt động)")
	if is_instance_valid(c2):
		c2.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
