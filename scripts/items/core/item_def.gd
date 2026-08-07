class_name ItemDef

enum Type { BLOCK, TOOL, WEAPON, FOOD, MATERIAL, ARMOR }
enum ArmorSlot { HEAD, BODY, LEGS, FEET, BACK, SUB }

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
var def_bonus: float
var armor_slot: int = ArmorSlot.BODY
var max_durability: int = 0  # 0 = không có độ bền (vĩnh cửu); >0 = hao mòn khi dùng
## May mắn (chỉ số ẩn, không hiện UI) — tăng tỷ lệ câu được đồ hiếm.
var luck_bonus: float = 0.0
## Kháng sát thương chí mạng — giảm phần thưởng crit khi bị đánh.
var crit_resist_bonus: float = 0.0
## Số slot inventory cộng thêm khi trang bị (vd: ba lô da thú).
var inv_slots_bonus: int = 0
## Hệ số giới hạn tải khi trang bị (1.0 = không đổi; 1.05 = +5% weight).
var weight_multiplier: float = 1.0
## Thời gian ăn (giây) — giữ chuột phải đủ lâu mới ăn xong 1 lần
var eat_time: float = 3.0
## Trọng lượng (weight) quy ra đơn vị tải — cộng dồn theo kho đồ cho cơ chế quá tải
var weight: float = 0.0

func _init(p_id: String, p_name: String, p_type: int, p_color: Color, p_char: String,
		   p_desc: String = "", p_stackable: bool = true, p_max: int = 64,
		   p_heal: int = 0, p_atk: int = 0, p_def: float = 0.0, p_armor_slot: int = -1,
		   p_durability: int = 0, p_luck: float = 0.0, p_crit_resist: float = 0.0,
		   p_slots: int = 0, p_weight_mult: float = 1.0):
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
	max_durability = p_durability
	luck_bonus = p_luck
	crit_resist_bonus = p_crit_resist
	inv_slots_bonus = p_slots
	weight_multiplier = p_weight_mult

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
		ArmorSlot.BACK: return tr("SLOT_BACK")
		ArmorSlot.SUB: return tr("SLOT_SUB")
	return ""

func is_equippable() -> bool:
	return type == Type.WEAPON or type == Type.TOOL or type == Type.ARMOR
