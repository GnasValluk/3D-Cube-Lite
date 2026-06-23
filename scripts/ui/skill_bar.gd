## ui/skill_bar.gd
## Thanh kỹ năng 4 slot (LMB / Q / R / SPACE) hiển thị cooldown + hotkey.

extends Control
class_name SkillBar

var _slots: Array[Dictionary] = []
var _tracked: CharacterBase = null
var _skills: Array[Dictionary] = []

var _element_color: Color = Color(0.3, 0.3, 0.5)

var slot_size := Vector2(56, 56)
var gap := 8.0

func _ready() -> void:
	_setup_slots()

func _setup_slots() -> void:
	var total_w := slot_size.x * 4 + gap * 3
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 20
	offset_top = -(slot_size.y + 20)
	offset_right = 20 + total_w
	offset_bottom = -20

	for i in range(4):
		var panel := Panel.new()
		panel.size = slot_size
		panel.position = Vector2(i * (slot_size.x + gap), 0)
		panel.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(panel)

		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.06, 0.06, 0.10, 0.85)
		bg.corner_radius_top_left = 6
		bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6
		bg.corner_radius_bottom_right = 6
		bg.border_width_left = 1
		bg.border_width_right = 1
		bg.border_width_top = 1
		bg.border_width_bottom = 1
		bg.border_color = Color(0.3, 0.3, 0.4, 0.5)
		panel.add_theme_stylebox_override("panel", bg)

		var icon := ColorRect.new()
		icon.size = Vector2(40, 28)
		icon.position = Vector2(8, 6)
		icon.color = Color(0.2, 0.2, 0.3)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(icon)

		var hotkey := Label.new()
		hotkey.position = Vector2(6, 36)
		hotkey.add_theme_font_size_override("font_size", 11)
		hotkey.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
		hotkey.add_theme_constant_override("shadow_offset_x", 1)
		hotkey.add_theme_constant_override("shadow_offset_y", 1)
		hotkey.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		hotkey.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(hotkey)

		var cd_overlay := ColorRect.new()
		cd_overlay.size = slot_size
		cd_overlay.position = Vector2.ZERO
		cd_overlay.color = Color(0, 0, 0, 0.55)
		cd_overlay.mouse_filter = MOUSE_FILTER_IGNORE
		cd_overlay.visible = false
		panel.add_child(cd_overlay)

		var cd_label := Label.new()
		cd_label.position = Vector2(0, 14)
		cd_label.size = slot_size
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.add_theme_font_size_override("font_size", 22)
		cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		cd_label.add_theme_constant_override("shadow_offset_x", 1)
		cd_label.add_theme_constant_override("shadow_offset_y", 1)
		cd_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		cd_label.mouse_filter = MOUSE_FILTER_IGNORE
		cd_label.visible = false
		panel.add_child(cd_label)

		var sd: Dictionary = {}
		sd["panel"] = panel
		sd["icon"] = icon
		sd["hotkey"] = hotkey
		sd["cd_overlay"] = cd_overlay
		sd["cd_label"] = cd_label
		sd["cd_var"] = ""
		sd["max_cd_var"] = ""
		sd["bg"] = bg
		_slots.append(sd)

func _process(_delta: float) -> void:
	if _tracked == null or not is_instance_valid(_tracked):
		for sd in _slots:
			_slot_hide_cd(sd)
		return

	for sd in _slots:
		var overlay: ColorRect = sd["cd_overlay"]
		var label: Label = sd["cd_label"]
		var cd_var: String = sd["cd_var"]
		if cd_var == "":
			overlay.visible = false
			label.visible = false
			continue
		var cd: float = _tracked.get(cd_var)
		if cd > 0.0:
			overlay.visible = true
			label.visible = true
			label.text = str(ceili(cd))
		else:
			if overlay.visible:
				overlay.visible = false
				label.visible = false

func _slot_hide_cd(sd: Dictionary) -> void:
	var overlay: ColorRect = sd["cd_overlay"]
	var label: Label = sd["cd_label"]
	overlay.visible = false
	label.visible = false

func track(ch: CharacterBase) -> void:
	_tracked = ch
	if ch == null:
		return

	if "element" in ch:
		var elem: Variant = ch.get("element")
		if elem is int and (elem as int) > 0:
			var ec: Variant = CharacterBase.ELEMENT_COLORS.get(elem as int)
			if ec is Color:
				_element_color = ec as Color
	if _element_color == Color(0.0, 0.0, 0.0):
		_element_color = Color(0.3, 0.3, 0.5)

	var skills: Array[Dictionary] = [
		{ "idx": 0, "key": "LMB", "cd_var": "_lmb_cd", "max_cd_var": "lmb_cooldown" },
		{ "idx": 1, "key": "Q",   "cd_var": "_q_cd",   "max_cd_var": "q_cooldown" },
		{ "idx": 2, "key": "R",   "cd_var": "_r_cd",   "max_cd_var": "r_cooldown" },
	]

	if ch.has_method("is_flying"):
		skills.append({ "idx": 3, "key": "FLY", "cd_var": "_flight_cd", "max_cd_var": "flight_cooldown" })
	else:
		skills.append({ "idx": 3, "key": "SPACE", "cd_var": "", "max_cd_var": "" })

	for i in range(4):
		var slot: Dictionary = _slots[i]
		var icon: ColorRect = slot["icon"]
		var bright: float = 1.0 - float(i) * 0.15
		icon.color = Color(
			clampf(_element_color.r * bright, 0.0, 1.0),
			clampf(_element_color.g * bright, 0.0, 1.0),
			clampf(_element_color.b * bright, 0.0, 1.0))
		var bg: StyleBoxFlat = slot["bg"]
		if bg:
			bg.border_color = Color(_element_color.r, _element_color.g, _element_color.b, 0.7)

	for s in skills:
		var slot: Dictionary = _slots[s.idx]
		slot["hotkey"].text = s.key
		slot["cd_var"] = s.cd_var
		slot["max_cd_var"] = s.max_cd_var
