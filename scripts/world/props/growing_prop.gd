class_name GrowingProp
extends DestroyableProp

## Cây có vòng đời: MẦM → NON → TRƯỞNG THÀNH (→ CHÍN nếu cây có 3 ngưỡng)
## theo thời gian game (TimeSystem). Ngày "sinh" được sinh ra từ hash vị trí
## → mỗi cây có tuổi riêng, ổn định giữa các lần load world, và dần trưởng
## thành khi người chơi chơi lâu.

const CYCLE_DURATION: float = 600.0  # 1 ngày game = 10 phút thực (TimeSystem.CYCLE_DURATION)

enum Stage { SPROUT = 0, YOUNG = 1, MATURE = 2, RIPE = 3 }

const _CHECK_INTERVAL: float = 3.0

var _birth_cycle: float = 0.0
var _birth_set: bool = false
var _stage: int = Stage.SPROUT
var _check_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_birth_cycle = _get_now_cycle() \
		- _hash_position_to_float(global_position) * _birth_span_days() * CYCLE_DURATION
	_birth_set = true
	_stage = _compute_stage()

## Số ngày game tối đa mà cây được sinh ra trong quá khứ (khoảng tuổi tự nhiên).
func _birth_span_days() -> float:
	return 40.0

## [ngày hết MẦM, ngày hết NON, (ngày hết QUẢ NON)] — có 3 ngưỡng thì cây
## có thêm giai đoạn CHÍN (RIPE); 2 ngưỡng thì TRƯỞNG THÀNH là giai đoạn cuối.
func _stage_thresholds() -> Array[float]:
	return [5.0, 15.0]

func _get_now_cycle() -> float:
	if TimeSystem != null:
		return TimeSystem.get_cycle_time()
	return 0.0

func _compute_stage() -> int:
	if not _birth_set:
		return Stage.SPROUT
	var age_days := (_get_now_cycle() - _birth_cycle) / CYCLE_DURATION
	if age_days < 0.0:
		age_days = 0.0
	var th := _stage_thresholds()
	if age_days < th[0]:
		return Stage.SPROUT
	if age_days < th[1]:
		return Stage.YOUNG
	if th.size() < 3:
		return Stage.MATURE
	if age_days < th[2]:
		return Stage.MATURE
	return Stage.RIPE

func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = _CHECK_INTERVAL
		_check_growth()

## Kiểm tra tuổi mỗi vài giây; nếu qua ngưỡng thì chuyển giai đoạn + rebuild hình.
func _check_growth() -> void:
	var s := _compute_stage()
	if s != _stage:
		var from: int = _stage
		_stage = s
		_apply_stage(from, s)

func _apply_stage(_from: int, _to: int) -> void:
	pass

## Hook test: đặt tuổi cây (ngày game) — nếu qua ngưỡng giai đoạn thì chuyển + rebuild
## y hệt khi thời gian thật trôi trong game.
func set_birth_age_days(days: float) -> void:
	_birth_cycle = _get_now_cycle() - days * CYCLE_DURATION
	_birth_set = true
	var s := _compute_stage()
	if s != _stage:
		var from: int = _stage
		_stage = s
		_apply_stage(from, s)

## Hiệu ứng "nhú lên" khi cây lớn thêm một giai đoạn.
func _pop_growth() -> void:
	scale = Vector3.ONE * 0.85
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Hash ổn định vị trí thế giới → [0..1): mỗi vị trí có 1 số duy nhất.
static func _hash_position_to_float(p: Vector3) -> float:
	var h: int = int(p.x * 374761393) ^ int(p.y * 668265263) ^ int(p.z * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7FFFFFFF) / 2147483648.0
