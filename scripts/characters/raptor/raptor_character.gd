## raptor/raptor_character.gd – Velociraptor Neon (Nhân vật 1)
## Entry point: extends CharacterBase, tạo mesh và animator, delegate animate().

extends CharacterBase
class_name RaptorCharacter

var _mesh: RaptorMesh
var _anim: RaptorAnimator

var _burst_count:   int   = 0
var _burst_elapsed: float = 0.0
const BURST_INTERVAL: float = 0.08
const BURST_SHOTS:    int   = 3

var _r_buff_timer: float = 0.0
var _base_move_speed: float = 0.0
var _base_sprint_speed: float = 0.0
var _base_lmb_cooldown: float = 0.0
const R_BUFF_DURATION: float = 3.0
const R_BUFF_SPEED_MULT: float = 2.0

func _build_character() -> void:
	move_speed   = 6.5
	sprint_speed = 9.5
	jump_height  = 1.4
	attack_duration = 0.40
	_attack2_duration = 0.90
	melee_range  = 1.5
	melee_damage = 10
	attack_power = 135
	defense = 26
	lmb_cooldown = 0.6
	q_cooldown   = 1.5
	r_cooldown   = 5.0
	max_hp = 340
	mana_cost_q = 50
	mana_cost_r = 50
	character_name = "Raptor"
	element = Element.DIEN
	_base_move_speed = move_speed
	_base_sprint_speed = sprint_speed
	_base_lmb_cooldown = lmb_cooldown

	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.28; cs.height = 1.10
	col.shape = cs; col.position = Vector3(0, 0.55, 0)
	add_child(col)

	_mesh = RaptorMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

	_anim = RaptorAnimator.new()
	_anim.setup(_mesh, self)

func _on_primary_attack() -> void:
	_burst_count   = 0
	_burst_elapsed = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _r_buff_timer > 0.0:
		_r_buff_timer = max(_r_buff_timer - delta, 0.0)
		if _r_buff_timer <= 0.0:
			_deactivate_r_buff()
	if _state != State.ATTACK:
		return
	_burst_elapsed += delta
	while _burst_count < BURST_SHOTS and _burst_elapsed >= _burst_count * BURST_INTERVAL:
		_spawn_bullet()
		_burst_count += 1

func _activate_r_buff() -> void:
	_r_buff_timer = R_BUFF_DURATION
	move_speed = _base_move_speed * R_BUFF_SPEED_MULT
	sprint_speed = _base_sprint_speed * R_BUFF_SPEED_MULT
	lmb_cooldown = 0.0

func _deactivate_r_buff() -> void:
	move_speed = _base_move_speed
	sprint_speed = _base_sprint_speed
	lmb_cooldown = _base_lmb_cooldown

func _spawn_bullet() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var bullet := RaptorBullet.new()
	var muzzle: Vector3 = global_position + Vector3(0, 0.8, 0)
	if _mesh and _mesh.neck:
		muzzle = _mesh.neck.global_position + Vector3(0, 0.05, 0)
	var fire_dir: Vector3 = _aim_dir if _aim_dir.length_squared() > 0.001 else global_transform.basis.z
	parent.add_child(bullet)
	bullet.setup(muzzle, fire_dir, self)

func _on_secondary_attack() -> void:
	var mgr: Node = _find_character_manager()
	if mgr == null:
		return
	var targets: Array[Vector3] = []
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != self and ch.is_alive and ch._active:
			var d: float = global_position.distance_to(ch.global_position)
			if d <= 10.0:
				ch.take_damage(calc_skill_damage(75), self)
				targets.append(ch.global_position)
	if targets.size() > 0:
		_activate_r_buff()
	if targets.size() == 0:
		targets.append(global_position + global_transform.basis.z * 5.0)
	var lightning: RaptorLightning = RaptorLightning.new()
	mgr.add_child(lightning)
	lightning.setup(global_position, targets, self)

func _on_dash() -> void:
	var mgr := _find_character_manager()
	if mgr == null:
		return
	var targets: Array[CharacterBase] = []
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != self and ch.is_alive and ch._active:
			var d := global_position.distance_to(ch.global_position)
			if d <= 7.0:
				targets.append(ch as CharacterBase)
	for t in targets:
		for i in range(3):
			get_tree().create_timer(i * 0.08).timeout.connect(_strike.bind(t, mgr))

func _strike(ch: CharacterBase, mgr: Node) -> void:
	if not is_instance_valid(ch) or not ch.is_alive:
		return
	ch.take_damage(calc_skill_damage(50), self)
	_spawn_dash_bolt(global_position, ch.global_position, mgr)
	var hit_mat := MeshBuilder.emit_mat(Color(1.0, 0.85, 0.20, 0.7), Color(1.0, 0.80, 0.10), 8.0)
	var hit := MeshInstance3D.new()
	var hsph := SphereMesh.new()
	hsph.radius = 0.06
	hsph.height = 0.12
	hit.mesh = hsph
	hit.material_override = hit_mat
	mgr.add_child(hit)
	hit.global_position = ch.global_position + Vector3(0, 0.5, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(hit, "scale", Vector3(3, 3, 3), 0.15)
	tw.tween_property(hit_mat, "emission_energy_multiplier", 0.0, 0.15)
	tw.tween_callback(func(): if is_instance_valid(hit): hit.queue_free())

func _spawn_dash_bolt(origin: Vector3, target: Vector3, mgr: Node) -> void:
	var root := Node3D.new()
	mgr.add_child(root)
	root.global_position = origin
	var diff := target - origin
	var dist := diff.length()
	if dist < 0.1:
		get_tree().create_timer(0.15).timeout.connect(func(): if is_instance_valid(root): root.queue_free())
		return
	var fwd := diff / dist
	var seg_count := 3
	var prev := Vector3.ZERO
	for i in range(seg_count):
		var seg_end := float(i + 1) / float(seg_count)
		var pos := fwd * dist * seg_end
		if i < seg_count - 1:
			var spread := dist * 0.035
			pos += Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.5, randf_range(-spread, spread))
		var seg_vec := pos - prev
		var seg_len := seg_vec.length()
		if seg_len < 0.01:
			prev = pos
			continue
		var seg_n := seg_vec / seg_len
		var bolt_mat := MeshBuilder.emit_mat(Color(1.0, 0.85, 0.20, 0.85), Color(1.0, 0.80, 0.10), 10.0)
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.015
		c.bottom_radius = 0.025
		c.height = seg_len
		mi.mesh = c
		mi.material_override = bolt_mat
		mi.position = (prev + pos) * 0.5
		if seg_n != Vector3.UP and seg_n != Vector3.DOWN:
			mi.quaternion = Quaternion(Vector3.UP, seg_n)
		root.add_child(mi)
		if i == seg_count - 1:
			var tip_mat := MeshBuilder.emit_mat(Color(1.0, 0.85, 0.20, 0.9), Color(1.0, 0.80, 0.10), 10.0)
			var tip := MeshInstance3D.new()
			var tsph := SphereMesh.new()
			tsph.radius = 0.04
			tsph.height = 0.08
			tip.mesh = tsph
			tip.material_override = tip_mat
			tip.position = pos
			root.add_child(tip)
		prev = pos
	get_tree().create_timer(0.15).timeout.connect(func(): if is_instance_valid(root): root.queue_free())

func _on_show_animation() -> void:
	_attack2_timer = _attack2_duration
	_state = State.DEVOUR

func _animate(delta: float) -> void:
	_anim.animate(delta)
