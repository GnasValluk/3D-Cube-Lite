extends Node

## Smoke test death/respawn relay — CLIENT side.
## Chạy cùng test_mp_death_respawn_host.tscn. Verify: client nhận death_chest_spawned
## (pos + inventory đúng), nhận player_respawned + RemotePlayer của host snap về pos.

const PORT := 7789
const TIMEOUT_MS := 30000
const _DummyPlayer := preload("res://tools/dummy_state_player.gd")

var _failures: int = 0
var _got_chest: bool = false
var _got_respawn: bool = false
var _chest_pos: Vector3 = Vector3.ZERO
var _chest_items: Array = []
var _respawn_pos: Vector3 = Vector3.ZERO

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_chest(_owner_peer: int, pos: Vector3, inv_data: Array) -> void:
	_got_chest = true
	_chest_pos = pos
	_chest_items = inv_data

func _on_respawn(peer_id: int, pos: Vector3) -> void:
	if peer_id == Net.my_peer_id:
		return
	_got_respawn = true
	_respawn_pos = pos

func _ready() -> void:
	print("== test_mp_death_respawn_client ==")
	Net.death_chest_spawned.connect(_on_chest)
	Net.player_respawned.connect(_on_respawn)
	var ok := Net.join_game("127.0.0.1", PORT, "DeathRespawnClient")
	_check(ok, "join_game(7789) ok")

	var dummy: CharacterBody3D = _DummyPlayer.new()
	dummy.name = "ClientDummy"
	add_child(dummy)
	dummy.global_position = Vector3(8, 3, 8)
	Net.register_local_player(dummy)

	await _wait_world_ready()

	# 1) Chờ host announce death chest → kiểm tra pos + inventory.
	await _wait_signal_chest()
	_check(_got_chest, "client nhận death_chest_spawned")
	if _got_chest:
		_check(_chest_pos.is_equal_approx(Vector3(10, 4, -3)), "death chest đúng vị trí (10,4,-3)")
		var has_carp := false
		var has_shrimp := false
		for entry in _chest_items:
			if entry != null:
				if str(entry.get("id", "")) == "carp" and int(entry.get("count", 0)) == 2:
					has_carp = true
				if str(entry.get("id", "")) == "shrimp" and int(entry.get("count", 0)) == 1:
					has_shrimp = true
		_check(has_carp, "death chest chứa carp x2")
		_check(has_shrimp, "death chest chứa shrimp x1")
	Net.send_chat_message("CHEST-OK")

	# 2) Chờ host announce respawn → kiểm tra pos.
	await _wait_signal_respawn()
	_check(_got_respawn, "client nhận player_respawned")
	if _got_respawn:
		_check(_respawn_pos.is_equal_approx(Vector3(0, 3, 0)), "respawn đúng vị trí (0,3,0)")
	Net.send_chat_message("RESPAWN-OK")

	await get_tree().create_timer(1.0).timeout
	Net.leave_game()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _wait_world_ready() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net.is_world_ready():
			return
		await get_tree().process_frame

func _wait_signal_chest() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if _got_chest:
			return
		await get_tree().process_frame

func _wait_signal_respawn() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if _got_respawn:
			return
		await get_tree().process_frame