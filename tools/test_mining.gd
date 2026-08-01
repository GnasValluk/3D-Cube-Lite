extends Node

## Headless verification: độ cứng block + cơ chế độ bền (Minecraft-style).
## Chạy qua tools/test_mining.tscn (không chạy trực tiếp file .gd).

const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Slot = preload("res://scripts/items/core/item_slot.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260803)
	ItemDatabase.ensure_db()

	# ── 1. Bảng độ cứng ───────────────────────────────────────────────────
	_check(_D.get_block_hardness(_D.BlockID.STONE) == 1.2, "đá 1.2s (cúp sắt)")
	_check(_D.get_block_hardness(_D.BlockID.GRASS) == 1.2, "cỏ 1.2s (xẻng sắt)")
	_check(_D.get_block_hardness(_D.BlockID.DIRT) == 1.2, "đất 1.2s (xẻng sắt)")
	_check(_D.get_block_hardness(_D.BlockID.SAND) == 1.2, "cát 1.2s (xẻng sắt)")
	_check(_D.get_block_hardness(_D.BlockID.TILLED_SOIL) == 0.8, "đất tơi xốp 0.8s")
	_check(_D.get_block_hardness(_D.BlockID.BAUXITE_ORE) == 1.3, "quặng nhôm 1.3s")
	_check(_D.get_block_hardness(_D.BlockID.COPPER_ORE) == 1.6, "quặng đồng 1.6s")
	_check(_D.get_block_hardness(_D.BlockID.IRON_ORE) == 2.4, "quặng sắt 2.4s (cứng hơn đá)")
	_check(_D.get_block_hardness(_D.BlockID.TITAN_ORE) == 3.6, "quặng titan 3.6s (cứng nhất)")
	_check(_D.get_block_hardness(_D.BlockID.BEDROCK) == -1.0, "bedrock không thể phá")
	_check(_D.get_block_hardness(_D.BlockID.AIR) == 0.0, "air không đào được")
	_check(_D.get_block_hardness(_D.BlockID.WATER_SOURCE) == 0.0, "nước không tính độ cứng")

	# ── 2. Phân loại công cụ ──────────────────────────────────────────────
	_check(_D.is_pickaxable(_D.BlockID.STONE), "cúp: đá")
	_check(_D.is_pickaxable(_D.BlockID.IRON_ORE), "cúp: quặng sắt")
	_check(not _D.is_pickaxable(_D.BlockID.GRASS), "cúp: không đào cỏ")
	_check(not _D.is_pickaxable(_D.BlockID.BEDROCK), "cúp: không đào bedrock")
	_check(_D.is_shovelable(_D.BlockID.GRASS), "xẻng: cỏ")
	_check(_D.is_shovelable(_D.BlockID.SAND), "xẻng: cát")
	_check(_D.is_shovelable(_D.BlockID.TILLED_SOIL), "xẻng: đất tơi xốp")
	_check(not _D.is_shovelable(_D.BlockID.STONE), "xẻng: không đào đá")

	# ── 3. ItemDef có độ bền ──────────────────────────────────────────────
	var db := ItemDatabase.items_db
	_check((db["pickaxe"] as ItemDef).max_durability == 251, "cúp sắt 251 độ bền")
	_check((db["shovel"] as ItemDef).max_durability == 251, "xẻng sắt 251 độ bền")
	_check((db["axe"] as ItemDef).max_durability == 251, "rìu sắt 251 độ bền")
	_check((db["hoe"] as ItemDef).max_durability == 251, "cuốc sắt 251 độ bền")
	_check((db["iron_sword"] as ItemDef).max_durability == 251, "kiếm sắt 251 độ bền")
	_check((db["iron_greatsword"] as ItemDef).max_durability == 500, "đại kiếm 500 độ bền")
	_check((db["iron_halberd"] as ItemDef).max_durability == 400, "kích sắt 400 độ bền")
	_check((db["crossbow"] as ItemDef).max_durability == 300, "nỏ 300 độ bền")
	_check((db["fishing_rod"] as ItemDef).max_durability == 64, "cần câu 64 độ bền")
	_check((db["block_dirt"] as ItemDef).max_durability == 0, "khối đất không có độ bền")
	_check((db["coconut"] as ItemDef).max_durability == 0, "thức ăn không có độ bền")

	# ── 4. ItemSlot khởi tạo độ bền ───────────────────────────────────────
	var pick := db["pickaxe"] as ItemDef
	var slot := _Slot.new()
	slot.item = pick
	_check(slot.durability == 251, "slot cúp mới = 251 độ bền")
	_check(slot.get_durability_ratio() == 1.0, "tỉ lệ độ bền 100%")
	slot.durability = 100
	_check(absf(slot.get_durability_ratio() - 100.0 / 251.0) < 0.001, "tỉ lệ độ bền 100/251")
	slot.clear()
	_check(slot.durability == -1 and slot.is_empty(), "clear slot → độ bền -1")
	var dirt := db["block_dirt"] as ItemDef
	slot.item = dirt
	_check(slot.durability == -1, "item không độ bền → slot -1")

	# ── 5. Inventory: hao mòn + swap/transfer + save ──────────────────────
	var inv := Inventory.new()
	inv.add_item(pick, 1)
	var p_idx := inv.find_slot_of_item(pick)
	_check(p_idx >= 0 and inv.slots[p_idx].durability == 251, "add cúp → slot full bền")
	_check(inv.damage_slot_durability(p_idx, 1), "trừ 1 độ bền → còn dùng được")
	_check(inv.slots[p_idx].durability == 250, "độ bền = 250 sau 1 lần đào")

	# Swap: độ bền theo item
	var inv2 := Inventory.new()
	var hoe := db["hoe"] as ItemDef
	inv2.add_item(hoe, 1)
	var h_idx := inv2.find_slot_of_item(hoe)
	inv2.slots[h_idx].durability = 30
	inv2.swap(h_idx, p_idx)
	_check(inv2.slots[p_idx].item == hoe and inv2.slots[p_idx].durability == 30,
		"swap: độ bền đi theo item")

	# Save roundtrip
	var data := inv2.to_dict()
	var inv3 := Inventory.new()
	inv3.from_dict(data)
	var h_idx3 := inv3.find_slot_of_item(hoe)
	_check(h_idx3 >= 0 and inv3.slots[h_idx3].durability == 30,
		"save/load: độ bền 30 giữ nguyên")
	_check(inv3.to_dict()[p_idx]["dur"] == 30, "to_dict lưu trường dur")

	# Save cũ không có dur → mặc định full bền
	var old_data: Array = []
	for i in range(inv3.slots.size()):
		var s := inv3.slots[i]
		old_data.append(null if s.is_empty() else {"id": s.item.id, "count": s.count})
	var inv4 := Inventory.new()
	inv4.from_dict(old_data)
	var h_idx4 := inv4.find_slot_of_item(hoe)
	_check(h_idx4 >= 0 and inv4.slots[h_idx4].durability == 251,
		"save cũ không có dur → full bền")

	# Vỡ khi về 0
	_check(not inv.damage_slot_durability(p_idx, 250), "trừ hết → vỡ (false)")
	_check(inv.slots[p_idx].durability == 0, "độ bền clamp về 0")
	inv.remove_item(p_idx, 1)
	_check(inv.slots[p_idx].is_empty(), "vỡ → slot rỗng")

	# Split stack giữ độ bền (item có thể stack + có độ bền)
	var stacky := ItemDef.new("test_stacky", "Test", ItemDef.Type.TOOL, Color.WHITE, "T",
		"", true, 64, 0, 0, 0, -1, 100)
	var inv5 := Inventory.new()
	inv5.add_item(stacky, 5)
	var s_idx := inv5.find_slot_of_item(stacky)
	inv5.slots[s_idx].durability = 77
	var new_idx: int = inv5.split_stack(s_idx, 2)
	_check(new_idx >= 0 and inv5.slots[new_idx].durability == 77 and inv5.slots[s_idx].durability == 77,
		"split stack → độ bền nhân bản đúng")

	# ── 6. Mô phỏng tiến trình đào (core loop) ────────────────────────────
	# progress += delta / hardness; vỡ khi >= 1.0
	var frames_stone: int = 0
	var prog := 0.0
	while prog < 1.0:
		prog += 0.1 / _D.get_block_hardness(_D.BlockID.STONE)
		frames_stone += 1
	_check(frames_stone == 12, "đá 1.2s @0.1s/frame = 12 frame (thực tế %d)" % frames_stone)
	var frames_titan: int = 0
	prog = 0.0
	while prog < 1.0:
		prog += 0.1 / _D.get_block_hardness(_D.BlockID.TITAN_ORE)
		frames_titan += 1
	_check(frames_titan == 36, "titan 3.6s @0.1s/frame = 36 frame (thực tế %d)" % frames_titan)
	var frames_soil: int = 0
	prog = 0.0
	while prog < 1.0:
		prog += 0.1 / _D.get_block_hardness(_D.BlockID.TILLED_SOIL)
		frames_soil += 1
	_check(frames_soil == 8, "đất tơi xốp 0.8s = 8 frame (thực tế %d)" % frames_soil)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
