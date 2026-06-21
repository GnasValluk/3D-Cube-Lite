## warrior/warrior_mesh.gd
## Procedural mesh cho Warrior tay không với nắm đấm lớn.

class_name WarriorMesh

var rig: Node3D
var spine: Node3D
var chest: Node3D
var head: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var upper_arm_l: Node3D
var upper_arm_r: Node3D
var lower_arm_l: Node3D
var lower_arm_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var hip: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var cape: Array[Node3D] = []
var cloth_panels: Array[Node3D] = []
var back_spikes: Array[Node3D] = []

var _m_armor: StandardMaterial3D
var _m_trim: StandardMaterial3D
var _m_glow: StandardMaterial3D
var _m_cloth: StandardMaterial3D
var _m_dark: StandardMaterial3D
var _m_edge: StandardMaterial3D

func A() -> StandardMaterial3D: return _m_armor
func T() -> StandardMaterial3D: return _m_trim
func G() -> StandardMaterial3D: return _m_glow
func C() -> StandardMaterial3D: return _m_cloth
func D() -> StandardMaterial3D: return _m_dark
func E() -> StandardMaterial3D: return _m_edge

func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = MeshBuilder.pivot(root, Vector3(0, 0.08, 0))
	rig.name = "WarriorRig"
	_build_torso()
	_build_head()
	_build_arms()
	_build_legs()
	_build_cape()

func _make_materials() -> void:
	_m_armor = MeshBuilder.emit_mat(Color(0.10, 0.12, 0.20), Color(0.18, 0.26, 0.44), 1.2)
	_m_trim = MeshBuilder.emit_mat(Color(0.68, 0.72, 0.90), Color(0.55, 0.78, 1.00), 2.0)
	_m_glow = MeshBuilder.emit_mat(Color(0.15, 0.80, 1.00), Color(0.08, 0.92, 1.00), 4.0)
	_m_cloth = MeshBuilder.emit_mat(Color(0.38, 0.04, 0.08), Color(0.75, 0.06, 0.16), 1.6)
	_m_dark = MeshBuilder.emit_mat(Color(0.04, 0.04, 0.08), Color(0.08, 0.08, 0.16), 0.8)
	_m_edge = MeshBuilder.emit_mat(Color(0.20, 0.95, 1.00), Color(0.12, 1.00, 1.00), 5.0)

func _build_torso() -> void:
	spine = MeshBuilder.pivot(rig, Vector3(0, 0.82, 0.02))
	chest = MeshBuilder.pivot(spine, Vector3(0, 0.10, 0.06))
	hip = MeshBuilder.pivot(rig, Vector3(0, 0.74, -0.06))

	MeshBuilder.box(spine, Vector3(0, 0.02, -0.04), Vector3(0.62, 0.44, 0.40), A())
	MeshBuilder.box(spine, Vector3(0, 0.16, 0.06), Vector3(0.74, 0.46, 0.54), A())
	MeshBuilder.box(spine, Vector3(0, -0.12, -0.08), Vector3(0.52, 0.16, 0.30), D())
	MeshBuilder.box(spine, Vector3(0, 0.06, -0.22), Vector3(0.42, 0.34, 0.14), T())
	MeshBuilder.box(spine, Vector3(0, 0.18, 0.22), Vector3(0.58, 0.28, 0.18), T())
	MeshBuilder.box(spine, Vector3(0, 0.20, 0.00), Vector3(0.18, 0.24, 0.12), G())
	MeshBuilder.box(spine, Vector3(0, 0.20, 0.08), Vector3(0.10, 0.14, 0.10), E())
	for i in range(4):
		MeshBuilder.box(spine, Vector3(0, -0.02 + float(i) * 0.09, 0.24 + float(i) * 0.02), Vector3(0.10, 0.06, 0.04), E())
	for i in range(3):
		var sx: float = 0.28 + float(i) * 0.08
		MeshBuilder.box(spine, Vector3(-sx, 0.18 + float(i) * 0.04, 0.02), Vector3(0.06, 0.14, 0.24), T())
		MeshBuilder.box(spine, Vector3( sx, 0.18 + float(i) * 0.04, 0.02), Vector3(0.06, 0.14, 0.24), T())

	MeshBuilder.box(chest, Vector3(0, 0.00, 0.12), Vector3(0.82, 0.34, 0.38), A())
	MeshBuilder.box(chest, Vector3(0, 0.14, 0.16), Vector3(0.62, 0.18, 0.20), T())
	MeshBuilder.box(chest, Vector3(0, 0.06, 0.28), Vector3(0.24, 0.14, 0.12), G())
	MeshBuilder.box(chest, Vector3(0, -0.12, 0.12), Vector3(0.44, 0.12, 0.26), D())

	MeshBuilder.box(hip, Vector3(0, 0.00, 0.06), Vector3(0.56, 0.18, 0.28), A())
	MeshBuilder.box(hip, Vector3(0, 0.08, 0.12), Vector3(0.34, 0.08, 0.16), T())
	for i in range(3):
		var panel: Node3D = MeshBuilder.pivot(hip, Vector3(-0.22 + float(i) * 0.22, -0.12, 0.18))
		MeshBuilder.box(panel, Vector3(0, -0.18, 0), Vector3(0.14, 0.34, 0.06), C())
		MeshBuilder.box(panel, Vector3(0, -0.04, 0.02), Vector3(0.16, 0.10, 0.08), T())
		cloth_panels.append(panel)

	MeshBuilder.box(rig, Vector3(0, 1.18, -0.16), Vector3(0.22, 0.26, 0.10), T())
	for i in range(5):
		var spike: Node3D = MeshBuilder.pivot(rig, Vector3(0, 1.00 + float(i) * 0.08, -0.16 - float(i) * 0.05))
		MeshBuilder.box(spike, Vector3(0, 0.06, 0), Vector3(0.05, 0.14, 0.05), T())
		MeshBuilder.box(spike, Vector3(0, 0.16, 0), Vector3(0.025, 0.10, 0.025), E())
		back_spikes.append(spike)

func _build_head() -> void:
	head = MeshBuilder.pivot(chest, Vector3(0, 0.28, 0.12))
	MeshBuilder.box(head, Vector3(0, 0.02, 0.02), Vector3(0.30, 0.28, 0.30), A())
	MeshBuilder.box(head, Vector3(0, 0.12, 0.08), Vector3(0.18, 0.10, 0.16), T())
	MeshBuilder.box(head, Vector3(0, -0.02, 0.18), Vector3(0.16, 0.08, 0.10), T())
	MeshBuilder.box(head, Vector3(0, -0.02, 0.22), Vector3(0.10, 0.05, 0.06), G())
	MeshBuilder.box(head, Vector3(-0.10, 0.03, 0.12), Vector3(0.04, 0.05, 0.03), G())
	MeshBuilder.box(head, Vector3( 0.10, 0.03, 0.12), Vector3(0.04, 0.05, 0.03), G())
	MeshBuilder.box(head, Vector3(0, 0.26, 0.00), Vector3(0.08, 0.22, 0.08), T())
	MeshBuilder.box(head, Vector3(0, 0.42, -0.04), Vector3(0.05, 0.12, 0.05), E())
	MeshBuilder.box(head, Vector3(-0.18, 0.16, 0.02), Vector3(0.10, 0.18, 0.08), T())
	MeshBuilder.box(head, Vector3( 0.18, 0.16, 0.02), Vector3(0.10, 0.18, 0.08), T())
	MeshBuilder.box(head, Vector3(-0.24, 0.30, -0.04), Vector3(0.06, 0.14, 0.06), E())
	MeshBuilder.box(head, Vector3( 0.24, 0.30, -0.04), Vector3(0.06, 0.14, 0.06), E())

func _build_arms() -> void:
	shoulder_l = MeshBuilder.pivot(chest, Vector3(-0.48, 0.14, 0.10))
	shoulder_r = MeshBuilder.pivot(chest, Vector3( 0.48, 0.14, 0.10))
	var left_arm: Array[Node3D] = _build_arm(shoulder_l, -1.0)
	var right_arm: Array[Node3D] = _build_arm(shoulder_r, 1.0)
	upper_arm_l = left_arm[0]
	lower_arm_l = left_arm[1]
	hand_l = left_arm[2]
	upper_arm_r = right_arm[0]
	lower_arm_r = right_arm[1]
	hand_r = right_arm[2]

func _build_arm(shoulder: Node3D, side: float) -> Array[Node3D]:
	MeshBuilder.sphere(shoulder, Vector3(0, 0, 0), 0.16, T())
	MeshBuilder.box(shoulder, Vector3(side * 0.10, -0.02, 0.00), Vector3(0.28, 0.24, 0.38), A())
	MeshBuilder.box(shoulder, Vector3(side * 0.04, 0.10, 0.04), Vector3(0.18, 0.12, 0.22), E())
	MeshBuilder.box(shoulder, Vector3(side * 0.20, -0.10, 0.12), Vector3(0.10, 0.16, 0.18), T())

	var upper: Node3D = MeshBuilder.pivot(shoulder, Vector3(side * 0.22, -0.10, 0.02))
	MeshBuilder.box(upper, Vector3(side * 0.08, -0.16, 0.00), Vector3(0.22, 0.34, 0.20), A())
	MeshBuilder.box(upper, Vector3(side * 0.10, -0.02, 0.00), Vector3(0.12, 0.16, 0.12), G())
	MeshBuilder.box(upper, Vector3(side * 0.16, -0.14, 0.10), Vector3(0.06, 0.16, 0.12), T())

	var lower: Node3D = MeshBuilder.pivot(upper, Vector3(side * 0.10, -0.32, 0.00))
	MeshBuilder.box(lower, Vector3(side * 0.08, -0.18, 0.00), Vector3(0.20, 0.36, 0.18), A())
	MeshBuilder.box(lower, Vector3(side * 0.08, -0.02, 0.00), Vector3(0.12, 0.14, 0.12), T())
	MeshBuilder.box(lower, Vector3(side * 0.12, -0.18, 0.10), Vector3(0.06, 0.18, 0.12), E())
	MeshBuilder.box(lower, Vector3(side * 0.10, -0.28, 0.02), Vector3(0.18, 0.08, 0.16), G())

	var hand: Node3D = MeshBuilder.pivot(lower, Vector3(side * 0.08, -0.34, 0.00))
	MeshBuilder.box(hand, Vector3(side * 0.04, -0.02, 0.05), Vector3(0.20, 0.18, 0.20), D())
	MeshBuilder.box(hand, Vector3(side * 0.05, 0.02, 0.08), Vector3(0.16, 0.10, 0.12), G())
	MeshBuilder.box(hand, Vector3(side * 0.10, -0.02, -0.02), Vector3(0.08, 0.14, 0.10), T())
	for i in range(4):
		var knuckle_x: float = side * (-0.07 + float(i) * 0.045)
		MeshBuilder.box(hand, Vector3(knuckle_x, 0.00, 0.20), Vector3(0.05, 0.08, 0.10), T())
		MeshBuilder.box(hand, Vector3(knuckle_x, 0.02, 0.27), Vector3(0.03, 0.04, 0.06), E())
	MeshBuilder.box(hand, Vector3(side * 0.00, -0.10, 0.08), Vector3(0.18, 0.05, 0.12), T())

	return [upper, lower, hand]

func _build_legs() -> void:
	thigh_l = MeshBuilder.pivot(hip, Vector3(-0.20, -0.02, 0.02))
	thigh_r = MeshBuilder.pivot(hip, Vector3( 0.20, -0.02, 0.02))
	var left_leg: Array[Node3D] = _build_leg(thigh_l, -1.0)
	var right_leg: Array[Node3D] = _build_leg(thigh_r, 1.0)
	shin_l = left_leg[0]
	foot_l = left_leg[1]
	shin_r = right_leg[0]
	foot_r = right_leg[1]

func _build_leg(thigh: Node3D, side: float) -> Array[Node3D]:
	MeshBuilder.box(thigh, Vector3(0, -0.22, 0.00), Vector3(0.24, 0.42, 0.24), A())
	MeshBuilder.box(thigh, Vector3(0, -0.04, 0.04), Vector3(0.16, 0.14, 0.16), T())
	MeshBuilder.box(thigh, Vector3(side * 0.10, -0.22, 0.10), Vector3(0.06, 0.20, 0.14), E())

	var shin: Node3D = MeshBuilder.pivot(thigh, Vector3(0, -0.42, 0.02))
	MeshBuilder.box(shin, Vector3(0, -0.22, -0.02), Vector3(0.20, 0.42, 0.18), A())
	MeshBuilder.box(shin, Vector3(0, -0.06, 0.00), Vector3(0.12, 0.16, 0.10), G())
	MeshBuilder.box(shin, Vector3(side * 0.08, -0.24, 0.08), Vector3(0.05, 0.20, 0.10), T())

	var foot: Node3D = MeshBuilder.pivot(shin, Vector3(0, -0.42, -0.02))
	MeshBuilder.box(foot, Vector3(0, -0.04, 0.10), Vector3(0.26, 0.12, 0.34), A())
	MeshBuilder.box(foot, Vector3(0, 0.04, 0.06), Vector3(0.20, 0.08, 0.16), T())
	MeshBuilder.box(foot, Vector3(0, -0.06, 0.20), Vector3(0.18, 0.06, 0.16), D())
	for i in range(3):
		var tx: float = (-0.08 + float(i) * 0.08) * side
		MeshBuilder.box(foot, Vector3(tx, -0.05, 0.28 + float(i) * 0.02), Vector3(0.05, 0.04, 0.12), T())
		MeshBuilder.box(foot, Vector3(tx, -0.06, 0.36 + float(i) * 0.02), Vector3(0.03, 0.03, 0.08), E())
	return [shin, foot]

func _build_cape() -> void:
	cape.clear()
	for i in range(4):
		var root_x: float = -0.24 + float(i) * 0.16
		var root_seg: Node3D = MeshBuilder.pivot(spine, Vector3(root_x, 0.18, -0.28))
		root_seg.rotation.x = 0.18
		MeshBuilder.box(root_seg, Vector3(0, -0.18, -0.04), Vector3(0.14, 0.40, 0.08), C())
		var mid_seg: Node3D = MeshBuilder.pivot(root_seg, Vector3(0, -0.34, -0.06))
		MeshBuilder.box(mid_seg, Vector3(0, -0.22, -0.04), Vector3(0.12, 0.46, 0.08), C())
		var tip_seg: Node3D = MeshBuilder.pivot(mid_seg, Vector3(0, -0.40, -0.08))
		MeshBuilder.box(tip_seg, Vector3(0, -0.22, -0.02), Vector3(0.10, 0.42, 0.08), C())
		MeshBuilder.box(root_seg, Vector3(0, -0.02, 0.00), Vector3(0.16, 0.08, 0.10), T())
		cape.append(root_seg)
	for i in range(3):
		MeshBuilder.box(spine, Vector3(-0.20 + float(i) * 0.20, -0.02, -0.22), Vector3(0.14, 0.10, 0.08), T())
