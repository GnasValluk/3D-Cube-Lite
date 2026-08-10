extends Node

## Smoke test death/respawn relay — HOST side.
## Chạy cùng test_mp_death_respawn_client.tscn. Verify: host announce death chest
## (pos + inventory) → client nhận death_chest_spawned; host announce respawn →
## client nhận player_respawned + RemotePlayer của host snap về đúng vị trí.

const PORT := 7789
const TIMEOUT_MS := 30000
const _DummyPlayer := preload("res://tools/dummy_state_player.gd")

var _failures: int = 0
var _confirmations: Array = []

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_chat(_name: String, _color: Color, text: String) -> void:
	var t := str(text).strip_edges()
	if t == "CHEST-OK" or t == "RESPAWN-OK":
		_confirmations.append(t)

func _ready() -> void:
	print("== test_mp_death_respawn_host ==")
	Net.chat_message_received.connect(_on_chat)
	var ok := Net.host_game(PORT, "DeathRespawnHost")
	_check(ok, "host_game(7789) ok")

	var dummy: CharacterBody3D = _DummyPlayer.new()
	dummy.name = "HostDummy"
	add_child(dummy)
	dummy.global_position = Vector3(5, 3, 5)
	Net.register_local_player(dummy)
	_check(Net.is_world_ready(), "world_ready sau register_local_player")

	await _wait_peer_registered()
	if Net._peers.size() == 0:
		_check(false, "không có client nối tới trong thời gian chờ")
		Net.leave_game()
		print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(0 if _failures == 0 else 1)
		return

	# 1) Host announce death chest tại (10, 4, -3) chứa carp x2 + shrimp x1
	#    → client nhận đúng payload.
	var chest_inv := Inventory.new(45)
	ItemDatabase.ensure_db()
	if ItemDatabase.items_db.has("carp"):
		chest_inv.add_item(ItemDatabase.items_db["carp"], 2)
	if ItemDatabase.items_db.has("shrimp"):
		chest_inv.add_item(ItemDatabase.items_db["shrimp"], 1)
	Net.announce_death_chest(Vector3(10, 4, -3), chest_inv.to_dict())
	var got_chest: bool = await _wait_confirm("CHEST-OK")
	_check(got_chest, "client nhận death chest (CHEST-OK)")

	# 2) Host announce respawn tại (0, 3, 0) → client snap RemotePlayer về đó.
	Net.announce_respawn(Vector3(0, 3, 0))
	var got_respawn: bool = await _wait_confirm("RESPAWN-OK")
	_check(got_respawn, "client nhận respawn + snap RemotePlayer (RESPAWN-OK)")

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

func _wait_confirm(kind: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if _confirmations.has(kind):
			return true
		await get_tree().process_frame
	return false

func _wait_peer_disconnect() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._peers.size() == 0:
			return
		await get_tree().process_frame