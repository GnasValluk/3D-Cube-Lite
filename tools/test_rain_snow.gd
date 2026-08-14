extends Node3D
## Smoke test: RainManager instantiate + tuyết trong bio băng không lỗi runtime.

const _Rain = preload("res://scripts/world/weather/rain_manager.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_rain_snow: RainManager + snow frost biome ==")
	WorldSeed.seed_value = 20260805
	preload("res://scripts/world/chunk/chunk_noise.gd").clear_cache()

	var rm := _Rain.new()
	add_child(rm)
	_check(rm.find_child("RainDrops", true, false) != null, "có RainDrops")
	_check(rm.find_child("RainSplash", true, false) != null, "có RainSplash")
	_check(rm.find_child("SnowFlakes", true, false) != null, "có SnowFlakes")
	_check(rm.find_child("RainClouds", true, false) == null, "KHÔNG còn RainClouds (mây đã bỏ)")

	var snow := rm.find_child("SnowFlakes", true, false) as GPUParticles3D
	if snow:
		var pm := snow.process_material as ParticleProcessMaterial
		_check(pm.gravity.y > -6.0, "tuyết rơi chậm (gravity nhẹ): %.2f" % pm.gravity.y)
		var mesh := snow.draw_pass_1
		_check(mesh != null and mesh is SphereMesh, "hạt tuyết là SphereMesh (tròn)")
	else:
		_check(false, "không lấy được SnowFlakes")

	# biome_at FROST tại điểm bio băng đã biết từ test_frost_biome
	var bio := WorldChunk.biome_at(-898.0, 199.0, _Data._Dim.DimensionID.REAL_WORLD)
	_check(bio == _Data.TileType.FROST, "biome_at tại (-898,199) là FROST (đúng nơi test tuyết)")

	for i in 10:
		await get_tree().process_frame

	get_tree().quit(0 if _failures == 0 else 1)
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
