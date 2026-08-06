extends Node

## Profiler pipeline load chunk — đo chính xác từng bước tốn thời gian trên
## MAIN THREAD (nguồn lag khi load chunk). Chạy: res://tools/test_stream_profile.tscn
## Không phải test PASS/FAIL — chỉ in số liệu để benchmark.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const SIZE := 32
const REAL: int = _D._Dim.DimensionID.REAL_WORLD

var _stage: int = 0
var _parent: Node3D = null

func _ready() -> void:
	WorldSeed.seed_value = 123456789
	_W.prewarm_async()
	_parent = Node3D.new()
	add_child(_parent)
	_stage = 1

func _process(_delta: float) -> void:
	if _stage == 1:
		if _W._networks_ready:
			_stage = 2
			_find_grassy()
	elif _stage == 2:
		_stage = 3
		_profile_ocean()
	elif _stage == 3:
		await _W.wait_for_tasks_async(get_tree())
		get_tree().quit(0)

func _find_grassy() -> void:
	print("== tìm chunk nhiều cỏ ==")
	var best := Vector2i(0, 0)
	var best_n := 0
	var best_data: Dictionary = {}
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var k := Vector2i(dx, dz)
			var data := _W.compute_chunk(k.x, k.y, SIZE, REAL)
			var n := (data.get("grass_blade_data", {}).get("xforms", []) as Array).size()
			if n > best_n:
				best_n = n
				best = k
				best_data = data
	print("best grass chunk=%s n=%d" % [best, best_n])
	if best_n > 0:
		_apply_timed(best_data, "GRASSY", best)

func _profile_ocean() -> void:
	print("== OCEAN chunk ==")
	var data := _W.compute_chunk(-302, -230, SIZE, REAL)
	_apply_timed(data, "OCEAN", Vector2i(-302, -230))

func _apply_timed(data: Dictionary, tag: String, k: Vector2i) -> void:
	var gbd: Dictionary = data.get("grass_blade_data", {})
	var vbd: Dictionary = data.get("village_data", {})
	var gxforms: Array = gbd.get("xforms", [])
	var gcolors: Array = gbd.get("colors", [])
	print("[%s] grass=%d village=%d props=%d lotus=%d lamps=%d" % [
		tag, gxforms.size(), (vbd.get("xforms", []) as Array).size(),
		(data.get("plant_props", []) as Array).size(),
		(data.get("lotus_lights", []) as Array).size(),
		(data.get("lamp_positions", []) as Array).size(),
	])

	var t := Time.get_ticks_usec()
	var mm := _build_grass_mm(gxforms, gcolors)
	var loop_ms := (Time.get_ticks_usec() - t) * 0.001
	print("[%s] GRASS_MM_LOOP=%.2fms" % [tag, loop_ms])

	t = Time.get_ticks_usec()
	var mm2 := _build_grass_mm_bulk(gxforms, gcolors)
	var bulk_ms := (Time.get_ticks_usec() - t) * 0.001
	print("[%s] GRASS_MM_BULK=%.2fms" % [tag, bulk_ms])

	var c := _W.new()
	c.name = "C"
	c.position = Vector3(k.x * SIZE, 0, k.y * SIZE)
	c._cx = k.x; c._cz = k.y; c._size = SIZE
	c._dimension_id = REAL
	c._cols = int(SIZE / _D.VOXEL)
	c._tiles_per_chunk = int(c._cols / _D.TILE_W)
	c._init_materials()
	_parent.add_child(c)
	t = Time.get_ticks_usec()
	c.apply_chunk(data)
	c._pending_data = {}
	print("[%s] APPLY_TOTAL=%.2fms" % [tag, (Time.get_ticks_usec() - t) * 0.001])

	# Đo chi phí tạo trimesh collision shape (chạy trong CollisionQueue._process)
	var tmesh: ArrayMesh = data.get("mesh")
	if tmesh != null:
		t = Time.get_ticks_usec()
		var shape := tmesh.create_trimesh_shape()
		var tri_cnt := 0
		for i in range(tmesh.get_surface_count()):
			var arr := tmesh.surface_get_arrays(i)
			if arr != null and arr.size() > 0:
				var idx = arr[Mesh.ARRAY_INDEX]
				if (idx is PackedInt32Array) and (idx as PackedInt32Array).size() > 0:
					tri_cnt += (idx as PackedInt32Array).size() / 3
				else:
					var v: PackedVector3Array = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
					tri_cnt += v.size() / 3
		print("[%s] TRIMESH=%.2fms tris=%d" % [tag, (Time.get_ticks_usec() - t) * 0.001, tri_cnt])

	t = Time.get_ticks_usec()
	var sd2 := _W._build_shaped_block_data(c.block_data, c._cols, REAL)
	print("[%s] SHAPED_SCAN=%.2fms boxes=%d" % [tag, (Time.get_ticks_usec() - t) * 0.001, sd2["shaped_pos"].size()])

	t = Time.get_ticks_usec()
	c._apply_shaped_block_data(data)
	var shaped_ms := (Time.get_ticks_usec() - t) * 0.001
	var colliders := 0
	var body = c._shaped_collider
	if body != null:
		colliders = body.get_child_count()
	print("[%s] SHAPED_APPLY=%.2fms colliders=%d" % [tag, shaped_ms, colliders])

	var hasw: bool = data.get("has_water", false)
	if hasw and c._max_water_ly >= 0 and c.block_data != null:
		t = Time.get_ticks_usec()
		var wm := _W._build_water_mesh(c.block_data, c._cols, REAL, _D.VOXEL * 0.5,
			SIZE * 0.5, {}, c._max_water_ly)
		print("[%s] WATER_BUILD=%.2fms" % [tag, (Time.get_ticks_usec() - t) * 0.001])
	c.queue_free()

## Cách hiện tại trong apply_chunk — set_instance_transform từng cái
func _build_grass_mm(gxforms: Array, gcolors: Array) -> MultiMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = gxforms.size()
	for i in range(gxforms.size()):
		mm.set_instance_transform(i, gxforms[i] as Transform3D)
		mm.set_instance_color(i, gcolors[i] as Color)
	return mm

## Dùng set_buffer — 1 lệnh cho toàn bộ transform + color
func _build_grass_mm_bulk(gxforms: Array, gcolors: Array) -> MultiMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = gxforms.size()
	var buf := PackedFloat32Array()
	buf.resize(gxforms.size() * 16)
	var k := 0
	for i in range(gxforms.size()):
		var t: Transform3D = gxforms[i] as Transform3D
		buf[k] = t.basis.x.x; buf[k+1] = t.basis.y.x; buf[k+2] = t.basis.z.x; buf[k+3] = t.origin.x
		buf[k+4] = t.basis.x.y; buf[k+5] = t.basis.y.y; buf[k+6] = t.basis.z.y; buf[k+7] = t.origin.y
		buf[k+8] = t.basis.x.z; buf[k+9] = t.basis.y.z; buf[k+10] = t.basis.z.z; buf[k+11] = t.origin.z
		var col: Color = gcolors[i] as Color
		buf[k+12] = col.r; buf[k+13] = col.g; buf[k+14] = col.b; buf[k+15] = col.a
		k += 16
	mm.set_buffer(buf)
	return mm
