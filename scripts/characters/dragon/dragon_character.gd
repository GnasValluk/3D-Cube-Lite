## dragon/dragon_character.gd – Rồng Neon (Nhân vật 2)
## Entry point: extends CharacterBase, tạo mesh và animator, delegate animate().

extends CharacterBase
class_name DragonCharacter

var _mesh: DragonMesh
var _anim: DragonAnimator

func _build_character() -> void:
	move_speed      = 4.8
	sprint_speed    = 8.5
	jump_height     = 1.8
	dash_speed      = 16.0
	attack_duration = 0.55

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

func _animate(delta: float) -> void:
	_anim.animate(delta)
