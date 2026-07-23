class_name ArrowProjectile
extends Area3D

var _damage: int = 10
var _shooter: Node = null
var _speed: float = 30.0
var _direction: Vector3
var _max_range: float = 50.0
var _dist_traveled: float = 0.0
var _hit_something: bool = false

func setup(dir: Vector3, dmg: int, spd: float, max_rng: float, shooter: Node) -> void:
	_direction = dir
	_damage = dmg
	_speed = spd
	_max_range = max_rng
	_shooter = shooter
	look_at(global_position + dir, Vector3.UP)
	body_entered.connect(_on_hit)

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	col.shape = shape
	add_child(col)

	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = 0.02
	mi.mesh.bottom_radius = 0.04
	mi.mesh.height = 0.35
	mi.mesh.radial_segments = 6
	mi.position = Vector3(0, 0, -0.17)
	mi.rotation_degrees.x = 90
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.40, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.metallic_specular = 0.0
	mi.material_override = mat
	add_child(mi)

	var tip := MeshInstance3D.new()
	tip.mesh = CylinderMesh.new()
	tip.mesh.top_radius = 0.0
	tip.mesh.bottom_radius = 0.035
	tip.mesh.height = 0.10
	tip.mesh.radial_segments = 6
	tip.position = Vector3(0, 0, -0.37)
	tip.rotation_degrees.x = 90
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.65, 0.65, 0.70)
	tip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tip.material_override = tip_mat
	add_child(tip)

	var fletch := MeshInstance3D.new()
	fletch.mesh = BoxMesh.new()
	fletch.mesh.size = Vector3(0.10, 0.02, 0.06)
	fletch.position = Vector3(0, 0, 0.18)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.75, 0.70, 0.55)
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fletch.material_override = fmat
	add_child(fletch)

	var fletch2 := MeshInstance3D.new()
	fletch2.mesh = BoxMesh.new()
	fletch2.mesh.size = Vector3(0.02, 0.10, 0.06)
	fletch2.position = Vector3(0, 0, 0.18)
	fletch2.material_override = fmat
	add_child(fletch2)

func _physics_process(delta: float) -> void:
	if _hit_something:
		return
	var step := _direction * _speed * delta
	global_position += step
	_dist_traveled += step.length()
	if _dist_traveled >= _max_range:
		_drop_arrow()
		queue_free()

func _on_hit(body: Node) -> void:
	if _hit_something:
		return
	if body == _shooter:
		return
	_hit_something = true
	if body is CharacterBase and body.is_alive:
		body.take_damage(_damage, _shooter)
		queue_free()
		return
	_drop_arrow()
	queue_free()

func _drop_arrow() -> void:
	var def := ItemDatabase.items_db.get("mui_ten") as ItemDef
	if def == null:
		return
	var world := get_tree().current_scene
	if world == null:
		return
	DroppedItem.spawn(world, def, global_position, 1)
