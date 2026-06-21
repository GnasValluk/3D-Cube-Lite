## dragon/dragon_character.gd – Rồng Neon (Nhân vật 2)
## LMB = Khè lửa + bắn fireball
## RMB = Cuối xuống ăn xác (Devour)

extends CharacterBase
class_name DragonCharacter

var _mesh: DragonMesh
var _anim: DragonAnimator

# Thời điểm trong animation để bắn fireball (giây sau khi bắt đầu khè)
const FIRE_SPAWN_TIME := 0.30

var _fire_spawned: bool = false   # tránh spam

func _build_character() -> void:
	move_speed       = 4.8
	sprint_speed     = 8.5
	jump_height      = 1.8
	dash_speed       = 16.0
	attack_duration  = 0.65   # thời gian khè lửa
	_attack2_duration = 0.80  # thời gian devour

	# Collision
	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.42; cs.height = 1.30
	col.shape = cs; col.position = Vector3(0, 0.65, 0)
	add_child(col)

	# Mesh
	_mesh = DragonMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

	# Animator
	_anim = DragonAnimator.new()
	_anim.setup(_mesh, self)

# ── LMB: Khè lửa → reset fire_spawned flag ───────────────────────────────────
func _on_primary_attack() -> void:
	_fire_spawned = false

# ── RMB: Devour – không cần gì thêm ở đây ────────────────────────────────────
func _on_secondary_attack() -> void:
	pass

# ── Spawn fireball vào đúng thời điểm trong animation ────────────────────────
func _physics_process(delta: float) -> void:
	# Gọi base trước
	super._physics_process(delta)
	# Spawn fireball khi đã qua FIRE_SPAWN_TIME trong animation khè
	if _state == State.ATTACK and not _fire_spawned:
		var elapsed: float = attack_duration - _attack_timer
		if elapsed >= FIRE_SPAWN_TIME:
			_spawn_fireball()
			_fire_spawned = true

func _spawn_fireball() -> void:
	var fb := DragonFireball.new()

	# Tính forward từ rotation.y trực tiếp — tránh nhầm lẫn basis convention
	# sin/cos của rotation.y cho vector nhìn về phía nhân vật đang hướng
	var fire_dir: Vector3 = Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()

	# Vị trí miệng: offset về phía trước + lên cao
	var mouth_pos: Vector3 = global_position + Vector3(0, 1.4, 0) + fire_dir * 0.8
	if _mesh and _mesh.head_pivot:
		mouth_pos = _mesh.head_pivot.global_position + fire_dir * 0.6

	# Spawn vào scene root
	var scene_root: Node = get_parent().get_parent()
	if scene_root == null:
		scene_root = get_parent()
	scene_root.add_child(fb)
	fb.setup(mouth_pos, fire_dir)

func _animate(delta: float) -> void:
	_anim.animate(delta)
