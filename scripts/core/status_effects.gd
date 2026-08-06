## core/status_effects.gd
## Hệ thống hiệu ứng trạng thái (status effects) cho nhân vật.
## Hiện có hiệu ứng LÀM CHẬM (debuff) với 5 cấp độ.
##
##   Cấp | Giảm tốc | Không nhảy | Không tương tác
##   ----+----------+------------+-----------------
##    1  |   15%    |     ✗      |       ✗
##    2  |   30%    |     ✗      |       ✗
##    3  |   50%    |     ✗      |       ✗
##    4  |   70%    |     ✔      |       ✗
##    5  |   95%    |     ✔      |       ✔  (vật, thú cưỡi, phương tiện)

class_name StatusEffects
extends RefCounted

const SLOW_LEVELS: Dictionary = {
	1: { "reduction": 0.15, "no_jump": false, "no_interact": false },
	2: { "reduction": 0.30, "no_jump": false, "no_interact": false },
	3: { "reduction": 0.50, "no_jump": false, "no_interact": false },
	4: { "reduction": 0.70, "no_jump": true,  "no_interact": false },
	5: { "reduction": 0.95, "no_jump": true,  "no_interact": true },
}

## Kiểu hiệu ứng — tương lai mở rộng thêm (độc, cháy, ...)
enum Type { SLOW }

## Hiệu ứng làm chậm tạm thời (vd: slime pool, khả năng kẻ địch bắn ra)
var _slow_level: int = 0
var _slow_duration: float = 0.0
## Hiệu ứng làm chậm thường trực (vd: quá tải theo trọng lượng kho đồ)
var _persist_slow: int = 0

signal effects_changed

func _init(_owner: Node = null) -> void:
	pass

## Cấp làm chậm tổng hợp (lấy cấp cao nhất giữa tạm thời và thường trực).
func get_slow_level() -> int:
	return maxi(_persist_slow, _slow_level)

## Cấp làm chậm tạm thời hiện tại.
func get_temp_slow_level() -> int:
	return _slow_level

func get_effective_slow_info() -> Dictionary:
	return SLOW_LEVELS.get(get_slow_level(), {})

## Áp dụng làm chậm tạm thời (level 1-5, giữ cấp cao hơn nếu đang có).
func apply_slow(level: int, duration: float) -> void:
	level = clampi(level, 1, 5)
	if level > _slow_level:
		_slow_level = level
	_slow_duration = maxf(_slow_duration, duration)
	effects_changed.emit()

## Xoá hiệu ứng làm chậm tạm thời.
func clear_slow() -> void:
	if _slow_level == 0 and _slow_duration <= 0.0:
		return
	_slow_level = 0
	_slow_duration = 0.0
	effects_changed.emit()

## Thiết lập làm chậm thường trực theo cấp cho sẵn (0 = tắt). Dùng cho quá tải trọng số.
func set_persistent_slow(level: int) -> void:
	level = clampi(level, 0, 5)
	if level != _persist_slow:
		_persist_slow = level
		effects_changed.emit()

## Cập nhật theo thời gian — gọi mỗi frame từ CharacterBase.
func tick(delta: float) -> void:
	if _slow_level > 0:
		_slow_duration -= delta
		if _slow_duration <= 0.0:
			_slow_level = 0
			_slow_duration = 0.0
			effects_changed.emit()

## Hệ số tốc độ di chuyển hiệu dụng (1.0 = bình thường).
func get_move_multiplier() -> float:
	var lvl := get_slow_level()
	if lvl <= 0:
		return 1.0
	return 1.0 - SLOW_LEVELS[lvl]["reduction"]

## Có được nhảy hay không.
func can_jump() -> bool:
	var lvl := get_slow_level()
	if lvl <= 0:
		return true
	return not SLOW_LEVELS[lvl]["no_jump"]

## Có được tương tác (đồ vật, thú cưỡi, phương tiện) hay không.
func can_interact() -> bool:
	var lvl := get_slow_level()
	if lvl <= 0:
		return true
	return not SLOW_LEVELS[lvl]["no_interact"]

func has_active_effect() -> bool:
	return get_slow_level() > 0