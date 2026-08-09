extends Node

## Diagnostic: tái hiện landing-point của _on_teleport_tavern (hud.gd) cho TẤT CẢ
## quán trong bán kính quét, rồi kiểm tra điểm rơi có nằm TRONG interior AABB
## (thứ gây fade vỏ -> "đống hỗn tạp" khi nhìn từ trong). Nếu nhiều quán có
## điểm rơi trong AABB -> root cause là vị trí hạ cánh, không phải build data.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _V = preload("res://scripts/world/chunk/village.gd")
const _Road = preload("res://scripts/world/chunk/chunk_road.gd")

const SIZE := 32
const SEED := 20260806
const RADIUS := 6000.0

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		print("  FAIL: %s" % label)

## Sao chép _tavern_interior_aabb từ world_chunk.gd (world space, yaw quanh Y).
func _interior_aabb(b: Dictionary) -> Array:
	var yaw: float = float(b.get("yaw", 0.0))
	var co: float = cos(yaw)
	var si: float = sin(yaw)
	var c := Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
	const LX: float = 5.0
	const Z0: float = -2.4
	const Z1: float = 6.6
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for lz in [Z0, Z1]:
		for s in [-1.0, 1.0]:
			var lx: float = s * LX
			var wx: float = c.x + lx * co - lz * si
			var wz: float = c.z + lx * si + lz * co
			mn = mn.min(Vector2(wx, wz))
			mx = mx.max(Vector2(wx, wz))
	var bot: float = float(b.get("gy", 0.0)) - 0.5
	var top: float = float(b.get("gy", 0.0)) + float(b.get("top_y", 11.5)) + 0.5
	return [Vector3(mn.x, bot, mn.y), Vector3(mx.x, top, mx.y)]

func _ready() -> void:
	WorldSeed.seed_value = SEED
	seed(SEED)
	SeedSnapshot.set_seed(SEED)

	print("== test_tavern_landing: điểm hạ cánh so interior AABB ==")

	var origin := Vector2(0.0, 0.0)
	var taverns: Array = _V.scan_taverns(origin, RADIUS)
	_check(taverns.size() > 0, "có %d quán trong bán kính %dm" % [taverns.size(), int(RADIUS)])
	print("  tổng quán scan: %d" % taverns.size())

	var inside := 0
	var outside := 0
	var tested := 0
	for t in taverns:
		var bx: float = float(t.x)
		var bz: float = float(t.z)
		var node_pt: Vector2 = _Road.intersection_point(int(t.gx), int(t.gz))
		var toward := (node_pt - Vector2(bx, bz))
		if toward.length() < 0.1:
			toward = Vector2(0, 1)
		toward = toward.normalized()
		WorldChunk.ensure_chunk_built(bx, bz)
		var land: Vector2 = WorldChunk.tavern_landing_point(bx, bz, toward)

		# Lấy tòa nhà thật từ chunk build (village_data "info.buildings").
		var half: float = SIZE * 0.5
		var cx: int = int(floor((land.x + half) / SIZE))
		var cz: int = int(floor((land.y + half) / SIZE))
		var data := _W.compute_chunk(cx, cz, SIZE, _D._Dim.DimensionID.REAL_WORLD)
		var vbd: Dictionary = data.get("village_data", {})
		if not vbd.get("has", false):
			continue
		var b := {}
		for item in vbd.get("info", {}).get("buildings", []):
			if absf(float(item.get("x", 0.0)) - bx) < 5.0 \
					and absf(float(item.get("z", 0.0)) - bz) < 5.0:
				b = item
				break
		if b.is_empty():
			continue
		tested += 1
		var ab: Array = _interior_aabb(b)
		var ab0: Vector3 = ab[0]
		var ab1: Vector3 = ab[1]
		var in_box: bool = land.x >= ab0.x and land.x <= ab1.x \
			and land.y >= ab0.z and land.y <= ab1.z
		if in_box:
			inside += 1
			print("    INSIDE quán (%d,%d) land=(%.1f,%.1f) center=(%.1f,%.1f) aabb=%.1f..%.1f / %.1f..%.1f yaw=%.1f" % [
				int(t.gx), int(t.gz), land.x, land.y, bx, bz,
				ab0.x, ab1.x, ab0.z, ab1.z, float(b.get("yaw", 0.0)) * 57.2957795])
		else:
			outside += 1

	print("  số quán kiểm tra được: %d" % tested)
	print("  điểm rơi TRONG interior AABB: %d (%.0f%%)" % [inside, 100.0 * inside / maxi(1, tested)])
	print("  điểm rơi NGOÀI (hạ cán tốt):  %d (%.0f%%)" % [outside, 100.0 * outside / maxi(1, tested)])
	_check(tested > 0, "có quán để kiểm tra landing")
	_check(inside == 0, "MỌI landing nằm ngoài interior AABB (%d vi phạm)" % inside)

	print("== kết thúc: %d lỗi ==" % _failures)
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(1 if _failures > 0 else 0)