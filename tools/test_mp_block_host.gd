extends Node

## Smoke test block edit sync — HOST side.
## Chạy cùng test_mp_block_client.tscn. Host verify: client gửi request_block_edit
## → host ghi ledger _block_edits + broadcast net_block_edit → block_edit_applied
## phát trên host. Host cũng tự announce một edit để verify path host-local.

const PORT := 7789
const TIMEOUT_MS := 30000
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

var _failures: int = 0
var _dummy: CharacterBody3D
var _applied: Array = []

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_block_edit(dim_id: int, cell: Vector3i, block_id: int) -> void:
	_applied.append([dim_id, cell, block_id])

func _ready() -> void:
	print("== test_mp_block_host ==")
	Net.block_edit_applied.connect(_on_block_edit)
	var ok := Net.host_game(PORT, "BlockHost")
	_check(ok, "host_game(7789) ok")

	_dummy = CharacterBody3D.new()
	_dummy.name = "HostDummy"
	add_child(_dummy)
	_dummy.global_position = Vector3(5, 3, 5)
	Net.register_local_player(_dummy)
	_check(Net.is_world_ready(), "world_ready sau register_local_player")

	await _wait_peer_registered()
	if Net._peers.size() == 0:
		_check(false, "không có client nối tới trong thời gian chờ")
		Net.leave_game()
		print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(0 if _failures == 0 else 1)
		return

	# 1) Client yêu cầu phá block → host phải ghi ledger + broadcast (client test
	#    cũng nhận applied). Đợi client rpc request_block_edit.
	var applied_by_client: bool = await _wait_client_edit_applied()
	_check(applied_by_client, "host nhận request_block_edit từ client và áp block edit")

	var key: String = "0:12:8:2"
	_check(Net._block_edits.has(key), "ledger host có edit của client (%s)" % key)
	_check(int(Net._block_edits.get(key, -1)) == _Data.BlockID.AIR, "block edit client là AIR (phá)")

	# 2) Host tự announce một edit (đặt block) → ledger + broadcast + applied.
	var before := _applied.size()
	Net.announce_block_edit(0, Vector3i(20, 4, 30), _Data.BlockID.STONE)
	await get_tree().process_frame
	var key2: String = "0:20:4:30"
	_check(Net._block_edits.has(key2), "ledger host có edit host tự đặt (%s)" % key2)
	_check(int(Net._block_edits.get(key2, -1)) == _Data.BlockID.STONE, "block edit host là STONE")
	_check(_applied.size() > before, "host nhận block_edit_applied cho edit của mình")

	# Giữ host sống cho tới khi client test xong.
	await _wait_peer_disconnect()
	Net.leave_game()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _wait_peer_registered() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._peers.size() > 0:
			return
		await get_tree().process_frame

func _wait_client_edit_applied() -> bool:
	var key: String = "0:12:8:2"
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._block_edits.has(key):
			return true
		await get_tree().process_frame
	return false

func _wait_peer_disconnect() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._peers.size() == 0:
			return
		await get_tree().process_frame
