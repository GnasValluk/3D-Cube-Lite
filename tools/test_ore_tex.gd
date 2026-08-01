extends Node

## Headless verification: block quặng đặt tay (placement) phải có texture overlay.
## Fix: rebuild_mesh không còn bỏ qua scan ore khi _has_ores == false (chunk mới
## không sinh ore tự nhiên → ore đặt tay trước đây hiển thị màu trơn, không hoa văn).
## Chạy qua tools/test_ore_tex.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

const _ORES: Array[int] = [
	_D.BlockID.COPPER_ORE,
	_D.BlockID.BAUXITE_ORE,
	_D.BlockID.SILVER_ORE,
	_D.BlockID.IRON_ORE,
	_D.BlockID.GOLD_ORE,
	_D.BlockID.TITAN_ORE,
	_D.BlockID.PLATINUM_ORE,
	_D.BlockID.COAL_ORE,
]

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260804)

	# ── 0. Dữ liệu quặng than ───────────────────────────────────────────────
	_check(_D.BlockID.COAL_ORE == 33, "COAL_ORE = 33")
	_check(_D.ITEM_TO_BLOCK.get("coal_ore", 0) == _D.BlockID.COAL_ORE,
		"ITEM_TO_BLOCK[coal_ore] → 33 (đặt được)")
	_check(_D.BLOCK_TO_ITEM.get(_D.BlockID.COAL_ORE, "") == "coal",
		"BLOCK_TO_ITEM[33] → coal (đào rớt Than Đá)")
	_check(_D.get_block_hardness(_D.BlockID.COAL_ORE) == 1.5, "than 1.5s (mềm, dễ đào)")
	_check(_D.is_pickaxable(_D.BlockID.COAL_ORE), "cúp đào được quặng than")

	ItemDatabase.ensure_db()
	var coal_ore_item: ItemDef = ItemDatabase.items_db.get("coal_ore") as ItemDef
	var coal_item: ItemDef = ItemDatabase.items_db.get("coal") as ItemDef
	var charcoal_item: ItemDef = ItemDatabase.items_db.get("charcoal") as ItemDef
	_check(coal_ore_item != null and coal_ore_item.type == ItemDef.Type.BLOCK,
		"item coal_ore tồn tại, loại BLOCK")
	_check(coal_item != null and coal_item.type == ItemDef.Type.MATERIAL,
		"item coal (Than Đá) tồn tại, loại MATERIAL")
	_check(charcoal_item != null and charcoal_item.type == ItemDef.Type.MATERIAL,
		"item charcoal (Than Củi) tồn tại, loại MATERIAL")
	_check(coal_item != null and coal_item.max_stack == 64, "Than Đá stack 64")
	_check(charcoal_item != null and charcoal_item.max_stack == 64, "Than Củi stack 64")

	var chunk := _W.new()
	chunk.name = "OreTexChunk"
	add_child(chunk)
	chunk.setup(0, 0, SIZE, RW, true)
	_check(chunk.block_data != null, "chunk setup sync ok")

	if chunk.block_data != null:
		_check(not chunk._has_ores, "chunk mới: chưa có ore (generation chưa bật)")

		# Tìm một cột có bề mặt solid để đặt ore lên trên
		var dig_x := -1
		var dig_z := -1
		var dig_top := -1
		for x in range(COLS):
			for z in range(COLS):
				var t := chunk._top_ly_cache[x * COLS + z]
				if t >= 0:
					dig_x = x; dig_z = z; dig_top = t
					break
			if dig_x >= 0:
				break
		_check(dig_x >= 0, "tìm được cột bề mặt (%d,%d)" % [dig_x, dig_z])

		if dig_x >= 0:
			var half_sz := SIZE * 0.5
			var wx := chunk.global_position.x - half_sz + (dig_x + 0.5) * _D.VOXEL
			var wz := chunk.global_position.z - half_sz + (dig_z + 0.5) * _D.VOXEL

			# ── 1. Đặt từng loại ore lên bề mặt → phải có overlay textured ──
			for i in range(_ORES.size()):
				var bid: int = _ORES[i]
				var wy := _BD.layer_to_world_y(dig_top + 1 + i)
				var placed: bool = chunk.place_block_at(wx, wy, wz, bid)
				_check(placed, "đặt ore %d ok" % bid)
				_check(chunk.block_data.get_block(dig_x, dig_top + 1 + i, dig_z) == bid,
					"block data lưu ore %d" % bid)
				_check(chunk._has_ores, "_has_ores = true sau khi đặt ore %d" % bid)
				var mi := chunk._textured_block_mesh_instances.get(bid) as MeshInstance3D
				_check(mi != null and mi.mesh != null, "có mesh instance cho ore %d" % bid)
				if mi != null and mi.mesh != null:
					_check(mi.mesh.get_surface_count() > 0, "mesh overlay ore %d có geometry" % bid)
					_check(mi.material_override != null, "material ore %d không null" % bid)

			# ── 2. Phá ore → overlay tương ứng phải biến mất ──
			var last_bid: int = _ORES[_ORES.size() - 1]
			var last_wy := _BD.layer_to_world_y(dig_top + 1 + _ORES.size() - 1)
			chunk.break_block_at(wx, last_wy, wz)
			_check(not chunk._textured_block_mesh_instances.has(last_bid),
				"phá ore → overlay instance bị xóa")

			# ── 3. Phá hết ore → _has_ores quay về false ──
			for i in range(_ORES.size() - 1):
				var wy_i := _BD.layer_to_world_y(dig_top + 1 + i)
				chunk.break_block_at(wx, wy_i, wz)
			_check(not chunk._has_ores, "phá hết ore → _has_ores = false")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
