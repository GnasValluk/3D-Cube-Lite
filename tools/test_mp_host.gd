extends Node

## Smoke test multiplayer — HOST side.
## Chạy cùng test_mp_client.tscn (join 127.0.0.1) để kiểm tra handshake:
## host_game → register_local_player → client request_join → world_info +
## net_spawn_player (host tạo RemotePlayer cho client) → relay_move broadcast.

const PORT := 7789
const TIMEOUT_MS := 30000

var _failures: int = 0
var _dummy: CharacterBody3D

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_mp_host ==")
	var ok := Net.host_game(PORT, "HostTester")
	_check(ok, "host_game(7789) ok")
	_check(Net.is_host, "is_host true")
	_check(Net.is_active(), "is_active true")

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

	var cid := -1
	for pid in Net._peers:
		cid = int(pid)
	var remote: Node3D = Net._find_remote(cid)
	_check(remote != null, "host đã spawn RemotePlayer cho client")

	var moved: bool = await _wait_remote_move(cid)
	_check(moved, "host nhận relay_move từ client và áp lên RemotePlayer")

	# Giữ host sống cho tới khi client test xong (client sẽ leave_game → host
	# nhận peer_disconnected) — nếu thoát sớm, client không kịp nhận net_move.
	await _wait_peer_disconnect(cid)

	Net.leave_game()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _wait_peer_registered() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._peers.size() > 0:
			return
		await get_tree().process_frame

func _wait_peer_disconnect(cid: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if not Net._peers.has(cid):
			return
		await get_tree().process_frame

func _wait_remote_move(cid: int) -> bool:
	var target := Vector3(8, 2, 8)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var r: Node3D = Net._find_remote(cid)
		if r:
			var tp: Variant = r.get("_target_pos")
			if tp is Vector3 and (tp as Vector3).distance_to(target) < 0.5:
				return true
		await get_tree().process_frame
	return false
