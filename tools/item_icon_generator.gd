@tool
extends Node

const OUT := "res://assets/icon_items/"

## Icon các loại bàn được render trực tiếp từ ENTITY (model thật trong game)
## để icon luôn giống hệt model ngoài thế giới.
const TABLE_ENTITIES := {
	"crafting_table": preload("res://scripts/items/entities/crafting_table.gd"),
	"tool_table": preload("res://scripts/items/entities/tool_table.gd"),
	"mech_table": preload("res://scripts/items/entities/mech_table.gd"),
	"farm_table": preload("res://scripts/items/entities/farm_table.gd"),
	"chem_table": preload("res://scripts/items/entities/chem_table.gd"),
	"magic_table": preload("res://scripts/items/entities/magic_table.gd"),
	"kitchen_table": preload("res://scripts/items/entities/kitchen_table.gd"),
	"architecture_table": preload("res://scripts/items/entities/architecture_table.gd"),
}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_run()

func _run() -> void:
	ItemDatabase.ensure_db()
	var only := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			for id in a.substr(5).split(",", false):
				only[id] = true
	var ids: Array[String] = []
	for k in ItemDatabase.items_db.keys():
		ids.append(k)
	ids.sort()
	for item_id in ids:
		if not only.is_empty() and not only.has(item_id):
			continue
		await _snap_item(item_id)
	print("=== All item icons generated ===")
	get_tree().quit(0)

func _snap_item(item_id: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)

	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	cam.near = 0.01
	cam.far = 100.0

	for p in [Vector3(3, 6, 4), Vector3(-3, 4, -2)]:
		var lt := DirectionalLight3D.new()
		vp.add_child(lt)
		lt.look_at_from_position(p, Vector3.ZERO)
		lt.light_energy = 1.5 if p.z > 0 else 0.6

	var root := Node3D.new()
	vp.add_child(root)

	var held_items := ["pickaxe", "shovel", "axe", "iron_sword", "fishing_rod",
		"iron_greatsword", "iron_halberd", "leather_gloves", "crossbow",
		"watermelon_cannon", "arrow", "watermelon_nuke_ammo", "pumpkin_mortar",
		"ak_12", "bullet_762mm", "m200", "bullet_338mm"]

	if item_id in held_items:
		ToolsMesh.build_held(root, item_id)
	elif TABLE_ENTITIES.has(item_id):
		root.add_child(TABLE_ENTITIES[item_id].new())
		await get_tree().process_frame
	else:
		ItemMesh.build(root, item_id)

	var aabb := _compute_aabb(root)
	if aabb != AABB():
		var center := aabb.get_center()
		root.position = -center

		var max_size := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		cam.size = maxf(max_size, 0.01) * 1.5

	var dir := Vector3(2.0, 1.5, 2.0).normalized()
	cam.look_at_from_position(dir * 5.0, Vector3.ZERO)

	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var img: Image = vp.get_texture().get_image()
	if img:
		# get_image() của SubViewport có thể trả về định dạng float/HDR mà PNG
		# writer không ghi được → ép về RGBA8 trước khi lưu.
		img.convert(Image.FORMAT_RGBA8)
		var d := DirAccess.open("res://")
		if d:
			d.make_dir_recursive("assets/icon_items")
		var out := OUT.path_join(item_id + ".png")
		var abs := ProjectSettings.globalize_path(out)
		var r := img.save_png(abs)
		if r == OK:
			print("Saved: ", out)
		else:
			await _retry_save(img, abs, out, r)
	vp.queue_free()
	await get_tree().process_frame

func _retry_save(img: Image, abs: String, out: String, r: Error) -> void:
	var attempts := 6
	for i in attempts:
		await get_tree().create_timer(0.5).timeout
		# Ghi đè một file đã có .import có thể bị editor giữ khóa trong lúc scan
		# → nếu ghi lỗi, thử xoá file cũ rồi ghi lại.
		if r != OK:
			DirAccess.remove_absolute(abs)
		r = img.save_png(abs)
		if r == OK:
			print("Saved (retry ", i + 1, "): ", out)
			return
	push_error("Save failed: ", out, " err=", r)

static func _compute_aabb(root: Node3D) -> AABB:
	var aabb: AABB
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		var mesh_aabb := mi.mesh.get_aabb()
		var global_aabb := mi.global_transform * mesh_aabb
		if first:
			aabb = global_aabb
			first = false
		else:
			aabb = aabb.merge(global_aabb)
	return aabb
