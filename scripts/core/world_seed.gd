extends Node

const SAVE_PATH: String = "user://saves.json"
const _WorldChunk := preload("res://scripts/world/chunk/world_chunk.gd")

var seed_value: int = 42:
	set(v):
		seed_value = v
		SeedSnapshot.set_seed(v)
var target_scene: String = "res://scenes/open_world_real.tscn"
var world_name: String = ""
var is_loading: bool = false

## Vị trí player đứng trước khi save — spawn thẳng tại đây khi load lại
## hành trình (WorldManager + CharacterManager đọc để generate chunk + đặt
## player đúng chỗ, tránh teleport sau khi load gây lag).
var saved_player_pos: Vector3 = Vector3.INF
var has_saved_player_pos: bool = false

func _ready() -> void:
	randomize()
	seed_value = randi() % 2147483647
	SeedSnapshot.set_seed(seed_value)
	target_scene = "res://scenes/open_world_real.tscn"

func start_new_journey(name: String, seed_val: int) -> void:
	seed_value = seed_val
	SeedSnapshot.set_seed(seed_val)
	world_name = name
	target_scene = "res://scenes/open_world_real.tscn"
	is_loading = false
	saved_player_pos = Vector3.INF
	has_saved_player_pos = false
	if SaveManager:
		SaveManager.reset_load_state()
	save_journey()
	_WorldChunk.prewarm_async()

func save_journey() -> void:
	var saves: Dictionary = _load_saves()
	saves.saves.append({
		"name": world_name,
		"seed": seed_value,
		"timestamp": Time.get_unix_time_from_system()
	})
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.new().stringify(saves, "  "))
		f.close()

func load_journey(idx: int) -> bool:
	var saves: Dictionary = _load_saves()
	if idx < 0 or idx >= saves.saves.size():
		return false
	var s: Dictionary = saves.saves[idx]
	world_name = s.get("name", "World")
	seed_value = s.get("seed", randi() % 2147483647)
	SeedSnapshot.set_seed(seed_value)
	target_scene = "res://scenes/open_world_real.tscn"
	is_loading = SaveManager and SaveManager.save_exists(world_name)
	saved_player_pos = Vector3.INF
	has_saved_player_pos = false
	if is_loading and SaveManager:
		saved_player_pos = SaveManager.get_saved_player_position(world_name)
		has_saved_player_pos = saved_player_pos != Vector3.INF
	if SaveManager:
		SaveManager.reset_load_state()
	_WorldChunk.prewarm_async()
	return true

func get_saves() -> Array:
	return _load_saves().get("saves", [])

func delete_save(idx: int) -> void:
	var saves: Dictionary = _load_saves()
	if idx >= 0 and idx < saves.saves.size():
		var save_name: String = saves.saves[idx].get("name", "")
		saves.saves.remove_at(idx)
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.new().stringify(saves, "  "))
			f.close()
		if not save_name.is_empty() and SaveManager:
			var dir := SaveManager.get_world_dir(save_name)
			if DirAccess.dir_exists_absolute(dir):
				DirAccess.remove_absolute(dir)

func _load_saves() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"saves": []}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var text: String = f.get_as_text()
		f.close()
		var json := JSON.new()
		var err := json.parse(text)
		if err == OK and json.data is Dictionary:
			return json.data
	return {"saves": []}
