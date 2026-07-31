## core/damage_system.gd
## Static damage utilities for CharacterBase.
## Called as _Damage.method(self, ...)

extends RefCounted

static func take_damage(character: CharacterBase, amount: int, attacker: Node3D = null, damage_type: int = 0) -> void:
	if not character.is_alive or character._invul_timer > 0.0:
		return
	var dmg := maxi(1, amount - character.defense)
	if character.shield > 0:
		var absorbed := mini(character.shield, dmg)
		character.shield -= absorbed
		dmg -= absorbed
		character.shield_changed.emit(character.shield)
	if dmg > 0:
		character.hp = maxi(0, character.hp - dmg)
		character._invul_timer = 0.05
		character._hit_timer = 0.18
		character._hit_flash()
		character._spawn_damage_number(dmg, attacker, damage_type)
		SFXManager.play_hurt()
		character._state = CharacterBase.State.HIT
		character._attack_timer = 0.0
		character._attack2_timer = 0.0
		character.hp_changed.emit(character.hp, character.max_hp)
		character.damage_taken.emit(dmg, attacker)
	if character.hp <= 0:
		_die(character, attacker)

static func add_shield(character: CharacterBase, amount: int) -> void:
	character.shield += amount
	character.shield_changed.emit(character.shield)

static func heal(character: CharacterBase, amount: int) -> void:
	if not character.is_alive:
		return
	character.hp = mini(character.max_hp, character.hp + amount)
	character.hp_changed.emit(character.hp, character.max_hp)

static func _die(character: CharacterBase, _attacker: Node3D = null) -> void:
	character.is_alive = false
	character._flash_restore()
	SFXManager.play_death()
	character._death_timer = 1.8
	character._state = CharacterBase.State.DEAD
	character._attack_timer = 0.0
	character._attack2_timer = 0.0
	character._hit_timer = 0.0
	character.velocity = Vector3.ZERO
	character.died.emit(_attacker)

static func revive(character: CharacterBase) -> void:
	character.hp = character.max_hp
	character.is_alive = true
	character._active = true
	character._state = CharacterBase.State.IDLE
	character._flash_restore()
	character._death_timer = 0.0
	character._hit_timer = 0.0
	character.set_physics_process(true)
	character.set_process_unhandled_input(true)
	character.set_process_unhandled_key_input(true)
	if character._rig:
		character._rig.visible = true
	character.hp_changed.emit(character.hp, character.max_hp)

static func apply_dot(character: CharacterBase, damage_per_tick: int, tick_interval: float, duration: float, attacker: Node3D = null) -> void:
	if not character.is_alive:
		return
	var dot := Node.new()
	var timer := Timer.new()
	timer.wait_time = tick_interval
	timer.autostart = true
	timer.timeout.connect(func():
		if character.is_alive:
			take_damage(character, damage_per_tick, attacker)
	)
	dot.add_child(timer)
	character.add_child(dot)
	character.get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(dot):
			dot.queue_free()
	)
