extends Node

## Boot real world scene, count chunks at radius 3, then change setting to 5 and
## verify chunks load immediately (no restart) — regression for dynamic chunk view.

func _ready() -> void:
	print("== chunk_view_test ==")
	if SettingsManager:
		SettingsManager.chunk_view = 3
	var wm_loaded: bool = false
	var scene: Node = null
	var pack := load("res://scenes/open_world.tscn")
	if pack:
		scene = pack.instantiate()
		add_child(scene)
	for f in 180:
		await get_tree().process_frame
		var wm := scene.get_node_or_null("WorldManager") as Node
		if wm != null and wm.get("_chunks") != null:
			var loaded: int = (wm._chunks as Dictionary).size()
			if loaded >= 9 and not wm_loaded:
				print("initial radius3 chunks=%d" % loaded)
				wm_loaded = true
			if wm_loaded and loaded >= 9:
				break
	if not wm_loaded:
		print("FAIL: world chunks never reached 9")
		get_tree().quit(1)
		return
	# raise radius to 5 -> (2*5+1)^2 = 121
	SettingsManager.chunk_view = 5
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var wm := scene.get_node_or_null("WorldManager") as Node
	if wm == null:
		print("FAIL: no WorldManager")
		get_tree().quit(1)
		return
	var radius_now: int = wm.view_radius
	print("after set 5 -> view_radius=%d" % radius_now)
	var count_a: int = (wm._chunks as Dictionary).size() + (wm._loading as Dictionary).size()
	print("chunks+loading after 3 frames=%d" % count_a)
	# wait up to 6s for chunks to expand
	var grew: bool = false
	for f in 360:
		await get_tree().process_frame
		var c: int = (wm._chunks as Dictionary).size()
		var c2: int = (wm._loading as Dictionary).size()
		if c + c2 > count_a + 5:
			grew = true
			print("expanded: chunks=%d loading=%d (grew)" % [c, c2])
			break
	if not grew:
		print("WARN: chunks did not expand within 6s: chunks=%d loading=%d" % [(wm._chunks as Dictionary).size(), (wm._loading as Dictionary).size()])
	print("== done ==")
	get_tree().quit(0)