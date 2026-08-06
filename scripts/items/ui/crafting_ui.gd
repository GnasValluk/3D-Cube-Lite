class_name CraftingUI
extends Control

## Bàn chế tạo kiểu danh sách: trái = danh sách công thức (tên + icon nguyên liệu),
## phải = preview vật phẩm được chọn, nút Chế Tạo tiêu hao nguyên liệu thẳng từ túi.

const _RecipeDB = preload("res://scripts/items/core/recipe_database.gd")

const S: float = 1.6

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
const TEAL := Color(0.12, 0.52, 0.32)
const PINK := Color(0.88, 0.35, 0.32)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

const PAD: float = 16.0
const LIST_W: float = 402.0
const PREVIEW_W: float = 320.0
const PANEL_W: float = PAD * 4 + LIST_W + PREVIEW_W
const PANEL_H: float = 620.0
const CARD_W: float = 378.0
const CARD_H: float = 84.0

var _player_ref: PlayerCharacter = null
var _recipes: Array = []
var _cards: Array[Panel] = []
var _list_box: VBoxContainer
var _selected_idx: int = -1

var _card_style: StyleBoxFlat
var _card_hover_style: StyleBoxFlat
var _craft_style: StyleBoxFlat
var _craft_dis_style: StyleBoxFlat
var _icon_slot_style: StyleBoxFlat
var _tween: Tween

var _pv_icon_tex: TextureRect
var _pv_icon_face: ColorRect
var _pv_name: Label
var _pv_cat: Label
var _pv_mat_box: VBoxContainer
var _pv_mat_rows: Array = []
var _craft_btn: Button

func _ready() -> void:
	_recipe_styles()
	size = Vector2(PANEL_W, PANEL_H)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	position += Vector2(0, -10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_background()
	_setup_title()
	_setup_list()
	_setup_preview()
	visible = false

func _recipe_styles() -> void:
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = BG_CARD
	_card_style.corner_radius_top_left = 8
	_card_style.corner_radius_top_right = 8
	_card_style.corner_radius_bottom_left = 8
	_card_style.corner_radius_bottom_right = 8
	_card_style.border_width_left = 1
	_card_style.border_width_right = 1
	_card_style.border_width_top = 1
	_card_style.border_width_bottom = 1
	_card_style.border_color = Color(0.55, 0.57, 0.62, 0.15)

	_card_hover_style = _card_style.duplicate()
	_card_hover_style.bg_color = Color(0.18, 0.30, 0.22, 0.95)
	_card_hover_style.border_color = Color(0.22, 0.72, 0.38, 0.75)
	_card_hover_style.border_width_left = 2
	_card_hover_style.border_width_right = 2
	_card_hover_style.border_width_top = 2
	_card_hover_style.border_width_bottom = 2

	_craft_style = StyleBoxFlat.new()
	_craft_style.bg_color = Color(0.18, 0.55, 0.30)
	_craft_style.corner_radius_top_left = 8
	_craft_style.corner_radius_top_right = 8
	_craft_style.corner_radius_bottom_left = 8
	_craft_style.corner_radius_bottom_right = 8
	_craft_style.border_width_left = 2
	_craft_style.border_width_right = 2
	_craft_style.border_width_top = 2
	_craft_style.border_width_bottom = 2
	_craft_style.border_color = Color(0.30, 0.80, 0.45, 0.6)

	_craft_dis_style = _craft_style.duplicate()
	_craft_dis_style.bg_color = Color(0.12, 0.13, 0.16)
	_craft_dis_style.border_color = Color(0.30, 0.30, 0.32, 0.4)

	# Khung icon giống slot inventory: bo góc, viền mờ, clip nội dung để icon
	# 256px không bao giờ vượt khung.
	_icon_slot_style = StyleBoxFlat.new()
	_icon_slot_style.bg_color = Color(0.09, 0.07, 0.14, 0.9)
	_icon_slot_style.corner_radius_top_left = 6
	_icon_slot_style.corner_radius_top_right = 6
	_icon_slot_style.corner_radius_bottom_left = 6
	_icon_slot_style.corner_radius_bottom_right = 6
	_icon_slot_style.border_width_left = 1
	_icon_slot_style.border_width_right = 1
	_icon_slot_style.border_width_top = 1
	_icon_slot_style.border_width_bottom = 1
	_icon_slot_style.border_color = Color(0.85, 0.80, 0.95, 0.16)

func _setup_background() -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = BG_PANEL
	bg_style.corner_radius_top_left = 14
	bg_style.corner_radius_top_right = 14
	bg_style.corner_radius_bottom_left = 14
	bg_style.corner_radius_bottom_right = 14
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.85, 0.80, 0.95, 0.12)

	var bg := Panel.new()
	bg.size = Vector2(PANEL_W, PANEL_H)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

func _setup_title() -> void:
	var title := Label.new()
	title.text = tr("CRAFTING_LABEL")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(S * 15))
	title.add_theme_color_override("font_color", TEXT_BRIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.position = Vector2(0, 14)
	title.size = Vector2(PANEL_W, 28)
	add_child(title)

func _setup_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 52)
	scroll.size = Vector2(LIST_W, PANEL_H - 52 - PAD)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

func _setup_preview() -> void:
	var px: float = PAD * 2 + LIST_W
	var pv := Panel.new()
	pv.position = Vector2(px, 52)
	pv.size = Vector2(PREVIEW_W, PANEL_H - 52 - PAD)
	pv.add_theme_stylebox_override("panel", _card_style)
	add_child(pv)

	var icx: float = (PREVIEW_W - 110) / 2.0
	var box := Panel.new()
	box.position = Vector2(icx, 18)
	box.size = Vector2(110, 110)
	box.clip_contents = true
	box.add_theme_stylebox_override("panel", _icon_slot_style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(box)

	_pv_icon_face = ColorRect.new()
	_pv_icon_face.position = Vector2(1, 1)
	_pv_icon_face.size = Vector2(108, 108)
	_pv_icon_face.color = Color(0.20, 0.15, 0.30, 0.4)
	_pv_icon_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pv_icon_face)

	_pv_icon_tex = TextureRect.new()
	_pv_icon_tex.position = Vector2(1, 1)
	_pv_icon_tex.size = Vector2(108, 108)
	_pv_icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_pv_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pv_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pv_icon_tex)

	_pv_name = Label.new()
	_pv_name.position = Vector2(14, 134)
	_pv_name.size = Vector2(PREVIEW_W - 28, 26)
	_pv_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pv_name.add_theme_font_size_override("font_size", int(S * 15))
	_pv_name.add_theme_color_override("font_color", TEXT_BRIGHT)
	pv.add_child(_pv_name)

	_pv_cat = Label.new()
	_pv_cat.position = Vector2(14, 162)
	_pv_cat.size = Vector2(PREVIEW_W - 28, 20)
	_pv_cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pv_cat.add_theme_font_size_override("font_size", int(S * 9))
	_pv_cat.add_theme_color_override("font_color", TEXT_MUTED)
	pv.add_child(_pv_cat)

	var mat_lbl := Label.new()
	mat_lbl.text = tr("CRAFT_MATERIALS")
	mat_lbl.position = Vector2(16, 194)
	mat_lbl.add_theme_font_size_override("font_size", int(S * 12))
	mat_lbl.add_theme_color_override("font_color", TEXT_DIM)
	pv.add_child(mat_lbl)

	_pv_mat_box = VBoxContainer.new()
	_pv_mat_box.position = Vector2(16, 222)
	_pv_mat_box.size = Vector2(PREVIEW_W - 32, 260)
	_pv_mat_box.add_theme_constant_override("separation", 6)
	pv.add_child(_pv_mat_box)

	_craft_btn = Button.new()
	_craft_btn.text = tr("CRAFT_BUTTON")
	_craft_btn.position = Vector2(16, PANEL_H - 52 - PAD - 64)
	_craft_btn.size = Vector2(PREVIEW_W - 32, 48)
	_craft_btn.add_theme_font_size_override("font_size", int(S * 14))
	_craft_btn.add_theme_color_override("font_color", TEXT_BRIGHT)
	_craft_btn.add_theme_stylebox_override("normal", _craft_style)
	_craft_btn.add_theme_stylebox_override("hover", _craft_style)
	_craft_btn.add_theme_stylebox_override("pressed", _craft_style)
	_craft_btn.add_theme_stylebox_override("disabled", _craft_dis_style)
	_craft_btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	_craft_btn.pressed.connect(_craft)
	pv.add_child(_craft_btn)

## Thêm icon vật phẩm vào parent tại (px,py) kích thước sz; bọc trong khung slot
## clip_contents (giống inventory) để icon 256px không bao giờ vượt khung.
## count_str nếu khác "" thì hiện góc phải-dưới.
func _add_icon(parent: Control, px: float, py: float, sz: float, item_id: String, count_str: String = "") -> void:
	ItemDatabase.ensure_db()
	var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
	var tex := ItemDatabase.load_icon_2d(item_id)

	var slot := Panel.new()
	slot.position = Vector2(px, py)
	slot.size = Vector2(sz, sz)
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _icon_slot_style)
	parent.add_child(slot)

	var face := ColorRect.new()
	face.position = Vector2(1, 1)
	face.size = Vector2(sz - 2, sz - 2)
	face.color = Color(0.05, 0.04, 0.10, 0.55) if tex != null else (def.icon_color if def != null else Color(0.20, 0.15, 0.30, 0.5))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)

	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.position = Vector2(1, 1)
		t.size = Vector2(sz - 2, sz - 2)
		t.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(t)

	if count_str != "":
		var c := Label.new()
		c.text = count_str
		c.position = Vector2(1, sz - 18)
		c.size = Vector2(sz - 2, 16)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.add_theme_font_size_override("font_size", int(S * 9))
		c.add_theme_color_override("font_color", TEXT_BRIGHT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(c)

func _rebuild_list() -> void:
	for ch in _list_box.get_children():
		ch.queue_free()
	_cards.clear()

	var craftable: Array = []
	var locked: Array = []
	for r in _RecipeDB.recipes:
		(craftable if _can_craft(r) else locked).append(r)
	_recipes = craftable + locked

	for i in range(_recipes.size()):
		var card := Panel.new()
		card.custom_minimum_size = Vector2(CARD_W, CARD_H)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_theme_stylebox_override("panel", _card_style)
		card.gui_input.connect(_on_card_input.bind(i))
		_list_box.add_child(card)
		_cards.append(card)

		var r: Dictionary = _recipes[i]
		ItemDatabase.ensure_db()
		var rdef: ItemDef = ItemDatabase.items_db.get(r.get("result", "")) as ItemDef
		var rid: String = r.get("result", "")

		_add_icon(card, 10, 8, 46, rid, "")
		var name := Label.new()
		name.text = r.get("name", rid)
		name.position = Vector2(66, 14)
		name.size = Vector2(CARD_W - 66 - 64, 22)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.add_theme_font_size_override("font_size", int(S * 12))
		name.add_theme_color_override("font_color", TEXT_BRIGHT)
		card.add_child(name)

		var cnt := Label.new()
		cnt.text = "x%d" % r.get("count", 1)
		cnt.position = Vector2(CARD_W - 60, 17)
		cnt.size = Vector2(50, 18)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", int(S * 10))
		cnt.add_theme_color_override("font_color", Color(0.65, 0.85, 0.55))
		card.add_child(cnt)

		# Dòng nguyên liệu: icon + số lượng từng loại
		var ing: Dictionary = r.get("ingredients", {})
		var x: float = 12.0
		var y: float = 60.0
		var first := true
		for ing_id in ing:
			if not first:
				var plus := Label.new()
				plus.text = "+"
				plus.position = Vector2(x, y - 1)
				plus.add_theme_font_size_override("font_size", int(S * 9))
				plus.add_theme_color_override("font_color", TEXT_MUTED)
				card.add_child(plus)
				x += 14.0
			first = false
			_add_icon(card, x, y, 18, ing_id)
			var need := Label.new()
			need.text = "x%d" % int(ing[ing_id])
			need.position = Vector2(x + 20, y + 1)
			need.add_theme_font_size_override("font_size", int(S * 8))
			need.add_theme_color_override("font_color", TEXT_DIM)
			card.add_child(need)
			x += 20.0 + 16.0 * int(ing[ing_id]) + 26.0
			if x > CARD_W - 60:
				break

func _on_card_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if idx >= 0 and idx < _recipes.size() and _can_craft(_recipes[idx]):
			_select(idx)

func _select(idx: int) -> void:
	_selected_idx = idx
	for i in range(_cards.size()):
		_cards[i].add_theme_stylebox_override("panel", _card_hover_style if i == idx else _card_style)
	_render_preview()

func _clear_pv_mat() -> void:
	for ch in _pv_mat_box.get_children():
		ch.queue_free()
	_pv_mat_rows.clear()

func _render_preview() -> void:
	_clear_pv_mat()
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		_pv_icon_tex.texture = null
		_pv_icon_face.color = Color(0.20, 0.15, 0.30, 0.4)
		_pv_name.text = "—"
		_pv_cat.text = ""
		_craft_btn.disabled = true
		_craft_btn.text = tr("CRAFT_BUTTON")
		return
	ItemDatabase.ensure_db()
	var r: Dictionary = _recipes[_selected_idx]
	var rdef: ItemDef = ItemDatabase.items_db.get(r.get("result", "")) as ItemDef
	var rid: String = r.get("result", "")

	var tex := ItemDatabase.load_icon_2d(rid)
	_pv_icon_tex.texture = tex
	_pv_icon_face.color = Color(0.05, 0.04, 0.10, 0.55) if tex != null else (rdef.icon_color if rdef != null else Color(0.20, 0.15, 0.30, 0.5))
	_pv_name.text = r.get("name", rid)
	_pv_cat.text = r.get("category", "")
	_pv_cat.text = ("%s · x%d" % [_pv_cat.text, r.get("count", 1)]) if _pv_cat.text != "" else "x%d" % r.get("count", 1)

	var ing: Dictionary = r.get("ingredients", {})
	for ing_id in ing:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(PREVIEW_W - 32, 30)
		row.add_theme_constant_override("separation", 8)
		_pv_mat_box.add_child(row)

		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(26, 26)
		wrap.size = Vector2(26, 26)
		row.add_child(wrap)
		_add_icon(wrap, 0, 1, 24, ing_id)

		var def: ItemDef = ItemDatabase.items_db.get(ing_id) as ItemDef
		var nm := Label.new()
		nm.text = def.name if def != null else ing_id
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", int(S * 10))
		nm.add_theme_color_override("font_color", TEXT_BRIGHT)
		row.add_child(nm)

		var have := Label.new()
		have.text = "0"
		have.add_theme_font_size_override("font_size", int(S * 10))
		row.add_child(have)

		var sep := Label.new()
		sep.text = "/"
		sep.add_theme_font_size_override("font_size", int(S * 10))
		sep.add_theme_color_override("font_color", TEXT_MUTED)
		row.add_child(sep)

		var need := Label.new()
		need.text = "%d" % int(ing[ing_id])
		need.add_theme_font_size_override("font_size", int(S * 10))
		need.add_theme_color_override("font_color", Color(0.65, 0.85, 0.55))
		row.add_child(need)

		_pv_mat_rows.append({ "ing": ing_id, "need": int(ing[ing_id]), "have": have })

	_craft_btn.disabled = not _can_craft(r)
	_craft_btn.text = tr("CRAFT_CANNOT") if not _can_craft(r) else tr("CRAFT_BUTTON")

func _can_craft(recipe: Dictionary) -> bool:
	if _player_ref == null:
		return false
	var pi = _player_ref.inventory
	if pi == null:
		return false
	var ing: Dictionary = recipe.get("ingredients", {})
	for ing_id in ing:
		if pi.get_item_count(ing_id) < int(ing[ing_id]):
			return false
	return _has_space_for_result(recipe)

func _has_space_for_result(recipe: Dictionary) -> bool:
	var pi = _player_ref.inventory
	if pi == null:
		return false
	ItemDatabase.ensure_db()
	var def: ItemDef = ItemDatabase.items_db.get(recipe.get("result", "")) as ItemDef
	if def == null:
		return false
	if not pi.is_full():
		return true
	if def.stackable:
		for slot in pi.slots:
			if not slot.is_empty() and slot.item.id == def.id and slot.count < def.item.max_stack:
				return true
	return false

func _craft() -> void:
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return
	if _player_ref == null:
		return
	var recipe: Dictionary = _recipes[_selected_idx]
	if not _can_craft(recipe):
		return
	var pi = _player_ref.inventory
	var ing: Dictionary = recipe.get("ingredients", {})
	for ing_id in ing:
		pi.remove_item_by_id(ing_id, int(ing[ing_id]))
	ItemDatabase.ensure_db()
	var def: ItemDef = ItemDatabase.items_db.get(recipe.get("result", "")) as ItemDef
	if def == null:
		return
	var count: int = recipe.get("count", 1)
	pi.add_item(def, count)
	if _player_ref.has_method("_scroll_inventory_message"):
		_player_ref._scroll_inventory_message("+%d %s" % [count, def.name])
	if _player_ref.get("equipped_weapon") != null \
			and _player_ref.equipped_weapon.id == def.id:
		_player_ref._update_weapon_mesh()

func open(player: PlayerCharacter) -> void:
	_player_ref = player
	_RecipeDB.ensure()
	_selected_idx = -1
	_rebuild_list()
	_render_preview()
	_play_appear()

func close() -> void:
	_player_ref = null
	_play_disappear()

func _play_appear() -> void:
	visible = true
	scale = Vector2.ZERO
	modulate.a = 0.0
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.15)

func _play_disappear() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.10)
	_tween.tween_callback(func():
		visible = false
		scale = Vector2.ONE
		modulate.a = 1.0
	)

func _process(_delta: float) -> void:
	if not visible or _player_ref == null:
		return
	var pi = _player_ref.inventory
	if pi == null:
		return
	# Cập nhật trạng thái đủ/thiếu nguyên liệu cho từng card
	for i in range(_cards.size()):
		var ok: bool = _can_craft(_recipes[i])
		_cards[i].modulate = Color(1, 1, 1, 1) if ok else Color(1, 1, 1, 0.40)
	# Cập nhật preview: have/need + nút chế tạo
	if _selected_idx >= 0 and _selected_idx < _recipes.size():
		var r: Dictionary = _recipes[_selected_idx]
		for row in _pv_mat_rows:
			var have: int = pi.get_item_count(row.ing)
			row.have.text = "%d" % have
			row.have.add_theme_color_override("font_color", TEXT_BRIGHT if have >= row.need else PINK)
		var ok: bool = _can_craft(r)
		_craft_btn.disabled = not ok
		_craft_btn.text = tr("CRAFT_CANNOT") if not ok else tr("CRAFT_BUTTON")
