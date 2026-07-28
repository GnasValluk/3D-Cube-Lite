class_name PigAnimator

var _m: PigMesh
var _body: CharacterBody3D
var _phase: float = 0.0
var _look_target: Vector3 = Vector3.ZERO
var _head_turn: float = 0.0

func setup(m: PigMesh, body: CharacterBody3D) -> void:
	_m = m
	_body = body

func set_look_target(target: Vector3) -> void:
	_look_target = target

func clear_look() -> void:
	_look_target = Vector3.ZERO

func animate(delta: float) -> void:
	if _m == null or _m.rig == null:
		return
	_phase += delta * 5.0
	if not _body.get("is_alive"):
		_m.rig.rotation.x = lerp(_m.rig.rotation.x, 1.5, delta * 2.0)
		_m.rig.rotation.z = lerp(_m.rig.rotation.z, 0.3, delta * 2.0)
		return
	if _body.get("_underwater"):
		_swim_anim(delta)
		return
	var speed := _body.velocity.length()
	if speed > 0.3:
		_walk(delta)
	else:
		_idle(delta)
	_tail_wag(delta)
	_ear_flick(delta)
	_update_look_at(delta)

func _swim_anim(delta: float) -> void:
	var s := sin(_phase * 1.5)
	_m.pivot_leg_fl.rotation.x = lerp(_m.pivot_leg_fl.rotation.x, sin(_phase * 1.5) * 0.8, delta * 10.0)
	_m.pivot_leg_br.rotation.x = lerp(_m.pivot_leg_br.rotation.x, sin(_phase * 1.5) * 0.8, delta * 10.0)
	_m.pivot_leg_fr.rotation.x = lerp(_m.pivot_leg_fr.rotation.x, sin(_phase * 1.5 + PI) * 0.8, delta * 10.0)
	_m.pivot_leg_bl.rotation.x = lerp(_m.pivot_leg_bl.rotation.x, sin(_phase * 1.5 + PI) * 0.8, delta * 10.0)
	_m.pivot_head.rotation.x = lerp(_m.pivot_head.rotation.x, -0.35, delta * 4.0)
	_m.rig.position.y = lerp(_m.rig.position.y, sin(_phase * 1.5) * 0.04, delta * 6.0)
	_tail_wag(delta)
	_ear_flick(delta)
	_update_look_at(delta)

func _walk(delta: float) -> void:
	_m.pivot_leg_fl.rotation.x = lerp(_m.pivot_leg_fl.rotation.x, sin(_phase) * 0.65, delta * 10.0)
	_m.pivot_leg_br.rotation.x = lerp(_m.pivot_leg_br.rotation.x, sin(_phase) * 0.65, delta * 10.0)
	_m.pivot_leg_fr.rotation.x = lerp(_m.pivot_leg_fr.rotation.x, sin(_phase + PI) * 0.65, delta * 10.0)
	_m.pivot_leg_bl.rotation.x = lerp(_m.pivot_leg_bl.rotation.x, sin(_phase + PI) * 0.65, delta * 10.0)
	_m.rig.position.y = lerp(_m.rig.position.y, abs(sin(_phase)) * 0.05, delta * 8.0)
	_m.pivot_head.rotation.x = lerp(_m.pivot_head.rotation.x, -0.10 + sin(_phase * 0.5) * 0.08, delta * 6.0)

func _idle(delta: float) -> void:
	_m.pivot_leg_fl.rotation.x = lerp(_m.pivot_leg_fl.rotation.x, 0.0, delta * 6.0)
	_m.pivot_leg_fr.rotation.x = lerp(_m.pivot_leg_fr.rotation.x, 0.0, delta * 6.0)
	_m.pivot_leg_bl.rotation.x = lerp(_m.pivot_leg_bl.rotation.x, 0.0, delta * 6.0)
	_m.pivot_leg_br.rotation.x = lerp(_m.pivot_leg_br.rotation.x, 0.0, delta * 6.0)
	_m.pivot_head.rotation.x = lerp(_m.pivot_head.rotation.x, sin(_phase * 0.3) * 0.05, delta * 3.0)
	_m.pivot_head.rotation.z = lerp(_m.pivot_head.rotation.z, sin(_phase * 0.2) * 0.03, delta * 3.0)
	_m.rig.position.y = lerp(_m.rig.position.y, 0.0, delta * 4.0)

func _tail_wag(delta: float) -> void:
	var wag := sin(_phase * 1.5) * 0.6
	_m.pivot_tail.rotation.y = lerp(_m.pivot_tail.rotation.y, wag, delta * 8.0)
	_m.pivot_tail.rotation.x = lerp(_m.pivot_tail.rotation.x, 0.5 + sin(_phase * 1.2) * 0.2, delta * 6.0)
	_m.pivot_tail.rotation.z = lerp(_m.pivot_tail.rotation.z, sin(_phase * 1.5) * 0.2, delta * 6.0)

func _ear_flick(delta: float) -> void:
	var flick := sin(_phase * 0.7) * 0.4
	_m.pivot_ear_l.rotation.x = lerp(_m.pivot_ear_l.rotation.x, flick * 0.5, delta * 4.0)
	_m.pivot_ear_l.rotation.z = lerp(_m.pivot_ear_l.rotation.z, flick, delta * 4.0)
	_m.pivot_ear_r.rotation.x = lerp(_m.pivot_ear_r.rotation.x, -flick * 0.5, delta * 4.0)
	_m.pivot_ear_r.rotation.z = lerp(_m.pivot_ear_r.rotation.z, -flick, delta * 4.0)

func _update_look_at(delta: float) -> void:
	if _look_target == Vector3.ZERO:
		_head_turn = lerp(_head_turn, 0.0, delta * 4.0)
	else:
		var body_pos := _body.global_position
		var to_target := _look_target - body_pos
		var fwd := -_body.global_transform.basis.z
		var flat_target := Vector3(to_target.x, 0.0, to_target.z).normalized()
		var flat_fwd := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var dot := clampf(flat_fwd.dot(flat_target), -1.0, 1.0)
		var angle_h := acos(dot)
		var cross_h := flat_fwd.cross(flat_target)
		if cross_h.y < 0.0:
			angle_h = -angle_h
		_head_turn = lerp(_head_turn, clampf(angle_h, -1.2, 1.2), delta * 6.0)
	_m.pivot_head.rotation.y = lerp(_m.pivot_head.rotation.y, _head_turn, delta * 8.0)
