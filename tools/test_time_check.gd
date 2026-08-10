extends Node

## Does TIME advance in sky() fragment? Render two frames with a sky shader that
## outputs pure f(TIME); compare pixel deltas.

func _ready() -> void:
	print("== time_check ==")
	var sh := Shader.new()
	sh.code = "shader_type sky;\nvoid sky() {\n\tCOLOR = vec3(0.5 + 0.5 * sin(TIME * 3.0));\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	await get_tree().process_frame
	await get_tree().process_frame
	var a: Color = get_viewport().get_texture().get_image().get_pixel(100, 100)
	for i in 20:
		await get_tree().process_frame
	var b: Color = get_viewport().get_texture().get_image().get_pixel(100, 100)
	for i in 20:
		await get_tree().process_frame
	var c: Color = get_viewport().get_texture().get_image().get_pixel(100, 100)
	print("px a=%.3f b=%.3f c=%.3f  (a!==b => TIME advances)" % [(a.r + a.g + a.b) / 3.0, (b.r + b.g + b.b) / 3.0, (c.r + c.g + c.b) / 3.0])
	get_tree().quit(0)