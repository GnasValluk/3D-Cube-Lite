class_name Furnace
extends DestructibleEntity

var _player_nearby: bool = false
var _is_open: bool = false
var _fire_particles: GPUParticles3D
var _smoke_particles: GPUParticles3D

func _init() -> void:
	max_hp = 100
	drop_item_id = "furnace"

## Phân biệt chế độ lò (nung quặng) — CookingStove ghi đè để bếp nấu dùng
## FurnaceUI ở chế độ cooking.
func get_furnace_mode() -> String:
	return "smelt"

func _ready() -> void:
	super._ready()
	_setup_mesh()
	_setup_area()
	_setup_fire_vfx()

func _m(color: Color, metallic: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = rough
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _setup_mesh() -> void:
	var stone := _m(Color(0.30, 0.28, 0.26), 0.1, 0.9)
	var stone2 := _m(Color(0.27, 0.25, 0.23), 0.1, 0.92)
	var stone_dark := _m(Color(0.20, 0.18, 0.17), 0.1, 0.95)
	var brick := _m(Color(0.40, 0.22, 0.15), 0.0, 0.85)
	var brick_dark := _m(Color(0.32, 0.16, 0.10), 0.0, 0.9)
	var mortar := _m(Color(0.24, 0.22, 0.20), 0.0, 0.95)
	var metal := _m(Color(0.22, 0.22, 0.25), 0.4, 0.6)
	var metal_bright := _m(Color(0.42, 0.42, 0.47), 0.6, 0.35)
	var metal_dark := _m(Color(0.15, 0.15, 0.18), 0.4, 0.7)
	var anvil_mat := _m(Color(0.28, 0.28, 0.32), 0.5, 0.5)
	var fire_glow := _m(Color(0.80, 0.30, 0.05), 0.0, 0.8)
	var fire_hot := _m(Color(0.95, 0.60, 0.10), 0.0, 0.7)
	var fire_core := _m(Color(1.0, 0.85, 0.30), 0.0, 0.6)
	var gold_ore := _m(Color(0.37, 0.33, 0.29))
	var iron_ore := _m(Color(0.36, 0.31, 0.26))
	var copper_ore := _m(Color(0.38, 0.29, 0.18))
	var wood := _m(Color(0.42, 0.26, 0.14), 0.05, 0.85)
	var wood_dark := _m(Color(0.33, 0.19, 0.09), 0.05, 0.9)
	var coal := _m(Color(0.12, 0.12, 0.14), 0.0, 0.95)
	var ash := _m(Color(0.45, 0.44, 0.42), 0.0, 0.9)
	var soot := _m(Color(0.10, 0.09, 0.09), 0.0, 0.95)
	var ember := _m(Color(0.90, 0.35, 0.06), 0.0, 0.7)

	# ---- FURNACE BODY ----
	var fw := 1.60  # furnace width
	var fh := 0.65  # furnace height
	var fd := 0.80  # furnace depth
	var fy := fh * 0.5

	# Main body — stone blocks with variation
	_box(self, Vector3(fw, fh, fd), Vector3(0, fy, 0), stone)
	# Stone block seams (horizontal rows)
	for i in range(4):
		_box(self, Vector3(fw + 0.02, 0.01, fd + 0.02), Vector3(0, 0.13 + i * 0.14, 0), mortar)
	# Stone block seams (vertical, staggered)
	for i in range(5):
		var vx := -0.64 + i * 0.32
		_box(self, Vector3(0.01, 0.24, fd + 0.02), Vector3(vx, 0.18, 0), mortar)
	for i in range(4):
		var vx2 := -0.48 + i * 0.32
		_box(self, Vector3(0.01, 0.24, fd + 0.02), Vector3(vx2, 0.45, 0), mortar)
	# Tone variation patches on front
	for entry in [
		[-0.35, 0.20, Vector3(0.14, 0.06, 0.01)],
		[0.45, 0.32, Vector3(0.18, 0.05, 0.01)],
		[-0.15, 0.45, Vector3(0.12, 0.04, 0.01)],
		[0.30, 0.16, Vector3(0.10, 0.05, 0.01)],
	]:
		_box(self, entry[2], Vector3(entry[0], entry[1], fd * 0.5 + 0.005), stone2)

	# Brick trim at top (double row)
	_box(self, Vector3(fw + 0.04, 0.06, fd + 0.04), Vector3(0, fh, 0), brick)
	_box(self, Vector3(fw + 0.06, 0.05, fd + 0.06), Vector3(0, fh + 0.055, 0), brick_dark)
	# Brick corner stones (top)
	for cx in [-fw * 0.5 - 0.01, fw * 0.5 + 0.01]:
		for cz in [-fd * 0.5 - 0.01, fd * 0.5 + 0.01]:
			_box(self, Vector3(0.12, 0.08, 0.12), Vector3(cx, fh - 0.03, cz), brick_dark)

	# Brick trim at base
	_box(self, Vector3(fw + 0.04, 0.06, fd + 0.04), Vector3(0, 0.03, 0), brick)
	# Brick base footer
	_box(self, Vector3(fw + 0.10, 0.05, fd + 0.10), Vector3(0, 0.055, 0), brick_dark)
	# Ash pile at base front
	_box(self, Vector3(0.30, 0.03, 0.16), Vector3(0, 0.085, fd * 0.5 + 0.02), ash)

	# Stone arch frame (front opening)
	var arch_mat := stone_dark
	# Arch top
	_box(self, Vector3(0.50, 0.05, 0.05), Vector3(0, fh * 0.55, fd * 0.5 + 0.02), arch_mat)
	# Arch sides (thicker, 2 layers)
	for ax in [-0.26, 0.26]:
		_box(self, Vector3(0.07, 0.34, 0.05), Vector3(ax, fh * 0.42, fd * 0.5 + 0.02), arch_mat)
		_box(self, Vector3(0.04, 0.20, 0.03), Vector3(ax - 0.055 if ax < 0 else ax + 0.055, fh * 0.30, fd * 0.5 + 0.02), arch_mat)
	# Fireplace sill
	_box(self, Vector3(0.44, 0.05, 0.06), Vector3(0, fh * 0.24, fd * 0.5 + 0.02), brick_dark)

	# ---- IRON FIRE GRATE (front of opening) ----
	var fire_z := fd * 0.5 + 0.035
	# vertical grate bars
	for gx in [-0.15, -0.05, 0.05, 0.15]:
		_box(self, Vector3(0.02, 0.14, 0.015), Vector3(gx, fh * 0.33, fire_z), metal_dark)
	# horizontal grate bars
	for gy in [fh * 0.27, fh * 0.39]:
		_box(self, Vector3(0.32, 0.015, 0.015), Vector3(0, gy, fire_z), metal_dark)

	# Fire inside opening (layered glow)
	_box(self, Vector3(0.38, 0.18, 0.05), Vector3(0, fh * 0.40, fire_z + 0.02), fire_glow)
	_box(self, Vector3(0.26, 0.10, 0.04), Vector3(0, fh * 0.45, fire_z + 0.03), fire_hot)
	_box(self, Vector3(0.12, 0.04, 0.04), Vector3(0, fh * 0.50, fire_z + 0.03), fire_core)
	# Logs beneath fire
	for lg in [-0.10, 0.10]:
		_box(self, Vector3(0.18, 0.03, 0.05), Vector3(lg, fh * 0.26, fire_z + 0.02), wood_dark)
	# Embers spilling onto sill
	_box(self, Vector3(0.06, 0.02, 0.05), Vector3(0.14, fh * 0.255, fd * 0.5 + 0.035), ember)
	_box(self, Vector3(0.04, 0.015, 0.04), Vector3(-0.16, fh * 0.255, fd * 0.5 + 0.03), coal)

	# ---- CHIMNEY (taller, stacked stone) ----
	var chimney_x := 0.0
	var chimney_z := -fd * 0.5 + 0.10
	_box(self, Vector3(0.26, 0.18, 0.26), Vector3(chimney_x, fh + 0.09, chimney_z), stone_dark)
	_box(self, Vector3(0.22, 0.20, 0.22), Vector3(chimney_x, fh + 0.28, chimney_z), stone)
	_box(self, Vector3(0.20, 0.07, 0.20), Vector3(chimney_x, fh + 0.41, chimney_z), stone_dark)
	_box(self, Vector3(0.28, 0.05, 0.28), Vector3(chimney_x, fh + 0.47, chimney_z), brick_dark)
	# Chimney flue cap
	_box(self, Vector3(0.12, 0.05, 0.12), Vector3(chimney_x, fh + 0.55, chimney_z), soot)
	# Smoke vent hint (dark top hole)
	_box(self, Vector3(0.10, 0.02, 0.10), Vector3(chimney_x, fh + 0.495, chimney_z), soot)

	# ---- ANVIL (right side, more detail) ----
	var ax := fw * 0.5 + 0.08
	var az := 0.10
	_box(self, Vector3(0.14, 0.08, 0.10), Vector3(ax, 0.12, az), anvil_mat)
	_box(self, Vector3(0.10, 0.06, 0.08), Vector3(ax, 0.19, az), anvil_mat)
	_box(self, Vector3(0.12, 0.02, 0.08), Vector3(ax, 0.09, az), metal)
	# anvil horn
	_box(self, Vector3(0.06, 0.03, 0.05), Vector3(ax - 0.08, 0.17, az), anvil_mat)
	# anvil base steps
	_box(self, Vector3(0.16, 0.03, 0.12), Vector3(ax, 0.04, az), metal_bright)
	_box(self, Vector3(0.18, 0.02, 0.14), Vector3(ax, 0.02, az), metal_dark)

	# Heated ore on anvil (small glowing piece) + sparks
	_box(self, Vector3(0.04, 0.03, 0.04), Vector3(ax + 0.03, 0.23, az), fire_hot)
	_box(self, Vector3(0.02, 0.015, 0.02), Vector3(ax + 0.035, 0.255, az + 0.01), ember)
	# Tongs holding it
	_box(self, Vector3(0.02, 0.06, 0.01), Vector3(ax + 0.03, 0.20, az + 0.03), metal)
	_box(self, Vector3(0.02, 0.02, 0.01), Vector3(ax + 0.03, 0.23, az + 0.03), metal_dark)

	# Tool rack (above anvil, larger with nails)
	_box(self, Vector3(0.12, 0.02, 0.05), Vector3(ax, 0.32, az), wood)
	for nx in [-0.035, 0.035]:
		_box(self, Vector3(0.02, 0.02, 0.02), Vector3(ax + nx, 0.335, az), metal)
	# Hammer on rack
	_box(self, Vector3(0.01, 0.06, 0.01), Vector3(ax - 0.03, 0.36, az), _m(Color(0.35, 0.22, 0.08)))
	_box(self, Vector3(0.035, 0.025, 0.015), Vector3(ax - 0.03, 0.345, az), metal)
	# Tongs on rack
	_box(self, Vector3(0.01, 0.05, 0.01), Vector3(ax + 0.03, 0.355, az), metal)
	_box(self, Vector3(0.03, 0.015, 0.015), Vector3(ax + 0.03, 0.345, az), metal)

	# ---- ORE BUCKET (front-left, fuller) ----
	var bx := -fw * 0.5 + 0.15
	var bz := fd * 0.5 - 0.05
	_box(self, Vector3(0.14, 0.08, 0.12), Vector3(bx, 0.04, bz), metal_dark)
	# bucket rim
	_box(self, Vector3(0.15, 0.02, 0.13), Vector3(bx, 0.085, bz), metal)
	# bucket handle (arc)
	_box(self, Vector3(0.02, 0.02, 0.08), Vector3(bx, 0.12, bz - 0.04), metal)
	_box(self, Vector3(0.02, 0.02, 0.08), Vector3(bx, 0.12, bz + 0.04), metal)
	_box(self, Vector3(0.02, 0.035, 0.02), Vector3(bx, 0.135, bz), metal)
	# Ores inside bucket
	_box(self, Vector3(0.04, 0.02, 0.04), Vector3(bx - 0.03, 0.10, bz - 0.02), copper_ore)
	_box(self, Vector3(0.04, 0.02, 0.04), Vector3(bx + 0.03, 0.10, bz + 0.02), iron_ore)
	_box(self, Vector3(0.03, 0.02, 0.03), Vector3(bx, 0.11, bz - 0.03), gold_ore)
	_box(self, Vector3(0.03, 0.015, 0.03), Vector3(bx - 0.02, 0.115, bz + 0.01), copper_ore)
	_box(self, Vector3(0.03, 0.015, 0.03), Vector3(bx + 0.01, 0.11, bz - 0.01), iron_ore)

	# ---- COAL PILE (front-right) ----
	var coal_x := fw * 0.5 - 0.22
	var coal_z := fd * 0.5 - 0.10
	for cpe in [
		[0, 0, 0, Vector3(0.10, 0.035, 0.08)],
		[-0.06, 0.005, 0.03, Vector3(0.05, 0.03, 0.05)],
		[0.05, 0.006, -0.03, Vector3(0.05, 0.03, 0.05)],
		[0.01, 0.02, 0.01, Vector3(0.04, 0.03, 0.04)],
		[-0.02, 0.025, 0.02, Vector3(0.035, 0.025, 0.035)],
	]:
		_box(self, cpe[3], Vector3(coal_x + cpe[0], 0.10 + cpe[1], coal_z + cpe[2]), coal)
	# small wood log pile next to coal
	_box(self, Vector3(0.16, 0.02, 0.02), Vector3(coal_x + 0.12, 0.09, coal_z - 0.02), wood_dark)
	_box(self, Vector3(0.16, 0.02, 0.02), Vector3(coal_x + 0.12, 0.10, coal_z), wood_dark)
	_box(self, Vector3(0.16, 0.02, 0.02), Vector3(coal_x + 0.12, 0.11, coal_z + 0.02), wood_dark)

	# ---- STORAGE BOXES (around base, with lids) ----
	_box(self, Vector3(0.14, 0.06, 0.10), Vector3(-fw * 0.5 + 0.40, 0.03, -fd * 0.5 + 0.06), wood)
	_box(self, Vector3(0.10, 0.04, 0.08), Vector3(fw * 0.5 - 0.20, 0.02, -fd * 0.5 + 0.08), wood)
	# lid + iron strap on back-left box
	_box(self, Vector3(0.15, 0.02, 0.11), Vector3(-fw * 0.5 + 0.40, 0.07, -fd * 0.5 + 0.06), wood_dark)
	_box(self, Vector3(0.15, 0.02, 0.015), Vector3(-fw * 0.5 + 0.40, 0.05, -fd * 0.5 + 0.055), metal)
	_box(self, Vector3(0.15, 0.02, 0.015), Vector3(-fw * 0.5 + 0.40, 0.05, -fd * 0.5 + 0.065), metal)

	# ---- BACK SHELF (with brackets + more items) ----
	_box(self, Vector3(0.40, 0.02, 0.08), Vector3(-0.10, fh * 0.25, -fd * 0.5 - 0.02), wood)
	# shelf bracket
	_box(self, Vector3(0.02, 0.06, 0.02), Vector3(-0.28, fh * 0.22, -fd * 0.5 - 0.02), wood_dark)
	# Items on shelf
	_box(self, Vector3(0.03, 0.03, 0.03), Vector3(-0.20, fh * 0.28, -fd * 0.5 - 0.02), _m(Color(0.15, 0.40, 0.80)))
	_box(self, Vector3(0.02, 0.04, 0.02), Vector3(0, fh * 0.28, -fd * 0.5 - 0.02), _m(Color(0.70, 0.15, 0.15)))
	_box(self, Vector3(0.03, 0.025, 0.03), Vector3(0.14, fh * 0.27, -fd * 0.5 - 0.02), gold_ore)
	_box(self, Vector3(0.025, 0.02, 0.025), Vector3(-0.06, fh * 0.27, -fd * 0.5 - 0.02), iron_ore)

	# ---- BELLOWS (left side) ----
	var blx := -fw * 0.5 - 0.10
	var blz := -0.15
	_box(self, Vector3(0.10, 0.05, 0.14), Vector3(blx, 0.16, blz), wood_dark)
	_box(self, Vector3(0.08, 0.03, 0.11), Vector3(blx, 0.21, blz), wood)
	_box(self, Vector3(0.04, 0.04, 0.04), Vector3(blx, 0.11, blz + 0.06), metal)
	_box(self, Vector3(0.03, 0.10, 0.03), Vector3(blx, 0.10, blz - 0.06), metal)

	# ---- COLLISION ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.0, 0.7, 1.0)
	col.shape = box_col
	col.position = Vector3(0, 0.35, 0)
	add_child(col)

func _setup_area() -> void:
	var area := Area3D.new()
	area.name = "InteractArea"
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	col_shape.shape = sphere
	area.add_child(col_shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _setup_fire_vfx() -> void:
	# Fire particles
	_fire_particles = GPUParticles3D.new()
	_fire_particles.emitting = true
	_fire_particles.amount = 12
	_fire_particles.lifetime = 0.8
	_fire_particles.one_shot = false
	_fire_particles.explosiveness = 0.3
	_fire_particles.randomness = 0.5
	_fire_particles.position = Vector3(0, 0.35, 0.43)

	var fire_mat := ParticleProcessMaterial.new()
	fire_mat.direction = Vector3(0, 1, 0)
	fire_mat.spread = 30.0
	fire_mat.gravity = Vector3(0, -0.3, 0)
	fire_mat.initial_velocity_min = 0.1
	fire_mat.initial_velocity_max = 0.25
	fire_mat.scale_min = 0.02
	fire_mat.scale_max = 0.06
	var fire_grad := Gradient.new()
	fire_grad.set_color(0, Color(1.0, 0.7, 0.1, 0.9))
	fire_grad.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
	var fire_tex := GradientTexture1D.new()
	fire_tex.gradient = fire_grad
	fire_mat.color_ramp = fire_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	_fire_particles.draw_pass_1 = quad
	_fire_particles.process_material = fire_mat
	add_child(_fire_particles)

	# Smoke particles — khói ống khói (cầu 3D hiển thị đều mọi góc, phình to
	# theo thời gian sống để khói bay lên rõ ràng như đang cháy).
	_smoke_particles = GPUParticles3D.new()
	_smoke_particles.emitting = true
	_smoke_particles.amount = 18
	_smoke_particles.lifetime = 2.8
	_smoke_particles.one_shot = false
	_smoke_particles.explosiveness = 0.0
	_smoke_particles.randomness = 0.55
	_smoke_particles.position = Vector3(0, 1.32, -0.30)

	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, 1, 0)
	smoke_mat.spread = 14.0
	smoke_mat.gravity = Vector3(0, 0.6, 0)
	smoke_mat.initial_velocity_min = 0.30
	smoke_mat.initial_velocity_max = 0.65
	smoke_mat.scale_min = 0.7
	smoke_mat.scale_max = 1.3
	var smoke_grow := Curve.new()
	smoke_grow.add_point(Vector2(0, 1.0))
	smoke_grow.add_point(Vector2(1, 2.8))
	var smoke_curve_tex := CurveTexture.new()
	smoke_curve_tex.curve = smoke_grow
	smoke_mat.scale_curve = smoke_curve_tex
	var smoke_grad := Gradient.new()
	smoke_grad.set_color(0, Color(0.45, 0.45, 0.45, 0.50))
	smoke_grad.set_color(1, Color(0.30, 0.30, 0.30, 0.0))
	var smoke_tex := GradientTexture1D.new()
	smoke_tex.gradient = smoke_grad
	smoke_mat.color_ramp = smoke_tex

	var smoke_sph := SphereMesh.new()
	smoke_sph.radius = 0.5
	smoke_sph.height = 1.0
	smoke_sph.radial_segments = 10
	smoke_sph.rings = 6
	var smoke_sph_mat := StandardMaterial3D.new()
	smoke_sph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_sph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_sph_mat.vertex_color_use_as_albedo = true
	smoke_sph_mat.vertex_color_is_srgb = true
	smoke_sph_mat.albedo_color = Color.WHITE
	smoke_sph.material = smoke_sph_mat
	_smoke_particles.draw_pass_1 = smoke_sph
	_smoke_particles.process_material = smoke_mat
	add_child(_smoke_particles)

func _on_body_entered(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = true

func _on_body_exited(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = false
		close_ui()

func is_player_nearby() -> bool:
	return _player_nearby

func open_ui() -> void:
	if _is_open:
		return
	_is_open = true
	var hud := _find_hud()
	if hud:
		hud.open_furnace(self)

func close_ui() -> void:
	if not _is_open:
		return
	_is_open = false
	var hud := _find_hud()
	if hud:
		hud.close_furnace()

func _find_hud() -> HUD:
	var root := get_tree().current_scene if get_tree() else null
	if root == null:
		return null
	for child in root.get_children():
		if child is HUD:
			return child
	return null

## Bị phá huỷ: tắt lửa/khói + đóng UI (UI sẽ trả đồ còn trong lò về túi người chơi).
func _on_destroy() -> void:
	if _fire_particles:
		_fire_particles.emitting = false
	if _smoke_particles:
		_smoke_particles.emitting = false
	close_ui()
