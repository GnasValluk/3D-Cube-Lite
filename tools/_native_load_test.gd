extends SceneTree

func _init() -> void:
	var t := NativeTest.new()
	var r: int = t.test_add(20, 22)
	print("NATIVE_TEST_RUN result=" + str(r))
	t.free()
	quit()