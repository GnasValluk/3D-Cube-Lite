extends Node

## Smoke test multiplayer — CLIENT side.
## Join 127.0.0.1 (host test_mp_host.tscn): chờ welcome_received → xác nhận
## WorldSeed nhận seed/spawn → register_local_player → spawn RemotePlayer cho
## host (peer 1) → gửi relay_move → nhận net_move từ host.

const PORT := 7789
const TIMEOUT_MS := 30000

var _failures: int = 0
var _welcome: bool = false
var _dummy: CharacterBody3D

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_welcome() -> void:
	_welcome = true

func _ready() -> void:
	print("== test_mp_client ==")
	Net.welcome_received.connect(_on_welcome)
	var ok := Net.join_game("127.0.0.1", PORT, "ClientTester")
	_check(ok, "join_game(127.0.0.1,7789) ok")
	_check(Net.is_client, "is_client true")
	_check(Net.is_active(), "is_active true")

	await _wait_welcome()
	_check(_welcome, "welcome_received đã phát")
	_check(WorldSeed.use_remote_spawn, "use_remote_spawn được set từ world_info")
	_check(WorldSeed.has_saved_player_pos, "has_saved_player_pos được set từ world_info")

	_dummy = CharacterBody3D.new()
	_dummy.name = "ClientDummy"
	add_child(_dummy)
	_dummy.global_position = Vector3(8, 2, 8)
	Net.register_local_player(_dummy)

	await _wait_remote_host()
	var remote: Node3D = Net._find_remote(1)
	_check(remote != null, "client đã spawn RemotePlayer cho host (peer 1)")
	if remote:
		_check(str(remote.get("display_name")) == "HostTester", "tên RemotePlayer host đúng")

	var moved: bool = await _wait_host_move()
	_check(moved, "client nhận net_move từ host")

	# Kiểm tra LAN discovery: host đang nghe DISCOVERY_PORT, client quét broadcast.
	Net.start_browser()
	var found: bool = await _wait_discover_host()
	_check(found, "client phát hiện host qua LAN discovery")

	# Giữ kết nối thêm 2s để host kịp nhận relay_move và xác nhận.
	await get_tree().create_timer(2.0).timeout

	Net.stop_browser()
	Net.leave_game()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _wait_welcome() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if _welcome:
			return
		await get_tree().process_frame

func _wait_remote_host() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._find_remote(1) != null:
			return
		await get_tree().process_frame

func _wait_host_move() -> bool:
	var target := Vector3(5, 3, 5)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var r: Node3D = Net._find_remote(1)
		if r:
			var tp: Variant = r.get("_target_pos")
			if tp is Vector3 and (tp as Vector3).distance_to(target) < 0.5:
				return true
		await get_tree().process_frame
	return false

func _wait_discover_host() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for h in Net.found_hosts:
			if str(h.get("name", "")) == "HostTester":
				return true
		await get_tree().process_frame
	return false
