class_name ArrowProjectile
extends Area3D

signal arrow_hit(pos: Vector3)

var _damage: int = 10
var _shooter: Node = null
var _speed: float = 30.0
var _direction: Vector3
var _max_range: float = 50.0
var _dist_traveled: float = 0.0
var _hit_something: bool = false
var _trail_timer: float = 0.0

## Shape dùng cho sweep liên tục (cast_motion) — tránh discrete body_entered
## làm mũi tên "dính" sớm ~1 block khi bay nhanh (step/skin > bán kính).
var _sweep_shape: SphereShape3D = null

func setup(dir: Vector3, dmg: int, spd: float, max_rng: float, shooter: Node) -> void:
	_direction = dir
	_damage = dmg
	_speed = spd
	_max_range = max_rng
	_shooter = shooter
	look_at(global_position + dir, Vector3.UP)

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.20
	col.shape = shape
	add_child(col)
	_sweep_shape = shape
	monitoring = false

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

var _spawn_dist: float = 0.0

func _physics_process(delta: float) -> void:
	if _hit_something:
		return
	var step := _direction * _speed * delta
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _sweep_shape
		q.transform = Transform3D(Basis.IDENTITY, global_position)
		q.motion = step
		q.collide_with_areas = false
		q.collide_with_bodies = true
		if _shooter is CollisionObject3D:
			q.exclude = [_shooter.get_rid()]
		var motion := space.cast_motion(q)
		if motion.size() >= 2:
			var unsafe: float = motion[1]
			if unsafe < 1.0:
				var contact_step: float = step.length() * maxf(unsafe, 0.0)
				if _spawn_dist + contact_step < 0.3:
					# Bỏ qua va chạm ngay lúc mới bắn (spawn lùi trước nòng),
					# tiếp tục bay — tránh dính sát người bắn.
					global_position += step
				else:
					# Dừng CHÍNH XÁC tại điểm chạm (sweep) thay vì để discrete
					# overlap ăn sâu hàng chục cm → nhìn như dính sớm 1 block.
					global_position += step * maxf(unsafe, 0.0)
					_dist_traveled += contact_step
					_spawn_dist += contact_step
					_hit_something = true
					arrow_hit.emit(global_position)
					_resolve_hit(space)
					queue_free()
					return
			else:
				global_position += step
	_dist_traveled += step.length()
	_spawn_dist += step.length()
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.03
		_spawn_trail()
	if _dist_traveled >= _max_range:
		_drop_arrow()
		queue_free()

func _resolve_hit(space: PhysicsDirectSpaceState3D) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sweep_shape
	q.transform = Transform3D(Basis.IDENTITY, global_position)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	if _shooter is CollisionObject3D:
		q.exclude = [_shooter.get_rid()]
	var hits := space.intersect_shape(q, 8)
	for h in hits:
		var body: Node = h.get("collider")
		if body == null or body == _shooter:
			continue
		if body is CharacterBase and body.is_alive:
			body.take_damage(_damage, _shooter, 0)
		else:
			_drop_arrow()
		return
	_drop_arrow()

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := MeshBuilder.emit_mat(
		Color(0.75, 0.70, 0.55, 0.6),
		Color(0.90, 0.85, 0.70), 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	mi.mesh = sph
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = global_position - _direction * 0.08

	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.15, 0.15, 0.15), 0.35)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(mi.queue_free).set_delay(0.4)

func _drop_arrow() -> void:
	var def := ItemDatabase.items_db.get("arrow") as ItemDef
	if def == null:
		return
	var world := get_tree().current_scene
	if world == null:
		return
	DroppedItem.spawn(world, def, global_position, 1)
