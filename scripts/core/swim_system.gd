extends RefCounted

const BUOYANCY: float = 2.5
const SURFACE_FLOAT_SPEED: float = 1.0

static func swim_physics(character: CharacterBase, delta: float) -> void:
	var dir := character._read_input()
	# Dưới lòng nước ấn "chạy nhanh" → chuyển sang bơi (SWIM) + bơi nhanh hơn
	var sprinting: bool = character._is_player and Input.is_action_pressed("sprint")
	var spd: float = character.move_speed * (0.85 if sprinting else 0.55) * character.get_speed_multiplier()
	var accel: float = character.acceleration * 0.6
	var frict: float = character.friction * 0.5

	var wants_jump: bool = character._jbuf > 0.0 and character._swim_jump_cd <= 0.0 and character.can_jump()
	character._jbuf = 0.0
	character._swim_jump_cd = max(character._swim_jump_cd - delta, 0.0)

	if wants_jump:
		character.velocity.y = character._jump_v * 0.7
		character._swim_jump_cd = 0.6
	elif character._is_player and Input.is_action_pressed("jump"):
		if character.global_position.y < -0.7:
			character.velocity.y = 4.0
		else:
			character.velocity.y = 7.0
	else:
		character.velocity.y += (BUOYANCY - 3.0) * delta
		if character.global_position.y > 0.3 and character.velocity.y > 0.0:
			character.velocity.y = move_toward(character.velocity.y, 0.0, SURFACE_FLOAT_SPEED * delta)

	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		character.velocity.x = move_toward(character.velocity.x, dir.x * spd, accel * delta)
		character.velocity.z = move_toward(character.velocity.z, dir.z * spd, accel * delta)
		character.rotation.y = lerp_angle(character.rotation.y, atan2(dir.x, dir.z), delta * 10.0)
		if character._attack_timer <= 0.0:
			character._state = CharacterBase.State.SWIM if sprinting else CharacterBase.State.WALK
	else:
		character.velocity.x = move_toward(character.velocity.x, 0.0, frict * delta)
		character.velocity.z = move_toward(character.velocity.z, 0.0, frict * delta)
		if character._attack_timer <= 0.0:
			character._state = CharacterBase.State.IDLE

	character.move_and_slide()
	character._animate(delta)
