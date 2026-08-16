class_name FarPropPool
extends Object

## Pool props RENDER XA — GỘP MỌI cây/bụi ở vòng ngoài (Chebyshev > PROP_MERGE_RING)
## thành vài MultiMeshInstance3D toàn cục (1 draw call / loại), thay vì 1 node
## DestroyableProp + collision + sway riêng cho mỗi cây. Vòng gần vẫn spawn node
## tương tác (chặt/đập) qua queue thường. Voxel proxy dùng chung BoxMesh
## (VoxelShared.box) + material (VoxelShared.mat); sinh deterministic theo vị trí
## → 2 lần load cùng chunk ra cùng hình. Data theo chunk để gỡ/rebuild dễ khi
## chunk vào/ra; flush rebuild thay đổi mỗi frame trong OpenWorldManager._process.

const _VS = preload("res://scripts/world/props/voxel_shared.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

static var _holder: Node3D = null
static var _by_chunk: Dictionary = {}   # chunkkey → Array[Dictionary{type, positions, scales, colors}]
static var _mmi: Dictionary = {}        # type → MultiMeshInstance3D
static var _dirty: Dictionary = {}      # type → true (cần rebuild)

## Nhóm "cây lớn": thân + tán. Còn lại = cụm nhỏ ven nước/đồng cỏ.
const _TREES := ["palm", "oak", "orange_tree", "dense_tree", "spruce",
	"swamp_tree", "mangrove"]

static func _ensure_holder() -> void:
	if _holder == null and Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			_holder = Node3D.new()
			_holder.name = "FarProps"
			tree.root.add_child(_holder)

static func _hash(p: Vector3, salt: String) -> int:
	return hash(Vector3i(roundi(p.x * 8), roundi(p.y * 8), roundi(p.z * 8))) \
			* 31 + salt.hash()

## ── Proxy hình dáng ──────────────────────────────────────────────────────────
## Sinh deterministic: seed từ (vị trí, type). Cây = cột thân + vài khối tán;
## bụi/cỏ nước = vài voxel nhỏ. Đủ nhìn ở xa, chi phí rẻ.
static func proxy_for(type: String, variant: String, p: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(p, type + "/" + variant)
	var positions: Array[Vector3] = []
	var scales: Array[float] = []
	var colors: Array[Color] = []

	var trunk_c := _trunk_color(type)
	var leaf_c := _leaf_color(type, rng)
	var is_tree: bool = type in _TREES
	var h := 0.6
	var canopy_r := 0.9
	if is_tree:
		match type:
			"palm":
				h = rng.randf_range(4.0, 6.0); canopy_r = rng.randf_range(1.1, 1.5)
			"spruce":
				h = rng.randf_range(3.5, 5.5); canopy_r = rng.randf_range(1.0, 1.3)
			"mangrove":
				h = rng.randf_range(2.6, 4.0); canopy_r = rng.randf_range(1.2, 1.7)
			"swamp_tree":
				h = rng.randf_range(3.2, 4.6); canopy_r = rng.randf_range(1.0, 1.4)
			_:
				h = rng.randf_range(3.4, 5.2); canopy_r = rng.randf_range(1.3, 1.8)

	# Thân: 2-4 lớp voxel cột, nhấp nhô nhẹ quanh trục.
	var trunk_layers := ceili(h / 0.5)
	for li in range(trunk_layers):
		var y := 0.4 + li * 0.5
		var jx := (rng.randf() - 0.5) * 0.18 * (1.0 - float(li) / float(trunk_layers))
		var jz := (rng.randf() - 0.5) * 0.18 * (1.0 - float(li) / float(trunk_layers))
		positions.append(p + Vector3(jx, y, jz))
		scales.append(_VS.TRUNK_SCALE)
		colors.append(trunk_c)

	if is_tree:
		var canopy_top := p.y + h + rng.randf_range(0.2, 0.8)
		var n_leaf := 8 + rng.randi() % 8
		for _i in range(n_leaf):
			var a := rng.randf() * TAU
			var rr := rng.randf()
			var rad := canopy_r * sqrt(rr)
			var ly := p.y + h + (rng.randf() - 0.5) * canopy_r * 0.8
			var op := Vector3(cos(a) * rad, ly, sin(a) * rad)
			positions.append(op)
			scales.append(_VS.LEAF_SCALE)
			colors.append(leaf_c)
	else:
		# Bụi / cây mảnh / cỏ nước: 3-6 voxel nhỏ quanh gốc.
		var n_small := 3 + rng.randi() % 4
		for _i in range(n_small):
			var a := rng.randf() * TAU
			var rr := rng.randf() * canopy_r
			var ly := p.y + 0.2 + rng.randf() * 0.5
			var op := Vector3(cos(a) * rr, ly, sin(a) * rr)
			positions.append(op)
			scales.append(_VS.FINE_SCALE)
			colors.append(leaf_c)

	return {"type": type, "positions": positions, "scales": scales, "colors": colors}

static func _trunk_color(type: String) -> Color:
	match type:
		"oak":            return Color(0.39, 0.26, 0.12)
		"palm":           return Color(0.62, 0.50, 0.30)
		"mangrove":       return Color(0.30, 0.18, 0.10)
		"spruce":         return Color(0.24, 0.16, 0.10)
		"swamp_tree":     return Color(0.30, 0.26, 0.22)
		"orange_tree":    return Color(0.55, 0.40, 0.22)
		"dense_tree":     return Color(0.30, 0.20, 0.10)
		_:                return Color(0.44, 0.36, 0.30)

static func _leaf_color(type: String, rng: RandomNumberGenerator) -> Color:
	var base: Color
	match type:
		"spruce":         base = Color(0.10, 0.30, 0.18)
		"swamp_tree":     base = Color(0.20, 0.35, 0.16)
		"mangrove":       base = Color(0.22, 0.38, 0.20)
		"palm":           base = Color(0.30, 0.50, 0.18)
		"sunflower":      base = Color(0.95, 0.78, 0.10)  # đầu hoa vàng rực
		"tulip":          base = Color(0.92, 0.22, 0.34)  # búp đỏ/cam
		"rose":           base = Color(0.86, 0.12, 0.18)  # cánh hồng thắm
		"clover":         base = Color(0.14, 0.50, 0.12)  # lá ba chét xanh
		"wild_berry":     base = Color(0.52, 0.18, 0.10)  # quả đỏ thẫm
		_:
			base = Color(0.45, 0.62, 0.12)
	var j := (rng.randf() - 0.5) * 0.10
	return Color(clampf(base.r + j, 0.0, 1.0), clampf(base.g + j, 0.0, 1.0),
		clampf(base.b + j, 0.0, 1.0), 1.0)

## Thay thế data proxy của 1 chunk (entries = Array[Dictionary]) — đánh dấu dirty.
static func add_chunk(chunkkey: String, entries: Array) -> void:
	_ensure_holder()
	_by_chunk[chunkkey] = entries
	for e in entries:
		_dirty[e["type"]] = true

static func remove_chunk(chunkkey: String) -> void:
	if not _by_chunk.has(chunkkey):
		return
	var entries: Array = _by_chunk[chunkkey]
	_by_chunk.erase(chunkkey)
	for e in entries:
		var t: String = e["type"]
		if _mmi.has(t) and is_instance_valid(_mmi[t]):
			(_mmi[t] as MultiMeshInstance3D).queue_free()
		_mmi.erase(t)
		_dirty[t] = true

## Dựng lại (lazy) mọi type bị đánh dấu — chạy 1 lần/frame trong manager.
## Rebuild = cộng toàn bộ entry chunk của type vào 1 MultiMesh duy nhất.
static func flush() -> void:
	if _dirty.is_empty():
		return
	var f0 := Time.get_ticks_usec()
	var to_build: Array = _dirty.keys()
	_dirty.clear()
	for type in to_build:
		var positions := PackedVector3Array()
		var buf := PackedFloat32Array()
		var n := 0
		for ck in _by_chunk.keys():
			for e in (_by_chunk[ck] as Array):
				if e["type"] != type:
					continue
				var ps: Array = e["positions"]
				var sc: Array = e["scales"]
				var bc: Array = e["colors"]
				for i in range(ps.size()):
					var p: Vector3 = ps[i]
					var s: float = sc[i]
					var c: Color = bc[i]
					buf.resize((n + 1) * 16)
					buf[n * 16] = s; buf[n * 16 + 1] = 0.0; buf[n * 16 + 2] = 0.0; buf[n * 16 + 3] = p.x
					buf[n * 16 + 4] = 0.0; buf[n * 16 + 5] = s; buf[n * 16 + 6] = 0.0; buf[n * 16 + 7] = p.y
					buf[n * 16 + 8] = 0.0; buf[n * 16 + 9] = 0.0; buf[n * 16 + 10] = s; buf[n * 16 + 11] = p.z
					buf[n * 16 + 12] = c.r; buf[n * 16 + 13] = c.g; buf[n * 16 + 14] = c.b; buf[n * 16 + 15] = c.a
					positions.append(p)
					n += 1
		var mm: MultiMesh = null
		if _mmi.has(type) and is_instance_valid(_mmi[type]):
			mm = (_mmi[type] as MultiMeshInstance3D).multimesh
		if mm == null:
			mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = _VS.box()
			mm.instance_count = 0
		mm.instance_count = n
		if n > 0:
			mm.set_buffer(buf)
		if not _mmi.has(type):
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _VS.mat()
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_holder.add_child(mmi)
			_mmi[type] = mmi
	var fcost := float(Time.get_ticks_usec() - f0) * 0.001
	if fcost > 5.0:
		print("[fpp] flush cost=%.1fms types=%d chunks=%d" % [fcost, to_build.size(), _by_chunk.size()])

static func clear_all() -> void:
	for t in _mmi:
		if is_instance_valid(_mmi[t]):
			(_mmi[t] as MultiMeshInstance3D).queue_free()
	_mmi.clear()
	_by_chunk.clear()
	_dirty.clear()