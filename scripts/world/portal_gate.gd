extends Node3D
class_name PortalGate

const _Dim = preload("res://scripts/world/dimension_defs.gd")

var dest_dimension: int = _Dim.DimensionID.TWILIGHT

const VOXEL: float = 0.50
const FW: int = 5
const FH: int = 8
const BASE_W: int = 9
const BASE_D: int = 7

var _player_on: bool = false
var _age: float = 0.0
var _light: OmniLight3D
var _motes: Array[MeshInstance3D] = []
var _mote_angles: Array[float] = []
var _fireflies: Array[MeshInstance3D] = []
var _firefly_angles: Array[float] = []
var _spores: Array[MeshInstance3D] = []
var _spore_angles: Array[float] = []

func _ready() -> void:
	_build_platform()

func _is_twilight() -> bool:
	return dest_dimension == _Dim.DimensionID.TWILIGHT

func _build_platform() -> void:
	_build_base()
	_build_frame()
	_build_vines()
	_build_portal_surface()
	_build_light()
	if _is_twilight():
		_build_moss()
		_build_glowing_plants()
		_build_mushrooms()
		_build_runes()
		_build_hanging_moss()
		_build_flowers()
		_build_fireflies()
		_build_spores()
	else:
		_build_moss_ruins()
		_build_carvings()
		_build_motes()
	_build_area()

func make_voxel_mat(albedo: Color, emissive: Color = Color.BLACK, emit_power: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = albedo
	if emit_power > 0.0:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = emit_power
	return m

func _add_voxel(parent: Node3D, pos: Vector3, mat: StandardMaterial3D, sz: float = VOXEL) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(sz, sz, sz)
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_base() -> void:
	var base_mat: StandardMaterial3D
	if _is_twilight():
		base_mat = make_voxel_mat(Color(0.04, 0.07, 0.09), Color(0.06, 0.10, 0.12), 0.1)
	else:
		base_mat = make_voxel_mat(Color(0.28, 0.25, 0.22))
	var off: Vector3 = Vector3(
		-(BASE_W - 1) * VOXEL * 0.5,
		-VOXEL * 0.5,
		-(BASE_D - 1) * VOXEL * 0.5
	)
	for x in range(BASE_W):
		for z in range(BASE_D):
			var p: Vector3 = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
			_add_voxel(self, p, base_mat)

	var body: StaticBody3D = StaticBody3D.new()
	var bcol: CollisionShape3D = CollisionShape3D.new()
	var bcs: BoxShape3D = BoxShape3D.new()
	bcs.size = Vector3(BASE_W * VOXEL, VOXEL, BASE_D * VOXEL)
	bcol.shape = bcs
	bcol.position.y = -VOXEL * 0.5
	body.add_child(bcol)
	add_child(body)

func _build_moss() -> void:
	var moss_mat: StandardMaterial3D = make_voxel_mat(Color(0.04, 0.12, 0.09), Color(0.06, 0.18, 0.12), 0.2)
	var off: Vector3 = Vector3(
		-(BASE_W - 1) * VOXEL * 0.5,
		VOXEL * 0.45,
		-(BASE_D - 1) * VOXEL * 0.5
	)
	for i in range(16):
		var x: int = randi_range(0, BASE_W - 1)
		var z: int = randi_range(0, BASE_D - 1)
		var p: Vector3 = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(VOXEL * 0.5, VOXEL * 0.08, VOXEL * 0.5)
		mi.mesh = box
		mi.material_override = moss_mat
		mi.position = p
		add_child(mi)

func _build_moss_ruins() -> void:
	var moss_mat: StandardMaterial3D = make_voxel_mat(Color(0.12, 0.40, 0.15))
	var off: Vector3 = Vector3(
		-(BASE_W - 1) * VOXEL * 0.5,
		VOXEL * 0.45,
		-(BASE_D - 1) * VOXEL * 0.5
	)
	for i in range(24):
		var x: int = randi_range(0, BASE_W - 1)
		var z: int = randi_range(0, BASE_D - 1)
		var p: Vector3 = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(VOXEL * 0.6, VOXEL * 0.10, VOXEL * 0.6)
		mi.mesh = box
		mi.material_override = moss_mat
		mi.position = p
		add_child(mi)

func _build_glowing_plants() -> void:
	var plant_mat: StandardMaterial3D = make_voxel_mat(Color(0.06, 0.20, 0.15), Color(0.10, 0.35, 0.25), 1.2)
	var crystal_mat: StandardMaterial3D = make_voxel_mat(Color(0.05, 0.25, 0.30), Color(0.08, 0.45, 0.50), 2.5)
	var off: Vector3 = Vector3(
		-(BASE_W - 1) * VOXEL * 0.5,
		VOXEL * 0.5,
		-(BASE_D - 1) * VOXEL * 0.5
	)
	for i in range(8):
		var x: int = randi_range(1, BASE_W - 2)
		var z: int = randi_range(1, BASE_D - 2)
		var mat: StandardMaterial3D = plant_mat if i % 2 == 0 else crystal_mat
		var h: float = 0.3 + randf() * 0.5
		var p: Vector3 = off + Vector3(x * VOXEL, 0.0, z * VOXEL)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(VOXEL * 0.22, h, VOXEL * 0.22)
		mi.mesh = box
		mi.material_override = mat
		mi.position = p
		add_child(mi)
		var tip: MeshInstance3D = MeshInstance3D.new()
		var tip_box: BoxMesh = BoxMesh.new()
		tip_box.size = Vector3(VOXEL * 0.1, VOXEL * 0.12, VOXEL * 0.1)
		tip.mesh = tip_box
		tip.material_override = mat
		tip.position = p + Vector3(0.0, h * 0.5 + VOXEL * 0.06, 0.0)
		add_child(tip)

func _build_mushrooms() -> void:
	var stem_mat: StandardMaterial3D = make_voxel_mat(Color(0.05, 0.10, 0.08), Color(0.07, 0.15, 0.10), 0.1)
	var cap_colors: Array[Color] = [
		Color(0.08, 0.35, 0.30),
		Color(0.10, 0.40, 0.25),
		Color(0.05, 0.25, 0.35),
		Color(0.15, 0.30, 0.20),
	]
	var off_base: Vector3 = Vector3(
		-(BASE_W - 1) * VOXEL * 0.5,
		0.0,
		-(BASE_D - 1) * VOXEL * 0.5
	)
	for i in range(4):
		var x: int = randi_range(1, BASE_W - 2)
		var z: int = randi_range(1, BASE_D - 2)
		var p: Vector3 = off_base + Vector3(x * VOXEL, 0.0, z * VOXEL)
		var stem: MeshInstance3D = MeshInstance3D.new()
		var stem_box: BoxMesh = BoxMesh.new()
		stem_box.size = Vector3(VOXEL * 0.15, VOXEL * 0.4, VOXEL * 0.15)
		stem.mesh = stem_box
		stem.material_override = stem_mat
		stem.position = p + Vector3(0.0, VOXEL * 0.2, 0.0)
		add_child(stem)
		var cap_mat: StandardMaterial3D = StandardMaterial3D.new()
		var ci: int = i % cap_colors.size()
		cap_mat.albedo_color = cap_colors[ci]
		cap_mat.emission_enabled = true
		cap_mat.emission = cap_colors[ci]
		cap_mat.emission_energy_multiplier = 1.5
		cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var cap: MeshInstance3D = MeshInstance3D.new()
		var cap_sph: SphereMesh = SphereMesh.new()
		cap_sph.radius = VOXEL * 0.18
		cap_sph.height = VOXEL * 0.18
		cap.mesh = cap_sph
		cap.material_override = cap_mat
		cap.position = p + Vector3(0.0, VOXEL * 0.4, 0.0)
		add_child(cap)

func _build_frame() -> void:
	var ox: float = -(FW - 1) * VOXEL * 0.5
	var oz: float = 0.0

	if _is_twilight():
		var frame_mat: StandardMaterial3D = make_voxel_mat(Color(0.03, 0.06, 0.08), Color(0.08, 0.12, 0.15), 0.15)
		var frame_mat2: StandardMaterial3D = make_voxel_mat(Color(0.05, 0.08, 0.10), Color(0.06, 0.10, 0.12), 0.12)
		for x in range(FW):
			var p: Vector3 = Vector3(ox + x * VOXEL, 0.0, oz)
			_add_voxel(self, p, frame_mat)
		for x in range(FW):
			var p: Vector3 = Vector3(ox + x * VOXEL, (FH - 1) * VOXEL, oz)
			var m: StandardMaterial3D = frame_mat2 if (x == 0 or x == FW - 1) else frame_mat
			_add_voxel(self, p, m)
		for y in range(1, FH - 1):
			var p: Vector3 = Vector3(ox, y * VOXEL, oz)
			_add_voxel(self, p, frame_mat2)
		for y in range(1, FH - 1):
			var p: Vector3 = Vector3(ox + (FW - 1) * VOXEL, y * VOXEL, oz)
			_add_voxel(self, p, frame_mat2)

		var crystal_mat: StandardMaterial3D = make_voxel_mat(Color(0.05, 0.30, 0.35), Color(0.10, 0.55, 0.60), 3.0)
		for side in [-1, 1]:
			for dz in [-1, 1]:
				var sx: float = ox + (1 if side < 0 else FW - 2) * VOXEL + side * VOXEL * 0.5
				var sy: float = (FH - 1) * VOXEL + VOXEL * 0.5
				var sz: float = dz * VOXEL * 0.4
				var pos: Vector3 = Vector3(sx, sy, sz)
				var mi: MeshInstance3D = MeshInstance3D.new()
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3(VOXEL * 0.5, VOXEL * 0.7, VOXEL * 0.3)
				mi.mesh = box
				mi.material_override = crystal_mat
				mi.position = pos
				add_child(mi)
				var tip: MeshInstance3D = MeshInstance3D.new()
				var tip_box: BoxMesh = BoxMesh.new()
				tip_box.size = Vector3(VOXEL * 0.25, VOXEL * 0.35, VOXEL * 0.15)
				tip.mesh = tip_box
				tip.material_override = crystal_mat
				tip.position = pos + Vector3(0.0, VOXEL * 0.5, 0.0)
				add_child(tip)

		var root_mat: StandardMaterial3D = make_voxel_mat(Color(0.03, 0.08, 0.06), Color(0.05, 0.12, 0.08), 0.1)
		for side in [-1, 1]:
			var wx: float = ox + (FW - 1) * VOXEL * 0.5 - side * VOXEL * 0.5
			for seg in range(3):
				var ry: float = (1 + seg * 2) * VOXEL
				var ro: MeshInstance3D = MeshInstance3D.new()
				var rbox: BoxMesh = BoxMesh.new()
				rbox.size = Vector3(VOXEL * 0.35, VOXEL * 0.18, VOXEL * 0.35)
				ro.mesh = rbox
				ro.material_override = root_mat
				ro.position = Vector3(wx + side * VOXEL * 0.4, ry, oz)
				add_child(ro)
	else:
		var stone: StandardMaterial3D = make_voxel_mat(Color(0.32, 0.30, 0.27))
		var stone_dark: StandardMaterial3D = make_voxel_mat(Color(0.26, 0.24, 0.22))
		var stone_light: StandardMaterial3D = make_voxel_mat(Color(0.38, 0.35, 0.31))

		for x in range(FW):
			var p: Vector3 = Vector3(ox + x * VOXEL, 0.0, oz)
			_add_voxel(self, p, stone_dark)
		for x in range(FW):
			var p: Vector3 = Vector3(ox + x * VOXEL, (FH - 1) * VOXEL, oz)
			var m: StandardMaterial3D = stone_light if (x == 0 or x == FW - 1) else stone
			_add_voxel(self, p, m)
		for y in range(1, FH - 1):
			var p: Vector3 = Vector3(ox, y * VOXEL, oz)
			var m: StandardMaterial3D = stone_light if y % 3 == 0 else stone_dark
			_add_voxel(self, p, m)
		for y in range(1, FH - 1):
			var p: Vector3 = Vector3(ox + (FW - 1) * VOXEL, y * VOXEL, oz)
			var m: StandardMaterial3D = stone_light if y % 3 == 0 else stone_dark
			_add_voxel(self, p, m)

func _build_runes() -> void:
	var rune_mat: StandardMaterial3D = make_voxel_mat(Color(0.10, 0.45, 0.40), Color(0.15, 0.70, 0.60), 3.0)
	var ox: float = -(FW - 1) * VOXEL * 0.5
	var oz: float = 0.0

	for side in [0, FW - 1]:
		for y in [2, 5]:
			var p: Vector3 = Vector3(ox + side * VOXEL, y * VOXEL, oz + VOXEL * 0.3)
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(VOXEL * 0.15, VOXEL * 0.15, VOXEL * 0.15)
			mi.mesh = box
			mi.material_override = rune_mat
			mi.position = p
			add_child(mi)

	var top_rune: MeshInstance3D = MeshInstance3D.new()
	var tr_box: BoxMesh = BoxMesh.new()
	tr_box.size = Vector3(VOXEL * 0.5, VOXEL * 0.12, VOXEL * 0.12)
	top_rune.mesh = tr_box
	top_rune.material_override = rune_mat
	top_rune.position = Vector3(0.0, (FH - 1) * VOXEL + VOXEL * 0.5, oz)
	add_child(top_rune)

func _build_carvings() -> void:
	var carve_mat: StandardMaterial3D = make_voxel_mat(Color(0.45, 0.42, 0.38))
	var ox: float = -(FW - 1) * VOXEL * 0.5
	var oz: float = 0.0

	for side in [0, FW - 1]:
		for y in [3, 6]:
			var p: Vector3 = Vector3(ox + side * VOXEL, y * VOXEL, oz + VOXEL * 0.3)
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(VOXEL * 0.12, VOXEL * 0.12, VOXEL * 0.08)
			mi.mesh = box
			mi.material_override = carve_mat
			mi.position = p
			add_child(mi)

	var top_carve: MeshInstance3D = MeshInstance3D.new()
	var tc_box: BoxMesh = BoxMesh.new()
	tc_box.size = Vector3(VOXEL * 0.6, VOXEL * 0.10, VOXEL * 0.10)
	top_carve.mesh = tc_box
	top_carve.material_override = carve_mat
	top_carve.position = Vector3(0.0, (FH - 1) * VOXEL + VOXEL * 0.5, oz)
	add_child(top_carve)

func _build_vines() -> void:
	var ox: float = -(FW - 1) * VOXEL * 0.5
	var oz: float = 0.0

	if _is_twilight():
		var vine_mat: StandardMaterial3D = make_voxel_mat(Color(0.04, 0.10, 0.07), Color(0.06, 0.15, 0.10), 0.1)
		var leaf_mat: StandardMaterial3D = make_voxel_mat(Color(0.05, 0.18, 0.12), Color(0.08, 0.25, 0.15), 0.3)
		for side in [0, FW - 1]:
			for v in range(3):
				var start_y: int = 3 + randi_range(0, 3)
				var len_vine: int = 2 + randi_range(0, 2)
				var x_off: float = ox + side * VOXEL
				var z_jitter: float = (randf() - 0.5) * VOXEL * 0.5
				for seg in range(len_vine):
					var y_pos: float = start_y * VOXEL - seg * VOXEL * 0.6
					if y_pos < 0.0:
						break
					var p: Vector3 = Vector3(x_off + (randf() - 0.5) * VOXEL * 0.3, y_pos, oz + z_jitter)
					var mi: MeshInstance3D = MeshInstance3D.new()
					var box: BoxMesh = BoxMesh.new()
					box.size = Vector3(VOXEL * 0.18, VOXEL * 0.25, VOXEL * 0.18)
					mi.mesh = box
					mi.material_override = vine_mat
					mi.position = p
					add_child(mi)
					if seg % 2 == 0:
						var lf: MeshInstance3D = MeshInstance3D.new()
						var lb: BoxMesh = BoxMesh.new()
						lb.size = Vector3(VOXEL * 0.25, VOXEL * 0.05, VOXEL * 0.15)
						lf.mesh = lb
						lf.material_override = leaf_mat
						lf.position = p + Vector3((randf() - 0.5) * VOXEL * 0.3, -VOXEL * 0.15, (randf() - 0.5) * VOXEL * 0.3)
						add_child(lf)
	else:
		var vine_mat: StandardMaterial3D = make_voxel_mat(Color(0.10, 0.38, 0.12))
		var leaf_mat: StandardMaterial3D = make_voxel_mat(Color(0.15, 0.50, 0.18))
		for side in [0, FW - 1]:
			for v in range(5):
				var start_y: int = 2 + randi_range(0, 4)
				var len_vine: int = 3 + randi_range(0, 3)
				var x_off: float = ox + side * VOXEL
				var z_jitter: float = (randf() - 0.5) * VOXEL * 0.6
				for seg in range(len_vine):
					var y_pos: float = start_y * VOXEL - seg * VOXEL * 0.5
					if y_pos < 0.0:
						break
					var p: Vector3 = Vector3(x_off + (randf() - 0.5) * VOXEL * 0.3, y_pos, oz + z_jitter)
					var mi: MeshInstance3D = MeshInstance3D.new()
					var box: BoxMesh = BoxMesh.new()
					box.size = Vector3(VOXEL * 0.20, VOXEL * 0.22, VOXEL * 0.20)
					mi.mesh = box
					mi.material_override = vine_mat
					mi.position = p
					add_child(mi)
					if seg % 2 == 0:
						var lf: MeshInstance3D = MeshInstance3D.new()
						var lb: BoxMesh = BoxMesh.new()
						lb.size = Vector3(VOXEL * 0.30, VOXEL * 0.04, VOXEL * 0.18)
						lf.mesh = lb
						lf.material_override = leaf_mat
						lf.position = p + Vector3((randf() - 0.5) * VOXEL * 0.3, -VOXEL * 0.12, (randf() - 0.5) * VOXEL * 0.3)
						add_child(lf)
				var flower_clr: Color = [Color(1.0, 0.85, 0.90), Color(1.0, 0.95, 0.70), Color(0.90, 0.70, 0.80)][randi_range(0, 2)]
				if randf() < 0.5:
					var fm: StandardMaterial3D = StandardMaterial3D.new()
					fm.albedo_color = flower_clr
					fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					var fmi: MeshInstance3D = MeshInstance3D.new()
					var fsph: SphereMesh = SphereMesh.new()
					fsph.radius = VOXEL * 0.06
					fsph.height = VOXEL * 0.12
					fmi.mesh = fsph
					fmi.material_override = fm
					fmi.position = Vector3(x_off + (randf() - 0.5) * VOXEL * 0.5, start_y * VOXEL + 0.2, oz + z_jitter)
					add_child(fmi)

func _build_hanging_moss() -> void:
	var moss_mat: StandardMaterial3D = make_voxel_mat(Color(0.04, 0.12, 0.08), Color(0.06, 0.16, 0.10), 0.15)
	var ox: float = -(FW - 1) * VOXEL * 0.5
	var oz: float = 0.0

	for x in range(1, FW - 1):
		var count: int = 1 + randi_range(0, 1)
		for c in range(count):
			var len_moss: int = 1 + randi_range(0, 2)
			var x_off: float = ox + x * VOXEL + (randf() - 0.5) * VOXEL * 0.4
			for seg in range(len_moss):
				var y_pos: float = (FH - 1) * VOXEL - seg * VOXEL * 0.3
				var p: Vector3 = Vector3(x_off, y_pos, oz + (randf() - 0.5) * VOXEL * 0.3)
				var mi: MeshInstance3D = MeshInstance3D.new()
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3(VOXEL * 0.12, VOXEL * 0.2, VOXEL * 0.12)
				mi.mesh = box
				mi.material_override = moss_mat
				mi.position = p
				add_child(mi)

func _build_flowers() -> void:
	var colors: Array[Color] = [
		Color(0.10, 0.60, 0.50),
		Color(0.15, 0.50, 0.60),
		Color(0.30, 0.70, 0.40),
		Color(0.80, 0.55, 0.10),
		Color(0.10, 0.70, 0.55),
	]
	var ox: float = -(FW - 1) * VOXEL * 0.5
	var oz: float = 0.0

	for side in [-1, 1]:
		for f in range(3):
			var y_pos: float = (1 + randi_range(0, 5)) * VOXEL
			var x_off: float = ox + (FW - 1) * VOXEL * 0.5 - side * VOXEL * 0.3
			var clr: Color = colors[randi_range(0, colors.size() - 1)]
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = clr
			mat.emission_enabled = true
			mat.emission = clr
			mat.emission_energy_multiplier = 2.5
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var mi: MeshInstance3D = MeshInstance3D.new()
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = VOXEL * 0.13
			sph.height = VOXEL * 0.26
			mi.mesh = sph
			mi.material_override = mat
			mi.position = Vector3(x_off + side * VOXEL * 0.5, y_pos, oz + (randf() - 0.5) * VOXEL * 0.8)
			add_child(mi)
			var mi2: MeshInstance3D = MeshInstance3D.new()
			var sph2: SphereMesh = SphereMesh.new()
			sph2.radius = VOXEL * 0.07
			sph2.height = VOXEL * 0.14
			mi2.mesh = sph2
			mi2.material_override = mat
			mi2.position = mi.position + Vector3((randf() - 0.5) * VOXEL * 0.3, 0.0, (randf() - 0.5) * VOXEL * 0.3)
			add_child(mi2)

func _build_portal_surface() -> void:
	var pw: float = (FW - 2) * VOXEL
	var ph: float = (FH - 2) * VOXEL
	var pos: Vector3 = Vector3(0.0, (FH - 1) * VOXEL * 0.5, VOXEL * 0.5 + 0.05)

	if _is_twilight():
		var layers: Array[Dictionary] = [
			{ "alpha": 0.25, "emit": 2.0, "zoff": 0.0 },
			{ "alpha": 0.18, "emit": 1.5, "zoff": 0.03 },
			{ "alpha": 0.12, "emit": 1.0, "zoff": 0.06 },
		]
		for layer in layers:
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.albedo_color = Color(0.10, 0.55, 0.45, layer["alpha"])
			m.emission_enabled = true
			m.emission = Color(0.08, 0.45, 0.35)
			m.emission_energy_multiplier = layer["emit"]
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(pw, ph, 0.02)
			mi.mesh = box
			mi.material_override = m
			mi.position = pos + Vector3(0.0, 0.0, layer["zoff"])
			add_child(mi)
	else:
		var layers: Array[Dictionary] = [
			{ "alpha": 0.30, "emit": 1.5, "zoff": 0.0 },
			{ "alpha": 0.20, "emit": 1.0, "zoff": 0.04 },
			{ "alpha": 0.12, "emit": 0.6, "zoff": 0.08 },
		]
		for layer in layers:
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.albedo_color = Color(0.55, 0.80, 1.0, layer["alpha"])
			m.emission_enabled = true
			m.emission = Color(0.40, 0.70, 1.0)
			m.emission_energy_multiplier = layer["emit"]
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var mi: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(pw, ph, 0.02)
			mi.mesh = box
			mi.material_override = m
			mi.position = pos + Vector3(0.0, 0.0, layer["zoff"])
			add_child(mi)

func _build_light() -> void:
	_light = OmniLight3D.new()
	if _is_twilight():
		_light.light_color = Color(0.10, 0.50, 0.45)
		_light.light_energy = 1.0
		_light.omni_range = 4.0
	else:
		_light.light_color = Color(1.0, 0.90, 0.70)
		_light.light_energy = 1.2
		_light.omni_range = 5.0
	_light.position = Vector3(0.0, (FH - 1) * VOXEL * 0.5, 0.5)
	add_child(_light)

func _build_fireflies() -> void:
	var colors: Array[Color] = [
		Color(0.3, 0.9, 0.7),
		Color(0.5, 0.9, 0.4),
		Color(0.2, 0.7, 0.8),
		Color(0.9, 0.7, 0.2),
	]
	for i in range(30):
		var clr: Color = colors[randi_range(0, colors.size() - 1)]
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = clr
		mat.emission_enabled = true
		mat.emission = clr
		mat.emission_energy_multiplier = 6.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sph: SphereMesh = SphereMesh.new()
		var r: float = 0.02 + randf() * 0.04
		sph.radius = r
		sph.height = r * 2.0
		mi.mesh = sph
		mi.material_override = mat
		var theta: float = randf() * 6.28318
		var dist: float = 1.5 + randf() * 4.5
		mi.position = Vector3(
			sin(theta) * dist,
			0.5 + randf() * 4.0,
			cos(theta) * dist
		)
		add_child(mi)
		_fireflies.append(mi)
		_firefly_angles.append(theta)

func _build_spores() -> void:
	var spore_mat: StandardMaterial3D = StandardMaterial3D.new()
	spore_mat.albedo_color = Color(0.08, 0.30, 0.25, 0.6)
	spore_mat.emission_enabled = true
	spore_mat.emission = Color(0.10, 0.40, 0.35)
	spore_mat.emission_energy_multiplier = 2.0
	spore_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spore_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(15):
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sph: SphereMesh = SphereMesh.new()
		var r: float = 0.04 + randf() * 0.06
		sph.radius = r
		sph.height = r * 2.0
		mi.mesh = sph
		mi.material_override = spore_mat
		var theta: float = randf() * 6.28318
		var dist: float = 0.8 + randf() * 2.0
		mi.position = Vector3(
			sin(theta) * dist,
			0.3 + randf() * 3.0,
			cos(theta) * dist
		)
		add_child(mi)
		_spores.append(mi)
		_spore_angles.append(theta)

func _build_motes() -> void:
	var mote_clrs: Array[Color] = [
		Color(1.0, 0.95, 0.70),
		Color(0.90, 0.95, 1.0),
		Color(1.0, 0.85, 0.60),
	]
	for i in range(20):
		var clr: Color = mote_clrs[randi_range(0, mote_clrs.size() - 1)]
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = clr
		mat.emission_enabled = true
		mat.emission = clr
		mat.emission_energy_multiplier = 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sph: SphereMesh = SphereMesh.new()
		var r: float = 0.025 + randf() * 0.035
		sph.radius = r
		sph.height = r * 2.0
		mi.mesh = sph
		mi.material_override = mat
		var theta: float = randf() * 6.28318
		var dist: float = 1.0 + randf() * 3.5
		mi.position = Vector3(
			sin(theta) * dist,
			0.8 + randf() * 3.5,
			cos(theta) * dist
		)
		add_child(mi)
		_motes.append(mi)
		_mote_angles.append(theta)

func _build_area() -> void:
	var area: Area3D = Area3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var cs: BoxShape3D = BoxShape3D.new()
	cs.size = Vector3(FW * VOXEL + 1.5, FH * VOXEL + 0.5, 2.0)
	col.shape = cs
	col.position = Vector3(0.0, FH * VOXEL * 0.5, 0.0)
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(b: Node) -> void:
	if b is CharacterBase and b._is_player:
		_player_on = true

func _on_body_exited(b: Node) -> void:
	if b is CharacterBase and b._is_player:
		_player_on = false

func is_player_on() -> bool:
	return _player_on

func _process(delta: float) -> void:
	_age += delta
	if _is_twilight():
		_light.light_energy = 3.0 + sin(_age * 1.0) * 0.8
		_light.light_color = Color(
			0.10 + sin(_age * 0.5) * 0.05,
			0.50 + sin(_age * 0.8) * 0.10,
			0.45 + sin(_age * 0.6) * 0.10,
		)
	else:
		_light.light_energy = 1.2 + sin(_age * 0.6) * 0.3
		_light.light_color = Color(
			1.0,
			0.90 + sin(_age * 0.4) * 0.05,
			0.70 + sin(_age * 0.5) * 0.05,
		)

	for i in range(_fireflies.size()):
		var a: float = _firefly_angles[i] + _age * (0.12 + float(i) * 0.008)
		var d: float = 1.5 + sin(_age * 0.35 + float(i)) * 1.5
		var bob: float = sin(_age * 1.3 + float(i) * 3.0) * 0.5
		var scale_f: float = 0.5 + sin(_age * 2.5 + float(i) * 1.5) * 0.5
		_fireflies[i].position = Vector3(
			cos(a) * d,
			0.5 + bob + sin(_age * 0.6 + float(i)) * 1.0,
			sin(a) * d
		)
		_fireflies[i].scale = Vector3(scale_f, scale_f, scale_f)

	for i in range(_spores.size()):
		var a: float = _spore_angles[i] + _age * (0.05 + float(i) * 0.005)
		var dd: float = 0.8 + sin(_age * 0.2 + float(i)) * 1.0
		var drift_y: float = sin(_age * 0.5 + float(i)) * 0.6
		_spores[i].position = Vector3(
			cos(a) * dd,
			0.3 + drift_y + _age * 0.05,
			sin(a) * dd
		)
		if _spores[i].position.y > 5.0:
			_spores[i].position.y = 0.3

	for i in range(_motes.size()):
		var a: float = _mote_angles[i] + _age * (0.08 + float(i) * 0.006)
		var d: float = 1.0 + sin(_age * 0.25 + float(i)) * 1.2
		var bob: float = sin(_age * 0.9 + float(i) * 2.0) * 0.6
		var scale_f: float = 0.6 + sin(_age * 1.8 + float(i) * 1.2) * 0.4
		_motes[i].position = Vector3(
			cos(a) * d,
			0.8 + bob + sin(_age * 0.5 + float(i)) * 0.8,
			sin(a) * d
		)
		_motes[i].scale = Vector3(scale_f, scale_f, scale_f)
