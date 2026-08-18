extends Node

## test_world_lighting — Ánh sáng thế giới CỐ ĐỊNH:
##  - Mọi world (Real + Twilight) có DirectionalLight3D "SunLight" (bóng đổ).
##  - ambient_light_energy = 0 (không ambient — nắng là nguồn sáng duy nhất).
##  - Grass/cỏ shaded (PER_PIXEL) để bắt sáng, không còn flat unshaded.
## Chạy qua tools/test_world_lighting.tscn (không chạy trực tiếp .gd).

const _Env = preload("res://scripts/world/environment/real_world_environment.gd")
const _Twilight = preload("res://scripts/world/environment/twilight_environment.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _check_sun(node: Node, label: String) -> void:
	var sun := node.get_node_or_null("SunLight") as DirectionalLight3D
	_check(sun != null, label + ": có SunLight")
	if sun:
		_check(sun.visible, label + ": SunLight visible")
		_check(sun.shadow_enabled, label + ": SunLight bật shadow")
		_check(sun.light_energy > 0.0, label + ": SunLight có năng lượng")
		_check(sun.get_parent() != null, label + ": SunLight đã thêm vào world")

func _ready() -> void:
	print("== test_world_lighting: nắng + không ambient ==")

	# ── 1. Real world ────────────────────────────────────────────────────────
	WorldChunk.prewarm_grass_resources()
	var host := Node3D.new()
	add_child(host)
	var env := _Env.new()
	host.add_child(env)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_sun(env, "Real world")
	_check(absf(env.environment.ambient_light_energy) < 0.001,
		"Real world ambient_light_energy = 0 (có %g)" % env.environment.ambient_light_energy)
	if WorldChunk._grass_mat != null:
		_check(int(WorldChunk._grass_mat.shading_mode) == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
			"grass shading = PER_PIXEL (nhận sáng)")

	# ── 2. Twilight (hub/main) ──────────────────────────────────────────────
	var tw := _Twilight.new()
	host.add_child(tw)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_sun(tw, "Twilight")
	_check(absf(tw.environment.ambient_light_energy) < 0.001,
		"Twilight ambient_light_energy = 0 (có %g)" % tw.environment.ambient_light_energy)

	host.queue_free()
	await get_tree().process_frame

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)