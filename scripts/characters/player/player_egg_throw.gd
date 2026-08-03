## player_egg_throw.gd — Ném trứng sinh vật: giữ chuột trái ngắm (parabol
## như pháo bí ngô), thả chuột để ném; tiêu 1 trứng ở slot hotbar đang chọn.
## Trứng chỉ lấy từ thư viện — không có nguồn khác.

class_name PlayerEggThrow
extends RefCounted

const _EggProjectile = preload("res://scripts/items/entities/egg_projectile.gd")

static func is_egg_item(item) -> bool:
	return item != null and _EggProjectile.is_egg_item_id(item.id)

static func start_aim(player) -> void:
	var item = player.get_selected_item()
	if not is_egg_item(item):
		return
	player._bow_aiming = true
	player._bow_charge = 0.0
	_setup_indicator(player, item)

static func _setup_indicator(player, item) -> void:
	if player._bow_indicator_root == null:
		player._bow_indicator_root = Node3D.new()
		player._bow_indicator_root.name = "BowAimIndicator"
		player.get_tree().current_scene.add_child(player._bow_indicator_root)
	for ch in player._bow_indicator_root.get_children():
		ch.queue_free()
	var egg_col := _EggProjectile.egg_color(item.id)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(egg_col.r, egg_col.g, egg_col.b, 0.50)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = egg_col
	ring_mat.emission_energy_multiplier = 0.6
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	player._bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.35
	ring.bottom_radius = 0.35
	ring.height = 0.05
	ring.radial_segments = 20
	player._bow_indicator_target.mesh = ring
	player._bow_indicator_target.material_override = ring_mat
	player._bow_indicator_target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player._bow_indicator_root.add_child(player._bow_indicator_target)
	player._bow_indicator_root.visible = true

static func update_aim(player, delta: float) -> void:
	var cam: Camera3D = player.get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse_pos: Vector2 = player.get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var plane_y: float = player.global_position.y
	player._bow_aim_dir = player.global_transform.basis.z
	if abs(dir.y) > 0.001:
		var t: float = (plane_y - from.y) / dir.y
		var ground_hit: Vector3 = from + dir * max(t, 0.0)
		var to_target: Vector3 = ground_hit - player.global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			player._bow_aim_dir = to_target.normalized()
	player.rotation.y = atan2(player._bow_aim_dir.x, player._bow_aim_dir.z)

	player._bow_charge = min(player._bow_charge + delta * player._bow_charge_rate, player._bow_max_charge)
	var cp: float = player._bow_charge / player._bow_max_charge
	var h_speed: float = lerp(2.0, 15.0, cp)
	var v_speed: float = lerp(3.0, 12.0, cp)
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	var start_pos: Vector3 = player.global_position + Vector3(0, 0.8, 0) + player._bow_aim_dir * 0.5
	if player._mesh and player._mesh.weapon_pivot:
		start_pos = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.35, 0)

	var a: float = -0.5 * g
	var b: float = v_speed
	var c: float = start_pos.y
	var discriminant: float = b * b - 4.0 * a * c
	var flight_time: float = 0.0
	if discriminant >= 0.0:
		flight_time = (-b - sqrt(discriminant)) / (2.0 * a)
		if flight_time < 0.0:
			flight_time = (-b + sqrt(discriminant)) / (2.0 * a)
	if flight_time <= 0.0:
		return
	var range_h: float = h_speed * flight_time
	var end_pos: Vector3 = player._bow_aim_dir * range_h

	if player._bow_indicator_root == null or player._bow_indicator_target == null:
		return
	player._bow_indicator_root.global_position = start_pos
	player._bow_indicator_target.position = Vector3(end_pos.x, -start_pos.y, end_pos.z)

	for ch in player._bow_indicator_root.get_children():
		if ch != player._bow_indicator_target:
			ch.queue_free()
	var item = player.get_selected_item()
	var egg_col := _EggProjectile.egg_color(item.id if is_egg_item(item) else "egg_carp")
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(egg_col.r, egg_col.g, egg_col.b, 0.45)
	dot_mat.emission_enabled = true
	dot_mat.emission_color = egg_col
	dot_mat.emission_energy_multiplier = 0.5
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.no_depth_test = true
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.05
	dot_mesh.height = 0.10
	var steps: int = 24
	for i in range(steps):
		var t: float = float(i + 1) / float(steps)
		var ft: float = flight_time * t
		var hx: float = player._bow_aim_dir.x * h_speed * ft
		var hz: float = player._bow_aim_dir.z * h_speed * ft
		var vy: float = v_speed * ft - 0.5 * g * ft * ft
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = dot_mat
		dot.position = Vector3(hx, vy, hz)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		player._bow_indicator_root.add_child(dot)

static func fire(player) -> void:
	if not player._bow_aiming:
		return
	player._bow_aiming = false
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false

	var item = player.get_selected_item()
	if not is_egg_item(item):
		return
	if not player.try_skill(player.stamina_cost_lmb):
		return

	# Tiêu 1 trứng ở slot hotbar đang chọn
	if player.inventory == null or player._selected_slot < 0 \
			or player._selected_slot >= player.inventory.slots.size():
		return
	player.inventory.remove_item(player._selected_slot, 1)

	var dir: Vector3 = player._calc_aim_dir()
	if dir.length_squared() < 0.01:
		dir = -player.global_transform.basis.z
	var cp: float = player._bow_charge / player._bow_max_charge
	var h_speed: float = lerp(2.0, 15.0, cp)
	var v_speed: float = lerp(3.0, 12.0, cp)

	var proj := _EggProjectile.new()
	var world: Node = player.get_tree().current_scene
	if world:
		world.add_child(proj)
	else:
		player.add_child(proj)
	var spawn_pos: Vector3 = player.global_position + Vector3(0, 0.8, 0) + dir * 0.5
	if player._mesh and player._mesh.weapon_pivot:
		spawn_pos = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.35, 0)
	proj.global_position = spawn_pos
	proj.setup(dir, h_speed, v_speed, item.id)

	if player._mesh and player._mesh.weapon_pivot:
		var tw: Tween = player.create_tween().set_parallel()
		var orig: Vector3 = player._mesh.weapon_pivot.position
		tw.tween_property(player._mesh.weapon_pivot, "position:y", orig.y - 0.05, 0.05)
		tw.tween_property(player._mesh.weapon_pivot, "position:y", orig.y, 0.08).set_delay(0.05)

static func cancel_aim(player) -> void:
	player._bow_aiming = false
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false
