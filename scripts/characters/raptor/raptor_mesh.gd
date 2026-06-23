## raptor/raptor_mesh.gd
## Xây dựng toàn bộ mesh procedural của Raptor.
## Không extends Node – được tạo và gọi từ raptor_character.gd.

class_name RaptorMesh

# Refs trỏ về các pivot dùng cho animation
var rig:       Node3D
var neck:      Node3D
var snout_bot: MeshInstance3D
var arm_l:     Node3D
var arm_r:     Node3D
var thigh_l:   Node3D
var thigh_r:   Node3D
var shin_l:    Node3D
var shin_r:    Node3D
var foot_l:    Node3D
var foot_r:    Node3D
var tail:      Array[Node3D] = []

var _mat_body:  StandardMaterial3D
var _mat_dark:  StandardMaterial3D
var _mat_light: StandardMaterial3D
var _mat_eye:   StandardMaterial3D

# ── Entry point ───────────────────────────────────────────────────────────────
func build(root: CharacterBody3D) -> void:
	_make_materials()

	rig          = MeshBuilder.pivot(root, Vector3(0, 0.10, 0))
	rig.name     = "RaptorRig"

	_build_torso()
	_build_neck_head()
	_build_arms()
	_build_legs()
	_build_tail()

func _make_materials() -> void:
	_mat_body  = MeshBuilder.emit_mat(Color(0.85,0.72,0.12), Color(0.95,0.80,0.10), 1.8)
	_mat_dark  = MeshBuilder.emit_mat(Color(0.30,0.22,0.04), Color(0.35,0.25,0.04), 0.8)
	_mat_light = MeshBuilder.emit_mat(Color(0.95,0.95,0.98), Color(1.0,1.0,1.0), 3.0)
	_mat_eye   = MeshBuilder.emit_mat(Color(1.00,0.98,0.60), Color(1.00,0.95,0.40), 4.0)

# ── Torso ─────────────────────────────────────────────────────────────────────
func _build_torso() -> void:
	MeshBuilder.box(rig, Vector3(0, 0.62,  0.00), Vector3(0.44,0.30,0.70), _mat_body)
	MeshBuilder.box(rig, Vector3(0, 0.55,  0.28), Vector3(0.38,0.22,0.22), _mat_body)
	MeshBuilder.box(rig, Vector3(0, 0.60, -0.30), Vector3(0.40,0.26,0.28), _mat_body)
	for i in range(4):
		MeshBuilder.box(rig,
			Vector3(0, 0.78+float(i)*0.04, 0.18-float(i)*0.08),
			Vector3(0.06, 0.10+float(i)*0.02, 0.05), _mat_light)

# ── Neck + Head ───────────────────────────────────────────────────────────────
func _build_neck_head() -> void:
	neck = MeshBuilder.pivot(rig, Vector3(0, 0.74, 0.26))
	MeshBuilder.box(neck, Vector3(0, 0.10, 0.12), Vector3(0.20,0.22,0.30), _mat_body)
	MeshBuilder.box(neck, Vector3(0, 0.22, 0.26), Vector3(0.16,0.18,0.22), _mat_body)

	var hp: Node3D = MeshBuilder.pivot(neck, Vector3(0, 0.28, 0.32))
	MeshBuilder.box(hp, Vector3(0,  0.00, 0.04), Vector3(0.22,0.18,0.30), _mat_body)
	MeshBuilder.box(hp, Vector3(0, -0.02, 0.21), Vector3(0.16,0.08,0.18), _mat_body)
	snout_bot = MeshBuilder.box(hp, Vector3(0,-0.07,0.18), Vector3(0.14,0.06,0.16), _mat_body)

	for ti in range(3):
		MeshBuilder.box(hp,
			Vector3(-0.04+float(ti)*0.04, -0.10, 0.20+float(ti)*0.02),
			Vector3(0.02,0.04,0.02), _mat_light)
	MeshBuilder.box(hp, Vector3(0, 0.10,-0.04), Vector3(0.06,0.12,0.08), _mat_light)
	MeshBuilder.sphere(hp, Vector3(-0.10, 0.04, 0.10), 0.038, _mat_eye)
	MeshBuilder.sphere(hp, Vector3( 0.10, 0.04, 0.10), 0.038, _mat_eye)
	MeshBuilder.box(hp, Vector3(-0.10, 0.06, 0.13), Vector3(0.06,0.04,0.04), _mat_dark)
	MeshBuilder.box(hp, Vector3( 0.10, 0.06, 0.13), Vector3(0.06,0.04,0.04), _mat_dark)
	MeshBuilder.box(hp, Vector3(-0.05,-0.01, 0.27), Vector3(0.03,0.02,0.02), _mat_dark)
	MeshBuilder.box(hp, Vector3( 0.05,-0.01, 0.27), Vector3(0.03,0.02,0.02), _mat_dark)

# ── Arms ──────────────────────────────────────────────────────────────────────
func _build_arms() -> void:
	arm_l = MeshBuilder.pivot(rig, Vector3(-0.22, 0.64, 0.20))
	MeshBuilder.box(arm_l, Vector3(0,-0.08, 0.00), Vector3(0.08,0.16,0.07), _mat_body)
	MeshBuilder.box(arm_l, Vector3(0,-0.20, 0.02), Vector3(0.06,0.10,0.06), _mat_body)
	MeshBuilder.box(arm_l, Vector3(-0.02,-0.28,0.04), Vector3(0.04,0.06,0.03), _mat_dark)

	arm_r = MeshBuilder.pivot(rig, Vector3( 0.22, 0.64, 0.20))
	MeshBuilder.box(arm_r, Vector3(0,-0.08, 0.00), Vector3(0.08,0.16,0.07), _mat_body)
	MeshBuilder.box(arm_r, Vector3(0,-0.20, 0.02), Vector3(0.06,0.10,0.06), _mat_body)
	MeshBuilder.box(arm_r, Vector3( 0.02,-0.28,0.04), Vector3(0.04,0.06,0.03), _mat_dark)

# ── Legs ──────────────────────────────────────────────────────────────────────
func _build_legs() -> void:
	thigh_l = MeshBuilder.pivot(rig, Vector3(-0.16, 0.50,-0.10))
	var ll: Array[Node3D] = _build_leg(thigh_l, -1.0)
	shin_l = ll[0]; foot_l = ll[1]

	thigh_r = MeshBuilder.pivot(rig, Vector3( 0.16, 0.50,-0.10))
	var lr: Array[Node3D] = _build_leg(thigh_r,  1.0)
	shin_r = lr[0]; foot_r = lr[1]

func _build_leg(tp: Node3D, side: float) -> Array[Node3D]:
	MeshBuilder.box(tp, Vector3(0,-0.14, 0.04), Vector3(0.14,0.28,0.16), _mat_body)
	MeshBuilder.box(tp, Vector3(0,-0.30, 0.08), Vector3(0.10,0.08,0.10), _mat_light)

	var shin: Node3D = MeshBuilder.pivot(tp, Vector3(0,-0.30, 0.06))
	MeshBuilder.box(shin, Vector3(0,-0.12,-0.02), Vector3(0.10,0.22,0.10), _mat_body)

	var foot: Node3D = MeshBuilder.pivot(shin, Vector3(0,-0.24,-0.02))
	MeshBuilder.box(foot, Vector3(0,-0.03, 0.06), Vector3(0.10,0.06,0.20), _mat_body)
	for tt in range(3):
		var tx: float = (-0.06 + float(tt)*0.06) * side
		MeshBuilder.box(foot, Vector3(tx,-0.04, 0.18+float(tt)*0.01), Vector3(0.04,0.04,0.10), _mat_body)
		MeshBuilder.box(foot, Vector3(tx,-0.06, 0.25), Vector3(0.03,0.03,0.05), _mat_dark)
	MeshBuilder.box(foot, Vector3(0, 0.02, 0.22), Vector3(0.03,0.08,0.04), _mat_light)

	return [shin, foot]

# ── Tail ──────────────────────────────────────────────────────────────────────
func _build_tail() -> void:
	tail.clear()
	var tsz: Array[Vector3] = [
		Vector3(0.26,0.20,0.22), Vector3(0.20,0.16,0.20),
		Vector3(0.15,0.12,0.18), Vector3(0.11,0.09,0.16),
		Vector3(0.07,0.06,0.14)]
	var tp2: Node3D = rig
	for i in range(5):
		var off: Vector3 = Vector3(0,0.58,-0.44) if i == 0 else Vector3(0,0,-tsz[i-1].z)
		var tp: Node3D   = MeshBuilder.pivot(tp2, off)
		MeshBuilder.box(tp, Vector3(0,0,-tsz[i].z*0.5), tsz[i], _mat_body)
		if i < 3:
			MeshBuilder.box(tp,
				Vector3(0, tsz[i].y*0.55, -tsz[i].z*0.4),
				Vector3(0.04, 0.07-float(i)*0.02, 0.04), _mat_light)
		tail.append(tp)
		tp2 = tp
	MeshBuilder.box(tp2, Vector3(0,0,-0.14), Vector3(0.04,0.04,0.12), _mat_light)
