extends Node

## Smoke test state/inventory relay — HOST side.
## Chạy cùng test_mp_state_client.tscn. Verify: client gửi state (hp/food) →
## host nhận player_state_received + RemotePlayer của client được cập nhật;
## client gửi inventory → host nhận player_inventory_received.

const PORT := 7789
const TIMEOUT_MS := 30000
const _DummyPlayer := preload("res://tools/dummy_state_player.gd")

var _failures: int = 0
var _dummy: CharacterBody3D
var _received_state: Array = []
var _received_inv: Array = []

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_state(peer_id: int, hp: int, max_hp: int, food: int, max_food: int, shield: int, level: int, alive: bool) -> void:
	_received_state.append([peer_id, hp, max_hp, food, max_food, shield, level, alive])

func _on_inv(peer_id: int, data: Array) -> void:
	_received_inv.append([peer_id, data])

func _ready() -> void:
	print("== test_mp_state_host ==")
	Net.player_state_received.connect(_on_state)
	Net.player_inventory_received.connect(_on_inv)
	var ok := Net.host_game(PORT, "StateHost")
	_check(ok, "host_game(7789) ok")

	_dummy = _DummyPlayer.new()
	_dummy.name = "HostDummy"
	add_child(_dummy)
	_dummy.global_position = Vector3(5, 3, 5)
	Net.register_local_player(_dummy)
	_check(Net.is_world_ready(), "world_ready sau register_local_player")

	# Host đổi state + inventory của mình → broadcast → client nhận.
	_dummy.set("hp", 40)
	_dummy.set("max_hp", 40)
	_dummy.set("food", 8)
	_dummy.set("max_food", 8)
	_dummy.set("shield", 3)
	_dummy.set("level", 5)
	_dummy.set("is_alive", true)
	var inv: Inventory = Inventory.new()
	ItemDatabase.ensure_db()
	if ItemDatabase.items_db.has("carp"):
		inv.add_item(ItemDatabase.items_db["carp"], 2)
	_dummy.set("inventory", inv)

	await _wait_peer_registered()
	if Net._peers.size() == 0:
		_check(false, "không có client nối tới trong thời gian chờ")
		Net.leave_game()
		print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(0 if _failures == 0 else 1)
		return

	# 1) Client đổi hp/food → host phải nhận state của client.
	var got_state: bool = await _wait_state_from_client(60, 60, 10, 10)
	_check(got_state, "host nhận state từ client (hp=60 max=60 food=10 max=10)")

	# 2) Client thêm item vào kho → host phải nhận inventory của client.
	var got_inv: bool = await _wait_inv_from_client()
	_check(got_inv, "host nhận inventory từ client (chứa shrimp)")

	# 2.5) Client báo "sẵn sàng" (hp=61) → chờ trước khi host diễn tập chết/respawn.
	var ready: bool = await _wait_state_from_client(61, 60, 10, 10, true)
	_check(ready, "host nhận tín hiệu sẵn sàng của client (hp=61)")

	# 3) Host "chết" (hp=0, alive=false) → broadcast → client ẩn RemotePlayer.
	_dummy.set("hp", 0)
	_dummy.set("is_alive", false)
	await get_tree().create_timer(1.0).timeout
	# 4) Host "respawn" → broadcast → client hiện RemotePlayer lại.
	_dummy.set("hp", 40)
	_dummy.set("is_alive", true)
	await get_tree().create_timer(1.0).timeout

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

func _wait_state_from_client(p_hp: int, p_max_hp: int, p_food: int, p_max_food: int, p_alive: bool = true) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for s in _received_state:
			if int(s[1]) == p_hp and int(s[2]) == p_max_hp and int(s[3]) == p_food and int(s[4]) == p_max_food and bool(s[7]) == p_alive:
				return true
		await get_tree().process_frame
	return false

func _wait_inv_from_client() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for inv in _received_inv:
			if _inv_has(inv[1], "shrimp"):
				return true
		await get_tree().process_frame
	return false

func _inv_has(data: Array, item_id: String) -> bool:
	for entry in data:
		if entry != null and str(entry.get("id", "")) == item_id:
			return true
	return false

func _wait_peer_disconnect() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._peers.size() == 0:
			return
		await get_tree().process_frame
