extends Node

## Smoke test chat relay — HOST side.
## Chạy cùng test_mp_chat_client.tscn. Verify: client gửi chat → host relay →
## chat_message_received phát trên host (tên client + text đúng). Host tự gửi
## cũng phải nhận được message.

const PORT := 7789
const TIMEOUT_MS := 30000

var _failures: int = 0
var _dummy: CharacterBody3D
var _received: Array = []

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_chat(sender_name: String, sender_color: Color, text: String) -> void:
	_received.append([sender_name, text])

func _ready() -> void:
	print("== test_mp_chat_host ==")
	Net.chat_message_received.connect(_on_chat)
	var ok := Net.host_game(PORT, "ChatHost")
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

	# 1) Client gửi "xin chao" → host phải nhận relay_chat từ client.
	var got_client: bool = await _wait_chat_from("ChatClient", "xin chao")
	_check(got_client, "host nhận chat từ client (ChatClient: xin chao)")

	# 2) Host tự gửi "chaoban" → broadcast → host cũng nhận message của mình.
	Net.send_chat_message("chaoban")
	var got_self: bool = await _wait_chat_from("ChatHost", "chaoban")
	_check(got_self, "host nhận chat chính mình gửi (ChatHost: chaoban)")

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

func _wait_chat_from(sender: String, text: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for r in _received:
			if str(r[0]) == sender and str(r[1]) == text:
				return true
		await get_tree().process_frame
	return false

func _wait_peer_disconnect() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._peers.size() == 0:
			return
		await get_tree().process_frame
