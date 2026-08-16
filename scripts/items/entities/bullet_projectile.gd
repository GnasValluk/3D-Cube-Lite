class_name BulletProjectile
extends Area3D

## Đạn của súng trường/sniper — bay thẳng cực nhanh, xuyên theo đường sweep,
## tắt khi hết tầm. Không rớt lại item (khác mũi tên nỏ).
##
## Dễ dính địch nhờ: bán kính sweep rộng + "aim-assist" kéo đầu đạn về phía
## địch nằm sát đường bay (trong phạm vi cho phép) thay vì trượt qua.

const HIT_RADIUS: float = 0.16
## Bán kính tìm mục tiêu quanh đầu đạn để bám — chỉ bám trong khoảng cách bước đạn.
const ASSIST_RADIUS: float = 0.6

var _damage: int = 8
var _shooter: Node = null
var _speed: float = 120.0
var _direction: Vector3
var _max_range: float = 40.0
var _dist_traveled: float = 0.0
var _hit_something: bool = false
var _spawn_dist: float = 0.0

var _sweep_shape: SphereShape3D = null

func setup(dir: Vector3, dmg: int, spd: float, max_rng: float, shooter: Node) -> void:
	_direction = dir
	_damage = dmg
	_speed = spd
	_max_range = max_rng
	_shooter = shooter
	look_at(global_position + dir, Vector3.UP)

func _ready() -> void:
	add_to_group("bullets")
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = HIT_RADIUS
	col.shape = shape
	add_child(col)
	_sweep_shape = shape
	monitoring = false

	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = 0.012
	mi.mesh.bottom_radius = 0.012
	mi.mesh.height = 0.22
	mi.mesh.radial_segments = 6
	mi.position = Vector3(0, 0, -0.09)
	mi.rotation_degrees.x = 90
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.30)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.40)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)

	## Đốm tia cuối đầu đạn — sáng hơn để đọc được hướng bay.
	var tip := MeshInstance3D.new()
	tip.mesh = SphereMesh.new()
	tip.mesh.radius = 0.02
	tip.mesh.height = 0.04
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(1.0, 0.92, 0.55)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(1.0, 0.9, 0.5)
	tip_mat.emission_energy_multiplier = 3.0
	tip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tip.material_override = tip_mat
	tip.position = Vector3(0, 0, -0.20)
	add_child(tip)

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
				if _spawn_dist + contact_step < 0.25:
					# Bỏ qua va chạm ngay lúc mới bắn (spawn lùi trước nòng).
					global_position += step
				else:
					global_position += step * maxf(unsafe, 0.0)
					_dist_traveled += contact_step
					_spawn_dist += contact_step
					_hit_something = true
					_resolve_hit(space)
					queue_free()
					return
			else:
				# Đường bay tự do — thử bám tới địch sát đường bay trước khi bay tiếp.
				if _try_assist(space, step):
					return
				global_position += step
		else:
			if _try_assist(space, step):
				return
			global_position += step
	_dist_traveled += step.length()
	_spawn_dist += step.length()
	_spawn_trail()
	if _dist_traveled >= _max_range:
		queue_free()

## Aim-assist: nếu đường bay tự do (không trúng tường) nhưng có địch sống nằm
## trong ASSIST_RADIUS quanh đầu đạn, kéo đạn bám về phía địch ngay trong bước
## di chuyển này — giúp trúng dễ hơn trong gameplay. Trả true nếu đã kết thúc đạn.
func _try_assist(space: PhysicsDirectSpaceState3D, step: Vector3) -> bool:
	var end_pos: Vector3 = global_position + step
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = ASSIST_RADIUS
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, end_pos)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	if _shooter is CollisionObject3D:
		q.exclude = [_shooter.get_rid()]
	var hits := space.intersect_shape(q, 8)
	var nearest: Node3D = null
	var nearest_dist: float = ASSIST_RADIUS + 1.0
	for h in hits:
		var body: Node = h.get("collider")
		if body == null or body == _shooter:
			continue
		if body is CharacterBase and body.is_alive:
			var nb: Node3D = body as Node3D
			var d: float = global_position.distance_to(nb.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = nb
	if nearest == null:
		return false
	var to_target := (nearest.global_position + Vector3(0, 0.4, 0)) - global_position
	var assist_len: float = min(to_target.length(), step.length() * 1.6)
	var assist_step: Vector3 = to_target.normalized() * maxf(assist_len, 0.0)
	# Chỉ bám khi mục tiêu nằm phía trước theo hướng bay trội hơn.
	if to_target.normalized().dot(_direction) < 0.1:
		return false
	global_position += assist_step
	_dist_traveled += assist_step.length()
	_spawn_dist += assist_step.length()
	_hit_something = true
	_resolve_hit(space)
	queue_free()
	return true

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
		_spawn_impact()
		return
	_spawn_impact()

func _spawn_impact() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in 4:
		var mat := MeshBuilder.emit_mat(
			Color(0.95, 0.75, 0.30, 0.7),
			Color(1.0, 0.85, 0.40), 4.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.035
		sph.height = 0.07
		mi.mesh = sph
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = global_position
		mi.position += Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 0.1), 0.25)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
		tw.tween_callback(mi.queue_free).set_delay(0.3)

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	if parent == null or randf() > 0.35:
		return
	var mat := MeshBuilder.emit_mat(
		Color(1.0, 0.8, 0.35, 0.5),
		Color(1.0, 0.9, 0.55), 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.02
	sph.height = 0.04
	mi.mesh = sph
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = global_position - _direction * 0.05
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 0.05), 0.15)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(mi.queue_free).set_delay(0.2)