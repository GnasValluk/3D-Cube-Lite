extends Node

const SAVE_VERSION = 1
const AUTO_SAVE_INTERVAL = 30.0

var _auto_save_timer: float = 0.0
var _pending_blocks: Dictionary = {}
var _load_applied: bool = false

func _ready():
	DirAccess.make_dir_recursive_absolute("user://saves/")

func _process(delta):
	if _is_in_game_world():
		if not _load_applied and WorldSeed.is_loading:
			_load_and_apply()
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			_auto_save_timer = 0.0
			save_game()

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _is_in_game_world():
			save_game()

func _is_in_game_world() -> bool:
	var scene = get_tree().current_scene
	if scene == null: return false
	var name = scene.name
	return name == "OpenWorld" or name == "OpenWorldThucTe"

func get_world_dir(world_name: String = "") -> String:
	if world_name.is_empty(): world_name = WorldSeed.world_name
	return "user://saves/" + _sanitize(world_name) + "/"

func _sanitize(name: String) -> String:
	var safe = ""
	for c in name:
		if c.is_valid_unicode_identifier() or c == "." or c == "-":
			safe += c
		elif c == " ":
			safe += "_"
	return safe

func save_exists(world_name: String = "") -> bool:
	if world_name.is_empty(): world_name = WorldSeed.world_name
	if world_name.is_empty(): return false
	return FileAccess.file_exists(get_world_dir(world_name) + "save.json")

func save_game() -> bool:
	var data = _collect_save_data()
	if data.is_empty(): return false
	data["version"] = SAVE_VERSION
	data["world_name"] = WorldSeed.world_name
	data["seed"] = WorldSeed.seed_value
	data["timestamp"] = Time.get_unix_time_from_system()
	var dir = get_world_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f = FileAccess.open(dir + "save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.new().stringify(data, "\t"))
		return true
	return false

func _collect_save_data() -> Dictionary:
	var data = {}
	var scene = get_tree().current_scene
	if scene == null: return data
	var cm = scene.get_node_or_null("CharacterManager") as CharacterManager
	if cm:
		data["player"] = _collect_player_data(cm)
		data["party"] = _collect_party_data(cm)
	var wm = scene.get_node_or_null("WorldManager") as OpenWorldManager
	if wm:
		data["dimension"] = wm.dimension_id
		data["blocks"] = _collect_block_data(wm)
	data["time"] = _collect_time_data()
	var es = scene.get_node_or_null("ExploreSystem") as ExploreSystem
	if es:
		data["explored"] = es.serialize()
	var ps = scene.get_node_or_null("PlacementSystem") as PlacementSystem
	if ps:
		data["buildings"] = ps.serialize()
	return data

func _collect_player_data(cm: CharacterManager) -> Dictionary:
	var ch = cm.get_current_character()
	if ch == null: return {}
	var pd = {
		"name": ch.character_name,
		"hp": ch.hp, "max_hp": ch.max_hp,
		"mana": ch.mana, "max_mana": ch.max_mana,
		"oxygen": ch.oxygen, "max_oxygen": ch.max_oxygen,
		"level": ch.level, "exp": ch.exp,
		"shield": ch.shield,
		"character_name": ch.character_name,
		"element": ch.element
	}
	if ch is PlayerCharacter:
		var pc = ch as PlayerCharacter
		pd["position"] = [pc.global_position.x, pc.global_position.y, pc.global_position.z]
		pd["rotation"] = [pc.rotation.x, pc.rotation.y, pc.rotation.z]
		pd["inventory"] = pc.inventory.to_dict() if pc.inventory else []
		pd["equipped_weapon"] = pc.equipped_weapon.id if pc.equipped_weapon else ""
		pd["equipped_head"] = pc.equipped_head.id if pc.equipped_head else ""
		pd["equipped_body"] = pc.equipped_body.id if pc.equipped_body else ""
		pd["equipped_legs"] = pc.equipped_legs.id if pc.equipped_legs else ""
		pd["equipped_feet"] = pc.equipped_feet.id if pc.equipped_feet else ""
	return pd

func _collect_party_data(cm: CharacterManager) -> Array:
	var result = []
	var party = cm.get_party_characters()
	for ch in party:
		result.append({
			"name": ch.character_name,
			"hp": ch.hp, "max_hp": ch.max_hp,
			"mana": ch.mana, "max_mana": ch.max_mana,
			"level": ch.level, "exp": ch.exp,
			"element": ch.element
		})
	return result

func _collect_block_data(wm: OpenWorldManager) -> Dictionary:
	var dim_id = wm.dimension_id
	var result = {}
	for key in wm._chunks:
		var chunk = wm._chunks[key] as WorldChunk
		if chunk.block_data and chunk.block_data.dirty:
			var ck = "%d,%d" % [chunk._cx, chunk._cz]
			result[ck] = Marshalls.raw_to_base64(chunk.block_data.to_bytes())
	return result

func _collect_time_data() -> Dictionary:
	if not TimeSystem: return {}
	return {
		"cycle_time": TimeSystem._cycle_time,
		"time_scale": TimeSystem._time_scale,
		"weather": TimeSystem._weather,
		"weather_timer": TimeSystem._weather_timer,
		"weather_intensity": TimeSystem._weather_intensity
	}

func load_and_apply_after_chunks() -> void:
	var dir = get_world_dir()
	if not FileAccess.file_exists(dir + "save.json"): return
	var f = FileAccess.open(dir + "save.json", FileAccess.READ)
	if not f: return
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK: return
	_apply_save_data(json.data)

func _load_and_apply() -> void:
	if _load_applied: return
	var scene = get_tree().current_scene
	if scene == null: return
	var wm = scene.get_node_or_null("WorldManager") as OpenWorldManager
	if wm == null or not wm._initial_generated: return
	_load_applied = true
	load_and_apply_after_chunks()

func reset_load_state() -> void:
	_load_applied = false
	_pending_blocks = {}

func _apply_save_data(data: Dictionary) -> void:
	var scene = get_tree().current_scene
	if scene == null: return
	var cm = scene.get_node_or_null("CharacterManager") as CharacterManager
	if cm and data.has("player"):
		_apply_player_data(cm, data["player"])
	if cm and data.has("party"):
		_apply_party_data(cm, data["party"])
	if data.has("time"):
		_apply_time_data(data["time"])
	var es = scene.get_node_or_null("ExploreSystem") as ExploreSystem
	if es and data.has("explored"):
		es.deserialize(data["explored"])
	var ps = scene.get_node_or_null("PlacementSystem") as PlacementSystem
	if ps and data.has("buildings"):
		ps.deserialize(data["buildings"])
	if data.has("blocks"):
		_pending_blocks = data["blocks"]
		if data.has("dimension"):
			_pending_blocks["_dim"] = data["dimension"]
	# Apply block mods to all already-loaded chunks
	var wm = scene.get_node_or_null("WorldManager") as OpenWorldManager
	if wm and not _pending_blocks.is_empty():
		for key in wm._chunks:
			var chunk = wm._chunks[key] as WorldChunk
			if chunk:
				apply_block_modifications_for_chunk(chunk, chunk._cx, chunk._cz)

func _apply_player_data(cm: CharacterManager, pd: Dictionary) -> void:
	var ch = cm.get_current_character()
	if ch == null: return
	ch.hp = pd.get("hp", ch.max_hp)
	ch.max_hp = pd.get("max_hp", ch.max_hp)
	ch.mana = pd.get("mana", ch.max_mana)
	ch.max_mana = pd.get("max_mana", ch.max_mana)
	ch.oxygen = pd.get("oxygen", ch.max_oxygen)
	ch.max_oxygen = pd.get("max_oxygen", ch.max_oxygen)
	ch.level = pd.get("level", 1)
	ch.exp = pd.get("exp", 0)
	ch.shield = pd.get("shield", 0)
	if ch is PlayerCharacter:
		var pc = ch as PlayerCharacter
		var pos = pd.get("position", [])
		if pos.size() == 3:
			pc.global_position = Vector3(pos[0], pos[1], pos[2])
		var rot = pd.get("rotation", [])
		if rot.size() == 3:
			pc.rotation = Vector3(rot[0], rot[1], rot[2])
		if pc.inventory and pd.has("inventory"):
			pc.inventory.from_dict(pd["inventory"])
		var db = Inventory.create_item_db()
		var wid = pd.get("equipped_weapon", "")
		pc.equipped_weapon = db.get(wid, null)
		var hid = pd.get("equipped_head", "")
		pc.equipped_head = db.get(hid, null)
		var bid = pd.get("equipped_body", "")
		pc.equipped_body = db.get(bid, null)
		var lid = pd.get("equipped_legs", "")
		pc.equipped_legs = db.get(lid, null)
		var fid = pd.get("equipped_feet", "")
		pc.equipped_feet = db.get(fid, null)
		if pc.equipped_weapon:
			pc.call_deferred("_update_weapon_mesh")
	var scene = get_tree().current_scene
	if scene != null:
		var wm = scene.get_node_or_null("WorldManager") as OpenWorldManager
		if wm:
			wm._last_pos = Vector3(99999, 99999, 99999)

func _apply_party_data(cm: CharacterManager, party_data: Array) -> void:
	var party = cm.get_party_characters()
	for pd in party_data:
		var name = pd.get("name", "")
		for ch in party:
			if ch.character_name == name:
				ch.hp = pd.get("hp", ch.max_hp)
				ch.max_hp = pd.get("max_hp", ch.max_hp)
				ch.mana = pd.get("mana", ch.max_mana)
				ch.max_mana = pd.get("max_mana", ch.max_mana)
				ch.level = pd.get("level", 1)
				ch.exp = pd.get("exp", 0)
				break

func _apply_time_data(td: Dictionary) -> void:
	if not TimeSystem: return
	if td.has("cycle_time"):
		TimeSystem._cycle_time = td["cycle_time"]
	if td.has("time_scale"):
		TimeSystem._time_scale = td["time_scale"]
	if td.has("weather"):
		TimeSystem._weather = td["weather"]
	if td.has("weather_timer"):
		TimeSystem._weather_timer = td["weather_timer"]
	if td.has("weather_intensity"):
		TimeSystem._weather_intensity = td["weather_intensity"]

func apply_block_modifications_for_chunk(chunk: WorldChunk, cx: int, cz: int) -> void:
	if _pending_blocks.is_empty(): return
	var dim = _pending_blocks.get("_dim", -1)
	if dim != -1 and dim != chunk._dimension_id: return
	var ck = "%d,%d" % [cx, cz]
	if not _pending_blocks.has(ck): return
	var b64 = _pending_blocks[ck]
	if b64 is String:
		var bytes = Marshalls.base64_to_raw(b64)
		if bytes and chunk.block_data:
			chunk.block_data.from_bytes(bytes, chunk._cols, chunk._cols)
			chunk.rebuild_mesh()
