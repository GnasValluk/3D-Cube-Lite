## warrior/warrior_ice_zone.gd
## Cột băng nhọn cho Q của Warrior. Xuất hiện/grow + biến mất/shrink.

extends Node3D
class_name WarriorIceZone

const RADIUS: float = 15.0
const SPIKE_COUNT: int = 40
const DURATION: float = 10.0
const APPEAR_TIME: float = 0.4
const FADE_TIME: float = 0.5

var _spikes: Array[MeshInstance3D] = []
var _spike_heights: Array[float] = []
var _spike_mats: Array[StandardMaterial3D] = []
var _fading: bool = false

func setup(origin: Vector3) -> void:
	global_position = origin
	_build()

func _build() -> void:
	for i in range(SPIKE_COUNT):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.85, 1.0, 0.80)
		mat.emission_enabled = true
		mat.emission = Color(0.30, 0.75, 1.0, 0.50)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spike_mats.append(mat)

		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		var h: float = 1.5 + randf() * 4.0
		var r: float = 0.06 + randf() * 0.22
		cone.top_radius = 0.0
		cone.bottom_radius = r
		cone.height = h
		spike.mesh = cone
		spike.material_override = mat

		var angle := float(i) / float(SPIKE_COUNT) * TAU + randf() * 0.06
		var dist := RADIUS * (0.5 + randf() * 0.5)
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		spike.position = Vector3(x, 0.0, z)
		_spikes.append(spike)
		_spike_heights.append(h)
		add_child(spike)

	var light := OmniLight3D.new()
	light.light_color = Color(0.40, 0.85, 1.0)
	light.light_energy = 8.0
	light.omni_range = 18.0
	light.position.y = 2.0
	add_child(light)

	_make_snow()

	get_tree().create_timer(DURATION, false).timeout.connect(_start_fade)

	var delay_step: float = APPEAR_TIME / float(SPIKE_COUNT) * 0.3
	for i in range(SPIKE_COUNT):
		var idx := i
		get_tree().create_timer(delay_step * float(i), false).timeout.connect(_grow_spike.bind(idx))
		_spikes[i].scale = Vector3(1.0, 0.01, 1.0)
		_spikes[i].position.y = 0.0

func _grow_spike(idx: int) -> void:
	if not is_instance_valid(_spikes[idx]):
		return
	var h := _spike_heights[idx]
	var st := create_tween()
	st.tween_property(_spikes[idx], "scale", Vector3(1.0, 1.0, 1.0), 0.25)
	st.parallel().tween_property(_spikes[idx], "position:y", h * 0.5, 0.25)

func _start_fade() -> void:
	if _fading:
		return
	_fading = true
	var delay_step2: float = FADE_TIME * 0.3 / float(SPIKE_COUNT)
	for i in range(SPIKE_COUNT):
		var st := create_tween()
		var h := _spike_heights[i]
		st.tween_property(_spikes[i], "scale", Vector3(1.0, 0.01, 1.0), FADE_TIME * 0.7)
		st.parallel().tween_property(_spikes[i], "position:y", -h * 0.5, FADE_TIME * 0.7)
		var mat := _spike_mats[i]
		get_tree().create_timer(delay_step2 * float(i), false).timeout.connect(func():
			if not is_instance_valid(mat):
				return
			var ft := create_tween()
			ft.tween_property(mat, "albedo_color:a", 0.0, FADE_TIME * 0.5)
			ft.tween_property(mat, "emission:a", 0.0, FADE_TIME * 0.5)
		)
	get_tree().create_timer(FADE_TIME).timeout.connect(queue_free)

const SNOW_COUNT: int = 60

func _make_snow() -> void:
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.85, 0.95, 1.0, 0.70)
	sm.emission_enabled = true
	sm.emission = Color(0.60, 0.85, 1.0, 0.40)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(SNOW_COUNT):
		var flake := MeshInstance3D.new()
		var ss := SphereMesh.new()
		ss.radius = 0.02 + randf() * 0.04
		ss.height = ss.radius * 2.0
		flake.mesh = ss
		flake.material_override = sm
		var angle := randf() * TAU
		var dist := randf() * RADIUS
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		flake.position = Vector3(x, 4.0 + randf() * 6.0, z)
		add_child(flake)
		var fall := create_tween()
		var target_y: float = -(randf() * 2.0)
		fall.tween_property(flake, "position:y", target_y, 3.0 + randf() * 3.0)
		fall.parallel().tween_property(flake, "position:x", x + randf_range(-1.0, 1.0), 3.0 + randf() * 3.0)
		fall.parallel().tween_property(flake, "position:z", z + randf_range(-1.0, 1.0), 3.0 + randf() * 3.0)
		fall.tween_callback(func():
			if is_instance_valid(flake):
				flake.queue_free()
		)
