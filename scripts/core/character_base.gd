## core/character_base.gd
## Base class cho mọi nhân vật (người chơi + bot).
## Chứa: physics, state machine, input, camera, squash/stretch, HP/stats.

extends CharacterBody3D
class_name CharacterBase

const _Damage = preload("res://scripts/core/damage_system.gd")
const _Swim  = preload("res://scripts/core/swim_system.gd")
const _Effects = preload("res://scripts/core/status_effects.gd")

signal damage_taken(amount: int, attacker: Node3D)
signal died(attacker: Node3D)
signal hp_changed(current: int, max_hp: int)
signal shield_changed(current: int)
signal stamina_changed(current: int, max_stamina: int)
signal oxygen_changed(current: int, max_oxygen: int)
signal level_up(new_level: int)
signal submerged(underwater: bool)

# ── Damage type system ─────────────────────────────────────────────────────────
enum DamageType { PHYSICAL, POISON, FIRE, WATER, LIGHTNING, ICE }
const DAMAGE_TYPE_COLORS: Dictionary = {
	DamageType.PHYSICAL:   Color(1.0, 1.0, 1.0),
	DamageType.POISON:     Color(0.20, 0.85, 0.20),
	DamageType.FIRE:       Color(1.0, 0.35, 0.05),
	DamageType.WATER:      Color(0.20, 0.55, 1.0),
	DamageType.LIGHTNING:  Color(1.0, 0.85, 0.0),
	DamageType.ICE:        Color(0.40, 0.85, 1.0),
}
const DAMAGE_TYPE_NAMES: Dictionary = {
	DamageType.PHYSICAL:   "Dmg Vật Lý",
	DamageType.POISON:     "Dmg Độc",
	DamageType.FIRE:       "Dmg Lửa",
	DamageType.WATER:      "Dmg Nước",
	DamageType.LIGHTNING:  "Dmg Điện",
	DamageType.ICE:        "Dmg Băng",
}

# ── Stats ─────────────────────────────────────────────────────────────────────
@export var max_hp:             int   = 100
@export var hp:                 int   = 100
@export var defense:            int   = 0
@export var attack_power:       int   = 15

## Giáp phòng thủ tổng (defense cơ bản + bonus trang bị).
## Player ghi đè để cộng def_bonus của giáp đang mặc.
func get_total_def() -> float:
	return float(defense)

@export var move_speed:         float = 5.5
@export var sprint_speed:       float = 9.5
@export var acceleration:       float = 26.0
@export var friction:           float = 20.0
@export var jump_height:        float = 1.4
@export var jump_time_rise:     float = 0.28
@export var jump_time_fall:     float = 0.20
@export var dash_speed:         float = 18.0
@export var dash_duration:      float = 0.18
@export var dash_cooldown:      float = 0.80
@export var attack_duration:    float = 0.45
@export var melee_damage:       int   = 0
@export var melee_range:        float = 2.2
@export var auto_aim_range:     float = 20.0
## Bán kính hitbox của nhân vật — cộng thêm vào tầm đánh/đạn để khớp kích thước thật
@export var hit_radius:         float = 0.3
@export var lmb_cooldown:       float = 0.0
@export var q_cooldown:         float = 0.0
@export var r_cooldown:         float = 0.0
@export var cooldown_rate:      float = 1.0
@export var sprint_stamina_cost:   float = 0.5
@export var crouch_speed:       float = 2.5

# ── Stamina ───────────────────────────────────────────────────────────────────
@export var max_stamina:            int   = 100
@export var stamina:                int   = 100
@export var stamina_regen:          float = 5.0
@export var stamina_refund:         int   = 3
@export var stamina_cost_lmb:       int   = 0
@export var stamina_cost_q:         int   = 0
@export var stamina_cost_r:         int   = 0
@export var level:               int   = 1
@export var exp:                 int   = 0
@export var exp_to_next:         int   = 100
@export var crit_rate:           float = 0.05
@export var crit_dmg:            float = 0.50
var _stamina_regen_acc: float = 0.0
var _sprint_stamina_acc: float = 0.0

var is_alive: bool = true
var character_name: String = ""
var element: int = 0
var shield: int = 0
## Hệ thống hiệu ứng trạng thái (làm chậm, ...) — khởi tạo trong _ready
var effects: StatusEffects = null
var _melee_hit_once: bool = false
var _melee_hit_progress: float = 0.25

# ── Oxygen / Swimming ──────────────────────────────────────
@export var max_oxygen: float = 100.0
var oxygen: float = 100.0
const OXYGEN_DEPLETE_RATE: float = 7.0
const OXYGEN_REFILL_RATE: float = 15.0
const DROWN_DAMAGE_INTERVAL: float = 1.5
var _drown_timer: float = 0.0
var _underwater: bool = false
var _swim_jump_cd: float = 0.0
var _water_check_cd: float = 0.0

# ── State machine ─────────────────────────────────────────────────────────────
enum State { IDLE, WALK, SPRINT, CROUCH, DASH, ATTACK, DEVOUR, JUMP, FALL, HIT, DEAD, SWIM, EAT }
var _state: State = State.IDLE

# ── Timers ────────────────────────────────────────────────────────────────────
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.10
const FALL_DAMAGE_THRESHOLD: float = 4.0  # rơi xuống đất vượt quá mức cao này → sát thương
var _coyote:          float  = 0.0
var _jbuf:            float  = 0.0
var _dash_timer:      float  = 0.0
var _dash_cd:         float  = 0.0
var _attack_timer:    float  = 0.0
var _attack2_timer:   float  = 0.0
var _attack2_duration: float = 0.70
var _action_lunge_timer: float = 0.0
var _action_lunge_speed: float = 0.0
var _dash_dir:        Vector3 = Vector3.ZERO
var _lmb_cd:          float   = 0.0
var _q_cd:            float   = 0.0
var _r_cd:            float   = 0.0
var _invul_timer:     float   = 0.0
var _hit_timer:       float   = 0.0
var _death_timer:     float   = 0.0
var _aim_dir:         Vector3 = Vector3.FORWARD
var _freeze_timer:    float   = 0.0
var _han_bang_buff:    float   = 0.0

# ── Physics internals ─────────────────────────────────────────────────────────
var _jump_v:    float = 0.0
var _grav_rise: float = 0.0
var _grav_fall: float = 0.0
var _was_floor: bool  = false
var _time:      float = 0.0
var _falling: bool = false
var _fall_start_y: float = 0.0
var _safe_fall_timer: float = 0.0  # thời gian bảo vệ rơi từ xe/tượng (không gây sát thương)


# ── Squash / stretch ──────────────────────────────────────────────────────────
var _sy_tgt: float = 1.0
var _sy_cur: float = 1.0

# ── Visual root ───────────────────────────────────────────────────────────────
var _rig: Node3D

# ── Active flag ───────────────────────────────────────────────────────────────
var _active: bool = true
var _is_player: bool = true
## false = ẩn WorldHPBar (dùng cho sinh vật passive như cá, thú rừng)
@export var show_world_hp_bar: bool = true
## true = hiển thị world HP bar ngay trên đầu character
var _world_hp_enabled: bool = false

# ── Camera refs ───────────────────────────────────────────────────────────────
var _camera:  Camera3D
var _fp_rig:  Node3D
var _tp_rig:  Node3D
var _use_tp:  bool = true  # mặc định cam 3 (third-person); ấn F1 → first-person
var _water_mgr: OpenWorldManager = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	effects = _Effects.new(self)
	_jump_v    = (2.0 * jump_height) / jump_time_rise
	_grav_rise = (2.0 * jump_height) / (jump_time_rise * jump_time_rise)
	_grav_fall = (2.0 * jump_height) / (jump_time_fall * jump_time_fall)
	_build_character()
	hp = max_hp
	stamina = max_stamina
	oxygen = max_oxygen
	await get_tree().process_frame
	if _is_player:
		var root: Node = get_parent().get_parent()
		if root == null:
			root = get_parent()
		_fp_rig = root.get_node_or_null("CameraRig")
		_tp_rig = root.get_node_or_null("TPCameraRig")
		_camera  = get_viewport().get_camera_3d()
	if not has_meta("no_world_hp_bar") and _world_hp_enabled and show_world_hp_bar:
		_add_world_hp_bar()

	_water_mgr = _find_water_manager()

func _add_world_hp_bar() -> void:
	var bar := WorldHPBar.new()
	add_child(bar)
	bar.setup(self)

func _process(delta: float) -> void:
	if _invul_timer > 0.0:
		_invul_timer = max(_invul_timer - delta, 0.0)
	if _hit_timer > 0.0:
		_hit_timer = max(_hit_timer - delta, 0.0)
	_freeze_timer = max(_freeze_timer - delta, 0.0)
	_han_bang_buff = max(_han_bang_buff - delta, 0.0)
	if effects:
		effects.tick(delta)

	# Stamina regen
	_stamina_regen_acc += stamina_regen * delta
	if _stamina_regen_acc >= 1.0:
		var gain: int = int(_stamina_regen_acc)
		_stamina_regen_acc -= gain
		add_stamina(gain)

	if not _active:
		var cd_delta: float = delta * cooldown_rate
		_lmb_cd = max(_lmb_cd - cd_delta, 0.0)
		_q_cd = max(_q_cd - cd_delta, 0.0)
		_r_cd = max(_r_cd - cd_delta, 0.0)
		_dash_cd = max(_dash_cd - delta, 0.0)
		_on_offline_tick(delta, cd_delta)
		return

	# Oxygen
	if _underwater:
		oxygen -= OXYGEN_DEPLETE_RATE * delta
		if oxygen <= 0.0:
			oxygen = 0.0
			_drown_timer += delta
			if _drown_timer >= DROWN_DAMAGE_INTERVAL:
				_drown_timer = 0.0
				_Damage.take_damage(self, 5)
		oxygen_changed.emit(int(oxygen), int(max_oxygen))
	else:
		if oxygen < max_oxygen:
			oxygen += OXYGEN_REFILL_RATE * delta
			if oxygen > max_oxygen:
				oxygen = max_oxygen
			oxygen_changed.emit(int(oxygen), int(max_oxygen))
		_drown_timer = 0.0

# ── Overrideable interface ────────────────────────────────────────────────────
func _build_character() -> void:      pass
func _animate(_delta: float) -> void: pass
func _animate_swim(_delta: float) -> void: pass
func _on_primary_attack() -> void:    pass
func _on_secondary_attack() -> void:  pass
func _on_show_animation() -> void:    pass
func _on_dash() -> void:              pass
func _on_offline_tick(_delta: float, _cd_delta: float) -> void: pass

func apply_freeze(duration: float) -> void:
	if not is_alive:
		return
	_freeze_timer = duration
	_spawn_freeze_vfx()

func add_han_bang_buff(duration: float) -> void:
	_han_bang_buff = max(_han_bang_buff, duration)

func is_han_bang_buffed() -> bool:
	return _han_bang_buff > 0.0

func is_frozen() -> bool:
	return _freeze_timer > 0.0

# ── Status effects (làm chậm) ─────────────────────────────────────────────────
func get_speed_multiplier() -> float:
	if effects == null:
		return 1.0
	return effects.get_move_multiplier()

func can_jump() -> bool:
	if effects == null:
		return true
	return effects.can_jump()

func can_interact() -> bool:
	if effects == null:
		return true
	return effects.can_interact()

func _spawn_freeze_vfx() -> void:
	if _rig == null:
		return
	# Ẩn VFX cũ nếu có
	for c in _rig.get_children():
		if c is Node and c.name == "_FreezeVFX":
			c.queue_free()
			break
	var vfx := FreezeVFX.new()
	vfx.name = "_FreezeVFX"
	_rig.add_child(vfx)
	vfx.setup(_freeze_timer)

func _spawn_splash(entering: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.85, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.85, 1.0) * 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	var count := 8 if entering else 4
	var parent := get_parent()
	if parent == null: return
	for k in range(count):
		var sp := MeshInstance3D.new()
		sp.mesh = sphere
		sp.material_override = mat
		parent.add_child(sp)
		sp.global_position = global_position + Vector3(0, 0.25, 0)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		var dist := 0.5 + randf() * 1.0
		var tw := create_tween()
		tw.tween_property(sp, "global_position", sp.global_position + dir * dist, 0.4).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "scale", Vector3.ZERO, 0.4)
		tw.tween_callback(sp.queue_free)

# ── Level / Exp ───────────────────────────────────────────────────────────────
const MAX_LEVEL: int = 100

## Bonus level theo bản thân sinh vật (vd: cá la hán +1, slime +2).
var mob_bonus_lv: int = 0
## Bonus level theo vùng sinh thái nơi spawn (do spawner đặt trước add_child).
var bio_bonus_lv: int = 0

## Level tổng của creature = 1 (gốc) + mob_bonus_lv + bio_bonus_lv.
func compute_level() -> int:
	return 1 + mob_bonus_lv + bio_bonus_lv

## Hệ số chỉ số theo level creature: mỗi level trên 1 tăng +2%.
##   stat_eff = base * get_stat_mult()
func get_stat_mult() -> float:
	return 1.0 + 0.02 * float(maxi(level - 1, 0))

## Hệ số tỷ lệ drop theo level creature: mỗi level trên 1 tăng +5% (của rate gốc).
##   rate_eff = rate * get_rate_mult()
func get_rate_mult() -> float:
	return 1.0 + 0.05 * float(maxi(level - 1, 0))

func add_exp(amount: int) -> void:
	if level >= MAX_LEVEL:
		exp = exp_to_next
		return
	exp += amount
	while exp >= exp_to_next and level < MAX_LEVEL:
		exp -= exp_to_next
		level += 1
		exp_to_next = level * 100
		SFXManager.play_levelup()
		level_up.emit(level)

func calc_skill_damage(skill_power: int) -> int:
	return maxi(1, skill_power * attack_power / 100)

func calc_hp_skill_damage(percent: float) -> int:
	return maxi(1, int(max_hp * percent / 100.0))

# ── HP / Damage ───────────────────────────────────────────────────────────────
func take_damage(amount: int, attacker: Node3D = null, damage_type: int = 0) -> void:
	_Damage.take_damage(self, amount, attacker, damage_type)

## Gọi khi lên/xuống xe: bảo vệ rơi ngắn trong thời gian ngắn để không gây
## falling damage khi chỉ "bước xuống" (trường hợp lỗi heli-exit instant-drop).
func enable_exit_grace(duration: float = 0.5) -> void:
	_safe_fall_timer = max(_safe_fall_timer, duration)
	_falling = false

func add_shield(amount: int) -> void:
	_Damage.add_shield(self, amount)

func add_stamina(amount: int) -> void:
	stamina = mini(stamina + amount, max_stamina)
	stamina_changed.emit(stamina, max_stamina)

func try_skill(cost: int) -> bool:
	if stamina < cost:
		return false
	stamina -= cost
	stamina = mini(stamina + stamina_refund, max_stamina)
	stamina_changed.emit(stamina, max_stamina)
	return true

func heal(amount: int) -> void:
	_Damage.heal(self, amount)

func apply_dot(damage_per_tick: int, tick_interval: float, duration: float, attacker: Node3D = null) -> void:
	_Damage.apply_dot(self, damage_per_tick, tick_interval, duration, attacker)

func _die(_attacker: Node3D = null) -> void:
	_Damage._die(self, _attacker)

func revive() -> void:
	_Damage.revive(self)

# ── Hit flash ─────────────────────────────────────────────────────────────────
var _white_mat: StandardMaterial3D = null
var _flash_pairs: Array[Dictionary] = []

func _hit_flash() -> void:
	_flash_restore()
	if _rig == null:
		return
	if _white_mat == null:
		_white_mat = StandardMaterial3D.new()
		_white_mat.albedo_color = Color(1, 1, 1)
		_white_mat.emission = Color(1, 1, 1)
		_white_mat.emission_energy_multiplier = 10.0
		_white_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mis: Array[MeshInstance3D] = []
	_collect_mesh_instances(_rig, mis)
	for mi in mis:
		var orig := mi.material_override as StandardMaterial3D
		if orig == null:
			continue
		_flash_pairs.append({"mi": mi, "orig": orig})
		mi.material_override = _white_mat

	if is_inside_tree():
		get_tree().create_timer(0.18).timeout.connect(_flash_restore)

func _flash_restore() -> void:
	if _flash_pairs.is_empty():
		return
	for pair in _flash_pairs:
		var mi = pair["mi"]
		if is_instance_valid(mi) and mi is MeshInstance3D:
			mi.material_override = pair["orig"]
	_flash_pairs.clear()

func _collect_mesh_instances(node: Node3D, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
		if child is Node3D:
			_collect_mesh_instances(child as Node3D, out)

# ── CharacterManager API ──────────────────────────────────────────────────────
func set_active(value: bool) -> void:
	_active = value
	set_physics_process(value)
	set_process_unhandled_input(value)
	set_process_unhandled_key_input(value)
	if _rig:
		_rig.visible = value
	for child in get_children():
		if child is WorldHPBar:
			child.visible = value
	if value and _is_player:
		await get_tree().process_frame
		_sync_camera()
		_camera = get_viewport().get_camera_3d()

## Đồng bộ trạng thái camera rig theo _use_tp — gọi khi player active để
## đúng ngay từ đầu (không phải bấm F1 2 lần mới chuẩn).
func _sync_camera() -> void:
	if not _is_player:
		return
	if _use_tp:
		if is_instance_valid(_fp_rig):
			_fp_rig.call("deactivate")
		if is_instance_valid(_tp_rig):
			_tp_rig.call("activate")
	else:
		if is_instance_valid(_tp_rig):
			_tp_rig.call("deactivate")
		if is_instance_valid(_fp_rig):
			_fp_rig.call("activate")

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or not _is_player:
		return
	if _is_building_placing():
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.is_action_pressed("jump") and _freeze_timer <= 0.0 and can_jump():
				_jbuf = JUMP_BUFFER
			if k.is_action_pressed("camera_toggle"):
				_toggle_camera()
			if k.is_action_pressed("crouch"):
				if _attack_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
					_on_show_animation()
			if k.is_action_pressed("skill"):
				if _r_cd <= 0.0 and _freeze_timer <= 0.0 and _attack2_timer <= 0.0 and _attack_timer <= 0.0 and _state != State.DASH:
					if not try_skill(stamina_cost_r):
						return
					_aim_dir = _calc_aim_dir()
					var fwd := global_transform.basis.z
					if _aim_dir.dot(fwd) < 0.99:
						rotation.y = atan2(_aim_dir.x, _aim_dir.z)
					_r_cd = r_cooldown
					_on_secondary_attack()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not _is_player:
		return
	if _is_building_placing():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if _lmb_cd <= 0.0 and _freeze_timer <= 0.0 and _attack_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
					if not try_skill(stamina_cost_lmb):
						return
					_aim_dir = _calc_aim_dir()
					var fwd := global_transform.basis.z
					if _aim_dir.dot(fwd) < 0.99:
						rotation.y = atan2(_aim_dir.x, _aim_dir.z)
					_lmb_cd = lmb_cooldown
					_attack_timer = attack_duration
					_state = State.ATTACK
					_melee_hit_once = false
					_on_primary_attack()

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not _active:
		return
	if not is_alive:
		if _state == State.DEAD:
			_death_timer -= delta
			velocity.x *= 0.85
			velocity.z *= 0.85
			_animate(delta)
			if _death_timer <= 0.0:
				_active = false
				set_physics_process(false)
				set_process_unhandled_input(false)
				set_process_unhandled_key_input(false)
				if _rig:
					_rig.visible = false
			return
		return

	_time          += delta
	var cd_delta: float = delta * cooldown_rate
	_lmb_cd         = max(_lmb_cd - cd_delta, 0.0)
	_q_cd           = max(_q_cd - cd_delta, 0.0)
	_r_cd           = max(_r_cd - cd_delta, 0.0)
	_dash_cd        = max(_dash_cd - delta, 0.0)
	_attack_timer   = max(_attack_timer - delta, 0.0)
	_attack2_timer  = max(_attack2_timer - delta, 0.0)
	_action_lunge_timer = max(_action_lunge_timer - delta, 0.0)
	_invul_timer    = max(_invul_timer - delta, 0.0)

	if _hit_timer > 0.0:
		velocity.x *= 0.3
		velocity.z *= 0.3
		_state = State.HIT
		move_and_slide()
		_animate(delta)
		return

	if _freeze_timer > 0.0:
		_attack_timer  = max(_attack_timer - delta, 0.0)
		_attack2_timer = max(_attack2_timer - delta, 0.0)
		_dash_timer    = max(_dash_timer - delta, 0.0)
		if _dash_timer <= 0.0 and _state == State.DASH:
			_state = State.IDLE
		velocity.x *= 0.2
		velocity.z *= 0.2
		move_and_slide()
		_animate(delta)
		return

	# Water detection — player check mỗi frame, NPC throttle
	_water_check_cd -= delta
	if _is_player or _water_check_cd <= 0.0:
		if not _is_player:
			_water_check_cd = 0.5
		var was_underwater := _underwater
		if _water_mgr == null or not _water_mgr.is_inside_tree():
			_water_mgr = _find_water_manager()
		if _water_mgr != null:
			_underwater = _water_mgr.is_in_water(global_position.x, global_position.z, global_position.y) \
				or _water_mgr.is_in_water(global_position.x, global_position.z, global_position.y + 0.5)
		else:
			_underwater = false
		if _underwater != was_underwater:
			submerged.emit(_underwater)
			_spawn_splash(!_underwater)

	# Đang lái thuyền/máy kéo: bỏ qua điều khiển di chuyển — vị trí do xe đồng bộ
	if _is_player and (has_meta("driving_boat") or has_meta("driving_vehicle")):
		if _attack_timer > 0.0 and not _melee_hit_once and (1.0 - _attack_timer / attack_duration) >= _melee_hit_progress:
			_do_melee_hit()
		_animate(delta)
		return

	# Underwater / swimming
	if _underwater:
		_Swim.swim_physics(self, delta)
		if _attack_timer > 0.0 and not _melee_hit_once and (1.0 - _attack_timer / attack_duration) >= _melee_hit_progress:
			_do_melee_hit()
		return

	var on_floor: bool = is_on_floor()

	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = max(_coyote - delta, 0.0)
	_jbuf = max(_jbuf - delta, 0.0)

	# DASH
	if _state == State.DASH:
		_dash_timer = max(_dash_timer - delta, 0.0)
		velocity    = _dash_dir * dash_speed
		velocity.y  = 0.0
		if _dash_timer <= 0.0:
			_state = State.IDLE
		move_and_slide()
		_animate(delta)
		return

	# Gravity
	if not on_floor:
		if velocity.y > 0.0:
			velocity.y -= _grav_rise * delta
		else:
			velocity.y -= _grav_fall * delta
	else:
		velocity.y = -0.5

	# Jump
	if _jbuf > 0.0 and _coyote > 0.0 and can_jump():
		velocity.y = _jump_v
		_jbuf = 0.0
		_coyote = 0.0
		_sy_tgt = 1.22
		SFXManager.play_pop()

	# Void protection: if fallen below world bottom, warp player up or kill NPC
	if global_position.y < -30.0:
		if _is_player:
			global_position.y = 3.0
			velocity = Vector3.ZERO
			on_floor = false
		else:
			_die()

	if on_floor and not _was_floor:
		_sy_tgt = 0.76
		SFXManager.play_fall_small()
		if _falling and _safe_fall_timer <= 0.0:
			var dist: float = _fall_start_y - global_position.y
			_falling = false
			if dist > FALL_DAMAGE_THRESHOLD and not _underwater and is_alive:
				var dmg: int = maxi(1, int(dist - FALL_DAMAGE_THRESHOLD))
				_Damage.take_damage(self, dmg, null, 0)
	_was_floor = on_floor
	_safe_fall_timer = max(_safe_fall_timer - delta, 0.0)
	# Track fall start height (takeoff point) for falling-damage computation.
	if not on_floor and _safe_fall_timer <= 0.0 and not _falling:
		_falling = true
		_fall_start_y = global_position.y

	_sy_cur = lerp(_sy_cur, _sy_tgt, delta * 18.0)
	_sy_tgt = lerp(_sy_tgt, 1.0,     delta * 10.0)
	if _rig:
		var sx: float = 1.0 + (1.0 - _sy_cur) * 0.5
		_rig.scale = Vector3(sx, _sy_cur, sx)

	# Movement input
	var attacking: bool = _attack_timer > 0.0
	var devouring: bool = _attack2_timer > 0.0
	var lunging: bool = _action_lunge_timer > 0.0 and (attacking or devouring)
	var dir: Vector3 = _read_input()
	var crouching: bool
	var sprinting: bool
	if _is_player:
		crouching = Input.is_action_pressed("crouch")
		sprinting = Input.is_action_pressed("sprint") and not crouching
		if sprinting and sprint_stamina_cost > 0.0 and dir.length_squared() > 0.001:
			_sprint_stamina_acc += sprint_stamina_cost * delta
			if _sprint_stamina_acc >= 1.0:
				var drain: int = int(_sprint_stamina_acc)
				_sprint_stamina_acc -= drain
				stamina = maxi(0, stamina - drain)
				if stamina <= 0:
					sprinting = false
				stamina_changed.emit(stamina, max_stamina)
		else:
			_sprint_stamina_acc = 0.0
	else:
		crouching = false
		sprinting = false

	var spd: float = crouch_speed if crouching else (sprint_speed if sprinting else move_speed)
	spd *= get_speed_multiplier()

	if dir.length_squared() > 0.001 and not attacking and not devouring:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * spd, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, acceleration * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 14.0)
	elif lunging:
		var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
		velocity.x = fwd.x * _action_lunge_speed
		velocity.z = fwd.z * _action_lunge_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# Melee hit detection (ATTACK state)
	if attacking and not _melee_hit_once and (1.0 - _attack_timer / attack_duration) >= _melee_hit_progress:
		_do_melee_hit()

	# Dash trigger
	var want_dash: bool = false
	if _is_player:
		want_dash = Input.is_action_pressed("dash") and _q_cd <= 0.0 and _freeze_timer <= 0.0 and not attacking and not devouring
	if want_dash:
		if not try_skill(stamina_cost_q):
			return
		var di := _read_input()
		if di.length_squared() > 0.001:
			_dash_dir = di.normalized()
		else:
			_dash_dir = -global_transform.basis.z
		_dash_dir.y = 0.0
		_dash_dir    = _dash_dir.normalized()
		_q_cd        = q_cooldown
		_dash_timer  = dash_duration
		_dash_cd     = dash_cooldown
		_state       = State.DASH
		_sy_tgt      = 1.15
		_on_dash()
		SFXManager.play_sweep()
		move_and_slide()
		_animate(delta)
		return

	# State update
	if attacking:
		_state = State.ATTACK
	elif devouring:
		_state = State.DEVOUR
	elif not on_floor:
		if velocity.y > 0.0:
			_state = State.JUMP
		else:
			_state = State.FALL
	elif crouching:
		_state = State.CROUCH
	elif dir.length_squared() > 0.001:
		if sprinting:
			_state = State.SPRINT
		else:
			_state = State.WALK
	else:
		_state = State.IDLE

	move_and_slide()
	_animate(delta)

func _do_melee_hit() -> void:
	_melee_hit_once = true
	var range_scale: float = 1.0
	var angle_threshold: float = 0.35
	if _is_player:
		var pc := self as PlayerCharacter
		if pc and pc.equipped_weapon:
			match pc.equipped_weapon.id:
				"iron_greatsword": range_scale = 1.75; angle_threshold = 0.15
				"giao_dai": range_scale = 1.7
				"iron_halberd": range_scale = 1.9; angle_threshold = 0.15
				"axe": range_scale = 1.3
				"iron_sword": range_scale = 1.2
				"pickaxe", "shovel", "hoe": range_scale = 1.1
				"leather_gloves": range_scale = 0.9
	var max_dist: float = melee_range * range_scale
	var landed := false
	var mgr := _find_character_manager()
	if mgr == null:
		return
	var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != self and ch.is_alive and ch._active:
			var offset: Vector3 = ch.global_position - global_position
			offset.y = 0.0
			var dist: float = offset.length()
			if dist <= max_dist + ch.hit_radius:
				var dot: float = fwd.dot(offset / dist)
				if dot >= angle_threshold:
					SFXManager.play_damage_hit()
					var dmg: int = attack_power
					if _is_player:
						var pc := self as PlayerCharacter
						if pc and pc.equipped_weapon:
							dmg += pc.equipped_weapon.atk_bonus
					ch.take_damage(dmg, self)
					landed = true
	# Also hit fish in the "fish" group (cá tự nhiên trong FishSpawner + cá nở
	# từ trứng đều vào group này — nếu chỉ quét FishSpawner thì cá từ trứng
	# không thuộc spawner nên không thể bị đánh trúng).
	var fish_nodes := get_tree().get_nodes_in_group("fish")
	for f in fish_nodes:
		if not is_instance_valid(f) or not f.get("is_alive"):
			continue
		var offset: Vector3 = f.global_position - global_position
		offset.y = 0.0
		var dist: float = offset.length()
		if dist <= max_dist + f.hit_radius:
			var dot: float = fwd.dot(offset / dist)
			if dot >= angle_threshold:
					SFXManager.play_damage_hit()
					var dmg: int = attack_power
					if _is_player:
						var pc := self as PlayerCharacter
						if pc and pc.equipped_weapon:
							dmg += pc.equipped_weapon.atk_bonus
					f.take_damage(dmg, self)
					landed = true

	# Also hit pigs in PigSpawner
	var pig_nodes := get_tree().get_nodes_in_group("pig")
	for pn in pig_nodes:
		if not is_instance_valid(pn) or not pn.get("is_alive"):
			continue
		var offset: Vector3 = pn.global_position - global_position
		offset.y = 0.0
		var dist: float = offset.length()
		if dist <= max_dist + pn.hit_radius:
			var dot: float = fwd.dot(offset / dist)
			if dot >= angle_threshold:
					SFXManager.play_damage_hit()
					var dmg: int = attack_power
					if _is_player:
						var pc := self as PlayerCharacter
						if pc and pc.equipped_weapon:
							dmg += pc.equipped_weapon.atk_bonus
					pn.take_damage(dmg, self)
					landed = true

	# Also hit slimes in SlimeSpawner
	var slime_nodes := get_tree().get_nodes_in_group("slime")
	for sn in slime_nodes:
		if not is_instance_valid(sn) or not sn.get("is_alive"):
			continue
		var offset: Vector3 = sn.global_position - global_position
		offset.y = 0.0
		var dist: float = offset.length()
		if dist <= max_dist + sn.hit_radius:
			var dot: float = fwd.dot(offset / dist)
			if dot >= angle_threshold:
					SFXManager.play_damage_hit()
					var dmg: int = attack_power
					if _is_player:
						var pc := self as PlayerCharacter
						if pc and pc.equipped_weapon:
							dmg += pc.equipped_weapon.atk_bonus
					sn.take_damage(dmg, self)
					landed = true

	# Also hit fireflies (đom đóm — sinh vật nhỏ hp=1, không rớt gì)
	var firefly_nodes := get_tree().get_nodes_in_group("firefly")
	for ff in firefly_nodes:
		if not is_instance_valid(ff) or not ff.get("is_alive"):
			continue
		var offset: Vector3 = ff.global_position - global_position
		offset.y = 0.0
		var dist: float = offset.length()
		if dist <= max_dist + ff.hit_radius:
			var dot: float = fwd.dot(offset / dist)
			if dot >= angle_threshold:
					SFXManager.play_damage_hit()
					var dmg: int = attack_power
					if _is_player:
						var pc := self as PlayerCharacter
						if pc and pc.equipped_weapon:
							dmg += pc.equipped_weapon.atk_bonus
					ff.take_damage(dmg, self)
					landed = true

	# Also hit destroyable props (đèn, cây, v.v.)
	var weapon_id: String = ""
	if _is_player:
		var pc := self as PlayerCharacter
		if pc and pc.equipped_weapon != null:
			weapon_id = pc.equipped_weapon.id
	var tree := get_tree()
	if tree == null:
		return
	var prop_nodes := tree.get_nodes_in_group("destroyable_props")
	for pn in prop_nodes:
		if not is_instance_valid(pn):
			continue
		if not pn.has_method("try_destroy"):
			continue
		var offset: Vector3 = pn.global_position - global_position
		offset.y = 0.0
		var dist: float = offset.length()
		if dist <= max_dist:
			var dot: float = fwd.dot(offset / dist)
			if dot >= angle_threshold:
				var dmg: int = 1
				if _is_player:
					var pc := self as PlayerCharacter
					if pc and pc.equipped_weapon != null:
						dmg = pc.equipped_weapon.atk_bonus
				if pn.try_destroy(weapon_id, dmg):
					landed = true

	# Độ bền vũ khí: mỗi đòn trúng đích giảm 1 (như Minecraft)
	if landed and _is_player:
		var pc := self as PlayerCharacter
		if pc:
			pc._damage_equipped_tool(1)

func _find_character_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

# ── Read input direction ──────────────────────────────────────────────────────
func _read_input() -> Vector3:
	if _is_player:
		var rx: float = 0.0
		var rz: float = 0.0

		# Keyboard input (PC)
		if Input.is_action_pressed("move_forward"): rz -= 1.0
		if Input.is_action_pressed("move_back"):    rz += 1.0
		if Input.is_action_pressed("move_left"):    rx -= 1.0
		if Input.is_action_pressed("move_right"):   rx += 1.0

		# Virtual joystick input (Mobile) — ưu tiên nếu có tín hiệu
		if DeviceManager and DeviceManager.is_mobile():
			var mob_ctrl := _find_mobile_controls()
			if mob_ctrl and mob_ctrl.has_method("get") and mob_ctrl.joystick != null:
				var jv: Vector2 = mob_ctrl.joystick.call("get_vector")
				if jv.length_squared() > 0.001:
					rx = jv.x
					rz = jv.y

		if rx == 0.0 and rz == 0.0:
			return Vector3.ZERO
		if _camera == null:
			return Vector3.ZERO
		var cb:  Basis   = _camera.global_transform.basis
		var fwd: Vector3 = -cb.z; fwd.y = 0.0; fwd = fwd.normalized()
		var rgt: Vector3 =  cb.x; rgt.y = 0.0; rgt = rgt.normalized()
		return fwd * -rz + rgt * rx
	return Vector3.ZERO

## Tìm MobileControls node trong scene (nếu có)
func _find_mobile_controls() -> Node:
	var root := get_tree().current_scene
	if root == null: return null
	for ch in root.get_children():
		if ch.get_script() and ch.get_script().resource_path.ends_with("mobile_controls.gd"):
			return ch
	return null

func _swim_physics(delta: float) -> void:
	_Swim.swim_physics(self, delta)

func _calc_aim_dir() -> Vector3:
	var target := _find_nearest_target()
	if target != null:
		var dir := target.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			return dir.normalized()
	return global_transform.basis.z

func _find_nearest_target() -> CharacterBase:
	var mgr := _find_character_manager()
	if mgr == null:
		return null
	var best: CharacterBase = null
	var best_dsq := auto_aim_range * auto_aim_range
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != self and ch.is_alive and not ch._is_player:
			var dsq := global_position.distance_squared_to(ch.global_position)
			if dsq < best_dsq:
				best_dsq = dsq
				best = ch as CharacterBase
	return best

func _start_forward_lunge(speed: float, duration: float) -> void:
	_action_lunge_speed = speed
	_action_lunge_timer = duration

func _spawn_damage_number(dmg: int, attacker: Node3D = null, damage_type: int = 0) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	if damage_type < 0 or damage_type >= DamageType.size():
		damage_type = 0
	var col: Color = DAMAGE_TYPE_COLORS.get(damage_type, Color.WHITE)
	var type_name: String = DAMAGE_TYPE_NAMES.get(damage_type, "")
	var dn := FloatingDamage.new()
	world.add_child(dn)
	dn.setup(dmg, global_position + Vector3(0, 1.5, 0), col, type_name)

# ── Camera toggle ─────────────────────────────────────────────────────────────
func _toggle_camera() -> void:
	_use_tp = not _use_tp
	_sync_camera()
	await get_tree().process_frame
	_camera = get_viewport().get_camera_3d()

func _is_building_placing() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if not tree.root.has_meta("building_placement_active"):
		return false
	var val: Variant = tree.root.get_meta("building_placement_active")
	return bool(val)

func play_spawn_animation() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var col: Color = Color(0.5, 0.8, 1.0)
	var pos := global_position
	visible = false
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = col
	sphere_mat.albedo_color.a = 0.0
	sphere_mat.emission_enabled = true
	sphere_mat.emission = col * 1.5
	sphere_mat.emission.a = 0.0
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.1
	sph.height = 0.2
	sphere.mesh = sph
	sphere.material_override = sphere_mat
	parent.add_child(sphere)
	sphere.global_position = pos + Vector3(0, 0.8, 0)
	var sph_tw := create_tween()
	sph_tw.tween_property(sphere_mat, "albedo_color:a", 0.9, 0.15)
	sph_tw.parallel().tween_property(sphere_mat, "emission:a", 0.8, 0.15)
	sph_tw.parallel().tween_property(sphere, "scale", Vector3(8.0, 8.0, 8.0), 0.25).set_ease(Tween.EASE_OUT)
	sph_tw.tween_interval(0.15)
	sph_tw.tween_property(sphere_mat, "albedo_color:a", 0.0, 0.3)
	sph_tw.parallel().tween_property(sphere_mat, "emission:a", 0.0, 0.3)
	sph_tw.parallel().tween_property(sphere, "scale", Vector3(12.0, 12.0, 12.0), 0.3).set_ease(Tween.EASE_OUT)
	sph_tw.tween_callback(sphere.queue_free)
	var char_tw := create_tween()
	char_tw.tween_interval(0.5)
	char_tw.tween_callback(func() -> void: visible = true)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = col
	spark_mat.emission_enabled = true
	spark_mat.emission = col * 2.0
	var spark_tw := create_tween()
	spark_tw.tween_interval(0.25)
	for k in range(16):
		var sp := MeshInstance3D.new()
		var ss := SphereMesh.new()
		ss.radius = 0.05
		ss.height = 0.1
		sp.mesh = ss
		sp.material_override = spark_mat
		parent.add_child(sp)
		sp.global_position = pos + Vector3(0, 0.8, 0)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.5, 1.0), randf_range(-1, 1)).normalized()
		var dist := 1.0 + randf() * 2.5
		var st := create_tween()
		st.tween_property(sp, "global_position", sp.global_position + dir * dist, 0.6).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(sp, "scale", Vector3.ZERO, 0.6)
		st.tween_callback(sp.queue_free)

func _find_water_manager() -> OpenWorldManager:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("WorldManager") as OpenWorldManager
