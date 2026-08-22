extends Control

## CROSSHAIR giữa màn hình cho súng / nỏ / cung — vẽ bằng _draw():
## 4 vạch chữ thập + chấm tròn trung tâm, viền tối dễ nhìn trên mọi nền.

const GAP := 7.0        # khoảng hở từ tâm
const LEN := 9.0        # chiều dài vạch
const THICK := 2.0
var _col := Color(0.95, 0.97, 1.00, 0.92)
var _outline := Color(0.05, 0.05, 0.08, 0.85)
## Độ căng (cung): nới rộng vạch + sáng lên khi căng hết
var _charge := 0.0

func set_charge(v: float) -> void:
	var nv := clampf(v, 0.0, 1.0)
	if nv != _charge:
		_charge = nv
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(64, 64)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var gap := GAP + _charge * 4.0
	var col := Color(_col.r, _col.g, _col.b,
		lerpf(0.75, 1.0, _charge))
	# Vạch chữ thập (trên/dưới/trái/phải) + viền tối
	_line(c + Vector2(0, -gap - LEN * 0.5), Vector2(0, LEN))
	_line(c + Vector2(0, gap + LEN * 0.5), Vector2(0, LEN))
	_line(c + Vector2(-gap - LEN * 0.5, 0), Vector2(LEN, 0))
	_line(c + Vector2(gap + LEN * 0.5, 0), Vector2(LEN, 0))
	# Chấm trung tâm
	draw_circle(c, 1.8, Color(col.r, col.g, col.b, col.a))
	draw_circle(c, 3.0, Color(_outline.r, _outline.g, _outline.b, 0.25))

func _line(center: Vector2, size: Vector2) -> void:
	var half := size * 0.5
	var rect := Rect2(center - half - Vector2.ONE * (THICK * 0.5),
		size + Vector2.ONE * THICK)
	draw_rect(rect, _outline)
	var inner := Rect2(center - half, size)
	draw_rect(inner, _col)
