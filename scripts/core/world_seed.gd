extends Node

const SAVE_PATH: String = "user://saves.json"

var seed_value: int = 42
var target_scene: String = "res://scenes/open_world_real.tscn"
var world_name: String = ""
var is_loading: bool = false

func _ready() -> void:
	randomize()
	seed_value = randi() % 2147483647
	target_scene = "res://scenes/open_world_real.tscn"

func start_new_journey(name: String, seed_val: int) -> void:
	seed_value = seed_val
	world_name = name
	target_scene = "res://scenes/open_world_real.tscn"
	is_loading = false
	if SaveManager:
		SaveManager.reset_load_state()
	save_journey()

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
	target_scene = "res://scenes/open_world_real.tscn"
	is_loading = SaveManager and SaveManager.save_exists(world_name)
	if SaveManager:
		SaveManager.reset_load_state()
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
