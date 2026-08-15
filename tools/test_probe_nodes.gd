extends Node3D

## test_probe_nodes — đếm node theo loại khi nạp ring full vr=4 (81 chunk)
## để xác định nút cổ chai thật của props trước Bước 3 (gộp props toàn cầu).

const _WM = preload("res://scripts/world/open_world_manager.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _T = preload("res://scripts/world/chunk/world_tile.gd")

const REAL: int = _D._Dim.DimensionID.REAL_WORLD

var _wm = null
var _player: Node3D = null
var _f: int = 0
var _done: bool = false

func _ready() -> void:
	print("== test_probe_nodes: vr=4 ring full ==")
	WorldSeed.seed_value = 20260806
	if SettingsManager and SettingsManager.chunk_view > 4:
		SettingsManager.chunk_view = 4
	_W.props_enabled = true
	_W.clear_noise_cache()
	var root := Node3D.new()
	root.name = "WorldRoot"
	add_child(root)
	_wm = _WM.new()
	_wm.dimension_id = REAL
	_wm.name = "WorldManager"
	root.add_child(_wm)
	_player = Node3D.new()
	_player.name = "Player"
	_player.position = Vector3(0, 4, 0)
	root.add_child(_player)
	_wm._player = _player

func _process(_d: float) -> void:
	_f += 1
	if _done:
		return
	if not (_wm._loading.is_empty() and _wm._pending.is_empty()
			and _wm._pending_lod.is_empty() and _wm._pending_tiles.is_empty()
			and _wm._loading_tiles.is_empty()):
		return
	if _f < 20:
		return
	_done = true
	# Chờ prop queue thực thi hết
	var counts := {}
	_count_nodes(self, counts)
	var mmpi: int = int(counts.get("MultiMeshInstance3D", 0))
	var mi: int = int(counts.get("MeshInstance3D", 0))
	var omni: int = int(counts.get("OmniLight3D", 0))
	var props: int = int(counts.get("Prop", 0)) + int(counts.get("DestroyableProp", 0))
	var total: int = 0
	for k in counts:
		total += int(counts[k])
	print("NODE_CENSUS nearest-to-player stats:")
	print("  MultiMeshInstance3D=%d  MeshInstance3D=%d  OmniLight3D=%d  Proppable=%d" % [mmpi, mi, omni, props])
	print("  WorldChunk(built)=%d  WorldTile=%d  total_children=%d" % [
		counts.get("WorldChunk", 0), counts.get("WorldTile", 0), total])
	# Đếm riêng trong từng chunk: grass MMPI + nó có bao nhiêu instance
	var grass_inst := 0
	var grass_mmpi := 0
	for key in _wm._chunks:
		var c: Node = _wm._chunks[key]
		if c == null or not is_instance_valid(c):
			continue
		for ch in c.get_children():
			if ch is MultiMeshInstance3D:
				grass_mmpi += 1
				grass_inst += ch.multimesh.instance_count if ch.multimesh else 0
	print("  grass MultiMeshInstance3D=%d  total_bades=%d" % [grass_mmpi, grass_inst])
	print("DONE")
	get_tree().quit(0)

func _count_nodes(n: Node, counts: Dictionary) -> void:
	var cn := n.get_class()
	counts[cn] = int(counts.get(cn, 0)) + 1
	var sc: GDScript = n.get_script()
	if sc != null and sc == _W:
		counts["WorldChunk"] = int(counts.get("WorldChunk", 0)) + 1
	if sc != null and sc == _T:
		counts["WorldTile"] = int(counts.get("WorldTile", 0)) + 1
	if sc != null and "prop" in (sc.resource_path.to_lower()):
		counts["Prop"] = int(counts.get("Prop", 0)) + 1
	for ch in n.get_children():
		_count_nodes(ch, counts)