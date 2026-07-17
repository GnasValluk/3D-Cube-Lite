@tool
extends EditorScript

const IN_DIR = "res://assets/icon_items/"
const OUT_DIR = "res://assets/models_items/"
const VOXEL_SIZE = 0.05

func _run() -> void:
	_process_dir(IN_DIR, OUT_DIR)
	print("=== All voxel models generated ===")


func _process_dir(in_dir_path: String, out_dir_path: String) -> void:
	var dir = DirAccess.open(in_dir_path)
	if not dir:
		return
		
	DirAccess.make_dir_recursive_absolute(out_dir_path)
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_process_dir(in_dir_path.path_join(file_name), out_dir_path.path_join(file_name))
		elif file_name.ends_with(".png"):
			_process_image(in_dir_path.path_join(file_name), out_dir_path.path_join(file_name.replace(".png", ".tres")))
		file_name = dir.get_next()

func _process_image(in_path: String, out_path: String) -> void:
	var img := Image.load_from_file(in_path.replace("res://", "d:/codespace/3d-project-cube-lite-zero-assets/"))
	if not img:
		push_error("Failed to load image: ", in_path)
		return
	
	img.convert(Image.FORMAT_RGBA8)
	var width = img.get_width()
	var height = img.get_height()
	
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var has_voxels = false
	
	for y in range(height):
		for x in range(width):
			var color = img.get_pixel(x, y)
			if color.a > 0.1: # Threshold for alpha
				_add_voxel(surface_tool, x, y, width, height, color)
				has_voxels = true
	
	if has_voxels:
		surface_tool.generate_normals()
		surface_tool.generate_tangents()
		var array_mesh = surface_tool.commit()
		
		var err = ResourceSaver.save(array_mesh, out_path)
		if err == OK:
			print("Saved voxel model: ", out_path)
		else:
			push_error("Failed to save voxel model: ", out_path, " err=", err)

func _add_voxel(st: SurfaceTool, x: int, y: int, img_width: int, img_height: int, color: Color) -> void:
	var s = VOXEL_SIZE
	
	var px = (x - img_width / 2.0) * s
	var py = (img_height / 2.0 - y) * s
	var pz = 0.0
	var hs = s / 2.0
	
	var p1 = Vector3(px - hs, py - hs, pz - hs)
	var p2 = Vector3(px + hs, py - hs, pz - hs)
	var p3 = Vector3(px + hs, py + hs, pz - hs)
	var p4 = Vector3(px - hs, py + hs, pz - hs)
	var p5 = Vector3(px - hs, py - hs, pz + hs)
	var p6 = Vector3(px + hs, py - hs, pz + hs)
	var p7 = Vector3(px + hs, py + hs, pz + hs)
	var p8 = Vector3(px - hs, py + hs, pz + hs)
	
	st.set_color(color)
	
	st.add_vertex(p5); st.add_vertex(p6); st.add_vertex(p7)
	st.add_vertex(p5); st.add_vertex(p7); st.add_vertex(p8)
	
	st.add_vertex(p2); st.add_vertex(p1); st.add_vertex(p4)
	st.add_vertex(p2); st.add_vertex(p4); st.add_vertex(p3)
	
	st.add_vertex(p1); st.add_vertex(p5); st.add_vertex(p8)
	st.add_vertex(p1); st.add_vertex(p8); st.add_vertex(p4)
	
	st.add_vertex(p6); st.add_vertex(p2); st.add_vertex(p3)
	st.add_vertex(p6); st.add_vertex(p3); st.add_vertex(p7)
	
	st.add_vertex(p8); st.add_vertex(p7); st.add_vertex(p3)
	st.add_vertex(p8); st.add_vertex(p3); st.add_vertex(p4)
	
	st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p6)
	st.add_vertex(p1); st.add_vertex(p6); st.add_vertex(p5)

