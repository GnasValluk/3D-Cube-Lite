class_name Furnace
extends StaticBody3D

var _player_nearby: bool = false
var _is_open: bool = false
var _fire_particles: GPUParticles3D
var _smoke_particles: GPUParticles3D

func _ready() -> void:
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
	var stone_dark := _m(Color(0.20, 0.18, 0.17), 0.1, 0.95)
	var brick := _m(Color(0.40, 0.22, 0.15), 0.0, 0.85)
	var metal := _m(Color(0.22, 0.22, 0.25), 0.4, 0.6)
	var metal_dark := _m(Color(0.15, 0.15, 0.18), 0.4, 0.7)
	var anvil_mat := _m(Color(0.28, 0.28, 0.32), 0.5, 0.5)
	var fire_glow := _m(Color(0.80, 0.30, 0.05), 0.0, 0.8)
	var fire_hot := _m(Color(0.95, 0.60, 0.10), 0.0, 0.7)
	var fire_core := _m(Color(1.0, 0.85, 0.30), 0.0, 0.6)
	var gold_ore := _m(Color(0.37, 0.33, 0.29))
	var iron_ore := _m(Color(0.36, 0.31, 0.26))
	var copper_ore := _m(Color(0.38, 0.29, 0.18))
	var wood := _m(Color(0.42, 0.26, 0.14), 0.05, 0.85)

	# ---- FURNACE BODY ----
	var fw := 1.60  # furnace width
	var fh := 0.65  # furnace height
	var fd := 0.80  # furnace depth
	var fy := fh * 0.5

	# Main body
	_box(self, Vector3(fw, fh, fd), Vector3(0, fy, 0), stone)

	# Brick trim at top
	_box(self, Vector3(fw + 0.04, 0.06, fd + 0.04), Vector3(0, fh, 0), brick)

	# Brick trim at base
	_box(self, Vector3(fw + 0.04, 0.06, fd + 0.04), Vector3(0, 0.03, 0), brick)

	# Stone arch frame (front opening)
	var arch_mat := stone_dark
	# Arch top
	_box(self, Vector3(0.50, 0.04, 0.04), Vector3(0, fh * 0.55, fd * 0.5 + 0.02), arch_mat)
	# Arch sides
	_box(self, Vector3(0.04, 0.32, 0.04), Vector3(-0.26, fh * 0.42, fd * 0.5 + 0.02), arch_mat)
	_box(self, Vector3(0.04, 0.32, 0.04), Vector3(0.26, fh * 0.42, fd * 0.5 + 0.02), arch_mat)

	# Fire inside opening
	var fire_z := fd * 0.5 + 0.03
	_box(self, Vector3(0.38, 0.18, 0.04), Vector3(0, fh * 0.40, fire_z), fire_glow)
	_box(self, Vector3(0.26, 0.10, 0.04), Vector3(0, fh * 0.45, fire_z), fire_hot)
	_box(self, Vector3(0.12, 0.04, 0.04), Vector3(0, fh * 0.50, fire_z), fire_core)

	# Chimney (top-back)
	var chimney_x := 0.0
	var chimney_z := -fd * 0.5 + 0.10
	_box(self, Vector3(0.24, 0.18, 0.24), Vector3(chimney_x, fh + 0.09, chimney_z), stone_dark)
	_box(self, Vector3(0.20, 0.06, 0.20), Vector3(chimney_x, fh + 0.21, chimney_z), stone_dark)

	# ---- ANVIL (right side) ----
	var ax := fw * 0.5 + 0.08
	var az := 0.10
	_box(self, Vector3(0.14, 0.08, 0.10), Vector3(ax, 0.12, az), anvil_mat)
	_box(self, Vector3(0.10, 0.06, 0.08), Vector3(ax, 0.19, az), anvil_mat)
	_box(self, Vector3(0.12, 0.02, 0.08), Vector3(ax, 0.09, az), metal)

	# Heated ore on anvil (small glowing piece)
	_box(self, Vector3(0.04, 0.03, 0.04), Vector3(ax + 0.03, 0.23, az), fire_hot)
	# Tongs holding it
	_box(self, Vector3(0.02, 0.06, 0.01), Vector3(ax + 0.03, 0.20, az + 0.03), metal)

	# Tool rack (above anvil)
	_box(self, Vector3(0.10, 0.02, 0.04), Vector3(ax, 0.32, az), wood)
	# Hammer on rack
	_box(self, Vector3(0.01, 0.06, 0.01), Vector3(ax - 0.03, 0.36, az), _m(Color(0.35, 0.22, 0.08)))
	_box(self, Vector3(0.03, 0.02, 0.01), Vector3(ax - 0.03, 0.34, az), metal)
	# Tongs on rack
	_box(self, Vector3(0.01, 0.05, 0.01), Vector3(ax + 0.03, 0.355, az), metal)

	# ---- ORE BUCKET (front-left) ----
	var bx := -fw * 0.5 + 0.15
	var bz := fd * 0.5 - 0.05
	_box(self, Vector3(0.14, 0.08, 0.12), Vector3(bx, 0.04, bz), metal_dark)
	# Ores inside bucket
	_box(self, Vector3(0.04, 0.02, 0.04), Vector3(bx - 0.03, 0.09, bz - 0.02), copper_ore)
	_box(self, Vector3(0.04, 0.02, 0.04), Vector3(bx + 0.03, 0.09, bz + 0.02), iron_ore)
	_box(self, Vector3(0.03, 0.02, 0.03), Vector3(bx, 0.10, bz - 0.03), gold_ore)

	# ---- STORAGE BOXES (around base) ----
	_box(self, Vector3(0.14, 0.06, 0.10), Vector3(-fw * 0.5 + 0.40, 0.03, -fd * 0.5 + 0.06), wood)
	_box(self, Vector3(0.10, 0.04, 0.08), Vector3(fw * 0.5 - 0.20, 0.02, -fd * 0.5 + 0.08), wood)

	# ---- BACK SHELF ----
	_box(self, Vector3(0.40, 0.02, 0.08), Vector3(-0.10, fh * 0.25, -fd * 0.5 - 0.02), wood)
	# Items on shelf
	_box(self, Vector3(0.03, 0.03, 0.03), Vector3(-0.20, fh * 0.28, -fd * 0.5 - 0.02), _m(Color(0.15, 0.40, 0.80)))
	_box(self, Vector3(0.02, 0.04, 0.02), Vector3(0, fh * 0.28, -fd * 0.5 - 0.02), _m(Color(0.70, 0.15, 0.15)))

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

	# Smoke particles
	_smoke_particles = GPUParticles3D.new()
	_smoke_particles.emitting = true
	_smoke_particles.amount = 8
	_smoke_particles.lifetime = 2.0
	_smoke_particles.one_shot = false
	_smoke_particles.explosiveness = 0.0
	_smoke_particles.randomness = 0.6
	_smoke_particles.position = Vector3(0, 0.90, -0.30)

	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, 1, 0)
	smoke_mat.spread = 20.0
	smoke_mat.gravity = Vector3(0, -0.1, 0)
	smoke_mat.initial_velocity_min = 0.05
	smoke_mat.initial_velocity_max = 0.15
	smoke_mat.scale_min = 0.03
	smoke_mat.scale_max = 0.08
	var smoke_grad := Gradient.new()
	smoke_grad.set_color(0, Color(0.4, 0.4, 0.4, 0.4))
	smoke_grad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	var smoke_tex := GradientTexture1D.new()
	smoke_tex.gradient = smoke_grad
	smoke_mat.color_ramp = smoke_tex

	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.08, 0.08)
	_smoke_particles.draw_pass_1 = smoke_quad
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
