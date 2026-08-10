## core/network_manager.gd
## Multiplayer v1 — host-authoritative (host là người làm chính thế giới).
## Host tạo ENetMultiplayerPeer server; client nối qua IP:port. Client nhận
## seed + spawn pos + danh sách peer từ host, tự generate terrain deterministic
## (giống seed) rồi spawn RemotePlayer cho từng người chơi khác. Movement được
## relay qua host (host = authority duy nhất) để đảm bảo thứ tự nhất quán.

extends Node

const _RemotePlayer := preload("res://scripts/characters/player/remote_player.gd")
const _WorldChunk := preload("res://scripts/world/chunk/world_chunk.gd")
const _Data := preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData := preload("res://scripts/world/chunk/chunk_block_data.gd")

const DEFAULT_PORT: int = 7777
const WORLD_SPAWN := Vector3(0, 3, 0)
const MOVE_TICK: float = 0.05

# ── LAN discovery ──────────────────────────────────────────────────────────────
const DISCOVERY_PORT: int = 7877
const DISCOVERY_PING: String = "TILA_MP_PING"
const DISCOVERY_PONG: String = "TILA_MP_PONG"
const DISCOVERY_INTERVAL: float = 1.0

var _discovery_socket: PacketPeerUDP = null  # host lắng nghe ping
var _browser_socket: PacketPeerUDP = null    # máy tìm quét broadcast
var _browser_timer: float = 0.0
var _browser_stopped: bool = true
var found_hosts: Array = []                  # [{ip, port, name, world, players}]

signal hosts_updated(hosts: Array)

var is_host: bool = false
var is_client: bool = false
var player_name: String = "Player"
var my_peer_id: int = 1
var _server_port: int = DEFAULT_PORT

var _local_player: CharacterBody3D = null
var _world_ready: bool = false
var _peers: Dictionary = {}
var _move_timer: float = 0.0
var _welcome_players: Array = []

# ── Block edit sync ───────────────────────────────────────────────────────────
## Host-authoritative. Người đào/xây áp dụng local trước (để có drop/SFX ngay),
## rồi gọi announce_block_edit → host ghi ledger + broadcast; mọi client áp dụng
## lại (idempotent). Ledger giúp replay khi chunk load muộn / client vào sau.
var _block_edits: Dictionary = {}  # "dim:x:z:layer" -> block_id (0 = AIR/đã phá)

signal block_edit_applied(dim_id: int, cell: Vector3i, block_id: int)
signal chat_message_received(sender_name: String, sender_color: Color, text: String)
signal player_state_received(peer_id: int, hp: int, max_hp: int, food: int, max_food: int, shield: int, level: int, alive: bool)
signal player_inventory_received(peer_id: int, data: Array)
signal death_chest_spawned(owner_peer: int, pos: Vector3, inv_data: Array)
signal player_respawned(peer_id: int, pos: Vector3)

signal multiplayer_started
signal multiplayer_stopped
signal local_player_registered(node: CharacterBody3D)
signal peer_registered(peer_id: int, player_name: String)
signal join_ready
signal welcome_received

func is_active() -> bool:
	return is_host or is_client

# ── LAN discovery ──────────────────────────────────────────────────────────────
## Host: mở socket lắng nghe ping broadcast, trả về thông tin thế giới.
## Browser (menu Multiplayer): quét broadcast, gom các pong vào found_hosts.
func start_discovery_listener() -> void:
	stop_discovery_listener()
	_discovery_socket = PacketPeerUDP.new()
	var err := _discovery_socket.bind(DISCOVERY_PORT, "*")
	if err != OK:
		push_error("MP: discovery bind fail %d" % err)
		_discovery_socket = null

func stop_discovery_listener() -> void:
	if _discovery_socket:
		_discovery_socket.close()
		_discovery_socket = null

func start_browser() -> void:
	stop_browser()
	_browser_socket = PacketPeerUDP.new()
	_browser_socket.set_broadcast_enabled(true)
	_browser_socket.bind(0, "*")
	_browser_timer = 0.0
	_browser_stopped = false
	found_hosts.clear()
	_send_discovery_ping()

func stop_browser() -> void:
	_browser_stopped = true
	if _browser_socket:
		_browser_socket.close()
		_browser_socket = null

func get_found_hosts() -> Array:
	return found_hosts

func _send_discovery_ping() -> void:
	if _browser_socket == null:
		return
	_browser_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_browser_socket.put_packet(DISCOVERY_PING.to_utf8_buffer())

func _poll_discovery(delta: float) -> void:
	# Host: trả pong cho mọi ping nhận được.
	if _discovery_socket:
		while _discovery_socket.get_available_packet_count() > 0:
			var data := _discovery_socket.get_packet()
			var msg := data.get_string_from_utf8()
			if msg != DISCOVERY_PING:
				continue
			var sender_ip := _discovery_socket.get_packet_ip()
			var sender_port := _discovery_socket.get_packet_port()
			var players: int = _peers.size() + 1
			var info := {
				"ip": sender_ip,
				"port": _server_port,
				"name": player_name,
				"world": WorldSeed.world_name,
				"players": players,
			}
			var payload := (DISCOVERY_PONG + JSON.stringify(info)).to_utf8_buffer()
			_discovery_socket.set_dest_address(sender_ip, sender_port)
			_discovery_socket.put_packet(payload)
	# Browser: quét định kỳ + gom pong.
	if _browser_socket == null or _browser_stopped:
		return
	_browser_timer -= delta
	if _browser_timer <= 0.0:
		_browser_timer = DISCOVERY_INTERVAL
		_send_discovery_ping()
	while _browser_socket.get_available_packet_count() > 0:
		var data := _browser_socket.get_packet()
		var msg := data.get_string_from_utf8()
		if not msg.begins_with(DISCOVERY_PONG):
			continue
		var json_str := msg.substr(DISCOVERY_PONG.length())
		var json := JSON.new()
		if json.parse(json_str) != OK:
			continue
		var info: Dictionary = json.data
		var ip := _browser_socket.get_packet_ip()
		info["ip"] = ip
		var key := "%s:%d" % [ip, int(info.get("port", 0))]
		var dup := false
		for h in found_hosts:
			if "%s:%d" % [str(h.get("ip", "")), int(h.get("port", 0))] == key:
				dup = true
				break
		if not dup:
			found_hosts.append(info)
			hosts_updated.emit(found_hosts)

func host_game(port: int, name: String) -> bool:
	if is_active():
		return false
	player_name = name
	_clear_peers()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 8)
	if err != OK:
		push_error("MP: create_server fail %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	is_host = true
	my_peer_id = 1
	_world_ready = false
	_local_player = null
	_server_port = port
	start_discovery_listener()
	multiplayer_started.emit()
	return true

func join_game(ip: String, port: int, name: String) -> bool:
	if is_active():
		return false
	player_name = name
	_clear_peers()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("MP: create_client fail %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	is_client = true
	_world_ready = false
	_local_player = null
	_welcome_players.clear()
	multiplayer_started.emit()
	return true

func leave_game() -> void:
	if not is_active():
		return
	_cleanup_remotes()
	if multiplayer.multiplayer_peer:
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	is_client = false
	_world_ready = false
	_local_player = null
	_clear_peers()
	_cleanup_remotes()
	_clear_block_edits()
	stop_discovery_listener()
	stop_browser()
	WorldSeed.use_remote_spawn = false
	WorldSeed.has_saved_player_pos = false
	multiplayer_stopped.emit()

# ── Player / world wiring ──────────────────────────────────────────────────────
## Đăng ký player cục bộ khi world sẵn sàng (gọi từ CharacterManager sau khi
## set_active, hoặc open_world_manager khi initial chunks xong).
func register_local_player(node: CharacterBody3D) -> void:
	if not is_active():
		return
	if _local_player == node:
		return
	_local_player = node
	_world_ready = true
	local_player_registered.emit(node)
	if is_host:
		_flush_pending_join()
	elif is_client:
		my_peer_id = multiplayer.get_unique_id()
		for p in _welcome_players:
			var pid: int = int(p["peer_id"])
			if pid == my_peer_id:
				continue
			_ensure_remote(pid, str(p["name"]), p["pos"])
		_welcome_players.clear()
		join_ready.emit()

func is_world_ready() -> bool:
	return _world_ready

# ── Host handlers ──────────────────────────────────────────────────────────────
func _on_peer_connected(peer_id: int) -> void:
	# Client mới nối tới chưa từng nhận inventory của các player khác; ép
	# re-broadcast inventory ở tick kế tiếp để late-joiner bắt kịp.
	_last_inv_json = ""
	pass

func _on_peer_disconnected(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	_peers.erase(peer_id)
	if is_host:
		_despawn_player(peer_id)
	_cleanup_remote(peer_id)

func _on_connected_to_server() -> void:
	my_peer_id = multiplayer.get_unique_id()
	request_join.rpc_id(1, player_name)

func _on_connection_failed() -> void:
	is_client = false
	multiplayer.multiplayer_peer = null
	push_error("MP: connection failed")
	multiplayer_stopped.emit()

func _on_server_disconnected() -> void:
	is_client = false
	multiplayer.multiplayer_peer = null
	_world_ready = false
	_local_player = null
	_cleanup_remotes()
	multiplayer_stopped.emit()

# ── RPC: client → host ─────────────────────────────────────────────────────────
var _pending_join_peer: int = 0
var _pending_join_name: String = ""

@rpc("any_peer", "call_remote", "reliable")
func request_join(p_name: String) -> void:
	if not is_host:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _peers.has(peer_id):
		return
	if not _world_ready:
		_pending_join_peer = peer_id
		_pending_join_name = p_name
		return
	_register_peer(peer_id, p_name)

func _flush_pending_join() -> void:
	if _pending_join_peer != 0 and not _peers.has(_pending_join_peer):
		_register_peer(_pending_join_peer, _pending_join_name)
	_pending_join_peer = 0
	_pending_join_name = ""

func _register_peer(peer_id: int, p_name: String) -> void:
	var spawn_pos: Vector3 = _host_spawn_pos()
	_peers[peer_id] = {
		"name": p_name,
		"pos": spawn_pos,
	}
	peer_registered.emit(peer_id, p_name)
	var list := _player_list_for(peer_id)
	world_info.rpc_id(peer_id, {
		"seed": WorldSeed.seed_value,
		"scene": WorldSeed.target_scene,
		"spawn": spawn_pos,
		"players": list,
		"block_edits": _block_edits.duplicate(),
	})
	_spawn_player(peer_id, p_name, spawn_pos)

func _host_spawn_pos() -> Vector3:
	if _local_player and is_instance_valid(_local_player):
		return _local_player.global_position + Vector3(2, 0, 2)
	return WORLD_SPAWN

func _player_list_for(except_id: int) -> Array:
	var out: Array = []
	# Host (peer 1) luôn nằm trong danh sách — mọi client phải thấy host.
	if except_id != 1:
		var host_pos: Vector3 = WORLD_SPAWN
		if _local_player and is_instance_valid(_local_player):
			host_pos = _local_player.global_position
		out.append({ "peer_id": 1, "name": player_name, "pos": host_pos })
	for pid in _peers:
		if pid == except_id:
			continue
		var info: Dictionary = _peers[pid]
		out.append({ "peer_id": pid, "name": info["name"], "pos": info["pos"] })
	return out

# ── RPC: host → client (world info) ────────────────────────────────────────────
@rpc("authority", "call_remote", "reliable")
func world_info(info: Dictionary) -> void:
	if is_client:
		_apply_welcome(info)

func _apply_welcome(info: Dictionary) -> void:
	WorldSeed.seed_value = int(info.get("seed", WorldSeed.seed_value))
	WorldSeed.target_scene = str(info.get("scene", WorldSeed.target_scene))
	WorldSeed.world_name = "Multiplayer_" + str(info.get("seed", 0))
	WorldSeed.is_loading = false
	WorldSeed.use_remote_spawn = true
	WorldSeed.saved_player_pos = info.get("spawn", WORLD_SPAWN)
	WorldSeed.has_saved_player_pos = true
	my_peer_id = multiplayer.get_unique_id()
	_welcome_players = info.get("players", [])
	_block_edits = info.get("block_edits", {}).duplicate()
	welcome_received.emit()

func _spawn_player(peer_id: int, p_name: String, pos: Vector3) -> void:
	rpc("net_spawn_player", peer_id, p_name, pos)

@rpc("authority", "call_local", "reliable")
func net_spawn_player(peer_id: int, p_name: String, pos: Vector3) -> void:
	if peer_id == my_peer_id:
		return
	_ensure_remote(peer_id, p_name, pos)

func _despawn_player(peer_id: int) -> void:
	rpc("net_despawn_player", peer_id)

@rpc("authority", "call_local", "reliable")
func net_despawn_player(peer_id: int) -> void:
	if peer_id == my_peer_id:
		return
	_cleanup_remote(peer_id)

# ── RemotePlayer management ────────────────────────────────────────────────────
func _ensure_remote(peer_id: int, p_name: String, pos: Vector3) -> Node3D:
	var existing: Node3D = _find_remote(peer_id)
	if existing:
		if existing.display_name != p_name:
			existing.set_name_label(p_name)
		return existing
	var remote := _RemotePlayer.new()
	remote.setup(peer_id, p_name, pos)
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(remote)
	remote.global_position = pos
	return remote

func _find_remote(peer_id: int) -> Node3D:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	for c in scene.get_children():
		if c is Node3D and c.has_method("is_remote_for") and c.is_remote_for(peer_id):
			return c as Node3D
	return null

func _cleanup_remote(peer_id: int) -> void:
	var r: Node3D = _find_remote(peer_id)
	if r:
		r.queue_free()

func _cleanup_remotes() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for c in scene.get_children():
		if c is Node3D and c.has_method("is_remote_for"):
			c.queue_free()

# ── Movement relay (host-authoritative order) ──────────────────────────────────
@rpc("any_peer", "call_remote", "unreliable")
func relay_move(pos: Vector3, yaw: float, moving: bool) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	rpc("net_move", sender, pos, yaw, moving)

@rpc("any_peer", "call_local", "unreliable")
func net_move(peer_id: int, pos: Vector3, yaw: float, moving: bool) -> void:
	if peer_id == my_peer_id:
		return
	var r: Node3D = _find_remote(peer_id)
	if r:
		r.apply_net_state(pos, yaw, moving)

# ── Player state sync (hp/food/shield, host-authoritative order) ──────────────
## Client gửi trạng thái local → host relay broadcast → mọi player. Mỗi máy
## tự cập nhật RemotePlayer (health bar) + emit player_state_received.
const STATE_TICK: float = 0.1
var _state_timer: float = 0.0
var _last_inv_json: String = ""

func _broadcast_player_state(delta: float) -> void:
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	_state_timer = STATE_TICK
	var lp := _local_player
	if lp == null or not is_instance_valid(lp):
		return
	var hp := _prop_int(lp, "hp", 100)
	var max_hp := _prop_int(lp, "max_hp", 100)
	var food := _prop_int(lp, "food", 20)
	var max_food := _prop_int(lp, "max_food", 20)
	var shield := _prop_int(lp, "shield", 0)
	var level := _prop_int(lp, "level", 1)
	var alive_val: Variant = lp.get("is_alive")
	var alive: bool = bool(alive_val) if alive_val != null else true
	if is_host:
		net_state.rpc(my_peer_id, hp, max_hp, food, max_food, shield, level, alive)
	else:
		relay_state.rpc_id(1, hp, max_hp, food, max_food, shield, level, alive)
	_broadcast_inventory_if_changed(lp)

func _prop_int(obj: Object, prop: String, fallback: int) -> int:
	var v: Variant = obj.get(prop)
	if v == null:
		return fallback
	return int(v)

func _broadcast_inventory_if_changed(lp: CharacterBody3D) -> void:
	var inv: Object = lp.get("inventory")
	if inv == null or not inv.has_method("to_dict"):
		return
	var data: Array = inv.to_dict()
	var json := JSON.stringify(data)
	if json == _last_inv_json:
		return
	_last_inv_json = json
	if is_host:
		net_inventory.rpc(my_peer_id, data)
	else:
		relay_inventory.rpc_id(1, data)

@rpc("any_peer", "call_remote", "unreliable")
func relay_state(hp: int, max_hp: int, food: int, max_food: int, shield: int, level: int, alive: bool) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	net_state.rpc(sender, hp, max_hp, food, max_food, shield, level, alive)

@rpc("any_peer", "call_local", "unreliable")
func net_state(peer_id: int, hp: int, max_hp: int, food: int, max_food: int, shield: int, level: int, alive: bool) -> void:
	if peer_id == my_peer_id:
		return
	var r: Node3D = _find_remote(peer_id)
	if r:
		r.apply_state(hp, max_hp, food, max_food, shield, level, alive)
	player_state_received.emit(peer_id, hp, max_hp, food, max_food, shield, level, alive)

@rpc("any_peer", "call_remote", "reliable")
func relay_inventory(data: Array) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	net_inventory.rpc(sender, data)

@rpc("any_peer", "call_local", "reliable")
func net_inventory(peer_id: int, data: Array) -> void:
	if peer_id == my_peer_id:
		return
	var r: Node3D = _find_remote(peer_id)
	if r:
		r.apply_inventory(data)
	player_inventory_received.emit(peer_id, data)

# ── Death / respawn relay (host-authoritative order) ──────────────────────────
## Player chết → mọi máy spawn death chest giống hệt (pos + inventory) tại điểm
## chết; respawn → snap vị trí RemotePlayer về đúng spawn (tránh lerp từ xa).

func announce_death_chest(pos: Vector3, inv_data: Array) -> void:
	if not is_active():
		return
	if is_host:
		net_death_chest.rpc(my_peer_id, pos, inv_data)
	else:
		relay_death_chest.rpc_id(1, pos, inv_data)

@rpc("any_peer", "call_remote", "reliable")
func relay_death_chest(pos: Vector3, inv_data: Array) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	net_death_chest.rpc(sender, pos, inv_data)

@rpc("any_peer", "call_local", "reliable")
func net_death_chest(owner_peer: int, pos: Vector3, inv_data: Array) -> void:
	death_chest_spawned.emit(owner_peer, pos, inv_data)

func announce_respawn(pos: Vector3) -> void:
	if not is_active():
		return
	if is_host:
		net_respawn.rpc(my_peer_id, pos)
	else:
		relay_respawn.rpc_id(1, pos)

@rpc("any_peer", "call_remote", "unreliable")
func relay_respawn(pos: Vector3) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	net_respawn.rpc(sender, pos)

@rpc("any_peer", "call_local", "unreliable")
func net_respawn(peer_id: int, pos: Vector3) -> void:
	if peer_id == my_peer_id:
		return
	player_respawned.emit(peer_id, pos)
	var r: Node3D = _find_remote(peer_id)
	if r:
		r.apply_net_state(pos, r.rotation.y, false)
		if r.has_method("snap_to"):
			r.snap_to(pos)

# ── Block edit sync (host-authoritative) ──────────────────────────────────────
## Gameplay gọi khi player local phá/đặt/cuốc block thành công. Dùng chung cho
## cả host và client: host thì tự ghi + broadcast; client thì gửi request host.
## `cell` là toạ độ canonical: x/z = floor(wx), y = slab layer (0-based).
func announce_block_edit(dim_id: int, cell: Vector3i, block_id: int) -> void:
	if not is_active():
		return
	if is_host:
		net_block_edit.rpc(dim_id, cell.x, cell.y, cell.z, block_id)
	else:
		request_block_edit.rpc_id(1, dim_id, cell.x, cell.y, cell.z, block_id)

@rpc("any_peer", "call_remote", "reliable")
func request_block_edit(dim_id: int, px: int, py: int, pz: int, block_id: int) -> void:
	if not is_host:
		return
	net_block_edit.rpc(dim_id, px, py, pz, block_id)

@rpc("authority", "call_local", "reliable")
func net_block_edit(dim_id: int, px: int, py: int, pz: int, block_id: int) -> void:
	_apply_block_edit(dim_id, Vector3i(px, py, pz), block_id)

func _apply_block_edit(dim_id: int, cell: Vector3i, block_id: int) -> void:
	_block_edits["%d:%d:%d:%d" % [dim_id, cell.x, cell.y, cell.z]] = block_id
	block_edit_applied.emit(dim_id, cell, block_id)

## Chuyển toạ độ world (tâm block) → canonical cell (x/z = floor(wx), y = layer).
func world_pos_to_cell(wx: float, wy: float, wz: float) -> Vector3i:
	return Vector3i(floori(wx), _BlockData.world_y_to_layer(wy), floori(wz))

## Chuyển canonical cell → world tâm block (dùng khi replay/edit).
func cell_to_world_pos(cell: Vector3i) -> Vector3:
	return Vector3(cell.x + 0.5, _BlockData.layer_to_world_y(cell.y), cell.z + 0.5)

## Replay mọi edit nằm trong chunk (cx, cz) — gọi khi chunk vừa được generate
## để áp lại các thay đổi đã ghi mà chunk chưa kịp có lúc edit.
func replay_chunk_edits(dim_id: int, chunk: WorldChunk, cx: int, cz: int) -> void:
	if chunk == null:
		return
	var size: int = chunk._size
	var half: int = int(size * 0.5)
	var x0: int = cx * size - half
	var z0: int = cz * size - half
	for key in _block_edits:
		var parts: PackedStringArray = String(key).split(":")
		if parts.size() != 4:
			continue
		if int(parts[0]) != dim_id:
			continue
		var bx := int(parts[1])
		var by := int(parts[2])
		var bz := int(parts[3])
		if bx < x0 or bx >= x0 + size or bz < z0 or bz >= z0 + size:
			continue
		var bid: int = int(_block_edits[key])
		var wpos: Vector3 = cell_to_world_pos(Vector3i(bx, by, bz))
		if bid == _Data.BlockID.AIR:
			chunk.break_block_at(wpos.x, wpos.y, wpos.z)
		else:
			chunk.place_block_at(wpos.x, wpos.y, wpos.z, bid)

func _clear_block_edits() -> void:
	_block_edits.clear()

# ── Chat relay (host-authoritative) ──────────────────────────────────────────
## Client gửi tin nhắn → host relay broadcast cho mọi player (kể cả client gửi).
## Host tự gửi thì broadcast thẳng. Mỗi máy emit chat_message_received khi nhận.
func send_chat_message(text: String) -> void:
	if not is_active():
		return
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	if is_host:
		relay_chat.rpc(player_name, my_peer_id, trimmed)
	else:
		request_chat.rpc_id(1, trimmed)

@rpc("any_peer", "call_remote", "reliable")
func request_chat(text: String) -> void:
	if not is_host:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var sname: String = _name_for_peer(sender)
	relay_chat.rpc(sname, sender, text)

@rpc("authority", "call_local", "reliable")
func relay_chat(sender_name: String, sender_id: int, text: String) -> void:
	chat_message_received.emit(sender_name, _color_for_peer(sender_id), text)

func _name_for_peer(pid: int) -> String:
	if pid == my_peer_id:
		return player_name
	if _peers.has(pid):
		return str(_peers[pid].get("name", "Player"))
	return "Player%d" % pid

func _color_for_peer(pid: int) -> Color:
	var palette: Array[Color] = [
		Color(0.35, 0.75, 1.0),
		Color(1.0, 0.65, 0.35),
		Color(0.55, 0.9, 0.45),
		Color(1.0, 0.85, 0.3),
		Color(0.85, 0.5, 0.95),
		Color(0.5, 0.85, 0.85),
		Color(0.95, 0.55, 0.6),
		Color(0.75, 0.9, 0.6),
	]
	return palette[abs(pid) % palette.size()]

func _process(delta: float) -> void:
	_poll_discovery(delta)
	if not is_active() or not _world_ready or _local_player == null or not is_instance_valid(_local_player):
		return
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_broadcast_player_state(delta)
	_move_timer -= delta
	if _move_timer > 0.0:
		return
	_move_timer = MOVE_TICK
	var lv := _local_player.velocity as Vector3
	var moving: bool = lv.length_squared() > 0.25
	if is_host:
		rpc("net_move", my_peer_id, _local_player.global_position, _local_player.rotation.y, moving)
	else:
		relay_move.rpc_id(1, _local_player.global_position, _local_player.rotation.y, moving)

func _clear_peers() -> void:
	_peers.clear()
