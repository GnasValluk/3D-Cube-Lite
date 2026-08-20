extends Node
func _ready() -> void:
	var f := FastNoiseLite.new()
	print("default fractal_type=", f.fractal_type)
	print("default fractal_octaves=", f.fractal_octaves)
	print("default fractal_gain=", f.fractal_gain)
	print("default fractal_lacunarity=", f.fractal_lacunarity)
	print("default noise_type=", f.noise_type)
	f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	f.seed = 5999
	f.frequency = 0.022
	var a := f.get_noise_2d(12.5, -3.25)
	f.fractal_type = FastNoiseLite.FRACTAL_FBM
	f.fractal_octaves = 5
	f.fractal_gain = 0.5
	f.fractal_lacunarity = 2.0
	# NOTE: sau khi đổi fractal_type/octaves, noise THAY ĐỔI. In cả 2.
	print("plain=", a, " fbm5=", f.get_noise_2d(12.5, -3.25))
	get_tree().quit(0)