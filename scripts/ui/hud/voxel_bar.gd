extends Control
class_name VoxelBar

var bar_color: Color = Color.RED
var bar_empty_color: Color = Color(0.15, 0.05, 0.05)
var max_value: int = 20
var num_voxels: int = 14

var value: int = 20:
	set(v):
		v = clampi(v, 0, max_value)
		if v != _value:
			_animate_change(_value, v)

var _value: int = 20
var _voxels: Array[ColorRect] = []
var _voxel_bgs: Array[ColorRect] = []
var _voxel_size: float = 8.0
var _tween: Tween
var _initialized: bool = false

func setup(bar_col: Color, empty_col: Color, num: int, mx: int) -> void:
	bar_color = bar_col
	bar_empty_color = empty_col
	num_voxels = num
	max_value = mx
	_value = mx
	value = mx
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_voxels.clear()
	_voxel_bgs.clear()

	var pad: float = 3.0
	var total_h: float = _voxel_size + pad * 2.0
	var total_w: float = num_voxels * (_voxel_size + 1.0) - 1.0 + pad * 2.0
	custom_minimum_size = Vector2(total_w, total_h)

	var vx_start: float = pad
	var vy: float = pad
	for i in num_voxels:
		var bx: float = vx_start + i * (_voxel_size + 1.0)
		var bg := ColorRect.new()
		bg.color = Color(bar_empty_color.r * 0.5, bar_empty_color.g * 0.5, bar_empty_color.b * 0.5, 0.25)
		bg.size = Vector2(_voxel_size, _voxel_size)
		bg.position = Vector2(bx, vy)
		add_child(bg)
		_voxel_bgs.append(bg)

		var r := ColorRect.new()
		r.color = bar_empty_color
		r.size = Vector2(_voxel_size, _voxel_size)
		r.position = Vector2(bx, vy)
		add_child(r)
		_voxels.append(r)

	_initialized = true
	_apply_state(false)

func _apply_state(immediate: bool) -> void:
	if not _initialized:
		return
	var filled: float = float(_value) / float(max_value) * float(num_voxels)
	var filled_int: int = floori(filled)
	var frac: float = filled - float(filled_int)
	for i in num_voxels:
		var r: ColorRect = _voxels[i]
		if i < filled_int:
			r.color = bar_color
			if immediate:
				r.modulate = Color.WHITE
				r.scale = Vector2.ONE
		elif i == filled_int and frac > 0.01:
			r.color = bar_color.lerp(bar_empty_color, 1.0 - frac)
			if immediate:
				r.modulate = Color.WHITE
				r.scale = Vector2.ONE
		else:
			r.color = bar_empty_color
			if immediate:
				r.modulate = Color.WHITE
				r.scale = Vector2.ONE

func _animate_change(old_val: int, new_val: int) -> void:
	if not _initialized:
		_value = new_val
		return
	_value = new_val
	var old_filled: float = float(old_val) / float(max_value) * float(num_voxels)
	var new_filled: float = float(new_val) / float(max_value) * float(num_voxels)

	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()

	for i in num_voxels:
		var i_filled: float = float(i) / float(num_voxels) * float(max_value)
		var was_filled: bool = i_filled < float(old_val)
		var now_filled: bool = i_filled < float(new_val)

		if was_filled and not now_filled:
			_tween.tween_callback(_play_break.bind(i)).set_delay(float(i) * 0.015)
		elif not was_filled and now_filled:
			_tween.tween_callback(_play_fill.bind(i)).set_delay(float(i) * 0.015)

	_tween.tween_interval(0.4)
	_tween.tween_callback(_apply_state.bind(true))

func _play_break(idx: int) -> void:
	if idx < 0 or idx >= _voxels.size():
		return
	var r: ColorRect = _voxels[idx]
	r.color = Color.WHITE
	for p in 3:
		var part := ColorRect.new()
		part.color = bar_color
		part.size = Vector2(3, 3) if p % 2 == 0 else Vector2(2, 2)
		part.position = r.position + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		add_child(part)
		var pt := create_tween()
		pt.tween_property(part, "position",
			part.position + Vector2(randf_range(-20.0, 20.0), randf_range(-30.0, -8.0)),
			0.35).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(part, "modulate:a", 0.0, 0.35)
		pt.tween_callback(part.queue_free)

func _play_fill(idx: int) -> void:
	if idx < 0 or idx >= _voxels.size():
		return
	var r: ColorRect = _voxels[idx]
	r.color = bar_color
	r.modulate = Color(1, 1, 1, 0)
	r.scale = Vector2(0.01, 0.01)
	var vt := create_tween()
	vt.tween_property(r, "modulate", Color.WHITE, 0.12)
	vt.parallel().tween_property(r, "scale", Vector2.ONE, 0.18
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


