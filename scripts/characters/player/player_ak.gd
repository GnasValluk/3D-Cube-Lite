class_name PlayerAK
extends RefCounted

## Súng trường tấn công AK-12 — bắn tự động trong lúc giữ chuột trái,
## tiêu hao đạn 7,62mm mỗi phát.

const AK_FIRE_INTERVAL: float = 0.11
const AK_BULLET_SPEED: float = 120.0
const AK_RANGE: float = 40.0
const AK_SPREAD_DEG: float = 0.8

static func has_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for slot in player.inventory.slots:
		if not slot.is_empty() and slot.item.id == "bullet_762mm":
			return true
	return false

static func consume_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for i in range(player.inventory.slots.size()):
		var slot: ItemSlot = player.inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "bullet_762mm":
			player.inventory.remove_item(i, 1)
			return true
	return false

static func start_fire(player) -> void:
	if not player.equipped_weapon or player.equipped_weapon.id != "ak_12":
		return
	if not has_ammo(player):
		player._scroll_inventory_message(player.tr("NO_AK_AMMO"))
		return
	player._bow_aiming = true
	player._bow_charge = 0.0
	player._ak_fire_cooldown = 0.0
	_setup_indicator(player)

static func _setup_indicator(player) -> void:
	if player._bow_indicator_root == null:
		player._bow_indicator_root = Node3D.new()
		player._bow_indicator_root.name = "BowAimIndicator"
		player.get_tree().current_scene.add_child(player._bow_indicator_root)
	else:
		for ch in player._bow_indicator_root.get_children():
			ch.queue_free()
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

static func update_fire(player, delta: float) -> void:
	if not player._bow_aiming:
		return
	if not player.equipped_weapon or player.equipped_weapon.id != "ak_12":
		player._bow_aiming = false
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if not has_ammo(player):
		player._scroll_inventory_message(player.tr("NO_AK_AMMO"))
		cancel_aim(player)
		return
	player._ak_fire_cooldown -= delta
	if player._ak_fire_cooldown > 0.0:
		return
	player._ak_fire_cooldown = AK_FIRE_INTERVAL
	fire_shot(player)

static func fire_shot(player) -> void:
	if not consume_ammo(player):
		cancel_aim(player)
		return
	player._damage_equipped_tool(1)

	var base_dmg: int = player.attack_power + (player.equipped_weapon.atk_bonus if player.equipped_weapon else 8)

	var spawn_from: Vector3 = player.global_position + Vector3(0, 0.6, 0) + player._bow_aim_dir * 0.5
	if player._mesh and player._mesh.weapon_pivot:
		spawn_from = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.36, 0)

	var aim_dir: Vector3 = player._bow_aim_dir
	if player._aim_tp_mode and player._aim_world_point != Vector3.ZERO:
		var to_tgt: Vector3 = player._aim_world_point - spawn_from
		if to_tgt.length_squared() > 0.01:
			aim_dir = to_tgt.normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = -player.global_transform.basis.z

	var spread := deg_to_rad(AK_SPREAD_DEG)
	var up_ref := Vector3.UP
	if absf(aim_dir.dot(up_ref)) > 0.98:
		up_ref = Vector3.RIGHT
	var right := aim_dir.cross(up_ref).normalized()
	var up2 := right.cross(aim_dir).normalized()
	var dir := (aim_dir + right * randf_range(-spread, spread) + up2 * randf_range(-spread, spread)).normalized()

	var bullet := BulletProjectile.new()
	var world: Node = player.get_tree().current_scene
	if world:
		world.add_child(bullet)
	else:
		player.add_child(bullet)
	bullet.global_position = spawn_from + dir * 0.3
	bullet.setup(dir, base_dmg, AK_BULLET_SPEED, AK_RANGE, player)

	SFXManager.play_gun_shot()
	_muzzle_flash(player, spawn_from)
	_kick(player)

static func _muzzle_flash(player, pos: Vector3) -> void:
	var world: Node = player.get_tree().current_scene
	if world == null:
		return
	var mat := MeshBuilder.emit_mat(
		Color(1.0, 0.85, 0.4, 0.9),
		Color(1.0, 0.8, 0.4), 5.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.10
	mi.mesh = sph
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = pos
	var tw: Tween = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(0.25, 0.25, 0.25), 0.06)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)
	tw.tween_callback(mi.queue_free).set_delay(0.15)

static func _kick(player) -> void:
	if player._mesh == null or player._mesh.weapon_pivot == null:
		return
	var wp: Node3D = player._mesh.weapon_pivot
	var base_pos: Vector3 = wp.position
	var tw: Tween = player.create_tween()
	tw.tween_property(wp, "position:y", base_pos.y - 0.03, 0.035)
	tw.tween_property(wp, "position:y", base_pos.y, 0.07).set_delay(0.035)

static func cancel_aim(player) -> void:
	player._bow_aiming = false
	player._bow_charge = 0.0
	player._aim_tp_mode = false
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false