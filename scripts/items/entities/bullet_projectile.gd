class_name BulletProjectile
extends Area3D

## Đạn của súng trường/sniper — bay thẳng cực nhanh, xuyên theo đường sweep,
## tắt khi hết tầm. Không rớt lại item (khác mũi tên nỏ).
##
## Dễ dính địch nhờ: bán kính sweep rộng + "aim-assist" kéo đầu đạn về phía
## địch nằm sát đường bay (trong phạm vi cho phép) thay vì trượt qua.

const HIT_RADIUS: float = 0.24
## Bán kính tìm mục tiêu quanh đầu đạn để bám — chỉ bám trong khoảng cách bước đạn.
const ASSIST_RADIUS: float = 1.0
## Bán kính hình cầu "cản cứng" (tường/đất) — nhỏ, bám sát viên đạn để không dính
## va chạm địa hình khi bay sát mặt đất; địch vẫn được bắt nhờ sweep rộng + assist.
const WORLD_RADIUS: float = 0.03
## Bán kính vụ nổ khi trúng địch — địch trong vùng chịu sát thương bằng đạn.
const BLAST_RADIUS: float = 2.0

var _damage: int = 8
var _shooter: Node = null
var _speed: float = 120.0
var _direction: Vector3
var _max_range: float = 40.0
var _dist_traveled: float = 0.0
var _hit_something: bool = false
var _spawn_dist: float = 0.0

var _sweep_shape: SphereShape3D = null
var _world_shape: SphereShape3D = null

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
	var wcol := SphereShape3D.new()
	wcol.radius = WORLD_RADIUS
	_world_shape = wcol
	monitoring = false

	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = 0.02
	mi.mesh.bottom_radius = 0.02
	mi.mesh.height = 0.30
	mi.mesh.radial_segments = 6
	mi.position = Vector3(0, 0, -0.11)
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
	tip.mesh.radius = 0.035
	tip.mesh.height = 0.07
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(1.0, 0.92, 0.55)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(1.0, 0.9, 0.5)
	tip_mat.emission_energy_multiplier = 3.0
	tip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tip.material_override = tip_mat
	tip.position = Vector3(0, 0, -0.26)
	add_child(tip)

func _physics_process(delta: float) -> void:
	if _hit_something:
		return
	var step := _direction * _speed * delta
	var space := get_world_3d().direct_space_state
	if space != null and _world_shape != null:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _world_shape
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
	_spawn_trail(step.length())
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
			# Trúng địch → NỔ: sát thương vùng quanh điểm dính + hiệu ứng nổ.
			_explode_on_target()
			return
		_spawn_impact()
		return
	_spawn_impact()

## Trúng địch: nổ — gây sát thương cho địch quanh điểm nổ + hiệu ứng vụ nổ.
func _explode_on_target() -> void:
	_deal_blast_damage()
	_spawn_explosion_vfx()

func _deal_blast_damage() -> void:
	for ch in _get_characters():
		if ch == _shooter:
			continue
		var offset: Vector3 = global_position - ch.global_position
		offset.y = 0.0
		if offset.length() < BLAST_RADIUS:
			ch.take_damage(_damage, _shooter, 0)

func _get_characters() -> Array:
	var chars: Array = []
	var root := get_tree().current_scene
	if root == null:
		return chars
	_scan_characters(root, chars)
	return chars

func _scan_characters(node: Node, chars: Array) -> void:
	if node is CharacterBase and node.is_alive:
		chars.append(node)
	for i in node.get_child_count():
		_scan_characters(node.get_child(i), chars)

func _spawn_explosion_vfx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Flash sáng cam.
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.1)
	flash.light_energy = 18.0
	flash.omni_range = 7.0
	flash.light_specular = 0.0
	parent.add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.1).timeout.connect(
		func(): if is_instance_valid(flash): flash.queue_free())
	# Quả cầu lửa phình to rồi tắt.
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(1.0, 0.55, 0.12, 0.85)
	ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ball := MeshInstance3D.new()
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.25
	ball_mesh.height = 0.5
	ball.mesh = ball_mesh
	ball.material_override = ball_mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ball)
	ball.global_position = global_position
	var tw := ball.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 4.0, 0.3)
	tw.tween_property(ball_mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(ball.queue_free).set_delay(0.35)
	# Tia lửa bắn ra mọi hướng.
	for i in range(10):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.5 + randf_range(0.0, 0.3), 0.0, 0.7)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.05
		sph.height = 0.1
		mi.mesh = sph
		mi.material_override = mat
		mi.position = Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = global_position
		var t2 := mi.create_tween()
		t2.set_parallel(true)
		t2.tween_property(mi, "position", mi.position * 4.0, 0.25)
		t2.tween_property(mat, "albedo_color:a", 0.0, 0.25)
		t2.tween_callback(mi.queue_free).set_delay(0.3)

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

func _spawn_trail(step_len: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Vệt mờ DÀI kéo về sau theo hướng bay — nối liền theo từng bước để đọc hướng rõ.
	var trail_len: float = minf(step_len + 1.2, 3.4)
	var mat := MeshBuilder.emit_mat(
		Color(0.55, 0.85, 1.0, 0.45),
		Color(0.6, 0.9, 1.0), 5.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.metallic_specular = 0.0
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = trail_len
	cyl.radial_segments = 6
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# Xoay trục dài (Y) của streak theo hướng bay; đặt tâm kéo về sau đạn.
	var dir := _direction.normalized()
	var side := Vector3.UP.cross(dir)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := dir.cross(side).normalized()
	mi.basis = Basis(side, dir, up)
	mi.global_position = global_position - dir * (trail_len * 0.5 + 0.15)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(mi, "scale", Vector3(0.12, 1.0, 0.12), 0.35)
	tw.tween_callback(mi.queue_free).set_delay(0.4)