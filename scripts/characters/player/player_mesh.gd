class_name PlayerMesh

var rig: Node3D
var head: Node3D
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

var _m_skin: StandardMaterial3D
var _m_hair: StandardMaterial3D
var _m_shirt: StandardMaterial3D
var _m_pants: StandardMaterial3D
var _m_shoe: StandardMaterial3D
var _m_eye: StandardMaterial3D

func S() -> StandardMaterial3D: return _m_skin
func H() -> StandardMaterial3D: return _m_hair
func T() -> StandardMaterial3D: return _m_shirt
func P() -> StandardMaterial3D: return _m_pants
func K() -> StandardMaterial3D: return _m_shoe
func E() -> StandardMaterial3D: return _m_eye

func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = MeshBuilder.pivot(root, Vector3(0, 0.04, 0))
	rig.name = "PlayerRig"
	_build_body()
	_build_head()
	_build_arms()
	_build_legs()

func _make_materials() -> void:
	_m_skin  = MeshBuilder.emit_mat(Color(0.83, 0.65, 0.45), Color(0, 0, 0), 0.0)
	_m_hair  = MeshBuilder.emit_mat(Color(0.55, 0.41, 0.08), Color(0, 0, 0), 0.0)
	_m_shirt = MeshBuilder.emit_mat(Color(0.29, 0.56, 0.85), Color(0, 0, 0), 0.0)
	_m_pants = MeshBuilder.emit_mat(Color(0.23, 0.36, 0.60), Color(0, 0, 0), 0.0)
	_m_shoe  = MeshBuilder.emit_mat(Color(0.36, 0.36, 0.36), Color(0, 0, 0), 0.0)
	_m_eye   = MeshBuilder.emit_mat(Color(0.24, 0.24, 0.24), Color(0, 0, 0), 0.0)

func _build_body() -> void:
	body = MeshBuilder.pivot(rig, Vector3(0, 0.50, 0))
	MeshBuilder.box(body, Vector3(0, 0, 0), Vector3(0.34, 0.36, 0.18), T())
	MeshBuilder.box(body, Vector3(0, 0.20, 0), Vector3(0.20, 0.06, 0.14), S())

func _build_head() -> void:
	head = MeshBuilder.pivot(rig, Vector3(0, 0.80, 0))
	MeshBuilder.box(head, Vector3(0, 0, 0), Vector3(0.28, 0.28, 0.28), S())
	MeshBuilder.box(head, Vector3(0, 0.16, -0.02), Vector3(0.30, 0.08, 0.26), H())
	MeshBuilder.box(head, Vector3(-0.16, -0.02, -0.02), Vector3(0.06, 0.24, 0.22), H())
	MeshBuilder.box(head, Vector3(0.16, -0.02, -0.02), Vector3(0.06, 0.24, 0.22), H())
	MeshBuilder.box(head, Vector3(-0.08, 0.04, 0.14), Vector3(0.05, 0.05, 0.02), E())
	MeshBuilder.box(head, Vector3(0.08, 0.04, 0.14), Vector3(0.05, 0.05, 0.02), E())
	MeshBuilder.box(head, Vector3(0, -0.06, 0.14), Vector3(0.10, 0.02, 0.02), H())

func _build_arms() -> void:
	arm_l = MeshBuilder.pivot(rig, Vector3(-0.24, 0.50, 0))
	arm_r = MeshBuilder.pivot(rig, Vector3(0.24, 0.50, 0))
	MeshBuilder.box(arm_l, Vector3(0, -0.02, 0), Vector3(0.12, 0.30, 0.12), T())
	MeshBuilder.box(arm_l, Vector3(0, -0.20, 0), Vector3(0.10, 0.12, 0.10), S())
	MeshBuilder.box(arm_r, Vector3(0, -0.02, 0), Vector3(0.12, 0.30, 0.12), T())
	MeshBuilder.box(arm_r, Vector3(0, -0.20, 0), Vector3(0.10, 0.12, 0.10), S())

func _build_legs() -> void:
	leg_l = MeshBuilder.pivot(rig, Vector3(-0.10, 0.26, 0))
	leg_r = MeshBuilder.pivot(rig, Vector3(0.10, 0.26, 0))
	MeshBuilder.box(leg_l, Vector3(0, -0.02, 0), Vector3(0.12, 0.28, 0.12), P())
	MeshBuilder.box(leg_l, Vector3(0, -0.18, 0.02), Vector3(0.14, 0.08, 0.18), K())
	MeshBuilder.box(leg_r, Vector3(0, -0.02, 0), Vector3(0.12, 0.28, 0.12), P())
	MeshBuilder.box(leg_r, Vector3(0, -0.18, 0.02), Vector3(0.14, 0.08, 0.18), K())
