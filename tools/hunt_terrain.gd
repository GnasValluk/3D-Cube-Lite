extends Node3D
## HUNT 2026-08-02 — tìm lại tọa độ ổn định sau khi đổi ocean/lake noise:
##  1. test_promote: 5 chunk toàn biển liền kề (seed 123456789)
##  2. test_village: làng đủ 7 công trình (house..dock, seed 20260805)
##  3. test_village: chunk có cầu tre (đường cắt sông, seed 20260805)
## Chạy qua tools/hunt_terrain.tscn; in kết quả rồi quit.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _V = preload("res://scripts/world/chunk/village.gd")
const _Road = preload("res://scripts/world/chunk/chunk_road.gd")
const _River = preload("res://scripts/world/chunk/chunk_river.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

func _ready() -> void:
	# ── 1. Ocean chunks (seed 123456789) ────────────────────────────────
	WorldSeed.seed_value = 123456789
	_W._Noise.clear_cache()
	var nd: Dictionary = _W._Noise._noise_for_dim(RW)
	var found_oc := Vector2i(99999, 99999)
	var oc_done := false
	var clean_chunks: Array[Vector2i] = []
	for cx in range(-300, -150):
		for cz in range(-230, -160):
			var all_oc := true
			for gx2 in range(4):
				for gz2 in range(4):
					var wxc: float = float(cx) * SIZE + 2.0 + gx2 * (SIZE - 4.0) / 3.0
					var wzc: float = float(cz) * SIZE + 2.0 + gz2 * (SIZE - 4.0) / 3.0
					if not _W._ocean_mask_at(nd, wxc, wzc):
						all_oc = false
						break
				if not all_oc: break
			if all_oc:
				clean_chunks.append(Vector2i(cx, cz))
	for c in clean_chunks:
		var has_group := false
		for gx2 in range(3):
			if has_group: break
			var ok := true
			for dx2 in range(3):
				for dz2 in range(2):
					if not clean_chunks.has(Vector2i(c.x + dx2, c.y + dz2)):
						ok = false
						break
				if not ok: break
			if ok:
				found_oc = Vector2i(c.x + gx2 - 2, c.y)
				has_group = true
		if has_group: break
	print("HUNT-OC | mask 3x2 candidate =", found_oc)
	if found_oc.x != 99999:
		var vkeys: Array = []
		for gx2 in range(3):
			for gz2 in range(2):
				vkeys.append(Vector2i(found_oc.x + gx2, found_oc.y + gz2))
		var all_clean := true
		for k in vkeys:
			var data := _W.compute_chunk(k.x, k.y, SIZE, RW)
			var bg: Array = data.get("biome_grid", [])
			var bad := 0
			if bg.size() == SIZE:
				for i in range(SIZE):
					for j in range(SIZE):
						if int(bg[i][j]) != _D.TileType.OCEAN_DEEP:
							bad += 1
			print("HUNT-OC | chunk %s bad_cells=%d" % [str(k), bad])
			if bad > 0:
				all_clean = false
			await _W.wait_for_tasks_async(get_tree())
		print("HUNT-OC | group all clean:", all_clean)

	# ── 2. Làng đủ 7 công trình (seed 20260805) ────────────────────────
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()
	_W._reset_networks()
	var full_village := Vector2i(99999, 99999)
	var done_full := false
	for cx in range(-30, 31):
		for cz in range(-30, 31):
			if done_full: break
			var cw_x: float = float(cx) * SIZE + SIZE * 0.5
			var cw_z: float = float(cz) * SIZE + SIZE * 0.5
			if sqrt(cw_x * cw_x + cw_z * cw_z) < _V.VILLAGE_MIN_DIST: continue
			var seed_v: int = cx * 1372589 ^ cz * 1731733
			if _V._vh_hash(seed_v, 1) % 100 >= _V.VILLAGE_CHANCE: continue
			var data := _W.compute_chunk(cx, cz, SIZE, RW)
			var vd: Dictionary = data.get("village_data", {})
			if not vd.get("has", false): continue
			var types: Array = []
			for b in vd.get("info", {}).get("buildings", []):
				if not types.has(b.type):
					types.append(b.type)
			if types.size() >= 7:
				print("HUNT-V | FULL village at (%d,%d) types=%s" % [cx, cz, str(types)])
				full_village = Vector2i(cx, cz)
				done_full = true
				await _W.wait_for_tasks_async(get_tree())

	# ── 3. Chunk có cầu tre (đường cắt sông) ───────────────────────────
	_W._reset_networks()
	_Road._ensure_roads()
	_River._ensure_rivers()
	var found_bridge := Vector2i(99999, 99999)
	var done_b := false
	for x in range(-600, 601, 4):
		for z in range(-600, 601, 4):
			if done_b: break
			if not _Road.is_on_road(float(x), float(z)): continue
			if not _River.is_on_river(float(x), float(z)): continue
			var bc2 := Vector2i(int(floor(float(x) / SIZE)), int(floor(float(z) / SIZE)))
			var data := _W.compute_chunk(bc2.x, bc2.y, SIZE, RW)
			var bd: Dictionary = data.get("bridge_data", {})
			var bx: Array = bd.get("xforms", [])
			if bx.size() > 0:
				print("HUNT-B | bridge at chunk %s boxes=%d" % [str(bc2), bx.size()])
				found_bridge = bc2
				done_b = true
				await _W.wait_for_tasks_async(get_tree())

	print("HUNT-DONE | ocean3x2=%s full_village=%s bridge=%s" % [str(found_oc), str(full_village), str(found_bridge)])
	await _W.wait_for_tasks_async(get_tree())
	get_tree().quit(0)
