extends Node

## Headless verification: aiming góc 3 (TPS) dành riêng cho 3 vũ khí.
## - Crossbow / Watermelon cannon: aim thẳng tới điểm thế giới crosshair đang trỏ
##   (giữ cả thành phần Y — kiểu bắn súng) thay vì flatten xuống mặt phẳng ngang.
## - Pumpkin mortar: phóng lựu — vận tốc (h, v) được giải sao cho đạn rơi ĐÚNG
##   điểm crosshair (bù chênh cao Y). Test mô phỏng quỹ ĐẠO hội tụ về target.
## Chạy qua tools/test_aim_tps.tscn.

const _PC = preload("res://scripts/characters/player/player_character.gd")
const _Bow = preload("res://scripts/characters/player/player_bow.gd")
const _Mortar = preload("res://scripts/characters/player/player_mortar.gd")
const _IDB = preload("res://scripts/items/core/item_database.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	WorldSeed.seed_value = 20260805
	seed(20260805)
	_IDB.ensure_db()

	var player := _PC.new()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	# ── 1. Crossbow TPS: aim dir giữ thành phần Y về điểm crosshair ──────────
	player.global_position = Vector3(0, 2, 0)
	player.rotation = Vector3.ZERO
	player.equipped_weapon = _IDB.items_db["crossbow"]
	player._use_tp = true
	player._bow_aiming = true
	player._bow_charge = player._bow_max_charge
	_Bow.update_aim(player, 0.016)
	_check(player._aim_tp_mode, "crossbow TPS: _aim_tp_mode = true")
	var target: Vector3 = player._aim_world_point
	_check(target != Vector3.ZERO, "crossbow TPS: có world aim point")
	var spawn_from: Vector3 = _Bow._muzzle_world(player)
	var to_target: Vector3 = target - spawn_from
	var aim_dir: Vector3 = to_target.normalized() if to_target.length_squared() > 0.01 else Vector3.FORWARD
	_check(absf(aim_dir.y) > 0.001, "crossbow TPS: aim_dir giữ thành phần Y (bắn theo độ dốc)")

	# ── 2. Nỏ nếu KHÔNG TP (iso): flatten như cũ, _aim_tp_mode = false ───────
	player._use_tp = false
	_Bow.update_aim(player, 0.016)
	_check(not player._aim_tp_mode, "crossbow ISO: _aim_tp_mode = false")

	# ── 3. Mortar TPS: quỹ đạo giải ra sẽ hạ cánh ngay điểm crosshair ────────
	player._use_tp = true
	player.global_position = Vector3(0, 3, 0)
	player.equipped_weapon = _IDB.items_db["pumpkin_mortar"]
	player._bow_aiming = true
	player._bow_charge = player._bow_max_charge
	_Mortar.update_aim(player, 0.016)
	var tgt: Vector3 = player._aim_world_point
	_check(tgt != Vector3.ZERO, "mortar TPS: có world aim point")
	var start_pos: Vector3 = player.global_position + Vector3(0, 0.8, 0) - player.global_transform.basis.z * 0.5
	if player._mesh and player._mesh.weapon_pivot:
		start_pos = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.35, 0)
	var h: float = player._mortar_launch_h
	var v: float = player._mortar_launch_v
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var horiz: Vector3 = tgt - start_pos
	horiz.y = 0.0
	var horiz_dist: float = horiz.length()
	var t_flight: float = horiz_dist / max(h, 0.5)
	var dir_h: Vector3 = horiz.normalized() if horiz_dist > 0.01 else -player.global_transform.basis.z
	var pred := Vector3(
		start_pos.x + dir_h.x * h * t_flight,
		start_pos.y + v * t_flight - 0.5 * g * t_flight * t_flight,
		start_pos.z + dir_h.z * h * t_flight)
	_check(t_flight > 0.0, "mortar TPS: tồn tại thời gian bay (t=%.2f)" % t_flight)
	_check(absf(pred.y - tgt.y) < 0.25, "mortar TPS: quỹ đạo hạ cánh sát crosshair (pred=%.2f tgt=%.2f)" % [pred.y, tgt.y])
	_check(v > 0.0, "mortar TPS: vận tốc đứng dương (phóng lên)")
	_check(h > 0.0, "mortar TPS: vận tốc ngang dương")
	_check(player._aim_tp_mode, "mortar TPS: _aim_tp_mode = true")

	# ── 4. Mortar ISO: rẽ nhánh iso không đánh dấu TP ────────────────────────
	player._use_tp = false
	_Mortar.update_aim(player, 0.016)
	_check(not player._aim_tp_mode, "mortar ISO: _aim_tp_mode = false")

	player.free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)