class_name ItemDef

enum Type { BLOCK, TOOL, WEAPON, FOOD, MATERIAL, ARMOR }
enum ArmorSlot { HEAD, BODY, LEGS, FEET, HANDS, BACK, SUB }

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
var armor_slot: int = ArmorSlot.BODY

func _init(p_id: String, p_name: String, p_type: int, p_color: Color, p_char: String,
		   p_desc: String = "", p_stackable: bool = true, p_max: int = 64,
		   p_heal: int = 0, p_atk: int = 0, p_def: int = 0, p_armor_slot: int = -1):
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
	if p_armor_slot >= 0:
		armor_slot = p_armor_slot

func get_type_name() -> String:
	match type:
		Type.BLOCK:    return tr("TYPE_BLOCK")
		Type.TOOL:     return tr("TYPE_TOOL")
		Type.WEAPON:   return tr("TYPE_WEAPON")
		Type.FOOD:     return tr("TYPE_FOOD")
		Type.MATERIAL: return tr("TYPE_MATERIAL")
		Type.ARMOR:    return tr("TYPE_ARMOR")
	return ""

func get_armor_slot_name() -> String:
	match armor_slot:
		ArmorSlot.HEAD: return tr("SLOT_HEAD")
		ArmorSlot.BODY: return tr("SLOT_BODY")
		ArmorSlot.LEGS: return tr("SLOT_LEGS")
		ArmorSlot.FEET: return tr("SLOT_FEET")
	return ""

func is_equippable() -> bool:
	return type == Type.WEAPON or type == Type.TOOL or type == Type.ARMOR
