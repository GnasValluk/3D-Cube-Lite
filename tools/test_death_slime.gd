extends Node3D

## Headless verification: Death Slime boss (egg_death_slime).
## Cấp cố định 100, không bonus lv, chỉ số theo get_stat_mult(), bất động,
## nhóm slime+death_slime, skill P1/P2, triệu hồi từ egg, chết → loot + exp.
## Chạy qua tools/test_death_slime.tscn.

const _EggProjectile = preload("res://scripts/items/entities/egg_projectile.gd")
const _DeathSlime = preload("res://scripts/characters/slime/death_slime.gd")

const BASE_HP:  int = 800
const BASE_ATK: int = 90
const BASE_DEF: int = 10

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _spawn_boss() -> Node:
	var existing: Array[Node] = []
	for ch in get_children():
		if ch.get_script() == _DeathSlime:
			existing.append(ch)
	var proj := _EggProjectile.new()
	add_child(proj)
	proj.global_position = Vector3(0, 0.5, 0)
	proj._egg_id = "egg_death_slime"
	proj._spawn_creature()
	for ch in get_children():
		if ch.get_script() == _DeathSlime and not existing.has(ch):
			ch.set_physics_process(false)
			return ch
	return null

func _make_player() -> Node3D:
	var p := CharacterBody3D.new()
	p.set_script(load("res://scripts/characters/player/player_character.gd"))
	p.set("_is_player", true)
	p.name = "Player"
	add_child(p)
	p.set_physics_process(false)
	return p

func _ready() -> void:
	seed(20260813)
	print("== test_death_slime: boss Death Slime sinh ra từ egg ==")
	ItemDatabase.ensure_db()

	# ── 1. Triệu hồi từ egg_death_slime ──
	var boss := _spawn_boss()
	_check(boss != null, "egg_death_slime nở ra Death Slime")
	if boss == null:
		get_tree().quit(1)
		return
	_check(boss.is_in_group("slime"), "boss vào group 'slime'")
	_check(boss.is_in_group("death_slime"), "boss vào group 'death_slime'")

	# ── 2. Cấp & bonus ──
	_check(boss.level == 100, "boss level = 100 (thực tế %d)" % boss.level)
	_check(boss.mob_bonus_lv == 0, "mob_bonus_lv = 0 (thực tế %d)" % boss.mob_bonus_lv)
	_check(boss.bio_bonus_lv == 0, "bio_bonus_lv = 0 (thực tế %d)" % boss.bio_bonus_lv)

	# ── 3. Chỉ số theo get_stat_mult() (lv100 → 2.98x) ──
	var smult: float = boss.get_stat_mult()
	var expect_hp: int = int(BASE_HP * smult)
	var expect_atk: int = int(BASE_ATK * smult)
	var expect_def: int = int(BASE_DEF * smult)
	_check(boss.max_hp == expect_hp, "max_hp theo lv (%d == %d)" % [boss.max_hp, expect_hp])
	_check(boss.hp == boss.max_hp, "hp đầy lúc sinh ra")
	_check(boss.attack_power == expect_atk, "attack_power theo lv (%d == %d)" % [boss.attack_power, expect_atk])
	_check(boss.defense == expect_def, "defense theo lv (%d == %d)" % [boss.defense, expect_def])

	# ── 4. Bất động ──
	_check(boss._read_input() == Vector3.ZERO, "boss bất động (_read_input = ZERO)")
	_check(boss.move_speed == 0.0 and boss.sprint_speed == 0.0, "move/sprint speed = 0")

	# ── 5. P1: Acide Cầu Vồng ──
	var player := _make_player()
	boss._player = player
	player.global_position = boss.global_position + Vector3(0, 0, 3.0)
	player.max_hp = 500
	player.hp = 500
	boss._cast_acid()
	_check(boss._puddles.size() == 1, "acid tạo 1 bãi độc")
	if boss._puddles.size() >= 1:
		var pd: Dictionary = boss._puddles[0]
		_check(is_instance_valid(pd["node"]), "bãi độc còn tồn tại")
		var hp0: int = player.hp
		boss._update_puddles(1.0)
		_check(player.hp < hp0, "bãi độc gây sát thương theo giây (%d → %d)" % [hp0, player.hp])
		var efx = player.get("effects")
		_check(efx != null and efx.get_slow_level() >= 3, "bãi độc làm chậm cấp 3")

	# ── 6. P1: Xúc Tu Đất ──
	boss._cast_tentacles()
	_check(boss._strikes.size() == 1, "xúc tu cảnh báo 1.5s")
	boss._update_strikes(0.2)  # vẫn đang cảnh báo, chưa có cột
	_check(boss._strikes[0]["column_node"] == null, "chưa tạo cột khi đang cảnh báo")
	player.global_position = (boss._strikes[0]["pos"] as Vector3) + Vector3(0, 0, 0.0)
	player._invul_timer = 0.0
	boss._update_strikes(1.5)  # hết cảnh báo → tạo cột
	_check(boss._strikes[0]["column_node"] != null, "cột xúc tu đã được tạo")
	var hp1: int = player.hp
	player._invul_timer = 0.0
	boss._update_strikes(0.1)  # lượt kế tiếp → cột đâm vào player
	_check(player.hp < hp1, "cột xúc tu gây sát thương (%d → %d)" % [hp1, player.hp])

	# ── 7. P1: Vòng Sóng Nhầy ──
	boss._cast_shockwave()
	_check(boss._waves.size() == 1, "shockwave tạo 1 vòng")
	var hp2: int = player.hp
	for i in range(30):
		player._invul_timer = 0.0
		boss._update_waves(0.1)
		if player.hp < hp2:
			break
	_check(player.hp < hp2, "sóng nhầy gây sát thương (%d → %d)" % [hp2, player.hp])

	# ── 8. P2: _enraged dưới 50% HP ──
	_check(not boss._enraged(), "chưa enrage khi HP đầy")
	boss.hp = boss.max_hp / 4
	_check(boss._enraged(), "enrage khi HP < 50%")

	# ── 9. P2: Chùm Bào Tử ──
	boss._spore_cd = 0.0
	boss._cast_spores()
	_check(boss._spores.size() >= 3 and boss._spores.size() <= 5, "spores tạo 3-5 minis (thực tế %d)" % boss._spores.size())
	var all_mini := true
	for sp in boss._spores:
		if not is_instance_valid(sp) or not sp.get("is_alive"):
			all_mini = false
	_check(all_mini, "các minis còn sống")
	_check(boss._spore_cd > 0.0, "spores có cooldown")

	# ── 10. P2: Void Devour one-shot ──
	player.is_alive = true  # hồi sinh sau khi bị sóng nhầy hạ
	player.max_hp = 300
	player.hp = 300
	player.global_position = boss.global_position + Vector3(0.5, 0.5, 0.5)  # trong MOUTH_RANGE
	boss._void_active = false
	boss._cast_void_devour()
	_check(boss._void_active, "void devour kích hoạt")
	boss._update_void(0.1)
	_check(boss._void_timer > 0.0, "void còn thời gian hoạt động")
	var hp3: int = player.hp
	for i in range(5):
		player._invul_timer = 0.0
		boss._update_void(0.1)
		if player.hp < hp3:
			break
	_check(player.hp < hp3, "void chạm mồm gây sát thương (%d → %d)" % [hp3, player.hp])

	# ── 11. Chết → loot slime_ball + exp ──
	boss.hp = 1
	boss._invul_timer = 0.0
	boss.take_damage(99999)
	_check(not boss.is_alive, "boss chết khi HP về 0")
	var loot_count := 0
	var orb_count := 0
	for ch in get_children():
		if ch is DroppedItem and ch.item_def != null:
			if ch.item_def.id == "slime_ball":
				loot_count += 1
		if ch is ExperienceOrb:
			orb_count += 1
	_check(loot_count >= 3, "rơi >= 3 slime_ball (thực tế %d)" % loot_count)
	_check(orb_count >= 10, "rơi >= 10 exp orb (thực tế %d)" % orb_count)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)