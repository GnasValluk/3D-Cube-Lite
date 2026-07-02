extends Node

# ── Path mappings ──────────────────────────────────────────────────────────────
const S_HURT:         Array[String] = ["res://assets/sfx/random/classic_hurt.ogg"]
const S_DEATH:        Array[String] = ["res://assets/sfx/mob/villager/death.ogg"]
const S_DAMAGE_HIT:   Array[String] = ["res://assets/sfx/damage/hit1.ogg","res://assets/sfx/damage/hit2.ogg","res://assets/sfx/damage/hit3.ogg"]
const S_ATTACK_WEAK:  Array[String] = ["res://assets/sfx/entity/player/attack/weak1.ogg","res://assets/sfx/entity/player/attack/weak2.ogg","res://assets/sfx/entity/player/attack/weak3.ogg","res://assets/sfx/entity/player/attack/weak4.ogg"]
const S_ATTACK_STRONG:Array[String] = ["res://assets/sfx/entity/player/attack/strong1.ogg","res://assets/sfx/entity/player/attack/strong2.ogg","res://assets/sfx/entity/player/attack/strong3.ogg","res://assets/sfx/entity/player/attack/strong4.ogg","res://assets/sfx/entity/player/attack/strong5.ogg","res://assets/sfx/entity/player/attack/strong6.ogg"]
const S_SWEEP:        Array[String] = ["res://assets/sfx/entity/player/attack/sweep1.ogg","res://assets/sfx/entity/player/attack/sweep2.ogg","res://assets/sfx/entity/player/attack/sweep3.ogg","res://assets/sfx/entity/player/attack/sweep4.ogg","res://assets/sfx/entity/player/attack/sweep5.ogg","res://assets/sfx/entity/player/attack/sweep6.ogg","res://assets/sfx/entity/player/attack/sweep7.ogg"]
const S_FALL_SMALL:   Array[String] = ["res://assets/sfx/damage/fallsmall.ogg"]
const S_FALL_BIG:     Array[String] = ["res://assets/sfx/damage/fallbig.ogg"]
const S_LEVELUP:      Array[String] = ["res://assets/sfx/random/levelup.ogg"]
const S_ORB:          Array[String] = ["res://assets/sfx/random/orb.ogg"]
const S_CHEST_OPEN:   Array[String] = ["res://assets/sfx/random/chestopen.ogg"]
const S_CHEST_CLOSE:  Array[String] = ["res://assets/sfx/random/chestclosed.ogg"]
const S_CLICK:        Array[String] = ["res://assets/sfx/random/click.ogg"]
const S_EXPLODE:      Array[String] = ["res://assets/sfx/random/explode1.ogg","res://assets/sfx/random/explode2.ogg","res://assets/sfx/random/explode3.ogg","res://assets/sfx/random/explode4.ogg"]
const S_SPLASH:       Array[String] = ["res://assets/sfx/random/splash.ogg"]
const S_POP:          Array[String] = ["res://assets/sfx/random/pop.ogg"]
const S_BOW:          Array[String] = ["res://assets/sfx/random/bow.ogg"]
const S_BOWHIT:       Array[String] = ["res://assets/sfx/random/bowhit1.ogg","res://assets/sfx/random/bowhit2.ogg","res://assets/sfx/random/bowhit3.ogg","res://assets/sfx/random/bowhit4.ogg"]
const S_FIRE:         Array[String] = ["res://assets/sfx/fire/fire.ogg"]
const S_IGNITE:       Array[String] = ["res://assets/sfx/fire/ignite.ogg"]
const S_GLASS:        Array[String] = ["res://assets/sfx/random/glass1.ogg","res://assets/sfx/random/glass2.ogg","res://assets/sfx/random/glass3.ogg"]
const S_FIZZ:         Array[String] = ["res://assets/sfx/random/fizz.ogg"]
const S_BURP:         Array[String] = ["res://assets/sfx/random/burp.ogg"]
const S_DRINK:        Array[String] = ["res://assets/sfx/random/drink.ogg"]
const S_EAT:          Array[String] = ["res://assets/sfx/random/eat1.ogg","res://assets/sfx/random/eat2.ogg","res://assets/sfx/random/eat3.ogg"]
const S_DOOR_OPEN:    Array[String] = ["res://assets/sfx/random/door_open.ogg"]
const S_DOOR_CLOSE:   Array[String] = ["res://assets/sfx/random/door_close.ogg"]
const S_DIG_GRASS:    Array[String] = ["res://assets/sfx/dig/grass1.ogg","res://assets/sfx/dig/grass2.ogg","res://assets/sfx/dig/grass3.ogg","res://assets/sfx/dig/grass4.ogg"]
const S_DIG_GRAVEL:   Array[String] = ["res://assets/sfx/dig/gravel1.ogg","res://assets/sfx/dig/gravel2.ogg","res://assets/sfx/dig/gravel3.ogg","res://assets/sfx/dig/gravel4.ogg"]
const S_DIG_SAND:     Array[String] = ["res://assets/sfx/dig/sand1.ogg","res://assets/sfx/dig/sand2.ogg","res://assets/sfx/dig/sand3.ogg","res://assets/sfx/dig/sand4.ogg"]
const S_DIG_STONE:    Array[String] = ["res://assets/sfx/dig/stone1.ogg","res://assets/sfx/dig/stone2.ogg","res://assets/sfx/dig/stone3.ogg","res://assets/sfx/dig/stone4.ogg"]
const S_DIG_WOOD:     Array[String] = ["res://assets/sfx/dig/wood1.ogg","res://assets/sfx/dig/wood2.ogg","res://assets/sfx/dig/wood3.ogg","res://assets/sfx/dig/wood4.ogg"]
const S_STEP_GRASS:   Array[String] = ["res://assets/sfx/step/grass1.ogg","res://assets/sfx/step/grass2.ogg","res://assets/sfx/step/grass3.ogg","res://assets/sfx/step/grass4.ogg","res://assets/sfx/step/grass5.ogg","res://assets/sfx/step/grass6.ogg"]
const S_STEP_GRAVEL:  Array[String] = ["res://assets/sfx/step/gravel1.ogg","res://assets/sfx/step/gravel2.ogg","res://assets/sfx/step/gravel3.ogg","res://assets/sfx/step/gravel4.ogg"]
const S_STEP_SAND:    Array[String] = ["res://assets/sfx/step/sand1.ogg","res://assets/sfx/step/sand2.ogg","res://assets/sfx/step/sand3.ogg","res://assets/sfx/step/sand4.ogg","res://assets/sfx/step/sand5.ogg"]
const S_STEP_STONE:   Array[String] = ["res://assets/sfx/step/stone1.ogg","res://assets/sfx/step/stone2.ogg","res://assets/sfx/step/stone3.ogg","res://assets/sfx/step/stone4.ogg","res://assets/sfx/step/stone5.ogg","res://assets/sfx/step/stone6.ogg"]
const S_STEP_WOOD:    Array[String] = ["res://assets/sfx/step/wood1.ogg","res://assets/sfx/step/wood2.ogg","res://assets/sfx/step/wood3.ogg","res://assets/sfx/step/wood4.ogg","res://assets/sfx/step/wood5.ogg","res://assets/sfx/step/wood6.ogg"]
const S_STEP_SNOW:    Array[String] = ["res://assets/sfx/step/snow1.ogg","res://assets/sfx/step/snow2.ogg","res://assets/sfx/step/snow3.ogg","res://assets/sfx/step/snow4.ogg"]
const S_SWIM:         Array[String] = ["res://assets/sfx/entity/fish/swim1.ogg","res://assets/sfx/entity/fish/swim2.ogg","res://assets/sfx/entity/fish/swim3.ogg","res://assets/sfx/entity/fish/swim4.ogg","res://assets/sfx/entity/fish/swim5.ogg","res://assets/sfx/entity/fish/swim6.ogg","res://assets/sfx/entity/fish/swim7.ogg"]
const S_PADDLE_LAND:  Array[String] = ["res://assets/sfx/entity/bobber/paddle_land1.ogg","res://assets/sfx/entity/bobber/paddle_land2.ogg","res://assets/sfx/entity/bobber/paddle_land3.ogg","res://assets/sfx/entity/bobber/paddle_land4.ogg","res://assets/sfx/entity/bobber/paddle_land5.ogg","res://assets/sfx/entity/bobber/paddle_land6.ogg"]
const S_FLOP:         Array[String] = ["res://assets/sfx/entity/fish/flop1.ogg","res://assets/sfx/entity/fish/flop2.ogg","res://assets/sfx/entity/fish/flop3.ogg","res://assets/sfx/entity/fish/flop4.ogg"]
const S_BLOCK_BREAK:  Array[String] = ["res://assets/sfx/block/break1.ogg","res://assets/sfx/block/break2.ogg","res://assets/sfx/block/break3.ogg","res://assets/sfx/block/break4.ogg"]
const S_BLOCK_PLACE:  Array[String] = ["res://assets/sfx/block/place1.ogg","res://assets/sfx/block/place2.ogg","res://assets/sfx/block/place3.ogg","res://assets/sfx/block/place4.ogg"]
const S_DROWN:        Array[String] = ["res://assets/sfx/entity/player/hurt/drown1.ogg","res://assets/sfx/entity/player/hurt/drown2.ogg","res://assets/sfx/entity/player/hurt/drown3.ogg","res://assets/sfx/entity/player/hurt/drown4.ogg"]
const S_FIRE_HURT:    Array[String] = ["res://assets/sfx/entity/player/hurt/fire_hurt1.ogg","res://assets/sfx/entity/player/hurt/fire_hurt2.ogg","res://assets/sfx/entity/player/hurt/fire_hurt3.ogg"]
const S_BREATH:       Array[String] = ["res://assets/sfx/random/breath.ogg"]
const S_PLANT_CROP:   Array[String] = ["res://assets/sfx/item/crop1.ogg","res://assets/sfx/item/crop2.ogg","res://assets/sfx/item/crop3.ogg","res://assets/sfx/item/crop4.ogg","res://assets/sfx/item/crop5.ogg","res://assets/sfx/item/crop6.ogg"]

var _cache: Dictionary = {}
var _players_2d: Array[AudioStreamPlayer] = []
var _player_idx_2d: int = 0
var _muted: bool = false

func _ready() -> void:
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players_2d.append(p)

func play_arr(arr: Array[String], volume: float = 0.0, pitch: float = 1.0) -> void:
	if _muted or arr.is_empty():
		return
	var path: String = arr[randi() % arr.size()]
	var stream: AudioStream = _load(path)
	if stream == null:
		return
	var p := _next_player()
	p.stream = stream
	p.volume_db = volume
	p.pitch_scale = pitch
	p.play()

func play_arr_var(arr: Array[String], volume: float = 0.0, pitch_var: float = 0.15) -> void:
	var pitch: float = 1.0 + randf_range(-pitch_var, pitch_var)
	play_arr(arr, volume, pitch)

func play_hurt() -> void:          play_arr_var(S_HURT)
func play_death() -> void:         play_arr_var(S_DEATH)
func play_damage_hit() -> void:    play_arr_var(S_DAMAGE_HIT)
func play_attack_weak() -> void:   play_arr_var(S_ATTACK_WEAK)
func play_attack_strong() -> void: play_arr_var(S_ATTACK_STRONG)
func play_sweep() -> void:         play_arr_var(S_SWEEP)
func play_fall_small() -> void:    play_arr_var(S_FALL_SMALL)
func play_fall_big() -> void:      play_arr_var(S_FALL_BIG)
func play_levelup() -> void:       play_arr_var(S_LEVELUP)
func play_orb() -> void:           play_arr_var(S_ORB)
func play_chest_open() -> void:    play_arr_var(S_CHEST_OPEN, -3.0)
func play_chest_close() -> void:   play_arr_var(S_CHEST_CLOSE, -3.0)
func play_click() -> void:         play_arr_var(S_CLICK, -6.0)
func play_explode() -> void:       play_arr_var(S_EXPLODE, -3.0)
func play_splash() -> void:        play_arr_var(S_SPLASH)
func play_pop() -> void:           play_arr_var(S_POP)
func play_fire() -> void:          play_arr_var(S_FIRE, -6.0)
func play_ignite() -> void:        play_arr_var(S_IGNITE, -6.0)
func play_glass_break() -> void:   play_arr_var(S_GLASS)
func play_fizz() -> void:          play_arr_var(S_FIZZ)
func play_drink() -> void:         play_arr_var(S_DRINK)
func play_eat() -> void:           play_arr_var(S_EAT)
func play_door_open() -> void:     play_arr_var(S_DOOR_OPEN, -3.0)
func play_door_close() -> void:    play_arr_var(S_DOOR_CLOSE, -3.0)
func play_drown() -> void:         play_arr_var(S_DROWN)
func play_fire_hurt() -> void:     play_arr_var(S_FIRE_HURT)
func play_swim() -> void:          play_arr_var(S_SWIM, -6.0)
func play_block_break() -> void:   play_arr_var(S_BLOCK_BREAK)
func play_block_place() -> void:   play_arr_var(S_BLOCK_PLACE)
func play_step_grass() -> void:    play_arr_var(S_STEP_GRASS, -8.0)
func play_step_gravel() -> void:   play_arr_var(S_STEP_GRAVEL, -6.0)
func play_step_sand() -> void:     play_arr_var(S_STEP_SAND, -6.0)
func play_step_stone() -> void:    play_arr_var(S_STEP_STONE, -6.0)
func play_step_wood() -> void:     play_arr_var(S_STEP_WOOD, -6.0)
func play_step_snow() -> void:     play_arr_var(S_STEP_SNOW, -6.0)
func play_breath() -> void:        play_arr_var(S_BREATH)
func play_plant_crop() -> void:    play_arr_var(S_PLANT_CROP)

func set_muted(val: bool) -> void:
	_muted = val

func is_muted() -> bool:
	return _muted

func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream := load(path) as AudioStream
	if stream:
		_cache[path] = stream
	return stream

func _next_player() -> AudioStreamPlayer:
	var p := _players_2d[_player_idx_2d]
	_player_idx_2d = (_player_idx_2d + 1) % _players_2d.size()
	return p
