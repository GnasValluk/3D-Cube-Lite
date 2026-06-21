## warrior/warrior_ground_impact.gd
## Shockwave + đất văng cho cú dậm chân của Warrior.

extends Node3D
class_name WarriorGroundImpact

const DEBRIS_COUNT: int = 14

var _age: float = 0.0
var _lifetime: float = 0.62
var _ring_root: Node3D
var _dust_root: Node3D
var _debris: Array[Node3D] = []
var _debris_velocities: Array[Vector3] = []
var _debris_spin: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _light: OmniLight3D

func setup(origin: Vector3) -> void:
	global_position = origin
	_rng.randomize()
	_build_visual()

func _build_visual() -> void:
	_ring_root = Node3D.new()
	_dust_root = Node3D.new()
	add_child(_ring_root)
	add_child(_dust_root)

	var mat_ring := MeshBuilder.emit_mat(
		Color(0.55, 0.90, 1.0),
		Color(0.15, 0.75, 1.0), 3.5)
	var mat_dust := MeshBuilder.emit_mat(
		Color(0.36, 0.30, 0.24),
		Color(0.20, 0.16, 0.10), 0.9)
	var mat_spark := MeshBuilder.emit_mat(
		Color(0.85, 0.95, 1.0),
		Color(0.45, 0.95, 1.0), 4.0)

	var outer := MeshBuilder.cylinder(_ring_root, Vector3(0.0, 0.04, 0.0), 0.95, 0.08, mat_ring)
	outer.scale = Vector3(1.0, 0.5, 1.0)
	var inner := MeshBuilder.cylinder(_ring_root, Vector3(0.0, 0.02, 0.0), 0.55, 0.05, mat_spark)
	inner.scale = Vector3(1.0, 0.4, 1.0)

	for i in range(DEBRIS_COUNT):
		var chunk := Node3D.new()
		_dust_root.add_child(chunk)
		var size: float = _rng.randf_range(0.07, 0.14)
		if i % 2 == 0:
			MeshBuilder.box(chunk, Vector3.ZERO, Vector3(size, size * 0.7, size), mat_dust)
		else:
			MeshBuilder.sphere(chunk, Vector3.ZERO, size * 0.5, mat_dust)
		chunk.position = Vector3(
			_rng.randf_range(-0.35, 0.35),
			_rng.randf_range(0.03, 0.12),
			_rng.randf_range(-0.35, 0.35)
		)
		_debris.append(chunk)

		var angle: float = _rng.randf_range(0.0, TAU)
		var outward: float = _rng.randf_range(2.4, 5.2)
		var upward: float = _rng.randf_range(2.8, 5.0)
		_debris_velocities.append(Vector3(cos(angle) * outward, upward, sin(angle) * outward))
		_debris_spin.append(Vector3(
			_rng.randf_range(-8.0, 8.0),
			_rng.randf_range(-10.0, 10.0),
			_rng.randf_range(-8.0, 8.0)
		))

	_light = OmniLight3D.new()
	_light.light_color = Color(0.45, 0.92, 1.0)
	_light.light_energy = 6.0
	_light.omni_range = 7.0
	add_child(_light)

func _process(delta: float) -> void:
	_age += delta
	var fade: float = clamp(_age / _lifetime, 0.0, 1.0)
	var ring_scale: float = lerp(1.0, 4.8, fade)
	_ring_root.scale = Vector3(ring_scale, 1.0, ring_scale)
	_ring_root.rotation.y += delta * 1.2

	for i in range(_debris.size()):
		_debris_velocities[i].y -= 12.5 * delta
		_debris[i].position += _debris_velocities[i] * delta
		_debris[i].rotation += _debris_spin[i] * delta
		if _debris[i].position.y < 0.0:
			_debris[i].position.y = 0.0
			_debris_velocities[i].x *= 0.78
			_debris_velocities[i].z *= 0.78
			_debris_velocities[i].y *= -0.18

	if is_instance_valid(_light):
		_light.light_energy = lerp(6.0, 0.0, fade)

	if _age >= _lifetime:
		queue_free()
