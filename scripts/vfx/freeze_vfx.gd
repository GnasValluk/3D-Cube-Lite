extends Node3D
class_name FreezeVFX

var _duration: float = 2.0
var _age: float = 0.0
var _flakes: Array[Node3D] = []
var _angles: Array[float] = []
var _speeds: Array[float] = []
var _heights: Array[float] = []
var _drifts: Array[float] = []
var _mat: StandardMaterial3D

func setup(duration: float) -> void:
	_duration = duration
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.8)
	_mat.emission_enabled = true
	_mat.emission = Color(0.60, 0.80, 1.0, 0.4)
	for i in range(12):
		var flake := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.025 + randf() * 0.02
		sph.height = sph.radius * 2.0
		flake.mesh = sph
		flake.material_override = _mat
		add_child(flake)
		_flakes.append(flake)
		_angles.append(randf() * TAU)
		_speeds.append(0.8 + randf() * 0.6)
		_heights.append(randf() * 1.2 - 0.2)
		_drifts.append(randf() * 0.3 - 0.15)

func _process(delta: float) -> void:
	_age += delta
	var t := _age / _duration
	if t >= 1.0:
		queue_free()
		return
	var fade := 1.0 if t < 0.7 else (1.0 - t) / 0.3
	for i in range(_flakes.size()):
		_angles[i] += _speeds[i] * delta
		var r: float = 0.45 + sin(_age * 2.0 + float(i)) * 0.15
		var x := cos(_angles[i]) * r
		var z := sin(_angles[i]) * r
		var y := _heights[i] + sin(_age * 3.0 + float(i) * 0.7) * 0.15 + _age * 0.6
		y = wrapf(y, -0.4, 1.0)
		_flakes[i].position = Vector3(x + _drifts[i], y, z)
		_flakes[i].scale = Vector3.ONE * fade
