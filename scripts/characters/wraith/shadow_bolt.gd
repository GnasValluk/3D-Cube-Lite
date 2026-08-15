## wraith/shadow_bolt.gd
## Tia tối do Bóng Đêm bắn ra — viên đạn đen tuyền bay thẳng, chạm player
## (hoặc bất kỳ CharacterBase thù địch khác) gây sát thương, chạm đất/biến
## mất, bay tối đa N mét rồi tự hủy kèm vệt khói đen.

class_name ShadowBolt
extends Area3D

var _damage: int = 5
var _shooter: Node = null
var _speed: float = 18.0
var _direction: Vector3
var _max_range: float = 30.0
var _dist_traveled: float = 0.0
var _hit_something: bool = false
var _trail_timer: float = 0.0
var _life: float = 0.0

func setup(dir: Vector3, dmg: int, shooter: Node, spd: float = 18.0, max_rng: float = 30.0) -> void:
	_direction = dir.normalized()
	_damage = dmg
	_speed = spd
	_max_range = max_rng
	_shooter = shooter
	look_at(global_position + _direction, Vector3.UP)
	body_entered.connect(_on_hit)

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	col.shape = shape
	add_child(col)

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.20
	sphere.height = 0.40
	sphere.radial_segments = 8
	sphere.rings = 4
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.08)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.65, 1.0)
	mat.emission_energy_multiplier = 1.6
	mi.material_override = mat
	add_child(mi)

	# Lõi sáng nhỏ ở giữa viên đạn
	var core := MeshInstance3D.new()
	var core_s := SphereMesh.new()
	core_s.radius = 0.09
	core_s.height = 0.18
	core.mesh = core_s
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.85, 0.92, 1.0)
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.70, 0.85, 1.0)
	core_mat.emission_energy_multiplier = 2.5
	core.material_override = core_mat
	add_child(core)

func _physics_process(delta: float) -> void:
	if _hit_something:
		return
	_life += delta
	global_position += _direction * _speed * delta
	_dist_traveled += _speed * delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.035
		_spawn_trail()
	if _dist_traveled >= _max_range or _life > 4.0:
		queue_free()

func _on_hit(body: Node) -> void:
	if _hit_something:
		return
	if _dist_traveled < 0.3:
		return
	if body == _shooter:
		return
	_hit_something = true
	if body is CharacterBase and body.is_alive:
		body.take_damage(_damage, _shooter, 0)
	_explode()
	queue_free()

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := MeshBuilder.emit_mat(
		Color(0.10, 0.10, 0.18, 0.6),
		Color(0.40, 0.50, 0.80), 3.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.10
	mi.mesh = sph
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = global_position - _direction * 0.08
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.20, 0.20, 0.20), 0.3)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free).set_delay(0.35)

func _explode() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := MeshBuilder.emit_mat(
		Color(0.15, 0.15, 0.25, 0.7),
		Color(0.50, 0.60, 0.90), 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in range(8):
		var sp := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.05
		sph.height = 0.10
		sp.mesh = sph
		sp.material_override = mat
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(sp)
		sp.global_position = global_position
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.8), randf_range(-1, 1)).normalized()
		var dist := 0.4 + randf() * 0.9
		var tw := sp.create_tween()
		tw.tween_property(sp, "global_position", sp.global_position + dir * dist, 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
		tw.tween_callback(sp.queue_free)