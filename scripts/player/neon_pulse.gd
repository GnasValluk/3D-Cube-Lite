## neon_pulse.gd
## Pulse nhẹ theo nhịp – style JSaB: không nhấp nháy lòe loẹt,
## chỉ thở nhẹ emission để tạo cảm giác "sống"

extends Node

@export var pulse_speed: float = 1.6
@export var energy_min:  float = 1.2
@export var energy_max:  float = 2.2

var _time:   float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _player: CharacterBody3D


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	for child in _player.get_children():
		if child is MeshInstance3D:
			_meshes.append(child as MeshInstance3D)


func _process(delta: float) -> void:
	if _meshes.is_empty():
		return

	var moving: bool  = Vector2(_player.velocity.x, _player.velocity.z).length_squared() > 0.1
	var spd: float    = pulse_speed * (1.6 if moving else 1.0)
	_time += delta * spd

	var t:      float = (sin(_time) + 1.0) * 0.5
	var energy: float = lerp(energy_min, energy_max, t)

	for mi in _meshes:
		var mat := mi.material_override
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_energy_multiplier = energy
