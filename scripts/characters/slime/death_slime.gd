## slime/death_slime.gd
## BOOS DRAFT: Death Slime — Slime Tử Thần.
##
## Bất động (Stationary Boss): đứng yên tại điểm triệu hồi, chỉ quay mặt theo
## player. Cấp 100 cố định, KHÔNG nhận bonus level, chỉ số tự sinh từ level
## AAA: nồi máu/đòn đánh theo get_stat_mult() (mỗi level +2%).
##
## Ngoại hình: khối trụ voxel khổng lồ (gấp 4-5 lần player) với gradient cầu
## vồng cuộn xoáy, mặt kinh dị (hốc mắt đen + đồng tử lửa đỏ luôn nhìn player,
## nụ cười đen xé mang tai), chân xoè + tua rua cắm đất. Hoạt ảnh: thở
## phồng-xẹp, sóng nhầy chảy từ đỉnh xuống, mắt giật giật, voxel nhỏ rơi rồi
## hút về chân.
##
## Bộ kỹ năng:
##   P1:  Acide Cầu Vồng (bãi độc làm chậm 50% + sát thương theo giây),
##        Xúc Tu Đất (hồi chuông cảnh báo 1.5s → cột nhầy đâm lên hất văng),
##        Vòng Sóng Nhầy (Jelly Shockwave).
##   P2 (<50% HP): Chùm Bào Tử Tử Thần (3-5 minis slime tự sát),
##        Void Devour (hố đen hút player, chạm mồm → one-shot).

extends CharacterBase
class_name DeathSlime

const BOSS_LEVEL: int = 100

## Chỉ số gốc — nhân get_stat_mult() (lv100 → 2.98x)
const BASE_HP:  int = 800
const BASE_ATK: int = 90
const BASE_DEF: int = 10
const BASE_SCALE: float = 4.0

## Tầm & thời gian kỹ năng
const AGGRO_RANGE: float = 26.0
const SKILL_RANGE: float = 9.0
const MOUTH_RANGE: float = 3.2
const VOID_RANGE: float  = 14.0
const SKILL_COOLDOWN: float = 4.5

const RAINBOW: Array[Color] = [
	Color(0.95, 0.22, 0.75),  # hồng neon
	Color(0.95, 0.86, 0.20),  # vàng chanh
	Color(0.30, 0.95, 0.55),  # xanh lục
	Color(0.78, 0.38, 0.95),  # tím thạch anh
	Color(0.95, 0.55, 0.20),  # cam
]

const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _ExpOrb = preload("res://scripts/items/entities/experience_orb.gd")
const _MiniSlime = preload("res://scripts/characters/slime/slime_character.gd")

var _body: Node3D
var _legs: Node3D
var _tentacles: Node3D
var _face: Node3D
var _eye_l: Node3D
var _eye_r: Node3D
var _pupil_l: MeshInstance3D
var _pupil_r: MeshInstance3D
var _pupil_root_l: Node3D
var _pupil_root_r: Node3D
var _smile: MeshInstance3D
var _smile_base_y: float = 0.0
var _void_orb: MeshInstance3D

var _player: Node3D = null
var _skill_cd: float = 2.0
var _facing_yaw: float = 0.0
var _wave_phase: float = 0.0
var _pupil_wiggle: float = 0.0
var _home: Vector3 = Vector3.ZERO

## Puddles acid: { node, life, tick, radius }
var _puddles: Array = []
## Shockwaves: { node, dist, speed }
var _waves: Array = []
## Tentacle strikes: { ring_node, delay, column_node }
var _strikes: Array = []
## Chùm bào tử: minis slime tự sát
var _spores: Array = []
var _spore_cd: float = 0.0

## Void Devour
var _void_active: bool = false
var _void_timer: float = 0.0
var _void_chomp_cd: float = 0.0

const MAX_SKILLS: int = 3  # P1
const MAX_SKILLS_P2: int = 5  # P2 thêm bào tử + void

func _enraged() -> bool:
	return hp < max_hp / 2

# ── Setup ────────────────────────────────────────────────────────────────────
func _build_character() -> void:
	_is_player = false
	character_name = "Death Slime"
	# Level cố định, KHÔNG bonus
	mob_bonus_lv = 0
	bio_bonus_lv = 0
	level = BOSS_LEVEL
	var smult: float = get_stat_mult()
	max_hp = int(BASE_HP * smult)
	hp = max_hp
	attack_power = int(BASE_ATK * smult)
	defense = int(BASE_DEF * smult)
	move_speed = 0.0
	sprint_speed = 0.0
	acceleration = 40.0
	friction = 30.0
	jump_height = 0.01
	jump_time_rise = 0.01
	jump_time_fall = 0.01
	melee_range = MOUTH_RANGE
	hit_radius = 2.1
	_world_hp_enabled = true

	scale = Vector3(BASE_SCALE, BASE_SCALE, BASE_SCALE)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.2
	shape.height = 5.4
	col.shape = shape
	col.position = Vector3(0, 2.7, 0)
	add_child(col)

	_build_mesh()

func _build_mesh() -> void:
	_rig = Node3D.new()
	_rig.name = "DeathSlimeRig"
	add_child(_rig)
	_body         = Node3D.new(); _body.name = "Body";    _rig.add_child(_body)
	_legs         = Node3D.new(); _legs.name = "Legs";    _rig.add_child(_legs)
	_tentacles    = Node3D.new(); _tentacles.name = "Tentacles"; _rig.add_child(_tentacles)
	_face         = Node3D.new(); _face.name = "Face";    _rig.add_child(_face)

	# ── Thân: trụ voxel 6 tầng, mỗi tầng một màu cầu vồng (bước chụm) ──
	for i in range(6):
		var y: float = 0.0 + i * 0.52
		var r: float = lerp(1.15, 0.85, float(i) / 5.0)
		if i % 2 == 1:
			r *= 0.94  # tạo răng cưa voxel
		var mat := MeshBuilder.emit_mat(RAINBOW[i % 5] * 0.75, RAINBOW[i % 5], 0.35)
		MeshBuilder.cylinder(_body, Vector3(0, y + 0.26, 0), r, 0.52, mat)

	# ── Chân xoè 4 trụ nhỏ ──
	for k in range(4):
		var ang := TAU * float(k) / 4.0
		var cx := cos(ang) * 0.85
		var cz := sin(ang) * 0.85
		var foot := MeshBuilder.cylinder(_legs, Vector3(cx, 0.12, cz), 0.28, 0.24,
			MeshBuilder.emit_mat(Color(0.25, 0.22, 0.30), Color(0.15, 0.12, 0.2), 0.1))
		foot.rotation.y = ang

	# ── Tua rua / xúc tu cắm đất ──
	for k in range(6):
		var ang := TAU * float(k) / 6.0 + 0.4
		var cx := cos(ang) * 1.25
		var cz := sin(ang) * 1.25
		var ten := MeshBuilder.cylinder(_tentacles, Vector3(cx, 1.1, cz), 0.07, 2.3,
			MeshBuilder.emit_mat(RAINBOW[k % 5] * 0.5, RAINBOW[k % 5] * 0.6, 0.3))
		ten.rotation.z = cos(ang) * 0.55
		ten.rotation.x = -sin(ang) * 0.55

	# ── Mặt kinh dị ở tầng trên (+Z = hướng nhìn) ──
	# Hốc mắt đen tuyền
	var socket_mat := MeshBuilder.emit_mat(Color(0.01, 0.0, 0.02), Color(0, 0, 0), 0.0)
	var socket_sz := Vector3(0.62, 0.78, 0.16)
	MeshBuilder.box(_face, Vector3(-0.44, 1.62, 1.03), socket_sz, socket_mat)
	MeshBuilder.box(_face, Vector3( 0.44, 1.62, 1.03), socket_sz, socket_mat)
	# Đồng tử lửa đỏ — đặt dưới pivot riêng để xoay "nhìn theo" player
	var pupil_mat := MeshBuilder.emit_mat(Color(1.0, 0.08, 0.05), Color(1.0, 0.1, 0.05), 2.6)
	var pupil_sz := Vector3(0.30, 0.42, 0.12)
	_pupil_root_l = Node3D.new(); _pupil_root_l.position = Vector3(-0.44, 1.62, 1.12); _face.add_child(_pupil_root_l)
	_pupil_root_r = Node3D.new(); _pupil_root_r.position = Vector3( 0.44, 1.62, 1.12); _face.add_child(_pupil_root_r)
	_pupil_l = MeshBuilder.box(_pupil_root_l, Vector3.ZERO, pupil_sz, pupil_mat)
	_pupil_r = MeshBuilder.box(_pupil_root_r, Vector3.ZERO, pupil_sz, pupil_mat)
	# Nụ cười xé mang tai (đen)
	_smile = MeshBuilder.box(_face, Vector3(0, 1.12, 1.06),
		Vector3(1.45, 0.10, 0.12), socket_mat)
	_smile_base_y = 1.12
	# Khoé miệng cong lên
	MeshBuilder.box(_face, Vector3(-0.68, 1.24, 1.02), Vector3(0.24, 0.18, 0.10), socket_mat)
	MeshBuilder.box(_face, Vector3( 0.68, 1.24, 1.02), Vector3(0.24, 0.18, 0.10), socket_mat)

	# Hố đen (ẩn) — khối cầu đen sẫm đặt trước miệng
	_void_orb = MeshBuilder.sphere(_face, Vector3(0, 1.15, 1.9), 0.5,
		MeshBuilder.emit_mat(Color(0.02, 0.0, 0.05), Color(0.1, 0.0, 0.2), 1.6))
	_void_orb.visible = false

func _ready() -> void:
	super._ready()
	_home = global_position
	add_to_group("slime")
	add_to_group("death_slime")

# ── Tìm player ───────────────────────────────────────────────────────────────
func _find_player() -> Node3D:
	var world := get_tree().current_scene
	if world == null:
		return null
	var mgr := world.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		return mgr.get_current_character()
	return null

func _read_input() -> Vector3:
	return Vector3.ZERO  # bất động

# ── AI chính (gọi trong _physics_process của CharacterBase) ──────────────────
func _animate(delta: float) -> void:
	if not is_alive:
		return
	_time += delta
	_wave_phase += delta * 1.4
	_pupil_wiggle = maxf(_pupil_wiggle - delta, 0.0)

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()

	_update_face()
	_update_void(delta)
	_update_puddles(delta)
	_update_waves(delta)
	_update_strikes(delta)
	_update_spores(delta)

	if _player and is_instance_valid(_player) and _player.get("is_alive"):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		# Quay mặt theo player
		if dist > 0.3:
			_facing_yaw = lerp_angle(_facing_yaw, atan2(to_player.x, to_player.z), delta * 10.0)
			rotation.y = _facing_yaw
		# Bắn kỹ năng theo chu kỳ
		_skill_cd -= delta
		if _skill_cd <= 0.0 and dist < SKILL_RANGE:
			_skill_cd = SKILL_COOLDOWN
			_cast_skill()

	# Sóng nhầy: lớp xoáy màu trượt từ đỉnh xuống đáy
	if _face:
		var y_off := 0.55 + 0.5 * sin(_wave_phase)
		_smile.position.y = _smile_base_y + 0.05 * sin(_wave_phase * 2.0)
		_face.position.y = y_off * 0.0  # giữ gốc; vòng màu xử lý riêng

	# Thở phồng-xẹp nhẹ (jelly) + giật mắt
	if _body:
		var pulse := 1.0 + 0.025 * sin(_time * 2.2)
		_body.scale = Vector3(pulse, 1.0 / pulse, pulse)

	_spawn_drip_voxel(delta)

	# Đồng tử nhìn player
	if _player and is_instance_valid(_player):
		var e := global_transform.basis.y
		var to_p: Vector3 = _player.global_position - global_position
		var local_p := global_transform.basis.inverse() * to_p
		var lx := clampf(local_p.x / 2.0, -0.14, 0.14)
		var ly := clampf(local_p.y / 2.0, -0.12, 0.12)
		var wob := 0.0
		if _pupil_wiggle > 0.0:
			wob = sin(_time * 46.0) * 0.04
		_pupil_root_l.position.x = -0.44 + lx + wob
		_pupil_root_l.position.y = 1.62 + ly
		_pupil_root_r.position.x = 0.44 + lx - wob
		_pupil_root_r.position.y = 1.62 + ly

## Voxel nhỏ rơi quanh thân rồi hút về chân
const MAX_DRIPS: int = 18
var _drip_t: float = 0.0
var _drips: Array = []

func _spawn_drip_voxel(delta: float) -> void:
	if not is_inside_tree():
		return
	_drip_t -= delta
	if _drip_t > 0.0:
		return
	_drip_t = 0.22
	if _drips.size() >= MAX_DRIPS:
		return
	var world := get_parent()
	if world == null:
		return
	var mat := MeshBuilder.emit_mat(RAINBOW[randi() % 5] * 0.7, RAINBOW[randi() % 5], 0.4)
	var mi := MeshBuilder.box(world, global_position + Vector3(
		randf_range(-1.6, 1.6), 2.6 + randf_range(0, 1.6), randf_range(-1.6, 1.6)),
		Vector3(0.14, 0.14, 0.14), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var home := global_position + Vector3(0, 0.35, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", home + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), 0.9).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.9)
	tw.tween_callback(mi.queue_free)
	_drips.append(mi)
	if _drips.size() > MAX_DRIPS:
		_drips.pop_front()

func _process_get_delta_reference() -> float:
	return 1.0 / 60.0

## Vẻ mặt: mắt giật giật khi player ở gần
func _update_face() -> void:
	if not _face:
		return
	if _player and is_instance_valid(_player):
		var d := global_position.distance_to(_player.global_position)
		if d < SKILL_RANGE and randf() < 0.01:
			_pupil_wiggle = 0.25

# ── Kỹ năng ──────────────────────────────────────────────────────────────────
func _cast_skill() -> void:
	if _enraged() and randi() % 2 == 0 and _void_timer <= 0.0:
		_cast_void_devour()
		return
	var skills: Array = [ "acid", "tentacles", "shockwave" ]
	if _enraged():
		skills.append_array([ "spores", "spores" ])
	var pick: String = skills[randi() % skills.size()]
	match pick:
		"acid":       _cast_acid()
		"tentacles":  _cast_tentacles()
		"shockwave":  _cast_shockwave()
		"spores":     _cast_spores()

## P1 — Acide Cầu Vồng: bãi độc làm chậm 50% (slow cấp 3) + damage theo giây
func _cast_acid() -> void:
	if _player == null:
		return
	var world := get_parent()
	if world == null:
		return
	var pos: Vector3 = _player.global_position
	pos.y = global_position.y
	var puddle := Node3D.new()
	puddle.name = "AcidPuddle"
	world.add_child(puddle)
	puddle.global_position = pos
	var mat := MeshBuilder.emit_mat(Color(0.4, 0.05, 0.6, 0.5), Color(0.5, 0.1, 0.7), 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshBuilder.cylinder(puddle, Vector3(0, 0.03, 0), 2.6, 0.06, mat)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 6.0).set_delay(4.0)
	_puddles.append({ "node": puddle, "life": 7.0, "tick": 0.0, "radius": 2.4 })
	SFXManager.play_fizz()

## P1 — Xúc Tu Đất: hồi chuông 1.5s tại chỗ player → cột nhầy đâm lên hất văng
func _cast_tentacles() -> void:
	if _player == null:
		return
	var world := get_parent()
	if world == null:
		return
	var pos: Vector3 = _player.global_position
	pos.y = global_position.y
	var ring := Node3D.new()
	ring.name = "TentacleWarning"
	world.add_child(ring)
	ring.global_position = pos
	var warn := MeshBuilder.emit_mat(Color(0.9, 0.1, 0.15, 0.55), Color(0.9, 0.1, 0.15), 0.7)
	warn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warn.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshBuilder.cylinder(ring, Vector3(0, 0.05, 0), 1.7, 0.1, warn)
	var tw := create_tween()
	tw.tween_property(warn, "albedo_color:a", 1.0, 1.5)
	_strikes.append({ "ring_node": ring, "delay": 1.5, "pos": pos, "column_node": null })

## P1 — Vòng Sóng Nhầy: vòng xung kích lan rộng theo giây
func _cast_shockwave() -> void:
	var world := get_parent()
	if world == null:
		return
	var wave := Node3D.new()
	wave.name = "JellyWave"
	world.add_child(wave)
	wave.global_position = global_position
	var mat := MeshBuilder.emit_mat(Color(0.1, 0.9, 0.8, 0.5), Color(0.1, 0.9, 0.8), 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := MeshBuilder.cylinder(wave, Vector3(0, 0.04, 0), 0.5, 0.08, mat)
	ring.material_override = mat
	_waves.append({ "node": wave, "dist": 0.5, "speed": 7.0, "max": 11.0, "hit": {} })

## P2 — Chùm Bào Tử Tử Thần: 3-5 minis slime tự sát, nổ khi chạm player
func _cast_spores() -> void:
	if _spore_cd > 0.0:
		return
	_spore_cd = 6.0
	var parent := get_parent()
	if parent == null:
		return
	var count := randi_range(3, 5)
	for i in range(count):
		var mini := CharacterBody3D.new() as CharacterBody3D
		mini.set_script(_MiniSlime)
		mini.set("slime_size", SlimeCharacter.SlimeSize.SMALL)
		mini.name = "DeathSpore_%d" % randi()
		parent.add_child(mini)
		var ang := TAU * float(i) / float(count) + randf() * 0.5
		mini.global_position = global_position + Vector3(cos(ang) * 2.0, 0.5, sin(ang) * 2.0)
		mini.set("_home", global_position)
		mini.set("attack_power", int(attack_power * 0.5))
		# Đánh dấu tự sát: phát nổ ngay khi gần player
		mini.set_meta("death_spore", true)
		mini.tree_exited.connect(func(spore = mini): _spores.erase(spore))
		_spores.append(mini)
	SFXManager.play_slime_big()

## Sát thương phạm vi quanh 1 điểm
func _aoe_damage(center: Vector3, radius: float, dmg: int, knock: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.get("is_alive"):
		return
	var d: float = _player.global_position.distance_to(center)
	if d <= radius:
		_player.take_damage(dmg, self)
		if knock > 0.0:
			var away: Vector3 = _player.global_position - center
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			away = away.normalized()
			_player.velocity += Vector3(away.x * knock, knock * 0.7, away.z * knock)

## P2 — Void Devour: hố đen hút player; chạm mồm → one-shot
func _cast_void_devour() -> void:
	if _void_active:
		return
	_void_active = true
	_void_timer = 5.0
	_void_chomp_cd = 0.0
	if _void_orb:
		_void_orb.visible = true
		var tw := create_tween()
		tw.tween_property(_void_orb, "scale", Vector3(2.2, 2.2, 2.2), 0.8)

func _update_void(delta: float) -> void:
	if not _void_active:
		return
	_void_timer -= delta
	_void_chomp_cd -= delta
	if _void_orb:
		_void_orb.rotation.y += delta * 3.0
	if _player and is_instance_valid(_player) and _player.get("is_alive"):
		var to_p := _player.global_position - global_position
		var dist := to_p.length()
		# Hút player về mồm
		if dist > MOUTH_RANGE and dist < VOID_RANGE:
			var pull: Vector3 = to_p.normalized()
			_player.velocity.x += pull.x * 45.0 * delta
			_player.velocity.z += pull.z * 45.0 * delta
			_player.velocity.y += -2.0 * delta
		# Chạm mồm → nhai → one-shot
		if dist <= MOUTH_RANGE:
			if _void_chomp_cd <= 0.0:
				_void_chomp_cd = 0.35
				_player.take_damage(int(_player.get("max_hp")) * 10, self)
				SFXManager.play_slime_big()
	if _void_timer <= 0.0:
		_void_active = false
		if _void_orb:
			_void_orb.visible = false
			_void_orb.scale = Vector3(1, 1, 1)

func _update_puddles(delta: float) -> void:
	for i in range(_puddles.size() - 1, -1, -1):
		var pd: Dictionary = _puddles[i]
		pd["life"] -= delta
		pd["tick"] -= delta
		var nd: Node3D = pd["node"]
		if pd["life"] <= 0.0 or not is_instance_valid(nd):
			if is_instance_valid(nd):
				nd.queue_free()
			_puddles.remove_at(i)
			continue
		if pd["tick"] <= 0.0:
			pd["tick"] = 0.6
			if _player and is_instance_valid(_player) and _player.get("is_alive"):
				var d := _player.global_position.distance_to(nd.global_position)
				if d <= pd["radius"]:
					_player.take_damage(_acid_tick_dmg(), self)
					var efx = _player.get("effects")
					if efx:
						efx.apply_slow(3, 2.2)

func _acid_tick_dmg() -> int:
	return maxi(10, int(attack_power / 5))

func _update_waves(delta: float) -> void:
	for i in range(_waves.size() - 1, -1, -1):
		var w: Dictionary = _waves[i]
		var nd: Node3D = w["node"]
		w["dist"] += w["speed"] * delta
		var m := nd.get_child(0) as MeshInstance3D
		if m:
			var cyl := m.mesh as CylinderMesh
			if cyl:
				cyl.top_radius = w["dist"]
				cyl.bottom_radius = w["dist"]
		if _player and is_instance_valid(_player) and _player.get("is_alive"):
			var d := _player.global_position.distance_to(nd.global_position)
			if d + 1.0 >= w["dist"] and d - 1.0 <= w["dist"]:
				if not w["hit"].has(_player.get_instance_id()):
					w["hit"][_player.get_instance_id()] = true
					_player.take_damage(int(attack_power * 0.8), self)
					_aoe_damage(nd.global_position, 9.0, 0, 9.0)
		if w["dist"] >= w["max"] or not is_instance_valid(nd):
			if is_instance_valid(nd):
				nd.queue_free()
			_waves.remove_at(i)

func _update_strikes(delta: float) -> void:
	for i in range(_strikes.size() - 1, -1, -1):
		var st: Dictionary = _strikes[i]
		st["delay"] -= delta
		if st["delay"] > 0.0:
			continue
		if st["column_node"] == null or not is_instance_valid(st["column_node"]):
			var world := get_parent()
			if world == null:
				_strikes.remove_at(i)
				continue
			var col_node := Node3D.new()
			col_node.name = "TentacleColumn"
			world.add_child(col_node)
			col_node.global_position = st["pos"]
			var mat := MeshBuilder.emit_mat(Color(0.55, 0.1, 0.85), Color(0.6, 0.2, 0.9), 0.9)
			MeshBuilder.cylinder(col_node, Vector3(0, 1.2, 0), 0.9, 2.4, mat)
			st["column_node"] = col_node
			var tw := create_tween()
			tw.tween_property(col_node, "position:y", 3.0, 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_property(col_node, "scale", Vector3(1, 0.05, 1), 0.8).set_delay(0.6)
		else:
			if _player and is_instance_valid(_player) and _player.get("is_alive"):
				var d := _player.global_position.distance_to(st["pos"])
				if d <= 2.6:
					_player.take_damage(int(attack_power * 1.2), self)
					_aoe_damage(st["pos"], 2.6, 0, 14.0)
			_strikes.remove_at(i)

func _update_spores(delta: float) -> void:
	_spore_cd = maxf(_spore_cd - delta, 0.0)
	for i in range(_spores.size() - 1, -1, -1):
		var sp: CharacterBody3D = _spores[i]
		if not is_instance_valid(sp):
			_spores.remove_at(i)
			continue
		if not sp.get("is_alive"):
			_spores.remove_at(i)
			continue
		if _player and is_instance_valid(_player) and _player.get("is_alive"):
			var d := sp.global_position.distance_to(_player.global_position)
			if d < 1.6:
				_spore_explode(sp)

func _spore_explode(spore: CharacterBody3D) -> void:
	if not is_instance_valid(spore):
		return
	var world := get_parent()
	_spores.erase(spore)
	if _player and is_instance_valid(_player) and _player.get("is_alive"):
		var d := _player.global_position.distance_to(spore.global_position)
		if d <= 3.0:
			_player.take_damage(int(attack_power * 0.45), self)
		if world:
			_spawn_spore_boom(world, spore.global_position)
	if is_instance_valid(spore):
		spore.take_damage(999999, self)

func _spawn_spore_boom(world: Node, pos: Vector3) -> void:
	var mat := MeshBuilder.emit_mat(Color(0.95, 0.1, 0.9, 0.9), Color(0.95, 0.1, 0.9), 1.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flash := MeshBuilder.sphere(world, pos + Vector3(0, 0.4, 0), 0.3, mat)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3(3.0, 3.0, 3.0), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "scale", Vector3.ZERO, 0.3).set_delay(0.35)
	tw.tween_callback(flash.queue_free)
	SFXManager.play_slime_big()

# ── Nhận sát thương ──────────────────────────────────────────────────────────
func take_damage(dmg: int, attacker: Node3D = null, damage_type: int = 0) -> void:
	super.take_damage(dmg, attacker, damage_type)
	if _smile and is_alive:
		_smile.position.y = _smile_base_y - 0.06  # nhăn khi bị đánh

# ── Chết ─────────────────────────────────────────────────────────────────────
func _die(_attacker: Node3D = null) -> void:
	for pd in _puddles:
		if is_instance_valid(pd["node"]):
			pd["node"].queue_free()
	for w in _waves:
		if is_instance_valid(w["node"]):
			w["node"].queue_free()
	for st in _strikes:
		if is_instance_valid(st["ring_node"]):
			st["ring_node"].queue_free()
	roll_loot()
	roll_exp()
	_void_active = false
	if _void_orb:
		_void_orb.visible = false
	super._die(_attacker)

func roll_loot() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	ItemDatabase.ensure_db()
	for k in range(3):
		var defn: ItemDef = ItemDatabase.items_db.get("slime_ball")
		if defn:
			var vel := Vector3(randf_range(-1.0, 1.0), randf_range(2.5, 4.0), randf_range(-1.0, 1.0))
			_DroppedItem.spawn(world, defn, global_position, randi_range(3, 6), vel, global_position.y)

func roll_exp() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	for k in range(20):
		_ExpOrb.spawn(world, global_position + Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2)), global_position.y)