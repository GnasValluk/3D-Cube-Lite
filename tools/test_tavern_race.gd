extends Node

## Stress-test race quán rượu: chạy CHỤM compute_chunk TRÊN WORKER THREAD đồng
## thời ngay sau khi road/river cache bị forced-reset (trạng thái "lần đầu
## spawn/tele") — đúng concurrency path. Nếu static cache build bị race,
## nhiều worker cùng build → road/river/sông/đường lệch → village "mớ hỗn".
## Test so kết quả mỗi worker với baseline tuần tự cùng seed.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Road = preload("res://scripts/world/chunk/chunk_road.gd")
const _River = preload("res://scripts/world/chunk/chunk_river.gd")

const SIZE := 32
const SEED := 20260805

var _failures: int = 0
var _results: Dictionary = {}
var _baseline: Dictionary = {}
var _pending: Array[Vector2i] = []
var _started: bool = false

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS | " + label)
	else:
		_failures += 1
		print("FAIL | " + label)

func _sig(data: Dictionary) -> String:
	var p := ""
	for x in data.get("village_data", {}).get("xforms", []):
		p += "%s;" % str(x as Transform3D)
	return p

func _thread_run(cx: int, cz: int) -> void:
	var data: Dictionary = _W.compute_chunk(cx, cz, SIZE, _D._Dim.DimensionID.REAL_WORLD)
	_results["%d,%d" % [cx, cz]] = _sig(data)

func _compute_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			coords.append(Vector2i(48 + dx, 19 + dz))
	for dx in range(-4, 5):
		for dz in range(-4, 5):
			coords.append(Vector2i(-4 + dx, -7 + dz))
	return coords

func _ready() -> void:
	WorldSeed.seed_value = SEED
	seed(SEED)
	SeedSnapshot.set_seed(SEED)

	print("== test_tavern_race: quán ổn định khi build song song ==")

	var coords := _compute_coords()

	for c in coords:
		_baseline["%d,%d" % [c.x, c.y]] = _sig(_W.compute_chunk(c.x, c.y, SIZE, _D._Dim.DimensionID.REAL_WORLD))
	print("baseline sẵn sàng (%d chunk)" % coords.size())

	_Road._reset_for_test()
	_River._reset_for_test()

	for c in coords:
		_pending.append(c)
		_results["%d,%d" % [c.x, c.y]] = "<run>"
		WorkerThreadPool.add_task(_thread_run.bind(c.x, c.y))

	_started = true

func _process(_delta: float) -> void:
	if not _started:
		return
	var done := 0
	for c in _pending:
		if _results.get("%d,%d" % [c.x, c.y], "") != "<run>":
			done += 1
	if done < _pending.size():
		return
	_started = false
	_finalize()

func _finalize() -> void:
	var mismatches := 0
	for c in _pending:
		var k: String = "%d,%d" % [c.x, c.y]
		if _results.get(k, "") != _baseline.get(k, "<missing>"):
			mismatches += 1
	print("  worker xforms khớp baseline: %d/%d" % [_pending.size() - mismatches, _pending.size()])
	_check(mismatches == 0, "worker vs baseline đồng nhất (%d mismatches)" % mismatches)
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await _W.wait_for_tasks_async(get_tree())
	get_tree().quit(1 if _failures > 0 else 0)