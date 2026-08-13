## egg_projectile.gd — Trứng sinh vật ném parabol (như pháo bí ngô).
## Chạm đất/nước → vỡ vỏ → nở sinh vật tương ứng (cá theo loài / heo con).

class_name EggProjectile
extends Node3D

const EGG_IDS: Array[String] = [
	"egg_carp", "egg_perch", "egg_tilapia", "egg_snakehead",
	"egg_flowerhorn", "egg_shrimp", "egg_pig",
]

const EGG_COLORS: Dictionary = {
	"egg_carp":       Color(0.95, 0.70, 0.10),
	"egg_perch":      Color(0.30, 0.30, 0.30),
	"egg_tilapia":    Color(0.88, 0.55, 0.45),
	"egg_snakehead":  Color(0.30, 0.25, 0.15),
	"egg_flowerhorn": Color(0.92, 0.25, 0.15),
	"egg_shrimp":     Color(0.85, 0.35, 0.20),
	"egg_pig":        Color(0.87, 0.72, 0.63),
}

# egg id → FishVariant (heo không phải cá — spawn riêng)
const EGG_FISH_VARIANT: Dictionary = {
	"egg_carp": 0, "egg_perch": 1, "egg_tilapia": 2,
	"egg_snakehead": 3, "egg_flowerhorn": 4, "egg_shrimp": 5,
}

static func is_egg_item_id(id: String) -> bool:
	return id in EGG_IDS

static func egg_color(id: String) -> Color:
	return EGG_COLORS.get(id, Color(1.0, 1.0, 1.0))

const _FishChar = preload("res://scripts/characters/fish/fish_character.gd")
const _PigChar = preload("res://scripts/characters/pig/pig_character.gd")

var _egg_id: String = "egg_carp"
var _direction: Vector3
var _speed: float = 12.0
var _vertical_speed: float = 8.0
var _hit_something: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _mesh_root: Node3D
var _spin_speed: float = 6.0
var _spawn_dist: float = 0.0

func setup(dir: Vector3, spd: float, vert_spd: float, egg_id: String) -> void:
	_direction = dir
	_speed = spd
	_vertical_speed = vert_spd
	_egg_id = egg_id

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	var main := StandardMaterial3D.new()
	main.albedo_color = egg_color(_egg_id)
	main.roughness = 0.75
	main.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var spot := StandardMaterial3D.new()
	spot.albedo_color = (egg_color(_egg_id) as Color).lerp(Color(1.0, 1.0, 1.0), 0.55)
	spot.roughness = 0.7
	spot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var body := MeshInstance3D.new()
	var egg_mesh := SphereMesh.new()
	egg_mesh.radius = 0.16
	egg_mesh.height = 0.24
	egg_mesh.radial_segments = 10
	egg_mesh.rings = 6
	body.mesh = egg_mesh
	body.material_override = main
	body.scale = Vector3(0.72, 1.0, 0.72)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_root.add_child(body)

	# Đốm sáng nhỏ trên vỏ trứng
	var speck := MeshInstance3D.new()
	speck.mesh = egg_mesh
	speck.material_override = spot
	speck.scale = Vector3(0.3, 0.42, 0.3)
	speck.position = Vector3(0.05, 0.07, 0.05)
	speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_root.add_child(speck)

func _physics_process(delta: float) -> void:
	if _hit_something:
		return

	var h_step := _direction * _speed * delta
	_vertical_speed -= _gravity * delta
	var v_step := Vector3(0, _vertical_speed * delta, 0)
	var next_pos := global_position + h_step + v_step

	_mesh_root.rotation.x += delta * _spin_speed
	_mesh_root.rotation.z += delta * _spin_speed * 0.5

	if _spawn_dist > 1.5:
		var space := get_world_3d().direct_space_state
		if space:
			var query := PhysicsRayQueryParameters3D.new()
			query.from = global_position
			query.to = next_pos
			query.collision_mask = 1
			var result := space.intersect_ray(query)
			if not result.is_empty():
				global_position = result.position
				_on_impact()
				return

	global_position = next_pos
	_spawn_dist += h_step.length() + abs(v_step.y)

	if global_position.y < -5.0:
		_on_impact()

func _on_impact() -> void:
	if _hit_something:
		return
	_hit_something = true

	_spawn_creature()
	_spawn_crack_vfx()

	set_physics_process(false)
	get_tree().create_timer(0.3).timeout.connect(queue_free)

## Nở sinh vật tương ứng trứng — cùng pattern với fish/pig spawner
func _spawn_creature() -> void:
	var world: Node = get_tree().current_scene
	if world == null:
		return
	var pos: Vector3 = global_position

	if _egg_id == "egg_pig":
		var pig := CharacterBody3D.new() as CharacterBody3D
		pig.set_script(_PigChar)
		pig.set("pig_variant", PigCharacter.Variant.NORMAL)
		pig.set("is_baby", true)
		pig.set("pig_scale", randf_range(0.45, 0.55))
		pig.name = "Pig_Hatch_%d" % get_instance_id()
		pig.set("_is_player", false)
		world.add_child(pig)
		pig.global_position = pos
		pig.rotation.y = randf_range(0.0, TAU)
		pig.set("_home", pos)
	else:
		var fish := CharacterBody3D.new() as CharacterBody3D
		fish.set_script(_FishChar)
		fish.set("fish_variant", int(EGG_FISH_VARIANT.get(_egg_id, 0)))
		fish.set("fish_scale", randf_range(0.35, 0.55))
		fish.name = "Fish_Hatch_%d" % get_instance_id()
		fish.set("_is_player", false)
		world.add_child(fish)
		fish.global_position = pos
		fish.rotation.y = randf_range(0.0, TAU)

## Vỡ vỏ: vụn trắng bay + chớp nhỏ
func _spawn_crack_vfx() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var flash := OmniLight3D.new()
	flash.light_color = Color(0.95, 0.95, 0.85)
	flash.light_energy = 8.0
	flash.omni_range = 4.0
	flash.light_specular = 0.0
	parent.add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.1).timeout.connect(
		func(): if is_instance_valid(flash): flash.queue_free())

	for i in range(10):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.93, 0.85, 0.9)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.03
		sph.height = 0.06
		mi.mesh = sph
		mi.material_override = mat
		mi.position = Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.1), randf_range(-0.1, 0.1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", mi.position + Vector3(
			randf_range(-0.4, 0.4), randf_range(0.2, 0.8), randf_range(-0.4, 0.4)), 0.4)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
		tw.tween_callback(mi.queue_free).set_delay(0.45)
