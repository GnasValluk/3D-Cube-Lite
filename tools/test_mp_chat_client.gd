extends Node

## Smoke test chat relay — CLIENT side.
## Join host test_mp_chat_host.tscn: chờ welcome → register_local_player →
## gửi "xin chao" → host relay → client nhận lại chat của mình. Host gửi
## "chaoban" → client cũng phải nhận.

const PORT := 7789
const TIMEOUT_MS := 30000

var _failures: int = 0
var _welcome: bool = false
var _dummy: CharacterBody3D
var _received: Array = []

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_welcome() -> void:
	_welcome = true

func _on_chat(sender_name: String, sender_color: Color, text: String) -> void:
	_received.append([sender_name, text])

func _ready() -> void:
	print("== test_mp_chat_client ==")
	Net.chat_message_received.connect(_on_chat)
	Net.welcome_received.connect(_on_welcome)
	var ok := Net.join_game("127.0.0.1", PORT, "ChatClient")
	_check(ok, "join_game(127.0.0.1,7789) ok")
	_check(Net.is_client, "is_client true")

	await _wait_welcome()
	_check(_welcome, "welcome_received đã phát")
	_check(WorldSeed.use_remote_spawn, "use_remote_spawn được set từ world_info")

	_dummy = CharacterBody3D.new()
	_dummy.name = "ClientDummy"
	add_child(_dummy)
	_dummy.global_position = Vector3(8, 2, 8)
	Net.register_local_player(_dummy)

	# Client gửi tin → host relay → nhận lại chính tin của mình.
	Net.send_chat_message("xin chao")
	var echoed: bool = await _wait_chat_from("ChatClient", "xin chao")
	_check(echoed, "client nhận lại chat mình gửi (ChatClient: xin chao)")

	# Host gửi "chaoban" → client nhận từ ChatHost.
	var from_host: bool = await _wait_chat_from("ChatHost", "chaoban")
	_check(from_host, "client nhận chat từ host (ChatHost: chaoban)")

	await get_tree().create_timer(2.0).timeout
	Net.leave_game()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _wait_welcome() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if _welcome:
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
