## WaterRebuildQueue — rebuild water mesh trên WORKER THREAD, áp kết quả trên main.
##
## Vấn đề cũ: refresh_boundary_water() đẩy job rebuild water mesh (kèm lân cận để
## nước liền mạch qua biên chunk) và WaterRebuildQueue._process build ĐỒNG BỘ trên
## main thread — mỗi job ~30-90ms → mỗi lần băng qua hồ/sông/biển bị giật nặng.
##
## Giải pháp: build ArrayMesh trên WorkerThreadPool (giống terrain mesh trong
## compute_chunk — SurfaceTool.commit() gửi command queue an toàn từ worker), chỉ
## _apply_water_mesh (gán mesh lên MeshInstance3D) chạy trên main thread khi xong.
## Job giữ reference block_data nên dữ liệu không bị free giữa chừng; apply lên
## chunk đã freed được chặn bằng is_instance_valid.
##
## Lưu ý teardown: mọi task được đăng ký qua WorldChunk._track_task() để
## wait_for_tasks_async() (dùng trong test) đợi trước khi thoát process.

extends Node

const MAX_SUBMIT_PER_FRAME: int = 4

var _pending: Array = []
var _mutex: Mutex = Mutex.new()
## [task_id, chunk_inst_id, slot] — đang build trên worker; slot là Array[1] để
## worker ghi mesh vào slot[0], main chỉ đọc sau khi task completed.
var _in_flight: Array = []

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
	# Bỏ luôn job đang build nhưng chunk đã chết → không phí worker. Slot được
	# worker ghi nhưng không ai đọc (entry đã bị xóa).
	i = _in_flight.size() - 1
	while i >= 0:
		if int(_in_flight[i][1]) == inst_id:
			_in_flight.remove_at(i)
		i -= 1
	_mutex.unlock()

func _process(_delta: float) -> void:
	# ── Harvest: áp mesh đã build xong lên main thread ───────────────────────
	var i := _in_flight.size() - 1
	while i >= 0:
		var e: Array = _in_flight[i]
		if not WorkerThreadPool.is_task_completed(e[0]):
			i -= 1
			continue
		_in_flight.remove_at(i)
		var chunk = instance_from_id(int(e[1]))
		if is_instance_valid(chunk) and chunk.is_inside_tree() \
				and chunk.has_method("_apply_water_mesh"):
			chunk._apply_water_mesh(e[2][0])
		i -= 1

	# ── Submit jobs mới lên worker (submission rẻ, build song song) ─────────
	var count: int = 0
	while count < MAX_SUBMIT_PER_FRAME and not _pending.is_empty():
		_mutex.lock()
		var job: Variant = _pending.pop_front()
		_mutex.unlock()
		if job == null:
			break
		var slot: Array = [null]
		var tid: int = WorkerThreadPool.add_task(_build_water_task.bind(job, slot))
		WorldChunk._track_task(tid)
		_in_flight.append([tid, int(job["inst_id"]), slot])
		count += 1

## Worker: build ArrayMesh water từ job data (chỉ đọc, không đụng scene tree).
func _build_water_task(job: Dictionary, slot: Array) -> void:
	slot[0] = WorldChunk._build_water_mesh_job(job)
