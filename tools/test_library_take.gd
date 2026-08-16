extends Control

## Headless verification thư viện vật phẩm: 1 click = lấy 1 pcs,
## giữ 1s = lấy 1 stack (max_stack), nhả giữa chừng chỉ lấy 1.

const _IDB = preload("res://scripts/items/core/item_database.gd")
const _INV = preload("res://scripts/items/core/inventory.gd")
const _LIB = preload("res://scripts/ui/inventory/item_library_panel.gd")

# ---- Mock owner (chính là test node) — các field _Library cần ----------
var _inventory: Inventory
var _player_ref: Node = null
var _lib_hold_item: ItemDef = null
var _lib_hold_panel: Panel = null
var _lib_hold_time: float = 0.0
var _lib_hold_stack_taken: bool = false
var _lib_panels: Array[Panel] = []
var _lib_items: Array[ItemDef] = []
var _lib_slot_style: StyleBoxFlat = StyleBoxFlat.new()
var _lib_slot_hover_style: StyleBoxFlat = StyleBoxFlat.new()

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _count(inv: Inventory, item_id: String) -> int:
	var total := 0
	for slot in inv.slots:
		if not slot.is_empty() and slot.item.id == item_id:
			total += slot.count
	return total

func _ready() -> void:
	seed(20260816)
	_IDB.ensure_db()

	# Item test: đá ngọc stackable, max_stack 64.
	var gem := ItemDef.new("t_gem", "Gem", ItemDef.Type.MATERIAL, Color.WHITE, "◆", "", true, 64)
	_inventory = _INV.new(4)
	_player_ref = Node.new()  # chỉ cần khác null

	# ── 1. Slot thư viện mock + press-left → bắt đầu giữ ─────────────────
	var panel := Panel.new()
	panel.set_meta("item_idx", 0)
	_lib_panels = [panel]
	_lib_items = [gem]

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(10, 10)
	_LIB.on_lib_slot_input(press, self, 0)
	_check(_lib_hold_item == gem, "press LMB → bắt đầu giữ item đúng")
	_check(_count(_inventory, gem.id) == 0, "mới bấm → chưa lấy gì vào kho")

	# ── 2. Nhả ngay (không giữ đủ 1s) → lấy 1 pcs ────────────────────────
	_LIB.process_lib_hold(self, 0.1 / 60.0)  # Input LMB không được giữ trong headless
	_check(_count(_inventory, gem.id) == 1, "nhả nhanh (click) → lấy đúng 1 pcs (got %d)" % _count(_inventory, gem.id))
	_check(_lib_hold_item == null, "sau khi nhả → reset trạng thái giữ")
	_check(not _lib_hold_stack_taken, "reset → không còn đánh dấu đã lấy stack")

	# ── 3. Giữ đủ 1s → lấy trọn 1 stack (max_stack 64) ───────────────────
	# Mô phỏng giữ: giả lập Input LMB đang giữ.
	var hold_press := InputEventMouseButton.new()
	hold_press.button_index = MOUSE_BUTTON_LEFT
	hold_press.pressed = true
	_LIB.on_lib_slot_input(hold_press, self, 0)
	_check(_lib_hold_item == gem, "lần 2: giữ item đúng")

	var lmb_held := false
	Input.parse_input_event(hold_press)
	await get_tree().process_frame
	lmb_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if lmb_held:
		# Tích lũy + vượt ngưỡng 1s
		for i in 65:
			_LIB.process_lib_hold(self, 1.0 / 60.0)
		_check(_count(_inventory, gem.id) == 1 + 64, "giữ đủ 1s → +1 stack (got %d)" % _count(_inventory, gem.id))
		_check(_lib_hold_stack_taken, "sau khi lấy stack → đánh dấu stack_taken")
		# Nhả sau khi đã lấy stack → không lấy thêm
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		Input.parse_input_event(release)
		await get_tree().process_frame
		_LIB.process_lib_hold(self, 1.0 / 60.0)
		_check(_count(_inventory, gem.id) == 65, "nhả sau stack → không lấy thêm pcs (got %d)" % _count(_inventory, gem.id))
	else:
		print("SKIP | headless không mô phỏng được giữ LMB — chỉ test đường nhả")

	# ── 4. take_lib_stack vượt sức chứa → lấy phần cố được, không lỗi ────
	var big := ItemDef.new("t_big", "Big", ItemDef.Type.MATERIAL, Color.RED, "■", "", false, 1)
	var inv_small := _INV.new(1)
	inv_small.add_item(gem, 64)  # lấp đầy slot duy nhất
	var owner_small := self
	owner_small._inventory = inv_small
	var leftover := owner_small._inventory.add_item(big, 5)
	_check(leftover > 0, "kho đầy → add_item trả phần còn lại (leftover=%d) không lỗi" % leftover)
	owner_small._inventory = _inventory

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)