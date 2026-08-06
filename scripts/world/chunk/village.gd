extends RefCounted

## ── Quán Rượu — half-timbered châu Âu, bên mép đường cái ────────────────────
## Deterministic theo chunk (cùng cx,cz → cùng quán). Mọc tại ngã 3 (10%) và
## ngã tư (80%) của mạng lưới đường — đặt LỆCH khỏi tâm ngã, nằm sát vai đường,
## mặt nhà quay về phía đường. Không bao giờ đè lên lòng đường.
##
## Quán = tập "hộp màu" (Transform3D + Color) dựng qua MultiMesh.
## Công trình: khối chính (trệt + tầng 2 + áp mái) mái ngói xanh so le, cánh phụ
## 2 tầng có jetty nhô ra, ống khói đá + khói voxel, biển hiệu, hiên + bậc thang,
## nền móng đá, thùng rượu / xe kéo / thùng gỗ / cây xanh.

const _Data = preload("chunk_data.gd")
const _Road = preload("chunk_road.gd")

static var DEBUG: bool = false
static var _dbg_count: int = 0

const TAVERN_MIN_DIST: float = 120.0   # cách spawn (0,0) tối thiểu (m)
const T3_CHANCE: int = 10               # xác suất ngã 3 có quán (%)
const T4_CHANCE: int = 80               # xác suất ngã tư có quán (%)
const FOOT_RX: int = 9                   # bán kính chân công trình (ô, trục X)
const FOOT_RZ: int = 7                   # bán kính chân công trình (ô, trục Z)

# ── Bảng màu quán rượu ─────────────────────────────────────────────────────────
const C_ROOF:      Color = Color(0.31, 0.61, 0.88)   # ngói xanh dương sáng
const C_ROOF_DK:   Color = Color(0.19, 0.44, 0.72)   # ngói xanh đậm (so le)
const C_ROOF_HI:   Color = Color(0.40, 0.72, 0.96)   # viên ngói sáng (mép)
const C_TRIM:      Color = Color(0.31, 0.21, 0.12)   # khung gỗ sậm (half-timber)
const C_TRIM_W:    Color = Color(0.43, 0.30, 0.16)   # khung gỗ nhạt hơn
const C_WALL:      Color = Color(0.93, 0.89, 0.80)   # tường trát sữa/kem
const C_WALL_B:    Color = Color(0.79, 0.75, 0.65)   # tường cũ bẩn
const C_WALL_P:    Color = Color(0.78, 0.68, 0.56)   # mảng trát bong tróc
const C_STONE:     Color = Color(0.55, 0.51, 0.46)   # nền móng đá
const C_STONE_DK:  Color = Color(0.41, 0.37, 0.33)
const C_WINDOW:    Color = Color(0.08, 0.17, 0.28)   # kính xanh đen
const C_DOOR:      Color = Color(0.36, 0.24, 0.14)   # cửa gỗ
const C_DECK:      Color = Color(0.52, 0.40, 0.25)   # sàn ván gỗ
const C_DECK_DK:   Color = Color(0.38, 0.28, 0.17)
const C_SMOKE_A:   Color = Color(0.58, 0.58, 0.62)
const C_SMOKE_B:   Color = Color(0.71, 0.74, 0.80)
const C_BARREL:    Color = Color(0.71, 0.55, 0.30)   # thùng rượu gỗ
const C_BARREL_DK: Color = Color(0.50, 0.39, 0.22)
const C_IRON:      Color = Color(0.20, 0.17, 0.15)   # đai sắt
const C_CRATE:     Color = Color(0.62, 0.45, 0.27)   # thùng gỗ
const C_CRATE_DK:  Color = Color(0.48, 0.34, 0.18)
const C_CART:      Color = Color(0.55, 0.42, 0.26)   # xe kéo
const C_LOAD:      Color = Color(0.72, 0.62, 0.42)   # bao tải
const C_SIGN:      Color = Color(0.95, 0.94, 0.89)   # bảng hiệu trắng
const C_SIGN_LT:   Color = Color(0.12, 0.10, 0.09)   # chữ/bảng viền đen
const C_TREE:      Color = Color(0.37, 0.25, 0.13)   # thân cây
const C_LEAF_A:    Color = Color(0.20, 0.52, 0.18)   # tán lá
const C_LEAF_B:    Color = Color(0.16, 0.42, 0.14)
const C_LEAF_C:    Color = Color(0.27, 0.60, 0.20)

static func _vh_hash(seed_v: int, salt: int) -> int:
	var h: int = seed_v ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7FFFFFFF

## ── Entry: compute_village ─────────────────────────────────────────────────────
static func compute_village(cx: int, cz: int, size: int, dim_id: int,
		biome_grid: Array, height_grid: Array, road_grid: PackedByteArray,
		_river_flag: PackedByteArray, cols: int) -> Dictionary:
	var empty := { "has": false, "xforms": [], "colors": [], "info": {} }
	if dim_id != _Data._Dim.DimensionID.REAL_WORLD:
		return empty

	var xforms: Array = []
	var colors: Array = []
	var buildings: Array = []
	_find_taverns(xforms, colors, buildings, cx, cz, size,
		biome_grid, height_grid, road_grid, cols)
	if buildings.is_empty():
		return empty

	var origin := Vector3(cx * size, 0.0, cz * size)
	for i in range(xforms.size()):
		xforms[i] = Transform3D((xforms[i] as Transform3D).basis,
			(xforms[i] as Transform3D).origin - origin)

	return {
		"has": true,
		"xforms": xforms,
		"colors": colors,
		"info": { "buildings": buildings },
	}

## ── Quét các node lưới đường phủ chunk (+ mép); roll xác suất từng ngã ────────
static func _find_taverns(xforms: Array, colors: Array, buildings: Array,
		cx: int, cz: int, size: int, biome_grid: Array, height_grid: Array,
		road_grid: PackedByteArray, cols: int) -> void:
	_Road._ensure_roads()
	var min_wx: float = float(cx) * size - float(size) * 0.5
	var min_wz: float = float(cz) * size - float(size) * 0.5
	var max_wx: float = min_wx + float(size)
	var max_wz: float = min_wz + float(size)
	var GRID: float = _Data.ROAD_GRID
	var margin: float = 45.0   # jitter node ±22 + vươn quán ~21: node phải được chunk chứa quán đánh giá
	var gx0: int = floori((min_wx - margin) / GRID)
	var gx1: int = floori((max_wx + margin) / GRID)
	var gz0: int = floori((min_wz - margin) / GRID)
	var gz1: int = floori((max_wz + margin) / GRID)
	gx0 = maxi(gx0, -_Data.ROAD_GRID_R)
	gx1 = mini(gx1, _Data.ROAD_GRID_R)
	gz0 = maxi(gz0, -_Data.ROAD_GRID_R)
	gz1 = mini(gz1, _Data.ROAD_GRID_R)
	for gx in range(gx0, gx1 + 1):
		for gz in range(gz0, gz1 + 1):
			_try_tavern(xforms, colors, buildings, gx, gz, size,
				biome_grid, height_grid, road_grid, cols, min_wx, min_wz)

## ── Một node ngã/xu: roll xác suất, tìm chỗ đậu quán ──────────────────────────
static func _try_tavern(xforms: Array, colors: Array, buildings: Array,
		gx: int, gz: int, _size: int, biome_grid: Array, height_grid: Array,
		road_grid: PackedByteArray, cols: int, min_wx: float, min_wz: float) -> void:
	if DEBUG:
		_dbg_count += 1
		if _dbg_count > 100000:
			return
	var deg: int = _Road.intersection_degree(gx, gz)
	if deg < 3 or deg > 4:
		return
	var seed_base: int = SeedSnapshot.ensure() + 7777
	var h: int = _vh_hash(seed_base ^ (gx * 53031 + gz * 70003), 0x1F0B2E)
	var r: int = h & 0x7FFFFFFF
	var chance: int = T3_CHANCE if deg == 3 else T4_CHANCE
	if r % 100 >= chance:
		if DEBUG:
			print("TT node(%d,%d) deg=%d ROLL-FAIL %d/%d" % [gx, gz, deg, r % 100, chance])
		return
	if DEBUG:
		print("TT node(%d,%d) deg=%d roll-OK %d/%d" % [gx, gz, deg, r % 100, chance])

	var has: Array = _Road.intersection_has(gx, gz)
	var dirs: Array = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	var con_idx: Array = []
	for d in range(4):
		if has[d]:
			con_idx.append(d)
	if con_idx.is_empty():
		return
	var node_pt: Vector2 = _Road.intersection_point(gx, gz)

	for attempt in range(30):
		var ha: int = _vh_hash(h ^ 0x51AB, attempt + 1)
		var di: int = con_idx[ha % con_idx.size()]
		var rd: Vector2 = dirs[di]
		var perp: Vector2 = Vector2(-rd.y, rd.x)
		var sign: float = 1.0 if (ha & 1) == 0 else -1.0
		var back: float = 7.5 + float((ha >> 4) % 3) * 1.7   # 7.5 / 9.2 / 10.9 dọc đường
		var side: float = 9.0 + float((ha >> 8) % 3) * 0.8   # 9.0/9.8/10.6 — cách tim đường ≥ 1.5+7+0.5

		var center: Vector2 = node_pt + rd * back + perp * (sign * side)
		if center.length() < TAVERN_MIN_DIST:
			if DEBUG:
				print("  try%d too-close-to-spawn (%.1f)" % [attempt, center.length()])
			continue
		var cc := Vector2i(int(floor(center.x - min_wx)), int(floor(center.y - min_wz)))
		if DEBUG and attempt == 0:
			print("  try0 node=(%.1f,%.1f) rd=%s perp=%s back=%.1f side=%.1f sign=%.1f center=(%.1f,%.1f) cc=%s" %
				[node_pt.x, node_pt.y, str(rd), str(perp), back, side, sign, center.x, center.y, str(cc)])
		if not _cell_ok(cc, cols):
			if DEBUG:
				print("  try%d cell-out cc=%s" % [attempt, str(cc)])
			continue
		if not _footprint_ok(cc, cols, biome_grid, height_grid, road_grid, FOOT_RX, FOOT_RZ):
			if DEBUG:
				print("  try%d foot-FAIL center=(%.1f,%.1f) cc=%s" % [attempt, center.x, center.y, str(cc)])
			continue
		if DEBUG:
			print("  try%d PLACED center=(%.1f,%.1f) cc=%s" % [attempt, center.x, center.y, str(cc)])

		var road_pt: Vector2 = node_pt + rd * back
		var toward: Vector2 = road_pt - center
		if toward.length() < 0.1:
			toward = Vector2(0, 1)
		toward = toward.normalized()
		var yaw: float = atan2(-toward.x, -toward.y)
		var gy: float = height_grid[cc.x][cc.y] + 0.02
		_add_tavern(xforms, colors, center, yaw, gy)
		buildings.append({
			"type": "tavern", "x": center.x, "z": center.y,
			"yaw": yaw, "deg": deg, "gx": gx, "gz": gz,
		})
		return

## ── Kiểm tra ô trong chunk ─────────────────────────────────────────────────────
static func _cell_ok(c: Vector2i, cols: int) -> bool:
	return c.x >= 0 and c.x < cols and c.y >= 0 and c.y < cols

## ── Kiểm tra chân công trình: đất phẳng, không đường, không nước ─────────────
static func _footprint_ok(c: Vector2i, cols: int, _biome_grid: Array,
		height_grid: Array, road_grid: PackedByteArray, rx: int, rz: int) -> bool:
	if not _cell_ok(c, cols):
		return false
	var ref_h: float = height_grid[c.x][c.y]
	for dx in range(-rx, rx + 1):
		for dz in range(-rz, rz + 1):
			var nx: int = c.x + dx
			var nz: int = c.y + dz
			if not _cell_ok(Vector2i(nx, nz), cols):
				if DEBUG:
					print("    foot: out-of-chunk cell (%d,%d)" % [nx, nz])
				return false
			if height_grid[nx][nz] <= _Data.WATER_Y:
				if DEBUG:
					print("    foot: water cell (%d,%d) h=%.2f" % [nx, nz, height_grid[nx][nz]])
				return false
			if absf(height_grid[nx][nz] - ref_h) > 1.0:
				if DEBUG:
					print("    foot: uneven cell (%d,%d) dh=%.2f" % [nx, nz, height_grid[nx][nz] - ref_h])
				return false
			if road_grid.size() > 0 and road_grid[nx * cols + nz] != 0:
				if DEBUG:
					print("    foot: road cell (%d,%d)" % [nx, nz])
				return false
	return true

## ── Emit hộp (world space) ─────────────────────────────────────────────────────
static func _emit_box(xforms: Array, colors: Array, pos: Vector3,
		sz: Vector3, col: Color) -> void:
	xforms.append(Transform3D(Basis().scaled(sz), pos))
	colors.append(col)

## ── Emit nhóm hộp local → world (xoay yaw quanh Y) ────────────────────────────
static func _emit_boxes(xforms: Array, colors: Array, local: Array,
		yaw: float, base: Vector3) -> void:
	var rot := Basis(Vector3.UP, yaw)
	for item in local:
		var pos: Vector3 = item[0]
		var sz: Vector3 = item[1]
		var col: Color = item[2]
		xforms.append(Transform3D(rot.scaled(sz), base + rot * pos))
		colors.append(col)

## ── Thanh vạch gạch (bước từng khối) giữa 2 điểm trong mặt phẳng ──────────────
static func _bar(local: Array, v: Vector3, w: Vector3, th: float, col: Color) -> void:
	var delta: Vector3 = w - v
	var span: float = maxf(absf(delta.x), maxf(absf(delta.y), absf(delta.z)))
	var steps: int = maxi(2, int(ceil(span / 0.5)))
	for i in range(steps):
		var t: float = (float(i) + 0.5) / float(steps)
		local.append([v + delta * t, Vector3(th, th, th), col])

## ── Cửa sổ ×2×2 (kính xanh đen + khung gỗ + thanh chữ thập) ──────────────────
static func _win(local: Array, x: float, z: float, y: float, w: float, h: float) -> void:
	var th: float = 0.10
	local.append([Vector3(x, y, z), Vector3(w + 0.16, h + 0.12, th + 0.06), C_TRIM])
	local.append([Vector3(x - 0.12, y, z), Vector3(w - 0.20, h - 0.40, th + 0.10), C_WINDOW])
	local.append([Vector3(x + 0.12, y, z), Vector3(w - 0.20, h - 0.40, th + 0.10), C_WINDOW])
	local.append([Vector3(x, y + (h - 0.40) * 0.25, z), Vector3(w - 0.20, 0.08, th + 0.12), C_TRIM])
	local.append([Vector3(x - 0.30, y, z), Vector3(0.08, h - 0.40, th + 0.12), C_TRIM])
	local.append([Vector3(x + 0.30, y, z), Vector3(0.08, h - 0.40, th + 0.12), C_TRIM])

## ── Mái so le: chạy từ đỉnh (ngọn) ra mép, mỗi lớp 1 phiến ngói ──────────────
## cx_off = lệch trục ridge (0 = mái chính; >0 = mái cánh phải)
static func _roof(local: Array, ridge_y: float, half_w: float,
		z_a: float, z_b: float, step: float, drop: float, cx_off: float = 0.0) -> void:
	var z_mid: float = (z_a + z_b) * 0.5
	var z_len: float = z_b - z_a
	var rows: int = maxi(1, int(ceil(half_w / step)))
	for i in range(rows):
		var xc: float = (float(i) + 0.5) * step
		var yc: float = ridge_y - float(i) * drop
		var col: Color = C_ROOF_DK if (i & 1) == 1 else C_ROOF
		local.append([Vector3(xc + cx_off, yc, z_mid), Vector3(step * 1.02, 0.17, z_len), col])
		local.append([Vector3(-xc + cx_off, yc, z_mid), Vector3(step * 1.02, 0.17, z_len), col])
	# Sống nóc + viền mép
	local.append([Vector3(cx_off, ridge_y + 0.08, z_mid), Vector3(0.5, 0.20, z_len), C_ROOF_HI])
	local.append([Vector3(cx_off, ridge_y - 0.06, z_mid), Vector3(1.1, 0.14, z_len), C_ROOF_DK])

## ── Cửa + khung cửa (mặt trước) ───────────────────────────────────────────────
static func _door(local: Array) -> void:
	local.append([Vector3(0.0, 1.25, -2.32), Vector3(1.55, 2.05, 0.30), C_DOOR])
	local.append([Vector3(-0.88, 1.25, -2.32), Vector3(0.18, 2.2, 0.34), C_TRIM])
	local.append([Vector3(0.88, 1.25, -2.32), Vector3(0.18, 2.2, 0.34), C_TRIM])
	local.append([Vector3(0.0, 2.62, -2.32), Vector3(1.9, 0.35, 0.30), C_TRIM])
	# nẹp dọc cửa + tay cầm
	local.append([Vector3(0.0, 1.25, -2.36), Vector3(0.10, 2.05, 0.06), C_DECK_DK])
	local.append([Vector3(0.55, 1.15, -2.38), Vector3(0.12, 0.12, 0.10), Color(0.80, 0.72, 0.30)])

## ── Tường trệt khối chính (main): 4 vách + nền móng đá ───────────────────────
static func _tavern_wall_main(local: Array) -> void:
	var yb: float = 0.30
	var yt: float = 3.20
	var ym: float = (yb + yt) * 0.5
	var zh: float = yt - yb
	# vách sau (z=+6.55)
	local.append([Vector3(0.0, ym, 6.55), Vector3(11.2, zh + 0.1, 0.34), C_WALL])
	# vách trái (x=-5.35)
	local.append([Vector3(-5.35, ym, 2.0), Vector3(0.34, zh + 0.1, 9.2), C_WALL_B])
	# vách phải (x=+5.35)
	local.append([Vector3(5.35, ym, 2.0), Vector3(0.34, zh + 0.1, 9.2), C_WALL_B])
	# vách trước (z=-2.35): 2 tấm 2 bên cửa
	local.append([Vector3(-3.45, ym, -2.35), Vector3(3.2, zh, 0.34), C_WALL])
	local.append([Vector3(5.15, ym, -2.35), Vector3(7.8, zh, 0.34), C_WALL])
	# mảng trát bong tróc (mặt trước + sau)
	local.append([Vector3(-3.6, 1.4, -2.42), Vector3(1.1, 0.9, 0.14), C_WALL_P])
	local.append([Vector3(2.6, 2.2, -2.42), Vector3(1.4, 0.7, 0.14), C_WALL_P])
	local.append([Vector3(4.4, 1.0, -2.42), Vector3(0.9, 0.6, 0.14), C_WALL_P])
	# nền móng đá main
	local.append([Vector3(0.0, 0.10, 2.0), Vector3(12.4, 0.22, 10.2), C_STONE])
	local.append([Vector3(0.0, -0.02, 2.0), Vector3(12.8, 0.16, 10.6), C_STONE_DK])

## ── Cánh phụ (wing) 2 tầng, jetty nhô ra trước, mái nhỏ tụt dưới mái chính ───
static func _tavern_wing(local: Array) -> void:
	var xw0: float = 5.6
	var xw1: float = 9.4
	var xw: float = (xw0 + xw1) * 0.5
	# Nền móng cánh
	local.append([Vector3(xw, 0.10, 0.9), Vector3(4.2, 0.22, 5.6), C_STONE])
	local.append([Vector3(xw, -0.02, 0.9), Vector3(4.4, 0.16, 5.8), C_STONE_DK])
	# tường trệt cánh (z -1.6..3.4, y 0.3..3.2)
	local.append([Vector3(xw, 1.75, 3.42), Vector3(4.0, 3.0, 0.34), C_WALL])
	local.append([Vector3(xw, 1.75, -1.62), Vector3(4.0, 3.0, 0.34), C_WALL])
	local.append([Vector3(xw0 - 0.17, 1.75, 0.9), Vector3(0.34, 3.0, 5.0), C_WALL_B])
	local.append([Vector3(xw1 + 0.17, 1.75, 0.9), Vector3(0.34, 3.0, 5.0), C_WALL_B])
	# jetty: sàn đua ra trước (z -2.5..-1.5) + sườn đỡ chéo
	local.append([Vector3(xw, 4.55, -2.0), Vector3(4.2, 0.30, 1.15), C_DECK])
	for px in [xw0 + 0.4, xw1 - 0.4]:
		local.append([Vector3(px, 4.15, -1.85), Vector3(0.30, 1.15, 0.5), C_TRIM])
		_bar(local, Vector3(px - 0.35, 3.55, -1.9), Vector3(px + 0.05, 4.35, -1.9), 0.26, C_TRIM)
		_bar(local, Vector3(px + 0.35, 3.55, -1.9), Vector3(px - 0.05, 4.35, -1.9), 0.26, C_TRIM)
	# tường tầng 2 cánh (y 3.4..5.5, jetty z -2.5)
	local.append([Vector3(xw, 4.45, 3.42), Vector3(4.0, 2.2, 0.34), C_WALL_B])
	local.append([Vector3(xw, 4.45, -2.52), Vector3(4.0, 2.2, 0.30), C_WALL])
	local.append([Vector3(xw, 4.45, 0.9), Vector3(0.34, 2.2, 6.0), C_WALL_B])
	local.append([Vector3(xw0 - 0.17, 4.45, 0.9), Vector3(0.34, 2.2, 6.0), C_WALL_B])
	local.append([Vector3(xw1 + 0.17, 4.45, 0.9), Vector3(0.34, 2.2, 6.0), C_WALL_B])
	# khung tầng 2 cánh + cửa sổ jetty
	local.append([Vector3(xw0, 4.45, -2.52), Vector3(0.28, 2.2, 5.6), C_TRIM])
	local.append([Vector3(xw1, 4.45, -2.52), Vector3(0.28, 2.2, 5.6), C_TRIM])
	local.append([Vector3(xw, 3.62, -2.52), Vector3(4.0, 0.22, 0.28), C_TRIM_W])
	local.append([Vector3(xw, 5.42, -2.52), Vector3(4.0, 0.22, 0.28), C_TRIM_W])
	_win(local, xw - 1.1, -2.42, 4.35, 0.75, 0.75)
	_win(local, xw + 1.1, -2.42, 4.35, 0.75, 0.75)
	# mái cánh: ridge x=7.5, tụt dưới mái chính
	_roof(local, 6.0, 2.1, -2.9, 4.1, 0.6, 0.28, xw)

## ── Khung timbers lộ ra: tầng trệt X liên tục, tầng 2 dọc/ngang, gable chữ thập ──
static func _framing(local: Array) -> void:
	# cột góc + vành trệt
	for px in [-5.3, 5.3]:
		for zz in [-2.0, 6.05]:
			local.append([Vector3(px, 1.75, zz), Vector3(0.30, 3.2, 0.30), C_TRIM])
	for zz in [-2.2, 6.0]:
		local.append([Vector3(0.0, 0.20, zz), Vector3(11.4, 0.16, 0.30), C_TRIM])
	# tầng trệt: cột đứng giữa
	for px in [-3.5, -1.75, 1.75, 3.5]:
		local.append([Vector3(px, 1.75, -2.18), Vector3(0.26, 3.2, 0.26), C_TRIM])
		local.append([Vector3(px, 1.75, 6.0), Vector3(0.26, 3.2, 0.26), C_TRIM])
	# chữ X liên tục mặt trước (bỏ qua ô cửa)
	for px in [-5.3, -3.5, -1.75, 1.75, 3.5]:
		var xa: float = px + 0.15
		var xb: float = px + 1.60
		_bar(local, Vector3(xa, 0.55, -2.2), Vector3(xb, 3.05, -2.2), 0.16, C_TRIM)
		_bar(local, Vector3(xb, 0.55, -2.2), Vector3(xa, 3.05, -2.2), 0.16, C_TRIM)
	# chữ X mặt trái (vách x=-5.35)
	for zz in [-1.5, 0.4, 2.3, 4.2]:
		var za: float = zz + 0.15
		var zb: float = zz + 1.60
		_bar(local, Vector3(-5.38, 0.55, za), Vector3(-5.38, 3.05, zb), 0.16, C_TRIM)
		_bar(local, Vector3(-5.38, 0.55, zb), Vector3(-5.38, 3.05, za), 0.16, C_TRIM)
	# tầng 2: cột dọc + ghi ngang (mặt trước + sau)
	for px in [-5.3, -3.95, -2.6, -1.25, 1.25, 2.6, 3.95, 5.3]:
		local.append([Vector3(px, 4.9, -2.2), Vector3(0.28, 3.4, 0.18), C_TRIM])
		local.append([Vector3(px, 4.9, 6.0), Vector3(0.28, 3.4, 0.18), C_TRIM])
	for px in [-4.55, -3.2, -1.85, -0.5, 0.5, 1.85, 3.2, 4.55]:
		_bar(local, Vector3(px, 3.65, -2.2), Vector3(px, 6.2, -2.2), 0.14, C_TRIM)
		_bar(local, Vector3(px, 3.65, 6.0), Vector3(px, 6.2, 6.0), 0.14, C_TRIM)
	# thanh ngang tầng 2
	for yy in [3.9, 5.2]:
		local.append([Vector3(0.0, yy, -2.2), Vector3(11.0, 0.14, 0.14), C_TRIM])
		local.append([Vector3(0.0, yy, 6.0), Vector3(11.0, 0.14, 0.14), C_TRIM])
	# dấu thập trong khung vuông — mặt gable trái (x=-5.36)
	var gy2: float = 6.9
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			local.append([Vector3(sx * 1.05, gy2 + sy * 1.05, -5.38), Vector3(0.30, 0.30, 0.26), C_TRIM])
	_bar(local, Vector3(-1.75, gy2 - 1.6, -5.38), Vector3(1.75, gy2 + 1.6, -5.38), 0.18, C_TRIM)
	_bar(local, Vector3(-1.75, gy2 + 1.6, -5.38), Vector3(1.75, gy2 - 1.6, -5.38), 0.18, C_TRIM)

## ── Mái + fascia + ống khói + biển hiệu + hiên + bậc ──────────────────────────
static func _tavern_top(local: Array) -> void:
	# mái chính so le
	_roof(local, 9.2, 6.9, -3.2, 7.4, 0.6, 0.30)
	# fascia viền mép mái (gỗ sậm) — 2 đầu hồi + mép trước/sau
	for xx in [-6.95, 6.95]:
		local.append([Vector3(xx, 5.5, 2.1), Vector3(0.22, 0.16, 11.0), C_TRIM_W])
	for zz in [-3.15, 7.35]:
		local.append([Vector3(0.0, 5.6, zz), Vector3(16.0, 0.14, 0.22), C_TRIM_W])
	# ống khói đá (phải) + khói voxel mờ dần
	local.append([Vector3(2.2, 7.6, -2.3), Vector3(1.3, 0.22, 1.3), C_STONE_DK])
	local.append([Vector3(2.2, 8.35, -2.3), Vector3(1.0, 1.2, 1.0), C_STONE])
	local.append([Vector3(2.2, 9.05, -2.3), Vector3(0.85, 1.1, 0.85), C_STONE_DK])
	local.append([Vector3(2.2, 10.15, -2.3), Vector3(1.15, 0.22, 1.15), C_STONE])
	local.append([Vector3(2.2, 10.45, -2.3), Vector3(0.55, 0.30, 0.55), Color(0.28, 0.27, 0.30)])
	var smoke_off: Array = [-0.15, 0.20, -0.05, 0.30, 0.0]
	for si in range(5):
		var wd: float = 0.50 - float(si) * 0.05
		local.append([Vector3(2.2 + smoke_off[si], 11.0 + float(si) * 0.5, -2.3 + smoke_off[si] * 0.6),
			Vector3(wd, 0.46, wd), C_SMOKE_A.lerp(C_SMOKE_B, float(si) / 4.0)])
	# biển hiệu treo cạnh cửa: khung + chữ "TV" đen trên nền trắng
	var bx: float = -0.85
	local.append([Vector3(bx, 3.1, -2.42), Vector3(0.08, 0.9, 0.08), C_TRIM])
	local.append([Vector3(bx, 3.1, -2.5), Vector3(0.06, 1.3, 0.06), C_TRIM])
	local.append([Vector3(bx, 2.5, -2.55), Vector3(1.45, 0.10, 0.10), C_TRIM])
	local.append([Vector3(bx, 1.85, -2.6), Vector3(1.45, 1.05, 0.10), C_TRIM])
	local.append([Vector3(bx, 1.85, -2.62), Vector3(1.26, 0.86, 0.14), C_SIGN])
	# chữ T
	local.append([Vector3(bx - 0.36, 2.12, -2.62), Vector3(0.34, 0.42, 0.20), C_SIGN_LT])
	local.append([Vector3(bx - 0.36, 1.72, -2.62), Vector3(0.12, 0.38, 0.20), C_SIGN_LT])
	# chữ V (2 nét chéo)
	_bar(local, Vector3(bx + 0.16, 1.60, -2.62), Vector3(bx + 0.36, 2.32, -2.62), 0.22, C_SIGN_LT)
	_bar(local, Vector3(bx + 0.56, 1.60, -2.62), Vector3(bx + 0.36, 2.32, -2.62), 0.22, C_SIGN_LT)
	# hiên gỗ: sàn + cột + xà + lan can
	local.append([Vector3(0.0, 0.14, -2.95), Vector3(5.8, 0.18, 2.0), C_DECK])
	for px in [-2.4, 2.4]:
		local.append([Vector3(px, 1.9, -2.95), Vector3(0.30, 3.4, 0.30), C_TRIM_W])
		local.append([Vector3(px, 3.55, -2.95), Vector3(0.42, 0.14, 0.42), C_TRIM])
	local.append([Vector3(0.0, 3.2, -2.95), Vector3(5.6, 0.22, 0.30), C_TRIM])
	# lan can 2 bên hiên
	for px in [-2.55, 2.55]:
		local.append([Vector3(px, 1.05, -2.95), Vector3(0.12, 1.0, 0.12), C_DECK_DK])
		local.append([Vector3(px, 0.5, -2.95), Vector3(0.12, 0.9, 0.12), C_DECK_DK])
		local.append([Vector3(px, 1.5, -2.95), Vector3(0.10, 0.12, 0.12), C_DECK_DK])
	# bậc thang 3 bậc ra phía đường
	local.append([Vector3(0.0, 0.02, -3.95), Vector3(2.4, 0.18, 1.6), C_DECK])
	local.append([Vector3(0.0, 0.02, -4.70), Vector3(2.2, 0.15, 1.3), C_STONE_DK])
	local.append([Vector3(0.0, 0.02, -5.35), Vector3(2.1, 0.12, 1.1), C_STONE])

## ── Props: thùng rượu, thùng gỗ, xe kéo, cây xanh ─────────────────────────────
static func _props(local: Array) -> void:
	# 3 thùng rượu nằm (trục z) bên phải hiên + 1 thùng đứng cạnh móng
	for q in range(3):
		var pz: float = -4.5 + float(q) * 1.25
		local.append([Vector3(4.6, 0.52, pz), Vector3(0.78, 0.78, 1.15), C_BARREL])
		for off in [-1.05, 0.0, 1.05]:
			local.append([Vector3(4.6, 0.52, pz + off), Vector3(0.80, 0.34, 0.12), C_IRON])
		local.append([Vector3(4.6, 0.52, pz - 0.62), Vector3(0.80, 0.48, 0.10), C_BARREL_DK])
		local.append([Vector3(4.6, 0.52, pz + 0.62), Vector3(0.80, 0.48, 0.10), C_BARREL_DK])
	local.append([Vector3(7.0, 0.60, -2.9), Vector3(0.80, 1.15, 0.80), C_BARREL])
	for off in [0.34, 0.0, -0.34]:
		local.append([Vector3(7.0, 0.60, -2.9 + off), Vector3(0.82, 1.20, 0.24), C_IRON])
	# 2 thùng gỗ trước hiên trái
	for q in [0, 1]:
		var cx2: float = 3.4 + float(q) * 1.7
		local.append([Vector3(cx2, 0.30, -1.2), Vector3(0.90, 0.60, 0.90), C_CRATE])
		local.append([Vector3(cx2, 0.62, -1.2), Vector3(0.86, 0.10, 0.86), C_CRATE_DK])
	# xe kéo 4 bánh nan hoa chữ thập (trái sau)
	local.append([Vector3(-6.1, 0.45, 5.6), Vector3(3.0, 0.28, 1.8), C_CART])
	for s in [-1, 1]:
		local.append([Vector3(-6.1 + s * 1.15, 0.95, 5.15), Vector3(0.42, 0.55, 0.14), C_CART])
		local.append([Vector3(-6.1 + s * 1.15, 0.95, 6.05), Vector3(0.42, 0.55, 0.14), C_CART])
		_wheel(local, -6.1 + s * 1.15, 0.62, 5.15)
		_wheel(local, -6.1 + s * 1.15, 0.62, 6.05)
	# bao tải chồng lên xe
	local.append([Vector3(-6.1, 1.62, 5.6), Vector3(1.8, 0.42, 1.2), C_LOAD])
	local.append([Vector3(-5.5, 2.05, 5.75), Vector3(1.3, 0.38, 0.9), C_LOAD])
	# cây xanh 2 bên
	_add_tree(local, -8.2, -2.0, 1.0)
	_add_tree(local, 9.8, 1.4, 0.9)

## ── Bánh xe: vành + nan hoa chữ thập ──────────────────────────────────────────
static func _wheel(local: Array, cx2: float, cy: float, cz2: float) -> void:
	local.append([Vector3(cx2, cy, cz2), Vector3(0.18, 0.18, 0.16), C_CART])
	local.append([Vector3(cx2, cy, cz2), Vector3(0.54, 0.10, 0.14), C_CART])
	local.append([Vector3(cx2, cy, cz2), Vector3(0.10, 0.54, 0.14), C_CART])

## ── 1 cây: thân + các búi tán lá ──────────────────────────────────────────────
static func _add_tree(local: Array, tx: float, tz: float, s: float) -> void:
	local.append([Vector3(tx, 1.3 * s, tz), Vector3(0.46 * s, 2.8 * s, 0.46 * s), C_TREE])
	var blobs: Array = [
		[0.0, 2.6 * s, 0.0, 2.0 * s, C_LEAF_A],
		[-1.5 * s, 2.9 * s, 0.7 * s, 1.5 * s, C_LEAF_B],
		[1.3 * s, 3.3 * s, -0.9 * s, 1.4 * s, C_LEAF_A],
		[-0.4 * s, 3.9 * s, -1.5 * s, 1.5 * s, C_LEAF_C],
		[0.8 * s, 4.2 * s, 0.9 * s, 1.3 * s, C_LEAF_B],
		[-1.1 * s, 2.2 * s, -1.2 * s, 1.1 * s, C_LEAF_C],
	]
	for b in blobs:
		local.append([Vector3(tx + b[0], b[1], tz + b[2]), Vector3(b[3], b[3], b[3]), b[4]])

## ── Builder chính quán rượu ───────────────────────────────────────────────────
static func _add_tavern(xforms: Array, colors: Array, at: Vector2, yaw: float, gy: float) -> void:
	var local: Array = []
	_tavern_wall_main(local)
	_door(local)
	_tavern_wing(local)
	_framing(local)
	_tavern_top(local)
	_props(local)
	# cửa sổ tầng trệt + tầng 2 (khối chính)
	_win(local, -2.7, -2.3, 1.55, 0.85, 0.90)
	_win(local, 2.7, -2.3, 1.55, 0.85, 0.90)
	_win(local, -5.2, 2.0, 1.55, 0.85, 0.90)
	_win(local, 5.2, 2.0, 1.55, 0.85, 0.90)
	for px in [-3.9, -2.6, -1.3, 1.3, 2.6, 3.9]:
		_win(local, px, -2.25, 4.6, 0.80, 0.90)
	_emit_boxes(xforms, colors, local, yaw, Vector3(at.x, gy, at.y))