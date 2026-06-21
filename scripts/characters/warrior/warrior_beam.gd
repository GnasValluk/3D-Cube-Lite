## warrior/warrior_beam.gd
## Beam năng lượng ngắn, bắn thẳng phía trước và tự xoá nhanh.

extends Node3D
class_name WarriorBeam

@export var speed: float = 28.0
@export var lifetime: float = 0.35
@export var beam_length: float = 5.8
@export var beam_width: float = 0.18

var _dir: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _beam_root: Node3D
var _light: OmniLight3D

func setup(origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	_dir = direction.normalized()
	_build_visual()
	_orient_to_dir()

func _build_visual() -> void:
	_beam_root = Node3D.new()
	add_child(_beam_root)

	var mat_core := MeshBuilder.emit_mat(
		Color(0.92, 0.98, 1.0),
		Color(0.30, 0.95, 1.0), 6.0)
	var mat_halo := MeshBuilder.emit_mat(
		Color(0.35, 0.75, 1.0, 0.8),
		Color(0.12, 0.65, 1.0), 3.5)
	var mat_ring := MeshBuilder.emit_mat(
		Color(0.80, 0.95, 1.0),
		Color(0.65, 1.0, 1.0), 4.5)

	MeshBuilder.box(
		_beam_root,
		Vector3(0.0, 0.0, -beam_length * 0.5),
		Vector3(beam_width, beam_width, beam_length),
		mat_core
	)
	MeshBuilder.box(
		_beam_root,
		Vector3(0.0, 0.0, -beam_length * 0.5),
		Vector3(beam_width * 2.6, beam_width * 2.6, beam_length * 0.96),
		mat_halo
	)

	for i in range(4):
		var t: float = float(i) / 3.0
		var ring := MeshBuilder.box(
			_beam_root,
			Vector3(0.0, 0.0, -0.25 - t * beam_length * 0.78),
			Vector3(beam_width * 3.0, beam_width * 0.30, beam_width * 3.0),
			mat_ring
		)
		ring.rotation.x = PI * 0.25
		ring.rotation.y = t * PI * 0.5

	MeshBuilder.sphere(_beam_root, Vector3.ZERO, beam_width * 1.6, mat_ring)
	MeshBuilder.sphere(_beam_root, Vector3(0.0, 0.0, -beam_length), beam_width * 1.2, mat_core)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.35, 0.9, 1.0)
	_light.light_energy = 4.0
	_light.omni_range = 6.0
	add_child(_light)

func _orient_to_dir() -> void:
	look_at(global_position + _dir, Vector3.UP)

func _process(delta: float) -> void:
	_age += delta
	_orient_to_dir()
	global_position += _dir * speed * delta

	var pulse: float = 1.0 + sin(_age * 20.0) * 0.08
	_beam_root.scale = Vector3(pulse, pulse, 1.0)
	_beam_root.rotation.z += delta * 14.0
	if is_instance_valid(_light):
		_light.light_energy = lerp(4.0, 0.0, clamp(_age / lifetime, 0.0, 1.0))

	if _age >= lifetime:
		queue_free()
