extends Node

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const _WorldManager = preload("res://scripts/world/open_world_manager.gd")
const _CharManager = preload("res://scripts/core/character_manager.gd")
const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")

const TEST_WORLD: String = "TestLoadSpawn"
const SAVE_X: float = 400.0
const SAVE_Z: float = -300.0
const EXPECT_CHUNK := Vector2i(12, -10)

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	seed(20260804)
	WorldSeed.seed_value = 20260804
	print("== test_load_spawn: load hành trình spawn thẳng tại điểm đã lưu ==")
	WorldSeed.world_name = TEST_WORLD
	WorldSeed.is_loading = true
	WorldSeed.saved_player_pos = Vector3(SAVE_X, 0.0, SAVE_Z)
	WorldSeed.has_saved_player_pos = true

	# ── 1. World manager: trung tâm = chunk chứa vị trí lưu ────────────────
	var root := Node3D.new()
	root.name = "OpenWorldThucTe"
	add_child(root)
	var wm := _WorldManager.new()
	wm.dimension_id = _Data._Dim.DimensionID.REAL_WORLD
	wm.name = "WorldManager"
	root.add_child(wm)

	var frames := 0
	while frames < 300 and not wm._chunks.has(EXPECT_CHUNK):
		await get_tree().process_frame
		frames += 1
	_check(wm._chunks.has(EXPECT_CHUNK), "chunk trung tâm (vị trí lưu) được generate")

	# ── 2. Tìm cột đất (không phải nước) + ghi save với vị trí thật ─────────
	var chunk: WorldChunk = wm._chunks[EXPECT_CHUNK]
	var best_x := 0
	var best_z := 0
	var best_ly := -1
	for lx in range(8, 24):
		for lz in range(8, 24):
			for ly in range(_BlockData.CHUNK_H - 1, -1, -1):
				var b := chunk.block_data.get_block(lx, ly, lz)
				if b != _Data.BlockID.AIR and not _is_water(b):
					if ly > best_ly:
						best_ly = ly
						best_x = lx
						best_z = lz
					break
	var saved_y := _BlockData.layer_to_world_y(best_ly) + 0.25
	var saved_pos := Vector3(best_x + EXPECT_CHUNK.x * 32, saved_y, best_z + EXPECT_CHUNK.y * 32)
	print("land col=(%d,%d) top_ly=%d saved_pos=%s" % [best_x, best_z, best_ly, saved_pos])
	_check(best_ly >= 0, "tìm thấy cột đất để lưu vị trí")

	var dir := SaveManager.get_world_dir(TEST_WORLD)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.new().stringify({
			"version": 1,
			"world_name": TEST_WORLD,
			"seed": WorldSeed.seed_value,
			"dimension": _Data._Dim.DimensionID.REAL_WORLD,
			"player": {"position": [saved_pos.x, saved_pos.y, saved_pos.z], "inventory": []},
			"blocks": {}
		}))
		f.close()
	WorldSeed.saved_player_pos = saved_pos

	# ── 3. Đọc vị trí từ save ──────────────────────────────────────────────
	var read_pos := SaveManager.get_saved_player_position(TEST_WORLD)
	_check(read_pos.distance_to(saved_pos) < 0.01, "get_saved_player_position trả đúng vị trí save")
	_check(SaveManager.get_saved_player_position("KhongTonTai") == Vector3.INF,
		"save không tồn tại → Vector3.INF")

	# ── 4. CharacterManager + Player: spawn thẳng tại vị trí lưu ───────────
	var cm := _CharManager.new()
	cm.name = "CharacterManager"
	var player := _PlayerChar.new()
	player.name = "Player"
	cm.add_child(player)
	root.add_child(cm)

	# ── 5. Chờ thế giới load xong quanh điểm lưu ───────────────────────────
	frames = 0
	while frames < 240 and not wm._loading_ready:
		await get_tree().process_frame
		frames += 1

	_check(player.global_position.distance_to(saved_pos) < 1.5,
		"player đứng tại vị trí lưu (không qua điểm đầu)")
	_check(player.global_position.distance_to(Vector3(0, 3, 0)) > 50.0,
		"player KHÔNG spawn ở điểm đầu (0,3,0)")
	_check(wm._last_chunk == EXPECT_CHUNK,
		"world manager trung tâm = chunk chứa vị trí lưu (%d,%d)" % [EXPECT_CHUNK.x, EXPECT_CHUNK.y])
	_check(wm._chunks.has(EXPECT_CHUNK) and wm._chunks[EXPECT_CHUNK]._built,
		"chunk trung tâm (vị trí lưu) đã build xong")
	_check(not wm._chunks.has(Vector2i(0, 0)),
		"không generate vùng (0,0) ban đầu (đã load thẳng vùng lưu)")

	# ── 6. Dọn dẹp save test ────────────────────────────────────────────────
	if DirAccess.dir_exists_absolute(dir):
		DirAccess.remove_absolute(dir)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _is_water(b: int) -> bool:
	return _Data.is_water(b)
