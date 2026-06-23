## raptor/raptor_character.gd – Velociraptor Neon (Nhân vật 1)
## Entry point: extends CharacterBase, tạo mesh và animator, delegate animate().

extends CharacterBase
class_name RaptorCharacter

var _mesh: RaptorMesh
var _anim: RaptorAnimator

var _burst_count:   int   = 0
var _burst_elapsed: float = 0.0
const BURST_INTERVAL: float = 0.08
const BURST_SHOTS:    int   = 3

var _r_buff_timer: float = 0.0
var _base_move_speed: float = 0.0
var _base_lmb_cooldown: float = 0.0
const R_BUFF_DURATION: float = 3.0
const R_BUFF_SPEED_MULT: float = 1.35

func _build_character() -> void:
	move_speed   = 5.5
	sprint_speed = 9.5
	jump_height  = 1.4
	attack_duration = 0.40
	_attack2_duration = 0.90
	melee_range  = 1.5
	melee_damage = 10
	lmb_cooldown = 0.6
	q_cooldown   = 1.5
	r_cooldown   = 5.0
	character_name = "Raptor"
	element = Element.DIEN
	_base_move_speed = move_speed
	_base_lmb_cooldown = lmb_cooldown

	# Collision
	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.28; cs.height = 1.10
	col.shape = cs; col.position = Vector3(0, 0.55, 0)
	add_child(col)

	# Mesh
	_mesh = RaptorMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

	# Animator
	_anim = RaptorAnimator.new()
	_anim.setup(_mesh, self)

func _on_primary_attack() -> void:
	_burst_count   = 0
	_burst_elapsed = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _r_buff_timer > 0.0:
		_r_buff_timer = max(_r_buff_timer - delta, 0.0)
		if _r_buff_timer <= 0.0:
			_deactivate_r_buff()
	if _state != State.ATTACK:
		return
	_burst_elapsed += delta
	while _burst_count < BURST_SHOTS and _burst_elapsed >= _burst_count * BURST_INTERVAL:
		_spawn_bullet()
		_burst_count += 1

func _activate_r_buff() -> void:
	_r_buff_timer = R_BUFF_DURATION
	move_speed = _base_move_speed * R_BUFF_SPEED_MULT
	lmb_cooldown = 0.0

func _deactivate_r_buff() -> void:
	move_speed = _base_move_speed
	lmb_cooldown = _base_lmb_cooldown

func _spawn_bullet() -> void:
	var bullet := RaptorBullet.new()
	var muzzle: Vector3 = global_position + Vector3(0, 0.8, 0)
	if _mesh and _mesh.neck:
		muzzle = _mesh.neck.global_position + Vector3(0, 0.05, 0)
	var fire_dir: Vector3 = _aim_dir if _aim_dir.length_squared() > 0.001 else global_transform.basis.z
	get_parent().add_child(bullet)
	bullet.setup(muzzle, fire_dir, self)

func _on_secondary_attack() -> void:
	var mgr: Node = _find_character_manager()
	if mgr == null:
		return
	var targets: Array[Vector3] = []
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != self and ch.is_alive and ch._active:
			var d: float = global_position.distance_to(ch.global_position)
			if d <= 10.0:
				ch.take_damage(75, self)
				targets.append(ch.global_position)
	if targets.size() > 0:
		_activate_r_buff()
	if targets.size() == 0:
		targets.append(global_position + global_transform.basis.z * 5.0)
	var lightning: RaptorLightning = RaptorLightning.new()
	mgr.add_child(lightning)
	lightning.setup(global_position, targets, self)

func _on_show_animation() -> void:
	_attack2_timer = _attack2_duration
	_state = State.DEVOUR

func _animate(delta: float) -> void:
	_anim.animate(delta)
