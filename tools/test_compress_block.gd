extends Node

## test_compress_block — đo tỉ lệ nén block_data_bytes trên chunk thật
## và chi phí compress/decompress, để chọn phương án Bước 2 (nén block data).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const REAL: int = _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_compress_block ==")
	WorldSeed.seed_value = 20260806
	_W.props_enabled = false
	_W.clear_noise_cache()

	var positions: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(2, 3), Vector2i(-4, 1),
		Vector2i(7, -5), Vector2i(-3, 6), Vector2i(5, 2),
		Vector2i(-8, 4), Vector2i(3, -7),
	]
	var raw_total := 0
	var def_total := 0
	var gzip_total := 0
	var snap_total := 0
	var t_comp := 0.0
	var t_decomp := 0.0
	for p in positions:
		var d := _W.compute_chunk(p.x, p.y, 32, REAL, false, false)
		var raw: PackedByteArray = d["block_data_bytes"]
		var t0 := Time.get_ticks_usec()
		var def := raw.compress(FileAccess.COMPRESSION_DEFLATE)
		var gz := raw.compress(FileAccess.COMPRESSION_GZIP)
		var sn := raw.compress(FileAccess.COMPRESSION_FASTLZ)
		t_comp += Time.get_ticks_usec() - t0
		var t1 := Time.get_ticks_usec()
		var back := def.decompress(raw.size(), FileAccess.COMPRESSION_DEFLATE)
		t_decomp += Time.get_ticks_usec() - t1
		raw_total += raw.size()
		def_total += def.size()
		gzip_total += gz.size()
		snap_total += sn.size()
		var ok := back == raw
		print("chunk (%d,%d): raw=%d deflate=%d (%.2fx) fastlz=%d (%.2fx) roundtrip=%s" % [
			p.x, p.y, raw.size(), def.size(), float(def.size()) / raw.size(),
			sn.size(), float(sn.size()) / raw.size(), str(ok)])
	print("TOTAL raw=%d deflate=%d (%.2fx) gzip=%d (%.2fx) fastlz=%d (%.2fx)" % [
		raw_total, def_total, float(def_total) / raw_total,
		gzip_total, float(gzip_total) / raw_total,
		snap_total, float(snap_total) / raw_total])
	print("compress %d chunks: %d us | decompress %d chunks: %d us" % [
		positions.size(), int(t_comp), positions.size(), int(t_decomp)])

	# ── Pipeline cache-giải nén khớp apply_chunk ─────────────────────────
	var N: int = _BD.CHUNK_H
	var p0 := positions[0]
	var d0: Dictionary = _W.compute_chunk(p0.x, p0.y, 32, REAL, false, false)
	var raw0: PackedByteArray = d0["block_data_bytes"]
	var saved := raw0.size()
	_W.compress_block_data(d0)
	_check(d0.get("bd_compressed", false) == true, "compress_block_data đánh dấu nén")
	_check(d0["block_data_bytes"].size() < saved / 8,
		"cache nén < 12.5%% (raw %d → %d)" % [saved, d0["block_data_bytes"].size()])
	var restored: PackedByteArray = d0["block_data_bytes"].decompress(
		32 * 32 * N, FileAccess.COMPRESSION_DEFLATE)
	_check(restored == raw0, "decompress khôi phục đúng block_data (khớp raw)")
	var size1: int = d0["block_data_bytes"].size()
	_W.compress_block_data(d0)
	_check(d0["block_data_bytes"].size() == size1, "compress_block_data idempotent (không nén lại lần 2)")
	var bd0 = _BD.new()
	bd0.from_bytes(restored, 32, 32)
	_check(bd0.get_block(5, 30, 5) >= 0, "chunkBlockData dựng lại từ bản nén hoạt động")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await _W.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)