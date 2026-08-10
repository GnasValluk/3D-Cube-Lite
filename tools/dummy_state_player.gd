extends CharacterBody3D

## Dummy player cho test state sync — có đủ hp/max_hp/food/max_food/shield/
## level/is_alive/inventory như PlayerCharacter thật, để Net._broadcast_player_state
## đọc được qua Object.get().

var hp: int = 100
var max_hp: int = 100
var food: int = 20
var max_food: int = 20
var shield: int = 0
var level: int = 1
var is_alive: bool = true
var inventory: Inventory = null
