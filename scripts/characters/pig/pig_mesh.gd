class_name PigMesh

var rig: Node3D
var body_color: Color
var belly_color: Color
var dark_color: Color
var snout_color: Color
var pink_color: Color
var eye_color: Color
var is_sand: bool = false

# Animation pivots
var pivot_head: Node3D
var pivot_tail: Node3D
var pivot_ear_l: Node3D
var pivot_ear_r: Node3D
var pivot_leg_fl: Node3D
var pivot_leg_fr: Node3D
var pivot_leg_bl: Node3D
var pivot_leg_br: Node3D

func build(root: Node3D) -> void:
	rig = Node3D.new()
	rig.name = "PigRig"
	root.add_child(rig)
	if is_sand:
		body_color = Color(0.72, 0.60, 0.38)
		belly_color = Color(0.82, 0.72, 0.52)
		dark_color = Color(0.55, 0.42, 0.22)
		snout_color = Color(0.62, 0.50, 0.30)
		pink_color = Color(0.78, 0.68, 0.48)
		eye_color = Color(0.15, 0.10, 0.05)
	else:
		body_color = Color(0.88, 0.62, 0.58)
		belly_color = Color(0.95, 0.82, 0.74)
		dark_color = Color(0.62, 0.33, 0.28)
		snout_color = Color(0.78, 0.52, 0.47)
		pink_color = Color(0.92, 0.72, 0.67)
		eye_color = Color(0.08, 0.08, 0.10)
	_build_body()
	_build_neck()
	_build_head()
	_build_ears()
	_build_legs()
	_build_tail()
	var sc: float = 0.95
	rig.scale = Vector3(sc, sc, sc)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = size
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _build_body() -> void:
	var b := rig
	# Main torso
	_box(b, Vector3(0, 0.28, 0.05), Vector3(0.66, 0.40, 0.78), body_color)
	# Rump
	_box(b, Vector3(0, 0.32, -0.34), Vector3(0.54, 0.32, 0.22), body_color.lightened(0.04))
	# Shoulder hump
	_box(b, Vector3(0, 0.46, 0.22), Vector3(0.50, 0.14, 0.28), body_color.lightened(0.06))
	# Back slope
	_box(b, Vector3(0, 0.42, -0.06), Vector3(0.52, 0.12, 0.48), body_color.lightened(0.03))
	# Belly — sagging underside
	_box(b, Vector3(0, 0.12, 0.05), Vector3(0.58, 0.14, 0.68), belly_color)
	# Belly sag
	_box(b, Vector3(0, 0.06, 0.05), Vector3(0.44, 0.06, 0.54), belly_color)

func _build_neck() -> void:
	var b := rig
	# Neck — bridges body and head cleanly
	_box(b, Vector3(0, 0.42, 0.50), Vector3(0.28, 0.18, 0.18), body_color)
	_box(b, Vector3(0, 0.34, 0.48), Vector3(0.24, 0.10, 0.16), belly_color)

func _build_head() -> void:
	pivot_head = Node3D.new()
	pivot_head.name = "PivotHead"
	pivot_head.position = Vector3(0, 0.52, 0.65)
	rig.add_child(pivot_head)
	var h := pivot_head
	# Main skull — sits above body, never clips
	_box(h, Vector3(0, 0, 0), Vector3(0.34, 0.18, 0.20), body_color)
	# Cheeks
	_box(h, Vector3(0.14, -0.02, -0.01), Vector3(0.08, 0.14, 0.14), body_color.lightened(0.05))
	_box(h, Vector3(-0.14, -0.02, -0.01), Vector3(0.08, 0.14, 0.14), body_color.lightened(0.05))
	# Forehead dome
	_box(h, Vector3(0, 0.08, 0), Vector3(0.26, 0.06, 0.14), body_color.lightened(0.08))
	# Snout base
	_box(h, Vector3(0, -0.04, 0.14), Vector3(0.28, 0.16, 0.12), snout_color)
	# Snout disc
	_box(h, Vector3(0, -0.02, 0.20), Vector3(0.22, 0.12, 0.05), snout_color.lightened(0.10))
	# Nostrils
	_box(h, Vector3(0.05, -0.02, 0.22), Vector3(0.05, 0.03, 0.02), dark_color)
	_box(h, Vector3(-0.05, -0.02, 0.22), Vector3(0.05, 0.03, 0.02), dark_color)
	# Eyes
	_box(h, Vector3(0.11, 0.04, 0.06), Vector3(0.06, 0.05, 0.03), eye_color)
	_box(h, Vector3(-0.11, 0.04, 0.06), Vector3(0.06, 0.05, 0.03), eye_color)
	# Eye highlights
	_box(h, Vector3(0.12, 0.05, 0.07), Vector3(0.02, 0.02, 0.01), Color(0.95, 0.95, 0.95))
	_box(h, Vector3(-0.10, 0.05, 0.07), Vector3(0.02, 0.02, 0.01), Color(0.95, 0.95, 0.95))
	# Mouth line
	_box(h, Vector3(0, -0.10, 0.16), Vector3(0.12, 0.01, 0.02), dark_color)

func _build_ears() -> void:
	var h := pivot_head
	pivot_ear_l = Node3D.new()
	pivot_ear_l.name = "PivotEarL"
	pivot_ear_l.position = Vector3(-0.18, 0.05, 0.03)
	h.add_child(pivot_ear_l)
	_box(pivot_ear_l, Vector3.ZERO, Vector3(0.14, 0.04, 0.08), dark_color)
	_box(pivot_ear_l, Vector3(0, 0.005, 0.01), Vector3(0.08, 0.02, 0.05), pink_color)
	_box(pivot_ear_l, Vector3(0, -0.03, 0), Vector3(0.10, 0.03, 0.06), dark_color)
	pivot_ear_r = Node3D.new()
	pivot_ear_r.name = "PivotEarR"
	pivot_ear_r.position = Vector3(0.18, 0.05, 0.03)
	h.add_child(pivot_ear_r)
	_box(pivot_ear_r, Vector3.ZERO, Vector3(0.14, 0.04, 0.08), dark_color)
	_box(pivot_ear_r, Vector3(0, 0.005, 0.01), Vector3(0.08, 0.02, 0.05), pink_color)
	_box(pivot_ear_r, Vector3(0, -0.03, 0), Vector3(0.10, 0.03, 0.06), dark_color)

func _build_legs() -> void:
	var leg_color := dark_color
	var hoof_color := dark_color.lightened(0.20)
	for params in [
		[Vector3(0.24, 0.16, 0.30), "LegFL"],
		[Vector3(-0.24, 0.16, 0.30), "LegFR"],
		[Vector3(0.24, 0.16, -0.30), "LegBL"],
		[Vector3(-0.24, 0.16, -0.30), "LegBR"],
	]:
		var p := Node3D.new()
		p.name = params[1]
		p.position = params[0]
		rig.add_child(p)
		# Upper leg
		_box(p, Vector3(0, -0.04, 0), Vector3(0.10, 0.18, 0.10), leg_color)
		# Knee
		_box(p, Vector3(0, -0.13, 0.02), Vector3(0.12, 0.05, 0.12), leg_color.lightened(0.08))
		# Lower leg
		_box(p, Vector3(0, -0.18, 0), Vector3(0.09, 0.08, 0.09), leg_color)
		# Hoof
		_box(p, Vector3(0, -0.23, 0.01), Vector3(0.12, 0.03, 0.08), hoof_color)
		# Cloven hooves
		_box(p, Vector3(-0.03, -0.22, 0.02), Vector3(0.03, 0.02, 0.05), dark_color)
		_box(p, Vector3(0.03, -0.22, 0.02), Vector3(0.03, 0.02, 0.05), dark_color)
		match params[1]:
			"LegFL": pivot_leg_fl = p
			"LegFR": pivot_leg_fr = p
			"LegBL": pivot_leg_bl = p
			"LegBR": pivot_leg_br = p

func _build_tail() -> void:
	pivot_tail = Node3D.new()
	pivot_tail.name = "PivotTail"
	pivot_tail.position = Vector3(0, 0.40, -0.42)
	rig.add_child(pivot_tail)
	var tail_color := dark_color
	var segs := 5
	for i in range(segs):
		var seg := MeshInstance3D.new()
		seg.mesh = CylinderMesh.new()
		seg.mesh.top_radius = 0.022 - i * 0.003
		seg.mesh.bottom_radius = 0.022 - i * 0.003
		seg.mesh.height = 0.05
		seg.material_override = _mat(tail_color)
		seg.position = Vector3(0, i * 0.02, -i * 0.035)
		seg.rotation.x = -0.3 + i * 0.15
		seg.rotation.z = sin(i * 1.2) * 0.3
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		pivot_tail.add_child(seg)
	var tip := MeshInstance3D.new()
	tip.mesh = SphereMesh.new()
	tip.mesh.radius = 0.02
	tip.mesh.height = 0.035
	tip.material_override = _mat(tail_color)
	tip.position = Vector3(0, 0.10, -0.18)
	pivot_tail.add_child(tip)
