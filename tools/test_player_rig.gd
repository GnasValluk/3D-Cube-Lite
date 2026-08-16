extends Node3D

## Rig test: build PlayerMesh blockout soulslike trong world thật, kiểm tra
## số xương/khối, đủ pivot equipment, và animate mọi trạng thái không ra NaN.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _has_nan(mesh: PlayerMesh) -> bool:
	for bn in mesh.bones.values():
		var n := bn as Node3D
		if n == null:
			continue
		var r: Vector3 = n.rotation
		var p: Vector3 = n.position
		if not (r.is_finite() and p.is_finite()):
			return true
	if not mesh.weapon_pivot.rotation_degrees.is_finite():
		return true
	return false

func _ready() -> void:
	print("== test_player_rig: blockout soulslike ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	for i in range(240):
		await get_tree().process_frame

	var player: Node = world.get_node_or_null("CharacterManager/Player")
	if player == null:
		print("FAIL | không có player trong world")
		get_tree().quit(1)
		return

	var mesh: PlayerMesh = player._mesh
	var anim: PlayerAnimator = player._anim
	_check(mesh != null, "player có PlayerMesh")
	_check(anim != null, "player có PlayerAnimator")
	if mesh == null or anim == null:
		get_tree().quit(1)
		return

	_check(mesh.bones.size() >= 40, "bones >= 40 (thực tế %d)" % mesh.bones.size())
	_check(mesh.box_count >= 120, "boxes >= 120 (thực tế %d)" % mesh.box_count)
	_check(mesh.bones.has("pelvis") and mesh.bones.has("spine_03") and mesh.bones.has("head"),
		"chuỗi Pelvis→Spine→Head đầy đủ")
	_check(mesh.bones.has("jaw") and mesh.bones.has("eye_l") and mesh.bones.has("eyelid_up_l"),
		"facial rig đầy đủ (jaw/eye/eyelid)")
	_check(mesh.bones.has("hand_l") and mesh.bones.has("hand_r"),
		"bàn tay đơn khối đầy đủ")
	_check(not mesh.bones.has("cape_01") and not mesh.bones.has("thumb_01_r"),
		"đã loại bỏ ngón tay + cape")

	for p in ["weapon_pivot", "helmet_pivot", "chestplate_pivot", "gauntlet_l_pivot",
			"gauntlet_r_pivot", "boot_l_pivot", "boot_r_pivot", "leg_armor_l_pivot",
			"leg_armor_r_pivot", "ring_pivot", "back_gear_pivot", "hair_pivot",
			"tails_pivot", "backpack"]:
		_check(mesh.get(p) != null, "pivot %s tồn tại" % p)

	# ── Sweep trạng thái: không NaN ──────────────────────────────────────────
	player.velocity = Vector3.ZERO
	var states := {
		"IDLE": CharacterBase.State.IDLE,
		"WALK": CharacterBase.State.WALK,
		"SPRINT": CharacterBase.State.SPRINT,
		"CROUCH": CharacterBase.State.CROUCH,
		"DASH": CharacterBase.State.DASH,
		"SWIM": CharacterBase.State.SWIM,
		"EAT": CharacterBase.State.EAT,
	}
	for name in states:
		player._state = states[name]
		for f in range(60):
			player._time += 0.016
			anim.animate(0.016)
		_check(not _has_nan(mesh), "no NaN sau %s" % name)

	# ── Gait engine: chân trụ KHÔNG trượt + spring hội tụ ─────────────────────
	player._state = CharacterBase.State.WALK
	player.velocity = Vector3(5, 0, 0)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var have_l := false
	var have_r := false
	var max_slide := 0.0
	var max_gap_l := 0.0
	var max_gap_r := 0.0
	var stance_frac := 0.6
	var settle := 60
	for f in range(260):
		player.global_position += Vector3(5 * 0.016, 0, 0)
		player._time += 0.016
		anim.animate(0.016)
		if f < settle:
			continue
		var lp: float = fmod(anim._step_phase, 1.0)
		var rp: float = fmod(anim._step_phase + 0.5, 1.0)
		var fl: Node3D = mesh.bones.get("foot_l") as Node3D
		var fr: Node3D = mesh.bones.get("foot_r") as Node3D
		if fl != null:
			var w := fl.global_position
			if lp < stance_frac:
				max_gap_l = maxf(max_gap_l, w.distance_to(anim._plant_l))
				if have_l:
					max_slide = maxf(max_slide, w.distance_to(prev_l))
				prev_l = w
				have_l = true
			else:
				have_l = false
		if fr != null:
			if rp < stance_frac:
				var w := fr.global_position
				max_gap_r = maxf(max_gap_r, w.distance_to(anim._plant_r))
				if have_r:
					max_slide = maxf(max_slide, w.distance_to(prev_r))
				prev_r = w
				have_r = true
			else:
				have_r = false
	# Slide <= 6cm/frame-stance trong nghệ thuật blocky là chân trụ; ngưỡng 0.06m.
	_check(max_slide < 0.06, "chân trụ KHÔNG trượt khi walk (max %.4fm)" % max_slide)
	_check(not _has_nan(mesh), "no NaN sau gait long-run")
	var sp: float = anim._sp_val.get("step_speed", 0.0)
	_check(anim._gait == 1 and absf(sp - 5.0) < 0.6, "step_speed hội tụ về vận tốc (%.2f)" % sp)
	var all_finite := true
	for k in anim._sp_val:
		var v: float = anim._sp_val[k]
		var u: float = anim._sp_vel.get(k, 0.0)
		if not (is_finite(v) and is_finite(u)):
			all_finite = false
	_check(all_finite, "spring state hữu hạn (no NaN/inf)")

	player._state = CharacterBase.State.HIT
	player._hit_timer = 0.18
	for f in range(20):
		player._time += 0.016
		anim.animate(0.016)
	_check(not _has_nan(mesh), "no NaN sau HIT")

	player._state = CharacterBase.State.JUMP
	player.velocity = Vector3(0, 6, 0)
	for f in range(30):
		player._time += 0.016
		anim.animate(0.016)
	player._state = CharacterBase.State.FALL
	player.velocity = Vector3(0, -6, 0)
	for f in range(30):
		player._time += 0.016
		anim.animate(0.016)
	_check(not _has_nan(mesh), "no NaN sau JUMP/FALL")

	player._state = CharacterBase.State.DEAD
	player._death_timer = 1.8
	for f in range(120):
		player._death_timer = max(0.0, player._death_timer - 0.016)
		player._time += 0.016
		anim.animate(0.016)
	_check(not _has_nan(mesh), "no NaN sau DEAD (wave collapse)")

	for step in [0, 1, 2]:
		player.combo_step = step
		player._state = CharacterBase.State.ATTACK
		player._attack_timer = 0.5
		player.attack_duration = 0.5
		anim._slash_spawned = false
		for f in range(40):
			player._state = CharacterBase.State.ATTACK
			player._attack_timer = max(0.0, player._attack_timer - 0.016)
			player._time += 0.016
			anim.animate(0.016)
		_check(not _has_nan(mesh), "no NaN sau ATTACK step %d" % step)
		player.combo_timer = 0.0

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)