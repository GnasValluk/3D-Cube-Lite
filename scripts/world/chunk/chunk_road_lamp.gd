extends RefCounted

const _Data  = preload("chunk_data.gd")
const _Road  = preload("chunk_road.gd")
const _WoodLamp = preload("res://scripts/world/props/wood_lamp.gd")

const LAMP_SPACING: float = 28.0
const LAMP_SIDE_OFFSET: float = 2.8
const LAMP_SKIP_CHANCE: float = 0.45

static func compute_positions(cx: int, cz: int, size: int,
		biome_grid: Array, height_grid: Array, cols: int) -> Array:
	_Road._ensure_roads()

	var half:     float = size * 0.5
	var cx_world: float = cx * size
	var cz_world: float = cz * size
	var min_x:    float = cx_world - half
	var max_x:    float = cx_world + half
	var min_z:    float = cz_world - half
	var max_z:    float = cz_world + half
	var pad:      float = LAMP_SPACING

	var rng := RandomNumberGenerator.new()
	rng.seed = SeedSnapshot.ensure() + cx * 100003 + cz * 200003 + 54321

	var placed: Array[Vector2] = []
	var result: Array = []

	for ci in _Road.gather_curve_indices(min_x, min_z, max_x, max_z):
		var curve: PackedVector2Array = _Road._road_curves[ci]
		if curve.size() < 2:
			continue
		var bb: Rect2 = _Road.curve_bbox(ci)
		if bb.end.x < min_x - pad or bb.position.x > max_x + pad: continue
		if bb.end.y < min_z - pad or bb.position.y > max_z + pad: continue

		var dist_acc: float = 0.0
		var next_dist: float = rng.randf_range(LAMP_SPACING * 0.3, LAMP_SPACING * 0.7)

		for i in range(curve.size() - 1):
			var a: Vector2 = curve[i]
			var b: Vector2 = curve[i + 1]
			var seg_len: float = a.distance_to(b)
			if seg_len < 0.001:
				continue
			var seg_dir:  Vector2 = (b - a) / seg_len
			var seg_perp: Vector2 = Vector2(seg_dir.y, -seg_dir.x)
			var t_end:    float   = dist_acc + seg_len

			while next_dist <= t_end:
				var frac:    float   = (next_dist - dist_acc) / seg_len
				var road_pt: Vector2 = a.lerp(b, frac)
				var lamp_2d: Vector2 = road_pt + seg_perp * LAMP_SIDE_OFFSET
				var lx: float = lamp_2d.x
				var lz: float = lamp_2d.y

				if lx >= min_x and lx < max_x and lz >= min_z and lz < max_z:
					if rng.randf() < LAMP_SKIP_CHANCE:
						next_dist += LAMP_SPACING
						continue

					var vx: int = clampi(int((lx - min_x) / _Data.VOXEL), 0, cols - 1)
					var vz: int = clampi(int((lz - min_z) / _Data.VOXEL), 0, cols - 1)
					var lamp_y: float = height_grid[vx][vz] if height_grid.size() > 0 else 1.0

					if cols > 0 and biome_grid.size() > 0:
						var biome: int = biome_grid[vx][vz]
						var h: float = height_grid[vx][vz] if height_grid.size() > 0 else 1.0
						var skip: bool = false
						match biome:
							_Data.TileType.SAND, _Data.TileType.SAND_WHITE, \
							_Data.TileType.SILT, _Data.TileType.OCEAN_DEEP:
								skip = true
						if not skip and h < _Data.WATER_Y:
							skip = true
						if not skip:
							for ox in [-1, 0, 1]:
								for oz in [-1, 0, 1]:
									var nx: int = clampi(vx + ox, 0, cols - 1)
									var nz: int = clampi(vz + oz, 0, cols - 1)
									var nb: int = biome_grid[nx][nz]
									var nh: float = height_grid[nx][nz] if height_grid.size() > 0 else 1.0
									if nb == _Data.TileType.SAND or nb == _Data.TileType.SAND_WHITE \
									or nb == _Data.TileType.SILT \
									or nb == _Data.TileType.OCEAN_DEEP or nh < _Data.WATER_Y:
										skip = true
										break
								if skip: break
						if skip:
							next_dist += LAMP_SPACING
							continue

					var too_close: bool = false
					var min_dist2: float = (LAMP_SPACING * 0.55) * (LAMP_SPACING * 0.55)
					for prev in placed:
						if prev.distance_squared_to(lamp_2d) < min_dist2:
							too_close = true
							break
					if not too_close:
						placed.append(lamp_2d)
						result.append({
							"x": lx - cx_world,
							"z": lz - cz_world,
							"y": lamp_y,
							"dx": seg_dir.x,
							"dz": seg_dir.y
						})
				next_dist += LAMP_SPACING
			dist_acc = t_end
	return result

static func spawn_from_data(parent: Node, positions: Array) -> void:
	const PER_FRAME: int = 2
	var count: int = 0
	for data in positions:
		if not parent.is_inside_tree():
			return
		var lamp: Node3D = _WoodLamp.new()
		lamp.set_meta("road_dir_x", data["dx"])
		lamp.set_meta("road_dir_y", data["dz"])
		lamp.position = Vector3(data["x"], data.get("y", 1.0), data["z"])
		parent.add_child(lamp)
		count += 1
		if count >= PER_FRAME:
			count = 0
			await parent.get_tree().process_frame
