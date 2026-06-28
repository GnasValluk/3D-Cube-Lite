class_name ItemDef

enum Type { BLOCK, TOOL, WEAPON, FOOD, MATERIAL, ARMOR }

var id: String
var name: String
var type: int
var stackable: bool
var max_stack: int
var icon_color: Color
var icon_char: String
var desc: String
var heal_amount: int
var atk_bonus: int
var def_bonus: int

func _init(p_id: String, p_name: String, p_type: int, p_color: Color, p_char: String,
		   p_desc: String = "", p_stackable: bool = true, p_max: int = 64,
		   p_heal: int = 0, p_atk: int = 0, p_def: int = 0):
	id = p_id
	name = p_name
	type = p_type
	icon_color = p_color
	icon_char = p_char
	desc = p_desc
	stackable = p_stackable
	max_stack = p_max
	heal_amount = p_heal
	atk_bonus = p_atk
	def_bonus = p_def

func get_type_name() -> String:
	match type:
		Type.BLOCK:    return "Khối"
		Type.TOOL:     return "Công cụ"
		Type.WEAPON:   return "Vũ khí"
		Type.FOOD:     return "Thức ăn"
		Type.MATERIAL: return "Nguyên liệu"
		Type.ARMOR:    return "Giáp"
	return ""

func is_equippable() -> bool:
	return type == Type.WEAPON or type == Type.TOOL or type == Type.ARMOR
