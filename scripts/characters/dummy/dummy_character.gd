## dummy/dummy_character.gd
## Bia tập bắn – 10000 HP, respawn khi chết.

extends CharacterBase
class_name DummyCharacter

var _mesh_root: Node3D

func _build_character() -> void:
	max_hp = 10000
	hp = 10000
	character_name = "Training Dummy"
	_is_player = false

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	col.shape = box
	col.position = Vector3(0, 1.0, 0)
	add_child(col)

	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	var mat_body := MeshBuilder.emit_mat(
		Color(0.90, 0.05, 0.10),
		Color(1.0, 0.0, 0.15), 4.0)
	MeshBuilder.box(_mesh_root, Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0), mat_body)

	var mat_glow := MeshBuilder.emit_mat(
		Color(0.90, 0.10, 0.15, 0.25),
		Color(1.0, 0.0, 0.10), 2.0)
	MeshBuilder.sphere(_mesh_root, Vector3(0, 1.0, 0), 0.8, mat_glow)

	var mat_ring := MeshBuilder.emit_mat(
		Color(1.0, 0.20, 0.25),
		Color(1.0, 0.10, 0.20), 5.0)
	for i in range(2):
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.7 + i * 0.1
		tor.outer_radius = 0.04
		mi.mesh = tor
		mi.material_override = mat_ring
		mi.position = Vector3(0, 1.0, 0)
		mi.rotation = Vector3(deg_to_rad(90), 0, deg_to_rad(i * 90))
		_mesh_root.add_child(mi)

func _process(delta: float) -> void:
	super._process(delta)
	if is_alive:
		_mesh_root.rotation.y += delta * 0.5

func _die(_attacker: Node3D = null) -> void:
	super._die(_attacker)
	get_tree().create_timer(2.0).timeout.connect(_respawn)

func _respawn() -> void:
	revive()
	global_position = Vector3(0, 3, 0)
	velocity = Vector3.ZERO
