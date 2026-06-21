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

func _build_character() -> void:
	move_speed   = 5.5
	sprint_speed = 9.5
	jump_height  = 1.4
	attack_duration = 0.40
	_attack2_duration = 0.90

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
	if _state != State.ATTACK:
		return
	_burst_elapsed += delta
	while _burst_count < BURST_SHOTS and _burst_elapsed >= _burst_count * BURST_INTERVAL:
		_spawn_bullet()
		_burst_count += 1

func _spawn_bullet() -> void:
	var bullet := RaptorBullet.new()
	var muzzle: Vector3 = global_position + Vector3(0, 0.8, 0)
	if _mesh and _mesh.neck:
		muzzle = _mesh.neck.global_position + Vector3(0, 0.05, 0)
	var fire_dir: Vector3 = global_transform.basis.z
	var root: Node = get_parent().get_parent()
	if root == null: root = get_parent()
	root.add_child(bullet)
	bullet.setup(muzzle, fire_dir)

func _on_secondary_attack() -> void:
	pass

func _animate(delta: float) -> void:
	_anim.animate(delta)
