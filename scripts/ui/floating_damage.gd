## ui/floating_damage.gd
## Số sát thương nổi lên khi nhân vật bị đánh.

extends Node3D
class_name FloatingDamage

func setup(damage: int, pos: Vector3, color: Color = Color.WHITE) -> void:
	position = pos + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))

	var label := Label3D.new()
	label.text = str(damage)
	label.font_size = 96
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.modulate = color
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0035
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector3(0, 2.5, 0), 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", Vector3(0, 0.6, 0), 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free).set_delay(1.2)
