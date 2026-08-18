extends MeshInstance3D
class_name VolumetricClouds

## Đám mây thể tích thật — một box trời quanh player, raymarch 3D noise
## (xem clouds_volumetric.gdshader). Noi noise được sinh hoàn toàn bằng code
## (NoiseTexture3D + FastNoiseLite) nên không cần asset. Mây trôi bay theo
## gió (TIME), sáng/tối theo mặt trời & trăng, đẩy từ môi trường mỗi frame.

const SHADER := preload("res://scripts/world/environment/clouds_volumetric.gdshader")

const CLOUD_MIN_Y := 55.0
const CLOUD_MAX_Y := 115.0
const BOX_HALF := 1500.0

var _mat: ShaderMaterial

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(BOX_HALF * 2.0, CLOUD_MAX_Y - CLOUD_MIN_Y, BOX_HALF * 2.0)
	mesh = box

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("cloud_noise_texture", _build_noise3d(0.018, 5, 128, 64, 128, 3117))
	_mat.set_shader_parameter("detail_noise_texture", _build_noise3d(0.11, 3, 128, 64, 128, 9182))
	_mat.set_shader_parameter("cloud_min_y", CLOUD_MIN_Y)
	_mat.set_shader_parameter("cloud_max_y", CLOUD_MAX_Y)
	material_override = _mat

	position = Vector3(0.0, (CLOUD_MIN_Y + CLOUD_MAX_Y) * 0.5, 0.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _build_noise3d(freq: float, octaves: int, w: int, h: int, d: int, seed: int) -> NoiseTexture3D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_gain = 0.55
	n.seed = seed
	var tex := NoiseTexture3D.new()
	tex.noise = n
	tex.width = w
	tex.height = h
	tex.depth = d
	tex.seamless = true
	return tex

## Cập nhật ánh sáng + màu mây theo giờ/trời (gọi mỗi frame từ môi trường).
func update_clouds(light_dir: Vector3, color: Color, brightness: float, threshold: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("light_direction", light_dir)
	_mat.set_shader_parameter("cloud_color", color)
	_mat.set_shader_parameter("cloud_brightness", brightness)
	_mat.set_shader_parameter("cloud_threshold", threshold)

## Giữ lớp trời luôn quanh player (theo x/z) để mây phủ khắp tầm nhìn.
func follow(player_pos: Vector3) -> void:
	position = Vector3(player_pos.x, (CLOUD_MIN_Y + CLOUD_MAX_Y) * 0.5, player_pos.z)
