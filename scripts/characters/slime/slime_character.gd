## slime/slime_character.gd
## Sinh vật thù địch đầu tiên: Slime Xanh Lá (Green Slime).
## Nhảy lò cò đuổi theo player, cơ chế squash/stretch khi nhảy & tiếp đất,
## tách đàn khi chết (Lớn→2-4 Vừa, Vừa→2-3 Nhỏ), drop Slimeball.

extends CharacterBase
class_name SlimeCharacter

enum SlimeSize { SMALL, MEDIUM, LARGE }

@export var slime_size: int = SlimeSize.MEDIUM

const SIZE_HP: Array[int]    = [6, 12, 24]
const SIZE_ATK: Array[int]   = [2, 4, 8]
const SIZE_SPEED: Array[float] = [2.4, 3.4, 4.2]
const SIZE_SCALE: Array[float] = [0.5, 1.0, 2.0]

const AGGRO_RANGE: float = 14.0
const ATTACK_RANGE: float = 1.6
const ATTACK_COOLDOWN: float = 1.0
const HOP_COOLDOWN: float = 0.9

const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _ExpOrb = preload("res://scripts/items/entities/experience_orb.gd")
const EXP_DROP_RATE: float = 0.07

var _mesh: SlimeMesh
var _home: Vector3 = Vector3.ZERO
var _player: Node3D = null
var _hop_cd: float = 0.0
var _attack_cd: float = 0.0
var _target_dir: Vector3 = Vector3.FORWARD
var _was_on_floor_ai: bool = false

func _init() -> void:
	show_world_hp_bar = true

func _build_character() -> void:
	_is_player = false
	character_name = "Green Slime"
	mob_bonus_lv = 2
	level = compute_level()
	var smult: float = get_stat_mult()
	max_hp = maxi(1, int(SIZE_HP[slime_size] * smult))
	hp = max_hp
	move_speed = SIZE_SPEED[slime_size] * smult
	sprint_speed = move_speed
	acceleration = 30.0
	friction = 8.0
	defense = 0
	attack_power = SIZE_ATK[slime_size]
	jump_height = 1.0
	jump_time_rise = 0.30
	jump_time_fall = 0.18
	melee_range = 0.4
	hit_radius = 0.34 * SIZE_SCALE[slime_size]
	_world_hp_enabled = true

	var sc: float = SIZE_SCALE[slime_size]
	scale = Vector3(sc, sc, sc)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 0.72
	col.shape = cap
	col.position = Vector3(0, 0.36, 0)
	add_child(col)

	_mesh = SlimeMesh.new()
	_mesh.show_props = (slime_size == SlimeSize.LARGE)
	_mesh.build(self)
	_rig = _mesh.rig

func _ready() -> void:
	super._ready()
	_home = global_position
	add_to_group("slime")
	_target_dir = -global_transform.basis.z

func _find_player() -> Node3D:
	var world := get_tree().current_scene
	if world == null:
		return null
	var mgr := world.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		return mgr.get_current_character()
	return null

func _read_input() -> Vector3:
	return _target_dir

func _animate(delta: float) -> void:
	if not is_alive:
		return
	_hop_cd = max(_hop_cd - delta, 0.0)
	_attack_cd = max(_attack_cd - delta, 0.0)

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()

	var attacking := false
	if _player and is_instance_valid(_player) and _player.get("is_alive"):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist < AGGRO_RANGE:
			if dist > 0.01:
				_target_dir = to_player.normalized()
			if dist < ATTACK_RANGE and _attack_cd <= 0.0:
				_attack_cd = ATTACK_COOLDOWN
				_player.take_damage(attack_power, self)
				SFXManager.play_slime_attack()
				attacking = true
			# Nhảy lò cò đuổi theo
			if is_on_floor() and _hop_cd <= 0.0:
				_jbuf = JUMP_BUFFER
				_coyote = COYOTE_TIME
				_hop_cd = HOP_COOLDOWN + randf_range(-0.2, 0.2)
				_sy_tgt = 0.72  # squash trước khi bật
				attacking = true
	else:
		# Lang thang chậm — không nhảy
		_target_dir = _target_dir.lerp(Vector3(sin(_time * 0.6), 0, cos(_time * 0.6)), delta * 0.5)

	# Biểu cảm miệng
	if _mesh:
		_mesh.set_mouth_open(attacking)

	# Phát hiện tiếp đất → splash + vài cú nảy nhỏ + hạt gel
	if is_on_floor():
		if not _was_on_floor_ai:
			_land_splash()
			if _player and is_instance_valid(_player) and global_position.distance_to(_player.global_position) < AGGRO_RANGE:
				_bounce_chain()
	_was_on_floor_ai = is_on_floor()

## Chuỗi nảy nhỏ khi đáp đất (2-3 nhịp) — chỉ khi đang đuổi theo
func _bounce_chain() -> void:
	var bounces: int = randi_range(2, 3)
	for i in range(bounces):
		get_tree().create_timer(0.14 * (i + 1)).timeout.connect(func():
			if is_alive and is_inside_tree() and is_on_floor():
				velocity.y = _jump_v * (0.5 - i * 0.12)
				_sy_tgt = 0.8
		)

## Văng hạt gel xanh khi tiếp đất / khi chết
func _spawn_gel_burst(count: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.90, 0.40, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.75, 0.30)
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.10
	for k in range(count):
		var sp := MeshInstance3D.new()
		sp.mesh = sphere
		sp.material_override = mat
		parent.add_child(sp)
		sp.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
		var dir := Vector3(randf_range(-1, 1), randf_range(0.4, 1.2), randf_range(-1, 1)).normalized()
		var dist := 0.5 + randf() * 1.2
		var tw := create_tween()
		tw.tween_property(sp, "global_position", sp.global_position + dir * dist, 0.5).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "scale", Vector3.ZERO, 0.5)
		tw.tween_callback(sp.queue_free)

## VFX nở ra khi tách đàn — chỉ visual, KHÔNG đụng scale của body
## (tránh basis singular với Jolt và tránh reset scale theo size)
func _spawn_character_vfx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var col := Color(0.6, 0.95, 0.5)
	var pos := global_position
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = col
	sphere_mat.albedo_color.a = 0.0
	sphere_mat.emission_enabled = true
	sphere_mat.emission = col * 1.5
	sphere_mat.emission.a = 0.0
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.1
	sph.height = 0.2
	sphere.mesh = sph
	sphere.material_override = sphere_mat
	parent.add_child(sphere)
	sphere.global_position = pos + Vector3(0, 0.8, 0)
	var sph_tw := create_tween()
	sph_tw.tween_property(sphere_mat, "albedo_color:a", 0.9, 0.15)
	sph_tw.parallel().tween_property(sphere_mat, "emission:a", 0.8, 0.15)
	sph_tw.parallel().tween_property(sphere, "scale", Vector3(8.0, 8.0, 8.0), 0.25).set_ease(Tween.EASE_OUT)
	sph_tw.tween_interval(0.15)
	sph_tw.tween_property(sphere_mat, "albedo_color:a", 0.0, 0.3)
	sph_tw.parallel().tween_property(sphere_mat, "emission:a", 0.0, 0.3)
	sph_tw.parallel().tween_property(sphere, "scale", Vector3(12.0, 12.0, 12.0), 0.3).set_ease(Tween.EASE_OUT)
	sph_tw.tween_callback(sphere.queue_free)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = col
	spark_mat.emission_enabled = true
	spark_mat.emission = col * 2.0
	for k in range(12):
		var sp := MeshInstance3D.new()
		var ss := SphereMesh.new()
		ss.radius = 0.05
		ss.height = 0.1
		sp.mesh = ss
		sp.material_override = spark_mat
		parent.add_child(sp)
		sp.global_position = pos + Vector3(0, 0.8, 0)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.5, 1.0), randf_range(-1, 1)).normalized()
		var dist := 1.0 + randf() * 2.5
		var st := create_tween()
		st.tween_property(sp, "global_position", sp.global_position + dir * dist, 0.6).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(sp, "scale", Vector3.ZERO, 0.6)
		st.tween_callback(sp.queue_free)

func _land_splash() -> void:
	if slime_size == SlimeSize.LARGE:
		SFXManager.play_slime_big()
		_spawn_gel_burst(8)
	else:
		SFXManager.play_slime_small()
		_spawn_gel_burst(5)

func take_damage(dmg: int, attacker: Node3D = null, damage_type: int = 0) -> void:
	super.take_damage(dmg, attacker, damage_type)
	if is_alive and _mesh:
		_mesh.set_mouth_open(false)  # bĩu môi khi bị đánh

func _roll_exp_drop() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	if randf() < EXP_DROP_RATE:
		_ExpOrb.spawn(world, global_position, global_position.y)

func _roll_loot() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	ItemDatabase.ensure_db()
	var defn: ItemDef = ItemDatabase.items_db.get("slime_ball")
	if defn and randf() < 0.9 * get_rate_mult():
		var count := 1
		if slime_size == SlimeSize.LARGE:
			count = randi_range(2, 3)
		elif slime_size == SlimeSize.MEDIUM:
			count = randi_range(1, 2)
		var vel := Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
		_DroppedItem.spawn(world, defn, global_position, count, vel, global_position.y)

func _spawn_children(child_size: int) -> void:
	var count: int = randi_range(2, 4) if slime_size == SlimeSize.LARGE else randi_range(2, 3)
	var parent := get_parent()
	if parent == null:
		return
	for i in range(count):
		var child := SlimeCharacter.new()
		child.slime_size = child_size
		parent.add_child(child)
		var ang := randf_range(0.0, TAU)
		var dist := 0.8 + randf() * 1.2
		child.global_position = global_position + Vector3(cos(ang) * dist, 0.4, sin(ang) * dist)
		child.call_deferred("_spawn_character_vfx")

func _die(_attacker: Node3D = null) -> void:
	# Tách đàn trước: Lớn → Vừa, Vừa → Nhỏ
	if slime_size == SlimeSize.LARGE:
		_spawn_children(SlimeSize.MEDIUM)
		SFXManager.play_slime_big()
		_spawn_gel_burst(14)
	elif slime_size == SlimeSize.MEDIUM:
		_spawn_children(SlimeSize.SMALL)
		SFXManager.play_slime_small()
		_spawn_gel_burst(8)
	else:
		SFXManager.play_slime_small()
		_spawn_gel_burst(6)
	_roll_loot()
	_roll_exp_drop()
	super._die(_attacker)
