## neon_environment.gd
## Environment style Just Shapes & Beats:
## Nền xanh tối, bloom chọn lọc (chỉ vật thể featured mới glow),
## không bloom lòe loẹt toàn màn hình.

extends WorldEnvironment

func _ready() -> void:
	var env := Environment.new()

	# ── Nền xanh tối đặc trưng JSaB ──────────────────────────────────────────
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.12, 0.12)

	# ── Ambient teal tối – tạo chiều sâu cho các đồi ─────────────────────────
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.05, 0.20, 0.18)
	env.ambient_light_energy = 0.35

	# ── Bloom nhẹ – chỉ khuếch đại vùng cực sáng (cây featured) ─────────────
	# threshold cao = chỉ emission > 1.0 mới glow, terrain tối không bị ảnh hưởng
	env.glow_enabled       = true
	env.glow_normalized    = true
	env.glow_intensity     = 0.6
	env.glow_strength      = 1.2
	env.glow_bloom         = 0.2
	env.glow_blend_mode    = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale     = 1.5
	env.set_glow_level(0, false)
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.set_glow_level(3, true)
	env.set_glow_level(4, false)
	env.set_glow_level(5, false)
	env.set_glow_level(6, false)

	# ── Tone mapping filmic – giữ màu teal sâu không bị wash out ─────────────
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 1.2

	# ── Saturation cao để teal/cyan rực hơn ──────────────────────────────────
	env.adjustment_enabled    = true
	env.adjustment_brightness = 0.95
	env.adjustment_contrast   = 1.05
	env.adjustment_saturation = 1.3

	environment = env

	# Setup lights sau 1 frame
	await get_tree().process_frame
	_setup_lights()


func _setup_lights() -> void:
	var omni := get_parent().find_child("PlayerLight", true, false) as OmniLight3D
	if omni:
		omni.light_color  = Color(0.4, 1.0, 0.85)
		omni.light_energy = 1.5
		omni.omni_range   = 4.0

	var dir := get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir:
		dir.light_color  = Color(0.15, 0.55, 0.50)
		dir.light_energy = 0.6
		dir.shadow_enabled = true
