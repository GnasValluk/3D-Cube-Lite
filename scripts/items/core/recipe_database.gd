## recipe_database.gd — Hệ thống công thức chế tạo (kiểu lưới, Minecraft).
## Recipe = {
##   "id", "name", "result", "count", "category", "desc",
##   "grid_size": 2 hoặc 3,
##   "pattern": [[item_id hoặc "", ...], ...]  # các dòng trên lưới,
##   "ingredients": {item_id: số lượng}          # tự suy ra từ pattern,
## }
## Ghép khớp theo hình dạng ô trên lưới chế tạo (có thể dịch chuyển pattern
## trong lưới, giống Minecraft).
class_name RecipeDatabase
extends RefCounted

static var recipes: Array[Dictionary] = []
static var _built: bool = false

const CAT_STRUCTURES: String = "Công Trình"
const CAT_TOOLS: String = "Công Cụ"
const CAT_MATERIALS: String = "Nguyên Liệu"

static func ensure() -> void:
	if _built:
		return
	_built = true
	# Toàn bộ công thức đã bị xoá. Danh sách để trống — thêm lại sau.
	recipes = []

## Trích mảng id item từ lưới chế tạo (grid_size×grid_size), "" = ô trống.
static func _grid_ids(grid_inventory, grid_size: int) -> Array:
	var ids: Array = []
	ids.resize(grid_size * grid_size)
	for i in range(grid_size * grid_size):
		ids[i] = ""
	if grid_inventory == null:
		return ids
	var n: int = mini(grid_size * grid_size, grid_inventory.slots.size())
	for i in range(n):
		var slot = grid_inventory.slots[i]
		if slot != null and not slot.is_empty():
			ids[i] = slot.item.id
	return ids

## Cắt bỏ viền trống của pattern để lấy khối chứa vật phẩm (bounding box).
static func _trim_pattern(pattern: Array) -> Array:
	var rows: Array = pattern
	var top := 0
	var bottom := rows.size() - 1
	while top <= bottom and _row_all_empty(rows[top]):
		top += 1
	while bottom >= top and _row_all_empty(rows[bottom]):
		bottom -= 1
	if bottom < top:
		return []
	var cols := 0
	for r in range(top, bottom + 1):
		cols = maxi(cols, (rows[r] as Array).size())
	var left := cols
	var right := 0
	for r in range(top, bottom + 1):
		var row: Array = rows[r]
		for c in range(row.size()):
			if (row[c] as String) != "":
				left = mini(left, c)
				right = maxi(right, c)
	if right < left:
		return []
	var trimmed: Array = []
	for r in range(top, bottom + 1):
		var row: Array = rows[r]
		var new_row: Array = []
		for c in range(left, right + 1):
			new_row.append(row[c] if c < row.size() else "")
		trimmed.append(new_row)
	return trimmed

static func _row_all_empty(row) -> bool:
	if row == null:
		return true
	for cell in row:
		if (cell as String) != "":
			return false
	return true

## So khớp pattern (đã trim) với lưới tại offset (ox, oy). Các ô ngoài vùng
## pattern phải trống; các ô trong pattern phải khớp id ("" = ô trống).
static func _pattern_at(ids: Array, pattern: Array, grid_size: int, ox: int, oy: int) -> bool:
	var rows: int = pattern.size()
	var cols: int = 0
	for row in pattern:
		cols = maxi(cols, (row as Array).size())
	for r in range(grid_size):
		for c in range(grid_size):
			var in_pattern: bool = r >= oy and r < oy + rows and c >= ox and c < ox + cols
			var want: String = ""
			if in_pattern:
				var prow: Array = pattern[r - oy]
				want = prow[c - ox] if c - ox < prow.size() else ""
			var have: String = ids[r * grid_size + c]
			if want == "" and have != "":
				return false
			if want != "" and have != want:
				return false
	return true

## Tìm recipe khớp theo hình dạng trên lưới grid_size×grid_size.
static func match_shape(grid_inventory, grid_size: int) -> Dictionary:
	var ids := _grid_ids(grid_inventory, grid_size)
	for r in recipes:
		var pattern: Array = r.get("pattern", [])
		if pattern.is_empty():
			continue
		var trimmed := _trim_pattern(pattern)
		if trimmed.is_empty():
			continue
		var rows: int = trimmed.size()
		var cols: int = 0
		for row in trimmed:
			cols = maxi(cols, (row as Array).size())
		if rows > grid_size or cols > grid_size:
			continue
		for oy in range(grid_size - rows + 1):
			for ox in range(grid_size - cols + 1):
				if _pattern_at(ids, trimmed, grid_size, ox, oy):
					return r
	return {}

## Đếm item trong lưới chế tạo → dictionary {item_id: count}.
static func count_grid(grid_inventory) -> Dictionary:
	var have: Dictionary = {}
	if grid_inventory == null:
		return have
	for slot in grid_inventory.slots:
		if slot == null or slot.is_empty():
			continue
		have[slot.item.id] = have.get(slot.item.id, 0) + slot.count
	return have

## Tìm recipe đầu tiên khớp với lưới chế tạo (đếm nguyên liệu, không theo hình
## dạng) — giữ để tương thích ngược.
static func match_grid(grid_inventory) -> Dictionary:
	var have := count_grid(grid_inventory)
	return match_counts(have)

## Tìm recipe khớp với dictionary {item_id: count}.
static func match_counts(have: Dictionary) -> Dictionary:
	for r in recipes:
		var ok := true
		for ing in (r["ingredients"] as Dictionary):
			if have.get(ing, 0) < (r["ingredients"] as Dictionary)[ing]:
				ok = false
				break
		if ok:
			return r
	return {}
