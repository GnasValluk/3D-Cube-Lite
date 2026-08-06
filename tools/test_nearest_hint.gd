extends Node3D

## test_nearest_hint — Helper UI "sinh vật gần nhất": panel hiện tên + khoảng
## cách của mob hoặc plant gần player, ẩn khi không có gì trong bán kính.
## Chạy qua tools/test_nearest_hint.tscn.

const _Hint = preload("res://scripts/ui/hud/nearest_creature_hint.gd")
const _Oak = preload("res://scripts/world/props/oak_prop.gd")

var _failures: int = 0
var _hint: CanvasLayer = null
var _player: Node = null
var _mob: Node = null
var _oak: Node = null

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _load_translations() -> void:
	var path := "res://translations/game.csv"
	if not FileAccess.file_exists(path):
		return
	for locale in ["vi", "en"]:
		var col: int = 1 if locale == "en" else 2
		var t := Translation.new()
		t.locale = locale
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var header: bool = true
			while not f.eof_reached():
				var line = f.get_csv_line()
				if line.is_empty() or line[0].is_empty():
					continue
				if header:
					header = false
					continue
				if line.size() > col:
					t.add_message(line[0], line[col])
			f.close()
		TranslationServer.add_translation(t)

func _make_mob_stub(name: String) -> Node:
	var s := GDScript.new()
	s.source_code = "extends CharacterBase\n" \
		+ "func _ready() -> void:\n" \
		+ "\tcharacter_name = \"%s\"\n\thp = 45\n\tmax_hp = 100\n" % name \
		+ "func _process(_d): pass\nfunc _physics_process(_d): pass\n"
	s.reload()
	var mob := CharacterBody3D.new()
	mob.set_script(s)
	return mob

func _ready() -> void:
	_load_translations()
	print("== test_nearest_hint: Sinh vật gần nhất ==")

	# ── 1. Setup world: player + mob + cây sồi ─────────────────────────────
	print("-- 1. Setup --")
	var player := _make_mob_stub("Player")
	player.name = "PlayerStub"
	add_child(player)
	player.global_position = Vector3(0, 1, 0)
	_player = player

	_mob = _make_mob_stub("Heo Rừng")
	_mob.name = "MobStub"
	add_child(_mob)
	_mob.global_position = Vector3(2, 0, 0)

	_oak = _Oak.new()
	_oak.name = "OakNear"
	add_child(_oak)
	_oak.global_position = Vector3(5, 0, 0)
	await get_tree().physics_frame
	_check(_oak.is_in_group("destroyable_props"), "cây sồi vào group destroyable_props")
	_check(_mob is CharacterBase, "mob stub là CharacterBase (script=%s)" % str(_mob.get_script()))
	_check(_player is CharacterBase, "player stub là CharacterBase")

	_hint = _Hint.new()
	_hint.name = "NearestHint"
	add_child(_hint)
	_hint.player_getter = Callable(self, "_get_player")

	# ── 2. Mob gần nhất ────────────────────────────────────────────────────
	print("-- 2. Mob gần nhất --")
	_mob.global_position = Vector3(2, 0, 0)
	_oak.global_position = Vector3(8, 0, 0)
	_hint._update_hint()
	_check(_hint._panel.visible, "panel hiển thị khi có sinh vật gần")
	_check(tr("CREATURE_TYPE_MOB") in _hint._name_lbl.text, "nhãn loại MOB (text=%s)" % _hint._name_lbl.text)
	_check(_hint._name_lbl.text.contains("Heo Rừng"), "tên mob đúng (text=%s)" % _hint._name_lbl.text)

	# ── 3. Plant gần nhất ──────────────────────────────────────────────────
	print("-- 3. Cây gần nhất --")
	_mob.global_position = Vector3(11, 0, 0)
	_oak.global_position = Vector3(3, 0, 0)
	_hint._update_hint()
	_check(_hint._panel.visible, "panel vẫn hiển thị (cây trong tầm)")
	_check(tr("CREATURE_TYPE_PLANT") in _hint._name_lbl.text, "nhãn loại PLANT (text=%s)" % _hint._name_lbl.text)
	_check(tr("PLANT_OAK") in _hint._name_lbl.text, "tên cây sồi (text=%s)" % _hint._name_lbl.text)

	# ── 4. Ngoài bán kính → ẩn ─────────────────────────────────────────────
	print("-- 4. Ngoài bán kính --")
	_mob.global_position = Vector3(50, 0, 0)
	_oak.global_position = Vector3(50, 0, 50)
	_hint._update_hint()
	_check(not _hint._panel.visible, "panel ẩn khi không có sinh vật trong 12m")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _get_player() -> Node:
	return _player if is_instance_valid(_player) else null