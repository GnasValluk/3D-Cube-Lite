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

# ── Minecraft skin box (ArrayMesh with per-face UV) ──────────────────────
static func skin_box(p: Node3D, pos: Vector3, sz: Vector3, mat: Material,
		front: Vector4, back: Vector4, right: Vector4, left: Vector4, top: Vector4, bottom: Vector4) -> MeshInstance3D:
	"""
	Build a box from 6 faces with explicit UV mapping for Minecraft skin textures.
	Each Vector4 is (pixel_x, pixel_y, pixel_w, pixel_h) on a 64×64 skin texture.
	Vertex order: CCW from outside for each face.
	"""
	var tw := 64.0
	var th := 64.0
	var hw := sz.x * 0.5
	var hh := sz.y * 0.5
	var hd := sz.z * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Helper: add one face (4 corners in BL→BR→TR→TL order, each face's own local UV space).
	# Triangles (0,1,2) and (0,2,3) must be CCW when looking from outside.
	var add_face := func(c0: Vector3, c1: Vector3, c2: Vector3, c3: Vector3,
		u0: Vector2, u1: Vector2, u2: Vector2, u3: Vector2):
		var n := (c1 - c0).cross(c2 - c0).normalized()
		for v in range(6):
			var vert := c0; var uv := u0
			if v == 1: vert = c1; uv = u1
			if v == 2 or v == 5: vert = c2; uv = u2
			if v == 3: vert = c0; uv = u0
			if v == 4: vert = c3; uv = u3
			st.set_normal(n)
			st.set_uv(uv / Vector2(tw, th))
			st.add_vertex(vert)

	# Each face: corners in BL→BR→TR→TL order
	var F := front
	add_face.call(
		Vector3(-hw, -hh, +hd), Vector3(+hw, -hh, +hd), Vector3(+hw, +hh, +hd), Vector3(-hw, +hh, +hd),
		Vector2(F.x, F.y+F.w), Vector2(F.x+F.z, F.y+F.w), Vector2(F.x+F.z, F.y), Vector2(F.x, F.y))

	var B := back
	add_face.call(
		Vector3(+hw, -hh, -hd), Vector3(-hw, -hh, -hd), Vector3(-hw, +hh, -hd), Vector3(+hw, +hh, -hd),
		Vector2(B.x, B.y+B.w), Vector2(B.x+B.z, B.y+B.w), Vector2(B.x+B.z, B.y), Vector2(B.x, B.y))

	# Right face: local BL = front-bottom (+hw,-hh,+hd), BR = back-bottom (+hw,-hh,-hd)
	var R := right
	add_face.call(
		Vector3(+hw, -hh, +hd), Vector3(+hw, -hh, -hd), Vector3(+hw, +hh, -hd), Vector3(+hw, +hh, +hd),
		Vector2(R.x, R.y+R.w), Vector2(R.x+R.z, R.y+R.w), Vector2(R.x+R.z, R.y), Vector2(R.x, R.y))

	# Left face: local BL = back-bottom (-hw,-hh,-hd), BR = front-bottom (-hw,-hh,+hd)
	var L := left
	add_face.call(
		Vector3(-hw, -hh, -hd), Vector3(-hw, -hh, +hd), Vector3(-hw, +hh, +hd), Vector3(-hw, +hh, -hd),
		Vector2(L.x, L.y+L.w), Vector2(L.x+L.z, L.y+L.w), Vector2(L.x+L.z, L.y), Vector2(L.x, L.y))

	var T := top
	add_face.call(
		Vector3(-hw, +hh, +hd), Vector3(+hw, +hh, +hd), Vector3(+hw, +hh, -hd), Vector3(-hw, +hh, -hd),
		Vector2(T.x, T.y+T.w), Vector2(T.x+T.z, T.y+T.w), Vector2(T.x+T.z, T.y), Vector2(T.x, T.y))

	var Bo := bottom
	add_face.call(
		Vector3(-hw, -hh, -hd), Vector3(+hw, -hh, -hd), Vector3(+hw, -hh, +hd), Vector3(-hw, -hh, +hd),
		Vector2(Bo.x, Bo.y+Bo.w), Vector2(Bo.x+Bo.z, Bo.y+Bo.w), Vector2(Bo.x+Bo.z, Bo.y), Vector2(Bo.x, Bo.y))

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = pos
	mi.material_override = mat
	p.add_child(mi)
	return mi
