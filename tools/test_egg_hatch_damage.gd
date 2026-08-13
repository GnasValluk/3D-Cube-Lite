extends Node3D

## Headless verification: cá/heo nở từ trứng (added vào world, KHÔNG trong
## FishSpawner/PigSpawner) phải nhận sát thương từ đòn đánh cận chiến của player
## và từ đòn ném Kích Sắt.
## Chạy qua tools/test_egg_hatch_damage.tscn (không chạy trực tiếp file .gd).

const _EggProjectile = preload("res://scripts/items/entities/egg_projectile.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _spawn_fish(eid: String) -> Node:
	var existing: Array[Node] = []
	for ch in get_children():
		if ch is FishCharacter:
			existing.append(ch)
	var proj := _EggProjectile.new()
	add_child(proj)
	proj.global_position = Vector3(2, 0, 2)
	proj._egg_id = eid
	proj._spawn_creature()
	for ch in get_children():
		if ch is FishCharacter and not existing.has(ch):
			ch.set_physics_process(false)
			return ch
	return null

func _spawn_pig() -> Node:
	var proj := _EggProjectile.new()
	add_child(proj)
	proj.global_position = Vector3(-2, 0, 2)
	proj._egg_id = "egg_pig"
	proj._spawn_creature()
	for ch in get_children():
		if ch is PigCharacter:
			ch.set_physics_process(false)
			return ch
	return null

func _ready() -> void:
	seed(20260813)
	print("== test_egg_hatch_damage: cá/heo từ trứng bị sát thương ==")
	ItemDatabase.ensure_db()

	# ── 0. CharacterManager chứa player (để _do_melee_hit hoạt động) ──
	var mgr := CharacterManager.new()
	mgr.name = "CharacterManager"
	add_child(mgr)
	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/characters/player/player_character.gd"))
	player.set("_is_player", true)
	player.name = "Player"
	mgr.add_child(player)
	player.set_physics_process(false)

	# ── 1. Cá nở từ trứng: vào group 'fish', melee player gây sát thương ──
	var fish := _spawn_fish("egg_tilapia")
	_check(fish != null, "trứng nở cá điêu hồng")
	if fish == null:
		get_tree().quit(1)
		return
	_check(fish.is_in_group("fish"), "cá nở vào group 'fish'")
	player.global_position = fish.global_position + Vector3(0, 0, -1.0)
	player.rotation.y = 0.0
	var fish_hp0: int = fish.hp
	player._do_melee_hit()
	_check(fish.hp < fish_hp0, "melee player gây sát thương cá nở từ trứng (%d → %d)" % [fish_hp0, fish.hp])

	# ── 2. Heo nở từ trứng: vào group 'pig', melee gây sát thương ──
	var pig := _spawn_pig()
	_check(pig != null, "trứng nở heo con")
	if pig != null:
		_check(pig.is_in_group("pig"), "heo nở vào group 'pig'")
		pig.global_position = player.global_position + Vector3(0, 0, 0.6)
		var pig_hp: int = pig.hp
		player._do_melee_hit()
		_check(pig.hp < pig_hp, "melee player gây sát thương heo nở từ trứng (%d → %d)" % [pig_hp, pig.hp])

	# ── 3. Ném Kích Sắt gây sát thương cá nở từ trứng (cá mới, chưa bị đánh) ──
	if player.equipped_weapon == null:
		player.equipped_weapon = ItemDatabase.items_db.get("iron_halberd")
	var fish2 := _spawn_fish("egg_carp")
	if fish2 != null:
		fish2.global_position = player.global_position + Vector3(0, 0, 0.6)
		var fish_hp2: int = fish2.hp
		var dir: Vector3 = (fish2.global_position - player.global_position).normalized()
		PlayerHalberd._apply_throw_damage(player, dir, fish2.global_position, 30)
		_check(fish2.hp < fish_hp2, "ném Kích Sắt gây sát thương cá nở từ trứng (%d → %d)" % [fish_hp2, fish2.hp])

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)