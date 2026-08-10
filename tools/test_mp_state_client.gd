extends Node

## Smoke test state/inventory relay — CLIENT side.
## Join host test_mp_state_host.tscn: chờ welcome → register_local_player →
## đổi hp/food trên dummy → host relay → client cũng phải nhận state/inventory
## của chính mình (broadcast). Host cũng phải nhận (xem test_mp_state_host).

const PORT := 7789
const TIMEOUT_MS := 30000
const _DummyPlayer := preload("res://tools/dummy_state_player.gd")

var _failures: int = 0
var _dummy: CharacterBody3D
var _welcome: bool = false
var _received_state: Array = []
var _received_inv: Array = []

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_welcome() -> void:
	_welcome = true

func _on_state(peer_id: int, hp: int, max_hp: int, food: int, max_food: int, shield: int, level: int, alive: bool) -> void:
	_received_state.append([peer_id, hp, max_hp, food, max_food, shield, level, alive])

func _on_inv(peer_id: int, data: Array) -> void:
	_received_inv.append([peer_id, data])

func _ready() -> void:
	print("== test_mp_state_client ==")
	Net.player_state_received.connect(_on_state)
	Net.player_inventory_received.connect(_on_inv)
	Net.welcome_received.connect(_on_welcome)
	var ok := Net.join_game("127.0.0.1", PORT, "StateClient")
	_check(ok, "join_game(127.0.0.1,7789) ok")
	_check(Net.is_client, "is_client true")

	await _wait_welcome()
	_check(_welcome, "welcome_received đã phát")

	_dummy = _DummyPlayer.new()
	_dummy.name = "ClientDummy"
	add_child(_dummy)
	_dummy.global_position = Vector3(8, 2, 8)
	Net.register_local_player(_dummy)

	# Đổi hp/food trên dummy → Net sẽ broadcast trong tick kế tiếp.
	_dummy.set("hp", 60)
	_dummy.set("max_hp", 60)
	_dummy.set("food", 10)
	_dummy.set("max_food", 10)
	_dummy.set("shield", 5)
	_dummy.set("level", 3)
	_dummy.set("is_alive", true)

	# Thêm item vào inventory → Net sẽ broadcast inventory khi đổi.
	_setup_inventory()

	# Client phải nhận state/inventory của HOST (peer 1), đã set trong test host.
	var got_host_state: bool = await _wait_state_from(1, 40, 40, 8, 8)
	_check(got_host_state, "client nhận state của host (hp=40 max=40 food=8 max=8)")

	var got_host_inv: bool = await _wait_inv_from_peer(1, "carp")
	_check(got_host_inv, "client nhận inventory của host (chứa carp)")

	# 3) Host chết → RemotePlayer của host trên client ẩn rig; 4) respawn → hiện lại.
	var remote: Node3D = Net._find_remote(1)
	if remote == null:
		_check(false, "tìm thấy RemotePlayer của host (peer 1)")
	else:
		_check(remote != null, "tìm thấy RemotePlayer của host (peer 1)")
		var rig: Node3D = remote.get("_mesh").rig
		# Báo host "sẵn sàng" → host sẽ diễn tập chết/respawn ngay sau đó.
		_dummy.set("hp", 61)
		var dead_seen: bool = await _wait_remote_dead(remote)
		_check(dead_seen, "client thấy RemotePlayer host ẩn khi chết (alive=false)")
		await _wait_remote_alive(remote)
		_check(rig.visible, "client thấy rig RemotePlayer host hiện lại sau respawn")

	await get_tree().create_timer(1.0).timeout
	Net.leave_game()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _setup_inventory() -> void:
	var inv: Inventory = Inventory.new()
	ItemDatabase.ensure_db()
	if ItemDatabase.items_db.has("shrimp"):
		inv.add_item(ItemDatabase.items_db["shrimp"], 3)
	_dummy.set("inventory", inv)

func _wait_welcome() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if _welcome:
			return
		await get_tree().process_frame

func _wait_state_from(p_peer: int, p_hp: int, p_max_hp: int, p_food: int, p_max_food: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for s in _received_state:
			if int(s[0]) == p_peer and int(s[1]) == p_hp and int(s[2]) == p_max_hp and int(s[3]) == p_food and int(s[4]) == p_max_food:
				return true
		await get_tree().process_frame
	return false

func _wait_inv_from_peer(p_peer: int, item_id: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for inv in _received_inv:
			if int(inv[0]) == p_peer and _inv_has(inv[1], item_id):
				return true
		await get_tree().process_frame
	return false

func _inv_has(data: Array, item_id: String) -> bool:
	for entry in data:
		if entry != null and str(entry.get("id", "")) == item_id:
			return true
	return false

func _wait_remote_dead(remote: Node3D) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var rig: Node3D = remote.get("_mesh").rig
		if not bool(remote.get("alive")) and not rig.visible:
			return true
		await get_tree().process_frame
	return false

func _wait_remote_alive(remote: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if bool(remote.get("alive")):
			return
		await get_tree().process_frame
