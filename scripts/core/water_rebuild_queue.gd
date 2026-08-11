## WaterRebuildQueue — rate-limit water mesh rebuild trên main thread.
##
## Vấn đề gốc: refresh_boundary_water() rebuild water mesh của chunk mới + 4
## lân cận ĐỒNG BỘ trên main thread (~60ms/mesh → spike ~300ms khi băng qua
## biển, đây là nguồn lag chính khi load chunk mới).
##
## Lưu ý an toàn thread: build ArrayMesh (RenderingServer) trên worker thread
## gây hư hỏng server → crash 0xC0000005 khi process thoát (headless, đã tái
## hiện tất định bằng test_promote). Vì vậy mesh build CHẠY TRÊN MAIN, chỉ
## rate-limited 2 job/frame — load chunk mới vẫn mượt, không spike.

extends Node

const MAX_PER_FRAME: int = 4
## Budget thời gian chung cho mỗi frame — tránh 1 job nước rất nặng (~60ms)
## chiếm trọn frame; nếu job rẻ thì xử lý được nhiều job hơn trong cùng budget.
const TIME_BUDGET_US: int = 6000

var _pending: Array = []
var _mutex: Mutex = Mutex.new()

## Gọi từ main thread (refresh_boundary_water)
func push_jobs(jobs: Array) -> void:
	_mutex.lock()
	for j in jobs:
		_pending.append(j)
	_mutex.unlock()

## Xóa kết quả của chunk đã bị freed (tránh apply lên node không còn tồn tại).
func clear_for_chunk(inst_id: int) -> void:
	_mutex.lock()
	var i: int = _pending.size() - 1
	while i >= 0:
		if int(_pending[i].get("inst_id", -1)) == inst_id:
			_pending.remove_at(i)
		i -= 1
	_mutex.unlock()

func _process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var t_budget := Time.get_ticks_usec()
	var count: int = 0
	while count < MAX_PER_FRAME and not _pending.is_empty():
		if count > 0 and Time.get_ticks_usec() - t_budget >= TIME_BUDGET_US:
			break
		_mutex.lock()
		var job: Variant = _pending.pop_front()
		_mutex.unlock()
		var chunk = instance_from_id(int(job["inst_id"]))
		if not is_instance_valid(chunk) or not chunk.is_inside_tree() \
				or not chunk.has_method("_apply_water_mesh"):
			continue
		var mesh: ArrayMesh = WorldChunk._build_water_mesh_job(job)
		chunk._apply_water_mesh(mesh)
		count += 1
