## CollisionQueue — rate-limit việc tạo shape + add StaticBody3D vào scene tree.
##
## Vấn đề gốc: nhiều worker threads hoàn thành cùng lúc → call_deferred dồn
## vào 1 frame → Jolt register N bodies → 300ms physics spike.
##
## Lưu ý an toàn thread: shape (create_trimesh_shape → physics server) PHẢI
## được tạo trên main thread — tạo trên worker thread gây hư hỏng server →
## crash 0xC0000005 khi process thoát (đã tái hiện tất định). Queue nhận mesh
## từ main thread, _process tạo shape + body, MAX_PER_FRAME/frame.

extends Node

const MAX_PER_FRAME: int = 8
## Budget thời gian chung mỗi frame — trimesh shape tốn ~6-12ms/cái (cost theo
## body, không theo tris). Giới hạn theo ms để không dồn nhiều shape nặng trong
## cùng 1 frame; luôn xử lý ≥1 job để không bị đói.
const TIME_BUDGET_US: int = 8000

## Mỗi entry: [chunk, mesh] dạng Variant array
## để tránh crash khi chunk bị freed trước khi entry được xử lý.
var _queue: Array = []
var _mutex: Mutex = Mutex.new()

## Gọi từ main thread (apply_chunk)
func push_mesh(chunk: Node3D, mesh: ArrayMesh) -> void:
	var entry: Array = [chunk, mesh]
	_mutex.lock()
	_queue.append(entry)
	_mutex.unlock()

## Gọi từ WorldChunk._notification(PREDELETE)
## Xóa tất cả entries của chunk đã bị freed khỏi queue
func remove_chunk(chunk: Node3D) -> void:
	_mutex.lock()
	var i: int = _queue.size() - 1
	while i >= 0:
		if _queue[i][0] == chunk:
			_queue.remove_at(i)
		i -= 1
	_mutex.unlock()

func _process(_delta: float) -> void:
	if _queue.is_empty():
		return

	var t_budget := Time.get_ticks_usec()
	var count: int = 0
	while count < MAX_PER_FRAME and not _queue.is_empty():
		if count > 0 and Time.get_ticks_usec() - t_budget >= TIME_BUDGET_US:
			break
		_mutex.lock()
		var entry: Array = _queue.pop_front()
		_mutex.unlock()

		var chunk = entry[0]   # Variant — không typed để tránh crash trên freed ref
		var mesh = entry[1]

		if not is_instance_valid(chunk):
			continue
		if not chunk.is_inside_tree():
			continue

		var shape: Shape3D = mesh.create_trimesh_shape()
		chunk._apply_collision(shape)
		count += 1
