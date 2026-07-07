## fish/fish_animator.gd
## Animation vẫy đuôi, vây bên, thân uốn — hoàn toàn dựa vào sin wave.

class_name FishAnimator

var mesh: FishMesh
var base: CharacterBase

var _swim_cycle: float = 0.0
var _idle_cycle: float = 0.0

func setup(m: FishMesh, b: CharacterBase) -> void:
	mesh = m
	base = b

func animate(delta: float) -> void:
	if mesh == null or base == null:
		return
	var speed := base.velocity.length()
	if speed > 0.2:
		_swim(delta, speed)
	else:
		_idle(delta)

func _swim(delta: float, speed: float) -> void:
	_swim_cycle += delta * (6.0 + speed * 1.2)
	var swing := sin(_swim_cycle)
	if mesh.body:
		mesh.body.rotation.y = lerp(mesh.body.rotation.y, swing * 0.08, delta * 8.0)
	if mesh.tail:
		mesh.tail.rotation.y = lerp(mesh.tail.rotation.y, swing * 0.55, delta * 12.0)
	if mesh.fin_l:
		mesh.fin_l.rotation.z = lerp(mesh.fin_l.rotation.z, -swing * 0.20, delta * 10.0)
	if mesh.fin_r:
		mesh.fin_r.rotation.z = lerp(mesh.fin_r.rotation.z,  swing * 0.20, delta * 10.0)
	if mesh.fin_top:
		mesh.fin_top.rotation.z = sin(_swim_cycle * 2.0) * 0.05

func _idle(delta: float) -> void:
	_idle_cycle += delta * 1.5
	var drift := sin(_idle_cycle)
	if mesh.tail:
		mesh.tail.rotation.y = lerp(mesh.tail.rotation.y, drift * 0.18, delta * 4.0)
	if mesh.body:
		mesh.body.rotation.y = lerp(mesh.body.rotation.y, drift * 0.03, delta * 3.0)
	if mesh.fin_l:
		mesh.fin_l.rotation.z = lerp(mesh.fin_l.rotation.z, -drift * 0.08, delta * 3.0)
	if mesh.fin_r:
		mesh.fin_r.rotation.z = lerp(mesh.fin_r.rotation.z,  drift * 0.08, delta * 3.0)
	if mesh.rig:
		mesh.rig.position.y = sin(_idle_cycle * 0.8) * 0.02
