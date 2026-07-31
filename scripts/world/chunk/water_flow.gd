extends RefCounted

const _Data = preload("chunk_data.gd")
const _BlockData = preload("chunk_block_data.gd")

const MAX_SPREAD: int = 7
const _DIRS := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]

static func _is_w(bid: int) -> bool:
	return bid == _Data.BlockID.WATER or (bid >= _Data.BlockID.WATER_SOURCE and bid <= _Data.BlockID.WATER_LEVEL_1)

static func _wl(bid: int) -> int:
	if bid == _Data.BlockID.WATER_SOURCE or bid == _Data.BlockID.WATER:
		return 8
	if bid >= _Data.BlockID.WATER_LEVEL_7 and bid <= _Data.BlockID.WATER_LEVEL_1:
		return 8 - (bid - _Data.BlockID.WATER_LEVEL_7)
	return 0

static func _is_src(bid: int) -> bool:
	return bid == _Data.BlockID.WATER_SOURCE or bid == _Data.BlockID.WATER

# neighbor_data format: { "n": {bd, chunk, cols}, "s": {bd, chunk, cols},
#                         "e": {bd, chunk, cols}, "w": {bd, chunk, cols} }
static func tick_flow(chunk, neighbor_data: Dictionary = {}) -> bool:
	var bd := chunk.block_data as _BlockData
	if bd == null: return false
	var cols: int = chunk._cols
	var any_change := false

	# Phase 1: Vertical drop (1 block per tick)
	for x in range(cols):
		for z in range(cols):
			# Scan bottom-to-top so moved water isn't processed again
			for y in range(1, _BlockData.CHUNK_H):
				var bid: int = bd.get_block(x, y, z)
				if not _is_w(bid):
					continue
				var level: int = _wl(bid)
				if level <= 0:
					continue
				var below: int = _gx(bd, neighbor_data, cols, x, y - 1, z)
				if below == _Data.BlockID.AIR:
					bd.set_block(x, y, z, _Data.BlockID.AIR)
					bd.set_block(x, y - 1, z, bid)
					any_change = true

	# Phase 2: Horizontal spread from sources
	var sources: Array[Vector3i] = []
	for x in range(cols):
		for z in range(cols):
			for y in range(_BlockData.CHUNK_H - 1, -1, -1):
				if _is_src(bd.get_block(x, y, z)):
					sources.append(Vector3i(x, y, z))

	for src in sources:
		var visited: Dictionary = {}
		var queue: Array[Dictionary] = []

		var bv: int = _gx(bd, neighbor_data, cols, src.x, src.y - 1, src.z)
		if bv == _Data.BlockID.AIR or (_is_w(bv) and _wl(bv) < 8):
			var wf: Dictionary = {"gx": src.x, "gy": src.y - 1, "gz": src.z, "level": 8, "bd": bd, "cols": cols, "nb": neighbor_data}
			queue.append(wf)

		queue.append({"gx": src.x, "gy": src.y, "gz": src.z, "level": 8, "bd": bd, "cols": cols, "nb": neighbor_data})
		visited[_key(src.x, src.y, src.z)] = true

		while not queue.is_empty():
			var cur: Dictionary = queue.pop_front()
			var cx: int = cur.gx
			var cy: int = cur.gy
			var cz: int = cur.gz
			var cl: int = cur.level
			var cbd: _BlockData = cur.bd
			var ccols: int = cur.cols
			var cnb: Dictionary = cur.nb

			if cl <= 1:
				continue
			var nxt: int = cl - 1

			for d in _DIRS:
				var nx: int = cx + d.x
				var nz: int = cz + d.z
				if cy < 0 or cy >= _BlockData.CHUNK_H:
					continue

				var tgt: _TxResult = _tx(nx, cy, nz, cbd, cnb, ccols)
				if tgt == null:
					continue
				var tnb: _BlockData = tgt.bd
				var tx: int = tgt.tx
				var ty: int = tgt.ty
				var tz: int = tgt.tz
				var tcols: int = tgt.cols
				var tnb_data: Dictionary = tgt.nb_data
				var is_cross: bool = tgt.cross

				var nid: int = tnb.get_block(tx, ty, tz)
				if nid != _Data.BlockID.AIR and not _is_w(nid):
					continue
				if _wl(nid) >= nxt:
					continue

				var vk: String = _key(nx, cy, nz)
				if visited.has(vk):
					continue
				visited[vk] = true

				var has_drop: bool = tnb.get_block(tx, ty - 1, tz) == _Data.BlockID.AIR

				if has_drop or nxt > 1:
					var wid: int = _Data.water_block_for_level(nxt)
					tnb.set_block(tx, ty, tz, wid)
					any_change = true
					if is_cross:
						_cross_notify(cnb, ccols, nx, nz)

					queue.append({"gx": tx, "gy": ty, "gz": tz, "level": nxt, "bd": tnb, "cols": tcols, "nb": tnb_data})

	# Phase 3: Source creation
	for x in range(cols):
		for z in range(cols):
			for y in range(_BlockData.CHUNK_H - 1, -1, -1):
				var bid: int = bd.get_block(x, y, z)
				if bid != _Data.BlockID.AIR:
					continue
				var hb: int = _gx(bd, neighbor_data, cols, x, y - 1, z)
				if _is_w(hb) or hb == _Data.BlockID.AIR:
					continue
				var sc: int = 0
				for d in _DIRS:
					var nx: int = x + d.x
					var nz: int = z + d.z
					var tgt: _TxResult = _tx(nx, y, nz, bd, neighbor_data, cols)
					if tgt != null:
						if _is_src(tgt.bd.get_block(tgt.tx, tgt.ty, tgt.tz)):
							sc += 1
				if sc >= 2:
					bd.set_block(x, y, z, _Data.BlockID.WATER_SOURCE)
					any_change = true

	return any_change

# ── Resolve a block position (nx,ny,nz) to the actual block data + coords ──
static func _tx(nx: int, ny: int, nz: int, bd: _BlockData, nb_data: Dictionary, cols: int) -> _TxResult:
	if ny < 0 or ny >= _BlockData.CHUNK_H:
		return null
	if nx >= 0 and nx < cols and nz >= 0 and nz < cols:
		return _TxResult.new(bd, nx, ny, nz, cols, nb_data, false)
	if nx < 0 and nb_data.has("w"):
		var e: Dictionary = nb_data["w"]
		return _TxResult.new(e.bd, e.cols - 1 + nx, ny, nz, e.cols, _gather_nb(e.chunk), true)
	if nx >= cols and nb_data.has("e"):
		var e: Dictionary = nb_data["e"]
		return _TxResult.new(e.bd, nx - cols, ny, nz, e.cols, _gather_nb(e.chunk), true)
	if nz < 0 and nb_data.has("n"):
		var e: Dictionary = nb_data["n"]
		return _TxResult.new(e.bd, nx, ny, e.cols - 1 + nz, e.cols, _gather_nb(e.chunk), true)
	if nz >= cols and nb_data.has("s"):
		var e: Dictionary = nb_data["s"]
		return _TxResult.new(e.bd, nx, ny, nz - cols, e.cols, _gather_nb(e.chunk), true)
	return null

static func _gx(bd: _BlockData, nb_data: Dictionary, cols: int, x: int, y: int, z: int) -> int:
	var tgt: _TxResult = _tx(x, y, z, bd, nb_data, cols)
	if tgt == null:
		return _Data.BlockID.AIR
	return tgt.bd.get_block(tgt.tx, tgt.ty, tgt.tz)

static func _gather_nb(chunk) -> Dictionary:
	var res: Dictionary = {}
	var p: Node = chunk.get_parent()
	if p == null or not "_chunks" in p:
		return res
	var cs: Dictionary = p._chunks
	var cx: int = chunk._cx
	var cz: int = chunk._cz
	var keys: Array[Vector2i] = [
		Vector2i(cx - 1, cz), Vector2i(cx + 1, cz),
		Vector2i(cx, cz - 1), Vector2i(cx, cz + 1)]
	var dirs := ["w", "e", "n", "s"]
	for i in 4:
		if cs.has(keys[i]):
			var nchunk = cs[keys[i]]
			if nchunk != null and nchunk.block_data != null:
				res[dirs[i]] = {"bd": nchunk.block_data, "chunk": nchunk, "cols": nchunk._cols}
	return res

static func _cross_notify(cnb: Dictionary, ccols: int, nx: int, nz: int) -> void:
	var nb_chunk = null
	if nx < 0 and cnb.has("w"): nb_chunk = cnb["w"].chunk
	elif nx >= ccols and cnb.has("e"): nb_chunk = cnb["e"].chunk
	elif nz < 0 and cnb.has("n"): nb_chunk = cnb["n"].chunk
	elif nz >= ccols and cnb.has("s"): nb_chunk = cnb["s"].chunk
	if nb_chunk != null:
		nb_chunk._water_tick_timer = 0.0
		nb_chunk.rebuild_water_mesh()

# ── Helper class for cross-chunk block resolution ──────────────────────────────
class _TxResult:
	var bd: _BlockData
	var tx: int
	var ty: int
	var tz: int
	var cols: int
	var nb_data: Dictionary
	var cross: bool

	func _init(b: _BlockData, x: int, y: int, z: int, c: int, nd: Dictionary, cr: bool):
		bd = b; tx = x; ty = y; tz = z; cols = c; nb_data = nd; cross = cr

static func _key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]
