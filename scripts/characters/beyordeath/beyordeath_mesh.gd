class_name BeyordeathMesh

var rig: Node3D
var head: Node3D
var torso: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var forearm_l: Node3D
var forearm_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var backpack: Node3D
var jet_root: Node3D

var _mat_white: StandardMaterial3D
var _mat_red: StandardMaterial3D
var _mat_blue: StandardMaterial3D
var _mat_dark: StandardMaterial3D
var _mat_glow: StandardMaterial3D
var _mat_visor: StandardMaterial3D
var _mat_metal: StandardMaterial3D

func build(root: CharacterBody3D) -> void:
	_make_materials()
	rig = MeshBuilder.pivot(root, Vector3(0, 0.10, 0))
	rig.name = "BeyordeathRig"
	_build_torso()
	_build_head()
	_build_shoulders()
	_build_arms()
	_build_legs()
	_build_wings()
	_build_jet_form()
	_jet_visible(false)

func _make_materials() -> void:
	var white := Color(0.92, 0.94, 0.96)
	var red   := Color(0.85, 0.08, 0.10)
	var blue  := Color(0.10, 0.35, 0.80)
	var dark  := Color(0.12, 0.14, 0.16)
	var metal := Color(0.28, 0.30, 0.34)
	_mat_white = MeshBuilder.emit_mat(white, Color(0, 0, 0), 0.0)
	_mat_red   = MeshBuilder.emit_mat(red,   Color(0.9, 0.1, 0.1), 0.5)
	_mat_blue  = MeshBuilder.emit_mat(blue,  Color(0.1, 0.3, 0.8), 0.5)
	_mat_dark  = MeshBuilder.emit_mat(dark,  Color(0, 0, 0), 0.0)
	_mat_metal = MeshBuilder.emit_mat(metal, Color(0, 0, 0), 0.0)
	_mat_glow  = MeshBuilder.emit_mat(Color(0.25, 1.0, 0.35), Color(0.3, 1.0, 0.45), 6.0)
	_mat_visor = MeshBuilder.emit_mat(Color(0.15, 0.60, 0.90, 0.7), Color(0.2, 0.7, 1.0), 3.0)

func _box(p: Node3D, pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	return MeshBuilder.box(p, pos, sz, mat)

func _sphere(p: Node3D, pos: Vector3, r: float, mat: StandardMaterial3D) -> MeshInstance3D:
	return MeshBuilder.sphere(p, pos, r, mat)

func _cyl(p: Node3D, pos: Vector3, r: float, h: float, mat: StandardMaterial3D) -> MeshInstance3D:
	return MeshBuilder.cylinder(p, pos, r, h, mat)

func _pivot(p: Node3D, pos: Vector3) -> Node3D:
	return MeshBuilder.pivot(p, pos)

func _build_torso() -> void:
	torso = _pivot(rig, Vector3(0, 0.50, 0))
	# Main chest block
	_box(torso, Vector3(0, 0.06, 0.02), Vector3(0.36, 0.28, 0.26), _mat_white)
	# Blue side panels
	_box(torso, Vector3(-0.20, 0.06, 0), Vector3(0.04, 0.20, 0.22), _mat_blue)
	_box(torso, Vector3(0.20, 0.06, 0), Vector3(0.04, 0.20, 0.22), _mat_blue)
	# Cockpit windshield
	_box(torso, Vector3(0, 0.14, 0.14), Vector3(0.14, 0.06, 0.06), _mat_visor)
	# Cockpit frame
	_box(torso, Vector3(0, 0.16, 0.13), Vector3(0.18, 0.02, 0.04), _mat_dark)
	# Nosecone
	_box(torso, Vector3(0, 0.16, 0.20), Vector3(0.06, 0.04, 0.10), _mat_red)
	# Center chest emblem
	_box(torso, Vector3(0, 0.06, 0.15), Vector3(0.08, 0.10, 0.04), _mat_red)
	# Waist
	_box(torso, Vector3(0, -0.10, 0.02), Vector3(0.30, 0.08, 0.20), _mat_white)
	_box(torso, Vector3(0, -0.08, 0.12), Vector3(0.16, 0.04, 0.06), _mat_blue)
	# Abdominal plates
	for i in range(3):
		_box(torso, Vector3(0, -0.02 - i * 0.04, 0.14), Vector3(0.12, 0.02, 0.04), _mat_dark)
	# Side intakes
	_box(torso, Vector3(-0.22, 0, -0.08), Vector3(0.06, 0.14, 0.12), _mat_dark)
	_box(torso, Vector3(0.22, 0, -0.08), Vector3(0.06, 0.14, 0.12), _mat_dark)
	# Intake glow
	_box(torso, Vector3(-0.22, 0, -0.14), Vector3(0.04, 0.08, 0.04), _mat_glow)
	_box(torso, Vector3(0.22, 0, -0.14), Vector3(0.04, 0.08, 0.04), _mat_glow)
	# Collar ring
	_box(torso, Vector3(0, 0.18, -0.02), Vector3(0.22, 0.04, 0.16), _mat_dark)

func _build_head() -> void:
	head = _pivot(rig, Vector3(0, 0.78, 0.04))
	# Helmet base
	_box(head, Vector3(0, 0, 0), Vector3(0.18, 0.16, 0.20), _mat_white)
	# Helmet crest swept back
	_box(head, Vector3(0, 0.10, -0.04), Vector3(0.06, 0.08, 0.08), _mat_red)
	_box(head, Vector3(0, 0.14, -0.06), Vector3(0.04, 0.04, 0.06), _mat_blue)
	# Visor
	_box(head, Vector3(0, 0.02, 0.10), Vector3(0.12, 0.06, 0.04), _mat_visor)
	# Visor frame
	_box(head, Vector3(0, 0.04, 0.09), Vector3(0.16, 0.02, 0.02), _mat_dark)
	# Jaw
	_box(head, Vector3(0, -0.05, 0.06), Vector3(0.10, 0.04, 0.08), _mat_dark)
	# Cheek plates
	_box(head, Vector3(-0.10, 0, 0.04), Vector3(0.04, 0.08, 0.08), _mat_blue)
	_box(head, Vector3(0.10, 0, 0.04), Vector3(0.04, 0.08, 0.08), _mat_blue)
	# Earpieces
	_box(head, Vector3(-0.12, 0.04, -0.04), Vector3(0.04, 0.06, 0.06), _mat_white)
	_box(head, Vector3(0.12, 0.04, -0.04), Vector3(0.04, 0.06, 0.06), _mat_white)
	# Neck
	_box(head, Vector3(0, -0.09, 0), Vector3(0.12, 0.04, 0.10), _mat_dark)

func _build_shoulders() -> void:
	shoulder_l = _pivot(torso, Vector3(-0.22, 0.14, 0))
	shoulder_r = _pivot(torso, Vector3(0.22, 0.14, 0))
	for side in [-1, 1]:
		var sh := shoulder_l if side < 0 else shoulder_r
		# Main pauldron
		_box(sh, Vector3(0, -0.02, 0), Vector3(0.12, 0.10, 0.14), _mat_white)
		# Top plate
		_box(sh, Vector3(0, 0.06, 0), Vector3(0.14, 0.04, 0.12), _mat_dark)
		# Red stripe
		_box(sh, Vector3(0, 0, 0.08), Vector3(0.08, 0.04, 0.04), _mat_red)
		# Outer blue edge
		_box(sh, Vector3(-0.08 * side, -0.02, 0.02), Vector3(0.04, 0.06, 0.08), _mat_blue)

func _build_arms() -> void:
	arm_l = _pivot(shoulder_l, Vector3(0, -0.08, 0))
	arm_r = _pivot(shoulder_r, Vector3(0, -0.08, 0))
	for side in [-1, 1]:
		var arm := arm_l if side < 0 else arm_r
		# Upper arm
		_box(arm, Vector3(0, -0.06, 0), Vector3(0.08, 0.12, 0.08), _mat_white)
		# Blue armour strip
		_box(arm, Vector3(0, -0.04, 0.06), Vector3(0.06, 0.06, 0.02), _mat_blue)
		# Elbow
		_box(arm, Vector3(0, -0.12, 0), Vector3(0.06, 0.04, 0.06), _mat_dark)
		# Forearm
		var forearm := _pivot(arm, Vector3(0, -0.14, 0))
		if side < 0: forearm_l = forearm
		else: forearm_r = forearm
		var f := forearm_l if side < 0 else forearm_r
		_box(f, Vector3(0, -0.04, 0), Vector3(0.07, 0.12, 0.07), _mat_white)
		# Red stripe
		_box(f, Vector3(0, -0.02, 0.06), Vector3(0.04, 0.06, 0.02), _mat_red)
		# Wrist
		_box(f, Vector3(0, -0.12, 0), Vector3(0.06, 0.04, 0.06), _mat_dark)
		# Hand / cannon
		var hand := _pivot(f, Vector3(0, -0.14, 0.04))
		if side < 0: hand_l = hand
		else: hand_r = hand
		var h := hand_l if side < 0 else hand_r
		# Cannon body
		_box(h, Vector3(0, -0.02, 0.02), Vector3(0.05, 0.05, 0.10), _mat_dark)
		# Barrel
		_cyl(h, Vector3(0, 0, 0.10), 0.025, 0.08, _mat_metal)
		# Muzzle
		_sphere(h, Vector3(0, 0, 0.14), 0.03, _mat_glow)

func _build_legs() -> void:
	thigh_l = _pivot(rig, Vector3(-0.12, 0.38, 0))
	thigh_r = _pivot(rig, Vector3(0.12, 0.38, 0))
	for side in [-1, 1]:
		var thigh := thigh_l if side < 0 else thigh_r
		# Upper thigh
		_box(thigh, Vector3(0, -0.02, 0), Vector3(0.14, 0.08, 0.10), _mat_white)
		# Side plate
		_box(thigh, Vector3(0, 0, 0.08), Vector3(0.08, 0.04, 0.04), _mat_blue)
		# Knee
		_box(thigh, Vector3(0, -0.08, 0), Vector3(0.08, 0.04, 0.08), _mat_dark)
		# Shin
		var shin := _pivot(thigh, Vector3(0, -0.10, 0))
		if side < 0: shin_l = shin
		else: shin_r = shin
		var s := shin_l if side < 0 else shin_r
		_box(s, Vector3(0, -0.06, 0), Vector3(0.10, 0.14, 0.08), _mat_white)
		# Shin front plate
		_box(s, Vector3(0, -0.04, 0.06), Vector3(0.06, 0.08, 0.02), _mat_red)
		# Rear thrusters
		_box(s, Vector3(0, -0.02, -0.06), Vector3(0.08, 0.08, 0.02), _mat_dark)
		_box(s, Vector3(0, -0.02, -0.08), Vector3(0.04, 0.04, 0.02), _mat_glow)
		# Ankle
		_box(s, Vector3(0, -0.12, 0), Vector3(0.07, 0.04, 0.07), _mat_dark)
		# Foot
		var foot := _pivot(s, Vector3(0, -0.14, 0.04))
		if side < 0: foot_l = foot
		else: foot_r = foot
		var f := foot_l if side < 0 else foot_r
		# Main foot
		_box(f, Vector3(0, -0.02, 0.02), Vector3(0.12, 0.04, 0.16), _mat_white)
		# Foot top
		_box(f, Vector3(0, 0, 0.04), Vector3(0.08, 0.02, 0.10), _mat_dark)
		# Foot accent
		_box(f, Vector3(0, 0, 0.10), Vector3(0.04, 0.02, 0.04), _mat_red)
		# Toe
		_box(f, Vector3(0, -0.02, 0.10), Vector3(0.04, 0.02, 0.04), _mat_blue)
		# Heel thruster
		_cyl(f, Vector3(0, -0.02, -0.06), 0.03, 0.03, _mat_dark)
		_sphere(f, Vector3(0, -0.03, -0.06), 0.02, _mat_glow)

func _build_wings() -> void:
	backpack = _pivot(torso, Vector3(0, 0.08, -0.14))
	# Wing mount base
	_box(backpack, Vector3(0, 0, 0), Vector3(0.22, 0.06, 0.08), _mat_dark)
	for side in [-1, 1]:
		var wp := _pivot(backpack, Vector3(side * 0.12, 0.02, 0))
		wp.rotation = Vector3(0, side * 0.35, side * -0.18)
		# Main wing
		_box(wp, Vector3(side * 0.25, 0, 0), Vector3(0.50, 0.02, 0.28), _mat_white)
		# Wing top plate
		_box(wp, Vector3(side * 0.25, 0.02, 0), Vector3(0.42, 0.02, 0.22), _mat_dark)
		# Wing red stripe
		_box(wp, Vector3(side * 0.25, 0.01, 0.12), Vector3(0.38, 0.02, 0.04), _mat_red)
		# Wing blue tip
		_box(wp, Vector3(side * 0.46, 0, 0), Vector3(0.10, 0.02, 0.18), _mat_blue)
		# Wing tip glow
		_sphere(wp, Vector3(side * 0.50, 0, 0), 0.025, _mat_glow)

func _build_jet_form() -> void:
	jet_root = _pivot(rig, Vector3(0, 0.45, -0.30))
	jet_root.name = "JetRoot"
	var fwd: float = -0.10
	# Fuselage
	var fuselage := BoxMesh.new()
	fuselage.size = Vector3(0.28, 0.18, 1.60)
	var fuselage_mi := MeshInstance3D.new()
	fuselage_mi.mesh = fuselage
	fuselage_mi.material_override = _mat_white
	fuselage_mi.position = Vector3(0, 0, fwd)
	jet_root.add_child(fuselage_mi)
	# Fuselage spine
	var spine := BoxMesh.new()
	spine.size = Vector3(0.08, 0.04, 1.40)
	var spine_mi := MeshInstance3D.new()
	spine_mi.mesh = spine
	spine_mi.material_override = _mat_blue
	spine_mi.position = Vector3(0, 0.10, fwd)
	jet_root.add_child(spine_mi)
	# Nose
	var nose := BoxMesh.new()
	nose.size = Vector3(0.10, 0.06, 0.35)
	var nose_mi := MeshInstance3D.new()
	nose_mi.mesh = nose
	nose_mi.material_override = _mat_white
	nose_mi.position = Vector3(0, 0.02, fwd - 0.90)
	jet_root.add_child(nose_mi)
	# Nose tip
	var nose_tip := BoxMesh.new()
	nose_tip.size = Vector3(0.04, 0.04, 0.12)
	var nt_mi := MeshInstance3D.new()
	nt_mi.mesh = nose_tip
	nt_mi.material_override = _mat_red
	nt_mi.position = Vector3(0, 0.02, fwd - 1.14)
	jet_root.add_child(nt_mi)
	# Cockpit
	var cockpit := SphereMesh.new()
	cockpit.radius = 0.06
	cockpit.height = 0.12
	cockpit.radial_segments = 12
	cockpit.rings = 8
	var cockpit_mi := MeshInstance3D.new()
	cockpit_mi.mesh = cockpit
	cockpit_mi.material_override = _mat_visor
	cockpit_mi.position = Vector3(0, 0.08, fwd - 0.50)
	cockpit_mi.scale = Vector3(1, 0.5, 1.2)
	jet_root.add_child(cockpit_mi)
	# Canopy frame
	var cframe := BoxMesh.new()
	cframe.size = Vector3(0.14, 0.02, 0.18)
	var cf_mi := MeshInstance3D.new()
	cf_mi.mesh = cframe
	cf_mi.material_override = _mat_dark
	cf_mi.position = Vector3(0, 0.12, fwd - 0.50)
	jet_root.add_child(cf_mi)
	# Wings
	for side in [-1, 1]:
		# Wing root
		var wr := BoxMesh.new()
		wr.size = Vector3(0.60, 0.02, 0.40)
		var wr_mi := MeshInstance3D.new()
		wr_mi.mesh = wr
		wr_mi.material_override = _mat_white
		wr_mi.position = Vector3(side * 0.38, -0.02, fwd - 0.20)
		wr_mi.rotation = Vector3(0, 0, side * 0.25)
		jet_root.add_child(wr_mi)
		# Wing top
		var wt := BoxMesh.new()
		wt.size = Vector3(0.52, 0.02, 0.32)
		var wt_mi := MeshInstance3D.new()
		wt_mi.mesh = wt
		wt_mi.material_override = _mat_dark
		wt_mi.position = Vector3(side * 0.38, 0, fwd - 0.20)
		wt_mi.rotation = Vector3(0, 0, side * 0.25)
		jet_root.add_child(wt_mi)
		# Wing stripe
		var wrs := BoxMesh.new()
		wrs.size = Vector3(0.48, 0.02, 0.04)
		var wrs_mi := MeshInstance3D.new()
		wrs_mi.mesh = wrs
		wrs_mi.material_override = _mat_red
		wrs_mi.position = Vector3(side * 0.38, 0.01, fwd - 0.08)
		wrs_mi.rotation = Vector3(0, 0, side * 0.25)
		jet_root.add_child(wrs_mi)
		# Wing tip
		var wtip := SphereMesh.new()
		wtip.radius = 0.015
		wtip.height = 0.03
		var wt_mi2 := MeshInstance3D.new()
		wt_mi2.mesh = wtip
		wt_mi2.material_override = _mat_glow
		wt_mi2.position = Vector3(side * 0.70, -0.02, fwd - 0.20)
		wt_mi2.rotation = Vector3(0, 0, side * 0.25)
		jet_root.add_child(wt_mi2)
		# Flaperon
		var flap := BoxMesh.new()
		flap.size = Vector3(0.16, 0.02, 0.12)
		var flap_mi := MeshInstance3D.new()
		flap_mi.mesh = flap
		flap_mi.material_override = _mat_blue
		flap_mi.position = Vector3(side * 0.38, -0.04, fwd + 0.16)
		flap_mi.rotation = Vector3(0.10, 0, side * 0.25)
		jet_root.add_child(flap_mi)
		# Vertical stabilizer
		var vstab := BoxMesh.new()
		vstab.size = Vector3(0.02, 0.22, 0.18)
		var vs_mi := MeshInstance3D.new()
		vs_mi.mesh = vstab
		vs_mi.material_override = _mat_white
		vs_mi.position = Vector3(side * 0.08, 0.14, fwd + 0.60)
		vs_mi.rotation = Vector3(0, 0, 0.06 * side)
		jet_root.add_child(vs_mi)
		# Stabilizer tip
		var vstip := BoxMesh.new()
		vstip.size = Vector3(0.02, 0.04, 0.14)
		var vsa_mi := MeshInstance3D.new()
		vsa_mi.mesh = vstip
		vsa_mi.material_override = _mat_red
		vsa_mi.position = Vector3(side * 0.08, 0.24, fwd + 0.60)
		vsa_mi.rotation = Vector3(0, 0, 0.06 * side)
		jet_root.add_child(vsa_mi)
		# Stabilizer glow
		var vsglow := SphereMesh.new()
		vsglow.radius = 0.012
		vsglow.height = 0.024
		var vsg_mi := MeshInstance3D.new()
		vsg_mi.mesh = vsglow
		vsg_mi.material_override = _mat_glow
		vsg_mi.position = Vector3(side * 0.08, 0.26, fwd + 0.60)
		vsg_mi.rotation = Vector3(0, 0, 0.06 * side)
		jet_root.add_child(vsg_mi)
		# Engine
		var eng := CylinderMesh.new()
		eng.top_radius = 0.04
		eng.bottom_radius = 0.06
		eng.height = 0.18
		eng.radial_segments = 10
		var eng_mi := MeshInstance3D.new()
		eng_mi.mesh = eng
		eng_mi.material_override = _mat_dark
		eng_mi.position = Vector3(side * 0.10, -0.04, fwd + 0.76)
		jet_root.add_child(eng_mi)
		# Intake
		var intake := CylinderMesh.new()
		intake.top_radius = 0.05
		intake.bottom_radius = 0.04
		intake.height = 0.03
		var int_mi := MeshInstance3D.new()
		int_mi.mesh = intake
		int_mi.material_override = _mat_metal
		int_mi.position = Vector3(side * 0.10, -0.04, fwd + 0.68)
		jet_root.add_child(int_mi)
		# Exhaust
		var exh := CylinderMesh.new()
		exh.top_radius = 0.035
		exh.bottom_radius = 0.05
		exh.height = 0.03
		var exh_mi := MeshInstance3D.new()
		exh_mi.mesh = exh
		exh_mi.material_override = _mat_glow
		exh_mi.position = Vector3(side * 0.10, -0.04, fwd + 0.86)
		jet_root.add_child(exh_mi)
		# Flame
		var flame := OmniLight3D.new()
		flame.light_color = Color(0.3, 1.0, 0.5)
		flame.light_energy = 2.0
		flame.omni_range = 2.0
		flame.position = Vector3(side * 0.10, -0.04, fwd + 0.92)
		jet_root.add_child(flame)
	# Belly cannon
	var belly := BoxMesh.new()
	belly.size = Vector3(0.04, 0.04, 0.30)
	var belly_mi := MeshInstance3D.new()
	belly_mi.mesh = belly
	belly_mi.material_override = _mat_dark
	belly_mi.position = Vector3(0, -0.10, fwd - 0.20)
	jet_root.add_child(belly_mi)
	# Belly muzzle
	var mz := BoxMesh.new()
	mz.size = Vector3(0.06, 0.03, 0.04)
	var mz_mi := MeshInstance3D.new()
	mz_mi.mesh = mz
	mz_mi.material_override = _mat_glow
	mz_mi.position = Vector3(0, -0.12, fwd - 0.34)
	jet_root.add_child(mz_mi)
	# Rear
	var rear := BoxMesh.new()
	rear.size = Vector3(0.16, 0.08, 0.24)
	var rear_mi := MeshInstance3D.new()
	rear_mi.mesh = rear
	rear_mi.material_override = _mat_white
	rear_mi.position = Vector3(0, 0, fwd + 0.76)
	jet_root.add_child(rear_mi)
	# Tail
	var tail := BoxMesh.new()
	tail.size = Vector3(0.08, 0.06, 0.10)
	var tail_mi := MeshInstance3D.new()
	tail_mi.mesh = tail
	tail_mi.material_override = _mat_red
	tail_mi.position = Vector3(0, 0, fwd + 0.94)
	jet_root.add_child(tail_mi)

func _jet_visible(v: bool) -> void:
	if jet_root:
		jet_root.visible = v

func set_jet_mode(enabled: bool) -> void:
	_jet_visible(enabled)
