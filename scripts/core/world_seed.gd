extends Node

var seed_value: int = 42

func _ready() -> void:
	randomize()
	seed_value = randi() % 2147483647
