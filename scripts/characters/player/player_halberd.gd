class_name PlayerHalberd
extends RefCounted

static func start_throw_aim(player) -> void:
	player._halberd_throwing = true
	player._bow_aiming = false
	if player._bow_indicator_root == null:
		player._bow_indicator_root = Node3D.new()
		player._bow_indicator_root.name = "BowAimIndicator"
		player.get_tree().current_scene.add_child(player._bow_indicator_root)
	else:
		for ch in player._bow_indicator_root.get_children():
			ch.queue_free()
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.3, 0.8, 0.6, 0.50)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(0.3, 0.8, 0.6)
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
	player._bow_indicator_target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player._bow_indicator_root.add_child(player._bow_indicator_target)
	player._bow_indicator_root.visible = true

static func update_aim(player, delta: float) -> void:
	var cam: Camera3D = player.get_viewport().get_camera_3d()
	if cam == null: return
	var mouse_pos: Vector2 = player.get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var plane_y: float = player.global_position.y
	player._halberd_aim_dir = player.global_transform.basis.z
	if abs(dir.y) > 0.001:
		var t: float = (plane_y - from.y) / dir.y
		var ground_hit: Vector3 = from + dir * max(t, 0.0)
		var to_target: Vector3 = ground_hit - player.global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			player._halberd_aim_dir = to_target.normalized()
	player.rotation.y = atan2(player._halberd_aim_dir.x, player._halberd_aim_dir.z)
	var charge_pct: float = player._halberd_charge_time / (player.HALBERD_CHARGE_TIME + player._bow_max_charge)
	charge_pct = clamp(charge_pct, 0.0, 1.0)
	var range_len: float = lerp(player.HALBERD_MIN_RANGE, player.HALBERD_MAX_RANGE, charge_pct)
	var end_pos: Vector3 = player._halberd_aim_dir * range_len
	end_pos.y = plane_y
	if player._bow_indicator_root == null or player._bow_indicator_target == null: return
	player._bow_indicator_root.global_position = player.global_position + Vector3(0, 0.3, 0)
	player._bow_indicator_target.global_position = player._bow_indicator_root.global_position + end_pos
	var ring_color := Color(0.3, 0.8, 0.6).lerp(Color(1.0, 0.4, 0.3), charge_pct)
	ring_color.a = 0.50
	player._bow_indicator_target.material_override.albedo_color = ring_color

static func fire_throw(player) -> void:
	player._halberd_throwing = false
	var saved_charge: float = player._halberd_charge_time
	player._halberd_charge_time = -1.0
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false
	if not player.try_skill(player.stamina_cost_lmb):
		return
	var dir: Vector3 = player._halberd_aim_dir
	if dir.length_squared() < 0.01:
		dir = -player.global_transform.basis.z
	var charge_pct: float = clamp(saved_charge / (player.HALBERD_CHARGE_TIME + player._bow_max_charge), 0.0, 1.0)
	var range_len: float = lerp(player.HALBERD_MIN_RANGE, player.HALBERD_MAX_RANGE, charge_pct)
	var plane_y: float = player.global_position.y
	var landing_pos: Vector3 = player.global_position + dir * range_len
	landing_pos.y = plane_y
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if space:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
		q.from = landing_pos + Vector3(0, 2.0, 0)
		q.to = landing_pos + Vector3(0, -4.0, 0)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			landing_pos.y = hit.position.y
	# Kích KHÔNG rời khỏi inventory — không spawn drop
	var base_dmg: int = player.attack_power + (player.equipped_weapon.atk_bonus if player.equipped_weapon else 10)
	var dmg: int = int(base_dmg * lerp(1.0, 1.6, charge_pct))
	_apply_throw_damage(player, dir, landing_pos, dmg)
	var msg: String = player.tr("THREW_MSG") if player.tr("THREW_MSG") != "THREW_MSG" else "Đã ném Kích Sắt"
	player._scroll_inventory_message(msg)

## Đòn ném: sát thương mọi mục tiêu nằm trong hành lang player → điểm đáp
static func _apply_throw_damage(player, dir: Vector3, landing_pos: Vector3, dmg: int) -> void:
	var start: Vector3 = player.global_position + Vector3(0, 0.4, 0)
	var end: Vector3 = landing_pos + Vector3(0, 0.4, 0)
	var hit_any := false
	var mgr: Node = player._find_character_manager()
	if mgr:
		for ch in mgr.get_children():
			if ch is CharacterBase and ch != player and ch.is_alive and ch._active:
				if _segment_dist(start, end, ch.global_position) <= 0.9 + ch.hit_radius:
					ch.take_damage(dmg, player)
					_knockback(ch, dir)
					hit_any = true
	var pig_nodes: Array[Node] = player.get_tree().get_nodes_in_group("pig")
	for pn in pig_nodes:
		if is_instance_valid(pn) and pn.get("is_alive"):
			if _segment_dist(start, end, pn.global_position) <= 0.9 + pn.hit_radius:
				pn.take_damage(dmg, player)
				_knockback(pn, dir)
				hit_any = true
	var fish_nodes: Array[Node] = player.get_tree().get_nodes_in_group("fish")
	for f in fish_nodes:
		if is_instance_valid(f) and f.get("is_alive"):
			if _segment_dist(start, end, f.global_position) <= 0.9 + f.hit_radius:
				f.take_damage(dmg, player)
				_knockback(f, dir)
				hit_any = true
	var crab_nodes: Array[Node] = player.get_tree().get_nodes_in_group("crab")
	for cn in crab_nodes:
		if is_instance_valid(cn) and cn.get("is_alive"):
			if _segment_dist(start, end, cn.global_position) <= 0.9 + cn.hit_radius:
				cn.take_damage(dmg, player)
				_knockback(cn, dir)
				hit_any = true
	if hit_any:
		SFXManager.play_damage_hit()

static func _segment_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return a.distance_to(a + ab * t)

static func _knockback(ch: CharacterBase, dir: Vector3) -> void:
	var kb := dir * 3.0
	kb.y = 1.5
	ch.velocity += kb

static func cancel_aim(player) -> void:
	player._halberd_throwing = false
	player._halberd_charge_time = -1.0
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false

static func do_melee(player) -> void:
	player._halberd_charge_time = -1.0
	if player._freeze_timer <= 0.0 and player._attack2_timer <= 0.0 and player._state != player.State.DASH:
		var max_step: int = 1
		if player.combo_timer > 0.0 and player.combo_step < max_step:
			player.combo_step += 1
		elif player._attack_timer <= 0.0:
			player.combo_step = 0
		else:
			return
		player.combo_timer = player.COMBO_WINDOW
		if not player.try_skill(player.stamina_cost_lmb):
			return
		player._aim_dir = player._calc_aim_dir()
		var fwd: Vector3 = player.global_transform.basis.z
		if player._aim_dir.dot(fwd) < 0.99:
			player.rotation.y = atan2(player._aim_dir.x, player._aim_dir.z)
		player._lmb_cd = 0.0
		match player.combo_step:
			0:
				player.attack_duration = 0.85
				player._melee_hit_progress = 0.35
			1:
				player.attack_duration = 0.70
				player._melee_hit_progress = 0.30
		player._attack_timer = player.attack_duration * (2.0 if player._underwater else 1.0)
		player._state = player.State.ATTACK
		player._melee_hit_once = false

static func on_dash(player) -> void:
	if player.equipped_weapon and player.equipped_weapon.id == "iron_halberd":
		player._halberd_dashing = true
		player._halberd_dash_hit = {}

static func check_dash_hit(player) -> void:
	var dir: Vector3 = player._dash_dir
	if dir.length_squared() < 0.01:
		return
	var fwd: Vector3 = dir.normalized()
	var right: Vector3 = Vector3.UP.cross(fwd).normalized()
	var box_center: Vector3 = player.global_position + fwd * 1.4 + Vector3(0, 0.5, 0)
	var half: Vector3 = Vector3(0.65, 0.55, 2.0)

	var mgr: Node = player._find_character_manager()
	if mgr:
		for ch in mgr.get_children():
			if ch is CharacterBase and ch != player and ch.is_alive and ch._active:
				_try_dash_hit(player, ch, box_center, right, fwd, half)

	var pig_nodes: Array[Node] = player.get_tree().get_nodes_in_group("pig")
	for pn in pig_nodes:
		if is_instance_valid(pn) and pn.get("is_alive"):
			_try_dash_hit(player, pn as CharacterBase, box_center, right, fwd, half)

	var fish_nodes: Array[Node] = player.get_tree().get_nodes_in_group("fish")
	for f in fish_nodes:
		if is_instance_valid(f) and f.get("is_alive"):
			_try_dash_hit(player, f as CharacterBase, box_center, right, fwd, half)

static func _point_in_hit_box(p: Vector3, box_center: Vector3, right: Vector3, fwd: Vector3, half: Vector3) -> bool:
	var to_target: Vector3 = p - box_center
	var local: Vector3 = Vector3(to_target.dot(right), to_target.dot(Vector3.UP), to_target.dot(fwd))
	return abs(local.x) < half.x and abs(local.y) < half.y and abs(local.z) < half.z

static func _try_dash_hit(player, ch: CharacterBase, box_center: Vector3, right: Vector3, fwd: Vector3, half: Vector3) -> void:
	if player._halberd_dash_hit.has(ch.get_instance_id()):
		return
	if _point_in_hit_box(ch.global_position, box_center, right, fwd, half):
		player._halberd_dash_hit[ch.get_instance_id()] = true
		var dmg: int = player.get_total_atk()
		ch.take_damage(dmg, player)
		SFXManager.play_damage_hit()
