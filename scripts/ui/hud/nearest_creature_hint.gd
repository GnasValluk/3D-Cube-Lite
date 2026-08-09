## ui/hud/nearest_creature_hint.gd
## Helper UI: hiển thị thông tin lượt ngắm hiện tại của người chơi. Ưu tiên 1:
## đang cầm công cụ khai thác (cuốc/cúp/cua/xẻng/rìu) nhìn vào block → hiện tên
## block + độ cứng + công cụ phù hợp. Ưu tiên 2: sinh vật/cây gần nhất. Panel
## nằm GÓC TRÁI TRÊN, có cờ bật/tắt riêng (tắt mặc định vì mang tính gợi ý).
## Quét chậm (throttle) để không tốn CPU mỗi frame.

extends CanvasLayer
class_name NearestCreatureHint

const MAX_RADIUS: float = 12.0
const PRUNE_PAD: float = 14.0
const UPDATE_INTERVAL: float = 0.2

const BG_PANEL := Color(0.10, 0.07, 0.18, 0.84)
const TEXT_MAIN := Color(0.95, 0.92, 1.0)
const TEXT_DIM := Color(0.62, 0.58, 0.80)
const COL_MOB := Color(0.95, 0.42, 0.36)
const COL_PLANT := Color(0.42, 0.72, 0.30)
const COL_BLOCK := Color(0.35, 0.72, 0.95)

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

## Callable trả về Node3D của người chơi (do HUD gán).
var player_getter: Callable

## Cờ bật/tắt panel — mặc định TẮT (ẩn), HUD có nút bật/tắt trong menu debug.
var hint_enabled: bool = false

var _timer: float = 0.0
var _panel: PanelContainer
var _name_lbl: Label
var _info_lbl: Label

const MINE_TOOL_IDS: Array[String] = ["hoe", "cuoc", "pickaxe", "shovel", "axe"]

func set_enabled(v: bool) -> void:
	hint_enabled = v
	if not v:
		_panel.visible = false

func _ready() -> void:
	_build_ui()
	set_process(true)

func _build_ui() -> void:
	var ps := StyleBoxFlat.new()
	ps.bg_color = BG_PANEL
	ps.set_corner_radius_all(8)
	ps.set_content_margin_all(10)
	ps.border_color = Color(1, 1, 1, 0.08)
	ps.set_border_width_all(1)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var vbox := VBoxContainer.new()
	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 20)
	_name_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	_name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_name_lbl)
	_info_lbl = Label.new()
	_info_lbl.add_theme_font_size_override("font_size", 15)
	_info_lbl.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(_info_lbl)
	_panel.add_child(vbox)
	add_child(_panel)

func _process(delta: float) -> void:
	if not hint_enabled:
		_panel.visible = false
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	_update_hint()

func _update_hint() -> void:
	if player_getter.is_null() or not player_getter.is_valid():
		_panel.visible = false
		return
	var player: Variant = player_getter.call()
	if player == null or not (player is Node) \
			or not is_instance_valid(player) or not player.is_inside_tree():
		_panel.visible = false
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		_panel.visible = false
		return
	var p: Vector3 = player.global_position
	# Ưu tiên 1: đang cầm công cụ khai thác + ngắm vào block → info block target
	var binfo := _block_target_info(player)
	if not binfo.is_empty():
		_panel.visible = true
		_name_lbl.text = binfo["label"]
		_name_lbl.add_theme_color_override("font_color", COL_BLOCK)
		_info_lbl.text = binfo["info"]
		_move_to_top_left()
		return
	var best := _scan(tree.current_scene, p, player)
	if best.is_empty():
		_panel.visible = false
		return
	_panel.visible = true
	_name_lbl.text = best["label"]
	_name_lbl.add_theme_color_override("font_color", best["color"])
	_info_lbl.text = best["info"]
	_move_to_top_left()

## Đặt panel ở GÓC TRÁI TRÊN màn hình (không theo tâm ngắm nữa).
func _move_to_top_left() -> void:
	_panel.size = Vector2.ZERO
	_panel.position = Vector2(12, 12)

## Info block đang ngắm khi cầm công cụ khai thác. Trả {} nếu không có.
func _block_target_info(player: Node) -> Dictionary:
	if not (player is PlayerCharacter):
		return {}
	var pc := player as PlayerCharacter
	var wep: ItemDef = pc.equipped_weapon
	if wep == null or wep.id not in MINE_TOOL_IDS:
		return {}
	if not pc._has_target:
		return {}
	var owm := pc._open_world_manager()
	if owm == null or not owm.has_method("get_block"):
		return {}
	var bid: int = owm.get_block(pc._target_block.x, pc._target_block.y, pc._target_block.z)
	if bid == _Data.BlockID.AIR or _Data.is_water(bid):
		return {}
	var tool_hint: String
	if _Data.is_pickaxable(bid):
		tool_hint = tr("BLOCK_TARGET_TOOLSTONE")
	elif _Data.is_axable(bid):
		tool_hint = tr("BLOCK_TARGET_TOOLWOOD")
	elif _Data.is_shovelable(bid):
		tool_hint = tr("BLOCK_TARGET_TOOLSOIL")
	elif _Data.is_tillable(bid):
		tool_hint = tr("BLOCK_TARGET_TOOLTILL")
	else:
		tool_hint = ""
	var info := "X%d Y%d Z%d  |  %s" % [
		int(pc._target_block.x), int(pc._target_block.y), int(pc._target_block.z),
		tool_hint if tool_hint != "" else tr("BLOCK_TARGET_NO_TOOL")]
	return {
		"label": "%s · %s" % [tr("BLOCK_TARGET_LABEL"), _block_display_name(bid)],
		"color": COL_BLOCK,
		"info": info,
	}

func _block_display_name(bid: int) -> String:
	var item_id: String = _Data.BLOCK_TO_ITEM.get(bid, "")
	if item_id == "":
		return "Block #%d" % bid
	var def := ItemDatabase.items_db.get(item_id) as ItemDef
	if def:
		return def.name
	return item_id

func _scan(root: Node, p: Vector3, player: Node) -> Dictionary:
	var best: Dictionary = {}
	_scan_nodes(root, p, player, best)
	for n in get_tree().get_nodes_in_group("destroyable_props"):
		if n is GrowingProp and is_instance_valid(n) and n.is_inside_tree():
			_consider(_plant_info(n, n.global_position.distance_to(p)), \
				n.global_position.distance_to(p), best)
	return best

func _scan_nodes(node: Node, p: Vector3, player: Node, best: Dictionary, depth: int = 0) -> void:
	if depth > 96:
		return
	if node is CharacterBase and node != player \
			and is_instance_valid(node) and node.is_inside_tree():
		_consider(_mob_info(node, node.global_position.distance_to(p)), \
			node.global_position.distance_to(p), best)
	for ch in node.get_children():
		if ch is Node3D:
			if ch.global_position.distance_to(p) > MAX_RADIUS + PRUNE_PAD:
				continue
		_scan_nodes(ch, p, player, best, depth + 1)

func _consider(info: Dictionary, d: float, best: Dictionary) -> void:
	if d < best.get("d", MAX_RADIUS):
		best["d"] = d
		best["label"] = info["label"]
		best["info"] = info["info"]
		best["color"] = info["color"]

func _mob_info(mob: CharacterBase, d: float) -> Dictionary:
	var name := mob.character_name
	if name == "":
		name = mob.name
	var hp: String = ""
	if mob.max_hp > 0:
		hp = "  |  %s %d/%d" % [tr("CREATURE_HP"), mob.hp, mob.max_hp]
	return {
		"label": "%s · %s" % [tr("CREATURE_TYPE_MOB"), name],
		"color": COL_MOB,
		"info": "%s %.1fm%s" % [tr("CREATURE_NEARBY"), d, hp],
	}

func _plant_info(n: Variant, d: float) -> Dictionary:
	var gp := n as GrowingProp
	var stage: String = _stage_name(gp)
	if stage != "":
		stage = "  |  " + stage
	return {
		"label": "%s · %s" % [tr("CREATURE_TYPE_PLANT"), _plant_name(n)],
		"color": COL_PLANT,
		"info": "%s %.1fm%s" % [tr("CREATURE_NEARBY"), d, stage],
	}

func _plant_name(n: Variant) -> String:
	if n is OakProp: return tr("PLANT_OAK")
	if n is DenseTreeProp: return tr("PLANT_DENSE")
	if n is OrangeTreeProp: return tr("PLANT_ORANGE")
	if n is PalmProp: return tr("PLANT_PALM")
	if n is WatermelonVineProp: return tr("PLANT_WATERMELON")
	if n is PumpkinVineProp: return tr("PLANT_PUMPKIN")
	if n is EggplantProp: return tr("PLANT_EGGPLANT")
	return n.name

func _stage_name(gp: Variant) -> String:
	if gp == null:
		return ""
	var s: int = gp._stage if "_stage" in gp else GrowingProp.Stage.SPROUT
	match s:
		GrowingProp.Stage.SPROUT: return tr("CREATURE_STAGE_SPROUT")
		GrowingProp.Stage.YOUNG: return tr("CREATURE_STAGE_YOUNG")
		GrowingProp.Stage.MATURE: return tr("CREATURE_STAGE_MATURE")
		GrowingProp.Stage.RIPE: return tr("CREATURE_STAGE_RIPE")
	return ""