extends Node3D

## Headless verification: trứng sinh vật — item trong db (chỉ có ở thư viện),
## icon mesh, nhận diện item trứng, projectile parabol, và nở sinh vật khi
## chạm đất/nước (cá theo loài / heo con).
## Chạy qua tools/test_eggs.tscn (không chạy trực tiếp file .gd).

const _EggProjectile = preload("res://scripts/items/entities/egg_projectile.gd")
const _EggThrow = preload("res://scripts/characters/player/player_egg_throw.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _count_type(script_obj) -> int:
	var count := 0
	for ch in get_children():
		if ch.get_script() == script_obj:
			count += 1
	return count

func _ready() -> void:
	seed(20260802)
	print("== test_eggs: Trứng sinh vật (ném parabol, nở cá/heo) ==")

	# ── 1. Item database: 7 trứng + không bị ăn (MATERIAL) ──
	ItemDatabase.ensure_db()
	var egg_ids := ["egg_carp", "egg_perch", "egg_tilapia", "egg_snakehead",
		"egg_flowerhorn", "egg_shrimp", "egg_pig", "egg_death_slime"]
	var all_ok := true
	for eid in egg_ids:
		if not ItemDatabase.items_db.has(eid):
			all_ok = false
			continue
		var defn: ItemDef = ItemDatabase.items_db[eid]
		if defn.type != ItemDef.Type.MATERIAL or not defn.stackable:
			all_ok = false
	_check(all_ok, "db có đủ 8 trứng sinh vật (type MATERIAL, stackable)")

	# ── 2. Nhận diện item trứng ──
	var fake_egg: ItemDef = ItemDatabase.items_db["egg_carp"]
	var fake_food: ItemDef = ItemDatabase.items_db["carp"]
	_check(_EggThrow.is_egg_item(fake_egg), "trứng cá chép là egg item")
	_check(not _EggThrow.is_egg_item(fake_food), "cá (food) không phải egg item")
	_check(not _EggThrow.is_egg_item(null), "null không phải egg item")

	# ── 3. Icon mesh từng loại — không crash ──
	var icon_root := Node3D.new()
	add_child(icon_root)
	for eid in egg_ids:
		var holder := Node3D.new()
		icon_root.add_child(holder)
		ItemMesh.build(holder, eid)
		_check(holder.get_child_count() > 0, "icon %s có mesh" % eid)

	# ── 4. Projectile: visual + nhận diện màu theo loài ──
	_check(_EggProjectile.is_egg_item_id("egg_pig"), "egg_pig là egg id")
	_check(not _EggProjectile.is_egg_item_id("carp"), "carp không phải egg id")
	var proj := _EggProjectile.new()
	add_child(proj)
	_check(proj.get_child_count() > 0, "trứng ném có mesh")
	_check(_EggProjectile.egg_color("egg_carp") != _EggProjectile.egg_color("egg_pig"),
		"màu trứng khác nhau theo loài")

	# ── 5. Nở cá: mỗi loài → đúng FishVariant ──
	var variant_map := {
		"egg_carp": FishCharacter.FishVariant.CARP,
		"egg_perch": FishCharacter.FishVariant.PERCH,
		"egg_tilapia": FishCharacter.FishVariant.TILAPIA,
		"egg_snakehead": FishCharacter.FishVariant.SNAKEHEAD,
		"egg_flowerhorn": FishCharacter.FishVariant.FLOWERHORN,
		"egg_shrimp": FishCharacter.FishVariant.SHRIMP,
	}
	for eid in variant_map:
		var p := _EggProjectile.new()
		add_child(p)
		p.global_position = Vector3(0, 0, 0)
		p._egg_id = eid
		p._spawn_creature()
		var found := false
		for ch in get_children():
			if ch is FishCharacter and int(ch.fish_variant) == int(variant_map[eid]):
				found = true
				break
		_check(found, "%s nở đúng loài cá (variant %d)" % [eid, int(variant_map[eid])])
		p.queue_free()

	# ── 6. Nở heo con ──
	var pig_proj := _EggProjectile.new()
	add_child(pig_proj)
	pig_proj.global_position = Vector3(5, 0, 5)
	pig_proj._egg_id = "egg_pig"
	pig_proj._spawn_creature()
	var pig_ok := false
	for ch in get_children():
		if ch is PigCharacter and ch.is_baby and ch.pig_variant == PigCharacter.Variant.NORMAL:
			pig_ok = true
			break
	_check(pig_ok, "egg_pig nở heo con (baby, NORMAL)")
	pig_proj.queue_free()

	# ── 7. Vòng đời projectile: chạm đất → nở + tự hủy ──
	var p2 := _EggProjectile.new()
	add_child(p2)
	p2.global_position = Vector3(10, 0, 10)
	p2._egg_id = "egg_tilapia"
	var before := _count_type(_EggProjectile) + 0
	p2._on_impact()
	var hatched := false
	for ch in get_children():
		if ch is FishCharacter and ch.fish_variant == FishCharacter.FishVariant.TILAPIA:
			hatched = true
			break
	_check(hatched, "chạm đất: trứng nở cá điêu hồng")
	_check(not p2._hit_something == false, "trứng đã đánh dấu va chạm")
	await get_tree().create_timer(0.5).timeout
	_check(not is_instance_valid(p2), "trứng tự hủy sau khi nở")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
