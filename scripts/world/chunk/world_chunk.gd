extends Node3D
class_name WorldChunk

const _Data  = preload("chunk_data.gd")
const _Noise = preload("chunk_noise.gd")
const _Road  = preload("chunk_road.gd")
const _River = preload("chunk_river.gd")
const _Detail = preload("chunk_detail.gd")
const _Grass = preload("chunk_grass.gd")
const _Aquatic = preload("chunk_aquatic.gd")
const _BlockData = preload("chunk_block_data.gd")
const _RoadLamp = preload("chunk_road_lamp.gd")
const _PalmProp = preload("res://scripts/world/props/palm_prop.gd")
const _OakProp = preload("res://scripts/world/props/oak_prop.gd")
const _OrangeTreeProp = preload("res://scripts/world/props/orange_tree_prop.gd")
const _DenseTreeProp = preload("res://scripts/world/props/dense_tree_prop.gd")
const _EggplantProp = preload("res://scripts/world/props/eggplant_prop.gd")
const _WatermelonVine = preload("res://scripts/world/props/watermelon_vine_prop.gd")
const _PumpkinVine = preload("res://scripts/world/props/pumpkin_vine_prop.gd")
const _PlainsBush = preload("res://scripts/world/props/plains_bush_prop.gd")
const _Terrain = preload("chunk_terrain.gd")
const _Village = preload("village.gd")
const _ChimneySmoke = preload("chimney_smoke.gd")
const _TavernDoor = preload("tavern_door.gd")
const _WaterFlow = preload("water_flow.gd")
const _OreTex = preload("res://scripts/items/models/ore_texture.gd")
const _MangroveProp = preload("res://scripts/world/props/mangrove_prop.gd")
const _CattailProp = preload("res://scripts/world/props/cattail_prop.gd")
const _MudCrabCreature = preload("res://scripts/characters/crab/mud_crab_character.gd")
const _FrostTreeProp = preload("res://scripts/world/props/frost_tree_prop.gd")
const _SeaPlantProp = preload("res://scripts/world/props/sea_plant_prop.gd")
const _SwampTreeProp = preload("res://scripts/world/props/swamp_tree_prop.gd")
const _SwampSedgeProp = preload("res://scripts/world/props/swamp_sedge_prop.gd")
const _DuckweedProp = preload("res://scripts/world/props/duckweed_prop.gd")
const _FarPropPool = preload("res://scripts/world/props/far_prop_pool.gd")

## Bán kính Chebyshev (chunk) giới hạn vòng prop tương tác: chunk TRONG vòng này
## vẫn spawn node DestroyableProp (chặt/đập/rung cây khi đứng gần); chunk NGOÀI
## vòng render qua FarPropPool (1 MultiMesh/loại toàn cục) để cắt mạnh số node.
const PROP_MERGE_RING: int = 2

static func _is_water_bid(bid: int) -> bool:
	return bid == _Data.BlockID.WATER \
		or (bid >= _Data.BlockID.WATER_SOURCE and bid <= _Data.BlockID.WATER_LEVEL_1)

static func _is_lava_bid(bid: int) -> bool:
	return bid == _Data.BlockID.LAVA_SOURCE \
		or (bid >= _Data.BlockID.LAVA_LEVEL_7 and bid <= _Data.BlockID.LAVA_LEVEL_1)

## Mặt địa hình thực (top face khối) được lượng tử hoá theo SLAB:
## cy_top = floor(h / SLAB) * SLAB. Cây/đánh phải bám ĐÚNG mặt này,
## không gắn theo h thô — nếu không sẽ lơ lửng trên đồi cao.
static func _snap_surface_y(h: float) -> float:
	return floorf(h / _BlockData.SLAB_HEIGHT) * _BlockData.SLAB_HEIGHT

## ── BFS đa nguồn (4-láng giềng, Manhattan) — thay multi-pass distance map ─────
## Nguồn = ô có giá trị != CONST_INF (0 cho source, sẵn giá trị band đầu nếu cần).
## Lan chỉ vào ô có mask==1 (mask rỗng → mọi ô). Kết quả y hệt multi-pass cũ.
static func _bfs_manhattan(dmap: PackedInt32Array, total: int, mask: PackedByteArray = PackedByteArray()) -> void:
	var use_mask: bool = mask.size() > 0
	var frontier := PackedInt32Array()
	for i in range(dmap.size()):
		if dmap[i] != _Data.CONST_INF:
			frontier.append(i)
	var fhead := 0
	while fhead < frontier.size():
		var idx: int = frontier[fhead]
		fhead += 1
		var nd: int = dmap[idx] + 1
		var cx: int = idx / total
		var cz: int = idx % total
		if cx > 0:
			var ni: int = idx - total
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)
		if cx < total - 1:
			var ni: int = idx + total
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)
		if cz > 0:
			var ni: int = idx - 1
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)
		if cz < total - 1:
			var ni: int = idx + 1
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)

## ── BFS đa nguồn (8-láng giềng, Chebyshev) — khoảng cách nước/đường/sa mạc ──
## Đầu vào: nguồn = 0, chưa biết = -1. Đầu ra: -1 được đổi thành CONST_INF để
## phép so sánh "khoảng cách <= r" không dính lỗi -1 <= r.
static func _bfs_chebyshev(dmap: PackedInt32Array, cols: int) -> void:
	var frontier := PackedInt32Array()
	for i in range(dmap.size()):
		if dmap[i] == 0:
			frontier.append(i)
	var fhead := 0
	while fhead < frontier.size():
		var idx: int = frontier[fhead]
		fhead += 1
		var nd: int = dmap[idx] + 1
		var cx: int = idx / cols
		var cz: int = idx % cols
		for dx in range(-1, 2):
			var nx: int = cx + dx
			if nx < 0 or nx >= cols:
				continue
			for dz in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nz: int = cz + dz
				if nz < 0 or nz >= cols:
					continue
				var ni: int = nx * cols + nz
				if dmap[ni] == -1:
					dmap[ni] = nd
					frontier.append(ni)
	for i in range(dmap.size()):
		if dmap[i] == -1:
			dmap[i] = _Data.CONST_INF

static func _water_level_of(bid: int) -> int:
	if bid == _Data.BlockID.WATER_SOURCE or bid == _Data.BlockID.WATER:
		return 8
	if bid >= _Data.BlockID.WATER_LEVEL_7 and bid <= _Data.BlockID.WATER_LEVEL_1:
		return 8 - (bid - _Data.BlockID.WATER_LEVEL_7)
	return 0

## Fluid (water hoặc lava) level — dùng cho fluid mesh chung.
static func _is_fluid_bid(bid: int) -> bool:
	return bid == _Data.BlockID.WATER \
		or (bid >= _Data.BlockID.WATER_SOURCE and bid <= _Data.BlockID.WATER_LEVEL_1) \
		or bid == _Data.BlockID.LAVA_SOURCE \
		or (bid >= _Data.BlockID.LAVA_LEVEL_7 and bid <= _Data.BlockID.LAVA_LEVEL_1)

static func _fluid_level_of(bid: int) -> int:
	if bid == _Data.BlockID.WATER_SOURCE or bid == _Data.BlockID.WATER:
		return 8
	if bid >= _Data.BlockID.WATER_LEVEL_7 and bid <= _Data.BlockID.WATER_LEVEL_1:
		return 8 - (bid - _Data.BlockID.WATER_LEVEL_7)
	if bid == _Data.BlockID.LAVA_SOURCE:
		return 8
	if bid >= _Data.BlockID.LAVA_LEVEL_7 and bid <= _Data.BlockID.LAVA_LEVEL_1:
		return 8 - (bid - _Data.BlockID.LAVA_LEVEL_7)
	return 0

## Fluid nào (water/lava) để chọn màu mesh.
static func _fluid_kind(bid: int) -> int:
	return 1 if (bid == _Data.BlockID.LAVA_SOURCE or (bid >= _Data.BlockID.LAVA_LEVEL_7 and bid <= _Data.BlockID.LAVA_LEVEL_1)) else 0

# ── Ocean mask tại 1 world cell — nguồn duy nhất cho đất vs biển ────────────
# Warp bờ biển + bias vùng spawn (gốc tọa độ luôn là đất). Hud teleport,
# explore map, fish_spawner và test dùng chung hàm này để không lệch nhau.
const SPAWN_BIAS_AMP: float = 2.2
const SPAWN_BIAS_SIG2: float = 500000.0
const SPAWN_BIAS_CUT: float = 2000000.0
## Đĩa an toàn quanh gốc: LUÔN là đất (spawn/tavern/village) — "đảo nhà" rộng
## ~650 để có lòng đồng cỏ sâu cho hồ/làng. Quần đảo nhỏ bắt đầu ngoài đĩa.
const SPAWN_FORCE_R2: float = 110000.0
## BIỂN KHÔNG ĐƯỢC PHÉP CẮT ĐỊA HÌNH NÚI: cells có "lõi núi thật" (mtn_t >
## 0.50 — khớp đúng ngưỡng vùng núi của find_mountain/zone hệ thống) luôn là đất
## liền, blob đảo bên dưới không thể phủ thành biển. Chọn 0.50 (không phải 0.0)
## để chỉ núi thật làm đất: đồi thấp thoải vẫn được quần đảo phủ (land ~39%).
## Hệ quả: dải núi thành lục địa tự nhiên, quần đảo sống ở vùng biển thấp.
const MOUNTAIN_LAND_T: float = 0.5

## Giới hạn số đèn sen 1 chunk — trước đây tạo 20-40 OmniLight3D/chunk (49 chunk
## trong tầm = ~1500 node đèn, cày GC + enter/exit tree mỗi lần stream → spike
## apply_chunk 10-50ms). LotusLightManager chỉ sáng 40 đèn GẦN camera nhất, nên
## đèn thừa là node chết. Giữ 12 đèn GẦN TÂM chunk nhất cho cảnh quan.
const MAX_LOTUS_PER_CHUNK: int = 12

static func _ocean_mask_at(nd: Dictionary, wx: float, wz: float) -> bool:
	# Thread-safe cache theo ô thế giới: lưới ocean stride-2 (42×42) của 2 chunk
	# kề nhau overlap ~62% số sample — dùng chung bỏ qua FastNoiseLite FBM lặp.
	# Key gồm seed để switch seed giữa chừng không trả mask của seed cũ.
	var key := Vector3i(floori(wx), floori(wz), SeedSnapshot.ensure())
	_ocean_cache_lock.lock()
	if _ocean_cache.has(key):
		var hit: bool = _ocean_cache[key]
		_ocean_cache_lock.unlock()
		return hit
	_ocean_cache_lock.unlock()
	var val: bool = _ocean_mask_compute(nd, wx, wz)
	_ocean_cache_lock.lock()
	if _ocean_cache.size() >= OCEAN_CACHE_MAX:
		_ocean_cache.clear()
	_ocean_cache[key] = val
	_ocean_cache_lock.unlock()
	return val

static func _ocean_mask_compute(nd: Dictionary, wx: float, wz: float) -> bool:
	var d2: float = wx * wx + wz * wz
	if d2 < SPAWN_FORCE_R2:
		return false
	# Vùng terrain thực sự MOUNTAIN → LUÔN đất, không để blob đảo phủ thành
	# biển ("biển không được cắt địa hình núi"). Dùng đúng noise mountain +
	# smoothstep như land-branch (height_grid 1c) để mask khớp địa hình thật.
	var n_mt: FastNoiseLite = nd.get("mountain")
	if n_mt:
		var mtn: float = (n_mt.get_noise_2d(wx, wz) + 1.0) * 0.5
		var mtn_t: float = clamp((mtn - 0.58) / 0.14, 0.0, 1.0)
		mtn_t = mtn_t * mtn_t * (3.0 - 2.0 * mtn_t)
		if mtn_t > MOUNTAIN_LAND_T:
			return false
	# Đảo = blob quanh hub của ô đảo chứa điểm. Rain lệch bán kính theo
	# ocean_warp để bờ biển lồi lõm; spawn-safe: mọc rộng quanh gốc tọa độ.
	var seed: int = SeedSnapshot.ensure()
	var cx: int = int(floor(wx / _Data.ISLAND_CELL))
	var cz: int = int(floor(wz / _Data.ISLAND_CELL))
	var hub := _Data.island_hub(cx, cz, seed)
	var axes := _Data.island_axes(cx, cz, seed)
	var dx: float = wx - hub.x
	var dz: float = wz - hub.y
	var edge: float = (nd["ocean_warp"] as FastNoiseLite).get_noise_2d(wx * 0.5, wz * 0.5)
	var e: float = 1.0 + edge * 0.12
	var grow: float = SPAWN_BIAS_AMP * exp(-d2 / SPAWN_BIAS_SIG2)
	# Gần gốc: đảo MỌC LỚN hơn (hồ nội địa, làng, quán rượu cần lòng đồng cỏ
	# sâu >40 ô). Suy giảm theo e^{−r²/σ²} → xa ~1.2km là quần đảo nhỏ chuẩn.
	var g: float = grow * 40.0
	var gaxes := Vector2(axes.x + g, axes.y + g)
	var sq: float = (dx / (gaxes.x * e)) * (dx / (gaxes.x * e)) \
		+ (dz / (gaxes.y * e)) * (dz / (gaxes.y * e))
	var seen: bool = sq < 1.0
	# Đảo nhỏ rải biển — thêm đất mảnh, tránh hành trình biển dài không đảo.
	if not seen:
		var icx: int = int(floor(wx / _Data.ISLET_CELL))
		var icz: int = int(floor(wz / _Data.ISLET_CELL))
		var ihub := _Data.islet_hub(icx, icz, seed)
		var ir: float = _Data.islet_radius(icx, icz, seed)
		var idx: float = wx - ihub.x
		var idz: float = wz - ihub.y
		seen = _Data.islet_present(icx, icz, seed) \
			and (idx * idx + idz * idz) < ir * ir
	if not seen and grow > 0.0:
		var reach: float = maxf(axes.x, axes.y) + grow * 1.8
		seen = dx * dx + dz * dz < reach * reach
	return not seen

## ── _gen_water_top_layer: layer cao nhất nước generation có thể tồn tại ─────
static func _gen_water_top_layer() -> int:
	return floori((_Data.WATER_Y - _BlockData.SLAB_HEIGHT) / _BlockData.SLAB_HEIGHT) - _BlockData.Y_MIN

var _cx: int = 0
var _cz: int = 0
var _was_setup: bool = false
var _size: int = 0
var _cols: int = 0
var _tiles_per_chunk: int = 0
var _biome_grid: Array[Array] = []
var _dimension_id: int = _Data._Dim.DimensionID.TWILIGHT
var _built: bool = false
var _is_lod: bool = false  # chunk xa: mesh thô, không block_data/props/water
var _collision_pending: bool = false
var _water_tick_timer: float = 0.0
var _has_water: bool = false
var _max_water_ly: int = -1
var _has_lava: bool = false
var _max_lava_ly: int = -1
var _lava_mesh_instance: MeshInstance3D = null
var _has_ores: bool = false
var _has_soil: bool = false
var _top_ly_cache := PackedInt32Array()

## Block data — cho phép set_block / get_block sau này (build/mine)
var block_data: _BlockData = null

## References to per-type meshes (preserved across rebuilds)
var _terrain_mesh_instance: MeshInstance3D = null
var _water_mesh_instance: MeshInstance3D = null
var _aquatic_mesh_instance: MeshInstance3D = null
var _textured_block_mesh_instances: Dictionary[int, MeshInstance3D] = {}
var _shaped_block_instances: Array[MeshInstance3D] = []
var _has_shaped_blocks: bool = false  # Chunk có shaped blocks (skip scan 70K khi không có)
var _mesh_container: Node3D = null
var _tavern_built: bool = false
var _lotus_lights: Array[OmniLight3D] = []
var _prop_queue: Array = []
var _prop_idx: int = 0
var _spawned_props: Array[Node] = []
var _props_via_pool: bool = false

## Bật/tắt spawn prop plant (headless benchmark tắt để đo sạch phần chunk;
## game thật luôn true).
static var props_enabled: bool = true

## Ngân sách spawn prop dùng chung toàn game/frame — khi có nhiều chunk cùng
## stream, từng chunk KHÔNG còn tự do 2 prop/frame (tổng có thể bùng hàng chục
## cây/khối nặng trong cùng 1 frame → spike). Thay vào đó dùng qui ước chi phí:
## cỏ/meadow rẻ, cây/khối nặng đắt; mỗi frame chia sẻ tổng ngân sách, hết thì
## dồn frame sau. Prop rẻ (weed/seagrass/taro) ưu tiên trước, cây nặng để sau.
static var _prop_budget_remaining: int = 0
static var _prop_budget_max: int = 8
static var _prop_budget_frame: int = -1
## Reset ngân sách 1 lần mỗi frame (idempotent dù nhiều chunk cùng _process).
static func _prop_reset_budget() -> void:
	var f := Engine.get_process_frames()
	if f == _prop_budget_frame:
		return
	_prop_budget_frame = f
	_prop_budget_remaining = _prop_budget_max

## Chi phí spawn (đơn vị ngân sách) theo loại prop — đắt nhất là cây voxel.
const _PROP_SPAWN_COST := {
	"oak": 6,
	"dense_tree": 4,
	"palm": 3,
	"orange_tree": 3,
	"mangrove": 3,
	"spruce": 4,
	"swamp_tree": 4,
	"pumpkin": 1,
	"watermelon": 1,
	"eggplant": 1,
	"cherry_bush": 1,
	"mud_crab": 2,
}

static func _prop_cost(ptype: String) -> int:
	return _PROP_SPAWN_COST.get(ptype, 1)

## ── Profiler section timing (benchmark test bật; mặc định tắt) ─────────────
static var _prof_enabled: bool = false
static var _prof_last_usec: int = 0
static func _prof_reset() -> void:
	_prof_last_usec = Time.get_ticks_usec()
static func _prof(tag: String) -> void:
	if not _prof_enabled:
		return
	var now := Time.get_ticks_usec()
	print("  [prof] %-22s %6.2fms" % [tag, (now - _prof_last_usec) * 0.001])
	_prof_last_usec = now

static var _mesh_cache: Dictionary = {}
## Cache LOD (mesh thô + height/biome/road) — tách riêng để `_mesh_cache` luôn
## giữ dữ liệu FULL cho sample_ground_height/is_tavern_built_at/ensure_chunk_built,
## tránh LOD phủ đè nguồn sự thật. Xoá khi chunk LOD bị free (PREDELETE).
static var _lod_mesh_cache: Dictionary = {}
static var _pending_chunks: Dictionary = {}
static var _pending_mutex := Mutex.new()

## ── Giới hạn số chunk/tile generation task song song ─────────────────────────
## WorkerThreadPool mặc định chạy trên MỌI core (max_threads=-1). Boot/stream
## đẩy đồng thời ~40+ chunk build + 16 sub-task/tile + water rebuild → bão hoà
## CPU: mỗi chunk compute phình 10-20x (300-1000ms thay vì 25-46ms solo) và
## main thread bị đói → frame spike 100-180ms (lag khi load chunk mới).
## Cap concurrency ≡ nửa số core → gen song song vẫn nhanh, main thread còn
## tài nguyên render/physics. Manager giữ task chưa gửi trong _pending, chỉ
## gửi tiếp khi in-flight dưới cap.
static var _gen_in_flight: int = 0
static var _gen_mutex := Mutex.new()
static func _gen_inc() -> void:
	_gen_mutex.lock()
	_gen_in_flight += 1
	_gen_mutex.unlock()
static func _gen_dec() -> void:
	_gen_mutex.lock()
	_gen_in_flight = maxi(0, _gen_in_flight - 1)
	_gen_mutex.unlock()
static func gen_in_flight() -> int:
	_gen_mutex.lock()
	var v := _gen_in_flight
	_gen_mutex.unlock()
	return v
static func _max_gen_in_flight() -> int:
	return maxi(1, int(floor(float(OS.get_processor_count()) * 0.5)))

## Thread-safe cache `_ocean_mask_at` theo ô thế giới — dùng chung giữa các
## chunk/tile cận kề (lưới ocean stride-2 overlap ~62% giữa chunk kế nhau).
static var _ocean_cache: Dictionary = {}
static var _ocean_cache_lock := Mutex.new()
const OCEAN_CACHE_MAX: int = 262144

## ── Task tracking: chờ mọi worker task xong trước khi process thoát ─────────
## Worker chạy lúc teardown (chunk build, water, collision, decorative, prewarm)
## đọc dữ liệu đang bị destroy → crash 0xC0000005 (từng tái hiện tất định ở
## test_till/test_ore_tex/test_promote). Test gọi wait_for_tasks_async() trước
## khi quit — engine bản này không có SceneTree.about_to_quit nên không thể
## hook tập trung.
static var _task_ids: Array[int] = []
static var _task_mutex := Mutex.new()

static func _track_task(tid: int) -> void:
	_task_mutex.lock()
	_task_ids.append(tid)
	_task_mutex.unlock()

static func _pending_task_count() -> int:
	_task_mutex.lock()
	var ids := _task_ids.duplicate()
	_task_mutex.unlock()
	var count := 0
	for tid in ids:
		if not WorkerThreadPool.is_task_completed(tid):
			count += 1
	return count

## Đợi mọi task hoàn thành (kể cả task sinh deferred sau 1-2 frame).
static func wait_for_tasks_async(tree: SceneTree, max_wait_ms: int = 15000) -> void:
	var stable_frames := 0
	var waited := 0
	while stable_frames < 3:
		if _pending_task_count() == 0:
			stable_frames += 1
		else:
			stable_frames = 0
		if waited >= max_wait_ms:
			push_warning("WorldChunk.wait_for_tasks_async: timeout %dms" % max_wait_ms)
			return
		await tree.process_frame
		waited += 16
var _pending_data: Dictionary = {}
static var _river_noise: FastNoiseLite = null
static var _river_bed_noise: FastNoiseLite = null

static func _ensure_river_noise() -> void:
	if _river_noise == null:
		_river_noise = FastNoiseLite.new()
		_river_noise.seed = SeedSnapshot.ensure() + 9999
		_river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_river_noise.frequency = 0.06
	if _river_bed_noise == null:
		_river_bed_noise = FastNoiseLite.new()
		_river_bed_noise.seed = SeedSnapshot.ensure() + 10101
		_river_bed_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_river_bed_noise.frequency = 0.04

static func _noise_for_dim(dim_id: int) -> Dictionary:
	return _Noise._noise_for_dim(dim_id)

static func clear_noise_cache() -> void:
	_Noise.clear_cache()
	_mesh_cache.clear()
	_lod_mesh_cache.clear()
	_mat_cache.clear()
	_river_noise = null
	_river_bed_noise = null
	_ocean_cache.clear()

## ── Pre-warm mạng đường + sông trên worker thread ────────────────────────────
## Network gen tốn ~5-6s một lần (cached static). Chạy trên worker trong lúc
## loading screen để world scene không bị đứng hình khi build chunk đầu.
static var _networks_ready: bool = false
static var _networks_seed: int = -1
static var _prewarm_running: bool = false

static func _reset_networks() -> void:
	_networks_ready = false
	_Road._road_curves.clear()
	_Road._road_curve_bboxes.clear()
	_Road._road_spatial.clear()
	_Road._road_ready = false
	_Road._int_cache.clear()
	_Road._node_has_cache.clear()
	_River._river_curves.clear()
	_River._river_spatial.clear()
	_River._river_ready = false
	_River._int_cache.clear()
	_River._noise_river = null

static func _prewarm_networks() -> void:
	var seed_v: int = SeedSnapshot.ensure()
	if _networks_ready and _networks_seed == seed_v:
		_prewarm_running = false
		return
	_reset_networks()
	_networks_seed = seed_v
	_Road._ensure_roads()
	_River._ensure_rivers()
	_networks_ready = true
	_prewarm_running = false

static func prewarm_async() -> void:
	var seed_v: int = WorldSeed.seed_value
	SeedSnapshot.set_seed(seed_v)
	if _networks_ready and _networks_seed == seed_v:
		return
	if _prewarm_running:
		return
	# Chặn ngay trên main thread — tránh loading screen start world với dữ liệu cũ
	_networks_ready = false
	_prewarm_running = true
	_track_task(WorkerThreadPool.add_task(_prewarm_networks))

static func _is_on_road(wx: float, wz: float) -> bool:
	return _Road.is_on_road(wx, wz)

## ── Bãi đất thổ lớn: 1 ô trong vùng đất — trộn nhiều loại đất theo noise ──
## Đồng bằng (cả trũng ẩm lẫn nền giữa): vùng đất đã rộng (patch_dirt), từng
## ô oanh loại đất: DIRT (đất thổ), GRASS_DIRT (đất cỏ cày), YOUNG_GRASS (đất
## non), DARK_GRASS (đất ẩm) theo patch_var — đồng xu đều, không lởm chởm.
static func _soil_field_block(ivx: int, ivz: int, wx: float, wz: float,
		nd: Dictionary, biome_grid: Array) -> void:
	var sv: float = (nd["patch_var"].get_noise_2d(wx, wz) + 1.0) * 0.5
	var p2: float = (nd["patch2"].get_noise_2d(wx, wz) + 1.0) * 0.5
	if sv > 0.82:
		biome_grid[ivx][ivz] = _Data.TileType.DIRT
	elif sv > 0.62:
		biome_grid[ivx][ivz] = _Data.TileType.GRASS_DIRT
	elif sv > 0.44:
		biome_grid[ivx][ivz] = _Data.TileType.YOUNG_GRASS
	elif p2 > 0.55:
		biome_grid[ivx][ivz] = _Data.TileType.DIRT
	else:
		biome_grid[ivx][ivz] = _Data.TileType.DARK_GRASS

static func _is_on_river(wx: float, wz: float) -> bool:
	return _River.is_on_river(wx, wz)

static func _cache_key(cx: int, cz: int, dim: int) -> String:
	return "%d,%d,%d" % [cx, cz, dim]

## Lấy cao độ mặt đất (m) tại world pos từ chunk đã build trong _mesh_cache.
## Trả về -INF nếu chunk chưa được build. Dùng cho teleport hạ cánh đúng tầng.
static func sample_ground_height(wx: float, wz: float) -> float:
	const SIZE: int = 32
	var half: float = SIZE * 0.5
	var cx: int = int(floor((wx + half) / SIZE))
	var cz: int = int(floor((wz + half) / SIZE))
	var ck: String = _cache_key(cx, cz, _Data._Dim.DimensionID.REAL_WORLD)
	if not _mesh_cache.has(ck):
		return -INF
	var hg: Array = (_mesh_cache[ck] as Dictionary).get("height_grid", [])
	if hg.is_empty():
		return -INF
	var cols: int = hg.size()
	var vx: int = int(floor((wx - (cx * SIZE - half)) / _Data.VOXEL))
	var vz: int = int(floor((wz - (cz * SIZE - half)) / _Data.VOXEL))
	if vx < 0 or vx >= cols or vz < 0 or vz >= cols:
		return -INF
	return float(hg[vx][vz])

## Build ĐỒNG BỘ chunk chứa (wx,wz) vào _mesh_cache nếu chưa có, để
## sample_ground_height / is_tavern_built_at trả về số liệu THẬT. Dùng khi
## teleport tới vùng chưa được stream: đặt player đúng độ cao + chỉ nhắm vào
## quán đã thực sự được dựng. Chỉ gọi từ main thread.
static func ensure_chunk_built(wx: float, wz: float) -> void:
	const SIZE: int = 32
	var half: float = SIZE * 0.5
	var cx: int = int(floor((wx + half) / SIZE))
	var cz: int = int(floor((wz + half) / SIZE))
	var ck: String = _cache_key(cx, cz, _Data._Dim.DimensionID.REAL_WORLD)
	if _mesh_cache.has(ck):
		return
	var data: Dictionary = compute_chunk(cx, cz, SIZE, _Data._Dim.DimensionID.REAL_WORLD)
	compress_block_data(data)
	_mesh_cache[ck] = data

## Nén `block_data_bytes` của 1 dict chunk (chỉ 1 lần, đánh dấu bd_compressed).
## Gọi trước khi cache; runtime chỉ dùng live `block_data` nên không cần giải nén.
static func compress_block_data(data: Dictionary) -> void:
	if data.get("bd_compressed", false):
		return
	var src: PackedByteArray = data.get("block_data_bytes", PackedByteArray())
	if not src.is_empty():
		data["block_data_bytes"] = src.compress(FileAccess.COMPRESSION_DEFLATE)
		data["bd_compressed"] = true

## Lấy biome (TileType) tại world pos — CÙNG nguồn sự thật với địa hình
## (có spawn-bias, ưu tiên sa mạc cao nguyên...). Dùng cho teleport biome
## để không bao giờ rơi vào biome khác với nơi được dựng.
static func biome_at(wx: float, wz: float, dim_id: int) -> int:
	return _Noise._biome_at(wx, wz, dim_id)

## Tìm world pos vùng NÚI CAO (mountain noise) gần (wx,wz), không nằm biển.
## Dùng cho debug teleport "Núi". Núi vừa (đắp 4..9 block) → không cần quá khắt
## khe: chọn tiêu chuẩn mtn_t > 0.50 (vừa khít vùng đắp cao thật).
## Trả { "ok", "x", "z" }.
static func find_mountain(wx: float, wz: float, max_radius: float = 15000.0) -> Dictionary:
	const DIM: int = _Data._Dim.DimensionID.REAL_WORLD
	var nd: Dictionary = _noise_for_dim(DIM)
	var n_mt: FastNoiseLite = nd.get("mountain")
	if n_mt == null:
		return { "ok": false }
	var origin := Vector2(wx, wz)
	const STEP: float = 120.0
	var r: float = STEP
	while r <= max_radius:
		var samples: int = max(8, int(r / STEP * TAU))
		for i in range(samples):
			var angle: float = float(i) / float(samples) * TAU
			var sx: float = origin.x + cos(angle) * r
			var sz: float = origin.y + sin(angle) * r
			if _ocean_mask_at(nd, sx, sz):
				continue
			var mtn: float = (n_mt.get_noise_2d(sx, sz) + 1.0) * 0.5
			var mtn_t: float = clamp((mtn - 0.58) / 0.14, 0.0, 1.0)
			mtn_t = mtn_t * mtn_t * (3.0 - 2.0 * mtn_t)
			if mtn_t > 0.50:
				return { "ok": true, "x": sx, "z": sz }
		r += STEP
	return { "ok": false }

## Cường độ rừng đước tại (wx,wz): 0 = không, ≈1 = lõi rừng ngập mặn ven biển.
## Khớp logic intertidal pass trong compute_chunk() để teleport tìm đúng chỗ:
## mask mangrove noise + phải gần bờ (đổi mask biển/đất trong ~14 block).
static func _mangrove_strength_at(nd: Dictionary, wx: float, wz: float) -> float:
	var mg: float = (nd["mangrove"].get_noise_2d(wx, wz) + 1.0) * 0.5
	var mg_mask: float = clamp((mg - 0.46) / 0.22, 0.0, 1.0)
	if mg_mask <= 0.0:
		return 0.0
	var is_oc: bool = _ocean_mask_at(nd, wx, wz)
	var near_shore: bool = false
	for k in range(8):
		var ang: float = float(k) / 8.0 * TAU
		var sx: float = wx + cos(ang) * 14.0
		var sz: float = wz + sin(ang) * 14.0
		if _ocean_mask_at(nd, sx, sz) != is_oc:
			near_shore = true
			break
	if not near_shore:
		return 0.0
	return mg_mask

## Giá trị ngẫu nhiên [0,1) XÁC ĐỊNH từ ô (vx,vz) — KHÔNG tiêu global RNG.
## Các rule thực vật dại khác (cà tím, dưa hấu, bí, cam...) dùng randf() chung
## với stream toàn cục; nếu rule rừng đước dùng randf() sẽ làm lệch stream →
## đổi phân bố cây dại trên các chunk sau. Hash này trả kết quả cố định.
static func _cell_hash01(vx: int, vz: int) -> float:
	var x := int(vx) * 73856093 + int(vz) * 19349663 + 83492791
	x = (x ^ (x >> 12)) * 715225241
	x = (x ^ (x >> 17)) * 449984367
	x = x ^ (x >> 13)
	return float(x & 0x7FFFFFFF) / 2147483648.0

## Tìm world pos vùng RỪNG NGẬP MẶN (bùn triều ven biển) gần (wx,wz).
## Dùng cho debug teleport "Rừng Ngập Mặn". Trả { "ok", "x", "z" }.
static func find_mangrove(wx: float, wz: float, max_radius: float = 25000.0) -> Dictionary:
	const DIM: int = _Data._Dim.DimensionID.REAL_WORLD
	var nd: Dictionary = _Noise._noise_for_dim(DIM)
	var n_mg: FastNoiseLite = nd.get("mangrove")
	if n_mg == null:
		return { "ok": false }
	var origin := Vector2(wx, wz)
	const STEP: float = 150.0
	var r: float = STEP
	while r <= max_radius:
		var samples: int = max(10, int(r / STEP * TAU))
		for i in range(samples):
			var angle: float = float(i) / float(samples) * TAU
			var sx: float = origin.x + cos(angle) * r
			var sz: float = origin.y + sin(angle) * r
			if _mangrove_strength_at(nd, sx, sz) >= 0.60:
				return { "ok": true, "x": sx, "z": sz }
		r += STEP
	return { "ok": false }

## Tìm điểm thuộc bio băng giá (FROST) gần nhất theo vòng xoắn quanh (wx,wz).
## Dùng đúng nguồn sự thật `biome_at` (spawn-bias r²>800000, fx>0.55) để tele.
static func find_frost(wx: float, wz: float, max_radius: float = 25000.0) -> Dictionary:
	const DIM: int = _Data._Dim.DimensionID.REAL_WORLD
	var nd: Dictionary = _noise_for_dim(DIM)
	if nd.is_empty():
		return { "ok": false }
	var origin := Vector2(wx, wz)
	const STEP: float = 150.0
	var r: float = STEP
	while r <= max_radius:
		var samples: int = max(10, int(r / STEP * TAU))
		for i in range(samples):
			var angle: float = float(i) / float(samples) * TAU
			var sx: float = origin.x + cos(angle) * r
			var sz: float = origin.y + sin(angle) * r
			if _ocean_mask_at(nd, sx, sz):
				continue
			if biome_at(sx, sz, DIM) == _Data.TileType.FROST:
				return { "ok": true, "x": sx, "z": sz }
		r += STEP
	return { "ok": false }

## Tìm điểm thuộc rừng đầm lầy (SWAMP) gần nhất theo vòng xoắn quanh (wx,wz).
## Dùng đúng nguồn sự thật `biome_at` (spawn-bias r²>600000, sw>0.57) để tele.
static func find_swamp(wx: float, wz: float, max_radius: float = 25000.0) -> Dictionary:
	const DIM: int = _Data._Dim.DimensionID.REAL_WORLD
	var nd: Dictionary = _noise_for_dim(DIM)
	if nd.is_empty():
		return { "ok": false }
	var origin := Vector2(wx, wz)
	const STEP: float = 150.0
	var r: float = STEP
	while r <= max_radius:
		var samples: int = max(10, int(r / STEP * TAU))
		for i in range(samples):
			var angle: float = float(i) / float(samples) * TAU
			var sx: float = origin.x + cos(angle) * r
			var sz: float = origin.y + sin(angle) * r
			if _ocean_mask_at(nd, sx, sz):
				continue
			if biome_at(sx, sz, DIM) == _Data.TileType.SWAMP:
				return { "ok": true, "x": sx, "z": sz }
		r += STEP
	return { "ok": false }

## ── Creature bio bonus (level theo vùng sinh thái) ─────────────────────────
## Phân loại vùng sinh thái tại (wx,wz) rồi roll bonus level cho sinh vật spawn:
##   Biển 0..30, Sa mạc 10..15, Đồng bằng 0..5; Núi +5..10 CHỒNG lên trên đất
##   (núi nằm trong đồng bằng/sa mạc → cộng dồn, đúng ví dụ user:
##   slime ở ruộng lúa trên núi trong đồng bằng = 1 + 2 + đồng bằng + núi).
## Trả về { "bonus": int, "zones": Array[String] }.
static func roll_bio_bonus_at(wx: float, wz: float) -> Dictionary:
	const DIM: int = _Data._Dim.DimensionID.REAL_WORLD
	var nd: Dictionary = _noise_for_dim(DIM)
	var zones: Array[String] = []
	var bonus: int = 0
	if _ocean_mask_at(nd, wx, wz):
		bonus += randi_range(0, 30)
		zones.append("sea")
	else:
		var bio: int = biome_at(wx, wz, DIM)
		if bio == _Data.TileType.DESERT:
			bonus += randi_range(10, 15)
			zones.append("desert")
		else:
			bonus += randi_range(0, 5)
			zones.append("plain")
		var n_mt: FastNoiseLite = nd["mountain"]
		if n_mt:
			var mtn: float = (n_mt.get_noise_2d(wx, wz) + 1.0) * 0.5
			var mtn_t: float = clamp((mtn - 0.58) / 0.14, 0.0, 1.0)
			mtn_t = mtn_t * mtn_t * (3.0 - 2.0 * mtn_t)
			if mtn_t > 0.50:
				bonus += randi_range(5, 10)
				zones.append("mountain")
	return { "bonus": bonus, "zones": zones }

## Kiểm tra có quán rượu THẬT đã build tại world pos (chunk phải nằm trong cache).
## Dùng cho teleport "quán gần nhất" để chỉ nhắm vào quán đã được dựng.
static func is_tavern_built_at(wx: float, wz: float) -> bool:
	const SIZE: int = 32
	var half: float = SIZE * 0.5
	var cx: int = int(floor((wx + half) / SIZE))
	var cz: int = int(floor((wz + half) / SIZE))
	var ck: String = _cache_key(cx, cz, _Data._Dim.DimensionID.REAL_WORLD)
	if not _mesh_cache.has(ck):
		return false
	var vbd: Dictionary = (_mesh_cache[ck] as Dictionary).get("village_data", {})
	if not vbd.get("has", false):
		return false
	var bls: Array = vbd.get("info", {}).get("buildings", [])
	for b in bls:
		if absf(float(b.get("x", 0.0)) - wx) < 5.0 \
				and absf(float(b.get("z", 0.0)) - wz) < 5.0:
			return true
	return false

## Lấy các interior AABB (world space) của MỌI quán trong chunk chứa (wx,wz).
## Dùng cho teleport: xác định vị trí hạ cánh VỀ PHÍA NGOÀI để không rơi vào
## trong quán (shell bị fade 0.10 bởi _update_tavern_fade → chỉ còn nội thất
## rời rạc = trông như "đống hỗn"). AABB lấy từ _mesh_cache — đảm bảo chính
## xác dữ liệu quán thật đã được dựng.
static func tavern_interior_aabbs(wx: float, wz: float) -> Array:
	const SIZE: int = 32
	var half: float = SIZE * 0.5
	var cx: int = int(floor((wx + half) / SIZE))
	var cz: int = int(floor((wz + half) / SIZE))
	var ck: String = _cache_key(cx, cz, _Data._Dim.DimensionID.REAL_WORLD)
	if not _mesh_cache.has(ck):
		return []
	var vbd: Dictionary = (_mesh_cache[ck] as Dictionary).get("village_data", {})
	var out: Array = []
	for b in vbd.get("info", {}).get("buildings", []):
		out.append(_tavern_interior_aabb(b))
	return out

static func _point_in_aabb(p: Vector2, ab: Array) -> bool:
	var a0: Vector3 = ab[0]
	var a1: Vector3 = ab[1]
	return p.x >= a0.x and p.x <= a1.x and p.y >= a0.z and p.y <= a1.z

## Chọn điểm hạ cánh cho teleport quán: cách tâm quán 8m theo hướng `toward`
## (về phía đường), nhưng nếu điểm đó nằm TRONG interior AABB (chunk phải
## được build — gọi ensure_chunk_built trước) thì đẩy dần ra tới khi thoát.
## Trả về Vector2 world coords — không bao giờ tele thành "đống hỗn" vì fade.
static func tavern_landing_point(wx: float, wz: float, toward: Vector2) -> Vector2:
	var dir := toward
	if dir.length() < 0.1:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var aabbs: Array = tavern_interior_aabbs(wx, wz)
	var d: float = 8.0
	while d <= 32.0:
		var p := Vector2(wx, wz) + dir * d
		var blocked := false
		for ab in aabbs:
			if _point_in_aabb(p, ab):
				blocked = true
				break
		if not blocked:
			return p
		d += 2.0
	return Vector2(wx, wz) + dir * 8.0

# ── Registry chunk (tra cứu O(1)) ─────────────────────────────────────────────
# Thay cho việc đệ quy quét toàn bộ scene tree từng lần (gây lag 400ms khi
# máy kéo/thuyền đổi chunk). Đăng ký khi setup, gỡ khi PREDELETE.
static var _chunk_registry: Dictionary = {}

static func get_chunk(cx: int, cz: int, dim: int) -> Node:
	return _chunk_registry.get(_cache_key(cx, cz, dim))

static func _register_chunk(cx: int, cz: int, dim: int, node: Node) -> void:
	_chunk_registry[_cache_key(cx, cz, dim)] = node

static func _unregister_chunk(cx: int, cz: int, dim: int) -> void:
	_chunk_registry.erase(_cache_key(cx, cz, dim))

func setup(cx: int, cz: int, size: int,
		dimension_id: int = _Data._Dim.DimensionID.TWILIGHT, sync: bool = false,
		lod: bool = false) -> void:
	# Đồng bộ SeedSnapshot với WorldSeed hiện tại (main thread) — test/flow có
	# thể set WorldSeed.seed_value trực tiếp; worker chỉ đọc snapshot.
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	_cx = cx; _cz = cz; _size = size
	_dimension_id = dimension_id
	_is_lod = lod
	_was_setup = true
	_cols = int(_size / _Data.VOXEL)
	_tiles_per_chunk = int(_cols / _Data.TILE_W)
	_init_materials()
	_water_tick_timer = randf_range(0.0, 0.5)
	if not lod:
		WorldChunk._register_chunk(cx, cz, dimension_id, self)

	var ck: String = _cache_key(cx, cz, dimension_id)
	if not lod and _mesh_cache.has(ck):
		apply_chunk(_mesh_cache[ck])
		return
	if lod and _lod_mesh_cache.has(ck):
		apply_chunk(_lod_mesh_cache[ck])
		return

	if sync:
		apply_chunk(compute_chunk(cx, cz, size, dimension_id, true, lod))
		if not lod:
			call_deferred("_schedule_decorative_rebuild")
		return

	_pending_mutex.lock()
	_pending_chunks[ck] = self
	_pending_mutex.unlock()
	_gen_inc()
	_track_task(WorkerThreadPool.add_task(
		_thread_build.bind(ck, cx, cz, size, dimension_id, lod), true, "chunk"))

static func _thread_build(ck: String, cx: int, cz: int, size: int, dim_id: int, lod: bool) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id, false, lod)
	_pending_mutex.lock()
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	_pending_mutex.unlock()
	if chunk != null and is_instance_valid(chunk) and chunk.is_inside_tree():
		# Không apply_chunk trực tiếp — chỉ lưu data, manager promote 1 chunk/frame
		# để tránh nhiều worker hoàn thành cùng lúc → node-creation spike trên main
		chunk.call_deferred("_store_pending_data", data)
	_gen_dec()

func _store_pending_data(data: Dictionary) -> void:
	_pending_data = data

## ── compute_chunk: tạo block data + build mesh ───────────────────────────────
static func compute_chunk(cx: int, cz: int, size: int, dim_id: int,
		fast_mode: bool = false, lod_mode: bool = false) -> Dictionary:
	var cols: int = int(size / _Data.VOXEL)
	var world_ox: float = cx * size
	var world_oz: float = cz * size
	var half: float = size * 0.5
	var h_vox: float = _Data.VOXEL * 0.5

	# ── 1. Biome sampling (với padding để stitch biên) ─────────────────────────
	_prof_reset()
	var total: int = cols + 2 * _Data.PAD
	var bio: Array[Array] = []
	bio.resize(total)
	for vx in range(total):
		var row: Array = []; row.resize(total); bio[vx] = row
		for vz in range(total):
			var wx: float = world_ox - half + (float(vx - _Data.PAD) + 0.5) * _Data.VOXEL
			var wz: float = world_oz - half + (float(vz - _Data.PAD) + 0.5) * _Data.VOXEL
			row[vz] = _Noise._biome_at(wx, wz, dim_id)
	_prof("S1 biome_sample")

	# ── 2. BFS distance map từ "đất nền" → tính gradient xuống nước ─────────
	# Đa nguồn: ô đất nền=0, ô lân cận kề đất nền=1 → BFS 4-láng giềng.
	# REAL: không còn DARK_GRASS/GRASS (đất liền = GRASS_DIRT dùng trong land-branch).
	# TWILIGHT: đất nền = TWILIGHT_GRASS, còn lại (TWILIGHT_DIRT) là gradient nước.
	var base_tile: int = _Data.TileType.TWILIGHT_GRASS
	var edge_tile: int = _Data.TileType.TWILIGHT_DIRT
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		base_tile = _Data.TileType.GRASS_DIRT
		edge_tile = _Data.TileType.GRASS_DIRT
	var dst := PackedInt32Array()
	dst.resize(total * total)
	for i in range(total * total):
		dst[i] = 0 if bio[i / total][i % total] == base_tile else _Data.CONST_INF
	for vx in range(total):
		for vz in range(total):
			if bio[vx][vz] != edge_tile: continue
			if (vx > 0 and bio[vx-1][vz] == base_tile) \
			or (vx < total-1 and bio[vx+1][vz] == base_tile) \
			or (vz > 0 and bio[vx][vz-1] == base_tile) \
			or (vz < total-1 and bio[vx][vz+1] == base_tile):
				dst[vx * total + vz] = 1
	if base_tile != edge_tile:
		_bfs_manhattan(dst, total)
	_prof("S2 bfs_dst")


	# ── 3. biome_grid + height_grid: biển trước → lục địa → hồ ──────────────
	var biome_grid: Array[Array] = []
	biome_grid.resize(cols)
	var height_grid: Array[Array] = []
	height_grid.resize(cols)

	var beach_mask: PackedByteArray
	beach_mask.resize(cols * cols)
	beach_mask.fill(0)

	var reef_mask: PackedFloat32Array
	reef_mask.resize(cols * cols)
	reef_mask.fill(0.0)

	for ivx in range(cols):
		biome_grid[ivx] = []; biome_grid[ivx].resize(cols)
		height_grid[ivx] = []; height_grid[ivx].resize(cols)

	# dmask: ô thuộc vùng sa mạc (base_bio DESERT) — cấm môn ngọt ở sa mạc
	# theo đúng vùng, không lệ thuộc cửa sổ lân cận cục bộ (chính xác qua biên chunk).
	var dmask: PackedByteArray = PackedByteArray()
	dmask.resize(total * total)
	dmask.fill(0)

	var nd: Dictionary = {}
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		nd = _Noise._noise_for_dim(dim_id)
		var n_lake: FastNoiseLite      = nd["lake"]
		var n_lake_type: FastNoiseLite = nd["lake_type"]

		# ── Ocean mask (BFS padded) — stride 2, ~75% fewer noise calls ─────────
		const OCEAN_PAD: int = 26
		var oct_total: int = cols + 2 * OCEAN_PAD
		var oct: Array[Array] = []
		oct.resize(oct_total)
		for pvx in range(oct_total):
			oct[pvx] = []; oct[pvx].resize(oct_total)
		for pvx in range(0, oct_total, 2):
			for pvz in range(0, oct_total, 2):
				var wx: float = world_ox - half + (float(pvx - OCEAN_PAD) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(pvz - OCEAN_PAD) + 0.5) * _Data.VOXEL
				oct[pvx][pvz] = _ocean_mask_at(nd, wx, wz)
		# Fill odd indices by copying nearest computed neighbor
		for pvx in range(0, oct_total, 2):
			for pvz in range(0, oct_total, 2):
				var val: bool = oct[pvx][pvz]
				if pvx + 1 < oct_total: oct[pvx + 1][pvz] = val
				if pvz + 1 < oct_total: oct[pvx][pvz + 1] = val
				if pvx + 1 < oct_total and pvz + 1 < oct_total:
					oct[pvx + 1][pvz + 1] = val

		var oct_small: Array[Array] = []
		oct_small.resize(total)
		for pvx in range(total):
			oct_small[pvx] = []; oct_small[pvx].resize(total)
			for pvz in range(total):
				oct_small[pvx][pvz] = oct[pvx + OCEAN_PAD - _Data.PAD][pvz + OCEAN_PAD - _Data.PAD]

		const OCEAN_BUFFER: int = 45
		var odst := PackedInt32Array()
		odst.resize(total * total)
		for i in range(total * total):
			odst[i] = 0 if oct_small[i / total][i % total] else _Data.CONST_INF
		_bfs_manhattan(odst, total)

		var shore_dst := PackedInt32Array()
		shore_dst.resize(total * total)
		var oct_mask := PackedByteArray()
		oct_mask.resize(total * total)
		for pvx in range(total):
			for pvz in range(total):
				var is_oc: bool = oct_small[pvx][pvz]
				oct_mask[pvx * total + pvz] = 1 if is_oc else 0
				if is_oc:
					var adj_land: bool = false
					if pvx > 0 and not oct_small[pvx-1][pvz]: adj_land = true
					elif pvx < total-1 and not oct_small[pvx+1][pvz]: adj_land = true
					elif pvz > 0 and not oct_small[pvx][pvz-1]: adj_land = true
					elif pvz < total-1 and not oct_small[pvx][pvz+1]: adj_land = true
					shore_dst[pvx * total + pvz] = 1 if adj_land else _Data.CONST_INF
				else:
					shore_dst[pvx * total + pvz] = _Data.CONST_INF
		_bfs_manhattan(shore_dst, total, oct_mask)
		_prof("S3 ocean_mask+bfs")

		# ── Single pass: biển → bãi biển → lục địa (có hồ) ────────────────
		const MAX_OCEAN_DEPTH_DIST: int = 30
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				var base_bio: int = bio[pvx][pvz]
				var od: int = odst[pvx * total + pvz]

				if od == 0:
					biome_grid[ivx][ivz] = _Data.TileType.OCEAN_DEEP
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var sd: int = shore_dst[pvx * total + pvz]
					if sd == _Data.CONST_INF: sd = MAX_OCEAN_DEPTH_DIST
					var raw_depth_t: float = clamp(float(sd - 1) / float(MAX_OCEAN_DEPTH_DIST - 1), 0.0, 1.0)

					# 3 chế độ địa hình: thềm → sườn → đồng bằng sâu
					var shelf_var: float = nd["sea_large"].get_noise_2d(wx * 0.5, wz * 0.5) * 0.08
					var shelf_end: float = 0.12 + shelf_var
					var slope_end: float = 0.32 + shelf_var * 0.5

					var base_h: float
					if raw_depth_t < shelf_end:
						var st: float = raw_depth_t / shelf_end
						base_h = lerp(-0.3, -1.5, st)
					elif raw_depth_t < slope_end:
						var st: float = (raw_depth_t - shelf_end) / max(slope_end - shelf_end, 0.01)
						st = st * st  # dốc tăng dần
						base_h = lerp(-1.5, -5.0, st)
					else:
						var st: float = (raw_depth_t - slope_end) / max(1.0 - slope_end, 0.01)
						base_h = lerp(-5.0, -8.5, st)

					# Cấu trúc lớn: sống núi, bồn trũng (amplitude tăng theo depth)
					var large_n: float = nd["sea_large"].get_noise_2d(wx, wz)
					base_h += large_n * (0.15 + raw_depth_t * 1.2)

					# Núi ngầm (Seamount) — núi lửa ngầm cao vút, xuất hiện khắp nơi
					var mt_n: float = nd["sea_mountain"].get_noise_2d(wx * 0.5, wz * 0.5)
					var mt_h: float = max(0.0, mt_n) * 8.0
					base_h += mt_h

					# Hẻm núi (canyon) — rãnh cắt vào thềm/sườn lục địa
					var c1: float = nd["sea_rough"].get_noise_2d(wx * 3.0, wz * 0.35)
					if c1 > 0.40:
						var c_h: float = (c1 - 0.40) / 0.60
						var c2: float = nd["sea_rough"].get_noise_2d(wx * 0.35, wz * 3.0)
						if c2 > 0.40:
							c_h = max(c_h, (c2 - 0.40) / 0.60)
						base_h -= c_h * c_h * (0.4 + raw_depth_t * 0.8)

					# Nhấp nhô tầm trung: mạnh ở vùng thềm/sườn, nhẹ ở đồng bằng
					var rough_n: float = nd["sea_rough"].get_noise_2d(wx, wz)
					var rough_scale: float = 1.0 - raw_depth_t * 0.6  # gần bờ gồ ghề hơn
					base_h += rough_n * 0.25 * rough_scale

					# Khe rãnh hẹp (trench) — vực sâu hiếm gặp
					var trench_n: float = nd["sea_rough"].get_noise_2d(wx * 4.0, wz * 0.5)
					var trench_t: float = clamp((abs(trench_n) - 0.55) / 0.25, 0.0, 1.0)
					var trench_mask: float = trench_t * trench_t * (3.0 - 2.0 * trench_t)
					base_h -= trench_mask * (0.3 + raw_depth_t * 1.0)

					# Bãi đá ngầm (Reef) — đá nhô cao rải rác khắp đáy biển
					var rf_n: float = (nd["reef"].get_noise_2d(wx, wz) + 1.0) * 0.5
					if rf_n > 0.40:
						var rf_h: float = (rf_n - 0.40) / 0.60
						rf_h = rf_h * 4.0
						base_h += rf_h
						reef_mask[ivx * cols + ivz] = rf_h * 0.3

					# Chặn không trồi lên quá mặt nước
					height_grid[ivx][ivz] = min(base_h, _Data.WATER_Y - 0.1)
				elif od <= _Data.BEACH_WIDTH:
					var beach_t: float = float(od - 1) / float(maxi(_Data.BEACH_WIDTH - 1, 1))
					biome_grid[ivx][ivz] = _Data.TileType.SAND_WHITE
					var wx2: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz2: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var warp_n: float = (nd["warp"].get_noise_2d(wx2 * 3.0, wz2 * 3.0) + 1.0) * 0.5
					var noise_offset: float = (warp_n - 0.5) * 0.3
					height_grid[ivx][ivz] = clamp(
						lerp(_Data.WATER_Y, _Data.VOXEL - 0.15, beach_t) + noise_offset,
						_Data.WATER_Y - 0.1, _Data.VOXEL - 0.08)
					beach_mask[ivx * cols + ivz] = 1
				else:
					# ── LỤC ĐỊA: ĐỊA HÌNH DÙNG CHUNG TRƯỚC, BIOME VẼ SAU ─────────
					# Mọi biome đất liền dùng CHUNG một công thức địa hình đồi
					# thoải (highland + highland_terr). Biome chỉ thay đổi "sơn bề
					# mặt" (loại block) chứ không can thiệp chiều cao → không còn
					# vết cắt cao độ tại ranh giới biome/biên chunk. (Biome nào
					# cần địa hình đặc biệt sẽ được code riêng ở cập nhật sau.)
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL

					# (1) Địa hình chung — đồi thoải rolling hills
					var hb: float = (nd["highland"].get_noise_2d(wx, wz) + 1.0) * 0.5
					var ht: float = (nd["highland_terr"].get_noise_2d(wx, wz) + 1.0) * 0.5
					var hb_rise: float = clamp((hb - 0.55) / 0.35, 0.0, 1.0)
					hb_rise = hb_rise * hb_rise * (3.0 - 2.0 * hb_rise)
					height_grid[ivx][ivz] = 1.0 + hb_rise * 3.0 + ht * hb_rise * 1.2
					# (1b) Vùng trũng (basin) — lòng chảo hạ thấp cục bộ trong đất
					# liền: vùng bát nhỏ mềm, mép thoải (smoothstep). Đáy được giữ
					# TRÊN mực nước để không tự sinh nước/phá đồng cỏ khô.
					# Noise tần thấp nên trũng âm lan rộng; nhiều trũng nông.
					var bsn: float = (nd["basin"].get_noise_2d(wx, wz) + 1.0) * 0.5
					var bsn_t: float = clamp((bsn - 0.55) / 0.20, 0.0, 1.0)
					bsn_t = bsn_t * bsn_t * (3.0 - 2.0 * bsn_t)
					if bsn_t > 0.0:
						height_grid[ivx][ivz] = maxf(height_grid[ivx][ivz] - bsn_t * 1.5, _Data.WATER_Y + 0.35)

					# (1c) Vùng NÚI VỪA — đắp cao 4..9 block trên nền đồi, ranh mềm
					# (smoothstep theo noise "mountain") để tạo dải núi rộng, đỉnh
					# không cắt thẳng.
					var mtn: float = (nd["mountain"].get_noise_2d(wx, wz) + 1.0) * 0.5
					var mtn_t: float = clamp((mtn - 0.58) / 0.14, 0.0, 1.0)
					mtn_t = mtn_t * mtn_t * (3.0 - 2.0 * mtn_t)
					if mtn_t > 0.0:
						var mtn_amp: float = 3.5 + ht * 5.5   # 3.5..9.0
						height_grid[ivx][ivz] += mtn_t * mtn_amp

# (2) Vẽ biome SAU — chỉ đổi surface, không đổi height
					if base_bio == _Data.TileType.DESERT:
						# ── SA MẠC: chỉ toàn CÁT các loại (không đất nâu) ────────
						#   - Mặt cát nền (DESERT) + cồn cát đậm (SAND_DEEP) rải theo
						#     độ nhô; ranh giới giữa 2 loại UỐN CONG bởi noise + dải
						#     loang (giống hiệu ứng cỏ non ở đồng):
						#       hb_rise thấp    → DESERT (cát sáng nền)
						#       hb_rise cao 	→ SAND_DEEP (cát đậm đỉnh cồn)
						#     Khoảng 0.52→0.66: SAND_DEEP loang dần (noise nhanh,
						#     đốm mật độ tăng theo độ cao) — không cắt thẳng.
						var warp_d: float = (nd["patch_var"].get_noise_2d(wx, wz) - 0.5) * 0.10
						var eff_d: float = hb_rise + warp_d
						var sd_t: float = clamp((eff_d - 0.56) / 0.10, 0.0, 1.0)
						if sd_t >= 1.0:
							biome_grid[ivx][ivz] = _Data.TileType.SAND_DEEP
						elif sd_t > 0.0:
							var loang_d: float = (nd["highland_terr"].get_noise_2d(wx * 3.0 + 5.0, wz * 3.0 + 5.0) + 1.0) * 0.5
							biome_grid[ivx][ivz] = _Data.TileType.SAND_DEEP if loang_d < sd_t else _Data.TileType.DESERT
						else:
							# Nền thấp sa mạc: đốm NHỎ — cồn cát đậm (SAND_DEEP) và cát
							# phai mờ (PALE_SAND) lỏng nền cát sáng (DESERT). patch2 tần
							# số cao → đốm rải rác vừa phải, không thành mảng gây rối.
							var p2: float = (nd["patch2"].get_noise_2d(wx, wz) + 1.0) * 0.5
							if p2 > 0.82:
								biome_grid[ivx][ivz] = _Data.TileType.SAND_DEEP
							elif p2 > 0.72:
								biome_grid[ivx][ivz] = _Data.TileType.PALE_SAND
							else:
								biome_grid[ivx][ivz] = _Data.TileType.DESERT
					elif base_bio == _Data.TileType.FROST:
						# ── BĂNG GIÁ: vùng tuyết lạnh ─────────────────────────
						# Địa hình dùng CHUNG (đồi thoải) như mọi biome đất liền.
						# Sơn bề mặt: FROST (tuyết nền), FROST_SNOW (đốm tuyết dày
						# theo patch2). Hồ nội địa vẫn là nước thường (SILT/MUDDY_SAND)
						# carve xuống mực nước như hồ đồng cỏ — nước KHÔNG đóng băng.
						var is_frost_ocean: bool = oct[ivx + OCEAN_PAD][ivz + OCEAN_PAD]
						var lake_f: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
						if not is_frost_ocean and lake_f > 0.68 \
								and (od == _Data.CONST_INF or od > 40):
							var lake_type_f: float = (n_lake_type.get_noise_2d(wx, wz) + 1.0) * 0.5
							if lake_type_f > 0.50:
								biome_grid[ivx][ivz] = _Data.TileType.SILT
							else:
								biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
							height_grid[ivx][ivz] = _Data.WATER_Y - (1.0 + (lake_f - 0.68) * 8.0)
						else:
							var p2_f: float = (nd["patch2"].get_noise_2d(wx, wz) + 1.0) * 0.5
							if p2_f > 0.78:
								biome_grid[ivx][ivz] = _Data.TileType.FROST_SNOW
							else:
								biome_grid[ivx][ivz] = _Data.TileType.FROST
					elif base_bio == _Data.TileType.SWAMP:
						# ── RỪNG ĐẦM LẦY: đầm lầy ngập nước nông ──────────────────
						# Địa hình KHÔNG dùng chung đồi thoải: hạ dần xuống sát mực
						# nước (WATER_Y ±) → bãi lầy ngập/nổi xen kẽ. Bề mặt bùn
						# sình (SWAMP_MUD); mô bùn cao khô ráo (SWAMP_DIRT) chỗ
						# swamp_terr cao; hố thấp hơn mặt nước thành vũng nước đen
						# (nước vẫn fill theo WATER_Y — đầm lầy có nước đứng).
						# Blending biên theo swamp noise: rìa đầm (sw vừa qua ngưỡng)
						# vẫn giữ địa hình đồi dần lún xuống, lõi đầm (sw cao) dẹt
						# bằng mặt nước → ranh giới không còn vách đứng.
						var sw_v: float = (nd["swamp"].get_noise_2d(wx, wz) + 1.0) * 0.5
						var sw_terr: float = (nd["swamp_terr"].get_noise_2d(wx, wz) + 1.0) * 0.5
						var sw_t: float = clamp((sw_v - 0.57) / 0.22, 0.0, 1.0)
						sw_t = sw_t * sw_t * (3.0 - 2.0 * sw_t)
						var orig_h: float = height_grid[ivx][ivz]
						# Hạ nền bãi lầy xuống sát mực nước → vũng nước đen HIỆN RÕ
						# khắp đầm (trước đây nền +0.30 cao hơn mực nước nên khó thấy hồ).
						var swamp_flat: float = _Data.WATER_Y + 0.10 + (sw_terr - 0.5) * 2.0
						# Hồ đầm lầy — carve sâu thành vũng nước đứng; ngưỡng n_lake THẤP
						# hơn hồ đồng cỏ (0.58) → số lượng hồ ở đầm lầy nhiều hơn hẳn.
						var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
						if lv > 0.58:
							swamp_flat = _Data.WATER_Y - (1.1 + (lv - 0.58) * 7.0)
						height_grid[ivx][ivz] = lerp(orig_h, swamp_flat, sw_t)
						# Vũng ngập: mực nước đứng trên bùn; chỉ mô cao mới nhô lên
						if swamp_flat <= _Data.WATER_Y:
							biome_grid[ivx][ivz] = _Data.TileType.SWAMP_MUD
						elif sw_terr > 0.66:
							biome_grid[ivx][ivz] = _Data.TileType.SWAMP_DIRT
						else:
							biome_grid[ivx][ivz] = _Data.TileType.SWAMP_MUD
					else:
						# ── ĐỒNG BẰNG CỎ: block phân theo HÌNH THẾ địa hình ──
						#   - Sát bãi biển (cách bờ ≤6) → cỏ ven biển (100% GRASS)
						#   - Trũng thấp (hb_rise nhỏ)  → DARK_GRASS (ẩm mát)
						#   - Đồi cao (hb_rise ≥ 0.52) → YOUNG_GRASS, ranh giới uốn cong theo noise
#     + dải loang 0.56→0.68 (cỏ non loang xuống vài block, không cắt thẳng)
						#   - Sườn thoải → GRASS; nền giữa → GRASS_DIRT
						#   - Cụm đất trống/cỏ rậm theo noise "patch_var" (tần thấp)
						var is_ocean: bool = oct[ivx + OCEAN_PAD][ivz + OCEAN_PAD]
						var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
						if not is_ocean and lake_val > 0.68 and (od == _Data.CONST_INF or od > 40):
							var lake_type_val: float = (n_lake_type.get_noise_2d(wx, wz) + 1.0) * 0.5
							if lake_type_val > 0.50:
								biome_grid[ivx][ivz] = _Data.TileType.SILT
							else:
								biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
							# Hồ carve — nước thấp hơn mặt đất đồng
							height_grid[ivx][ivz] = _Data.WATER_Y - (1.0 + (lake_val - 0.68) * 8.0)
						elif od <= _Data.BEACH_WIDTH + 6:
							# Dải bờ khô gần biển: đất cát pha ẩm chuyển dần ra cỏ
							if od <= _Data.BEACH_WIDTH + 2:
								biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
							else:
								biome_grid[ivx][ivz] = _Data.TileType.GRASS
						elif hb_rise < 0.20:
							# Trũng ẩm nội địa — cỏ đậm, giữ hơi ẩm. Vùng đất THẤP
							# có BÃI ĐẤT LỚN (đất thổ) theo noise tần rất thấp
							# (n_patch_dirt): 1 vùng đất rộng hàng chục ô trộn NHIỀU
							# loại đất như DIRT/GRASS_DIRT/YOUNG_GRASS/DARK_GRASS.
							# Không còn bãi đá (STONE_PATCH) lởm chởm trên mặt đất.
							var df_low: float = (nd["patch_dirt"].get_noise_2d(wx, wz) + 1.0) * 0.5
							if df_low > 0.55:
								_soil_field_block(ivx, ivz, wx, wz, nd, biome_grid)
							else:
								biome_grid[ivx][ivz] = _Data.TileType.DARK_GRASS
						elif hb_rise >= 0.52:
							# ── ĐỒI CỎ / ĐỈNH: YOUNG_GRASS nhưng KHÔNG cắt thẳng ──
							# Ranh giới bị uốn cong bởi noise (warp) → mép đồi lượn
							# theo địa hình chứ không chạy đúng theo một độ cao cố định.
							# Từ chân đồi 0.56 lên đỉnh 0.68 có dải LOANG: cỏ non chỉ
							# xuất hiện ở những chỗ "đủ cao" (noise < yg_t) → rìa đồi
							# thưa đốm cỏ non, lên cao dày dần — chuyển mềm vài block.
							var warp_v: float = (nd["patch_var"].get_noise_2d(wx, wz) - 0.5) * 0.10
							var eff_h: float = hb_rise + warp_v
							var yg_t: float = clamp((eff_h - 0.56) / 0.12, 0.0, 1.0)
							if yg_t >= 1.0:
								biome_grid[ivx][ivz] = _Data.TileType.YOUNG_GRASS
							elif yg_t > 0.0:
								# Dải loang: noise tần nhanh làm đốm, mật độ theo độ cao
								var loang: float = (nd["highland_terr"].get_noise_2d(wx * 3.0 + 5.0, wz * 3.0 + 5.0) + 1.0) * 0.5
								biome_grid[ivx][ivz] = _Data.TileType.YOUNG_GRASS if loang < yg_t else _Data.TileType.GRASS
							else:
								biome_grid[ivx][ivz] = _Data.TileType.GRASS
						elif hb_rise < 0.45:
							# Sườn thoải — cỏ xanh tươi mượt; vài đốm cỏ già (vàng rạ)
							# loang theo patch2 (tần số cao) để không thành mảng lớn.
							var p2_s: float = (nd["patch2"].get_noise_2d(wx, wz) + 1.0) * 0.5
							if p2_s > 0.84:
								biome_grid[ivx][ivz] = _Data.TileType.DRY_GRASS
							else:
								biome_grid[ivx][ivz] = _Data.TileType.GRASS
						else:
							# Nền giữa — đồng cỏ hỗn; BÃI ĐẤT LỚN theo n_patch_dirt
							# (tần rất thấp → vùng đất thổ rộng hàng chục ô) trộn
							# nhiều loại đất; ngoài bãi là cỏ già / cỏ thưa loang theo
							# patch_var để vùng đồng bằng có những mảng đất thật.
							var dv3: float = (nd["patch_dirt"].get_noise_2d(wx, wz) + 1.0) * 0.5
							if dv3 > 0.54:
								_soil_field_block(ivx, ivz, wx, wz, nd, biome_grid)
								continue
							var dv2: float = (nd["patch_var"].get_noise_2d(wx, wz) + 1.0) * 0.5
							var p2_n: float = (nd["patch2"].get_noise_2d(wx, wz) + 1.0) * 0.5
							if dv2 > 0.62:
								biome_grid[ivx][ivz] = _Data.TileType.DIRT
							elif dv2 < 0.22:
								biome_grid[ivx][ivz] = _Data.TileType.DARK_GRASS
							elif p2_n > 0.88:
								biome_grid[ivx][ivz] = _Data.TileType.YOUNG_GRASS
							elif p2_n > 0.80:
								biome_grid[ivx][ivz] = _Data.TileType.DRY_GRASS
							elif p2_n < 0.16:
								biome_grid[ivx][ivz] = _Data.TileType.SPARSE_GRASS
							else:
								biome_grid[ivx][ivz] = _Data.TileType.GRASS_DIRT
					# Đỉnh núi cao (sau khi biome paint xong) → bề mặt đá lộ thiên
					if mtn_t > 0.62 and _Data.is_grass_tile(biome_grid[ivx][ivz]):
						biome_grid[ivx][ivz] = _Data.TileType.STONE_PATCH

		# ── 3a1b. MANGROVE — rừng ngập mặn intertidal dọc bờ biển ────────────
		# Vệt bùn triều chạy 2 bên mực nước: thềm bùn ngập ăn ra biển, bãi bùn
		# ăn vào đất liền vài block. Độ cao kéo về mực triều (WATER_Y) → bãi
		# bùn ngập/nổi xen kẽ theo noise; chỗ terr cao thành mô bùn khô ráo.
		const MANGROVE_SEA_RANGE: float = 20.0   # ăn ra thềm biển (bùn ngập)
		const MANGROVE_LAND_RANGE: float = 19.0  # ăn sâu vào đất liền (bãi bùn)
		const MANGROVE_STRENGTH: float = 0.33    # ngưỡng trở thành rừng đước
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				var mg: float = (nd["mangrove"].get_noise_2d(wx, wz) + 1.0) * 0.5
				var mg_mask: float = clamp((mg - 0.42) / 0.28, 0.0, 1.0)
				if mg_mask <= 0.0: continue
				var is_oc: bool = oct_small[pvx][pvz]
				var pos: float
				if is_oc:
					var sd: int = shore_dst[pvx * total + pvz]
					if sd == _Data.CONST_INF: continue
					pos = -float(sd)
				else:
					pos = float(odst[pvx * total + pvz] - 1)
				var t_edge: float = clamp(-pos / MANGROVE_SEA_RANGE, 0.0, 1.0) if pos < 0.0 \
					else clamp(pos / MANGROVE_LAND_RANGE, 0.0, 1.0)
				var strength: float = mg_mask * (1.0 - t_edge)
				if strength < MANGROVE_STRENGTH: continue
				var inner: float = (nd["mangrove_inner"].get_noise_2d(wx, wz) + 1.0) * 0.5
				var terr: float = (nd["mangrove_terr"].get_noise_2d(wx, wz) + 1.0) * 0.5
				biome_grid[ivx][ivz] = _Data.TileType.MANGROVE_MUD
				if is_oc:
					# Thềm bùn ngập: đáy nông gần mặt nước; chỗ terr cao nổi mô bùn
					height_grid[ivx][ivz] = min(
						lerp(_Data.WATER_Y - 1.15, _Data.WATER_Y + 0.65, terr) + inner * 0.3,
						_Data.WATER_Y + 0.9)
				else:
					# Bãi bùn lục địa: hạ xuống mực triều, lạch nước ngập xen kẽ
					height_grid[ivx][ivz] = lerp(_Data.WATER_Y - 0.5, _Data.WATER_Y + 0.95, terr) + inner * 0.35

		# ── 3a2. Hồ ĐỒNG CỎ: đáy thoải theo khoảng cách từ bờ (BFS padded,
		# hàn liền qua biên chunk; ring 0 = WATER_Y như hồ cát dựa trên dst) ──
		var lake_mask: PackedByteArray = PackedByteArray()
		lake_mask.resize(total * total)
		lake_mask.fill(0)
		for pvx in range(total):
			for pvz in range(total):
				if bio[pvx][pvz] == _Data.TileType.DESERT:
					dmask[pvx * total + pvz] = 1
				if bio[pvx][pvz] != _Data.TileType.GRASS_DIRT: continue
				if oct[pvx + OCEAN_PAD - _Data.PAD][pvz + OCEAN_PAD - _Data.PAD]: continue
				var wx: float = world_ox - half + (float(pvx - _Data.PAD) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(pvz - _Data.PAD) + 0.5) * _Data.VOXEL
				var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
				var odv: int = odst[pvx * total + pvz]
				if lv > 0.68 and (odv == _Data.CONST_INF or odv > 40):
					lake_mask[pvx * total + pvz] = 1
		var ldist: PackedInt32Array = PackedInt32Array()
		ldist.resize(total * total)
		ldist.fill(-1)
		var frontier: Array[Vector2i] = []
		for pvx in range(total):
			for pvz in range(total):
				if lake_mask[pvx * total + pvz] == 0: continue
				var touching_land := false
				for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = pvx + d4.x
					var nz: int = pvz + d4.y
					if nx < 0 or nx >= total or nz < 0 or nz >= total: continue
					if lake_mask[nx * total + nz] == 0:
						touching_land = true
						break
				if touching_land:
					ldist[pvx * total + pvz] = 0
					frontier.append(Vector2i(pvx, pvz))
		var fhead := 0
		while fhead < frontier.size():
			var c: Vector2i = frontier[fhead]
			fhead += 1
			var cd: int = ldist[c.x * total + c.y] + 1
			for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = c.x + d4.x
				var nz: int = c.y + d4.y
				if nx < 0 or nx >= total or nz < 0 or nz >= total: continue
				if lake_mask[nx * total + nz] == 0: continue
				if ldist[nx * total + nz] != -1: continue
				ldist[nx * total + nz] = cd
				frontier.append(Vector2i(nx, nz))
		for ivx in range(cols):
			for ivz in range(cols):
				var pvx: int = ivx + _Data.PAD
				var pvz: int = ivz + _Data.PAD
				if lake_mask[pvx * total + pvz] == 0: continue
				var sd: float = minf(float(ldist[pvx * total + pvz]), float(_Data.PAD)) * _BlockData.SLAB_HEIGHT
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
				height_grid[ivx][ivz] = _Data.WATER_Y - minf(1.0 + (lv - 0.68) * 8.0, sd)

	else:
		# ── Non-REAL_WORLD: giữ logic cũ ────────────────────────────────────
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				biome_grid[ivx][ivz] = bio[pvx][pvz]
				if bio[pvx][pvz] == _Data.TileType.TWILIGHT_GRASS:
					height_grid[ivx][ivz] = _Data.VOXEL
				else:
					var d: int = dst[pvx * total + pvz]
					if d == _Data.CONST_INF: d = _Data.PAD
					height_grid[ivx][ivz] = _Data.WATER_Y - min(d, _Data.PAD) * _Data.VOXEL
	_prof("S4 biome_grid+height")


	# ── 3b. River override ────────────────────────────────────────────────────
	var river_flag: PackedByteArray = PackedByteArray()
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		_ensure_river_noise()
		river_flag.resize(cols * cols)
		var orig_heights: Array[Array] = []
		orig_heights.resize(cols)
		for ivx in range(cols):
			orig_heights[ivx] = []; orig_heights[ivx].resize(cols)
			for ivz in range(cols):
				orig_heights[ivx][ivz] = height_grid[ivx][ivz]
		for ivx in range(cols):
			for ivz in range(cols):
				var bg: int = biome_grid[ivx][ivz]
				if bg == _Data.TileType.OCEAN_DEEP:
					continue
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				var factor: float = _River.river_distance_factor(wx, wz)
				if factor >= 0.0:
					var orig_h: float = height_grid[ivx][ivz]
					var bottom_var: float = _river_noise.get_noise_2d(wx * 0.5, wz * 0.5) * 1.5 * _BlockData.SLAB_HEIGHT
					var deep_h: float = _Data.WATER_Y - 6.0 * _BlockData.SLAB_HEIGHT + bottom_var
					var t: float = clamp(factor, 0.0, 1.0)
					t = t * t * (3.0 - 2.0 * t)
					if orig_h <= _Data.WATER_Y:
						height_grid[ivx][ivz] = lerp(deep_h, orig_h, t)
					else:
						height_grid[ivx][ivz] = lerp(deep_h, max(orig_h, _Data.WATER_Y - 0.1), t)
					if t < 0.4:
						var bed_n: float = (_river_bed_noise.get_noise_2d(wx * 1.5, wz * 1.5) + 1.0) * 0.5
						if bed_n < 0.25:
							biome_grid[ivx][ivz] = _Data.TileType.SAND
						elif bed_n < 0.55:
							biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
						else:
							biome_grid[ivx][ivz] = _Data.TileType.SILT
					else:
						biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
					river_flag[ivx * cols + ivz] = 1
		# Flatten river banks at lake boundary
		var dirs4: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		for ivx in range(cols):
			for ivz in range(cols):
				if river_flag[ivx * cols + ivz] == 0:
					continue
				if height_grid[ivx][ivz] <= _Data.WATER_Y:
					continue
				var adjacent_to_lake: bool = false
				for d in dirs4:
					var nx: int = ivx + d.x
					var nz: int = ivz + d.y
					if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
						continue
					if orig_heights[nx][nz] <= _Data.WATER_Y and height_grid[nx][nz] <= _Data.WATER_Y:
						adjacent_to_lake = true
						break
				if adjacent_to_lake:
					height_grid[ivx][ivz] = _Data.WATER_Y - 0.1
					biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
	_prof("S5 river")


	var road_grid: PackedByteArray
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		road_grid.resize(cols * cols)
		road_grid.fill(0)
		_Road.paint_road_grid(road_grid, cols, size, cx, cz)
		for ivx in range(cols):
			for ivz in range(cols):
				if biome_grid[ivx][ivz] == _Data.TileType.OCEAN_DEEP:
					road_grid[ivx * cols + ivz] = 0
				elif river_flag[ivx * cols + ivz] == 1:
					road_grid[ivx * cols + ivz] = 0
				elif biome_grid[ivx][ivz] == _Data.TileType.SWAMP \
						or biome_grid[ivx][ivz] == _Data.TileType.SWAMP_MUD \
						or biome_grid[ivx][ivz] == _Data.TileType.SWAMP_DIRT:
					road_grid[ivx * cols + ivz] = 0
	_prof("S6a road_grid")

	# ── LOD MODE: dừng sau height/biome/river/road → mesh THÔ ─────────────────
	# Chunk xa chỉ cần hình dáng mặt đất: quads thô theo `step`, không block
	# data, không nước/cỏ/props/làng/quặng/đèn/shaped. Bỏ luôn BFS + fill_blocks
	# → worker xử lý nhanh hơn hẳn, main chỉ dựng 1 MeshInstance3D.
	if lod_mode:
		var st_lod := SurfaceTool.new()
		st_lod.begin(Mesh.PRIMITIVE_TRIANGLES)
		_Terrain.build_lod_mesh(st_lod, biome_grid, height_grid, road_grid, cols, dim_id)
		return {
			"lod": true,
			"mesh": st_lod.commit(),
			"biome_grid": biome_grid,
			"height_grid": height_grid,
			"river_flag": river_flag,
			"road_grid": road_grid,
			"cols": cols,
			"block_data_bytes": PackedByteArray(),
			"has_water": false, "has_lava": false, "has_ores": false,
			"village_data": { "has": false, "xforms": [], "colors": [], "info": {} },
			"plant_props": [], "lamp_positions": [],
			"lotus_lights": [] as Array[Vector3],
			"grass_blade_data": {},
			"top_ly_hint": PackedInt32Array(),
			"stone_patch_mask": PackedByteArray(),
			"shaped_mesh": null, "shaped_pos": [], "shaped_size": [],
		}

	# ── 4b. BFS bán kính Chebyshev: nước / đường / đất sa mạc ────────────────
	# Thay các cửa sổ quét 7×7 lặp lại cho cỏ, cây, môn ngọt bằng tra O(1).
	var wdist := PackedInt32Array()
	var rdist := PackedInt32Array()
	var dland := PackedInt32Array()
	var hdist := PackedInt32Array()
	wdist.resize(cols * cols); wdist.fill(-1)
	rdist.resize(cols * cols); rdist.fill(-1)
	dland.resize(cols * cols); dland.fill(-1)
	hdist.resize(cols * cols); hdist.fill(-1)
	for vx in range(cols):
		for vz in range(cols):
			var i2: int = vx * cols + vz
			if height_grid[vx][vz] <= _Data.WATER_Y:
				wdist[i2] = 0
			if road_grid.size() > 0 and road_grid[i2] != 0:
				rdist[i2] = 0
			if biome_grid[vx][vz] == _Data.TileType.DESERT and height_grid[vx][vz] > _Data.WATER_Y:
				dland[i2] = 0
			# Sườn dốc (chân núi/đồi): ô có chênh cao ≥ ngưỡng với ô kề 8-hướng
			# → seed cho BFS hdist. Cỏ lúa được phép mọc thêm vùng này (dưới đồi).
			var h0: float = height_grid[vx][vz]
			for dq in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var qx: int = vx + dq[0]
				var qz: int = vz + dq[1]
				if qx < 0 or qz < 0 or qx >= cols or qz >= cols:
					continue
				if absf(height_grid[qx][qz] - h0) >= _Data.VOXEL * 0.75:
					hdist[i2] = 0
					break
	_bfs_chebyshev(wdist, cols)
	_prof("S6b bfs_water")
	_bfs_chebyshev(rdist, cols)
	_prof("S6c bfs_road")
	_bfs_chebyshev(dland, cols)
	_bfs_chebyshev(hdist, cols)
	_prof("S6 road+bfs4x")


# ── 5. Tạo ChunkBlockData từ biome + height ────────────────────────────────
	var bd := _BlockData.new()
	bd.init(cols, cols)
	_Terrain.fill_blocks(bd, biome_grid, height_grid, road_grid, cols, dim_id, cx, cz, size, nd, reef_mask)

	# ── 5b. Đồi quặng trên bề mặt — chỉ khu vực xa spawn (deterministic) ─────
	var ore_hill_info: Dictionary = { "cx": -1, "cz": -1 }
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		ore_hill_info = _Terrain.spawn_ore_hills(bd, biome_grid, height_grid, road_grid,
				cols, cx, cz, size)
	_prof("S7 fill_blocks+ore")

	# ── 6. Build terrain mesh từ block data (greedy mesher) ───────────────────
	# top_ly_hint tính từ height grid — tránh scan lại 69 layer/column trong build.
	var top_ly_hint := PackedInt32Array()
	top_ly_hint.resize(cols * cols)
	for vx in range(cols):
		for vz in range(cols):
			var i3: int = vx * cols + vz
			top_ly_hint[i3] = clampi(
				floori((height_grid[vx][vz] - _BlockData.SLAB_HEIGHT) / _BlockData.SLAB_HEIGHT) - _BlockData.Y_MIN,
				0, _BlockData.CHUNK_H - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Terrain.build_terrain_mesh(st, bd, cols, dim_id, top_ly_hint)
	_prof("S8 terrain_mesh")


	# ── 6b. Detail mesh — đường mòn, sỏi cát, hoạ tiết đất ──────────────────
	var grass_xforms: Array = []
	var grass_colors: Array = []
	for vx in range(cols):
		for vz in range(cols):
			var h: float = height_grid[vx][vz]
			var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
			var pz: float = -half + (float(vz) + 0.5) * _Data.VOXEL
			var pos := Vector3(px, h, pz)
			var is_road: bool = road_grid.size() > 0 and road_grid[vx * cols + vz] != 0

			# (đã bỏ hoạ tiết: đường mòn add_trail_detail, sỏi/cát rời add_sand_gravel,
#  gò đất add_dirt_mounds — theo yêu cầu)

			# Cỏ lúa: mọc gần nước (wdist≤3) hoặc chân núi/đồi (hdist≤2).
			# Chân dốc mọc trên mọi nền đất ngoài sa mạc/đá ngầm/đường.
			var i_g: int = vx * cols + vz
			var near_water: bool = wdist[i_g] <= 3
			var hill_foot: bool = hdist[i_g] != _Data.CONST_INF and hdist[i_g] <= 2
			if not fast_mode and not is_road and h >= _Data.VOXEL * 0.9 \
					and (near_water or hill_foot) \
					and not (height_grid[vx][vz] <= _Data.WATER_Y) \
					and biome_grid[vx][vz] != _Data.TileType.DESERT \
					and biome_grid[vx][vz] != _Data.TileType.FROST \
					and biome_grid[vx][vz] != _Data.TileType.FROST_SNOW \
					and biome_grid[vx][vz] != _Data.TileType.SWAMP \
					and biome_grid[vx][vz] != _Data.TileType.SWAMP_MUD \
					and biome_grid[vx][vz] != _Data.TileType.SWAMP_DIRT:
				_Grass.add_voxel_grass(vx, vz, pos, grass_xforms, grass_colors, cols, wdist, hdist)

	# ── 6d. Quán rượu — bên mép đường tại ngã 3 / ngã tư (không trên đường) ──
	var village_data: Dictionary = { "has": false, "xforms": [], "colors": [], "info": {} }
	if not fast_mode and dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		village_data = _Village.compute_village(cx, cz, size, dim_id,
			biome_grid, height_grid, road_grid, river_flag, cols)
	_prof("S9 grass+village")
	var mesh := st.commit()
	if mesh == null:
		return { "mesh": null, "water_mesh": null, "lava_mesh": null, "biome_grid": biome_grid,
				"cols": cols, "block_data_bytes": bd.to_bytes() }

	# ── 7. Water mesh — from block data ──────────────────────────────────
	var has_water: bool = false
	for vx in range(cols):
		for vz in range(cols):
			if height_grid[vx][vz] <= _Data.WATER_Y:
				has_water = true
				break
		if has_water: break
	var mesh_water: ArrayMesh = null
	if has_water:
		var water_skip := PackedByteArray()
		water_skip.resize(cols * cols)
		for wx_ in range(cols):
			for wz_ in range(cols):
				water_skip[wx_ * cols + wz_] = 1 if height_grid[wx_][wz_] > _Data.WATER_Y else 0
		mesh_water = _build_water_mesh(bd, cols, dim_id, h_vox, half, {}, _gen_water_top_layer(), water_skip)
	_prof("S10 water_mesh")

	# ── 7b. Lava mesh — lava do người chơi đổ (xô lava), bao giờ cũng áp
	# SAU khi chunk đã generate (place_block_at → rebuild_mesh). block_data mới
	# sinh từ fill_blocks/spawn_ore_hills KHÔNG BAO GIỜ chứa lava → không cần
	# scan 70656 ô (44ms) mỗi lần generate. Lava đổ sau đó render qua terrain
	# mesh (rebuild_mesh), không qua compute_chunk.
	var has_lava: bool = false
	var mesh_lava: ArrayMesh = null
	_prof("S10 lava_mesh")

	# ── 8. Aquatic mesh — hồ (SAND/SILT) + rong, cỏ biển ở biển nông ──────────
	var mesh_aquatic = null
	var lotus_lights: Array[Vector3] = []
	var plant_props: Array[Dictionary] = []
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		var st_aq := SurfaceTool.new()
		st_aq.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vx in range(cols):
			for vz in range(cols):
				var b: int = biome_grid[vx][vz]
				var h: float = height_grid[vx][vz]
				# Hồ: SAND/SAND_WHITE/SILT/MUDDY_SAND; biển nông: OCEAN_DEEP
				if b != _Data.TileType.SAND and b != _Data.TileType.SAND_WHITE \
						and b != _Data.TileType.SILT and b != _Data.TileType.MUDDY_SAND \
						and b != _Data.TileType.OCEAN_DEEP: continue
				if h > _Data.WATER_Y: continue
				var px2: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz2: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				var pos2 := Vector3(px2, h, pz2)
				var is_river: bool = river_flag[vx * cols + vz] == 1
				# Cấm môn ngọt ở sa mạc: ô thuộc vùng DESERT (mask theo base_bio,
				# chính xác qua biên chunk) HOẶC có đất sa mạc trong 3 ô (hồ cát
				# giáp ranh sa mạc cũng bị cấm).
				var is_desert_water: bool = dmask[(vx + _Data.PAD) * total + (vz + _Data.PAD)] == 1
				if not is_desert_water and (b == _Data.TileType.SAND or b == _Data.TileType.MUDDY_SAND):
					if dland[vx * cols + vz] <= 3:
						is_desert_water = true
				# Cỏ biển multimesh — chỉ đáy biển nông OCEAN_DEEP; rong/taro/lotus
				# đi theo add_aquatic_plants (chạy cho MỌI ô nước: hồ SILT/SAND/
				# MUDDY_SAND lẫn biển nông, tự lọc is_ocean bên trong).
				var aq_biome: int = b
				if b == _Data.TileType.OCEAN_DEEP:
					var sea_wx: float = world_ox - half + (float(vx) + 0.5) * _Data.VOXEL
					var sea_wz: float = world_oz - half + (float(vz) + 0.5) * _Data.VOXEL
					_Grass.add_voxel_seagrass(vx, vz, pos2, grass_xforms, grass_colors,
						cols, _Data.WATER_Y - h, sea_wx, sea_wz)
				_Aquatic.add_aquatic_plants(st_aq, cx, cz, size, vx, vz, pos2, h_vox,
					aq_biome == _Data.TileType.SILT, aq_biome, lotus_lights, plant_props, is_river, is_desert_water)
		mesh_aquatic = st_aq.commit()
	_prof("S11 aquatic+plants")

	# ── 8b. Palm trees — on grass land, ≥2 cells from water ─────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				if not _Data.is_grass_tile(biome_grid[vx][vz]):
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				var wd: int = wdist[vx * cols + vz]
				if wd >= 2 and wd <= 3 and randf() < 0.005:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					# Cấm mọc trên đường đi
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					# Sink slightly into terrain, but never below water surface
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "palm", "pos": Vector3(px, y, pz), "variant": "river"})

	# ── 8c. Cây sồi cổ thụ — đồng cỏ, xa nước ≥2 ──────────────────────────
	for vx in range(cols):
		for vz in range(cols):
			var oak_bio: int = biome_grid[vx][vz]
			if not _Data.is_grass_tile(oak_bio):
				continue
			var h: float = height_grid[vx][vz]
			if h <= _Data.WATER_Y:
				continue
			if wdist[vx * cols + vz] <= 2:
				continue
			var chance: float = 0.0035 if oak_bio == _Data.TileType.GRASS_DIRT else 0.0012
			if randf() < chance:
				var px := -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
				# Cấm mọc trên đường đi
				if _is_on_road(world_ox + px, world_oz + pz):
					continue
				var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
				var variant := "plains"
				plant_props.append({"type": "oak", "pos": Vector3(px, y, pz), "variant": variant})

	# ── 8d. Bụi cherry tím dại — đồng cỏ, xa nước ≥2 ──────────────────────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var bush_bio: int = biome_grid[vx][vz]
				if not _Data.is_grass_tile(bush_bio):
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] <= 2:
					continue
				var chance: float = 0.0045 if bush_bio == _Data.TileType.GRASS_DIRT else 0.0016
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "cherry_bush", "pos": Vector3(px, y, pz), "variant": "plains"})

	# ── 8e. Cây cà tím dại — SÁT ĐƯỜNG ĐI (cách đường ≤2 ô), KHÔNG mọc trên đường ──
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var eg_bio: int = biome_grid[vx][vz]
				if not _Data.is_grass_tile(eg_bio):
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if road_grid[vx * cols + vz] != 0:
					continue
				if rdist[vx * cols + vz] > 2:
					continue
				var chance: float = 0.0024 if eg_bio == _Data.TileType.GRASS_DIRT else 0.0009
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "eggplant", "pos": Vector3(px, y, pz), "variant": "wild"})

	# ── 8f. Cây dưa hấu dại — GẦN nguồn nước (nước cách ≤2 ô), đồng cỏ ──
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var wm_bio: int = biome_grid[vx][vz]
				if not _Data.is_grass_tile(wm_bio):
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] > 2:
					continue
				var chance: float = 0.0016 if wm_bio == _Data.TileType.GRASS_DIRT else 0.0006
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "watermelon", "pos": Vector3(px, y, pz), "variant": "wild"})

	# ── 8g. Dây bí đỏ dại — XA nguồn nước (nước cách ≥3 ô), đồng cỏ ──
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var pk_bio: int = biome_grid[vx][vz]
				if not _Data.is_grass_tile(pk_bio):
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] <= 3:
					continue
				# Bí đỏ hiếm hơn — spawn ít lại (≈40% so với trước)
				var chance: float = 0.0010 if pk_bio == _Data.TileType.GRASS_DIRT else 0.0004
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "pumpkin", "pos": Vector3(px, y, pz), "variant": "wild"})

	# ── 8h. Cây cam — bờ nước (xa nước 2-3 ô) & trung tâm đồng cỏ tối ────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var or_bio: int = biome_grid[vx][vz]
				if not _Data.is_grass_tile(or_bio):
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				# Bờ nước: nước cách 2-3 ô nhưng không liền kề
				var wd2: int = wdist[vx * cols + vz]
				var near_close: bool = wd2 <= 1
				var near_far: bool = wd2 >= 2 and wd2 <= 3
				var spawned := false
				if near_far and not near_close and randf() < 0.0025:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "orange_tree", "pos": Vector3(px, y, pz), "variant": "river"})
					spawned = true
				# Trung tâm đồng cỏ: xa nước ≥2
				if not spawned and or_bio == _Data.TileType.GRASS_DIRT and not near_close and randf() < 0.0016:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "orange_tree", "pos": Vector3(px, y, pz), "variant": "plains"})

	# ── 8i. Cây rừng rậm — tán um tùm, xa nước ≥2 trên đồng cỏ ──────────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var dt_bio: int = biome_grid[vx][vz]
				if not _Data.is_grass_tile(dt_bio):
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] <= 2:
					continue
				if randf() < 0.0012:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "dense_tree", "pos": Vector3(px, y, pz), "variant": "plains"})

	# ── 8j. RỪNG NGẬP MẶN — đước + thủy trúc + cua bùn trên bãi bùn triều ───
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				if biome_grid[vx][vz] != _Data.TileType.MANGROVE_MUD:
					continue
				var h: float = height_grid[vx][vz]
				var mx: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var mz: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				# Cây đước — bãi bùn gần mực nước, rễ chùm ăn xuống lạch triều
				if h > _Data.WATER_Y - 1.1 and _cell_hash01(vx, vz) < 0.045:
					if _is_on_road(world_ox + mx, world_oz + mz):
						continue
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "mangrove", "pos": Vector3(mx, y, mz), "variant": "coast"})
				# Thủy trúc (cattail) — bãi bùn ngập nông, mọc thành cụm sát nước
				if h > _Data.WATER_Y - 1.5 and h <= _Data.WATER_Y + 0.2 and _cell_hash01(vx + 991, vz) < 0.034:
					var y2 := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "cattail", "pos": Vector3(mx, y2, mz), "variant": "mangrove"})
				# Cua bùn — bãi bùn nhô trên mực nước (mô bùn khô)
				if h > _Data.WATER_Y + 0.1 and _cell_hash01(vx + 1817, vz + 331) < 0.010:
					var y3 := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "mud_crab", "pos": Vector3(mx, y3, mz), "variant": "mud"})

	# ── 8k. Cây vân sam (thông tuyết) — bio băng giá, xa nước ≥2 ────────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var fr_bio: int = biome_grid[vx][vz]
				if fr_bio != _Data.TileType.FROST and fr_bio != _Data.TileType.FROST_SNOW:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] <= 2:
					continue
				var chance: float = 0.0065 if fr_bio == _Data.TileType.FROST_SNOW else 0.0035
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "spruce", "pos": Vector3(px, y, pz), "variant": "snow"})

	# ── 8l. RỪNG ĐẦM LẦY — cây tràm + lác nước + bèo ──────────────────────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var sw_bio: int = biome_grid[vx][vz]
				if sw_bio != _Data.TileType.SWAMP_MUD and sw_bio != _Data.TileType.SWAMP_DIRT:
					continue
				var h: float = height_grid[vx][vz]
				var px := -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
				if _is_on_road(world_ox + px, world_oz + pz):
					continue
				# Cây tràm — mô bùn nhô khỏi mặt nước (cao hơn mực nước); tán lớn nên thưa
				if h > _Data.WATER_Y + 0.15 and _cell_hash01(vx, vz) < 0.012:
					var y := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "swamp_tree", "pos": Vector3(px, y, pz), "variant": "marsh"})
				# Lác nước — bãi bùn ngập nông tới khô, cụm thành bụi
				if h > _Data.WATER_Y - 0.8 and h <= _Data.WATER_Y + 0.7 and _cell_hash01(vx + 131, vz + 77) < 0.045:
					var y2 := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "swamp_sedge", "pos": Vector3(px, y2, pz), "variant": "marsh"})
				# Cua bùn — mô bùn khô nhô trên mực nước (như rừng ngập mặn)
				if h > _Data.WATER_Y + 0.1 and _cell_hash01(vx + 2089, vz + 167) < 0.012:
					var y3 := maxf(_snap_surface_y(h), _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "mud_crab", "pos": Vector3(px, y3, pz), "variant": "mud"})
				# Bèo — vũng nước đứng (thấp hơn mực nước nên ngập), nổi trên mặt
				if h < _Data.WATER_Y - 0.05 and _cell_hash01(vx + 977, vz + 313) < 0.016:
					plant_props.append({"type": "duckweed", "pos": Vector3(px, _Data.WATER_Y + 0.03125, pz), "variant": "marsh"})

	_prof("S12 plant_props")

	# ── 9. Lamp positions ──────────────────────────────────────────────────────
	var lamp_positions: Array = []
	if not fast_mode and dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		lamp_positions = _RoadLamp.compute_positions(cx, cz, size, biome_grid, height_grid, cols)
	_prof("S13a lamps")


	# ── 10. Textured block (ore) overlays — bounded scan dưới bề mặt ─────────
	# Ore tồn tại trong bd ở 2 nơi: (1) đồi quặng (spawn_ore_hills) và (2) đỉnh
	# núi đá (STONE_PATCH → _stone_patch_top có thể là COAL_ORE/IRON_ORE). Gate
	# cũ chỉ theo ore_hill_info → chunk núi đá có quặng nhưng không có đồi sẽ bị
	# bỏ qua toàn bộ scan → quặng hiển thị màu trơn (không texture).
	# Kiểm tra rẻ: chỉ soi một lớp bề mặt theo top_ly_hint (kể cả cho vùng đồi).
	var max_top_ly: int = 0
	for vx in range(cols):
		for vz in range(cols):
			max_top_ly = maxi(max_top_ly, top_ly_hint[vx * cols + vz])
	var has_ore_blocks: bool = ore_hill_info.get("cx", -1) >= 0
	if not has_ore_blocks:
		for vx in range(cols):
			for vz in range(cols):
				var ly: int = top_ly_hint[vx * cols + vz]
				if ly >= 0 and _TEXTURED_BLOCK_IDS.has(bd.get_block(vx, ly, vz)):
					has_ore_blocks = true
					break
			if has_ore_blocks:
				break
	var ore_meshes: Dictionary[int, ArrayMesh] = {}
	if not fast_mode and _ORES_GENERATION_ENABLED and has_ore_blocks:
		ore_meshes = _build_textured_block_meshes(bd, cols, max_top_ly)
	_prof("S13b ore")

	# ── 10b. Shaped blocks (đá ¼/⅛/phiến) — BỎ SCAN ở generation ────────────
	# Terrain generation KHÔNG BAO GIỜ ghi shaped block (chỉ check). Shaped block
	# chỉ tồn tại qua đặt tay/save-restore → cả hai đều rebuild qua rebuild_mesh
	# → _build_shaped_block_nodes (scan tại đó). Scan 70K ô ~34ms ngay tại đây là
	# phí hoàn toàn, nhất là chunk trung tâm sync chạy ngay trên main thread.
	var shaped_data := _empty_shaped_data()

	# Cấm cây cối/prop mọc đè lên quán rượu (lọc theo AABB quán trong chunk)
	if not plant_props.is_empty() and village_data.get("has", false):
		var tv_aabs: Array = []
		for b in village_data.get("info", {}).get("buildings", []):
			tv_aabs.append(_tavern_aabb(b))
		if not tv_aabs.is_empty():
			var kept: Array[Dictionary] = []
			for pd in plant_props:
				var pos3: Vector3 = pd.get("pos", Vector3.ZERO)
				var wx3: float = world_ox + pos3.x
				var wz3: float = world_oz + pos3.z
				var hit := false
				for ab in tv_aabs:
					var mn: Vector3 = ab[0]
					var mx: Vector3 = ab[1]
					if wx3 >= mn.x and wx3 <= mx.x and wz3 >= mn.z and wz3 <= mx.z:
						hit = true
						break
				if not hit:
					kept.append(pd)
			plant_props = kept
	_prof("S13c tavern")

	# ── Sắp xếp props theo chi phí spawn (rẻ trước) NGAY TRÊN WORKER ─────────
	# Trước đây làm trên main thread trong apply_chunk (duplicate + sort_custom
	# so sánh Dictionary từng cặp) — chunk dày thực vật mất 12-50ms → frame spike.
	# Sort ở đây chỉ tốn thời gian của worker thread (chạy song song với frame).
	if plant_props.size() > 1:
		plant_props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _prop_cost(a.get("type", "weed")) < _prop_cost(b.get("type", "weed")))

	# ── Mask bãi đá (STONE_PATCH) — cho test/biết đâu là đá lộ thiên tự nhiên,
	# không phải đồi quặng (test_ore_hills dùng để loại khi đếm đồi).
	var stone_patch_mask := PackedByteArray()
	stone_patch_mask.resize(cols * cols)
	stone_patch_mask.fill(0)
	for vx in range(cols):
		for vz in range(cols):
			if biome_grid[vx][vz] == _Data.TileType.STONE_PATCH:
				stone_patch_mask[vx * cols + vz] = 1
	_prof("S13d stone_mask")

	# ── Grass MultiMesh build NGAY TRÊN WORKER (trước đây main trong apply_chunk:
	# loop đổ transforms+colors vào set_buffer cho hàng nghìn lá cỏ mất 10-17ms
	# mỗi chunk → frame spike). Ở đây chạy song song với frame, apply_chunk chỉ
	# bọc MultiMeshInstance3D.
	var grass_multimesh: MultiMesh = null
	if not grass_xforms.is_empty():
		var gres := _get_grass_resources()
		var gcube := gres[0] as BoxMesh
		var gmat := gres[1] as Material
		gcube.material = gmat
		var gmm := MultiMesh.new()
		gmm.transform_format = MultiMesh.TRANSFORM_3D
		gmm.use_colors = true
		gmm.mesh = gcube
		gmm.instance_count = grass_xforms.size()
		_multimesh_buffer(gmm, grass_xforms, grass_colors)
		grass_multimesh = gmm

	return {
		"mesh": mesh, "water_mesh": mesh_water, "lava_mesh": mesh_lava, "aquatic_mesh": mesh_aquatic,
		"grass_blade_data": { "xforms": grass_xforms, "colors": grass_colors },
		"grass_multimesh": grass_multimesh,
		"village_data": village_data, "height_grid": height_grid,
		"ore_hill": ore_hill_info,
		"lotus_lights": lotus_lights, "biome_grid": biome_grid, "cols": cols,
		"river_flag": river_flag,
		"block_data_bytes": bd.to_bytes(), "lamp_positions": lamp_positions,
		"textured_block_meshes": ore_meshes,
		"plant_props": plant_props, "has_water": has_water, "has_lava": has_lava,
		"has_ores": not ore_meshes.is_empty(),
		"top_ly_hint": top_ly_hint,
		"stone_patch_mask": stone_patch_mask,
		"shaped_mesh": shaped_data["shaped_mesh"],
		"shaped_pos": shaped_data["shaped_pos"],
		"shaped_size": shaped_data["shaped_size"],
	}



## ── _get_textured_block_material: delegate OreTextures (mỗi ore 1 hoa văn) ──
static func _get_textured_block_material(block_id: int) -> Material:
	if block_id == _Data.BlockID.TILLED_SOIL:
		return _OreTex.get_soil_material(false)
	return _OreTex.get_material(block_id)

## ── _build_xform_multimesh: BoxMesh đơn vị + vertex color (cỏ, rêu, làng, ...) ──
## `unshaded=true` cho chi tiết nhỏ (cỏ/rêu); làng/cầu dùng shaded như cây dừa
## (metallic 0, roughness cao, có ánh sáng).
## Đổ transforms + colors vào MultiMesh bằng set_buffer (1 lệnh) — nhanh hơn
## loop set_instance_transform/color ~3x cho hàng nghìn instance (grass/village).
static func _multimesh_buffer(mm: MultiMesh, xforms: Array, colors: Array) -> void:
	var n: int = xforms.size()
	if n == 0:
		return
	var buf := PackedFloat32Array()
	buf.resize(n * 16)
	var k: int = 0
	for i in range(n):
		var t: Transform3D = xforms[i] as Transform3D
		buf[k]     = t.basis.x.x; buf[k + 1]  = t.basis.y.x; buf[k + 2]  = t.basis.z.x; buf[k + 3]  = t.origin.x
		buf[k + 4] = t.basis.x.y; buf[k + 5]  = t.basis.y.y; buf[k + 6]  = t.basis.z.y; buf[k + 7]  = t.origin.y
		buf[k + 8] = t.basis.x.z; buf[k + 9]  = t.basis.y.z; buf[k + 10] = t.basis.z.z; buf[k + 11] = t.origin.z
		var c: Color = colors[i] as Color
		buf[k + 12] = c.r; buf[k + 13] = c.g; buf[k + 14] = c.b; buf[k + 15] = c.a
		k += 16
	mm.set_buffer(buf)

static func _build_xform_multimesh(xforms: Array, colors: Array,
		shadow_on: bool = false, unshaded: bool = true) -> MultiMeshInstance3D:
	var cube: BoxMesh
	var mat: Material
	if unshaded:
		var res := _get_grass_resources()
		cube = res[0] as BoxMesh
		mat = res[1] as Material
	else:
		var res := _get_village_resources()
		cube = res[0] as BoxMesh
		mat = res[1] as StandardMaterial3D
	cube.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = xforms.size()
	_multimesh_buffer(mm, xforms, colors)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow_on \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## ── AABB quán (x,z xoay theo yaw) — dùng cho phát hiện "đang đứng trong quán" ──
static func _tavern_aabb(b: Dictionary) -> Array:
	var yaw: float = float(b.get("yaw", 0.0))
	var hx: float = float(b.get("half_x", 10.7)) + 1.0
	var hz: float = float(b.get("half_z", 8.0)) + 1.0
	var c := Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
	var shx: float = absf(hx * cos(yaw)) + absf(hz * sin(yaw))
	var shz: float = absf(hx * sin(yaw)) + absf(hz * cos(yaw))
	var bot: float = float(b.get("gy", 0.0)) - 0.5
	var top: float = float(b.get("gy", 0.0)) + float(b.get("top_y", 11.5)) + 0.5
	return [Vector3(c.x - shx, bot, c.z - shz), Vector3(c.x + shx, top, c.z + shz)]

## ── AABB NỘI THẤT (KHẮT): dùng cho fade — chỉ mờ vỏ khi thật sự đứng TRONG
## nhà (trong phạm vi 4 bức tường). Không dùng để lọc cây, không nhô ra hiên/
## bậc như _tavern_aabb → hết cảnh "cả khối nhà nhì như nát khi đứng gần".
static func _tavern_interior_aabb(b: Dictionary) -> Array:
	var yaw: float = float(b.get("yaw", 0.0))
	var cx: float = cos(yaw)
	var sy: float = sin(yaw)
	var c := Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
	const LX: float = 5.0   # ±x tường trong (tường ±5.35)
	const Z0: float = -2.4  # sát mặt sau tường trước
	const Z1: float = 6.6   # sát mặt trong tường sau
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for lz in [Z0, Z1]:
		for s in [-1.0, 1.0]:
			var lx: float = s * LX
			var wx: float = c.x + lx * cx - lz * sy
			var wz: float = c.z + lx * sy + lz * cx
			mn = mn.min(Vector2(wx, wz))
			mx = mx.max(Vector2(wx, wz))
	var bot: float = float(b.get("gy", 0.0)) - 0.5
	var top: float = float(b.get("gy", 0.0)) + float(b.get("top_y", 11.5)) + 0.5
	return [Vector3(mn.x, bot, mn.y), Vector3(mx.x, top, mx.y)]

## ── Dựng MultiMesh quán (shell + nội thất) ────────────────────────────────────
## shell = vỏ công trình (nhìn thấy từ ngoài, đổ bóng); interior = nội thất.
static func _build_tavern_mesh(vbd: Dictionary) -> Array:
	var shell := _build_xform_multimesh(vbd.get("xforms", []), vbd.get("colors", []), true, false)
	var smat: StandardMaterial3D = shell.multimesh.mesh.material as StandardMaterial3D
	shell.material_override = smat
	var ix: Array = vbd.get("ixforms", [])
	var inner: MultiMeshInstance3D = null
	if ix.size() > 0:
		inner = _build_xform_multimesh(ix, vbd.get("icolors", []), false, false)
	return [shell, inner]

## ── Gắn tính năng cho từng quán: khói (VFX), đèn mái, collision tường, cửa ──
static func _attach_tavern_features(container: Node, vbd: Dictionary,
		cx: int, cz: int, size: int) -> void:
	var origin := Vector3(cx * size, 0.0, cz * size)
	for b in vbd.get("info", {}).get("buildings", []):
		var yaw: float = float(b.get("yaw", 0.0))
		var rot := Basis(Vector3.UP, yaw)
		var gx2 := float(b.get("x", 0.0))
		var gz2 := float(b.get("z", 0.0))
		var gy2 := float(b.get("gy", 0.0))
		var center_local := Vector3(gx2 - cx * size, gy2, gz2 - cz * size)

		# 1) Khói ống khói (VFX, bật chiều → tắt 2h sáng)
		var sm = _ChimneySmoke.new()
		sm.position = center_local + rot * Vector3(2.2, 12.0, -2.3)
		container.add_child(sm)

		# 2) Đèn mái — sáng mạnh ban đêm (RoadLampManager tự giảm sáng/đêm)
		var lamp := OmniLight3D.new()
		lamp.position = center_local + Vector3(0, 9.2, 0)
		lamp.light_color = Color(1.0, 0.82, 0.55)
		lamp.light_energy = 0.0
		lamp.omni_range = 6.0 if DeviceManager.is_mobile() else 22.0
		lamp.omni_attenuation = 1.4
		lamp.shadow_enabled = false
		lamp.light_specular = 0.0
		container.add_child(lamp)
		RoadLampManager.register_light(lamp)

		# 3) Collision tường (mở: cửa để khe giữa)
		_attach_tavern_walls(container, yaw, center_local)

		# 4) Cửa mở/đóng được
		var door = _TavernDoor.new()
		door.position = center_local
		door.rotation.y = yaw
		container.add_child(door)

## ── Tường collision quán (StaticBody3D xoay theo yaw, khe hở cửa trước) ──────
static func _attach_tavern_walls(container: Node,
		yaw: float, center_local: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center_local
	body.rotation.y = yaw
	var boxes := [
		[Vector3(0, 0.12, 2.0), Vector3(10.6, 0.24, 8.8)],     # sàn
		[Vector3(-3.15, 3.0, -2.35), Vector3(4.5, 5.7, 0.5)],  # tường trước (trái)
		[Vector3(3.15, 3.0, -2.35), Vector3(4.5, 5.7, 0.5)],   # tường trước (phải)
		[Vector3(0, 3.0, 6.55), Vector3(10.7, 5.7, 0.5)],      # tường sau
		[Vector3(-5.35, 3.0, 2.0), Vector3(0.5, 5.7, 9.0)],    # tường trái
		[Vector3(5.35, 3.0, 2.0), Vector3(0.5, 5.7, 9.0)],     # tường phải
	]
	for bx in boxes:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bx[1]
		col.shape = shape
		col.position = bx[0]
		body.add_child(col)
	container.add_child(body)


## ── _build_textured_block_mesh: mesh có UV cho block có texture ─────────────
static func _build_textured_block_mesh(bd: _BlockData, cols: int, target_block_id: int, top_ly: PackedInt32Array) -> ArrayMesh:
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB := _BlockData.SLAB_HEIGHT
	const B := _Data.BlockID
	var hw: float = _Data.VOXEL * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	const _SIDE_MUL: float = 0.62
	const _BOT_MUL: float = 0.40

	for x in range(cols):
		for z in range(cols):
			var hi: int = top_ly[x * cols + z]
			if hi < 0: continue
			# Chạy dọc đặc của loại block này [lo..hi] — gộp mọi block cùng loại
			# xếp chồng để texture phủ kín cả cột (block dưới không mất texture
			# khi place chồng thêm — trước đây chỉ vẽ topmost nên dưới chỉ brown).
			var lo: int = hi
			while lo > 0 and bd.get_block(x, lo - 1, z) == target_block_id:
				lo -= 1
			var cx_f: float = -half + (float(x) + 0.5) * _Data.VOXEL
			var cz_f: float = -half + (float(z) + 0.5) * _Data.VOXEL
			var cy_top: float = float(hi + Y_MIN) * SLAB + SLAB
			var cy_bot: float = float(lo + Y_MIN) * SLAB

			st.set_color(Color.WHITE)
			_Terrain._add_quad_uv(st, Vector3(cx_f, cy_top + 0.01, cz_f),
				Vector3(hw, 0, 0), Vector3(0, 0, hw), Vector3(0, 1, 0))

			if lo > 0:
				var below: int = bd.get_block(x, lo - 1, z)
				if below == B.AIR or below == B.WATER:
					st.set_color(Color(_BOT_MUL, _BOT_MUL, _BOT_MUL))
					_Terrain._add_quad_uv(st, Vector3(cx_f, cy_bot, cz_f),
						Vector3(-hw, 0, 0), Vector3(0, 0, hw), Vector3(0, -1, 0))

			var checks: Array = [
				[z > 0, x, z - 1, Vector3(0, 0, -1), Vector3(0, 0, -hw)],
				[z < cols - 1, x, z + 1, Vector3(0, 0, 1), Vector3(0, 0, hw)],
				[x > 0, x - 1, z, Vector3(-1, 0, 0), Vector3(-hw, 0, 0)],
				[x < cols - 1, x + 1, z, Vector3(1, 0, 0), Vector3(hw, 0, 0)],
			]
			for c in checks:
				if not c[0]: continue
				var nx: int = c[1]; var nz: int = c[2]
				var nly: int = top_ly[nx * cols + nz]
				if nly >= hi: continue
				var nrm: Vector3 = c[3]; var off: Vector3 = c[4]
				var n_top: float = float(nly + Y_MIN) * SLAB + SLAB if nly >= 0 else float(Y_MIN) * SLAB
				var side_h: float = cy_top - maxf(cy_bot, n_top)
				if side_h <= 0: continue
				var cy_mid: float = cy_top - side_h * 0.5
				var side_u: Vector3 = Vector3(hw, 0, 0) if abs(off.x) < 0.01 else Vector3(0, 0, hw)
				st.set_color(Color(_SIDE_MUL, _SIDE_MUL, _SIDE_MUL))
				# UV lặp lại theo từng slab (mỗi block cao 0.5 → 1 họa tiết)
				_Terrain._add_quad_uv(st, Vector3(cx_f + off.x + nrm.x * 0.01, cy_mid, cz_f + off.z + nrm.z * 0.01),
					side_u, Vector3(0, side_h * 0.5, 0), nrm, Vector2(1, side_h / SLAB))

	return st.commit()



const _TEXTURED_BLOCK_IDS: Array[int] = [
	_Data.BlockID.COPPER_ORE,
	_Data.BlockID.BAUXITE_ORE,
	_Data.BlockID.SILVER_ORE,
	_Data.BlockID.IRON_ORE,
	_Data.BlockID.GOLD_ORE,
	_Data.BlockID.TITAN_ORE,
	_Data.BlockID.PLATINUM_ORE,
	_Data.BlockID.COAL_ORE,
	_Data.BlockID.OAK_WOOD,
]

## Ore hiện được sinh qua đồi quặng (spawn_ore_hills) ở khu xa spawn
const _ORES_GENERATION_ENABLED: bool = true

static func _build_textured_block_meshes(bd: _BlockData, cols: int, max_ly: int = -1) -> Dictionary[int, ArrayMesh]:
	const CHUNK_H := _BlockData.CHUNK_H
	if max_ly < 0:
		max_ly = CHUNK_H - 1
	max_ly = clampi(max_ly, 0, CHUNK_H - 1)
	# 1 pass từ trên xuống: top_ly cho từng loại ore theo từng cột.
	# max_ly là đỉnh terrain cao nhất → ore luôn dưới max_ly → kết quả y hệt scan
	# đủ CHUNK_H trước đây (ore chỉ tồn tại dưới bề mặt terrain).
	var top_maps: Dictionary = {}
	for bid in _TEXTURED_BLOCK_IDS:
		var arr := PackedInt32Array()
		arr.resize(cols * cols)
		arr.fill(-1)
		top_maps[bid] = arr
	var n_types: int = _TEXTURED_BLOCK_IDS.size()
	for x in range(cols):
		for z in range(cols):
			var found_in_col := 0
			for ly in range(max_ly, -1, -1):
				var blk := bd.get_block(x, ly, z)
				if not top_maps.has(blk):
					continue
				var arr: PackedInt32Array = top_maps[blk]
				if arr[x * cols + z] == -1:
					arr[x * cols + z] = ly
					found_in_col += 1
					if found_in_col >= n_types:
						break
	var result: Dictionary[int, ArrayMesh] = {}
	for bid in _TEXTURED_BLOCK_IDS:
		var arr: PackedInt32Array = top_maps[bid]
		var any_hit := false
		for i in range(arr.size()):
			if arr[i] >= 0:
				any_hit = true
				break
		if not any_hit:
			continue
		var m := _build_textured_block_mesh(bd, cols, bid, arr)
		if m and m.get_surface_count() > 0:
			result[bid] = m
	return result

## ── Đất tơi xốp: overlay mesh — ẩm/khô qua vertex color tint ────────────────
## Ẩm khi có nước trong bán kính SOIL_RADIUS (tính từ block nước thực tế, đi
## qua biên chunk bằng nb_data) — deterministic, không lưu state riêng.
const _SOIL_DRY_TINT := Color(1.0, 0.96, 0.90)
const _SOIL_WET_TINT := Color(0.55, 0.60, 0.72)

static func _soil_cell_is_water(bd: _BlockData, nb_data: Dictionary, cols: int,
		wx: int, wly: int, wz: int) -> bool:
	if wx >= 0 and wx < cols and wz >= 0 and wz < cols:
		return _is_water_bid(bd.get_block(wx, wly, wz))
	var dir: String
	var tx: int = wx
	var tz: int = wz
	if wx < 0:
		dir = "w"; tx += cols
	elif wx >= cols:
		dir = "e"; tx -= cols
	elif wz < 0:
		dir = "n"; tz += cols
	else:
		dir = "s"; tz -= cols
	if not nb_data.has(dir):
		return false
	var info: Dictionary = nb_data[dir]
	var nb_bd: _BlockData = info["bd"]
	var nb_cols: int = info["cols"]
	if tx < 0 or tx >= nb_cols or tz < 0 or tz >= nb_cols:
		return false
	return _is_water_bid(nb_bd.get_block(tx, wly, tz))

static func _soil_is_wet_at(bd: _BlockData, nb_data: Dictionary, cols: int,
		x: int, ly: int, z: int) -> bool:
	const CHUNK_H := _BlockData.CHUNK_H
	var r: int = _Data.SOIL_RADIUS
	var max_ly: int = mini(ly + r, CHUNK_H - 1)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for wly in range(ly, max_ly + 1):
				if _soil_cell_is_water(bd, nb_data, cols, x + dx, wly, z + dz):
					return true
	return false

static func _build_soil_mesh(bd: _BlockData, cols: int, nb_data: Dictionary = {}) -> ArrayMesh:
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB := _BlockData.SLAB_HEIGHT
	const B := _Data.BlockID
	const _SIDE_MUL: float = 0.62
	const _BOT_MUL: float = 0.40
	var hw: float = _Data.VOXEL * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5

	var top_ly := PackedInt32Array()
	top_ly.resize(cols * cols)
	top_ly.fill(-1)
	for x in range(cols):
		for z in range(cols):
			for ly in range(CHUNK_H - 1, -1, -1):
				if bd.get_block(x, ly, z) == B.TILLED_SOIL:
					top_ly[x * cols + z] = ly
					break

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in range(cols):
		for z in range(cols):
			var ly: int = top_ly[x * cols + z]
			if ly < 0: continue
			var cx_f: float = -half + (float(x) + 0.5) * _Data.VOXEL
			var cz_f: float = -half + (float(z) + 0.5) * _Data.VOXEL
			var cy_top: float = float(ly + Y_MIN) * SLAB + SLAB
			var cy_bot: float = float(ly + Y_MIN) * SLAB

			var wet: bool = _soil_is_wet_at(bd, nb_data, cols, x, ly, z)
			var tint: Color = _SOIL_WET_TINT if wet else _SOIL_DRY_TINT

			st.set_color(tint)
			_Terrain._add_quad_uv(st, Vector3(cx_f, cy_top + 0.01, cz_f),
				Vector3(hw, 0, 0), Vector3(0, 0, hw), Vector3(0, 1, 0))

			if ly > 0:
				var below: int = bd.get_block(x, ly - 1, z)
				if below == B.AIR or _is_water_bid(below):
					st.set_color(tint * _BOT_MUL)
					_Terrain._add_quad_uv(st, Vector3(cx_f, cy_bot, cz_f),
						Vector3(-hw, 0, 0), Vector3(0, 0, hw), Vector3(0, -1, 0))

			var checks: Array = [
				[z > 0, x, z - 1, Vector3(0, 0, -1), Vector3(0, 0, -hw)],
				[z < cols - 1, x, z + 1, Vector3(0, 0, 1), Vector3(0, 0, hw)],
				[x > 0, x - 1, z, Vector3(-1, 0, 0), Vector3(-hw, 0, 0)],
				[x < cols - 1, x + 1, z, Vector3(1, 0, 0), Vector3(hw, 0, 0)],
			]
			for c in checks:
				if not c[0]: continue
				var nx: int = c[1]; var nz: int = c[2]
				var nly: int = top_ly[nx * cols + nz]
				if nly >= ly: continue
				var nrm: Vector3 = c[3]; var off: Vector3 = c[4]
				var n_top: float = float(nly + Y_MIN) * SLAB + SLAB if nly >= 0 else float(Y_MIN) * SLAB
				var side_h: float = cy_top - max(cy_bot, n_top)
				if side_h <= 0: continue
				var cy_mid: float = cy_top - side_h * 0.5
				var side_u: Vector3 = Vector3(hw, 0, 0) if abs(off.x) < 0.01 else Vector3(0, 0, hw)
				st.set_color(tint * _SIDE_MUL)
				_Terrain._add_quad_uv(st, Vector3(cx_f + off.x + nrm.x * 0.01, cy_mid, cz_f + off.z + nrm.z * 0.01),
					side_u, Vector3(0, side_h * 0.5, 0), nrm)

	return st.commit()

## ── _build_water_mesh: render exposed faces only (skip bottom, correct size) ─
## fluid_kind: 0=water only, 1=lava only, -1=bất kỳ fluid nào (render both + chọn màu theo từng block).
static func _build_water_mesh(bd: _BlockData, cols: int, dim_id: int,
		h_vox: float, half: float, nb_data: Dictionary = {}, max_ly: int = -1,
		skip_mask: PackedByteArray = PackedByteArray(), fluid_kind: int = -1) -> ArrayMesh:
	const SLAB := _BlockData.SLAB_HEIGHT
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	var VOXEL := _Data.VOXEL
	# Nước chỉ tồn tại ở layers 0..max_ly — giới hạn scan (tránh 69 layer rỗng)
	if max_ly < 0:
		max_ly = _gen_water_top_layer()
	max_ly = clampi(max_ly, 0, CHUNK_H - 1)

# ── Column-top map: per cột, tầng cao nhất có nước (tops[t]) + level của đỉnh
	# (levs[t]). 1 pass raw (bỏ bounds-check get_block), z innermost theo layout
	# x*CHUNK_H*cols + y*cols + z. Vòng y tăng → tops bị ghi đè lên tầng cao nhất.
	var nc := cols * cols
	var tops := PackedInt32Array()
	tops.resize(nc)
	tops.fill(-1)
	var levs := PackedByteArray()
	levs.resize(nc)
	var top_bids := PackedInt32Array()
	top_bids.resize(nc)
	top_bids.fill(0)
	var stride_x := CHUNK_H * cols
	var raw := bd._data
	# Cột-major: quét từ max_ly xuống, break ngay khi thấy nước (đỉnh cao nhất).
	# Cột không nước: bỏ hẳn (không quét đủ CHUNK_H như cũ). Với hồ nhỏ (chunk
	# 0,0) chỉ ~vài chục cột có nước → cắt mạnh scan.
	for x in range(cols):
		var bbase := x * stride_x
		for z in range(cols):
			if skip_mask.size() > 0 and skip_mask[x * cols + z] != 0:
				continue  # cột chắc chắn không nước (height > WATER_Y) — bỏ scan
			for y in range(max_ly, -1, -1):
				var bid: int = raw[bbase + y * cols + z]
				if _is_fluid_bid(bid) and (fluid_kind < 0 or _fluid_kind(bid) == fluid_kind):
					var ti := z * cols + x
					tops[ti] = y
					levs[ti] = _fluid_level_of(bid)
					top_bids[ti] = bid
					break

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	const EPS := 0.02  # tránh z-fight với vách terrain coplanar
	var hh := h_vox
	var hv := SLAB * 0.5
	for x in range(cols):
		var px := -half + (float(x) + 0.5) * VOXEL
		for z in range(cols):
			var ti := z * cols + x
			var tl: int = tops[ti]
			if tl < 0:
				continue
			var pz := -half + (float(z) + 0.5) * VOXEL
			# Màu water = xanh lam theo level; lava = cam/vàng theo level
			var col: Color
			if _fluid_kind(top_bids[ti]) == 1:
				col = Color(0.3 + 0.11 * float(levs[ti]) / 8.0, 0.18 + 0.15 * float(levs[ti]) / 8.0, 0.05)
			else:
				col = Color(0.20, 0.55 - 0.12 * float(levs[ti]) / 8.0, 0.80)
			var top_y := (float(tl + Y_MIN) + 0.5) * SLAB

			# Top face (+y) — luôn có vì tl là đỉnh cao nhất
			_add_quad(st, Vector3(px, top_y + hv, pz), Vector3(hh, 0, 0), Vector3(0, 0, hh), Vector3(0, 1, 0), col)

			# Side faces: band [bề mặt hàng xóm .. bề mặt cột hiện tại] nếu neighbor
			# thấp hơn (hoặc 0 nước). Vách KHỚP đúng 2 bề mặt nước (không lệch 0.5 slab)
			# → khối nước 4 mặt kín, không còn khe hở ở mép mực nước / bờ.
			# NOTE: tops là z-major (ti = z*cols+x) → x-neighbor lệch ±1, z lệch ±cols.
			var nxm: int = tops[ti - 1] if x > 0 else _nb_water_top(bd, nb_data, cols, x, max_ly, z, -1, 0, fluid_kind)
			var nxp: int = tops[ti + 1] if x + 1 < cols else _nb_water_top(bd, nb_data, cols, x, max_ly, z, 1, 0, fluid_kind)
			var nzm: int = tops[ti - cols] if z > 0 else _nb_water_top(bd, nb_data, cols, x, max_ly, z, 0, -1, fluid_kind)
			var nzp: int = tops[ti + cols] if z + 1 < cols else _nb_water_top(bd, nb_data, cols, x, max_ly, z, 0, 1, fluid_kind)

			# Đỉnh vách = đúng mặt nước (cùng mặt phẳng với top face) — không lệch xuống.
			var ytop := (float(tl + Y_MIN) + 1.0) * SLAB
			if nxp < tl:
				var ya := (float(maxi(nxp, -1) + 1 + Y_MIN)) * SLAB
				_add_quad(st, Vector3(px + hh + EPS, (ya + ytop) * 0.5, pz), Vector3(0, (ytop - ya) * 0.5, 0), Vector3(0, 0, hh), Vector3(1, 0, 0), col)
			if nxm < tl:
				var ya := (float(maxi(nxm, -1) + 1 + Y_MIN)) * SLAB
				_add_quad(st, Vector3(px - hh - EPS, (ya + ytop) * 0.5, pz), Vector3(0, (ytop - ya) * 0.5, 0), Vector3(0, 0, hh), Vector3(-1, 0, 0), col)
			if nzp < tl:
				var ya := (float(maxi(nzp, -1) + 1 + Y_MIN)) * SLAB
				_add_quad(st, Vector3(px, (ya + ytop) * 0.5, pz + hh + EPS), Vector3(hh, 0, 0), Vector3(0, (ytop - ya) * 0.5, 0), Vector3(0, 0, 1), col)
			if nzm < tl:
				var ya := (float(maxi(nzm, -1) + 1 + Y_MIN)) * SLAB
				_add_quad(st, Vector3(px, (ya + ytop) * 0.5, pz - hh - EPS), Vector3(hh, 0, 0), Vector3(0, (ytop - ya) * 0.5, 0), Vector3(0, 0, -1), col)
	return st.commit()

## ── _nb_water_top: top layer fluid của ô (x+dx, z+dz), băng qua biên chunk ──────
## Trả -1 nếu không có fluid. Quét xuống từ y_max (chỉ gọi cho cột biên → rẻ).
## kind: 0=water, 1=lava, -1=bất kỳ.
static func _nb_water_top(bd: _BlockData, nb_data: Dictionary, cols: int,
		x: int, y_max: int, z: int, dx: int, dz: int, kind: int = -1) -> int:
	var nx: int = x + dx
	var nz: int = z + dz
	if nx >= 0 and nx < cols and nz >= 0 and nz < cols:
		for y in range(y_max, -1, -1):
			var b: int = bd.get_block(nx, y, nz)
			if _is_fluid_bid(b) and (kind < 0 or _fluid_kind(b) == kind):
				return y
		return -1
	var dir: String
	if nx < 0: dir = "w"
	elif nx >= cols: dir = "e"
	elif nz < 0: dir = "n"
	else: dir = "s"
	if not nb_data.has(dir):
		return -1
	var info: Dictionary = nb_data[dir]
	var nb_bd: _BlockData = info["bd"]
	var nb_cols: int = info["cols"]
	var tx: int = nx if dir == "w" or dir == "e" else x
	var tz: int = nz if dir == "n" or dir == "s" else z
	if nx < 0: tx = nb_cols - 1
	elif nx >= cols: tx = 0
	if nz < 0: tz = nb_cols - 1
	elif nz >= cols: tz = 0
	if tx < 0 or tx >= nb_cols or tz < 0 or tz >= nb_cols:
		return -1
	for y in range(y_max, -1, -1):
		if _is_fluid_bid(nb_bd.get_block(tx, y, tz)):
			return y
	return -1

## ── rebuild_water_mesh: chỉ rebuild water mesh ───────────────────────────────
func rebuild_water_mesh() -> void:
	if block_data == null: return
	var h_vox := _Data.VOXEL * 0.5
	var half := _size * 0.5
	var nb_data := _get_neighbor_water_data()
	var mesh := _build_water_mesh(block_data, _cols, _dimension_id, h_vox, half, nb_data, _max_water_ly)
	_has_water = mesh != null
	if not _has_water:
		_max_water_ly = -1
	if _water_mesh_instance != null and is_instance_valid(_water_mesh_instance):
		_water_mesh_instance.mesh = mesh
	else:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = mesh
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		if _mesh_container != null:
			_mesh_container.add_child(mi_w)
		else:
			add_child(mi_w)
		_water_mesh_instance = mi_w
	# Nước đổi → độ ẩm đất tơi xốp đổi theo
	rebuild_soil_mesh()

## ── refresh_boundary_water: rebuild water mesh của chunk + 4 lân cận ────────
func refresh_boundary_water() -> void:
	# Thu thập jobs (chunk này + lân cận có nước) trên main thread — chỉ vài
	# lookup dictionary, rẻ. MESH BUILD CHẠY TRÊN WORKER (WaterRebuildQueue dùng
	# WorkerThreadPool, giống terrain mesh trong compute_chunk); hàm này chỉ đẩy
	# job với refs dữ liệu — worker giữ reference block_data nên an toàn teardown.
	var parent := get_parent()
	var chunks: Dictionary
	if parent != null and "_chunks" in parent:
		chunks = parent._chunks
	else:
		return
	var jobs: Array = []
	var seen: Dictionary = {}
	_collect_water_job(chunks, self, jobs, seen)
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var key := Vector2i(_cx + off.x, _cz + off.y)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				_collect_water_job(chunks, nb, jobs, seen)
	if jobs.is_empty():
		return
	if is_instance_valid(WaterRebuildQueue):
		WaterRebuildQueue.push_jobs(jobs)

## Gom 1 job rebuild water mesh của chunk `c` (nếu có nước) + refs lân cận.
## Chạy trên main thread — chỉ đọc refs, không lock.
static func _collect_water_job(chunks: Dictionary, c: WorldChunk, jobs: Array, seen: Dictionary) -> void:
	var id := c.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	if not c._has_water or c.block_data == null:
		return
	var nb: Dictionary = {}
	for d in [["w", c._cx - 1, c._cz], ["e", c._cx + 1, c._cz], ["n", c._cx, c._cz - 1], ["s", c._cx, c._cz + 1]]:
		var key := Vector2i(d[1], d[2])
		if chunks.has(key):
			var nb_chunk := chunks[key] as WorldChunk
			if nb_chunk and nb_chunk.block_data:
				nb[d[0]] = {"bd": nb_chunk.block_data, "cols": nb_chunk._cols}
	jobs.append({
		"inst_id": id,
		"bd": c.block_data,
		"cols": c._cols,
		"dim_id": c._dimension_id,
		"max_ly": c._max_water_ly,
		"h_vox": _Data.VOXEL * 0.5,
		"half": c._size * 0.5,
		"nb": nb,
	})

## Build 1 water mesh từ job data.
static func _build_water_mesh_job(job: Dictionary) -> ArrayMesh:
	return _build_water_mesh(job["bd"], job["cols"], job["dim_id"],
		job["h_vox"], job["half"], job["nb"], job["max_ly"])

## Main thread — gán mesh rebuild sẵn lên MeshInstance3D (mesh được WaterRebuildQueue
## build trên worker thread; hàm này chỉ gán, không build).
func _apply_water_mesh(mesh: ArrayMesh) -> void:
	if not is_inside_tree() or block_data == null:
		return
	_has_water = mesh != null and mesh.get_surface_count() > 0
	if not _has_water:
		_max_water_ly = -1
	if _water_mesh_instance != null and is_instance_valid(_water_mesh_instance):
		_water_mesh_instance.mesh = mesh
	else:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = mesh
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		if _mesh_container != null:
			_mesh_container.add_child(mi_w)
		else:
			add_child(mi_w)
		_water_mesh_instance = mi_w
	rebuild_soil_mesh()

## ── Materials ─────────────────────────────────────────────────────────────────
func _make_water_shader(dim_id: int) -> ShaderMaterial:
	var s := Shader.new()
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		# Vertex color: R = water_level/8 (density 0..1), G/B unused
		s.code = """
shader_type spatial;
render_mode blend_mix;
uniform vec4 shallow_color : source_color = vec4(0.15, 0.70, 0.60, 0.78);
uniform vec4 deep_color    : source_color = vec4(0.02, 0.18, 0.45, 0.92);
uniform float wave_speed = 1.0;
uniform float wave_height = 0.0;
uniform float wave_freq = 8.0;
uniform bool low_quality = false;

void vertex() {
	if (wave_height > 0.001) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float w1 = sin(TIME * wave_speed + world_pos.x * wave_freq + world_pos.z * wave_freq * 0.7) * wave_height;
		float w2 = sin(TIME * wave_speed * 1.7 + world_pos.x * wave_freq * 1.3 + world_pos.z * wave_freq * 0.9) * wave_height * 0.5;
		float w3 = sin(TIME * wave_speed * 2.4 + world_pos.x * wave_freq * 0.6 + world_pos.z * wave_freq * 1.5) * wave_height * 0.3;
		VERTEX.y += w1 + w2 + w3;
	}
}

void fragment() {
	float density = COLOR.r;
	vec3 water_col = mix(deep_color.rgb, shallow_color.rgb, density);
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wuv = world_pos.xz * 3.0;
	float caustic;
	if (low_quality) {
		caustic = max(0.0, sin(wuv.x * 3.0 + TIME * 1.2) * 0.06 + 0.06);
	} else {
		float c1 = sin(wuv.x * 4.0 + TIME * 1.2) * cos(wuv.y * 3.5 + TIME * 0.9);
		float c2 = sin(wuv.x * 6.0 - TIME * 1.5) * cos(wuv.y * 5.0 + TIME * 1.1);
		caustic = max(0.0, c1 * c2 * 0.12);
	}
	vec3 refl = vec3(0.55, 0.72, 0.90) * 0.06;
	vec3 final_col = water_col + refl + caustic;
	ALBEDO = final_col;
	ALPHA = mix(deep_color.a, shallow_color.a, density);
	ROUGHNESS = mix(0.05, 0.25, density);
	METALLIC = mix(0.05, 0.0, density);
	SPECULAR = 0.3;
}
"""
	else:
		s.code = """
shader_type spatial;
render_mode blend_mix, unshaded;
uniform vec4 water_color : source_color = vec4(0.10, 0.55, 0.45, 0.88);
uniform vec4 emit_color  : source_color = vec4(0.08, 0.45, 0.35, 1.0);
uniform float wave_speed = 1.0;
uniform float wave_height = 0.0;
uniform float wave_freq = 6.0;

void vertex() {
	if (wave_height > 0.001) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float w1 = sin(TIME * wave_speed + world_pos.x * wave_freq + world_pos.z * wave_freq * 0.7) * wave_height;
		float w2 = sin(TIME * wave_speed * 1.7 + world_pos.x * wave_freq * 1.3 + world_pos.z * wave_freq * 0.9) * wave_height * 0.5;
		float w3 = sin(TIME * wave_speed * 2.4 + world_pos.x * wave_freq * 0.6 + world_pos.z * wave_freq * 1.5) * wave_height * 0.3;
		VERTEX.y += w1 + w2 + w3;
	}
}

void fragment() {
	float density = COLOR.r;
	vec4 base = mix(vec4(water_color.rgb * 0.5, water_color.a + 0.1), water_color, density);
	ALBEDO = base.rgb; ALPHA = base.a;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	EMISSION = emit_color.rgb * (1.5 + sin(TIME * 0.5 + wp.x * 2.0 + wp.z * 3.0) * 0.5);
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	var is_mob: bool = DeviceManager != null and DeviceManager.is_mobile()
	m.set_shader_parameter("low_quality", is_mob)
	return m

## ── Lava shader — cam nóng rực, sóng nhanh, phát sáng mạnh (unshaded) ─────
func _make_lava_shader(dim_id: int) -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode blend_mix, unshaded, depth_prepass_alpha;
uniform vec4 lava_color : source_color = vec4(0.92, 0.28, 0.08, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.62, 0.16, 1.0);
uniform float wave_speed = 1.6;
uniform float wave_height = 0.0;
uniform float wave_freq = 8.0;

void vertex() {
	if (wave_height > 0.001) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float w1 = sin(TIME * wave_speed + world_pos.x * wave_freq + world_pos.z * wave_freq * 0.7) * wave_height;
		float w2 = sin(TIME * wave_speed * 1.7 + world_pos.x * wave_freq * 1.3 + world_pos.z * wave_freq * 0.9) * wave_height * 0.5;
		float w3 = sin(TIME * wave_speed * 2.4 + world_pos.x * wave_freq * 0.6 + world_pos.z * wave_freq * 1.5) * wave_height * 0.3;
		VERTEX.y += w1 + w2 + w3;
	}
}

void fragment() {
	float density = COLOR.r;
	vec4 base = mix(vec4(lava_color.rgb * 0.55, lava_color.a), lava_color, density);
	ALBEDO = base.rgb; ALPHA = base.a;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Đốm đỏ nóng di chuyển theo thời gian — cảm giác dung nham chảy
	float e1 = sin(TIME * 1.2 + wp.x * 3.0 + wp.z * 2.5);
	float e2 = sin(TIME * 1.8 + wp.x * 2.2 - wp.z * 3.4);
	float em = max(0.0, e1 * e2);
	EMISSION = ember_color.rgb * (2.0 + em * 2.5) + vec3(0.30, 0.08, 0.02) * (1.0 - density);
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	var is_mob: bool = DeviceManager != null and DeviceManager.is_mobile()
	m.set_shader_parameter("low_quality", is_mob)
	return m

static var _mat_cache: Dictionary = {}

## ── Cache dùng chung cho grass/rêu: 1 BoxMesh + 1 ShaderMaterial (sway) ──────
## Mỗi chunk trước đây tự tạo BoxMesh + material mới → D3D12 phải compile
## shader pipeline mỗi lần chunk mới stream vào (stutter ~100-300ms). Dùng chung
## 1 resource cho mọi chunk → GPU pipeline cache hit, giảm hẳn spike khi lướt.
static var _grass_box: BoxMesh = null
static var _grass_mat: ShaderMaterial = null

static func _get_grass_resources() -> Array:
	if _grass_box == null:
		_grass_box = BoxMesh.new()
		_grass_box.size = Vector3.ONE
	if _grass_mat == null:
		_grass_mat = ShaderMaterial.new()
		_grass_mat.shader = load("res://scripts/world/chunk/grass.gdshader")
	return [_grass_box, _grass_mat]

## Khởi tạo grass resources trên MAIN thread trước khi chunk worker chạm tới —
## tránh race lazy-init static khi nhiều worker cùng gọi _get_grass_resources.
static func prewarm_grass_resources() -> void:
	_get_grass_resources()

## ── Cache dùng chung cho làng/cầu voxel (shaded): 1 BoxMesh + 1 material ────
static var _village_box: BoxMesh = null
static var _village_mat: StandardMaterial3D = null

static func _get_village_resources() -> Array:
	if _village_box == null:
		_village_box = BoxMesh.new()
		_village_box.size = Vector3.ONE
	if _village_mat == null:
		_village_mat = StandardMaterial3D.new()
		_village_mat.vertex_color_use_as_albedo = true
		_village_mat.metallic = 0.0
		_village_mat.roughness = 0.85
	return [_village_box, _village_mat]
var _fade_state: bool = false  # per-instance: chunk này có đang dùng terrain_fade không

## ── Terrain fade (x-ray) khi player ở dưới lòng đất ─────────────────────────
## Chỉ làm mờ LỚP ĐẤT TRỰC TIẾP quanh player (một ống nhỏ trên đầu) để người
## chơi thấy rõ khoảng hang/hành lang do mình đào — KHÔNG tạo vùng xám rộng
## cả chục mét làm lộ ranh giới chunk. Ngoài ống này địa hình giữ nguyên đặc.
static func _make_terrain_fade_mat(dim_id: int) -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode blend_mix;
uniform vec3 fade_center = vec3(0.0, 0.0, 0.0);   // player position (world)
uniform float fade_radius = 3.0;                  // bán kính ống làm mờ (m)
uniform float fade_bottom = 0.0;                  // mốc bắt đầu mờ (phía dưới chân)
uniform float fade_top    = 1.8;                  // mốc mờ tối đa (phía trên đầu)

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
// Khoảng cách ngang tới player: trong ống thì rõ xuyên thấu, mép ống sắc gọn.
	float d = length(vec2(wp.x - fade_center.x, wp.z - fade_center.z));
	float inside = 1.0 - smoothstep(fade_radius * 0.5, fade_radius, d);
	// Block trên đầu → gần như trong suốt (alpha~0), dưới chân giữ đặc (1).
	float above = smoothstep(fade_bottom, fade_top, wp.y);
	float alpha = mix(1.0, 1.0 - above, inside);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	m.set_shader_parameter("fade_center", Vector3.ZERO)
	m.set_shader_parameter("fade_radius", 3.0)
	m.set_shader_parameter("fade_bottom", 0.0)
	m.set_shader_parameter("fade_top", 1.8)
	return m

## Cập nhật uniform chung của toàn bộ fade material (1 lần/frame).
static func set_fade_uniforms(dim_id: int, center: Vector3, radius: float,
		bottom: float, top: float) -> void:
	var fm := _mat_cache.get(dim_id, {}).get("terrain_fade", null) as ShaderMaterial
	if not is_instance_valid(fm):
		return
	fm.set_shader_parameter("fade_center", center)
	fm.set_shader_parameter("fade_radius", radius)
	fm.set_shader_parameter("fade_bottom", bottom)
	fm.set_shader_parameter("fade_top", top)

## Bật/tắt x-ray cho terrain mesh của chunk này (vật liệu dùng chung 1 shader).
func set_terrain_fade(fade: bool) -> void:
	_fade_state = fade
	if _terrain_mesh_instance == null or not is_instance_valid(_terrain_mesh_instance):
		return
	var cache: Dictionary = _mat_cache.get(_dimension_id, {})
	if fade and cache.has("terrain_fade"):
		_terrain_mesh_instance.material_override = cache["terrain_fade"]
	elif cache.has("terrain"):
		_terrain_mesh_instance.material_override = cache["terrain"]
func _init_materials() -> void:
	if _mat_cache.has(_dimension_id): return
	if _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		var m_t := StandardMaterial3D.new()
		m_t.vertex_color_use_as_albedo = true
		m_t.roughness = 0.9; m_t.metallic_specular = 0.0
		__cache_shaped_mat(_dimension_id, m_t)
	var m_t := StandardMaterial3D.new()
	m_t.vertex_color_use_as_albedo = true
	m_t.roughness = 1.0; m_t.metallic_specular = 0.0
	__cache_shaped_mat(_dimension_id, m_t)

## Tạo vật liệu 2 mặt (cull disabled) riêng cho shaped-block mesh — box hình
## nhỏ/quầy cần thấy cả mặt trong/mặt bên/mặt dưới khi xoay góc nhìn.
func __cache_shaped_mat(dim_id: int, m_t: StandardMaterial3D) -> void:
	var m_shaped := m_t.duplicate() as StandardMaterial3D
	m_shaped.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[dim_id] = { "terrain": m_t,
		"terrain_fade": _make_terrain_fade_mat(dim_id),
		"water": _make_water_shader(dim_id),
		"lava": _make_lava_shader(dim_id),
		"shaped": m_shaped }

## ── apply_chunk: nhận data từ thread, tạo nodes ──────────────────────────────
func apply_chunk(data: Dictionary) -> void:
	if _built:
		return
	if data.get("lod", false):
		# ── LOD chunk: 1 mesh thô duy nhất, cache riêng (không đè _mesh_cache) ──
		_is_lod = true
		_biome_grid = data["biome_grid"]
		_has_water = false
		_max_water_ly = -1
		_has_lava = false
		_has_ores = false
		_lod_mesh_cache[_cache_key(_cx, _cz, _dimension_id)] = data
		var mesh: ArrayMesh = data["mesh"]
		if mesh != null:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _mat_cache[_dimension_id]["terrain"]
			add_child(mi)
			_terrain_mesh_instance = mi
		_built = true
		return
# ── Cache full chunk với block_data NÉN ──────────────────────────────────
	# `block_data_bytes` raw là 70656 B/chunk (32×69×32). Lưu bản nén (Deflate
	# ~600-1400 B, x50) vào `_mesh_cache` để cắt memory tồn — chunk có thể được
	# tải lại từ cache (setup cache-hit) nên vẫn cần bản bytes để dựng block_data.
	# Live `block_data` của chunk đang hiển thị giữ bản raw (gameplay đọc nhanh).
	compress_block_data(data)
	_mesh_cache[_cache_key(_cx, _cz, _dimension_id)] = data
	_biome_grid = data["biome_grid"]
	_has_water = data.get("has_water", false)
	_max_water_ly = _gen_water_top_layer() if _has_water else -1
	_has_lava = data.get("has_lava", false)
	_has_ores = data.get("has_ores", false)
	_top_ly_cache = data.get("top_ly_hint", PackedInt32Array())

	# Khôi phục block_data (giải nén nếu là bản nén trong cache)
	var bdbytes: PackedByteArray = data.get("block_data_bytes", PackedByteArray())
	if not bdbytes.is_empty():
		if data.get("bd_compressed", false):
			# Kích thước raw có thể là 1× (chunk cũ) hoặc 2× (có offsets nội-ô).
			# Decompress buffer đủ 2× để nhận cả 2 định dạng.
			bdbytes = bdbytes.decompress(
				_cols * _cols * _BlockData.CHUNK_H * 2, FileAccess.COMPRESSION_DEFLATE)
		block_data = _BlockData.new()
		block_data.from_bytes(bdbytes, _cols, _cols)

	var mesh: ArrayMesh = data["mesh"]
	if mesh == null:
		_built = true; return

	# ── Gom tất cả nodes vào 1 container, add_child 1 lần duy nhất ──────────
	# Mỗi add_child khi đã trong scene tree tốn kém vì trigger notification.
	# Tạo container ngoài tree → add hết children vào → add_child(container) 1 lần.
	var container := Node3D.new()

	# Xoá container cũ nếu có (phòng trường hợp apply_chunk gọi 2 lần)
	if _mesh_container != null:
		_mesh_container.queue_free()
		_mesh_container = null
	_terrain_mesh_instance = null
	_water_mesh_instance = null
	_aquatic_mesh_instance = null
	_lava_mesh_instance = null
	_textured_block_mesh_instances.clear()
	for light in _lotus_lights:
		LotusLightManager.unregister(light)
	_lotus_lights.clear()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if _fade_state and _mat_cache[_dimension_id].has("terrain_fade"):
		mi.material_override = _mat_cache[_dimension_id]["terrain_fade"]
	else:
		mi.material_override = _mat_cache[_dimension_id]["terrain"]
	container.add_child(mi)
	_terrain_mesh_instance = mi

	var water_mesh = data.get("water_mesh")
	if water_mesh:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = water_mesh
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		container.add_child(mi_w)
		_water_mesh_instance = mi_w

	var has_lava: bool = data.get("has_lava", false)
	_has_lava = has_lava
	var lava_mesh = data.get("lava_mesh")
	if lava_mesh:
		var mi_l := MeshInstance3D.new()
		mi_l.mesh = lava_mesh
		mi_l.material_override = _mat_cache[_dimension_id]["lava"]
		container.add_child(mi_l)
		_lava_mesh_instance = mi_l

	var aquatic_mesh = data.get("aquatic_mesh")
	if aquatic_mesh:
		var mi_aq := MeshInstance3D.new()
		mi_aq.mesh = aquatic_mesh
		if not _mat_cache[_dimension_id].has("aquatic"):
			_mat_cache[_dimension_id]["aquatic"] = make_aquatic_mat()
		mi_aq.material_override = _mat_cache[_dimension_id]["aquatic"]
		mi_aq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mi_aq)
		_aquatic_mesh_instance = mi_aq

	var textured_block_meshes: Dictionary = data.get("textured_block_meshes", {})
	for bid in textured_block_meshes:
		var ore_mesh: ArrayMesh = textured_block_meshes[bid] as ArrayMesh
		if ore_mesh:
			var mi_o := MeshInstance3D.new()
			mi_o.mesh = ore_mesh
			mi_o.material_override = _get_textured_block_material(bid)
			mi_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			container.add_child(mi_o)
			_textured_block_mesh_instances[bid] = mi_o

	# Block hình dạng riêng (đá ¼, đá ⅛, đá phiến) — dữ liệu worker tính sẵn
	_apply_shaped_block_data(data)
	_has_shaped_blocks = not _shaped_block_instances.is_empty()

	var grass_mm: MultiMesh = data.get("grass_multimesh")
	if grass_mm:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = grass_mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mmi)

	# Quán rượu — MultiMesh có bóng đổ
	var vbd: Dictionary = data.get("village_data", {})
	var vxforms: Array = vbd.get("xforms", [])
	if vxforms.size() > 0 and not _tavern_built:
		_tavern_built = true
		var tavern_parts := _build_tavern_mesh(vbd)
		container.add_child(tavern_parts[0])
		if tavern_parts[1] != null:
			container.add_child(tavern_parts[1])
		_attach_tavern_features(container, vbd, _cx, _cz, _size)

	var lotus_positions: Array[Vector3] = data.get("lotus_lights", [] as Array[Vector3])
	if lotus_positions.size() > MAX_LOTUS_PER_CHUNK:
		lotus_positions = lotus_positions.duplicate()
		lotus_positions.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return a.distance_squared_to(Vector3.ZERO) < b.distance_squared_to(Vector3.ZERO))
		lotus_positions = lotus_positions.slice(0, MAX_LOTUS_PER_CHUNK)
	for lpos in lotus_positions:
		var is_weed_light: bool = lpos.x > 400.0
		var real_pos := Vector3(lpos.x - (500.0 if is_weed_light else 0.0), lpos.y, lpos.z)
		var light := OmniLight3D.new()
		if is_weed_light:
			light.light_color      = Color(1.0, 0.82, 0.08)  # vàng quả
			light.light_energy     = 0.6
			light.omni_range       = 8.0
		else:
			light.light_color      = Color(0.45, 0.85, 1.0)  # xanh sen
			light.light_energy     = 0.30
			light.omni_range       = 12.0
		light.omni_attenuation = 2.5
		light.shadow_enabled   = false
		light.light_specular   = 0.0
		light.position         = real_pos + Vector3(0, 0.15, 0)
		container.add_child(light)
		_lotus_lights.append(light)

	# 1 add_child duy nhất vào scene tree → 1 notification thay vì N
	add_child(container)
	_mesh_container = container

	# Đăng ký lotus lights sau khi đã vào tree
	for light in _lotus_lights:
		LotusLightManager.register(light)

	# Collision: queue (chunk, mesh) — shape ĐƯỢC TẠO TRÊN MAIN THREAD trong
	# CollisionQueue._process (rate-limited).
	# KHÔNG tạo shape trên worker: create_trimesh_shape → physics server
	# (Jolt) — không thread-safe ở bản này — hư hỏng → crash 0xC0000005 lúc
	# process thoát (đã tái hiện tất định bằng test_probe_tex).
	# Lazy: chỉ đánh dấu pending — open_world_manager push trimesh cho chunk
	# gần player (bán kính 2) để giảm mạnh số shape phải dựng lúc boot/teleport
	# (mỗi trimesh ~6-12ms — cost theo body, không theo tris).
	if is_instance_valid(CollisionQueue):
		_collision_pending = true


	# Spawn đèn đường — dùng positions đã tính sẵn trên worker thread
	if _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		var lamp_positions: Array = data.get("lamp_positions", [])
		if not lamp_positions.is_empty():
			_RoadLamp.spawn_from_data(self, lamp_positions)

	# Spawn plant props (taro, seaweed, seagrass) — global budget shared toàn
	# game để tránh nhiều chunk cùng bắn prop nặng trong 1 frame. Sắp prop rẻ
	# (weed/seagrass) lên trước để cây nặng spawn sau khi budget còn.
	_prop_queue = data.get("plant_props", [])
	_prop_idx = 0
	if not _prop_queue.is_empty():
		set_process(true)

	_built = true

## Process prop queue — global budget để tránh spike khi nhiều chunk cùng stream.
## Budget chia sẻ toàn game; prop rẻ (weed/seagrass) ưu tiên spawn trước.
func _process(delta: float) -> void:
	if not props_enabled:
		_prop_queue = []
		_prop_idx = 0
		set_process(false)
		return
	# Chunk xa (Chebyshev > PROP_MERGE_RING): không dựng node DestroyableProp
	# mà đẩy toàn bộ proxy vào FarPropPool (data rẻ, 1 lần/frame). Gộp nhiều chunk
	# cùng loại vào 1 MultiMesh → cắt mạnh số node ở vòng ngoài (Bước 3).
	if _props_via_pool:
		var entries: Array = []
		# pd pos là LOCAL (gốc chunk) — pool render toàn cục (holder ở gốc thế
		# giới), phải dịch sang world: chunk.position = (cx*size, 0, cz*size).
		var wo := Vector3(_cx * _size, 0.0, _cz * _size)
		while _prop_idx < _prop_queue.size():
			var pd: Dictionary = _prop_queue[_prop_idx]
			_prop_idx += 1
			var proxy: Dictionary = _FarPropPool.proxy_for(
				pd.get("type", "weed"), String(pd.get("variant", "")), pd["pos"] + wo)
			entries.append(proxy)
		if not entries.is_empty():
			_FarPropPool.add_chunk(_cache_key(_cx, _cz, _dimension_id), entries)
		set_process(false)
		return
	_prop_reset_budget()
	if _prop_budget_remaining <= 0:
		return
	var count: int = mini(3, _prop_queue.size() - _prop_idx)
	for _i in range(count):
		if _prop_idx >= _prop_queue.size():
			break
		if _prop_budget_remaining <= 0:
			break
		var pd: Dictionary = _prop_queue[_prop_idx]
		_prop_idx += 1
		var ptype: String = pd.get("type", "weed")
		_prop_budget_remaining -= _prop_cost(ptype)
		if ptype == "palm":
			var prop := _PalmProp.new(150, DestroyableProp.WeaponReq.AXE, "log_palm")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "river"))
			_spawn_prop_child(prop)
		elif ptype == "oak":
			var prop := _OakProp.new(250, DestroyableProp.WeaponReq.AXE, "log_oak")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "plains"))
			_spawn_prop_child(prop)
		elif ptype == "cherry_bush":
			var prop := _PlainsBush.new(40, DestroyableProp.WeaponReq.SWORD, "cherry")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "plains"))
			_spawn_prop_child(prop)
		elif ptype == "orange_tree":
			var prop := _OrangeTreeProp.new(150, DestroyableProp.WeaponReq.AXE, "orange")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "plains"))
			_spawn_prop_child(prop)
		elif ptype == "dense_tree":
			var prop := _DenseTreeProp.new(200, DestroyableProp.WeaponReq.AXE, "log_hard_wood")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "plains"))
			_spawn_prop_child(prop)
		elif ptype == "eggplant":
			var prop := _EggplantProp.new(40, DestroyableProp.WeaponReq.SWORD, "eggplant_fruit")
			prop.position = pd["pos"]
			prop.setup()
			_spawn_prop_child(prop)
		elif ptype == "watermelon":
			var prop := _WatermelonVine.new(40, DestroyableProp.WeaponReq.SWORD, "watermelon")
			prop.position = pd["pos"]
			prop.setup()
			_spawn_prop_child(prop)
		elif ptype == "pumpkin":
			var prop := _PumpkinVine.new(40, DestroyableProp.WeaponReq.SWORD, "pumpkin")
			prop.position = pd["pos"]
			prop.setup()
			_spawn_prop_child(prop)
		elif ptype == "mangrove":
			var prop := _MangroveProp.new(220, DestroyableProp.WeaponReq.AXE, "log_mangrove")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "coast"))
			_spawn_prop_child(prop)
		elif ptype == "cattail":
			var prop := _CattailProp.new(30, DestroyableProp.WeaponReq.SWORD, "cattail")
			prop.position = pd["pos"]
			prop.setup()
			_spawn_prop_child(prop)
		elif ptype == "mud_crab":
			var creature := _MudCrabCreature.new()
			creature.position = pd["pos"]
			_spawn_prop_child(creature)
		elif ptype == "spruce":
			var prop := _FrostTreeProp.new(220, DestroyableProp.WeaponReq.AXE, "log_spruce")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "snow"))
			_spawn_prop_child(prop)
		elif ptype == "swamp_tree":
			var prop := _SwampTreeProp.new(220, DestroyableProp.WeaponReq.AXE, "log_swamp")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "marsh"))
			_spawn_prop_child(prop)
		elif ptype == "swamp_sedge":
			var prop := _SwampSedgeProp.new(30, DestroyableProp.WeaponReq.NONE, "swamp_sedge")
			prop.position = pd["pos"]
			prop.setup()
			_spawn_prop_child(prop)
		elif ptype == "duckweed":
			var prop := _DuckweedProp.new(10, DestroyableProp.WeaponReq.NONE, "duckweed")
			prop.position = pd["pos"]
			prop.setup()
			_spawn_prop_child(prop)
		elif ptype == "kelp_tall":
			var prop := _SeaPlantProp.new(45, DestroyableProp.WeaponReq.SWORD, ptype)
			prop.position = pd["pos"]
			prop.setup(ptype, pd.get("seed_h1", 0), pd.get("seed_h2", 0), float(pd.get("water_gap", 6.0)))
			_spawn_prop_child(prop)
		elif ptype == "sea_bush" or ptype == "grass_carpet" or ptype == "seaweed":
			var prop := _SeaPlantProp.new(60, DestroyableProp.WeaponReq.SWORD, ptype)
			prop.position = pd["pos"]
			prop.setup(ptype, pd.get("seed_h1", 0), pd.get("seed_h2", 0))
			_spawn_prop_child(prop)
		elif ptype == "coral" or ptype == "brain_coral" or ptype == "sponge" \
				or ptype == "kelp" or ptype == "sea_fan" or ptype == "anemone":
			var prop := _SeaPlantProp.new(45, DestroyableProp.WeaponReq.SWORD, ptype)
			prop.position = pd["pos"]
			prop.setup(ptype, pd.get("seed_h1", 0), pd.get("seed_h2", 0))
			_spawn_prop_child(prop)
		else:
			var drop_id: String = "tropical_seaweed" if ptype == "weed" \
				else ("taro" if ptype == "taro" else "seagrass")
			var prop := PlantProp.new(50, DestroyableProp.WeaponReq.SWORD, drop_id)
			prop.position = pd["pos"]
			prop.setup(ptype, pd.get("seed_h1", 0), pd.get("seed_h2", 0),
				pd.get("has_silt", false), pd.get("water_gap", 1.0),
				pd.get("meadow", false))
			_spawn_prop_child(prop)
	if _prop_idx >= _prop_queue.size():
		set_process(false)

	# Water flow tick (disabled — water is static blocks now)
	#_water_tick_timer -= delta
	#if _water_tick_timer <= 0.0:
	#	_water_tick_timer = 0.5
	#	var nb_data := _get_neighbor_water_data()
	#	if _WaterFlow.tick_flow(self, nb_data):
	#		rebuild_water_mesh()

## Ghi nhận node prop đã spawn vào _spawned_props để set_props_near(false) có thể
## hủy khi chunk chuyển sang pool, rồi mới add vào tree.
func _spawn_prop_child(prop: Node) -> void:
	_spawned_props.append(prop)
	add_child(prop)

## Chuyển chế độ props của chunk: `near==true` → spawn node tương tác; `false`
## → đưa toàn bộ proxy vào FarPropPool (gộp multi-chunk). Gọi bởi manager khi
## player băng qua vòng PROP_MERGE_RING. Chunk chưa có _prop_queue chỉ ghi cờ.
func set_props_near(near: bool) -> void:
	var want_pool: bool = not near
	if want_pool == _props_via_pool:
		return
	_props_via_pool = want_pool
	_prop_idx = 0
	# Hủy node props cũ (nếu đang near) — proxy sẽ được build lại ở _process.
	for p in _spawned_props:
		if is_instance_valid(p):
			p.queue_free()
	_spawned_props.clear()
	# Chuyển pool → near: bỏ proxy chunk này khỏi pool (chunk sẽ spawn node).
	if not want_pool:
		_FarPropPool.remove_chunk(_cache_key(_cx, _cz, _dimension_id))
	if not _prop_queue.is_empty():
		set_process(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Unregister lotus lights
		for light in _lotus_lights:
			if is_instance_valid(light):
				LotusLightManager.unregister(light)
		_lotus_lights.clear()
		# Xóa collision entries pending trong queue — tránh apply sau khi freed
		if CollisionQueue:
			CollisionQueue.remove_chunk(self)
		if WaterRebuildQueue:
			WaterRebuildQueue.clear_for_chunk(get_instance_id())
		# Evict mesh cache khi chunk bị free — chống phình bộ nhớ vô hạn khi
		# lướt thế giới (cache chỉ giữ dữ liệu chunk đang/đã load).
		if _was_setup:
			if _is_lod:
				_lod_mesh_cache.erase(_cache_key(_cx, _cz, _dimension_id))
			else:
				_mesh_cache.erase(_cache_key(_cx, _cz, _dimension_id))
				WorldChunk._unregister_chunk(_cx, _cz, _dimension_id)
		# Gỡ proxy chunk khỏi FarPropPool (nếu đã đưa vào) khi chunk bị free —
		# tránh pool giữ data chunk đã mất, phình vô hạn khi lướt thế giới.
		if _props_via_pool and not _prop_queue.is_empty():
			_FarPropPool.remove_chunk(_cache_key(_cx, _cz, _dimension_id))

func _apply_collision(shape: Shape3D) -> void:
	if not is_inside_tree(): return
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

## ── Decorative rebuild (async) for elements skipped in fast_mode ──────────
func _schedule_decorative_rebuild() -> void:
	if block_data == null or _biome_grid.is_empty():
		return
	var ck: String = _cache_key(_cx, _cz, _dimension_id)
	_pending_mutex.lock()
	_pending_chunks[ck] = self
	_pending_mutex.unlock()
	_track_task(WorkerThreadPool.add_task(
		_thread_rebuild_decorative.bind(ck, _cx, _cz, _size, _dimension_id),
		true, "decorative"))

static func _thread_rebuild_decorative(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	_pending_mutex.lock()
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	_pending_mutex.unlock()
	if chunk == null or not is_instance_valid(chunk) or not chunk.is_inside_tree():
		return
	chunk.call_deferred("apply_decorative", {
		"grass_blade_data": data.get("grass_blade_data", {}),
		"grass_multimesh": data.get("grass_multimesh"),
		"village_data": data.get("village_data", {}),
		"textured_block_meshes": data.get("textured_block_meshes", {}),
		"lamp_positions": data.get("lamp_positions", [])
	})

func apply_decorative(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	var container := _mesh_container
	if container == null:
		container = Node3D.new()
		add_child(container)
		_mesh_container = container

	var grass_mm: MultiMesh = data.get("grass_multimesh")
	if grass_mm:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = grass_mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mmi)

	var vbd: Dictionary = data.get("village_data", {})
	var vxforms: Array = vbd.get("xforms", [])
	if vxforms.size() > 0 and not _tavern_built:
		_tavern_built = true
		var tavern_parts := _build_tavern_mesh(vbd)
		container.add_child(tavern_parts[0])
		if tavern_parts[1] != null:
			container.add_child(tavern_parts[1])
		_attach_tavern_features(container, vbd, _cx, _cz, _size)

	var ore_meshes: Dictionary = data.get("textured_block_meshes", {})
	for bid in ore_meshes:
		var ore_mesh := ore_meshes[bid] as ArrayMesh
		if ore_mesh and not _textured_block_mesh_instances.has(bid):
			var mi_o := MeshInstance3D.new()
			mi_o.mesh = ore_mesh
			mi_o.material_override = _get_textured_block_material(bid)
			mi_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			container.add_child(mi_o)
			_textured_block_mesh_instances[bid] = mi_o

	var lamp_positions: Array = data.get("lamp_positions", [])
	if not lamp_positions.is_empty() and _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		_RoadLamp.spawn_from_data(self, lamp_positions)

## ── rebuild_mesh: gọi khi block thay đổi (mine/place) ────────────────────────
## Chỉ thay thế terrain mesh + collision, không đụng mesh khác (cỏ, nước, ...)
## `at` = local block vừa đổi — dùng để cập nhật _top_ly_cache O(1) thay vì scan lại
## Build lại terrain mesh. `at` = ô thay đổi (cập nhật top_ly 1 cột); nếu đưa
## `at_columns` (Array[Vector3i]) thì cập nhật top_ly nhiều cột — tránh full
## scan 70K ô (~25ms) khi đặt/bulk nhiều biome block.
func rebuild_mesh(at := Vector3i(-1, -1, -1), at_columns: Array = []) -> void:
	if block_data == null: return

	# Cập nhật cache top layer cho column bị thay đổi
	if at_columns.size() > 0 and _top_ly_cache.size() == _cols * _cols:
		for c in at_columns:
			var blk: Vector3i = c
			if blk.x >= 0 and blk.x < _cols and blk.z >= 0 and blk.z < _cols:
				_update_top_ly_cache(blk)
	elif at.x >= 0 and _top_ly_cache.size() == _cols * _cols \
			and at.x < _cols and at.z < _cols:
		_update_top_ly_cache(at)
	else:
		# Fallback (save reload, ...) — scan lại toàn bộ
		_top_ly_cache = _build_top_ly_cache()

	# Xóa collision cũ
	for ch in get_children():
		if ch is StaticBody3D:
			ch.queue_free()

	# Xóa terrain mesh cũ, giữ nguyên mesh khác (cỏ, nước, thuỷ sinh, ...)
	if _terrain_mesh_instance != null and is_instance_valid(_terrain_mesh_instance):
		_terrain_mesh_instance.queue_free()
		_terrain_mesh_instance = null

	# Xóa overlay mesh instances cũ (ore blocks) — nay đã bake vào terrain mesh
	for bid in _textured_block_mesh_instances:
		var old := _textured_block_mesh_instances[bid]
		if is_instance_valid(old):
			old.queue_free()
	_textured_block_mesh_instances.clear()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Terrain.build_terrain_mesh(st, block_data, _cols, _dimension_id, _top_ly_cache)
	var mesh := st.commit()
	if mesh == null: return

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# Khôi phục đúng material state: underground fade → fade, còn lại → terrain
	if _fade_state and _mat_cache[_dimension_id].has("terrain_fade"):
		mi.material_override = _mat_cache[_dimension_id]["terrain_fade"]
	else:
		mi.material_override = _mat_cache[_dimension_id]["terrain"]
	if _mesh_container != null:
		_mesh_container.add_child(mi)
	else:
		add_child(mi)
	_terrain_mesh_instance = mi

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)

	# Rebuild textured block (ore) overlay meshes — scan lại từ block_data
	# (không dùng cờ _has_ores: ore đặt tay vào chunk chưa từng có ore sẽ bị mất texture)
	var max_top_ly: int = -1
	if _top_ly_cache.size() == _cols * _cols:
		max_top_ly = 0
		for ly_v in _top_ly_cache:
			max_top_ly = maxi(max_top_ly, ly_v)
	var ore_meshes := _build_textured_block_meshes(block_data, _cols, max_top_ly)
	_has_ores = not ore_meshes.is_empty()
	for bid in ore_meshes:
		var ore_mesh: ArrayMesh = ore_meshes[bid]
		if ore_mesh:
			var mi_o := MeshInstance3D.new()
			mi_o.mesh = ore_mesh
			mi_o.material_override = _get_textured_block_material(bid)
			mi_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if _mesh_container != null:
				_mesh_container.add_child(mi_o)
			else:
				add_child(mi_o)
			_textured_block_mesh_instances[bid] = mi_o

	# Rebuild đất tơi xốp overlay (ẩm/khô theo nước lân cận)
	rebuild_soil_mesh()

	_build_shaped_block_nodes()

	block_data.dirty = false

## ── Block có hình dạng riêng (đá ¼, đá ⅛, đá phiến mỏng...) ─────────────────
## Scan block_data, vẽ hộp nhỏ theo kích thước shape + collision riêng (hộp).
## Shape block KHÔNG vào heightmap/terrain mesh — vẽ đè lên như overlay.
## Block hình dạng riêng (đá ¼, đá ⅛, đá phiến). Scan thẳng PackedByteArray
## (bỏ 70K lời gọi get_block + bounds-check), gộp MỌI collider vào 1 StaticBody3D
## và dùng chung 3 BoxShape3D — trước đây mỗi block tạo 1 body + 1 shape mới
## ngay trên main thread (chunk đã trong tree → đăng ký physics Jolt từng body).
var _shaped_collider: StaticBody3D = null

## ── Build shaped-block overlay mesh + danh sách hộp collider (CHẠY TRÊN WORKER) ──
## Scan toàn bộ block_data tốn ~30ms (đo test_stream_profile) — tách khỏi main
## thread để apply_chunk không gây giật khi load chunk. Main thread chỉ nhận
## mesh có sẵn + tạo StaticBody3D từ danh sách hộp (nhanh).
static func _empty_shaped_data() -> Dictionary:
	return { "shaped_mesh": null, "shaped_pos": PackedVector3Array(), "shaped_size": PackedVector3Array() }

static func _build_shaped_block_data(bd: _BlockData, cols: int, dim_id: int) -> Dictionary:
	var use_rw: bool = dim_id == _Data._Dim.DimensionID.REAL_WORLD
	var colors: Array[Color] = _Data.BLOCK_COLORS_RW if use_rw else _Data.BLOCK_COLORS_TW
	var half: float = float(cols) * _Data.VOXEL * 0.5
	var raw: PackedByteArray = bd._data
	var raw_h: int = bd._chunk_h
	var raw_w: int = bd.size_z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos_data := PackedVector3Array()
	var size_data := PackedVector3Array()
	for x in range(cols):
		var xbase: int = x * raw_h * raw_w
		var wx: float = -half + (float(x) + 0.5) * _Data.VOXEL
		for z in range(cols):
			var wz: float = -half + (float(z) + 0.5) * _Data.VOXEL
			for ly in range(raw_h):
				var blk: int = raw[xbase + ly * raw_w + z]
				var shape: Vector3 = _Data.block_shape(blk)
				if shape == Vector3.ZERO:
					continue
				var off: int = bd.get_offset(x, ly, z)
				var off_d := _BlockData.offset_delta(off)
				var bottom: float = float(ly + _BlockData.Y_MIN) * _BlockData.SLAB_HEIGHT
				var pos := Vector3(wx + off_d.x, bottom + shape.y * 0.5, wz + off_d.y)
				# Box lệch tâm không gộp mặt (mask 0) để tránh bỏ mặt thừa khi
				# 2 box lệch nhau không thực sự dính toàn mặt.
				var mask := 0 if off != _BlockData.OFF_CENTER else _shaped_face_mask(raw, raw_h, raw_w, x, ly, z, blk, shape)
				_add_shaped_box(st, pos, shape, colors[blk], mask)
				pos_data.append(pos)
				size_data.append(shape)
	var mesh: ArrayMesh = null
	if pos_data.size() > 0:
		mesh = st.commit()
	return { "shaped_mesh": mesh, "shaped_pos": pos_data, "shaped_size": size_data }

## ── Áp dụng shaped-block data đã tính sẵn trên worker (main thread) ──────────
## Chỉ tạo MeshInstance3D + 1 StaticBody3D gộp mọi hộp — KHÔNG scan block_data.
func _apply_shaped_block_data(data: Dictionary) -> void:
	for mi in _shaped_block_instances:
		if is_instance_valid(mi):
			mi.queue_free()
	_shaped_block_instances.clear()
	if _shaped_collider != null:
		if is_instance_valid(_shaped_collider):
			_shaped_collider.queue_free()
		_shaped_collider = null
	var smesh: ArrayMesh = data.get("shaped_mesh")
	if smesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = smesh
		mi.material_override = _mat_cache[_dimension_id].get("shaped", _mat_cache[_dimension_id]["terrain"])
		if _mesh_container != null:
			_mesh_container.add_child(mi)
		else:
			add_child(mi)
		_shaped_block_instances.append(mi)
	var pos: PackedVector3Array = data.get("shaped_pos", PackedVector3Array())
	if pos.size() == 0:
		return
	var size: PackedVector3Array = data.get("shaped_size", PackedVector3Array())
	var shape_cache: Dictionary = {}
	var body := StaticBody3D.new()
	for i in range(pos.size()):
		var skey: String = "%.2f|%.2f|%.2f" % [size[i].x, size[i].y, size[i].z]
		var bs: BoxShape3D = shape_cache.get(skey)
		if bs == null:
			bs = BoxShape3D.new()
			bs.size = size[i]
			shape_cache[skey] = bs
		var cs := CollisionShape3D.new()
		cs.shape = bs
		cs.position = pos[i]
		body.add_child(cs)
	body.name = "ShapedPhysics"
	add_child(body)
	_shaped_collider = body

## Bản dùng cho rebuild_mesh (khi player phá/đặt block) — hiếm, giữ scan trên
## main thread. Load chunk thường dùng _apply_shaped_block_data (worker tính sẵn).
func _build_shaped_block_nodes() -> void:
	if block_data == null or not _has_shaped_blocks:
		return
	_apply_shaped_block_data(_build_shaped_block_data(block_data, _cols, _dimension_id))
	_has_shaped_blocks = not _shaped_block_instances.is_empty()

## Mask các mặt cần bỏ khi box cùng loại chạm nhau liền kề (tránh z-fight /
## mặt thừa giữa các tường/platform cùng block xếp sát). Bỏ mặt chỉ khi box
## lấp kín cả ô theo hướng đó (shape đầy cell) → 2 box thật sự dính nhau.
const _F_BOT := 1
const _F_TOP := 2
const _F_NZ := 4
const _F_PZ := 8
const _F_NX := 16
const _F_PX := 32

static func _shaped_face_mask(raw: PackedByteArray, raw_h: int, raw_w: int,
		x: int, ly: int, z: int, blk: int, shape: Vector3) -> int:
	var mask := 0
	var row: int = raw_h * raw_w
	var idx: int = x * row + ly * raw_w + z
	if shape.y >= _BlockData.SLAB_HEIGHT:
		if ly > 0 and raw[idx - raw_w] == blk:
			mask |= _F_BOT
		if ly + 1 < raw_h and raw[idx + raw_w] == blk:
			mask |= _F_TOP
	if shape.x >= _Data.VOXEL:
		if x > 0 and raw[idx - row] == blk:
			mask |= _F_NX
		if x + 1 < raw_w and raw[idx + row] == blk:
			mask |= _F_PX
	if shape.z >= _Data.VOXEL:
		if z > 0 and raw[idx - 1] == blk:
			mask |= _F_NZ
		if z + 1 < raw_w and raw[idx + 1] == blk:
			mask |= _F_PZ
	return mask

## Vẽ hộp 6 mặt bằng màu block (top sáng, side tối, đáy tối nhất). `mask` cho
## phép bỏ mặt dính với block cùng loại × `size` đầy ô (đã merge các platform).
static func _add_shaped_box(st: SurfaceTool, center: Vector3, size: Vector3,
		top_col: Color, mask: int = 0) -> void:
	var h: Vector3 = size * 0.5
	var side_col := _Data.block_side_color(top_col)
	var bot_col := Color(top_col.r * 0.35, top_col.g * 0.35, top_col.b * 0.35, top_col.a)
	if not mask & _F_TOP:
		_Terrain._add_quad(st, center + Vector3(0, h.y, 0),
			Vector3(h.x, 0, 0), Vector3(0, 0, h.z), Vector3(0, 1, 0), top_col)
	if not mask & _F_BOT:
		_Terrain._add_quad(st, center - Vector3(0, h.y, 0),
			Vector3(h.x, 0, 0), Vector3(0, 0, h.z), Vector3(0, -1, 0), bot_col)
	if not mask & _F_PZ:
		_Terrain._add_quad(st, center + Vector3(0, 0, h.z),
			Vector3(h.x, 0, 0), Vector3(0, h.y, 0), Vector3(0, 0, 1), side_col)
	if not mask & _F_NZ:
		_Terrain._add_quad(st, center - Vector3(0, 0, h.z),
			Vector3(h.x, 0, 0), Vector3(0, h.y, 0), Vector3(0, 0, -1), side_col)
	if not mask & _F_PX:
		_Terrain._add_quad(st, center + Vector3(h.x, 0, 0),
			Vector3(0, 0, h.z), Vector3(0, h.y, 0), Vector3(1, 0, 0), side_col)
	if not mask & _F_NX:
		_Terrain._add_quad(st, center - Vector3(h.x, 0, 0),
			Vector3(0, 0, h.z), Vector3(0, h.y, 0), Vector3(-1, 0, 0), side_col)

## ── Cập nhật _top_ly_cache cho 1 column sau khi block đổi ────────────────────
func _update_top_ly_cache(at: Vector3i) -> void:
	var idx := at.x * _cols + at.z
	var old_top: int = _top_ly_cache[idx]
	var blk := block_data.get_block(at.x, at.y, at.z)
	if blk != _Data.BlockID.AIR and not _is_water_bid(blk) \
			and not _Data.is_shaped_block(blk):
		# Block solid mới — nâng top nếu đặt cao hơn bề mặt hiện tại
		_top_ly_cache[idx] = maxi(old_top, at.y)
	elif at.y >= old_top:
		# Block trên đỉnh bị phá / thay bằng air/water — tìm top solid mới
		var ly := at.y - 1
		while ly >= 0:
			var b := block_data.get_block(at.x, ly, at.z)
			if b != _Data.BlockID.AIR and not _is_water_bid(b) \
					and not _Data.is_shaped_block(b):
				break
			ly -= 1
		_top_ly_cache[idx] = ly
	# else: phá block dưới đỉnh → top không đổi

## ── Build lại toàn bộ top_ly cache từ block_data (fallback hiếm gặp) ─────────
func _build_top_ly_cache() -> PackedInt32Array:
	var cache := PackedInt32Array()
	cache.resize(_cols * _cols)
	for x in range(_cols):
		for z in range(_cols):
			var top := -1
			for ly in range(_BlockData.CHUNK_H - 1, -1, -1):
				var blk := block_data.get_block(x, ly, z)
				if blk != _Data.BlockID.AIR and not _is_water_bid(blk) \
						and not _Data.is_shaped_block(blk):
					top = ly
					break
			cache[x * _cols + z] = top
	return cache

## ── Block API (dùng cho building / mining) ───────────────────────────────────
## Đổi tọa độ world → local block index, rồi set_block + rebuild
func world_to_local_block(wx: float, wy: float, wz: float) -> Vector3i:
	var half: float = _size * 0.5
	var lx: int = int(floor(wx - (global_position.x - half)))
	var lz: int = int(floor(wz - (global_position.z - half)))
	var ly: int = _BlockData.world_y_to_layer(wy)
	return Vector3i(lx, ly, lz)

## Offset nội-ô của block tại world position (OFF_CENTER nếu không có / không đặt
## lệch). Dùng để ép block mới sát cạnh block cũ khi build.
func get_block_offset_at(wx: float, wy: float, wz: float) -> int:
	if block_data == null: return _BlockData.OFF_CENTER
	var blk := world_to_local_block(wx, wy, wz)
	return block_data.get_offset(blk.x, blk.y, blk.z)

## Phá block tại world position. Trả về block_id đã xoá (0 = không có gì).
## BEDROCK không thể phá vỡ. WATER có thể phá (múc).
func break_block_at(wx: float, wy: float, wz: float) -> int:
	if block_data == null: return 0
	var blk := world_to_local_block(wx, wy, wz)
	var old_id: int = block_data.get_block(blk.x, blk.y, blk.z)
	if old_id == _Data.BlockID.AIR: return 0
	if old_id == _Data.BlockID.BEDROCK: return 0   # Bedrock không thể phá vỡ
	block_data.set_block(blk.x, blk.y, blk.z, _Data.BlockID.AIR)
	_water_tick_timer = 0.0
	if _is_water_bid(old_id):
		rebuild_water_mesh()
	elif _Data.is_shaped_block(old_id):
		request_shaped_rebuild()
	else:
		request_biome_rebuild([blk])
	# Kích hoạt water tick ở chunk lân cận nếu block ở biên
	_trigger_neighbor_water_tick(blk.x, blk.z)
	return old_id

## ── Rebuild terrain ASYNC (biome block place/break) ─────────────────────────
## Terrain rebuild full ~50ms. Thay vì chạy đồng bộ gây giật mỗi lần đặt/đào
## block đất/đá/cỏ, ta: cập nhật top_ly NGAY (rẻ) → dựng terrain/ore/shaped
## mesh trong WorkerThreadPool → áp vào main qua call_deferred (chỉ commit ~1ms
## + trimesh ~2ms + swap node). Nhiều edit trong cùng khoảng build → 1 rebuild
## (coalesce qua _rebuild_dirty_again).
var _rebuild_scheduled: bool = false
var _rebuild_dirty_again: bool = false

func request_biome_rebuild(ats: Array) -> void:
	if block_data == null:
		return
	if _top_ly_cache.size() == _cols * _cols:
		for c in ats:
			var blk: Vector3i = c
			if blk.x >= 0 and blk.x < _cols and blk.z >= 0 and blk.z < _cols:
				_update_top_ly_cache(blk)
	else:
		_top_ly_cache = _build_top_ly_cache()
	if _rebuild_scheduled:
		_rebuild_dirty_again = true
		return
	_rebuild_scheduled = true
	var snap_bd := _BlockData.new()
	snap_bd.init(_cols, _cols)
	snap_bd._data = block_data._data.duplicate()
	snap_bd._off = block_data._off.duplicate()
	var snap_top: PackedInt32Array = _top_ly_cache.duplicate()
	_track_task(WorkerThreadPool.add_task(
		_thread_biome_rebuild.bind(self, snap_bd, snap_top, _cols, _dimension_id),
		true, "biome_rebuild"))

static func _thread_biome_rebuild(chunk: Node, snap_bd: _BlockData, snap_top: PackedInt32Array,
		cols: int, dim_id: int) -> void:
	var payload := {}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Terrain.build_terrain_mesh(st, snap_bd, cols, dim_id, snap_top, false)
	payload["terrain_mesh"] = st.commit()
	var max_top := 0
	if snap_top.size() == cols * cols:
		for v in snap_top:
			max_top = maxi(max_top, v)
	payload["ore_meshes"] = _build_textured_block_meshes(snap_bd, cols, max_top)
	payload["shaped"] = _build_shaped_block_data(snap_bd, cols, dim_id)
	if chunk == null or not is_instance_valid(chunk) or not chunk.is_inside_tree():
		return
	chunk.call_deferred("_apply_biome_rebuild", payload)

func _apply_biome_rebuild(payload: Dictionary) -> void:
	_rebuild_scheduled = false
	if block_data == null or not is_inside_tree():
		return
	# Xoá collision + terrain mesh cũ (giữ overlay nước/cỏ/thuỷ sinh)
	for ch in get_children():
		if ch is StaticBody3D:
			ch.queue_free()
	if _terrain_mesh_instance != null and is_instance_valid(_terrain_mesh_instance):
		_terrain_mesh_instance.queue_free()
		_terrain_mesh_instance = null
	var tm: ArrayMesh = payload.get("terrain_mesh")
	if tm == null:
		_rebuild_dirty_again = false
		return
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	if _fade_state and _mat_cache[_dimension_id].has("terrain_fade"):
		mi.material_override = _mat_cache[_dimension_id]["terrain_fade"]
	else:
		mi.material_override = _mat_cache[_dimension_id]["terrain"]
	if _mesh_container != null:
		_mesh_container.add_child(mi)
	else:
		add_child(mi)
	_terrain_mesh_instance = mi
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = tm.create_trimesh_shape()
	body.add_child(col)
	add_child(body)
	# Ore overlay (textured block)
	for bid in _textured_block_mesh_instances:
		var old := _textured_block_mesh_instances[bid]
		if is_instance_valid(old):
			old.queue_free()
	_textured_block_mesh_instances.clear()
	var ore: Dictionary = payload.get("ore_meshes", {})
	for bid in ore:
		var om: ArrayMesh = ore[bid]
		if om == null:
			continue
		var mi_o := MeshInstance3D.new()
		mi_o.mesh = om
		mi_o.material_override = _get_textured_block_material(bid)
		mi_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _mesh_container != null:
			_mesh_container.add_child(mi_o)
		else:
			add_child(mi_o)
		_textured_block_mesh_instances[bid] = mi_o
	rebuild_soil_mesh()
	_apply_shaped_block_data(payload.get("shaped", {}))
	_has_shaped_blocks = not _shaped_block_instances.is_empty()
	block_data.dirty = false
	if _rebuild_dirty_again:
		_rebuild_dirty_again = false
		request_biome_rebuild([])

## ── Shaped rebuild ASYNC (platform/tường/đá tay đặt) ────────────────────────
## Tương tự biome: dựng shaped overlay data trong worker, áp main qua deferred
## (xoá micro-stutter ~17ms khi đặt platform). Coalesce edit liên tiếp.
var _shaped_scheduled: bool = false
var _shaped_dirty: bool = false

func request_shaped_rebuild() -> void:
	if block_data == null:
		return
	if _shaped_scheduled:
		_shaped_dirty = true
		return
	_shaped_scheduled = true
	var snap_bd := _BlockData.new()
	snap_bd.init(_cols, _cols)
	snap_bd._data = block_data._data.duplicate()
	snap_bd._off = block_data._off.duplicate()
	_track_task(WorkerThreadPool.add_task(
		_thread_shaped_rebuild.bind(self, snap_bd, _cols, _dimension_id),
		true, "shaped_rebuild"))

static func _thread_shaped_rebuild(chunk: Node, snap_bd: _BlockData, cols: int, dim_id: int) -> void:
	var payload := _build_shaped_block_data(snap_bd, cols, dim_id)
	if chunk == null or not is_instance_valid(chunk) or not chunk.is_inside_tree():
		return
	chunk.call_deferred("_apply_shaped_rebuild", payload)

func _apply_shaped_rebuild(payload: Dictionary) -> void:
	_shaped_scheduled = false
	if block_data == null or not is_inside_tree():
		return
	_apply_shaped_block_data(payload)
	_has_shaped_blocks = not _shaped_block_instances.is_empty()
	block_data.dirty = false
	if _shaped_dirty:
		_shaped_dirty = false
		request_shaped_rebuild()

## Đặt block tại world position.
func place_block_at(wx: float, wy: float, wz: float, block_id: int, off: int = _BlockData.OFF_CENTER) -> bool:
	if block_data == null: return false
	var blk := world_to_local_block(wx, wy, wz)
	var cur: int = block_data.get_block(blk.x, blk.y, blk.z)
	if cur != _Data.BlockID.AIR and not _is_water_bid(cur): return false
	block_data.set_block(blk.x, blk.y, blk.z, block_id)
	block_data.set_offset(blk.x, blk.y, blk.z, off)
	_water_tick_timer = 0.0
	if _is_water_bid(block_id):
		_has_water = true
		_max_water_ly = maxi(_max_water_ly, blk.y)
		rebuild_water_mesh()
	elif _is_water_bid(cur):
		rebuild_water_mesh()
		if not _Data.is_shaped_block(block_id):
			request_biome_rebuild([blk])
	else:
		if block_id == _Data.BlockID.TILLED_SOIL:
			_has_soil = true
		if _Data.is_shaped_block(block_id):
			request_shaped_rebuild()
		else:
			request_biome_rebuild([blk])
	_trigger_neighbor_water_tick(blk.x, blk.z)
	return true

## Đặt NHIỀU block cùng lúc (pattern platform 3×3 / tường 3×6) — chỉ rebuild
## mesh MỘT lần thay vì mỗi cell 1 lần rebuild (9–18 rebuild sync đã gây giật).
## Block nào đã bị chiếm (non-air, non-water) thì bỏ qua, không ghi đè.
## Trả về số block thực sự được đặt.
func place_blocks_at(positions: Array[Vector3], block_ids: Array[int], off: int = _BlockData.OFF_CENTER) -> int:
	if block_data == null or positions.is_empty():
		return 0
	var changed: int = 0
	var touched_water: bool = false
	var changed_at: Array[Vector3i] = []
	var col_set: Dictionary = {}
	for i in range(positions.size()):
		var wx: float = positions[i].x
		var wy: float = positions[i].y
		var wz: float = positions[i].z
		var blk := world_to_local_block(wx, wy, wz)
		var cur: int = block_data.get_block(blk.x, blk.y, blk.z)
		if cur != _Data.BlockID.AIR and not _is_water_bid(cur):
			continue
		block_data.set_block(blk.x, blk.y, blk.z, block_ids[i])
		block_data.set_offset(blk.x, blk.y, blk.z, off)
		changed += 1
		var ckey: int = blk.x * _cols + blk.z
		if not col_set.has(ckey):
			col_set[ckey] = true
			changed_at.append(blk)
		if _is_water_bid(block_ids[i]):
			touched_water = true
	if changed == 0:
		return 0
	_water_tick_timer = 0.0
	if touched_water:
		# Có nước trong batch → rebuild water surface trước, rồi shaped nếu có
		_has_water = true
		rebuild_water_mesh()
		var has_shaped: bool = false
		for i in range(positions.size()):
			if _Data.is_shaped_block(block_ids[i]):
				has_shaped = true
				break
		if has_shaped:
			request_shaped_rebuild()
	else:
		# Mọi block đều shaped (platform/tường/đá) → KHÔNG rebuild terrain (80ms)
		var all_shaped: bool = true
		for i in range(positions.size()):
			if not _Data.is_shaped_block(block_ids[i]):
				all_shaped = false
				break
		if all_shaped:
			request_shaped_rebuild()
		else:
			# Biome: cập nhật top_ly từng cột ngay, dựng mesh trong worker thread
			request_biome_rebuild(changed_at)
	return changed

## ── Cuốc đất: GRASS/DARK_GRASS/DIRT/DARK_DIRT → TILLED_SOIL ─────────────────
## Trả về block cũ đã cuốc (0 = không cuốc được).
func till_block_at(wx: float, wy: float, wz: float) -> int:
	if block_data == null: return 0
	var blk := world_to_local_block(wx, wy, wz)
	var old_id: int = block_data.get_block(blk.x, blk.y, blk.z)
	if not _Data.is_tillable(old_id): return 0
	block_data.set_block(blk.x, blk.y, blk.z, _Data.BlockID.TILLED_SOIL)
	_has_soil = true
	_water_tick_timer = 0.0
	request_biome_rebuild([blk])
	return old_id

## ── rebuild_soil_mesh: rebuild overlay đất tơi xốp (khô/ẩm theo nước) ───────
func rebuild_soil_mesh() -> void:
	if block_data == null: return
	if not _has_soil:
		_has_soil = _scan_has_soil()
		if not _has_soil: return
	var nb_data := _get_neighbor_water_data()
	var mesh := _build_soil_mesh(block_data, _cols, nb_data)
	if mesh == null or mesh.get_surface_count() == 0:
		_has_soil = false
		_remove_soil_mesh_instance()
		return
	_has_soil = true
	var mi := _textured_block_mesh_instances.get(_Data.BlockID.TILLED_SOIL) as MeshInstance3D
	if mi == null or not is_instance_valid(mi):
		mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _get_textured_block_material(_Data.BlockID.TILLED_SOIL)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _mesh_container != null:
			_mesh_container.add_child(mi)
		else:
			add_child(mi)
		_textured_block_mesh_instances[_Data.BlockID.TILLED_SOIL] = mi
	else:
		mi.mesh = mesh

func _remove_soil_mesh_instance() -> void:
	var mi := _textured_block_mesh_instances.get(_Data.BlockID.TILLED_SOIL) as MeshInstance3D
	if mi != null and is_instance_valid(mi):
		mi.queue_free()
	_textured_block_mesh_instances.erase(_Data.BlockID.TILLED_SOIL)

## Đất tơi xốp luôn nằm trên bề mặt → scan theo top_ly_cache (625 lookup, rẻ).
func _scan_has_soil() -> bool:
	var cols := _cols
	if _top_ly_cache.size() != cols * cols:
		return false
	for x in range(cols):
		for z in range(cols):
			var ly: int = _top_ly_cache[x * cols + z]
			if ly < 0: continue
			if block_data.get_block(x, ly, z) == _Data.BlockID.TILLED_SOIL:
				return true
	return false

## ── Aquatic shader ────────────────────────────────────────────────────────────
## Cache 1 ShaderMaterial dùng chung cho MỌI prop biển (coral/kelp/seaweed...).
## Trước đây mỗi prop tự tạo Shader + ShaderMaterial mới → D3D12 compile shader
## pipeline lại từng lần khi prop stream vào → stutter khi lướt qua biển.
static var _aquatic_mat: ShaderMaterial = null

static func make_aquatic_mat() -> ShaderMaterial:
	if _aquatic_mat == null:
		_aquatic_mat = _build_aquatic_shader()
	return _aquatic_mat

static func _build_aquatic_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sway_speed  : hint_range(0.1, 5.0) = 1.1;
uniform float sway_amount : hint_range(0.0, 0.5) = 0.035;
uniform float sway_freq   : hint_range(0.1, 8.0) = 1.9;
void vertex() {
	float is_flat = step(0.85, abs(NORMAL.y));
	float height_factor = max(0.0, VERTEX.y + 0.5) * 0.7;
	float phase_x = VERTEX.x * 3.7 + VERTEX.z * 1.3;
	float phase_z = VERTEX.z * 3.1 + VERTEX.x * 1.7;
	float w1  = sin(TIME * sway_speed + phase_x) * sway_amount * height_factor;
	float w1z = sin(TIME * sway_speed * 0.73 + phase_z + 1.1) * sway_amount * 0.6 * height_factor;
	float w2  = sin(TIME * sway_speed * 2.1 + phase_x * 0.5 + 0.4) * sway_amount * 0.3 * height_factor;
	float w2z = sin(TIME * sway_speed * 1.85 + phase_z * 0.6 + 2.2) * sway_amount * 0.25 * height_factor;
	float w3  = sin(TIME * sway_speed * 4.3 + phase_x * 1.2) * sway_amount * 0.12 * height_factor;
	VERTEX.x += w1 + w2 + w3;
	VERTEX.z += w1z + w2z;
}
void fragment() {
	vec4 col = COLOR * albedo_tint;
	if (col.a < 0.35) discard;
	ALBEDO = col.rgb; ALPHA = col.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = 1
	return m

## ── is_water_at: kiểm tra block data thực tế (tất cả loại nước) ──────────────
func is_water_at(wx: float, wz: float, wy: float) -> bool:
	if block_data == null: return false
	var half: float = _size * 0.5
	var vx: int = int((wx - (global_position.x - half)) / _Data.VOXEL)
	var vz: int = int((wz - (global_position.z - half)) / _Data.VOXEL)
	if vx < 0 or vx >= _cols or vz < 0 or vz >= _cols: return false
	var layer: int = _BlockData.world_y_to_layer(wy)
	return _is_water_bid(block_data.get_block(vx, layer, vz))

## ── _get_neighbor_water_data: lấy block data của 4 chunk lân cận ─────────────
func _get_neighbor_water_data() -> Dictionary:
	var parent := get_parent()
	if parent == null: return {}
	var chunks: Dictionary
	if "_chunks" in parent:
		chunks = parent._chunks
	else:
		return {}
	var res: Dictionary = {}
	var w_key := Vector2i(_cx - 1, _cz)
	if chunks.has(w_key):
		var nb := chunks[w_key] as WorldChunk
		if nb and nb.block_data:
			res["w"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	var e_key := Vector2i(_cx + 1, _cz)
	if chunks.has(e_key):
		var nb := chunks[e_key] as WorldChunk
		if nb and nb.block_data:
			res["e"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	var n_key := Vector2i(_cx, _cz - 1)
	if chunks.has(n_key):
		var nb := chunks[n_key] as WorldChunk
		if nb and nb.block_data:
			res["n"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	var s_key := Vector2i(_cx, _cz + 1)
	if chunks.has(s_key):
		var nb := chunks[s_key] as WorldChunk
		if nb and nb.block_data:
			res["s"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	return res

## ── _trigger_neighbor_water_tick: nếu block ở biên, kích water tick ở lân cận ─
func _trigger_neighbor_water_tick(lx: int, lz: int) -> void:
	if lx > 0 and lx < _cols - 1 and lz > 0 and lz < _cols - 1:
		return  # không ở biên
	var parent := get_parent()
	if parent == null: return
	var chunks: Dictionary
	if "_chunks" in parent:
		chunks = parent._chunks
	else:
		return
	if lx == 0:
		var key := Vector2i(_cx - 1, _cz)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()
	if lx == _cols - 1:
		var key := Vector2i(_cx + 1, _cz)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()
	if lz == 0:
		var key := Vector2i(_cx, _cz - 1)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()
	if lz == _cols - 1:
		var key := Vector2i(_cx, _cz + 1)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()

## ── _add_quad (shared helper, delegates to Terrain) ─────────────────────────
static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3,
		n: Vector3, col: Color) -> void:
	_Terrain._add_quad(st, center, u, v, n, col)
