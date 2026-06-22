## ai/bot_spawner.gd
## Spawn bot characters vào world, đặt dưới CharacterManager.

extends Node3D
class_name BotSpawner

@export var bot_count: int = 5
@export var spawn_radius: float = 30.0

var _bot_types: Array[Script] = []

func _ready() -> void:
	_bot_types = [
		load("res://scripts/characters/raptor/raptor_character.gd"),
		load("res://scripts/characters/dragon/dragon_character.gd"),
		load("res://scripts/characters/warrior/warrior_character.gd"),
	]
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_spawn_bots()

func _spawn_bots() -> void:
	var mgr := _find_manager()
	if mgr == null:
		push_error("BotSpawner: không tìm thấy CharacterManager")
		return
	for i in range(bot_count):
		var idx: int = i % _bot_types.size()
		var bot := CharacterBody3D.new()
		bot.set_script(_bot_types[idx])
		bot._is_player = false
		bot.name = "Bot_%d" % i

		var a := randf_range(0, TAU)
		var r := randf_range(8.0, spawn_radius)
		mgr.add_child(bot)
		bot.global_position = Vector3(cos(a) * r, 2.0, sin(a) * r)

		await get_tree().process_frame
		_add_bot_ai(bot)

func _add_bot_ai(body: CharacterBody3D) -> void:
	if body.has_node("BotAI"):
		return
	var ai: Node = load("res://scripts/ai/bot_character.gd").new()
	body.add_child(ai)
	ai.name = "BotAI"

func _find_manager() -> Node:
	var p := get_parent()
	if p != null:
		return p.get_node_or_null("CharacterManager")
	return null
