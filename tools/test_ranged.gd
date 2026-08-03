extends Node

## Headless verification: đã bỏ cooldown cho vũ khí tầm xa + ném kích,
## và đòn cận chiến chỉ kích hoạt khi GIỮ chuột trái (không tái kích khi thả chuột).
## Chạy qua tools/test_ranged.tscn (không chạy trực tiếp file .gd).

const _PC = preload("res://scripts/characters/player/player_character.gd")
const _IDB = preload("res://scripts/items/core/item_database.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _make_lmb(pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	return ev

func _ready() -> void:
	seed(20260805)

	# ── 1. Bảng cooldown đã được gỡ hoàn toàn ──────────────────────────────
	var pc_src: String = FileAccess.get_file_as_string("res://scripts/characters/player/player_character.gd")
	_check(not pc_src.contains("RANGED_COOLDOWNS"), "không còn hằng RANGED_COOLDOWNS")
	var pc = _PC.new()
	_check(not pc.has_method("_ranged_on_cd"),  "không còn _ranged_on_cd")
	_check(not pc.has_method("_set_ranged_cd"), "không còn _set_ranged_cd")
	_check(not pc.has_method("_tick_ranged_cd"),"không còn _tick_ranged_cd")
	_check(pc.get("_ranged_cd") == null, "không còn biến _ranged_cd")
	pc.free()

	# ── 2. Đòn cận chiến chỉ kích hoạt khi LMB nhấn (đã sửa animation giật) ──
	_IDB.ensure_db()
	var player: Node = _PC.new()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.equipped_weapon = _IDB.items_db["iron_sword"]

	player._unhandled_input(_make_lmb(true))
	_check(player._attack_timer > 0.0, "LMB nhấn → bắt đầu 1 đòn (attack_timer>0)")
	var first_timer: float = player._attack_timer
	var first_step: int = player.combo_step

	# LMB thả — KHÔNG được tái kích hoạt đòn lần nữa (trước đây giật/animation bị restart liên tục)
	player._unhandled_input(_make_lmb(false))
	_check(is_equal_approx(player._attack_timer, first_timer), "LMB thả → attack_timer không bị restart")
	_check(player.combo_step == first_step, "LMB thả → combo_step không tăng")

	# Nhấn LMB lại trong cửa combo → tiến combo bình thường
	player._unhandled_input(_make_lmb(true))
	_check(player.combo_step == 1, "nhấn tiếp theo → combo_step = 1")
	_check(player._attack_timer > 0.0, "nhấn tiếp theo → vẫn tấn công")
	player.free()

	# ── 3. Weapon đặc biệt không gọi cooldown ───────────────────────────────
	var halberd_src: String = FileAccess.get_file_as_string("res://scripts/characters/player/player_halberd.gd")
	var bow_src: String = FileAccess.get_file_as_string("res://scripts/characters/player/player_bow.gd")
	var mortar_src: String = FileAccess.get_file_as_string("res://scripts/characters/player/player_mortar.gd")
	_check(not halberd_src.contains("_ranged_on_cd"), "halberd không gọi _ranged_on_cd")
	_check(not halberd_src.contains("_set_ranged_cd"), "halberd không gọi _set_ranged_cd")
	_check(not bow_src.contains("_ranged_on_cd"), "bow không gọi _ranged_on_cd")
	_check(not bow_src.contains("_set_ranged_cd"), "bow không gọi _set_ranged_cd")
	_check(not mortar_src.contains("_ranged_on_cd"), "mortar không gọi _ranged_on_cd")
	_check(not mortar_src.contains("_set_ranged_cd"), "mortar không gọi _set_ranged_cd")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)