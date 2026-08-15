extends Node3D

## Verify death+respawn with items equipped and in FP camera mode —
## scenarios a real player hits that empty-inventory tests miss.

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_respawn_equipped: chết khi đang trang bị + FP cam ==")
	ItemDatabase.ensure_db()
	var p := _PlayerChar.new()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	# Trang bị vũ khí + giáp để phủ đường add_item(equipped) trong death chest.
	var db: Dictionary = ItemDatabase.items_db
	if db.has("iron_sword"):
		p.equipped_weapon = db["iron_sword"]
	if db.has("iron_helmet"):
		p.equipped_head = db["iron_helmet"]
	_check(p.equipped_weapon != null, "trang bị vũ khí trước khi chết")

	# Bật FP camera (F1) — model player bị ẩn.
	p._is_player = true
	p._use_tp = false
	p._sync_camera()
	var has_fp_rig: bool = p._fp_rig != null
	if has_fp_rig:
		_check(p._rig == null or p._rig.visible == false, "FP: rig ẩn khi sống (visible=%s)" % (p._rig.visible if p._rig else "no-rig"))

	p.take_damage(9999, null)
	_check(not p.is_alive, "player chết")

	for i in range(150):
		await get_tree().physics_frame

	_check(p.is_alive, "player hồi sinh (is_alive=%s)" % p.is_alive)
	_check(p._active, "player active sau hồi sinh")
	_check(p.is_physics_processing(), "physics bật lại")
	_check(p.equipped_weapon == null, "vũ khí bị tháo khi chết (đã cho rương)")

	# Sau respawn ở FP mode: rig phải ẩn lại (không được hiện model chặn cam).
	if has_fp_rig:
		_check(p._rig == null or p._rig.visible == false, "FP: rig vẫn ẩn sau respawn (visible=%s)" % (p._rig.visible if p._rig else "no-rig"))

	# Đồ rơi vương vãi thay rương: vũ khí đã trang bị phải drop thành DroppedItem.
	var sword_dropped := false
	for ch in get_children():
		if ch is DroppedItem and ch.item_def != null and ch.item_def.id == "iron_sword":
			sword_dropped = true
			break
	_check(sword_dropped, "vũ khí đã trang bị rơi thành DroppedItem sau khi chết")
	var no_chest := true
	for ch in get_children():
		if ch.name == "DeathChest":
			no_chest = false
			break
	_check(no_chest, "không còn rương đồ")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)