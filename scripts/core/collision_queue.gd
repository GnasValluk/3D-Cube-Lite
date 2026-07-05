## CollisionQueue — rate-limit việc add StaticBody3D vào scene tree.
##
## Vấn đề gốc: nhiều worker threads hoàn thành cùng lúc → call_deferred dồn
## vào 1 frame → Jolt register N bodies → 300ms physics spike.
##
## Giải pháp: queue tất cả pending collision, _process apply MAX_PER_FRAME/frame.

extends Node

const MAX_PER_FRAME: int = 1

## Mỗi entry: [chunk, shape] dạng Variant array
## để tránh crash khi chunk bị freed trước khi entry được xử lý.
var _queue: Array = []
var _mutex: Mutex = Mutex.new()

## Gọi từ worker thread — thread-safe
func push(chunk: Node3D, shape: Shape3D) -> void:
	var entry: Array = [chunk, shape]
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

	var count: int = 0
	while count < MAX_PER_FRAME and not _queue.is_empty():
		_mutex.lock()
		var entry: Array = _queue.pop_front()
		_mutex.unlock()

		var chunk = entry[0]   # Variant — không typed để tránh crash trên freed ref
		var shape = entry[1]

		if not is_instance_valid(chunk):
			continue
		if not chunk.is_inside_tree():
			continue

		chunk._apply_collision(shape)
		count += 1
