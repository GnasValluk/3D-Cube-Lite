class_name PlayerMesh

var rig: Node3D
var head: Node3D
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

var _tex: Texture2D

const PX: float = 1.0 / 32.0
const TW: float = 64.0

func build(root: CharacterBody3D) -> void:
	_load_skin()
	rig = MeshBuilder.pivot(root, Vector3(0, 0.04, 0))
	rig.name = "PlayerRig"
	_build_head()
	_build_body()
	_build_arm_r()
	_build_arm_l()
	_build_leg_r()
	_build_leg_l()

func _load_skin() -> void:
	_tex = load("res://assets/skin/purpleheart.png")

func _mat(reg: Vector4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_offset = Vector3(reg.x / TW, (reg.y + reg.w) / TW, 0)
	m.uv1_scale = Vector3(reg.z / TW, -reg.w / TW, 0)
	return m

func _face(parent: Node3D, pos: Vector3, ang: Vector3, sz: Vector2, reg: Vector4) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = sz
	mi.mesh = q
	mi.position = pos
	mi.rotation_degrees = ang
	mi.material_override = _mat(reg)
	parent.add_child(mi)

func _box(parent: Node3D, sz: Vector3, fn: Vector4, bk: Vector4, ri: Vector4, le: Vector4, to: Vector4, bo: Vector4) -> void:
	var sx := sz.x * 0.5
	var sy := sz.y * 0.5
	var szz := sz.z * 0.5
	_face(parent, Vector3(0, 0, szz), Vector3(0, 0, 0), Vector2(sz.x, sz.y), fn)
	_face(parent, Vector3(0, 0, -szz), Vector3(0, 180, 0), Vector2(sz.x, sz.y), bk)
	_face(parent, Vector3(sx, 0, 0), Vector3(0, 90, 0), Vector2(sz.z, sz.y), ri)
	_face(parent, Vector3(-sx, 0, 0), Vector3(0, -90, 0), Vector2(sz.z, sz.y), le)
	_face(parent, Vector3(0, sy, 0), Vector3(-90, 0, 0), Vector2(sz.x, sz.z), to)
	_face(parent, Vector3(0, -sy, 0), Vector3(90, 0, 0), Vector2(sz.x, sz.z), bo)

func _build_head() -> void:
	head = Node3D.new()
	head.position = Vector3(0, 28.0 * PX, 0)
	rig.add_child(head)
	var s := 8.0 * PX
	var os := 1.0 * PX
	_box(head, Vector3(s, s, s), _v4(8, 8, 8, 8), _v4(24, 8, 8, 8), _v4(0, 8, 8, 8), _v4(16, 8, 8, 8), _v4(8, 0, 8, 8), _v4(16, 0, 8, 8))
	_box(head, Vector3(s+os, s+os, s+os), _v4(40, 8, 8, 8), _v4(56, 8, 8, 8), _v4(32, 8, 8, 8), _v4(48, 8, 8, 8), _v4(40, 0, 8, 8), _v4(48, 0, 8, 8))

func _build_body() -> void:
	body = Node3D.new()
	body.position = Vector3(0, 18.0 * PX, 0)
	rig.add_child(body)
	_box(body, Vector3(8*PX, 12*PX, 4*PX), _v4(20, 20, 8, 12), _v4(32, 20, 8, 12), _v4(16, 20, 4, 12), _v4(28, 20, 4, 12), _v4(20, 16, 8, 4), _v4(28, 16, 8, 4))

func _build_arm_r() -> void:
	arm_r = Node3D.new()
	arm_r.position = Vector3(-5.0 * PX, 18.0 * PX, 0)
	rig.add_child(arm_r)
	_box(arm_r, Vector3(4*PX, 12*PX, 4*PX), _v4(44, 20, 4, 12), _v4(52, 20, 4, 12), _v4(40, 20, 4, 12), _v4(48, 20, 4, 12), _v4(44, 16, 4, 4), _v4(48, 16, 4, 4))

func _build_arm_l() -> void:
	arm_l = Node3D.new()
	arm_l.position = Vector3(5.0 * PX, 18.0 * PX, 0)
	rig.add_child(arm_l)
	_box(arm_l, Vector3(4*PX, 12*PX, 4*PX), _v4(36, 52, 4, 12), _v4(44, 52, 4, 12), _v4(32, 52, 4, 12), _v4(40, 52, 4, 12), _v4(36, 48, 4, 4), _v4(40, 48, 4, 4))

func _build_leg_r() -> void:
	leg_r = Node3D.new()
	leg_r.position = Vector3(-2.0 * PX, 6.0 * PX, 0)
	rig.add_child(leg_r)
	_box(leg_r, Vector3(4*PX, 12*PX, 4*PX), _v4(4, 20, 4, 12), _v4(12, 20, 4, 12), _v4(0, 20, 4, 12), _v4(8, 20, 4, 12), _v4(4, 16, 4, 4), _v4(8, 16, 4, 4))

func _build_leg_l() -> void:
	leg_l = Node3D.new()
	leg_l.position = Vector3(2.0 * PX, 6.0 * PX, 0)
	rig.add_child(leg_l)
	_box(leg_l, Vector3(4*PX, 12*PX, 4*PX), _v4(20, 52, 4, 12), _v4(28, 52, 4, 12), _v4(16, 52, 4, 12), _v4(24, 52, 4, 12), _v4(20, 48, 4, 4), _v4(24, 48, 4, 4))

func _v4(x: float, y: float, w: float, h: float) -> Vector4:
	return Vector4(x, y, w, h)
