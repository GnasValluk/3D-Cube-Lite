## crab/mud_crab_character.gd
## Sinh vật "Cua Bùn rừng ngập mặn" — passive, lang thang chậm, chỉ tránh đáng
## (giống cá/heo). Được đưa về CharacterBase để NHẬN SÁT THƯợNG từ mọi nguồn:
## melee (kiếm/rìu/...), bắn súng/tên, ném Kích Sắn — chứ không phải prop
## nên không bị bỏ qua bởi projectile. Chết sẽ rơi "Thịt Cua Bùn".
##
## LƯU Ý: trước đây nó là MudCrabProp (DestroyableProp); melee mới phá vỡ prop
## qua try_destroy() — nhưng bullet/ranged không bao giờ đánh đáp được, tạo cảm
## giác "cua bùn không nhận sát thương". Chuyển thành sinh vật để toàn bộ hệ
## damage (melee + ranged + halberd) áp dụng đồng đều.

extends CharacterBase
class_name MudCrabCharacter

const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _ExpOrb = preload("res://scripts/items/entities/experience_orb.gd")

const CRAB_HP: int = 5
const CRAB_SCALE: float = 1.0
const WANDER_RADIUS: float = 4.0

var _legs: Array[Node3D] = []
var _claws: Array[Node3D] = []
var _leg_offsets: Array[Vector3] = []
var _leg_phases: Array[float] = []
var _claw_phases: Array[float] = []

var _bob_timer: float = 0.0
var _move_timer: float = 0.0
var _move_dir: Vector3 = Vector3.ZERO
var _moving: bool = false

var _base_move_speed: float = 1.2
var _home: Vector3 = Vector3.ZERO
var _target_dir: Vector3 = Vector3.FORWARD

func _init() -> void:
	show_world_hp_bar = true

func _build_character() -> void:
	_is_player = false
	character_name = "Cua Bùn"
	mob_bonus_lv = 0
	level = compute_level()
	var smult: float = get_stat_mult()
	max_hp = maxi(1, int(CRAB_HP * smult))
	hp = max_hp
	_base_move_speed = 1.2 * smult
	move_speed = _base_move_speed
	sprint_speed = move_speed
	acceleration = 5.0
	friction = 6.0
	defense = 0
	attack_power = 0
	melee_range = 0.3
	hit_radius = 0.5
	jump_height = 0.5
	jump_time_rise = 0.18
	jump_time_fall = 0.20
	_world_hp_enabled = true

	var sc: float = CRAB_SCALE
	scale = Vector3(sc, sc, sc)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.6
	col.shape = cap
	col.position = Vector3(0, 0.3, 0)
	add_child(col)

	var rig := Node3D.new()
	rig.name = "_Rig"
	add_child(rig)
	_rig = rig
	_build_crab_mesh(rig)

func _ready() -> void:
	super._ready()
	_home = global_position
	add_to_group("crab")

func _read_input() -> Vector3:
	return _target_dir

func _animate(delta: float) -> void:
	if not is_alive:
		return
	_bob_timer += delta
	var t := _VoxelShared.time_sec()
	if _bob_timer > 0.4:
		_bob_timer = 0.0
		var s := sin(t * 3.0 + float(get_instance_id()) * 0.1)
		rotation.z = s * 0.06
	# Lang thang chậm: đi ít, dừng nhiều, trở về nhà khi xa quá xa
	var to_home := _home - global_position
	to_home.y = 0.0
	var home_dist := to_home.length()
	if home_dist > WANDER_RADIUS:
		_target_dir = to_home.normalized()
		_move_dir = _target_dir
		_moving = true
		_move_timer = randf_range(0.8, 1.5)
	elif _move_timer <= 0.0:
		if _moving:
			_target_dir = Vector3.ZERO
			_moving = false
			_move_timer = randf_range(1.2, 2.5)
		else:
			_move_timer = randf_range(2.0, 4.0)
			if randf() < 0.45:
				var a := randf() * TAU
				_move_dir = Vector3(cos(a), 0, sin(a))
				_moving = true
			_target_dir = _move_dir
	if _moving:
		_target_dir = _move_dir
	else:
		_target_dir = _target_dir.lerp(Vector3.ZERO, delta * 2.0)
	_move_timer -= delta
	move_speed = _base_move_speed * (0.4 if not _moving else 1.0)
	sprint_speed = move_speed

	# Chân/càng sống động (chỉ gần camera)
	if _VoxelShared.sway_active(global_position, 40.0):
		for i in _legs.size():
			var base: Vector3 = _leg_offsets[i]
			var ph: float = _leg_phases[i] + t * 4.0
			var swing := sin(ph)
			var leg := _legs[i]
			leg.position = base + Vector3(swing * 0.025, absf(swing) * 0.025, 0.0)
			leg.rotation = Vector3(swing * 0.4, 0.0, 0.0)
		for i in _claws.size():
			var c := _claws[i]
			var ph := _claw_phases[i]
			var pinch := sin(t * 3.5 + ph) * 0.35
			c.rotation = Vector3(0.0, pinch * 0.6, 0.0)
	elif not is_on_floor():
		# nh�ỏ về 0 khi ra khỏi camera để tránh tween lỗi
		for i in _legs.size():
			_legs[i].position = _leg_offsets[i]
			_legs[i].rotation = Vector3.ZERO
		for c in _claws.size():
			_claws[c].rotation = Vector3.ZERO

func take_damage(dmg: int, attacker: Node3D = null, damage_type: int = 0) -> void:
	super.take_damage(dmg, attacker, damage_type)
	if is_alive and _rig:
		_spawn_splash_vfx()

func _die(_attacker: Node3D = null) -> void:
	# Rơi thịt cua + hơi exp khi chết
	var world := get_tree().current_scene if get_tree() else null
	if world and world is Node3D:
		ItemDatabase.ensure_db()
		var def: ItemDef = ItemDatabase.items_db.get("mud_crab")
		if def != null:
			_DroppedItem.spawn(world, def, global_position, 1,
				Vector3(randf_range(-1.2, 1.2), randf_range(2.2, 3.2), randf_range(-1.2, 1.2)),
				global_position.y)
		if randf() < 0.5:
			_ExpOrb.spawn(world, global_position, global_position.y)
	super._die(_attacker)

## ── Mesh voxel cua bùn — thân mai + 8 chân + 2 cặp càng + mắt ──
func _build_crab_mesh(root: Node3D) -> void:
	var col_shell := Color(0.44, 0.22, 0.12)
	var col_leg := Color(0.33, 0.17, 0.10)
	var col_claw := Color(0.52, 0.26, 0.14)
	var col_eye := Color(0.08, 0.06, 0.05)

	_add_box(root, Vector3(0.0, 0.12, 0.0), Vector3(0.30, 0.16, 0.26), col_shell)
	_add_box(root, Vector3(0.0, 0.16, 0.0), Vector3(0.24, 0.06, 0.20), col_shell)
	_add_box(root, Vector3(0.0, 0.08, 0.14), Vector3(0.22, 0.10, 0.10), col_shell.darkened(0.12))

	for side in [-1.0, 1.0]:
		for li in range(4):
			var z_off: float = -0.16 + li * 0.10
			var reach: float = 0.11 + (li % 2) * 0.03
			_legs.append(_add_box(root, Vector3(side * 0.20, 0.06, z_off), Vector3(0.04, 0.04, 0.03), col_leg))
			_legs.append(_add_box(root, Vector3(side * (0.20 + reach), 0.015, z_off), Vector3(0.04, 0.03, 0.03), col_leg))
		_add_box(root, Vector3(side * 0.22, 0.10, -0.16), Vector3(0.05, 0.05, 0.22), col_leg)
		var c1 := _add_box(root, Vector3(side * 0.22, 0.17, -0.26), Vector3(0.09, 0.10, 0.06), col_claw)
		var c2 := _add_box(root, Vector3(side * 0.22, 0.17, -0.32), Vector3(0.06, 0.05, 0.06), col_claw.darkened(0.1))
		_claws.append(c1)
		_claws.append(c2)
	_claw_phases.resize(_claws.size())
	for i in _claws.size():
		_claw_phases[i] = float(i) / max(1.0, float(_claws.size())) * TAU

	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(side * 0.10, 0.24, 0.02), Vector3(0.03, 0.06, 0.03), col_leg)
		_add_box(root, Vector3(side * 0.10, 0.29, 0.02), Vector3(0.055, 0.055, 0.055), col_eye)

	_reset_leg_offsets()

func _reset_leg_offsets() -> void:
	_leg_offsets.resize(_legs.size())
	_leg_phases.resize(_legs.size())
	for i in _legs.size():
		_leg_offsets[i] = _legs[i].position

func _add_box(root: Node, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.05
	mat.roughness = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	root.add_child(mi)
	return mi

func _spawn_splash_vfx() -> void:
	var p := global_position + Vector3(0, 0.2, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.44, 0.22, 0.12, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.44, 0.22, 0.12)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s := SphereMesh.new()
	s.radius = 0.08
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = p
	get_tree().create_timer(0.2).timeout.connect(mi.queue_free)