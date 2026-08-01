extends RefCounted

## ── Ngôi Làng — làng quê đồng bằng (DARK_GRASS) dọc theo đường/sông ─────────
## Deterministic theo chunk (cùng cx,cz → cùng làng). Không spawn trên đường đi,
## cổng làng bắc ngang đường, nhà cửa quay mặt về phía đường (như đèn đường).
## Làng = tập các "hộp màu" (Transform3D + Color) dựng qua MultiMesh.
## Công trình: nhà ba gian, chòi, cổng làng, đình miếu, giếng, lò gạch,
## chợ quê, bến nước, cầu tre.

const _Data = preload("chunk_data.gd")
const _Road = preload("chunk_road.gd")

const VILLAGE_MIN_DIST: float = 120.0    # cách spawn (0,0) tối thiểu (block)
const VILLAGE_CHANCE: int = 20           # xác suất 1 chunk có làng (%)
const ROAD_RANGE_CELLS: float = 18.0     # đường cách tâm làng tối đa (ô)
const RIVER_RANGE_CELLS: float = 14.0    # sông cách tâm làng tối đa (ô)

# ── Bảng màu làng quê ────────────────────────────────────────────────────────
const C_THATCH: Color = Color(0.62, 0.46, 0.20)   # lá dừa khô
const C_THATCH_DARK: Color = Color(0.48, 0.34, 0.14)
const C_WOOD: Color = Color(0.47, 0.36, 0.25)      # vách gỗ
const C_WOOD_DARK: Color = Color(0.33, 0.23, 0.14) # cột gỗ
const C_LIME: Color = Color(0.86, 0.78, 0.54)      # vôi vàng nhạt
const C_BRICK: Color = Color(0.68, 0.26, 0.16)     # gạch thẻ đỏ
const C_TILE: Color = Color(0.72, 0.30, 0.18)      # ngói đỏ
const C_TILE_DARK: Color = Color(0.52, 0.20, 0.12)
const C_STONE: Color = Color(0.56, 0.52, 0.47)     # đá vôi
const C_STONE_DARK: Color = Color(0.42, 0.39, 0.35)
const C_MOSS: Color = Color(0.32, 0.52, 0.20)      # rêu phong
const C_WATER: Color = Color(0.16, 0.46, 0.56)     # nước giếng
const C_BAMBOO: Color = Color(0.66, 0.58, 0.30)    # tre nứa
const C_DOOR: Color = Color(0.40, 0.28, 0.16)      # cửa gỗ
const C_PROD_RED: Color = Color(0.80, 0.20, 0.12)  # cà chua
const C_PROD_YEL: Color = Color(0.85, 0.72, 0.20)  # bắp
const C_PROD_GRN: Color = Color(0.35, 0.62, 0.22)  # rau

static func _vh_hash(seed_v: int, salt: int) -> int:
	var h: int = seed_v ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7FFFFFFF

## ── Entry: compute_village ───────────────────────────────────────────────────
static func compute_village(cx: int, cz: int, size: int, dim_id: int,
		biome_grid: Array, height_grid: Array, road_grid: PackedByteArray,
		river_flag: PackedByteArray, cols: int) -> Dictionary:
	var empty := { "has": false, "xforms": [], "colors": [], "info": {} }
	if dim_id != _Data._Dim.DimensionID.REAL_WORLD:
		return empty

	var cw_x: float = float(cx) * size + size * 0.5
	var cw_z: float = float(cz) * size + size * 0.5
	if sqrt(cw_x * cw_x + cw_z * cw_z) < VILLAGE_MIN_DIST:
		return empty

	var seed_v: int = cx * 1372589 ^ cz * 1731733

	if _vh_hash(seed_v, 1) % 100 >= VILLAGE_CHANCE:
		return empty

	# Tâm làng: giữa chunk, biome đồng bằng (DARK_GRASS), đất phẳng
	var hx: int = 8 + _vh_hash(seed_v, 2) % (cols - 16)
	var hz: int = 8 + _vh_hash(seed_v, 3) % (cols - 16)
	if biome_grid[hx][hz] != _Data.TileType.DARK_GRASS:
		return empty
	if road_grid.size() > 0 and road_grid[hx * cols + hz] != 0:
		return empty
	var ch: float = height_grid[hx][hz]
	if ch <= _Data.WATER_Y or ch > 2.5:
		return empty
	# Vùng làng quanh tâm phải đồng bằng phẳng
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			var nx: int = hx + dx
			var nz: int = hz + dz
			if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
				return empty
			if biome_grid[nx][nz] != _Data.TileType.DARK_GRASS:
				return empty
			if absf(height_grid[nx][nz] - ch) > 0.6:
				return empty

	var center: Vector2 = Vector2(
		float(cx) * size - float(size) * 0.5 + (float(hx) + 0.5) * _Data.VOXEL,
		float(cz) * size - float(size) * 0.5 + (float(hz) + 0.5) * _Data.VOXEL)

	var road := _nearest_road(center, size)
	var river := _nearest_river(river_flag, cols, center, cx, cz, size)
	if road.is_empty() and river.is_empty():
		return empty
	if not road.is_empty() and road.dist > ROAD_RANGE_CELLS:
		road = {}
	if not river.is_empty() and river.dist > RIVER_RANGE_CELLS:
		river = {}
	if road.is_empty() and river.is_empty():
		return empty

	var use_road: bool = not road.is_empty() and (river.is_empty() or road.dist <= river.dist)
	var toward: Vector2 = (road.pt - center) if use_road \
		else (Vector2(river.pt.x, river.pt.y) - center)
	if toward.length() < 0.1:
		toward = Vector2(0, 1)
	toward = toward.normalized()

	var xforms: Array = []
	var colors: Array = []
	var buildings: Array = []

	var g_y: float = height_grid[hx][hz] + 0.02

	# ── Cổng làng bắc ngang đường (đầu làng bên phải đường) ────────────────
	var gate_placed: bool = false
	if use_road:
		var gate_pt: Vector2 = road.pt + road.dir * 6.0
		var gate_cell: Vector2i = _world_to_cell(gate_pt, cx, cz, size, cols)
		if _cell_ok(gate_cell, cols) and biome_grid[gate_cell.x][gate_cell.y] == _Data.TileType.DARK_GRASS:
			var gy: float = height_grid[gate_cell.x][gate_cell.y] + 0.02
			_add_gate(xforms, colors, gate_pt, road.dir, gy)
			gate_placed = true
			buildings.append({ "type": "gate", "x": gate_pt.x, "z": gate_pt.y, "yaw": 0.0, "facing": road.dir })

	# ── Nhà ba gian — mặt nhà quay về phía đường/sông ──────────────────────
	var side: float = 1.0 if _vh_hash(seed_v, 4) % 2 == 0 else -1.0
	var yaw_h: float = atan2(-toward.x, -toward.y)
	var perp_r: Vector2 = toward.orthogonal()
	var house_pt: Vector2 = center
	if use_road:
		perp_r = Vector2(road.dir.y, -road.dir.x)
		house_pt = road.pt + perp_r * (side * (4.0 + float(_vh_hash(seed_v, 5) % 4))) \
			+ road.dir * float(_vh_hash(seed_v, 6) % 5 - 2)
	else:
		house_pt = center + toward * 4.0
	var house_cell: Vector2i = _world_to_cell(house_pt, cx, cz, size, cols)
	if _footprint_ok(house_cell, cols, biome_grid, height_grid, road_grid, 4, 3):
		var hy: float = height_grid[house_cell.x][house_cell.y] + 0.02
		_add_house(xforms, colors, house_pt, yaw_h, hy)
		buildings.append({ "type": "house", "x": house_pt.x, "z": house_pt.y, "yaw": yaw_h, "facing": toward })

	# ── Đình miếu, giếng, lò gạch, chợ quanh sân làng ──────────────────────
	var plaza_off: float = 3.0 + float(_vh_hash(seed_v, 7) % 3)
	var s1: Vector2 = center + perp_r * (side * plaza_off) - (road.dir if use_road else perp_r) * 2.0
	var sc1: Vector2i = _world_to_cell(s1, cx, cz, size, cols)
	if _footprint_ok(sc1, cols, biome_grid, height_grid, road_grid, 3, 2):
		var y1: float = height_grid[sc1.x][sc1.y] + 0.02
		_add_shrine(xforms, colors, s1, yaw_h, y1)
		buildings.append({ "type": "shrine", "x": s1.x, "z": s1.y, "yaw": yaw_h, "facing": toward })

	var s2: Vector2 = center + perp_r * (side * (plaza_off - 1.0)) + (road.dir if use_road else perp_r) * 3.0
	var sc2: Vector2i = _world_to_cell(s2, cx, cz, size, cols)
	if _footprint_ok(sc2, cols, biome_grid, height_grid, road_grid, 2, 2):
		var y2: float = height_grid[sc2.x][sc2.y] + 0.02
		_add_well(xforms, colors, s2, y2)
		buildings.append({ "type": "well", "x": s2.x, "z": s2.y, "yaw": 0.0, "facing": Vector2(0, 1) })

	var s3: Vector2 = center - perp_r * (side * 3.5) + (road.dir if use_road else perp_r) * 1.0
	var sc3: Vector2i = _world_to_cell(s3, cx, cz, size, cols)
	if _footprint_ok(sc3, cols, biome_grid, height_grid, road_grid, 3, 3):
		var y3: float = height_grid[sc3.x][sc3.y] + 0.02
		_add_kiln(xforms, colors, s3, y3)
		buildings.append({ "type": "kiln", "x": s3.x, "z": s3.y, "yaw": 0.0, "facing": Vector2(0, 1) })

	var s4: Vector2 = center - perp_r * (side * (plaza_off + 0.5)) - (road.dir if use_road else perp_r) * 2.5
	var sc4: Vector2i = _world_to_cell(s4, cx, cz, size, cols)
	if _footprint_ok(sc4, cols, biome_grid, height_grid, road_grid, 3, 2):
		var y4: float = height_grid[sc4.x][sc4.y] + 0.02
		_add_stall(xforms, colors, s4, yaw_h, y4)
		_add_stall(xforms, colors, s4 + (road.dir if use_road else perp_r) * 3.0, yaw_h, y4)
		buildings.append({ "type": "market", "x": s4.x, "z": s4.y, "yaw": yaw_h, "facing": toward })

	# ── Chòi + bến nước phía sông ──────────────────────────────────────────
	if not river.is_empty():
		var rv: Vector2 = Vector2(river.pt.x, river.pt.y)
		var toward_r: Vector2 = (rv - center).normalized()
		var yaw_r: float = atan2(-toward_r.x, -toward_r.y)
		var hut_pt: Vector2 = center + toward_r * (river.dist - 1.5)
		var hut_cell: Vector2i = _world_to_cell(hut_pt, cx, cz, size, cols)
		if _cell_ok(hut_cell, cols):
			var hy2: float = height_grid[hut_cell.x][hut_cell.y] + 0.02
			_add_hut(xforms, colors, hut_pt, yaw_r, hy2)
			buildings.append({ "type": "hut", "x": hut_pt.x, "z": hut_pt.y, "yaw": yaw_r, "facing": toward_r })
		_add_dock(xforms, colors, river, height_grid, cx, cz, size, cols)
		buildings.append({ "type": "dock", "x": river.pt.x, "z": river.pt.y, "yaw": 0.0, "facing": toward_r })

	if buildings.is_empty():
		return empty

	# Chunk node nằm tại (cx*size, cz*size) → quy về tọa độ local như cỏ/rêu
	var origin := Vector3(cx * size, 0.0, cz * size)
	for i in range(xforms.size()):
		xforms[i] = Transform3D((xforms[i] as Transform3D).basis,
			(xforms[i] as Transform3D).origin - origin)

	return {
		"has": true,
		"xforms": xforms,
		"colors": colors,
		"info": {
			"center": Vector2i(hx, hz),
			"center_world": center,
			"road_dist": road.dist if not road.is_empty() else -1.0,
			"river_dist": river.dist if not river.is_empty() else -1.0,
			"road_dir": road.dir if use_road else Vector2.ZERO,
			"facing": toward,
			"gate": gate_placed,
			"buildings": buildings,
		}
	}

## ── Đường gần nhất + tiếp tuyến ─────────────────────────────────────────────
static func _nearest_road(center: Vector2, size: int) -> Dictionary:
	_Road._ensure_roads()
	var pad: float = 24.0
	var best := {}
	var best_d2: float = 1e18
	for ci in range(_Road._road_curves.size()):
		var curve: PackedVector2Array = _Road._road_curves[ci]
		if curve.size() < 2:
			continue
		var bb: Rect2 = _Road.curve_bbox(ci)
		if bb.end.x < center.x - pad or bb.position.x > center.x + pad:
			continue
		if bb.end.y < center.y - pad or bb.position.y > center.y + pad:
			continue
		for i in range(curve.size() - 1):
			var a: Vector2 = curve[i]
			var b2: Vector2 = curve[i + 1]
			var ab: Vector2 = b2 - a
			var len2: float = ab.length_squared()
			if len2 < 0.001:
				continue
			var t: float = clamp((center - a).dot(ab) / len2, 0.0, 1.0)
			var pt: Vector2 = a.lerp(b2, t)
			var d2: float = center.distance_squared_to(pt)
			if d2 < best_d2:
				best_d2 = d2
				best = { "pt": pt, "dir": ab / sqrt(len2), "dist": sqrt(d2) }
	return best

## ── Sông gần nhất (ô river_flag) ────────────────────────────────────────────
static func _nearest_river(river_flag: PackedByteArray, cols: int, center: Vector2,
		cx: int, cz: int, size: int) -> Dictionary:
	var best := {}
	var best_d2: float = 1e18
	if river_flag.is_empty():
		return best
	var min_x: float = float(cx) * size - float(size) * 0.5
	var min_z: float = float(cz) * size - float(size) * 0.5
	for vx in range(cols):
		for vz in range(cols):
			if river_flag[vx * cols + vz] == 0:
				continue
			var p: Vector2 = Vector2(min_x + (float(vx) + 0.5), min_z + (float(vz) + 0.5))
			var d2: float = p.distance_squared_to(center)
			if d2 < best_d2:
				best_d2 = d2
				best = { "pt": p, "dist": sqrt(d2) }
	return best

## ── Tool: world → cell ──────────────────────────────────────────────────────
static func _world_to_cell(p: Vector2, cx: int, cz: int, size: int, cols: int) -> Vector2i:
	var min_x: float = float(cx) * size - float(size) * 0.5
	var min_z: float = float(cz) * size - float(size) * 0.5
	return Vector2i(
		int(floor((p.x - min_x) / _Data.VOXEL)),
		int(floor((p.y - min_z) / _Data.VOXEL)))

static func _cell_ok(c: Vector2i, cols: int) -> bool:
	return c.x >= 0 and c.x < cols and c.y >= 0 and c.y < cols

## ── Kiểm tra chân công trình: đất phẳng, không đường, không nước ──────────
static func _footprint_ok(c: Vector2i, cols: int, biome_grid: Array,
		height_grid: Array, road_grid: PackedByteArray, rx: int, rz: int) -> bool:
	if not _cell_ok(c, cols):
		return false
	var ref_h: float = height_grid[c.x][c.y]
	for dx in range(-rx, rx + 1):
		for dz in range(-rz, rz + 1):
			var nx: int = c.x + dx
			var nz: int = c.y + dz
			if not _cell_ok(Vector2i(nx, nz), cols):
				return false
			if height_grid[nx][nz] <= _Data.WATER_Y:
				return false
			if absf(height_grid[nx][nz] - ref_h) > 0.5:
				return false
			if road_grid.size() > 0 and road_grid[nx * cols + nz] != 0:
				return false
	return true

## ── Cầu tre bắc qua sông nơi đường gặp nước (đặc trưng của đường, như đèn) ──
## Không phụ thuộc làng — bất kỳ chunk REAL_WORLD nào có đường cắt sông đều có cầu.
static func compute_bridges(cx: int, cz: int, size: int, dim_id: int,
		height_grid: Array, river_flag: PackedByteArray, cols: int) -> Dictionary:
	var empty := { "xforms": [], "colors": [] }
	if dim_id != _Data._Dim.DimensionID.REAL_WORLD:
		return empty
	var xforms: Array = []
	var colors: Array = []
	_find_bridges(xforms, colors, cx, cz, size, height_grid, river_flag, cols)
	var origin := Vector3(cx * size, 0.0, cz * size)
	for i in range(xforms.size()):
		xforms[i] = Transform3D((xforms[i] as Transform3D).basis,
			(xforms[i] as Transform3D).origin - origin)
	return { "xforms": xforms, "colors": colors }

## ── Quét đường cắt sông trong chunk; dựng cầu tre tại run sông 2~10 ô ───────
static func _find_bridges(xforms: Array, colors: Array, cx: int, cz: int, size: int,
		height_grid: Array, river_flag: PackedByteArray, cols: int) -> void:
	if river_flag.is_empty():
		return
	_Road._ensure_roads()
	var min_x: float = float(cx) * size - float(size) * 0.5
	var min_z: float = float(cz) * size - float(size) * 0.5
	var pad: float = 10.0
	var placed: int = 0
	for ci in range(_Road._road_curves.size()):
		var curve: PackedVector2Array = _Road._road_curves[ci]
		if curve.size() < 2:
			continue
		var bb: Rect2 = _Road.curve_bbox(ci)
		if bb.end.x < min_x - pad or bb.position.x > min_x + size + pad:
			continue
		if bb.end.y < min_z - pad or bb.position.y > min_z + size + pad:
			continue
		for i in range(curve.size() - 1):
			var a: Vector2 = curve[i]
			var b2: Vector2 = curve[i + 1]
			var ab: Vector2 = b2 - a
			var seg_len: float = ab.length()
			if seg_len < 0.5:
				continue
			var seg_dir: Vector2 = ab / seg_len
			var steps: int = int(seg_len / 0.8) + 1
			var run_len := 0
			var run_cells: Array = []
			for s in range(steps + 1):
				var p: Vector2 = a.lerp(b2, float(s) / float(steps))
				var vx: int = int(floor(p.x - min_x))
				var vz: int = int(floor(p.y - min_z))
				var in_chunk: bool = vx >= 0 and vx < cols and vz >= 0 and vz < cols
				var is_river: bool = in_chunk and river_flag[vx * cols + vz] != 0
				if is_river:
					run_len += 1
					run_cells.append(p)
				elif run_len >= 2 and run_len <= 10:
					if _bridge_ok(run_cells, seg_dir, cx, cz, size, cols, height_grid):
						_place_bridge(xforms, colors, run_cells, seg_dir)
						placed += 1
					run_len = 0
					run_cells.clear()
				else:
					run_len = 0
					run_cells.clear()
			if run_len >= 2 and run_len <= 10:
				if _bridge_ok(run_cells, seg_dir, cx, cz, size, cols, height_grid):
					_place_bridge(xforms, colors, run_cells, seg_dir)
					placed += 1
			if placed >= 3:
				return

## ── 2 đầu run phải khô (đất liền) ───────────────────────────────────────────
static func _bridge_ok(run_cells: Array, seg_dir: Vector2, cx: int, cz: int,
		size: int, cols: int, height_grid: Array) -> bool:
	var lo: Vector2 = run_cells[0] - seg_dir * 1.2
	var hi: Vector2 = run_cells[run_cells.size() - 1] + seg_dir * 1.2
	return _dry_land(lo, cx, cz, size, cols, height_grid) \
		and _dry_land(hi, cx, cz, size, cols, height_grid)

## ── Dựng cầu tại run ─────────────────────────────────────────────────────────
static func _place_bridge(xforms: Array, colors: Array, run_cells: Array,
		seg_dir: Vector2) -> void:
	var run_len: int = run_cells.size()
	var deck_y: float = _Data.WATER_Y + 0.15
	var perp_b: Vector2 = Vector2(seg_dir.y, -seg_dir.x)
	var mid2: Vector2 = (run_cells[0] + run_cells[run_cells.size() - 1]) * 0.5
	var yaw_b: float = atan2(perp_b.x, -perp_b.y)
	_emit_boxes(xforms, colors, [
		[Vector3(0, 0.0, 0), Vector3(float(run_len + 1), 0.12, 2.1), C_BAMBOO],
		[Vector3(0, 0.55, -1.02), Vector3(float(run_len + 1), 0.5, 0.1), C_WOOD_DARK],
		[Vector3(0, 0.55, 1.02), Vector3(float(run_len + 1), 0.5, 0.1), C_WOOD_DARK],
	], yaw_b, Vector3(mid2.x, deck_y, mid2.y))
	for i in range(1, run_len + 1):
		var p: Vector2 = run_cells[0] + seg_dir * float(i)
		_emit_box(xforms, colors, Vector3(p.x, _Data.WATER_Y - 0.05, p.y),
			Vector3(0.18, _Data.WATER_Y + 0.35, 0.18), C_WOOD_DARK)

## ── Điểm khô (đất liền, không sông) ─────────────────────────────────────────
static func _dry_land(p: Vector2, cx: int, cz: int, size: int, cols: int,
		height_grid: Array) -> bool:
	var c: Vector2i = _world_to_cell(p, cx, cz, size, cols)
	if not _cell_ok(c, cols):
		return false
	return height_grid[c.x][c.y] > _Data.WATER_Y + 0.1

## ── Emit hộp (world space) ──────────────────────────────────────────────────
static func _emit_box(xforms: Array, colors: Array, pos: Vector3,
		sz: Vector3, col: Color) -> void:
	xforms.append(Transform3D(Basis().scaled(sz), pos))
	colors.append(col)

## ── Emit nhóm hộp local → world (xoay yaw quanh Y) ─────────────────────────
static func _emit_boxes(xforms: Array, colors: Array, local: Array,
		yaw: float, base: Vector3) -> void:
	var rot := Basis(Vector3.UP, yaw)
	for item in local:
		var pos: Vector3 = item[0]
		var sz: Vector3 = item[1]
		var col: Color = item[2]
		xforms.append(Transform3D(rot.scaled(sz), base + rot * pos))
		colors.append(col)

## ── Nhà ba gian Nam Bộ (mặt trước = -Z) ─────────────────────────────────────
static func _add_house(xforms: Array, colors: Array, at: Vector2, yaw: float, gy: float) -> void:
	var local: Array = []
	var w: float = 5.0
	var d: float = 4.0
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	# Nền gạch tàu
	local.append([Vector3(0, 0.05, 0), Vector3(w + 0.3, 0.16, d + 0.3), C_BRICK])
	# Vách gỗ 4 phía
	local.append([Vector3(0, 1.25, -hd - 0.14), Vector3(w, 2.3, 0.3), C_WOOD])
	local.append([Vector3(-hw - 0.14, 1.25, 0), Vector3(0.3, 2.3, d), C_WOOD])
	local.append([Vector3(hw + 0.14, 1.25, 0), Vector3(0.3, 2.3, d), C_WOOD])
	# Mặt trước: 2 vách + cửa 4 cánh mở hé + lanh tô
	local.append([Vector3(-1.55, 1.25, hd + 0.14), Vector3(1.5, 2.3, 0.3), C_WOOD])
	local.append([Vector3(1.55, 1.25, hd + 0.14), Vector3(1.5, 2.3, 0.3), C_WOOD])
	for k in range(4):
		var dx: float = -0.45 + float(k) * 0.3
		local.append([Vector3(dx, 0.55, hd + 0.2), Vector3(0.26, 1.1, 0.12), C_DOOR])
	local.append([Vector3(0, 2.25, hd + 0.14), Vector3(1.3, 0.9, 0.3), C_WOOD])
	# Cửa sổ 2 bên
	local.append([Vector3(-2.1, 1.5, hd - 0.8), Vector3(0.7, 0.6, 0.08), C_DOOR])
	local.append([Vector3(2.1, 1.5, hd - 0.8), Vector3(0.7, 0.6, 0.08), C_DOOR])
	# Cột gỗ bo góc 4 góc
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			local.append([Vector3(sx * hw, 1.25, sz * hd), Vector3(0.38, 2.6, 0.38), C_WOOD_DARK])
	# Mái lá dừa nước — 2 lớp + nóc + mái rủ không đều
	local.append([Vector3(0, 2.6, 0), Vector3(w + 1.4, 0.34, d + 1.4), C_THATCH])
	local.append([Vector3(0, 2.85, 0), Vector3(w + 0.6, 0.28, d + 0.6), C_THATCH_DARK])
	local.append([Vector3(0, 3.05, 0), Vector3(2.8, 0.24, 1.0), C_THATCH_DARK])
	# Mép mái rủ
	local.append([Vector3(0, 2.42, hd + 0.95), Vector3(w + 1.3, 0.12, 0.55), C_THATCH])
	local.append([Vector3(0, 2.42, -hd - 0.95), Vector3(w + 1.1, 0.12, 0.5), C_THATCH])
	local.append([Vector3(hw + 1.0, 2.42, 0), Vector3(0.5, 0.12, d + 1.1), C_THATCH])
	local.append([Vector3(-hw - 0.85, 2.42, 0), Vector3(0.45, 0.12, d + 1.3), C_THATCH])
	# Rêu trên mái
	local.append([Vector3(1.8, 2.75, 1.6), Vector3(0.5, 0.16, 0.35), C_MOSS])
	local.append([Vector3(-2.2, 2.75, -1.4), Vector3(0.4, 0.14, 0.3), C_MOSS])
	# Hiên trước (mặt đường): nền + cột + mái hiên
	local.append([Vector3(0, 0.02, hd + 0.9), Vector3(3.4, 0.14, 1.5), C_BRICK])
	local.append([Vector3(-1.1, 1.3, hd + 1.45), Vector3(0.26, 2.5, 0.26), C_WOOD_DARK])
	local.append([Vector3(1.1, 1.3, hd + 1.45), Vector3(0.26, 2.5, 0.26), C_WOOD_DARK])
	local.append([Vector3(0, 2.95, hd + 1.15), Vector3(4.4, 0.22, 2.2), C_THATCH])
	local.append([Vector3(0, 3.05, hd + 1.15), Vector3(3.6, 0.18, 1.8), C_THATCH_DARK])
	_emit_boxes(xforms, colors, local, yaw, Vector3(at.x, gy, at.y))

## ── Chòi giữ đồng / chòi câu cá (nhà sàn) ───────────────────────────────────
static func _add_hut(xforms: Array, colors: Array, at: Vector2, yaw: float, gy: float) -> void:
	var local: Array = []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			local.append([Vector3(sx * 1.1, 1.05, sz * 1.1), Vector3(0.16, 2.2, 0.16), C_WOOD_DARK])
	local.append([Vector3(0, 2.1, 0), Vector3(2.6, 0.14, 2.6), C_BAMBOO])
	local.append([Vector3(0, 2.26, 0), Vector3(2.35, 0.08, 2.35), C_BAMBOO])
	# Mái nón lá dừa khô
	local.append([Vector3(0, 3.15, 0), Vector3(3.0, 0.32, 3.0), C_THATCH])
	local.append([Vector3(0, 3.5, 0), Vector3(2.1, 0.3, 2.1), C_THATCH_DARK])
	local.append([Vector3(0, 3.8, 0), Vector3(1.2, 0.26, 1.2), C_THATCH_DARK])
	local.append([Vector3(0, 4.05, 0), Vector3(0.4, 0.22, 0.4), C_THATCH])
	# Thang tre nhỏ bên hông
	for i in range(4):
		local.append([Vector3(1.35, 0.25 + i * 0.35, 0.2), Vector3(0.09, 0.28, 0.7), C_BAMBOO])
	local.append([Vector3(1.35, 0.75, 0.55), Vector3(0.09, 0.09, 0.3), C_BAMBOO])
	local.append([Vector3(1.35, 1.1, 0.7), Vector3(0.09, 0.09, 0.3), C_BAMBOO])
	# Lan can trước
	local.append([Vector3(0, 2.5, -1.32), Vector3(2.4, 0.45, 0.09), C_BAMBOO])
	_emit_boxes(xforms, colors, local, yaw, Vector3(at.x, gy, at.y))

## ── Cổng làng — bắc ngang đường (X = ngang đường, Z = dọc đường) ────────────
static func _add_gate(xforms: Array, colors: Array, at: Vector2, road_dir: Vector2, gy: float) -> void:
	var yaw: float = atan2(road_dir.x, road_dir.y)
	var local: Array = []
	# 2 cột gạch thẻ đỏ 2 bên đường
	for sx in [-1, 1]:
		local.append([Vector3(sx * 2.15, 1.7, 0), Vector3(0.9, 3.4, 0.9), C_BRICK])
		local.append([Vector3(sx * 2.15, 3.5, 0), Vector3(1.1, 0.28, 1.1), C_TILE_DARK])
		local.append([Vector3(sx * 2.15, 3.75, 0), Vector3(0.7, 0.16, 0.7), C_TILE])
	# Rêu phong trên cột
	local.append([Vector3(-2.15, 3.2, 0.35), Vector3(0.95, 0.3, 0.18), C_MOSS])
	local.append([Vector3(2.15, 2.6, -0.35), Vector3(0.95, 0.25, 0.16), C_MOSS])
	# Mái ngói vảy cá 2 tầng cong
	local.append([Vector3(0, 3.35, 0), Vector3(5.6, 0.4, 2.0), C_TILE])
	local.append([Vector3(0, 3.75, 0), Vector3(4.4, 0.32, 1.5), C_TILE_DARK])
	local.append([Vector3(0, 4.05, 0), Vector3(2.4, 0.26, 0.6), C_TILE])
	# Mái rủ + góc hất
	local.append([Vector3(0, 3.2, 1.05), Vector3(5.5, 0.12, 0.45), C_TILE])
	local.append([Vector3(0, 3.2, -1.05), Vector3(5.4, 0.12, 0.42), C_TILE])
	local.append([Vector3(2.9, 3.6, 0.3), Vector3(0.45, 0.14, 0.45), C_TILE_DARK])
	local.append([Vector3(-2.9, 3.6, -0.3), Vector3(0.45, 0.14, 0.45), C_TILE_DARK])
	# Vòm cửa bán nguyệt + lanh tô + bảng làng
	local.append([Vector3(0, 1.15, 0.28), Vector3(2.2, 1.1, 0.5), C_LIME])
	local.append([Vector3(0, 2.35, 0.28), Vector3(2.6, 0.35, 0.5), C_TILE_DARK])
	local.append([Vector3(0, 2.75, 0.28), Vector3(2.5, 0.55, 0.4), C_WOOD_DARK])
	local.append([Vector3(0, 2.75, 0.48), Vector3(2.1, 0.32, 0.12), C_LIME])
	# Máng xối dọc đường
	local.append([Vector3(0, 3.75, 0.75), Vector3(5.5, 0.3, 0.12), C_WOOD_DARK])
	_emit_boxes(xforms, colors, local, yaw, Vector3(at.x, gy, at.y))

## ── Đình làng / miếu thờ cổ ─────────────────────────────────────────────────
static func _add_shrine(xforms: Array, colors: Array, at: Vector2, yaw: float, gy: float) -> void:
	var local: Array = []
	# Sân đình lát gạch tàu
	local.append([Vector3(0, 0.05, 0.4), Vector3(4.6, 0.16, 4.2), C_BRICK])
	# Nền + tường vôi
	local.append([Vector3(0, 0.35, 0), Vector3(3.4, 0.3, 2.8), C_STONE])
	local.append([Vector3(0, 1.35, -1.25), Vector3(3.4, 2.3, 0.28), C_LIME])
	local.append([Vector3(-1.68, 1.35, 0), Vector3(0.28, 2.3, 2.6), C_LIME])
	local.append([Vector3(1.68, 1.35, 0), Vector3(0.28, 2.3, 2.6), C_LIME])
	# Cột gạch sơn đỏ sẫm trước hiên
	local.append([Vector3(-1.1, 1.35, 1.3), Vector3(0.32, 2.6, 0.32), Color(0.55, 0.18, 0.12)])
	local.append([Vector3(1.1, 1.35, 1.3), Vector3(0.32, 2.6, 0.32), Color(0.55, 0.18, 0.12)])
	# Tượng thờ bên trong
	local.append([Vector3(0, 0.75, -0.4), Vector3(0.55, 0.9, 0.45), C_WOOD_DARK])
	# Mái ngói xếp tầng + gờ mái
	local.append([Vector3(0, 2.75, 0), Vector3(4.8, 0.34, 4.0), C_TILE])
	local.append([Vector3(0, 3.05, 0), Vector3(3.4, 0.3, 2.8), C_TILE_DARK])
	local.append([Vector3(0, 3.35, 0), Vector3(1.5, 0.26, 0.6), C_TILE])
	# 4 góc hất + rồng/mây trắng xanh trên gờ
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			local.append([Vector3(sx * 2.45, 2.95, sz * 2.05), Vector3(0.4, 0.3, 0.4), C_TILE_DARK])
	local.append([Vector3(0.6, 3.3, 0.6), Vector3(0.5, 0.2, 0.16), Color(0.62, 0.78, 0.85)])
	local.append([Vector3(-0.7, 3.3, -0.5), Vector3(0.5, 0.2, 0.16), Color(0.62, 0.78, 0.85)])
	# Rêu trên mái
	local.append([Vector3(1.9, 2.9, -1.6), Vector3(0.55, 0.18, 0.3), C_MOSS])
	# Bát hương
	local.append([Vector3(0, 0.25, 1.05), Vector3(0.28, 0.18, 0.28), Color(0.8, 0.78, 0.7)])
	_emit_boxes(xforms, colors, local, yaw, Vector3(at.x, gy, at.y))

## ── Giếng làng — thành đá tròn + nước + mái che + gáo dừa ──────────────────
static func _add_well(xforms: Array, colors: Array, at: Vector2, gy: float) -> void:
	var local: Array = []
	for sx in [-1, 1]:
		local.append([Vector3(sx * 0.6, 0.28, 0), Vector3(0.4, 0.56, 1.6), C_STONE])
		local.append([Vector3(0, 0.28, sx * 0.6), Vector3(1.6, 0.56, 0.4), C_STONE])
	# Nước trong giếng
	local.append([Vector3(0, 0.04, 0), Vector3(1.1, 0.08, 1.1), C_WATER])
	# Mái che: 2 cột + xà + mái lá
	for sx in [-1, 1]:
		local.append([Vector3(sx * 0.95, 1.3, 0), Vector3(0.14, 2.5, 0.14), C_WOOD_DARK])
	local.append([Vector3(0, 1.6, 0), Vector3(0.12, 0.12, 1.9), C_WOOD_DARK])
	local.append([Vector3(0, 2.55, 0), Vector3(2.5, 0.16, 1.5), C_THATCH])
	local.append([Vector3(0, 2.68, 0), Vector3(1.9, 0.12, 1.1), C_THATCH_DARK])
	# Gáo dừa treo
	local.append([Vector3(0, 1.35, 0.35), Vector3(0.16, 0.22, 0.16), C_BAMBOO])
	# Rêu trên thành
	local.append([Vector3(0.65, 0.5, 0.3), Vector3(0.3, 0.14, 0.5), C_MOSS])
	local.append([Vector3(-0.65, 0.45, -0.4), Vector3(0.3, 0.12, 0.5), C_MOSS])
	_emit_boxes(xforms, colors, local, 0.0, Vector3(at.x, gy, at.y))

## ── Lò gạch cổ — tháp vòm thu nhỏ dần + lỗ thoát khói + dây leo ────────────
static func _add_kiln(xforms: Array, colors: Array, at: Vector2, gy: float) -> void:
	var local: Array = []
	local.append([Vector3(0, 0.6, 0), Vector3(4.8, 1.2, 4.8), C_BRICK])
	local.append([Vector3(0, 1.9, 0), Vector3(3.8, 1.0, 3.8), C_BRICK])
	local.append([Vector3(0, 3.0, 0), Vector3(2.8, 0.9, 2.8), Color(0.74, 0.3, 0.14)])
	local.append([Vector3(0, 4.0, 0), Vector3(1.8, 0.8, 1.8), Color(0.62, 0.24, 0.12)])
	# Đỉnh + lỗ thoát khói
	local.append([Vector3(0, 4.9, 0), Vector3(0.9, 0.6, 0.9), C_TILE_DARK])
	local.append([Vector3(0, 5.45, 0), Vector3(0.45, 0.5, 0.45), Color(0.15, 0.13, 0.12)])
	# Vệt gạch cháy đen
	local.append([Vector3(0, 1.6, 0), Vector3(4.95, 0.26, 4.95), Color(0.3, 0.16, 0.1)])
	local.append([Vector3(0, 3.1, 0), Vector3(2.95, 0.2, 2.95), Color(0.3, 0.16, 0.1)])
	# Cửa lò vòm
	local.append([Vector3(0, 0.65, 2.48), Vector3(1.5, 1.1, 0.3), Color(0.2, 0.13, 0.1)])
	# Dây leo phủ từ đỉnh xuống
	local.append([Vector3(0.9, 4.6, 0.9), Vector3(0.3, 0.7, 0.3), C_MOSS])
	local.append([Vector3(-0.9, 4.2, -0.9), Vector3(0.26, 0.9, 0.26), C_MOSS])
	local.append([Vector3(0.9, 3.6, -0.9), Vector3(0.24, 0.8, 0.24), C_MOSS])
	local.append([Vector3(-1.4, 2.6, 1.2), Vector3(0.3, 0.7, 0.3), C_MOSS])
	_emit_boxes(xforms, colors, local, 0.0, Vector3(at.x, gy, at.y))

## ── Chợ quê — dãy sạp gỗ + mái lá + nông sản ───────────────────────────────
static func _add_stall(xforms: Array, colors: Array, at: Vector2, yaw: float, gy: float) -> void:
	var local: Array = []
	# 2 cột + mái lá
	for sx in [-1, 1]:
		local.append([Vector3(sx * 1.1, 1.15, 0), Vector3(0.14, 2.3, 0.14), C_WOOD_DARK])
	local.append([Vector3(0, 2.35, 0), Vector3(3.0, 0.16, 2.1), C_THATCH])
	local.append([Vector3(0, 2.48, 0), Vector3(2.5, 0.12, 1.6), C_THATCH_DARK])
	# Kệ gỗ bậc thang
	local.append([Vector3(0, 0.55, 0.1), Vector3(2.5, 0.8, 0.9), C_WOOD])
	local.append([Vector3(0, 1.1, 0.25), Vector3(1.9, 0.6, 0.7), C_WOOD])
	# Nông sản trưng bày
	local.append([Vector3(-0.6, 1.0, 0.1), Vector3(0.3, 0.3, 0.3), C_PROD_RED])
	local.append([Vector3(0.1, 1.0, 0.1), Vector3(0.28, 0.34, 0.28), C_PROD_YEL])
	local.append([Vector3(0.7, 1.0, 0.1), Vector3(0.3, 0.26, 0.3), C_PROD_GRN])
	local.append([Vector3(-0.2, 1.45, 0.28), Vector3(0.32, 0.28, 0.32), C_PROD_RED])
	local.append([Vector3(0.45, 1.45, 0.28), Vector3(0.3, 0.3, 0.3), C_PROD_YEL])
	# Mái bạt nhăn nhẹ
	local.append([Vector3(0.4, 2.5, 0.5), Vector3(0.7, 0.08, 0.5), Color(0.75, 0.65, 0.5)])
	_emit_boxes(xforms, colors, local, yaw, Vector3(at.x, gy, at.y))

## ── Bến nước — sàn gỗ nhô ra sông + cọc buộc ghe + bậc thang ───────────────
static func _add_dock(xforms: Array, colors: Array, river: Dictionary,
		height_grid: Array, cx: int, cz: int, size: int, cols: int) -> void:
	var rp: Vector2 = Vector2(river.pt.x, river.pt.y)
	# Tìm ô đất liền kề sông để đặt bến
	var land_cell: Vector2i = Vector2i(-1, -1)
	var best_d2: float = 1e18
	for off in range(cols * cols):
		var vx: int = off / cols
		var vz: int = off % cols
		var p: Vector2 = Vector2(
			float(cx) * size - float(size) * 0.5 + (float(vx) + 0.5),
			float(cz) * size - float(size) * 0.5 + (float(vz) + 0.5))
		var d2: float = p.distance_squared_to(rp)
		if d2 >= best_d2:
			continue
		if height_grid[vx][vz] <= _Data.WATER_Y:
			continue
		best_d2 = d2
		land_cell = Vector2i(vx, vz)
	if land_cell.x < 0:
		return
	var land_world: Vector2 = Vector2(
		float(cx) * size - float(size) * 0.5 + (float(land_cell.x) + 0.5),
		float(cz) * size - float(size) * 0.5 + (float(land_cell.y) + 0.5))
	var toward: Vector2 = (rp - land_world)
	if toward.length() < 0.1:
		return
	toward = toward.normalized()
	var gy: float = height_grid[land_cell.x][land_cell.y] + 0.02
	# Sàn gỗ nhô ra nước + cọc + bậc thang
	var local: Array = []
	local.append([Vector3(0, 0.35, 0.5), Vector3(2.4, 0.16, 2.6), C_WOOD])
	local.append([Vector3(0, 0.25, 2.2), Vector3(1.8, 0.12, 1.2), C_WOOD])
	local.append([Vector3(0, 0.15, 3.2), Vector3(1.2, 0.1, 0.8), C_WOOD])
	for sx in [-1, 1]:
		local.append([Vector3(sx * 0.9, 0.4, 2.2), Vector3(0.14, 0.8, 0.14), C_WOOD_DARK])
	# Cọc buộc ghe xuồng
	local.append([Vector3(0, 0.6, 4.0), Vector3(0.18, 1.2, 0.18), C_WOOD_DARK])
	local.append([Vector3(0.55, 0.35, 4.6), Vector3(0.15, 0.7, 0.15), C_WOOD_DARK])
	# Bậc thang gạch xuống mực nước
	local.append([Vector3(0, 0.1, -0.4), Vector3(2.0, 0.2, 0.8), C_BRICK])
	# Lan can tay vịn
	local.append([Vector3(0, 0.85, 1.4), Vector3(2.2, 0.5, 0.08), C_BAMBOO])
	var yaw: float = atan2(-toward.x, -toward.y)
	_emit_boxes(xforms, colors, local, yaw, Vector3(land_world.x, gy, land_world.y))
