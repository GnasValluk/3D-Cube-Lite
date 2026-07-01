## mesh_builder.gd
## Utility class chứa các primitive helper dùng chung cho mọi character.
## Dùng như static helper – không extends Node.
##
## Cách dùng:
##   var b := MeshBuilder.new(owner_node)
##   b.box(parent, pos, size, mat)

class_name MeshBuilder

var _owner: Node3D   # node cha để add_child vào

func _init(owner: Node3D) -> void:
	_owner = owner

# ── Materials ──────────────────────────────────────────────────────────────
static func emit_mat(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color             = albedo
	m.roughness                = 1.0
	m.metallic_specular        = 0.0
	m.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled         = true
	m.emission                 = emit
	m.emission_energy_multiplier = energy
	return m

# ── Primitives ─────────────────────────────────────────────────────────────
static func box(p: Node3D, pos: Vector3, sz: Vector3,
				mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size            = sz
	mi.mesh              = mesh
	mi.position          = pos
	mi.material_override = mat
	p.add_child(mi)
	return mi

static func sphere(p: Node3D, pos: Vector3, r: float,
				   mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius          = r
	mesh.height          = r * 2.0
	mesh.radial_segments = 10
	mesh.rings           = 6
	mi.mesh              = mesh
	mi.position          = pos
	mi.material_override = mat
	p.add_child(mi)
	return mi

static func cylinder(p: Node3D, pos: Vector3, r: float, h: float,
					 mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius      = r
	mesh.bottom_radius   = r
	mesh.height          = h
	mesh.radial_segments = 8
	mi.mesh              = mesh
	mi.position          = pos
	mi.material_override = mat
	p.add_child(mi)
	return mi

static func pivot(p: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	p.add_child(n)
	return n
