## world_generator.gd
## 3 biome – ranh giới mượt bằng domain-warped noise
## Sàn patch nhỏ nhưng màu lấy từ noise tần số thấp → vùng lớn, cạnh organic

extends Node3D

@export var ground_size:     float = 130.0
@export var ground_thick:    float = 0.5
@export var patch_res:       int   = 60      # Tăng độ phân giải để voxel dày hơn
@export var tree_count:      int   = 220     # Tăng mật độ cây
@export var grass_count:     int   = 500     # Tăng mật độ cỏ
@export var featured_chance: float = 0.06
@export var spawn_seed:      int   = 42

# ── 3 Biome palette – bỏ DARK, giữ MID + LIGHT, thêm GREEN ──────────────────
# MID    – teal trung bình
# LIGHT  – teal sáng
# GREEN  – xanh lá thuần

const C_GND: Array = [
	Color(0.05, 0.18, 0.16),   # 0 MID    – teal tối
	Color(0.10, 0.32, 0.26),   # 1 LIGHT  – teal trung bình
	Color(0.04, 0.20, 0.28),   # 2 AQUA   – blue-teal lạnh
]
const C_FOL: Array = [
	Color(0.15, 0.90, 0.55),   # 0 MID    – neon xanh lá
	Color(0.25, 1.00, 0.70),   # 1 LIGHT  – neon xanh sáng
	Color(0.10, 0.70, 0.90),   # 2 AQUA   – neon xanh dương
]
const C_GRS: Array = [
	Color(0.10, 0.55, 0.35),   # 0 MID
	Color(0.18, 0.70, 0.45),   # 1 LIGHT
	Color(0.06, 0.50, 0.60),   # 2 AQUA
]
const C_TRUNK       := Color(0.04, 0.12, 0.10)
const C_FEAT_FOL    := Color(0.80, 1.00, 0.95)
const C_FEAT_EMIT   := Color(0.35, 1.00, 0.85)
const C_FEAT_TRUNK  := Color(0.25, 0.80, 0.65)

const C_FOL_EMIT: Array = [
	Color(0.10, 0.70, 0.40),   # 0 MID
	Color(0.18, 0.80, 0.50),   # 1 LIGHT
	Color(0.06, 0.50, 0.70),   # 2 AQUA
]
const C_GRS_EMIT: Array = [
	Color(0.06, 0.35, 0.22),   # 0 MID
	Color(0.10, 0.45, 0.28),   # 1 LIGHT
	Color(0.04, 0.30, 0.40),   # 2 AQUA
]

# ── Noise layers ──────────────────────────────────────────────────────────────
var _noise_biome: FastNoiseLite   # Tần số thấp → vùng lớn
var _noise_warp:  FastNoiseLite   # Dùng làm domain warp → cạnh cong organic

var _mat_trunk:       StandardMaterial3D
var _mat_trunk_feat:  StandardMaterial3D
var _mat_gnd:  Array[StandardMaterial3D] = []
var _mat_fol:  Array[StandardMaterial3D] = []
var _mat_grs:  Array[StandardMaterial3D] = []
var _mat_fol_neon: Array[StandardMaterial3D] = []
var _mat_grs_neon: Array[StandardMaterial3D] = []


func _ready() -> void:
	# Biome noise – tần số RẤT thấp để vùng thật lớn, mượt
	_noise_biome = FastNoiseLite.new()
	_noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_biome.seed       = spawn_seed
	_noise_biome.frequency  = 0.008   # <-- thấp = vùng to

	# Warp noise – tần số cao hơn một chút để làm cong cạnh
	_noise_warp = FastNoiseLite.new()
	_noise_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_warp.seed       = spawn_seed + 99
	_noise_warp.frequency  = 0.022

	_mat_trunk      = _flat(C_TRUNK)
	_mat_trunk_feat = _flat_emit(C_FEAT_TRUNK, C_FEAT_EMIT, 1.2)
	for i in range(3):
		_mat_gnd.append(_flat(C_GND[i]))
		_mat_fol.append(_flat(C_FOL[i]))
		_mat_grs.append(_flat(C_GRS[i]))
		_mat_fol_neon.append(_flat_emit(C_FOL[i], C_FOL_EMIT[i], 1.5))
		_mat_grs_neon.append(_flat_emit(C_GRS[i], C_GRS_EMIT[i], 0.8))

	generate()


# ── Helpers ───────────────────────────────────────────────────────────────────
func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = 1.0
	m.metallic_specular = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _flat_emit(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := _flat(albedo)
	m.emission_enabled = true; m.emission = emit
	m.emission_energy_multiplier = energy
	return m

## Domain-warped biome index tại (wx, wz)
## Warp làm cho ranh giới bị uốn cong tự nhiên thay vì thẳng
func _biome_at(wx: float, wz: float) -> int:
	var wx_off: float = _noise_warp.get_noise_2d(wx,        wz + 100.0) * 18.0
	var wz_off: float = _noise_warp.get_noise_2d(wx + 100.0, wz)        * 18.0
	var n: float = (_noise_biome.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5
	# 3 vùng đều nhau: MID / LIGHT / GREEN
	if n < 0.33:   return 0   # MID
	elif n < 0.66: return 1   # LIGHT
	else:          return 2   # GREEN


# ── Generate ──────────────────────────────────────────────────────────────────
func generate() -> void:
	for c in get_children():
		c.queue_free()
	_spawn_ground()

	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed + 1

	for _i in range(grass_count):
		var px: float = rng.randf_range(-ground_size * 0.47, ground_size * 0.47)
		var pz: float = rng.randf_range(-ground_size * 0.47, ground_size * 0.47)
		_spawn_grass_patch(Vector3(px, 0.0, pz), _biome_at(px, pz), rng)

	for _i in range(tree_count):
		var px: float  = rng.randf_range(-ground_size * 0.46, ground_size * 0.46)
		var pz: float  = rng.randf_range(-ground_size * 0.46, ground_size * 0.46)
		var b:  int    = _biome_at(px, pz)
		var feat: bool = rng.randf() < featured_chance
		var sf:   float = rng.randf_range(0.55, 1.40)
		_spawn_tree(Vector3(px, 0.0, pz), b, feat, sf, rng)

# ── Sàn: patch grid, màu theo biome noise ────────────────────────────────────
func _spawn_ground() -> void:
	var sb := StaticBody3D.new()
	sb.position = Vector3(0.0, -ground_thick * 0.5, 0.0)
	add_child(sb)
	var col := CollisionShape3D.new()
	var cs  := BoxShape3D.new()
	cs.size  = Vector3(ground_size, ground_thick, ground_size)
	col.shape = cs; sb.add_child(col)

	var ps: float = ground_size / float(patch_res)
	var half: float = ground_size * 0.5
	for xi in range(patch_res):
		for zi in range(patch_res):
			var wx: float = -half + (float(xi) + 0.5) * ps
			var wz: float = -half + (float(zi) + 0.5) * ps
			var b:  int   = _biome_at(wx, wz)
			var mi  := MeshInstance3D.new()
			var msh := BoxMesh.new()
			msh.size = Vector3(ps, ground_thick, ps)
			mi.mesh  = msh; mi.position = Vector3(wx, 0.0, wz)
			mi.material_override = _mat_gnd[b]
			sb.add_child(mi)


# ── Grass patch ───────────────────────────────────────────────────────────────
func _spawn_grass_patch(base: Vector3, b: int, rng: RandomNumberGenerator) -> void:
	var mat := _mat_grs_neon[b]
	for _i in range(rng.randi_range(2, 5)):
		var ox: float = rng.randf_range(-0.28, 0.28)
		var oz: float = rng.randf_range(-0.28, 0.28)
		if rng.randf() < 0.6:
			# Blade đứng
			var h: float = rng.randf_range(0.12, 0.28)
			var mi := MeshInstance3D.new()
			var msh := BoxMesh.new()
			msh.size = Vector3(0.05, h, 0.03)
			mi.mesh  = msh
			mi.position = base + Vector3(ox, h * 0.5, oz)
			mi.rotation_degrees.z = rng.randf_range(-20.0, 20.0)
			mi.material_override  = mat
			add_child(mi)
		else:
			# Tuft tròn dẹt
			var r: float = rng.randf_range(0.06, 0.14)
			var mi := MeshInstance3D.new()
			var msh := SphereMesh.new()
			msh.radius = r; msh.height = r * 2.0
			msh.radial_segments = 6; msh.rings = 4
			mi.mesh  = msh; mi.scale = Vector3(1.0, 0.4, 1.0)
			mi.position = base + Vector3(ox, r * 0.2, oz)
			mi.material_override = mat
			add_child(mi)


# ── Cây ───────────────────────────────────────────────────────────────────────
func _spawn_tree(base: Vector3, b: int, featured: bool,
				 sf: float, rng: RandomNumberGenerator) -> void:
	var fol_mat := _flat_emit(C_FEAT_FOL, C_FEAT_EMIT, 2.5) if featured \
				   else _mat_fol_neon[b]
	var trk_mat := _mat_trunk_feat if featured else _mat_trunk

	var trunk_h: float = rng.randf_range(0.9, 1.9) * sf
	_add_cylinder(base + Vector3(0, trunk_h * 0.5, 0), 0.07 * sf, trunk_h, trk_mat)

	for i in range(rng.randi_range(2, 4)):
		var ay: float = deg_to_rad(float(i) * (360.0 / float(rng.randi_range(2,4)))
						+ rng.randf_range(-25.0, 25.0))
		var blen: float = rng.randf_range(0.35, 0.75) * sf
		var bh:   float = trunk_h * rng.randf_range(0.40, 0.82)
		var bdir  := Vector3(sin(ay), rng.randf_range(0.22, 0.48), cos(ay)).normalized()
		_add_cylinder_dir(base + Vector3(0, bh, 0) + bdir * blen * 0.5,
						  0.036 * sf, blen, bdir, trk_mat)
		var tip := base + Vector3(0, bh, 0) + bdir * blen
		var tr: float = rng.randf_range(0.20, 0.40) * sf
		_add_sphere(tip + Vector3(0, tr * 0.4, 0), tr, fol_mat)

	for k in range(rng.randi_range(3, 6)):
		var ang: float = deg_to_rad(float(k) * 60.0 + rng.randf_range(0.0, 40.0))
		var sp:  float = rng.randf_range(0.0, 0.28) * sf
		var cr:  float = rng.randf_range(0.26, 0.56) * sf
		_add_sphere(base + Vector3(sin(ang) * sp,
					trunk_h + cr * 0.58 + rng.randf_range(-0.08, 0.24) * sf,
					cos(ang) * sp), cr, fol_mat)

	if featured:
		var lt := OmniLight3D.new()
		lt.position    = base + Vector3(0.0, trunk_h * 0.85, 0.0)
		lt.light_color  = Color(0.35, 1.0, 0.82)
		lt.light_energy = 1.5; lt.omni_range = 5.5
		add_child(lt)


# ── Mesh helpers ──────────────────────────────────────────────────────────────
func _add_sphere(pos: Vector3, r: float, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var msh := SphereMesh.new()
	msh.radius = r; msh.height = r * 2.0
	msh.radial_segments = 10; msh.rings = 6
	mi.mesh = msh; mi.position = pos; mi.material_override = mat
	add_child(mi)

func _add_cylinder(pos: Vector3, r: float, h: float,
				   mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var msh := CylinderMesh.new()
	msh.top_radius = r * 0.65; msh.bottom_radius = r; msh.height = h
	mi.mesh = msh; mi.position = pos; mi.material_override = mat
	add_child(mi)

func _add_cylinder_dir(pos: Vector3, r: float, length: float,
					   dir: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var msh := CylinderMesh.new()
	msh.top_radius = r * 0.45; msh.bottom_radius = r; msh.height = length
	mi.mesh = msh; mi.position = pos; mi.material_override = mat
	var axis := Vector3.UP.cross(dir)
	if axis.length_squared() > 0.0001:
		mi.transform = mi.transform.rotated(axis.normalized(), Vector3.UP.angle_to(dir))
		mi.position  = pos
	add_child(mi)
