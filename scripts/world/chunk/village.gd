extends RefCounted

## ── Quán Rượu — half-timbered châu Âu, bên mép đường cái ────────────────────
## Deterministic theo chunk (cùng cx,cz → cùng quán). Mọc tại ngã 3 (45%) và
## ngã tư (98%) của mạng lưới đường — đặt LỆCH khỏi tâm ngã, nằm sát vai đường,
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
const T3_CHANCE: int = 45               # xác suất ngã 3 có quán (%)
const T4_CHANCE: int = 98               # xác suất ngã tư có quán (%)
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
# ── Nội thất quán ──────────────────────────────────────────────────────────────
const C_FLOOR:     Color = Color(0.47, 0.34, 0.21)   # sàn gỗ trong nhà
const C_FLOOR_DK:  Color = Color(0.34, 0.24, 0.14)   # ván sàn tối
const C_BAR:       Color = Color(0.52, 0.35, 0.18)   # quầy bar gỗ
const C_BAR_DK:    Color = Color(0.36, 0.24, 0.12)
const C_TABLE:     Color = Color(0.46, 0.30, 0.16)   # mặt bàn
const C_CHAIR:     Color = Color(0.40, 0.27, 0.15)   # ghế
const C_CAB:       Color = Color(0.34, 0.22, 0.12)   # tủ/kệ
const C_BOTTLE:    Color = Color(0.30, 0.44, 0.34)   # chai lọ trên kệ
const C_BOTTLE_A:  Color = Color(0.62, 0.38, 0.22)   # chai sành
const C_HEARTH:    Color = Color(0.42, 0.38, 0.34)   # lò sưởi đá
const C_FIRE:      Color = Color(0.95, 0.60, 0.18)   # lửa
const C_EMBER:     Color = Color(0.40, 0.22, 0.10)
const C_RUG:       Color = Color(0.56, 0.32, 0.20)   # thảm
const C_LANTERN_I: Color = Color(1.0, 0.86, 0.45)   # đèn treo trong nhà

static func _vh_hash(seed_v: int, salt: int) -> int:
	var h: int = seed_v ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7FFFFFFF

## ── Hướng cửa (vector 2D, trục nằm ngang) quay ra — thiên về Z+ và X+ ──────
## Deterministic theo node (seed h) để ổn định theo chunk. Đã build nhà rồi xoay
## toàn bộ một lần (theo yaw) nên hướng không làm đảo lộn cấu trúc.
static func _pick_facing(h: int) -> Vector2:
	const DIRS := [
		Vector2(1.0, 0.0),        # +X
		Vector2(0.7071, 0.7071),  # +X +Z
		Vector2(0.0, 1.0),        # +Z
		Vector2(-0.7071, 0.7071), # -X +Z
		Vector2(-1.0, 0.0),       # -X
		Vector2(-0.7071, -0.7071),# -X -Z
		Vector2(0.0, -1.0),       # -Z
		Vector2(0.7071, -0.7071), # +X -Z
	]
	# trọng số: ưu tiên cao cho +X, +Z, +X+Z; thấp cho hướng âm
	const W := [5, 6, 5, 3, 1, 1, 1, 3]
	var total: int = 0
	for w in W:
		total += w
	var r: int = _vh_hash(h ^ 0xBEEF, 17) % total
	var acc: int = 0
	for i in range(W.size()):
		acc += W[i]
		if r < acc:
			return DIRS[i]
	return DIRS[0]

## ── Tìm vị trí đặt quán của 1 node (không phụ thuộc chunk/địa hình) ─────────
## Tái hiện ĐÚNG vòng attempt — dùng CHUNG cho cả scan_taverns và _try_tavern
## để hai đường quyết định vị trí không bao giờ lệch nhau.
## Trả về { center, road, node } hoặc {} nếu mọi attempt đều quá gần spawn.
static func _node_center_plan(gx: int, gz: int, seed_base: int, h: int) -> Dictionary:
	var has: Array = _Road.intersection_has(gx, gz)
	var dirs: Array = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	var con_idx: Array = []
	for d in range(4):
		if has[d]:
			con_idx.append(d)
	if con_idx.is_empty():
		return {}
	var node_pt: Vector2 = _Road.intersection_point(gx, gz)
	for attempt in range(30):
		var ha: int = _vh_hash(h ^ 0x51AB, attempt + 1)
		var di: int = con_idx[ha % con_idx.size()]
		var rd: Vector2 = dirs[di]
		var perp: Vector2 = Vector2(-rd.y, rd.x)
		var sign: float = 1.0 if (ha & 1) == 0 else -1.0
		var back: float = 10.5 + float((ha >> 4) % 3) * 2.5   # 10.5 / 13.0 / 15.5 dọc đường
		var side: float = 13.0 + float((ha >> 8) % 3) * 1.5   # 13.0/14.5/16.0 — cách tim đường ≥ 12
		var c: Vector2 = node_pt + rd * back + perp * (sign * side)
		if c.length() < TAVERN_MIN_DIST:
			continue
		return { "center": c, "road": node_pt + rd * back, "node": node_pt }
	return {}

## ── Quét định danh quán rượu xung quanh tâm thế giới (không đòi hỏi chunk) ──
## Dùng cho teleport "đến quán gần nhất". Dùng chung _node_center_plan() với
## quá trình build → trả về CHÍNH XÁC các quán có thể được dựng (bỏ qua kiểm
## tra footprint đất, chỉ giữ điều kiện khoảng-cách tới spawn).
## Trả về [ {x,z,gx,gz,deg}, ... ] world coords.
static func scan_taverns(center: Vector2, radius: float) -> Array:
	var out: Array = []
	_Road._ensure_roads()
	var seed_base: int = SeedSnapshot.ensure() + 7777
	var half_grid: float = _Data.ROAD_GRID
	var g0 := Vector2i(int(floor((center.x - radius) / half_grid)),
		int(floor((center.y - radius) / half_grid)))
	var g1 := Vector2i(int(floor((center.x + radius) / half_grid)),
		int(floor((center.y + radius) / half_grid)))
	g0.x = maxi(g0.x, -_Data.ROAD_GRID_R); g0.y = maxi(g0.y, -_Data.ROAD_GRID_R)
	g1.x = mini(g1.x, _Data.ROAD_GRID_R);   g1.y = mini(g1.y, _Data.ROAD_GRID_R)
	for gx in range(g0.x, g1.x + 1):
		for gz in range(g0.y, g1.y + 1):
			var deg: int = _Road.intersection_degree(gx, gz)
			if deg < 3 or deg > 4:
				continue
			var h: int = _vh_hash(seed_base ^ (gx * 53031 + gz * 70003), 0x1F0B2E)
			var r: int = h & 0x7FFFFFFF
			var chance: int = T3_CHANCE if deg == 3 else T4_CHANCE
			if r % 100 >= chance:
				continue
			var plan: Dictionary = _node_center_plan(gx, gz, seed_base, h)
			if plan.is_empty():
				continue
			var c: Vector2 = plan.center
			out.append({ "x": c.x, "z": c.y, "gx": gx, "gz": gz, "deg": deg })
	return out

## ── Entry: compute_village ─────────────────────────────────────────────────────
static func compute_village(cx: int, cz: int, size: int, dim_id: int,
		biome_grid: Array, height_grid: Array, road_grid: PackedByteArray,
		_river_flag: PackedByteArray, cols: int) -> Dictionary:
	var empty := { "has": false, "xforms": [], "colors": [], "info": {} }
	if dim_id != _Data._Dim.DimensionID.REAL_WORLD:
		return empty

	var xforms: Array = []
	var colors: Array = []
	var ixforms: Array = []
	var icolors: Array = []
	var buildings: Array = []
	_find_taverns(xforms, colors, ixforms, icolors, buildings, cx, cz, size,
		biome_grid, height_grid, road_grid, cols)
	if buildings.is_empty():
		return empty

	var origin := Vector3(cx * size, 0.0, cz * size)
	for i in range(xforms.size()):
		xforms[i] = Transform3D((xforms[i] as Transform3D).basis,
			(xforms[i] as Transform3D).origin - origin)
	for i in range(ixforms.size()):
		ixforms[i] = Transform3D((ixforms[i] as Transform3D).basis,
			(ixforms[i] as Transform3D).origin - origin)

	return {
		"has": true,
		"xforms": xforms,
		"colors": colors,
		"ixforms": ixforms,
		"icolors": icolors,
		"info": { "buildings": buildings },
	}

## ── Quét các node lưới đường phủ chunk (+ mép); roll xác suất từng ngã ────────
static func _find_taverns(xforms: Array, colors: Array, ixforms: Array, icolors: Array,
		buildings: Array, cx: int, cz: int, size: int, biome_grid: Array, height_grid: Array,
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
			_try_tavern(xforms, colors, ixforms, icolors, buildings, gx, gz, size,
				biome_grid, height_grid, road_grid, cols, min_wx, min_wz)

## ── Một node ngã/xu: roll xác suất, tìm chỗ đậu quán ──────────────────────────
static func _try_tavern(xforms: Array, colors: Array, ixforms: Array, icolors: Array,
		buildings: Array, gx: int, gz: int, _size: int, biome_grid: Array, height_grid: Array,
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

	var plan: Dictionary = _node_center_plan(gx, gz, seed_base, h)
	if plan.is_empty():
		return
	var center: Vector2 = plan.center
	var cc := Vector2i(int(floor(center.x - min_wx)), int(floor(center.y - min_wz)))
	if DEBUG:
		print("  node=(%.1f,%.1f) center=(%.1f,%.1f) cc=%s" %
			[plan.node.x, plan.node.y, center.x, center.y, str(cc)])
	if not _cell_ok(cc, cols):
		if DEBUG:
			print("  cell-out cc=%s" % str(cc))
		return
	if not _footprint_ok(cc, cols, biome_grid, height_grid, road_grid, FOOT_RX, FOOT_RZ):
		if DEBUG:
			print("  foot-FAIL center=(%.1f,%.1f) cc=%s" % [center.x, center.y, str(cc)])
		return
	if DEBUG:
		print("  PLACED center=(%.1f,%.1f) cc=%s" % [center.x, center.y, str(cc)])

	# Hướng cửa: chọn ngẫu nhiên có trọng số, thiên về Z+ và X+ (deterministic theo node)
	var fwd := _pick_facing(h)
	var yaw: float = atan2(-fwd.x, -fwd.y)
	var gy: float = height_grid[cc.x][cc.y] + 0.02
	_add_tavern(xforms, colors, ixforms, icolors, center, yaw, gy)
	buildings.append({
		"type": "tavern", "x": center.x, "z": center.y,
		"yaw": yaw, "deg": deg, "gx": gx, "gz": gz,
		"gy": gy, "half_x": 5.7, "half_z": 6.5, "top_y": 11.5,
	})

## ── Kiểm tra ô trong chunk ─────────────────────────────────────────────────────
static func _cell_ok(c: Vector2i, cols: int) -> bool:
	return c.x >= 0 and c.x < cols and c.y >= 0 and c.y < cols

## ── Kiểm tra chân công trình: đất phẳng, không đường, không nước ─────────────
## Chỉ kiểm tra phần footprint NẰM TRONG chunk — cho phép chân vươn sang chunk
## lân cận (chunk đó tự dựng địa hình riêng). Dung sai độ phẳng nới lên 2.5m
## để quán vẫn dựng được trên cao nguyên / cao nguyên sa mạc.
static func _footprint_ok(c: Vector2i, cols: int, _biome_grid: Array,
		height_grid: Array, road_grid: PackedByteArray, rx: int, rz: int) -> bool:
	if not _cell_ok(c, cols):
		return false
	var ref_h: float = height_grid[c.x][c.y]
	if ref_h <= _Data.WATER_Y:
		return false
	for dx in range(-rx, rx + 1):
		for dz in range(-rz, rz + 1):
			var nx: int = c.x + dx
			var nz: int = c.y + dz
			if not _cell_ok(Vector2i(nx, nz), cols):
				continue
			if height_grid[nx][nz] <= _Data.WATER_Y:
				return false
			if absf(height_grid[nx][nz] - ref_h) > 2.5:
				return false
			if road_grid.size() > 0 and road_grid[nx * cols + nz] != 0:
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
		xforms.append(Transform3D(rot * Basis().scaled(sz), base + rot * pos))
		colors.append(col)

## ── Thanh vạch gạch (bước từng khối) giữa 2 điểm trong mặt phẳng ──────────────
static func _bar(local: Array, v: Vector3, w: Vector3, th: float, col: Color) -> void:
	var delta: Vector3 = w - v
	var span: float = maxf(absf(delta.x), maxf(absf(delta.y), absf(delta.z)))
	var steps: int = maxi(2, int(ceil(span / 0.5)))
	for i in range(steps):
		var t: float = (float(i) + 0.5) / float(steps)
		local.append([v + delta * t, Vector3(th, th, th), col])

## ── Cửa sổ ×2 trên mặt song song trục Z (dir=+1 mặt -z, dir=-1 mặt +z) ─────────
## z_face = toạ độ z của mặt ngoài tường; kính nhô ra khỏi mặt ~0.14 cho thấy rõ.
static func _win_z(local: Array, x: float, y: float, w: float, h: float,
		z_face: float, dir: float) -> void:
	var z: float = z_face
	local.append([Vector3(x, y, z), Vector3(w + 0.16, h + 0.12, 0.18), C_TRIM])
	local.append([Vector3(x - 0.12, y, z - dir * 0.03), Vector3(w - 0.20, h - 0.40, 0.22), C_WINDOW])
	local.append([Vector3(x + 0.12, y, z - dir * 0.03), Vector3(w - 0.20, h - 0.40, 0.22), C_WINDOW])
	local.append([Vector3(x, y + (h - 0.40) * 0.25, z - dir * 0.03), Vector3(w - 0.20, 0.08, 0.24), C_TRIM])
	local.append([Vector3(x - 0.30, y, z - dir * 0.03), Vector3(0.08, h - 0.40, 0.24), C_TRIM])
	local.append([Vector3(x + 0.30, y, z - dir * 0.03), Vector3(0.08, h - 0.40, 0.24), C_TRIM])

## ── Cửa sổ ×2 trên mặt song song trục X (dir=+1 mặt -x, dir=-1 mặt +x) ─────────
static func _win_x(local: Array, z: float, y: float, w: float, h: float,
		x_face: float, dir: float) -> void:
	var x: float = x_face
	local.append([Vector3(x, y, z), Vector3(0.18, h + 0.12, w + 0.16), C_TRIM])
	local.append([Vector3(x - dir * 0.03, y, z - 0.12), Vector3(0.22, h - 0.40, w - 0.20), C_WINDOW])
	local.append([Vector3(x - dir * 0.03, y, z + 0.12), Vector3(0.22, h - 0.40, w - 0.20), C_WINDOW])
	local.append([Vector3(x - dir * 0.03, y + (h - 0.40) * 0.25, z), Vector3(0.24, 0.08, w - 0.20), C_TRIM])
	local.append([Vector3(x - dir * 0.03, y, z - 0.30), Vector3(0.24, h - 0.40, 0.08), C_TRIM])
	local.append([Vector3(x - dir * 0.03, y, z + 0.30), Vector3(0.24, h - 0.40, 0.08), C_TRIM])

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

## ── Cửa + khung cửa (mặt trước) — đẩy ra TRƯỚC mặt tường (z←) để không bị che ──
static func _door(local: Array) -> void:
	# khung cửa (cánh cửa là mesh động — TavernDoor mở/đóng)
	local.append([Vector3(-0.88, 1.25, -2.62), Vector3(0.18, 2.2, 0.34), C_TRIM])
	local.append([Vector3(0.88, 1.25, -2.62), Vector3(0.18, 2.2, 0.34), C_TRIM])
	local.append([Vector3(0.0, 2.62, -2.62), Vector3(1.9, 0.35, 0.30), C_TRIM])

## ── Tường 2 tầng khối chính: nền móng đá + 4 vách mỗi tầng + đai gỗ ngăn ─────
## Mặt trước z=-2.52, sau z=6.70, trái/phải x=±5.52. Khối liền, không hở.
static func _tavern_walls(local: Array) -> void:
	# nền móng đá
	local.append([Vector3(0.0, 0.14, 2.0), Vector3(12.2, 0.28, 10.0), C_STONE])
	local.append([Vector3(0.0, -0.06, 2.0), Vector3(12.6, 0.18, 10.4), C_STONE_DK])
	# tường trệt
	var yb: float = 0.28
	var yt: float = 3.30
	var ym: float = (yb + yt) * 0.5
	var zh: float = yt - yb
	local.append([Vector3(0.0, ym, -2.35), Vector3(10.7, zh, 0.34), C_WALL])
	local.append([Vector3(0.0, ym, 6.55), Vector3(10.7, zh, 0.34), C_WALL_B])
	local.append([Vector3(-5.35, ym, 2.0), Vector3(0.34, zh, 9.0), C_WALL_B])
	local.append([Vector3(5.35, ym, 2.0), Vector3(0.34, zh, 9.0), C_WALL_B])
	# tường tầng 2
	var yb2: float = 3.42
	var yt2: float = 5.85
	var ym2: float = (yb2 + yt2) * 0.5
	var zh2: float = yt2 - yb2
	local.append([Vector3(0.0, ym2, -2.35), Vector3(10.7, zh2, 0.30), C_WALL])
	local.append([Vector3(0.0, ym2, 6.55), Vector3(10.7, zh2, 0.30), C_WALL_B])
	local.append([Vector3(-5.35, ym2, 2.0), Vector3(0.30, zh2, 9.0), C_WALL_B])
	local.append([Vector3(5.35, ym2, 2.0), Vector3(0.30, zh2, 9.0), C_WALL_B])
	# mảng trát bong tróc
	local.append([Vector3(-3.6, 1.5, -2.44), Vector3(1.2, 0.9, 0.16), C_WALL_P])
	local.append([Vector3(4.2, 1.0, -2.44), Vector3(1.0, 0.7, 0.16), C_WALL_P])
	local.append([Vector3(2.6, 2.3, -2.44), Vector3(1.4, 0.6, 0.16), C_WALL_P])
	local.append([Vector3(-1.2, 5.2, -2.44), Vector3(1.6, 0.6, 0.16), C_WALL_P])
	# đai gỗ ngăn 2 tầng (nhô ra ngoài mặt tường, như jetty line)
	local.append([Vector3(0.0, 3.36, -2.38), Vector3(11.6, 0.12, 0.50), C_TRIM])
	local.append([Vector3(0.0, 3.36, 6.60), Vector3(11.6, 0.12, 0.50), C_TRIM])

## ── Lấp tam giác đầu hồi (gable): phiến trát kem theo bước mái + gỗ + cửa sổ ──
## roof_half_w quyết định số bậc (theo mái thật), wall_half_w chặn chiều rộng
## (không vượt quá tường). eave_y = đáy tam giác = mép mái.
static func _gable_fill(local: Array, z: float, ridge_y: float, roof_half_w: float,
		wall_half_w: float, step: float, drop: float) -> void:
	var rows: int = maxi(1, int(ceil(roof_half_w / step)))
	var eave_y: float = ridge_y - float(rows) * drop
	for i in range(rows):
		var hw: float = (float(i) + 0.5) * step
		if hw > wall_half_w:
			hw = wall_half_w
		if hw < 0.10:
			continue
		var yc: float = ridge_y - float(i) * drop
		local.append([Vector3(0.0, yc - 0.17, z), Vector3(hw * 2.0 - 0.04, 0.34, 0.26), C_WALL])
	# viền eave + 2 cạnh chéo + cột đứng
	local.append([Vector3(0.0, eave_y + 0.02, z), Vector3(wall_half_w * 2.0 - 0.10, 0.18, 0.28), C_TRIM])
	_bar(local, Vector3(-wall_half_w + 0.3, eave_y + 0.25, z), Vector3(0.0, eave_y + 2.0, z), 0.20, C_TRIM)
	_bar(local, Vector3(wall_half_w - 0.3, eave_y + 0.25, z), Vector3(0.0, eave_y + 2.0, z), 0.20, C_TRIM)
	_bar(local, Vector3(0.0, eave_y + 2.0, z), Vector3(0.0, ridge_y - 0.3, z), 0.18, C_TRIM)
	# ô cửa sổ đầu hồi
	var wy: float = eave_y + 1.1
	local.append([Vector3(0.0, wy, z), Vector3(0.70, 0.70, 0.30), C_TRIM])
	local.append([Vector3(0.0, wy, z), Vector3(0.54, 0.54, 0.34), C_WINDOW])

## ── Khung timbers half-timber: cột góc nhô, đai đế, cột cửa, tầng 2 cột + chữ X ──
static func _framing(local: Array) -> void:
	# cột góc trệt (nhô ra khỏi mặt tường)
	for px in [-5.35, 5.35]:
		for zz in [-2.55, 6.63]:
			local.append([Vector3(px, 1.79, zz), Vector3(0.34, 3.02, 0.34), C_TRIM])
	# vành đế trệt
	local.append([Vector3(0.0, 0.20, -2.55), Vector3(11.4, 0.16, 0.30), C_TRIM])
	local.append([Vector3(0.0, 0.20, 6.63), Vector3(11.4, 0.16, 0.30), C_TRIM])
	# cột đứng trệt 2 bên cửa
	local.append([Vector3(-1.55, 1.79, -2.55), Vector3(0.22, 3.02, 0.22), C_TRIM])
	local.append([Vector3(1.55, 1.79, -2.55), Vector3(0.22, 3.02, 0.22), C_TRIM])
	# tầng 2 mặt trước: cột dọc + chữ X (nhô ~0.07 so với mặt tường)
	for px in [-5.2, -3.9, -1.3, 1.3, 3.9, 5.2]:
		local.append([Vector3(px, 4.635, -2.50), Vector3(0.16, 2.43, 0.14), C_TRIM])
	for px in [-4.15, 4.15]:
		_bar(local, Vector3(px - 1.0, 3.6, -2.50), Vector3(px + 1.0, 5.7, -2.50), 0.14, C_TRIM)
		_bar(local, Vector3(px + 1.0, 3.6, -2.50), Vector3(px - 1.0, 5.7, -2.50), 0.14, C_TRIM)
	# thanh ngang tầng 2 (mặt trước + sau)
	local.append([Vector3(0.0, 3.55, -2.50), Vector3(11.2, 0.12, 0.12), C_TRIM])
	local.append([Vector3(0.0, 5.70, -2.50), Vector3(11.2, 0.12, 0.12), C_TRIM])
	local.append([Vector3(0.0, 3.55, 6.68), Vector3(11.2, 0.12, 0.12), C_TRIM])
	local.append([Vector3(0.0, 5.70, 6.68), Vector3(11.2, 0.12, 0.12), C_TRIM])

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
	# biển hiệu treo cạnh cửa: khung + chữ "TV" đen trên nền trắng (TRÁNH đè lên cửa)
	var bx: float = -1.60
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
	# 2 thùng gỗ bên trái nhà (ngoài tường)
	for q in [0, 1]:
		var cz2: float = -1.0 + float(q) * 1.4
		local.append([Vector3(-6.6, 0.30, cz2), Vector3(0.90, 0.60, 0.90), C_CRATE])
		local.append([Vector3(-6.6, 0.62, cz2), Vector3(0.86, 0.10, 0.86), C_CRATE_DK])
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

## ── Bánh xe: vành + nan hoa chữ thập ──────────────────────────────────────────
static func _wheel(local: Array, cx2: float, cy: float, cz2: float) -> void:
	local.append([Vector3(cx2, cy, cz2), Vector3(0.18, 0.18, 0.16), C_CART])
	local.append([Vector3(cx2, cy, cz2), Vector3(0.54, 0.10, 0.14), C_CART])
	local.append([Vector3(cx2, cy, cz2), Vector3(0.10, 0.54, 0.14), C_CART])

## ── Chi tiết ngoại thất nâng cấp: đá gốc, chớp cửa sổ, tán mái, hoa leo ──────
static func _tavern_extra(local: Array) -> void:
	# đá góc (quoins) 4 góc nhà, 2 tầng đá chồng
	for px in [-5.35, 5.35]:
		for pz in [-2.2, 6.6]:
			for qy in [0.6, 1.4, 2.2]:
				local.append([Vector3(px, qy, pz), Vector3(0.46, 0.36, 0.46), C_STONE])
	# khung ôm cửa chính (architrav) + ô ghi rõ chữ nhà trên lintel
	local.append([Vector3(0.0, 1.25, -2.44), Vector3(2.3, 2.5, 0.10), C_TRIM_W])
	local.append([Vector3(0.0, 2.78, -2.46), Vector3(2.6, 0.22, 0.12), C_TRIM])
	# nóc mái: đinh nhọn (finial) 2 đầu hồi — đỉnh mái trên sống nóc, cả 2 đầu trước/sau
	for pz in [-2.45, 6.60]:
		local.append([Vector3(0.0, 9.42, pz), Vector3(0.30, 0.40, 0.30), C_ROOF_HI])
		local.append([Vector3(0.0, 9.76, pz), Vector3(0.14, 0.34, 0.14), C_TRIM])
	# dây thường xuân leo trên mặt trước
	for vy in [0.8, 1.6, 2.4]:
		local.append([Vector3(-4.9, vy, -2.38), Vector3(0.16, 0.20, 0.30), C_LEAF_B])
		local.append([Vector3(4.9, vy, -2.38), Vector3(0.16, 0.20, 0.30), C_LEAF_B])
	# dải đá chân tường cao hơn + cửa hầm chứa (cửa nhỏ nửa nổi) bên hông
	local.append([Vector3(0.0, 0.36, -2.38), Vector3(10.9, 0.10, 0.34), C_STONE])
	local.append([Vector3(0.0, 0.36, 6.60), Vector3(10.9, 0.10, 0.34), C_STONE])
	# khay hoa ban công tầng 2 (mặt trước)
	for sx2 in [-2.6, 0.0, 2.6]:
		local.append([Vector3(sx2, 3.62, -2.42), Vector3(1.15, 0.12, 0.26), C_DECK_DK])
		local.append([Vector3(sx2, 3.74, -2.42), Vector3(1.05, 0.12, 0.20), C_LEAF_C])
	# ghế gỗ cạnh cửa
	local.append([Vector3(2.2, 0.30, -2.05), Vector3(1.5, 0.30, 0.55), C_DECK])
	local.append([Vector3(2.2, 0.62, -2.0), Vector3(1.5, 0.08, 0.45), C_DECK_DK])
	local.append([Vector3(1.4, 0.62, -2.0), Vector3(0.10, 0.40, 0.45), C_DECK_DK])
	local.append([Vector3(3.0, 0.62, -2.0), Vector3(0.10, 0.40, 0.45), C_DECK_DK])

## ── Chi tiết: mành cửa + chậu hoa cửa trệt, đèn lồng cạnh cửa ────────────────
static func _tavern_detail(local: Array) -> void:
	for x in [-2.7, 2.7]:
		# chậu hoa
		local.append([Vector3(x, 0.78, -2.40), Vector3(1.05, 0.22, 0.30), C_DECK_DK])
		local.append([Vector3(x, 0.94, -2.40), Vector3(0.95, 0.16, 0.24), C_LEAF_A])
		local.append([Vector3(x, 1.05, -2.40), Vector3(0.60, 0.08, 0.16), C_LEAF_C])
	# đèn lồng cạnh cửa (bên phải)
	local.append([Vector3(1.15, 2.05, -2.52), Vector3(0.06, 0.42, 0.06), C_TRIM])
	local.append([Vector3(0.78, 2.05, -2.52), Vector3(0.44, 0.06, 0.06), C_TRIM])
	local.append([Vector3(1.15, 2.32, -2.54), Vector3(0.26, 0.26, 0.14), Color(1.0, 0.85, 0.35)])

## ── Nội thất (bên trong khối chính) — nhìn thấy khi tường mờ ────────────────
static func _tavern_interior_local() -> Array:
	var local: Array = []
	# sàn gỗ + thảm giữa phòng (bao toàn bộ tầng trệt)
	local.append([Vector3(0.0, 0.06, 2.0), Vector3(10.9, 0.08, 8.9), C_FLOOR])
	local.append([Vector3(-1.4, 0.11, 3.0), Vector3(2.2, 0.05, 4.2), C_RUG])
	local.append([Vector3(-1.4, 0.155, 3.0), Vector3(2.2, 0.03, 4.2), C_FLOOR_DK])
	# quầy bar phía trong (x=+3.6, dọc trục z bên phải cửa sổ sau)
	var bar_h: float = 1.05
	local.append([Vector3(4.1, bar_h - 0.45, 3.4), Vector3(1.4, 0.78, 3.0), C_BAR_DK])
	local.append([Vector3(4.35, bar_h + 0.15, 3.4), Vector3(0.95, 0.10, 3.2), C_BAR])
	local.append([Vector3(4.35, bar_h + 0.45, 3.4), Vector3(0.95, 0.10, 3.2), C_BAR])
	# ghế quầy + giá gác chân
	for zz in [2.0, 3.0, 4.0, 5.0]:
		local.append([Vector3(3.35, bar_h - 0.05, zz), Vector3(0.95, 0.45, 0.10), C_BAR_DK])
	for zz in [2.2, 3.4, 4.6]:
		local.append([Vector3(4.15, 0.35, zz), Vector3(0.52, 0.06, 0.42), C_CHAIR])
	# kệ đựng chai trên tường sau (z=5.9, cao 2 tầng)
	for sy in [1.45, 2.6]:
		local.append([Vector3(4.35, sy, 5.9), Vector3(2.2, 0.16, 0.5), C_CAB])
		for i in range(4):
			var bx2: float = 3.4 + float(i) * 0.55
			local.append([Vector3(bx2, sy + 0.28, 5.85), Vector3(0.13, 0.42, 0.13), C_BOTTLE if (i & 1) == 0 else C_BOTTLE_A])
	# lò sưởi ở tường sau-giữa (x=0) + đống củi + lửa đỏ
	local.append([Vector3(0.0, 0.9, 5.55), Vector3(2.2, 1.5, 0.6), C_HEARTH])
	local.append([Vector3(0.0, 0.6, 5.85), Vector3(1.3, 1.1, 0.2), C_EMBER])
	local.append([Vector3(0.0, 0.5, 5.92), Vector3(0.7, 0.4, 0.16), C_FIRE])
	local.append([Vector3(0.0, 1.95, 5.4), Vector3(2.4, 0.14, 0.4), C_CAB])
	# bàn + ghế trong phòng
	for t in [[-2.6, 3.2], [-2.6, 4.8]]:
		local.append([Vector3(t[0], 0.45, t[1]), Vector3(1.5, 0.10, 1.3), C_TABLE])
		local.append([Vector3(t[0], 0.22, t[1]), Vector3(0.12, 0.44, 0.12), C_TABLE])
		local.append([Vector3(t[0], 0.22, t[1]), Vector3(0.12, 0.44, 0.12), C_TABLE])
		local.append([Vector3(t[0], 0.22, t[1]), Vector3(0.12, 0.44, 0.12), C_TABLE])
		for b in [-1.1, 1.1]:
			local.append([Vector3(t[0] + b, 0.30, t[1]), Vector3(1.0, 0.06, 0.42), C_CHAIR])
			local.append([Vector3(t[0] + b, 0.14, t[1] - 0.5), Vector3(0.10, 0.26, 0.40), C_CHAIR])
			local.append([Vector3(t[0] + b, 0.14, t[1] + 0.5), Vector3(0.10, 0.26, 0.40), C_CHAIR])
	# đèn treo giữa phòng + móc áo cạnh cửa
	local.append([Vector3(0.6, 6.3, 3.2), Vector3(0.05, 0.6, 0.05), C_TRIM])
	local.append([Vector3(0.6, 6.65, 3.2), Vector3(0.5, 0.18, 0.5), C_LANTERN_I])
	local.append([Vector3(-3.9, 1.2, 6.0), Vector3(1.6, 0.06, 0.2), C_CAB])
	return local

## ── Danh sách hộp local (chưa xoay/chưa dịch) — dùng chung build + diagnostics ─
static func _tavern_local() -> Array:
	var local: Array = []
	_tavern_walls(local)
	_door(local)
	_framing(local)
	_gable_fill(local, -2.45, 9.2, 6.9, 5.35, 0.6, 0.30)
	_gable_fill(local, 6.60, 9.2, 6.9, 5.35, 0.6, 0.30)
	_tavern_top(local)
	_props(local)
	_tavern_detail(local)
	_tavern_extra(local)
	# cửa sổ trệt: 2 trước, 2 sau, 2 bên
	_win_z(local, -2.7, 1.55, 0.85, 0.90, -2.52, 1.0)
	_win_z(local, 2.7, 1.55, 0.85, 0.90, -2.52, 1.0)
	_win_z(local, -2.7, 1.55, 0.85, 0.90, 6.70, -1.0)
	_win_z(local, 2.7, 1.55, 0.85, 0.90, 6.70, -1.0)
	_win_x(local, 2.0, 1.55, 0.85, 0.90, -5.52, 1.0)
	_win_x(local, 2.0, 1.55, 0.85, 0.90, 5.52, -1.0)
	# cửa sổ tầng 2: 3 trước, 2 sau, 2 bên
	_win_z(local, -2.6, 4.55, 0.80, 0.85, -2.52, 1.0)
	_win_z(local, 0.0, 4.55, 0.80, 0.85, -2.52, 1.0)
	_win_z(local, 2.6, 4.55, 0.80, 0.85, -2.52, 1.0)
	_win_z(local, -2.6, 4.55, 0.80, 0.85, 6.70, -1.0)
	_win_z(local, 2.6, 4.55, 0.80, 0.85, 6.70, -1.0)
	_win_x(local, 2.0, 4.55, 0.80, 0.85, -5.52, 1.0)
	_win_x(local, 2.0, 4.55, 0.80, 0.85, 5.52, -1.0)
	return local

## ── Builder chính quán rượu ───────────────────────────────────────────────────
static func _add_tavern(xforms: Array, colors: Array, ixforms: Array, icolors: Array,
		at: Vector2, yaw: float, gy: float) -> void:
	var rot := Basis(Vector3.UP, yaw)
	var base := Vector3(at.x, gy, at.y)
	for item in _tavern_local():
		xforms.append(Transform3D(rot * Basis().scaled(item[1]), base + rot * item[0]))
		colors.append(item[2])
	for item in _tavern_interior_local():
		ixforms.append(Transform3D(rot * Basis().scaled(item[1]), base + rot * item[0]))
		icolors.append(item[2])