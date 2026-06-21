## raptor/raptor_character.gd – Velociraptor Neon (Nhân vật 1)
## Entry point: extends CharacterBase, tạo mesh và animator, delegate animate().

extends CharacterBase
class_name RaptorCharacter

var _mesh: RaptorMesh
var _anim: RaptorAnimator

func _build_character() -> void:
	move_speed   = 5.5
	sprint_speed = 9.5
	jump_height  = 1.4

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

func _animate(delta: float) -> void:
	_anim.animate(delta)
