class_name PlayerAnimator

var walk_cycle_speed: float = 6.5
var sprint_cycle_mult: float = 1.6
var idle_breathe_speed: float = 0.9
var swim_cycle_speed: float = 4.5

var mesh: PlayerMesh
var base: CharacterBase
var player: PlayerCharacter
var _slash_spawned: bool = false
var _last_remaining: float = 0.0

func setup(m: PlayerMesh, b: CharacterBase) -> void:
	mesh = m
	base = b
	player = b as PlayerCharacter

func animate(delta: float) -> void:
	var t: float = base._time
	match base._state:
		CharacterBase.State.IDLE:
			_idle(delta, t)
		CharacterBase.State.WALK:
			_walk(delta, t, 1.0)
		CharacterBase.State.SPRINT:
			_walk(delta, t, sprint_cycle_mult)
		CharacterBase.State.CROUCH:
			_crouch(delta, t)
		CharacterBase.State.DASH:
			_dash(delta, t)
		CharacterBase.State.ATTACK:
			_attack(delta, t)
		CharacterBase.State.JUMP:
			_air(delta, t, true)
		CharacterBase.State.FALL:
			_air(delta, t, false)
		CharacterBase.State.HIT:
			_hit(delta, t)
		CharacterBase.State.DEAD:
			_dead(delta, t)
		CharacterBase.State.SWIM:
			_swim(delta, t)

func _idle(delta: float, t: float) -> void:
	# Chibi idle: nhún nhẹ, đầu lắc lư cute
	var b: float = sin(t * idle_breathe_speed)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02 + abs(b) * 0.008, delta * 5.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 7.0)
	mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, b * 0.015, delta * 4.0)
	# Đầu to chibi: lắc nhẹ trái phải, gật nhẹ
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, b * 0.03, delta * 4.0)
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(t * 0.4) * 0.08, delta * 3.0)
	mesh.head.rotation.z = lerp(mesh.head.rotation.z, sin(t * 0.5) * 0.04, delta * 3.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, b * 0.015, delta * 5.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.02, delta * 5.0)
	# Tay đung đưa nhẹ
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06 + b * 0.03, delta * 5.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06 + b * 0.03, delta * 5.0)
	mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z,  0.04 + b * 0.02, delta * 4.0)
	mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04 - b * 0.02, delta * 4.0)
	# Chân nhỏ đứng yên
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 6.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 6.0)

func _walk(delta: float, t: float, mult: float) -> void:
	# Chibi walk: nhún nhiều hơn, đầu to lắc cute
	var cyc: float = t * walk_cycle_speed * mult
	mesh.rig.position.y = 0.02 + abs(sin(cyc)) * (0.04 + mult * 0.018)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.05 * mult, delta * 8.0)
	mesh.rig.rotation.z = sin(cyc) * (0.025 + mult * 0.012)
	# Đầu to chibi: lắc lư theo nhịp bước
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(cyc * 0.5) * 0.10 * mult, delta * 5.0)
	mesh.head.rotation.z = lerp(mesh.head.rotation.z, sin(cyc * 0.5) * 0.05, delta * 5.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, sin(cyc * 0.5) * 0.04, delta * 5.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.02 + abs(sin(cyc * 0.5)) * 0.015, delta * 5.0)
	mesh.backpack.rotation.x = sin(cyc * 0.5) * 0.04
	# Tay đánh nhịp
	mesh.arm_l.rotation.x = sin(cyc + PI) * (0.28 + mult * 0.08)
	mesh.arm_r.rotation.x = sin(cyc) * (0.28 + mult * 0.08)
	mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.04, delta * 6.0)
	mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 6.0)
	# Chân ngắn chibi bước rộng hơn để cute
	mesh.leg_l.rotation.x = sin(cyc) * (0.50 + mult * 0.12)
	mesh.leg_r.rotation.x = sin(cyc + PI) * (0.50 + mult * 0.12)

func _crouch(delta: float, t: float) -> void:
	var cyc: float = t * walk_cycle_speed * 0.5
	mesh.rig.position.y = lerp(mesh.rig.position.y, -0.18, delta * 10.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.18, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.10, delta * 6.0)
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(t * 0.2) * 0.08, delta * 4.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.08, delta * 6.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.06, delta * 5.0)
	mesh.arm_l.rotation.x = sin(cyc + PI) * 0.20
	mesh.arm_r.rotation.x = sin(cyc) * 0.20
	mesh.leg_l.rotation.x = 0.30 + sin(cyc) * 0.20
	mesh.leg_r.rotation.x = 0.30 + sin(cyc + PI) * 0.20

func _dash(delta: float, _t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 18.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.30, delta * 18.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.15, delta * 14.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.20, delta * 16.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.06, delta * 12.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.40, delta * 16.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.40, delta * 16.0)
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.50, delta * 18.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.50, delta * 18.0)

func _air(delta: float, t: float, rising: bool) -> void:
	var tuck: float
	if rising:
		tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.5
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.02, delta * 8.0)
	# Đầu to chibi ngửa lên khi nhảy (cute)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.10 + tuck * 0.06, delta * 6.0)
	mesh.head.rotation.z = lerp(mesh.head.rotation.z, 0.0, delta * 6.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.04 + tuck * 0.10, delta * 8.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.04 - tuck * 0.03, delta * 8.0)
	# Tay xoè ra hai bên khi nhảy (cute)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.50 - tuck * 0.25, delta * 8.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.50 - tuck * 0.25, delta * 8.0)
	mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z,  0.30 + tuck * 0.20, delta * 8.0)
	mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.30 - tuck * 0.20, delta * 8.0)
	# Chân thu lên
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.30 - tuck * 0.35, delta * 10.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.30 - tuck * 0.35, delta * 10.0)

func _swim(delta: float, t: float) -> void:
	var cyc: float = t * swim_cycle_speed
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.18, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.12, delta * 6.0)
	mesh.body.rotation.x = sin(cyc * 0.5) * 0.06 + 0.10
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.04, delta * 5.0)
	mesh.arm_l.rotation.x = sin(cyc) * 0.60
	mesh.arm_r.rotation.x = sin(cyc + PI) * 0.60
	mesh.leg_l.rotation.x = sin(cyc + PI * 0.5) * 0.50
	mesh.leg_r.rotation.x = sin(cyc - PI * 0.5) * 0.50
	var kick: float = abs(sin(cyc * 1.5))
	mesh.rig.position.y += kick * 0.02

func _hit(delta: float, _t: float) -> void:
	var p: float = 1.0 - (base._hit_timer / 0.18)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.03, delta * 14.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.20 - p * 0.14, delta * 16.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.15 + p * 0.10, delta * 16.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.14 - p * 0.08, delta * 14.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.30, delta * 20.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.30, delta * 20.0)
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.08, delta * 12.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.08, delta * 12.0)

func _dead(delta: float, t: float) -> void:
	var prog: float = 1.0 - (base._death_timer / 1.8)
	if prog < 0.30:
		var p: float = prog / 0.30
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, p * 0.50, delta * 16.0)
		mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, p * (-0.10), delta * 14.0)
		mesh.head.rotation.x = lerp(mesh.head.rotation.x, -p * 0.20, delta * 14.0)
	elif prog < 0.70:
		var p: float = (prog - 0.30) / 0.40
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.50 + p * 0.60, delta * 14.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -p * 0.10, delta * 10.0)
	else:
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 1.10, delta * 8.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -0.10, delta * 6.0)

func _attack(delta: float, _t: float) -> void:
	var dur: float = base.attack_duration
	var remaining: float = base._attack_timer
	var prog: float = 1.0 - clamp(remaining / dur, 0.0, 1.0)
	var step: int = player.combo_step if player != null else 0
	var wp := mesh.weapon_pivot
	const IDLE_WP: Vector3 = Vector3(90, 0, 0)

	if remaining > _last_remaining + 0.001:
		_slash_spawned = false
	_last_remaining = remaining

	var is_heavy: bool = player and player.equipped_weapon != null and (player.equipped_weapon.id == "riu" or player.equipped_weapon.id == "cup")

	if is_heavy:
		# ── Heavy overhead swing ──────────────────────────────────────────────
		# Wind-up (0.0 → 0.35): raise weapon above head
		if prog < 0.35:
			var p: float = prog / 0.35
			wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, -35.0 + 90.0 * (1.0 - p), delta * 14.0)
			wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 8.0 * p, delta * 14.0)
			wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -5.0 * p, delta * 14.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.70 * p, delta * 18.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.06 * p, delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.06 * p, delta * 14.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.08 * p, delta * 12.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.06 * p, delta * 12.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.14 * p, delta * 12.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.10 * p, delta * 12.0)

		# Strike (0.35 → 0.75): overhead swing down
		elif prog < 0.75:
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.35) / 0.40
			wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 145.0, delta * 26.0)
			wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -12.0, delta * 22.0)
			wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 8.0, delta * 22.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.50 * p - 0.70 * (1.0 - p), delta * 28.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.12 * sin(p * PI), delta * 22.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.10 * sin(p * PI), delta * 18.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.15 * sin(p * PI), delta * 18.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.08 * sin(p * PI), delta * 16.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.18 * sin(p * PI), delta * 16.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.10 * sin(p * PI), delta * 14.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.15 * sin(p * PI), delta * 14.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.20 * sin(p * PI), delta * 12.0)

		# Recovery (0.75 → 1.0)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 10.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.0, delta * 10.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.0, delta * 10.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.0, delta * 10.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06, delta * 10.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 10.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06, delta * 10.0)
			mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 10.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 10.0)

	else:
		# ── Fast sword combo ──────────────────────────────────────────────────
		# Wind-up (0.0 → 0.25)
		if prog < 0.25:
			var p: float = prog / 0.25
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -14.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.55 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.20 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.12 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.18 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.12 * p, delta * 14.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.55 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.20 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.12 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.18 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.12 * p, delta * 14.0)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 82.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 42.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -7.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.28 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.32 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.20 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.25 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.16 * p, delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.08 * p, delta * 16.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.05 * p, delta * 14.0)

		# Strike (0.25 → 0.70)
		elif prog < 0.70:
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.25) / 0.45
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 112.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -22.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 16.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.75 * p - 0.55 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.10 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.22 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.18 * sin(p * PI), delta * 16.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 112.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 22.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -16.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.75 * p - 0.55 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.10 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.22 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.18 * sin(p * PI), delta * 16.0)
					mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 97.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -42.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 11.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.45 * p - 0.28 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.14 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.45 * sin(p * PI), delta * 22.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.38 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.06 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.22 * sin(p * PI), delta * 16.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.22 * sin(p * PI), delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.12 * p, delta * 22.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, -0.05 * sin(p * PI), delta * 20.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.08 * p, delta * 18.0)

		# Recovery (0.70 → 1.0)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 10.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.0, delta * 10.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.0, delta * 10.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.0, delta * 10.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06, delta * 10.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 10.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06, delta * 10.0)
			mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 10.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 10.0)
			if remaining <= 0.0 and player and player.combo_timer <= 0.0:
				player.combo_step = 0

func _spawn_slash(step: int) -> void:
	if not is_instance_valid(mesh) or not is_instance_valid(mesh.weapon_pivot):
		return
	if not player or not player.equipped_weapon:
		return
	var wp := mesh.weapon_pivot
	var is_heavy: bool = player.equipped_weapon.id == "riu" or player.equipped_weapon.id == "cup"

	if is_heavy:
		var is_axe: bool = player.equipped_weapon.id == "riu"
		var vfx := SlashVFX.new(75.0 if is_axe else 60.0, 0.40 if is_axe else 0.30, 0.10, Color.WHITE)
		wp.add_child(vfx)
		vfx.position = Vector3(0, 0.40, 0)
		vfx.rotation_degrees = Vector3(0, 90, 0)
	elif player.equipped_weapon.id == "kiem":
		var vfx := SlashVFX.new(70.0, 0.5, 0.12, Color.WHITE)
		wp.add_child(vfx)
		vfx.position = Vector3(0, 0.40, 0)
		match step:
			0: vfx.rotation_degrees = Vector3(0, 0, 30)
			1: vfx.rotation_degrees = Vector3(0, 0, -30)
			2: vfx.rotation_degrees = Vector3(85, 0, 0)
