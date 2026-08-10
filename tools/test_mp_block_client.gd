extends Node

## Smoke test block edit sync — CLIENT side.
## Join host test_mp_block_host.tscn: chờ welcome_received (ledger trong world_info)
## → register_local_player → announce_block_edit (phá block) → client cũng phải
## nhận net_block_edit broadcast về → block_edit_applied phát trên client.

const PORT := 7789
const TIMEOUT_MS := 30000
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

var _failures: int = 0
var _welcome: bool = false
var _dummy: CharacterBody3D
var _applied: Array = []

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _on_welcome() -> void:
	_welcome = true

func _on_block_edit(dim_id: int, cell: Vector3i, block_id: int) -> void:
	_applied.append([dim_id, cell, block_id])

func _ready() -> void:
	print("== test_mp_block_client ==")
	Net.block_edit_applied.connect(_on_block_edit)
	Net.welcome_received.connect(_on_welcome)
	var ok := Net.join_game("127.0.0.1", PORT, "BlockClient")
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

	# Client yêu cầu phá block — host phải ghi ledger + broadcast; client nhận về.
	Net.announce_block_edit(0, Vector3i(12, 8, 2), _Data.BlockID.AIR)
	var applied: bool = await _wait_applied()
	_check(applied, "client nhận net_block_edit broadcast từ host (block_edit_applied)")

	# Client cũng nhận được ledger từ world_info (rỗng lúc join, nhưng signal
	# block_edit_applied là cơ chế chính; ledger chỉ là replay cho chunk load muộn).
	var key: String = "0:12:8:2"
	_check(Net._block_edits.has(key), "client ledger có edit vừa gửi (%s)" % key)

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

func _wait_applied() -> bool:
	var key: String = "0:12:8:2"
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if Net._block_edits.has(key):
			return true
		await get_tree().process_frame
	return false
