class_name WatermelonProjectile
extends Node3D

var _damage: int = 12
var _shooter: Node = null
var _speed: float = 15.0
var _direction: Vector3
var _max_range: float = 30.0
var _dist_traveled: float = 0.0
var _aoe_radius: float = 2.0
var _hit_something: bool = false
var _trail_timer: float = 0.0
var _mesh_root: Node3D
var _light: OmniLight3D
var _ring_mats: Array[StandardMaterial3D] = []

var green_dark := Color(0.18, 0.50, 0.12)
var green_l := Color(0.28, 0.60, 0.20)
var red_flesh := Color(0.75, 0.15, 0.18)

var _crackled: bool = false

func setup(dir: Vector3, dmg: int, spd: float, max_rng: float, aoe: float, shooter: Node) -> void:
	_direction = dir
	_damage = dmg
	_speed = spd
	_max_range = max_rng
	_aoe_radius = aoe
	_shooter = shooter
	_build_visual()

func _build_visual() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	var mat_core := MeshBuilder.emit_mat(green_dark, green_dark, 6.0)
	MeshBuilder.sphere(_mesh_root, Vector3.ZERO, 0.11, mat_core)

	var mat_glow := MeshBuilder.emit_mat(green_l, green_l, 4.0)
	var glow := MeshBuilder.sphere(_mesh_root, Vector3.ZERO, 0.18, mat_glow)

	var mat_corona := MeshBuilder.emit_mat(Color(0.18, 0.50, 0.12, 0.30), green_l, 2.0)
	var corona := MeshBuilder.sphere(_mesh_root, Vector3.ZERO, 0.33, mat_corona)
	corona.scale = Vector3(1.0, 0.6, 1.0)

	var mat_ring1 := MeshBuilder.emit_mat(red_flesh, Color(1.0, 0.2, 0.25), 5.0)
	var mat_ring2 := MeshBuilder.emit_mat(green_dark, green_l, 3.0)
	_ring_mats = [mat_ring1, mat_ring2]

	for i in range(3):
		var tor := TorusMesh.new()
		tor.inner_radius = 0.18 + i * 0.03
		tor.outer_radius = 0.025
		var mi := MeshInstance3D.new()
		mi.mesh = tor
		mi.material_override = mat_ring1 if i % 2 == 0 else mat_ring2
		var ang := float(i) * 1.57
		mi.rotation = Vector3(ang, ang * 0.7, ang * 0.3)
		_mesh_root.add_child(mi)

	for i in range(5):
		var a1: float = float(i) / 5.0 * TAU
		var a2: float = float(i) * 1.1
		var pos := Vector3(
			cos(a1) * sin(a2),
			sin(a1) * sin(a2),
			cos(a2)
		) * 0.22
		var ec := red_flesh if i % 2 == 0 else green_l
		var mat_ember := MeshBuilder.emit_mat(ec, ec, 4.0 + sin(i * 1.7) * 2.0)
		MeshBuilder.sphere(_mesh_root, pos, 0.025, mat_ember)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.18, 0.60, 0.15)
	_light.light_energy = 1.5
	_light.omni_range = 1.5
	_light.light_specular = 0.0
	add_child(_light)

func _process(delta: float) -> void:
	if _hit_something:
		return
	_trail_timer += delta

	_mesh_root.rotation.z += delta * 4.0
	_mesh_root.rotation.y += delta * 3.0
	_mesh_root.rotation.x += delta * 1.2

	var step := _direction * _speed * delta
	var next_pos := global_position + step
	var space := get_world_3d().direct_space_state
	if space:
		var query := PhysicsRayQueryParameters3D.new()
		query.from = global_position
		query.to = next_pos
		query.collision_mask = 1
		var result := space.intersect_ray(query)
		if not result.is_empty():
			global_position = result.position
			_explode()
			return
	global_position = next_pos
	_dist_traveled += step.length()

	var pulse: float = 1.0 + sin(_dist_traveled * 3.0) * 0.08
	_mesh_root.scale = Vector3(pulse, pulse, pulse)

	_light.light_energy = 3.0 + sin(_dist_traveled * 5.0) * 1.0
	_light.omni_range = 3.0 + sin(_dist_traveled * 4.0) * 0.8

	if _trail_timer >= 0.03:
		_trail_timer = 0.0
		_spawn_trail()

	_check_hit()

	if _dist_traveled >= _max_range:
		_explode()
	elif _dist_traveled >= _max_range * 0.85 and not _crackled:
		_crackled = true
		_spawn_crackle()
	elif _dist_traveled >= _max_range * 0.90:
		var p: float = 1.0 + sin(_dist_traveled * 20.0) * 0.1
		_mesh_root.scale = Vector3(p, p, p)

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := MeshBuilder.emit_mat(
		Color(0.25, 0.55, 0.15, 0.6),
		Color(0.35, 0.70, 0.25), 5.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.08
	sph.height = 0.16
	mi.mesh = sph
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = global_position - _direction * 0.12

	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.15, 0.15, 0.15), 0.4)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(mi.queue_free).set_delay(0.45)

func _spawn_crackle() -> void:
	for i in 6:
		var cmat := MeshBuilder.emit_mat(
			Color(1.0, 0.6, 0.1, 0.7),
			Color(1.0, 0.4, 0.0), 4.0)
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var cmi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.02
		sph.height = 0.04
		cmi.mesh = sph
		cmi.material_override = cmat
		cmi.position = Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
		cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cmi)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(cmi, "position", cmi.position * 3.0, 0.2)
		tw.tween_property(cmat, "albedo_color:a", 0.0, 0.2)
		tw.tween_property(cmat, "emission_energy_multiplier", 0.0, 0.2)
		tw.tween_callback(cmi.queue_free).set_delay(0.25)

func _get_characters() -> Array:
	var chars: Array = []
	var root := get_tree().current_scene
	if root == null:
		return chars
	_scan_characters(root, chars)
	return chars

func _scan_characters(node: Node, chars: Array) -> void:
	if node is CharacterBase and node.is_alive:
		chars.append(node)
	for i in node.get_child_count():
		_scan_characters(node.get_child(i), chars)

func _check_hit() -> void:
	for ch in _get_characters():
		if ch == _shooter:
			continue
		var offset: Vector3 = global_position - ch.global_position
		offset.y = 0.0
		if offset.length() < 1.0:
			_explode()
			return

func _deal_aoe_damage() -> void:
	for ch in _get_characters():
		if ch == _shooter:
			continue
		var offset: Vector3 = global_position - ch.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist < _aoe_radius:
			var dmg_mult: float = 1.0
			if dist > 1.5:
				dmg_mult = max(0.0, 1.0 - 0.15 * (dist - 1.5))
			ch.take_damage(int(_damage * dmg_mult), _shooter, 1)

func _explode() -> void:
	_hit_something = true
	var parent := get_parent()
	if parent == null:
		queue_free()
		return
	var tw_puff := create_tween()
	tw_puff.tween_property(_mesh_root, "scale", Vector3(2.0, 2.0, 2.0), 0.08)
	tw_puff.tween_callback(func():
		_deal_aoe_damage()
		_spawn_poison_pool(parent)
		_explode_vfx(parent)
		_mesh_root.visible = false
	).set_delay(0.08)
	set_process(false)
	get_tree().create_timer(0.35).timeout.connect(queue_free)

func _spawn_poison_pool(parent: Node) -> void:
	var pool := preload("res://scripts/items/entities/poison_pool.gd").new()
	parent.add_child(pool)
	pool.setup(global_position, 5, _aoe_radius, 4.0, _shooter)

func _explode_vfx(parent: Node) -> void:
	var big_flash := OmniLight3D.new()
	big_flash.light_color = Color(0.40, 0.80, 0.20)
	big_flash.light_energy = 30.0
	big_flash.omni_range = 12.0
	big_flash.light_specular = 0.0
	parent.add_child(big_flash)
	big_flash.global_position = global_position
	get_tree().create_timer(0.08).timeout.connect(
		func(): if is_instance_valid(big_flash): big_flash.queue_free())

	for i in range(6):
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.30 + i * 0.06, 0.60 + i * 0.04, 0.10 + i * 0.02)
		flash.light_energy = 15.0 + i * 5.0
		flash.omni_range = 7.0 + i * 2.0
		flash.light_specular = 0.0
		parent.add_child(flash)
		flash.global_position = global_position
		get_tree().create_timer(0.02 * i).timeout.connect(
			func(): if is_instance_valid(flash): flash.queue_free())

	for j in range(6):
		var mat := MeshBuilder.emit_mat(
			Color(0.18 + j * 0.03, 0.50 - j * 0.04, 0.12 - j * 0.01),
			Color(0.30 + j * 0.04, 0.65 - j * 0.04, 0.15), 5.0 - j * 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.02 + j * 0.015
		tor.outer_radius = 0.10 - j * 0.008
		mi.mesh = tor
		mi.material_override = mat
		mi.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mi, "scale", Vector3(5, 5, 5), 0.3)
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
