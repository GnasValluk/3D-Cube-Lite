class_name PlayerBow
extends RefCounted

static func has_arrows(player) -> bool:
	if player.inventory == null:
		return false
	for slot in player.inventory.slots:
		if not slot.is_empty() and slot.item.id == "arrow":
			return true
	return false

static func consume_arrow(player) -> bool:
	if player.inventory == null:
		return false
	for i in range(player.inventory.slots.size()):
		var slot: ItemSlot = player.inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "arrow":
			player.inventory.remove_item(i, 1)
			return true
	return false

static func has_watermelon_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for slot in player.inventory.slots:
		if not slot.is_empty() and slot.item.id == "watermelon_nuke_ammo":
			return true
	return false

static func consume_watermelon_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for i in range(player.inventory.slots.size()):
		var slot: ItemSlot = player.inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "watermelon_nuke_ammo":
			player.inventory.remove_item(i, 1)
			return true
	return false

static func start_aim(player) -> void:
	if not player.equipped_weapon or player.equipped_weapon.id != "crossbow":
		return
	player._bow_aiming = true
	player._bow_charge = 0.0
	player._bow_string_node = null
	if player._mesh != null and player._mesh.weapon_pivot != null:
		for ch in player._mesh.weapon_pivot.get_children():
			if ch.name == "BowString":
				player._bow_string_node = ch
				break
	if player._bow_indicator_root == null:
		player._bow_indicator_root = Node3D.new()
		player._bow_indicator_root.name = "BowAimIndicator"
		player.get_tree().current_scene.add_child(player._bow_indicator_root)
	else:
		for ch in player._bow_indicator_root.get_children():
			ch.queue_free()
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	line_mat.emission_enabled = true
	line_mat.emission_color = Color(1.0, 1.0, 1.0)
	line_mat.emission_energy_multiplier = 0.4
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	player._bow_indicator_line = MeshInstance3D.new()
	player._bow_indicator_line.mesh = BoxMesh.new()
	player._bow_indicator_line.material_override = line_mat
	player._bow_indicator_root.add_child(player._bow_indicator_line)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.40)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(1.0, 0.85, 0.4)
	ring_mat.emission_energy_multiplier = 0.5
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	player._bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.05
	ring.radial_segments = 16
	player._bow_indicator_target.mesh = ring
	player._bow_indicator_target.material_override = ring_mat
	player._bow_indicator_root.add_child(player._bow_indicator_target)
	player._bow_indicator_root.visible = true
	update_bow_string(player, 0.0)

static func make_aoe_ring(player, radius: float, color: Color) -> void:
	if player._bow_indicator_aoe:
		player._bow_indicator_aoe.queue_free()
	var aoe_mat := StandardMaterial3D.new()
	aoe_mat.albedo_color = color
	aoe_mat.emission_enabled = true
	aoe_mat.emission_color = color
	aoe_mat.emission_energy_multiplier = 0.6
	aoe_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aoe_mat.no_depth_test = true
	aoe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	player._bow_indicator_aoe = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = radius - 0.06
	tor.outer_radius = 0.06
	tor.ring_segments = 12
	tor.rings = 24
	player._bow_indicator_aoe.mesh = tor
	player._bow_indicator_aoe.material_override = aoe_mat
	player._bow_indicator_aoe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player._bow_indicator_root.add_child(player._bow_indicator_aoe)

static func start_cannon_aim(player) -> void:
	if not player.equipped_weapon or player.equipped_weapon.id != "watermelon_cannon":
		return
	if not has_watermelon_ammo(player):
		return
	player._bow_aiming = true
	player._bow_charge = player._bow_max_charge
	if player._bow_indicator_root == null:
		player._bow_indicator_root = Node3D.new()
		player._bow_indicator_root.name = "BowAimIndicator"
		player.get_tree().current_scene.add_child(player._bow_indicator_root)
	else:
		for ch in player._bow_indicator_root.get_children():
			ch.queue_free()
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.9, 0.35, 0.35, 0.40)
	line_mat.emission_enabled = true
	line_mat.emission_color = Color(1.0, 0.4, 0.4)
	line_mat.emission_energy_multiplier = 0.5
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	player._bow_indicator_line = MeshInstance3D.new()
	player._bow_indicator_line.mesh = BoxMesh.new()
	player._bow_indicator_line.material_override = line_mat
	player._bow_indicator_root.add_child(player._bow_indicator_line)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.45)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(1.0, 0.85, 0.4)
	ring_mat.emission_energy_multiplier = 0.6
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	player._bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.05
	ring.radial_segments = 16
	player._bow_indicator_target.mesh = ring
	player._bow_indicator_target.material_override = ring_mat
	player._bow_indicator_root.add_child(player._bow_indicator_target)
	player._bow_indicator_root.visible = true
	make_aoe_ring(player, 7.0, Color(1.0, 0.3, 0.1, 0.30))

static func update_aim(player, delta: float) -> void:
	var is_cannon: bool = player.equipped_weapon != null and player.equipped_weapon.id == "watermelon_cannon"
	if is_cannon:
		player._bow_charge = player._bow_max_charge
	else:
		player._bow_charge = min(player._bow_charge + delta * player._bow_charge_rate, player._bow_max_charge)

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

	if player._bow_indicator_root == null or player._bow_indicator_line == null or player._bow_indicator_target == null:
		return
	var range_len: float = 25.0 if is_cannon else lerp(8.0, 50.0, player._bow_charge / player._bow_max_charge)
	var end_pos: Vector3 = player._bow_aim_dir * range_len
	end_pos.y = plane_y

	player._bow_indicator_root.global_position = player.global_position + Vector3(0, 0.3, 0)
	player._bow_indicator_line.position = end_pos * 0.5
	player._bow_indicator_line.mesh.size = Vector3(0.04, 0.04, range_len)
	player._bow_indicator_line.look_at(player._bow_indicator_root.global_position + end_pos, Vector3.UP)
	player._bow_indicator_target.global_position = player._bow_indicator_root.global_position + end_pos
	if player._bow_indicator_aoe:
		player._bow_indicator_aoe.global_position = player._bow_indicator_target.global_position

	if is_cannon:
		player._bow_indicator_line.material_override.albedo_color = Color(0.8, 0.3, 0.3, 0.35)
		player._bow_indicator_target.material_override.albedo_color = Color(1.0, 0.8, 0.3, 0.40)
	else:
		var cp: float = player._bow_charge / player._bow_max_charge
		var line_color := Color.WHITE.lerp(Color(1.0, 0.3, 0.1), cp)
		line_color.a = 0.30
		player._bow_indicator_line.material_override.albedo_color = line_color
		var ring_color := Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.2, 0.1), cp)
		ring_color.a = 0.35
		player._bow_indicator_target.material_override.albedo_color = ring_color

	if not is_cannon:
		update_pose(player)
		update_bow_string(player, player._bow_charge / player._bow_max_charge)

static func update_pose(player) -> void:
	if player._mesh == null or player._mesh.weapon_pivot == null or player._mesh.arm_r == null:
		return
	var is_no: bool = player.equipped_weapon != null and player.equipped_weapon.id == "crossbow"
	if not is_no:
		return
	player._mesh.weapon_pivot.rotation_degrees = player._mesh.weapon_pivot.rotation_degrees.lerp(Vector3(90, 0, 0), 0.15)
	if player._bow_aiming:
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, -0.35, 0.15)
	else:
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, 0.0, 0.12)

static func fire(player) -> void:
	if not player._bow_aiming:
		return
	player._bow_aiming = false
	update_bow_string(player, -1.0)
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false

	if not has_arrows(player):
		player._scroll_inventory_message(player.tr("BOW_NO_ARROWS"))
		return

	if not consume_arrow(player):
		player._scroll_inventory_message(player.tr("BOW_NO_ARROWS"))
		return

	var charge_pct: float = player._bow_charge / player._bow_max_charge
	var range_len: float = lerp(8.0, 50.0, charge_pct)
	var arrow_speed: float = lerp(15.0, 50.0, charge_pct)
	var base_dmg: int = player.attack_power + (player.equipped_weapon.atk_bonus if player.equipped_weapon else 8)
	var total_dmg: int = int(base_dmg * lerp(0.5, 1.5, charge_pct))

	var arrow := ArrowProjectile.new()
	var world: Node = player.get_tree().current_scene
	if world:
		world.add_child(arrow)
	else:
		player.add_child(arrow)
	arrow.global_position = player.global_position + Vector3(0, 0.5, 0) + player._bow_aim_dir * 0.5
	arrow.setup(player._bow_aim_dir, total_dmg, arrow_speed, range_len, player)

static func fire_watermelon_cannon(player) -> void:
	if not player.try_skill(player.stamina_cost_lmb):
		return
	if not player.equipped_weapon or player.equipped_weapon.id != "watermelon_cannon":
		return
	if not consume_watermelon_ammo(player):
		return
	var dir: Vector3 = player._calc_aim_dir()
	var base_dmg: int = player.attack_power + player.equipped_weapon.atk_bonus
	var proj := WatermelonProjectile.new()
	var world: Node = player.get_tree().current_scene
	if world:
		world.add_child(proj)
	else:
		player.add_child(proj)
	var spawn_pos: Vector3 = player.global_position + Vector3(0, 0.6, 0) + dir * 0.5
	if player._mesh and player._mesh.weapon_pivot:
		spawn_pos = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.42, 0)
	proj.global_position = spawn_pos
	proj.setup(dir, base_dmg, 17.0, 25.0, 7.0, player)
	var kb_dir: Vector3 = -dir
	kb_dir.y = 0.0
	if kb_dir.length_squared() > 0.01:
		player.velocity += kb_dir * 4.0
	if player._mesh and player._mesh.weapon_pivot:
		for i in 12:
			var smoke := MeshInstance3D.new()
			smoke.mesh = SphereMesh.new()
			smoke.mesh.radius = 0.08
			smoke.mesh.height = 0.16
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.6, 0.6, 0.6, 0.6)
			smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smat.no_depth_test = true
			smoke.material_override = smat
			smoke.position = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var muzzle: Vector3 = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.44, 0)
			player.get_tree().current_scene.add_child(smoke)
			smoke.global_position = muzzle
			var tw: Tween = player.create_tween().set_parallel()
			tw.tween_property(smoke, "position", smoke.position + Vector3(randf_range(-0.25, 0.25), randf_range(0, 0.3), randf_range(-0.25, 0.25)), 0.4)
			tw.tween_property(smat, "albedo_color:a", 0.0, 0.4)
			tw.tween_callback(smoke.queue_free).set_delay(0.45)
		var tw2: Tween = player.create_tween().set_parallel()
		var orig_pos: Vector3 = player._mesh.weapon_pivot.position
		var orig_rot: Vector3 = player._mesh.weapon_pivot.rotation
		tw2.tween_property(player._mesh.weapon_pivot, "position:y", orig_pos.y - 0.03, 0.04)
		tw2.tween_property(player._mesh.weapon_pivot, "position:y", orig_pos.y, 0.07).set_delay(0.04)
		tw2.tween_property(player._mesh.weapon_pivot, "rotation:x", orig_rot.x + 0.03, 0.04)
		tw2.tween_property(player._mesh.weapon_pivot, "rotation:x", orig_rot.x, 0.07).set_delay(0.04)

static func update_bow_string(player, charge_pct: float) -> void:
	if player._bow_string_node == null:
		return
	var left_seg: MeshInstance3D = player._bow_string_node.get_node_or_null("SegLeft")
	var right_seg: MeshInstance3D = player._bow_string_node.get_node_or_null("SegRight")
	if left_seg == null or right_seg == null:
		return
	var pull: float = charge_pct * 0.12 if charge_pct >= 0.0 else 0.0
	var left_anchor := Vector3(-0.210, 0.26, -0.030)
	var right_anchor := Vector3(0.210, 0.26, -0.030)
	var pull_pt := Vector3(0, 0.26 - pull, -0.030)
	_place_cylinder_between(left_seg, left_anchor, pull_pt)
	_place_cylinder_between(right_seg, right_anchor, pull_pt)

static func _place_cylinder_between(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var dist: float = a.distance_to(b)
	var dir: Vector3 = (b - a).normalized()
	mi.position = mid
	mi.mesh.height = dist
	var up := Vector3(0, 1, 0)
	if dir.distance_squared_to(up) < 0.0001:
		mi.basis = Basis.IDENTITY
	elif dir.distance_squared_to(-up) < 0.0001:
		mi.basis = Basis.IDENTITY.rotated(Vector3(1, 0, 0), PI)
	else:
		var axis: Vector3 = up.cross(dir).normalized()
		var angle: float = acos(up.dot(dir))
		mi.basis = Basis(axis, angle)

static func cancel_aim(player) -> void:
	player._bow_aiming = false
	player._bow_charge = 0.0
	update_bow_string(player, -1.0)
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false
