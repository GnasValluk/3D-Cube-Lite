extends CharacterBase
class_name PigCharacter

enum Variant { NORMAL, SAND }

@export var pig_variant: int = Variant.NORMAL
@export var pig_scale: float = 1.0
@export var is_baby: bool = false

const VARIANT_HP: Array[int]       = [20, 20]
const VARIANT_SPEED: Array[float]  = [1.8, 2.2]
const VARIANT_SCALE: Array[float]  = [1.0, 0.9]
const CURIOSITY_RANGE: float = 5.0

var _pig_mesh: PigMesh
var _pig_anim: PigAnimator
var _home: Vector3 = Vector3.ZERO
var _steer_target: Vector3 = Vector3.ZERO
var _move_dir: Vector3 = Vector3.FORWARD
var _turn_smooth: Vector3 = Vector3.FORWARD
var _wall_memory: Vector3 = Vector3.ZERO
var _wall_memory_timer: float = 0.0
var _flee_timer: float = 0.0
var _root_timer: float = 0.0
var _repath_timer: float = 0.0
var _speed_target: float = 0.0
var _swim_phase: float = 0.0
var _player_ref: Node3D = null
var _curiosity_target: Vector3 = Vector3.ZERO
var _curiosity_timer: float = 0.0
var _is_curious: bool = false
var _look_target: Vector3 = Vector3.ZERO


enum AIState { WANDER, ROOT, FLEE }
var _ai_state: int = AIState.WANDER

const WANDER_RADIUS: float = 10.0
const FLEE_SPEED_MULT: float = 2.5
const HOME_RADIUS: float = 20.0

const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
var _world_mgr: Node = null

func _build_character() -> void:
	_is_player = false
	character_name = "Pig"
	max_hp = VARIANT_HP[pig_variant]
	if is_baby:
		max_hp = maxi(1, max_hp / 2)
	hp = max_hp
	move_speed = VARIANT_SPEED[pig_variant] * (0.55 if is_baby else 1.0)
	sprint_speed = move_speed * FLEE_SPEED_MULT
	defense = 1 if is_baby else 2
	attack_power = 0
	jump_height = 0.5
	melee_range = 0.6
	show_world_hp_bar = false
	var sc: float = VARIANT_SCALE[pig_variant] * pig_scale
	scale = Vector3(sc, sc, sc)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 0.50
	col.shape = cap
	col.position = Vector3(0, 0.25, 0)
	add_child(col)
	_pig_mesh = PigMesh.new()
	_pig_mesh.is_sand = (pig_variant == Variant.SAND)
	_pig_mesh.build(self)
	_rig = _pig_mesh.rig
	_pig_anim = PigAnimator.new()
	_pig_anim.setup(_pig_mesh, self)

func _ready() -> void:
	super._ready()
	_home = global_position
	add_to_group("pig")
	_pick_new_wander()
	_world_mgr = _find_world_manager()

func _find_world_manager():
	var p := get_parent()
	while p:
		if p.has_method("get_block"):
			return p
		p = p.get_parent()
	return null

func _pick_new_wander() -> void:
	var a := randf_range(0.0, TAU)
	var r := randf_range(3.0, WANDER_RADIUS)
	_steer_target = _home + Vector3(cos(a) * r, 0, sin(a) * r)
	var to_home := _home - global_position
	to_home.y = 0.0
	if to_home.length_squared() > HOME_RADIUS * HOME_RADIUS:
		_steer_target = _home
	_repath_timer = randf_range(3.0, 6.0)

func _find_player() -> Node3D:
	var world := get_tree().current_scene
	if world == null:
		return null
	var mgr := world.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		return mgr.get_current_character()
	return null

func _check_curiosity(delta: float) -> void:
	_curiosity_timer -= delta
	if _curiosity_timer > 0.0:
		return
	_curiosity_timer = 2.0
	_is_curious = false
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = _find_player()
		if _player_ref == null:
			return
	var range_sq := CURIOSITY_RANGE * CURIOSITY_RANGE
	if _is_curious:
		range_sq *= 1.44  # hysteresis: khó thoát khỏi trạng thái curious
	var dist := global_position.distance_squared_to(_player_ref.global_position)
	_is_curious = dist < range_sq

func _enter_root() -> void:
	_ai_state = AIState.ROOT
	_root_timer = randf_range(2.0, 5.0)
	_move_dir = Vector3.ZERO
	_speed_target = 0.0

func _read_input() -> Vector3:
	if _underwater:
		return _move_dir
	return Vector3.ZERO

func _swim(delta: float) -> void:
	_swim_phase += delta
	var dir := _read_input()
	var spd: float = move_speed * 0.55
	var accel: float = acceleration * 0.6
	var frict: float = friction * 0.5

	# Gravity always applies (y hệt player)
	velocity.y -= 3.0 * delta

	# Buoyancy force — additive, creates natural equilibrium at surface
	var bob := sin(_swim_phase * 4.0) * 0.3
	if global_position.y < 0.0:
		velocity.y += (4.0 + bob) * delta
	elif global_position.y < 0.25:
		velocity.y += (3.0 + bob) * delta
	elif global_position.y < 0.40:
		velocity.y += (1.0 + bob) * delta
	# Above 0.40: no buoyancy, gravity pulls pig back

	# Land-seeking: swim toward nearest dry land
	var space := get_world_3d().direct_space_state
	if space and _water_mgr != null:
		var fwd := _move_dir if _move_dir.length_squared() > 0.01 else Vector3.FORWARD
		var best_dir: Vector3 = fwd
		var best_angle := 999.0
		var found := false
		for ang in range(0, 16):
			var a := fwd.rotated(Vector3.UP, ang * 0.3927)
			var ahead := global_position + a * 4.0
			ahead.y += 0.1
			if _water_mgr.is_in_water(ahead.x, ahead.z, ahead.y) == false:
				var da: float = absf(ang * 0.3927)
				if da < best_angle:
					best_angle = da
					best_dir = a
					found = true
		if found:
			_move_dir = best_dir
			dir = best_dir
		else:
			_move_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * spd, accel * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, accel * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, frict * delta)
		velocity.z = move_toward(velocity.z, 0.0, frict * delta)

	move_and_slide()
	if _pig_anim:
		_pig_anim.animate(delta)

func _physics_process(delta: float) -> void:
	if not is_alive:
		if _state == State.DEAD:
			_death_timer -= delta
			velocity.x *= 0.85
			velocity.z *= 0.85
			if _pig_anim:
				_pig_anim.clear_look()
				_pig_anim.animate(delta)
			move_and_slide()
			if _death_timer <= 0.0:
				queue_free()
		return

	# Water detection every frame (same as player)
	var was_underwater := _underwater
	if _water_mgr == null or not _water_mgr.is_inside_tree():
		_water_mgr = _find_water_manager()
	if _water_mgr != null:
		_underwater = _water_mgr.is_in_water(global_position.x, global_position.z, global_position.y) \
				or _water_mgr.is_in_water(global_position.x, global_position.z, global_position.y + 0.5)
	else:
		_underwater = false
	if _underwater != was_underwater:
		submerged.emit(_underwater)

	# Water→land transition: give pig a hop to climb onto shore
	if was_underwater and not _underwater:
		velocity.y = _jump_v * 0.5
		_pick_new_wander()

	if _underwater:
		if _pig_anim:
			_pig_anim.clear_look()
		_swim(delta)
		return

	# Curiosity — nhìn/xích lại gần player
	_check_curiosity(delta)

	if _flee_timer > 0.0:
		_flee_timer -= delta

	if _is_curious and _flee_timer <= 0.0 and _player_ref != null:
		var target_pos := _player_ref.global_position
		_curiosity_target = target_pos
		_look_target = target_pos
		var dir := target_pos - global_position
		dir.y = 0.0
		if dir.length_squared() < 0.5:
			_move_dir = dir.normalized()
			_speed_target = 0.0
		else:
			_move_dir = dir.normalized()
			_speed_target = move_speed * 0.25
		_steer_obstacles(delta)
		_move(delta)
		if _pig_anim:
			_pig_anim.set_look_target(_look_target)
			_pig_anim.animate(delta)
		return

	match _ai_state:
		AIState.WANDER:
			if _flee_timer > 0.0:
				_ai_state = AIState.FLEE
			else:
				_repath_timer -= delta
				if _repath_timer <= 0.0:
					_pick_new_wander()
				if randf() < delta * 0.25:
					if _pig_anim:
						_pig_anim.clear_look()
					_enter_root()
					return
				var dir := _steer_target - global_position
				dir.y = 0.0
				if dir.length_squared() < 2.0:
					_enter_root()
				else:
					_move_dir = dir.normalized()
					_speed_target = move_speed * randf_range(0.35, 0.75)
		AIState.ROOT:
			if _flee_timer > 0.0:
				_ai_state = AIState.FLEE
			else:
				_root_timer -= delta
				if _root_timer <= 0.0:
					_ai_state = AIState.WANDER
					_pick_new_wander()
		AIState.FLEE:
			if _flee_timer <= 0.0:
				_ai_state = AIState.WANDER
				_pick_new_wander()
	_steer_obstacles(delta)
	_move(delta)
	if _pig_anim:
		_pig_anim.set_look_target(Vector3.ZERO)
		_pig_anim.animate(delta)

func _steer_obstacles(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	_wall_memory_timer = max(_wall_memory_timer - delta, 0.0)
	var fwd: Vector3 = _move_dir if _move_dir.length_squared() > 0.01 else Vector3.FORWARD
	# Scan 3 directions: forward, forward-left, forward-right
	var angles := [0.0, -0.5, 0.5]
	var best_dir: Vector3 = fwd
	var best_idx: int = -1
	for i in range(angles.size()):
		var d: Vector3 = fwd.rotated(Vector3.UP, angles[i])
		# Wall check — high ray phát hiện tường cao (> 1 block), bỏ qua slab thấp
		var high_origin := global_position + Vector3(0, 0.80, 0)
		var high_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(high_origin, high_origin + d * 2.0))
		var blocked := not high_hit.is_empty()
		# Step check — chặn bậc quá cao ko nhảy được
		if not blocked:
			var step_origin := global_position + d * 0.8 + Vector3.UP * 0.60
			var step_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(step_origin, step_origin + Vector3.DOWN * 0.80))
			if not step_hit.is_empty():
				var step_h: float = step_origin.y - (step_hit.position as Vector3).y
				if step_h > 0.65:
					blocked = true
		# Water check
		if not blocked and _water_mgr != null:
			var ahead := global_position + d * 2.5
			ahead.y += 0.1
			if _water_mgr.is_in_water(ahead.x, ahead.z, ahead.y):
				blocked = true
		if not blocked:
			best_dir = d
			best_idx = i
			break
	if best_idx < 0:
		if _wall_memory_timer > 0.0 and _wall_memory.length_squared() > 0.01:
			_move_dir = _wall_memory
		else:
			_move_dir = Vector3(-fwd.z, 0, fwd.x)
		if _ai_state == AIState.WANDER:
			_steer_target = global_position + _move_dir * 4.0
	else:
		if best_idx > 0:
			_wall_memory = best_dir
			_wall_memory_timer = 1.5
		_move_dir = best_dir

func _move(delta: float) -> void:
	var dir := _move_dir
	if _ai_state == AIState.FLEE:
		if dir.length_squared() < 0.01:
			dir = Vector3.FORWARD
	elif dir.length_squared() < 0.01:
		return
	dir = dir.normalized()
	if _turn_smooth.length_squared() < 0.01:
		_turn_smooth = dir
	else:
		_turn_smooth = _turn_smooth.normalized().slerp(dir, delta * 4.0).normalized()
	var final_dir := _turn_smooth
	var spd: float = sprint_speed if _ai_state == AIState.FLEE else _speed_target
	velocity.x = final_dir.x * spd
	velocity.z = final_dir.z * spd

	if is_on_floor() and spd > 0.3:
		var space := get_world_3d().direct_space_state
		if space:
			var eye := global_position + Vector3(0, 0.05, 0)
			var fwd: Vector3 = final_dir if final_dir.length_squared() > 0.01 else velocity.normalized()
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + fwd * 0.6))
			if not hit.is_empty():
				velocity.y = _jump_v

	if velocity.y > 0.0:
		velocity.y -= _grav_rise * delta
	else:
		velocity.y -= _grav_fall * delta

	move_and_slide()
	if final_dir.length_squared() > 0.01:
		var target_angle := atan2(final_dir.x, final_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 5.0)

func take_damage(dmg: int, attacker: Node3D = null, damage_type: int = 0) -> void:
	super.take_damage(dmg, attacker, damage_type)
	if is_alive and attacker:
		_flee_timer = randf_range(3.0, 5.0)
		_ai_state = AIState.FLEE
		var away := global_position - attacker.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			_move_dir = away.normalized()

func _die(_attacker: Node3D = null) -> void:
	super._die(_attacker)
	_roll_loot()

func _roll_loot() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	ItemDatabase.ensure_db()
	var defn: ItemDef = ItemDatabase.items_db.get("raw_pork")
	if defn and randf() < 0.9:
		var vel := Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
		_DroppedItem.spawn(world, defn, global_position, 1, vel, global_position.y)
