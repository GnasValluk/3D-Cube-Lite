## core/character_manager.gd
## Quản lý danh sách nhân vật người chơi, điều phối switch, camera.
##
## Phím:  Tab = tuần tự   1/2/3 = chọn nhân vật   4 = Player

extends Node3D
class_name CharacterManager

signal character_switched(ch: CharacterBase)
signal party_changed()

var _characters: Array[CharacterBase] = []
var _current:    int = 0
var party_names: Array[String] = ["Raptor", "Dragon", "Warrior"]

var _iso_rig: Node3D
var _tp_rig:  Node3D

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	for ch in get_children():
		if ch is CharacterBase and ch._is_player:
			_characters.append(ch as CharacterBase)

	# Đưa "Player" lên đầu để là mặc định
	var player_idx: int = -1
	for i in range(_characters.size()):
		if _characters[i].character_name == "Player":
			player_idx = i
			break
	if player_idx > 0:
		var player := _characters[player_idx]
		_characters.erase(player)
		_characters.insert(0, player)

	if _characters.is_empty():
		push_error("CharacterManager: không có CharacterBase nào cho người chơi!")
		return

	var root := get_parent()
	_iso_rig = root.get_node_or_null("CameraRig")
	_tp_rig  = root.get_node_or_null("TPCameraRig")

	for ch in _characters:
		ch.set_physics_process(false)
		ch.set_process_unhandled_input(false)
		ch.set_process_unhandled_key_input(false)

	await get_tree().process_frame

	# Chỉ giữ 1 character trong tree — các character khác ở ngoài tree
	for i in range(1, _characters.size()):
		remove_child(_characters[i])

	_characters[0].set_active(true)
	_characters[0].play_spawn_animation()

	_aim_cameras_at(_characters[0])
	character_switched.emit(_characters[0])

# ── Offline cooldown tick ─────────────────────────────────────────────────────
func _process(delta: float) -> void:
	for ch in _characters:
		if ch != _characters[_current]:
			var cd_delta: float = delta * ch.cooldown_rate
			ch._lmb_cd = max(ch._lmb_cd - cd_delta, 0.0)
			ch._q_cd = max(ch._q_cd - cd_delta, 0.0)
			ch._r_cd = max(ch._r_cd - cd_delta, 0.0)
			ch._dash_cd = max(ch._dash_cd - delta, 0.0)
			ch._freeze_timer = max(ch._freeze_timer - delta, 0.0)
			ch._han_bang_buff = max(ch._han_bang_buff - delta, 0.0)
			# Mana regen for off-tree characters
			ch._mana_regen_acc += ch.mp_regen * delta
			if ch._mana_regen_acc >= 1.0:
				var gain: int = int(ch._mana_regen_acc)
				ch._mana_regen_acc -= gain
				ch.mana = mini(ch.mana + gain, ch.max_mana)
				ch.mana_changed.emit(ch.mana, ch.max_mana)
			ch._on_offline_tick(delta, cd_delta)

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			var cur := get_current_character()
			var is_player: bool = cur != null and cur.character_name == "Player"
			match k.keycode:
				KEY_TAB:
					_switch_party_next()
				KEY_1, KEY_KP_1:
					if not is_player: _switch_to_party(0)
				KEY_2, KEY_KP_2:
					if not is_player: _switch_to_party(1)
				KEY_3, KEY_KP_3:
					if not is_player: _switch_to_party(2)
				KEY_4, KEY_KP_4:
					_switch_to_player()

func _switch_party_next() -> void:
	var party := get_party_characters()
	if party.is_empty():
		return
	var active := get_current_character()
	if active == null:
		switch_by_name(party[0].character_name)
		return
	for i in range(party.size()):
		if party[i].character_name == active.character_name:
			var next_idx := (i + 1) % party.size()
			switch_by_name(party[next_idx].character_name)
			return
	switch_by_name(party[0].character_name)

func _switch_to_party(idx: int) -> void:
	var party := get_party_characters()
	if idx < party.size():
		switch_by_name(party[idx].character_name)

func _switch_to_player() -> void:
	for i in range(_characters.size()):
		if _characters[i].character_name == "Player":
			_switch_to(i)
			return

func _switch_to(idx: int) -> void:
	if idx == _current:
		return
	var prev_ch: CharacterBase = _characters[_current]
	var next_ch: CharacterBase = _characters[idx]

	var saved_pos := prev_ch.global_position
	var saved_rot := prev_ch.rotation

	prev_ch.set_active(false)
	remove_child(prev_ch)

	_current = idx

	add_child(next_ch)
	next_ch.global_position = saved_pos
	next_ch.rotation        = saved_rot
	next_ch.velocity        = Vector3.ZERO
	next_ch.set_active(true)
	next_ch.play_spawn_animation()

	_aim_cameras_at(next_ch)
	character_switched.emit(next_ch)
	_flash(next_ch.global_position)

# ── Party API ─────────────────────────────────────────────────────────────────
func get_party_characters() -> Array[CharacterBase]:
	var result: Array[CharacterBase] = []
	for name in party_names:
		for ch in _characters:
			if ch.character_name == name:
				result.append(ch)
				break
	return result

func get_current_character() -> CharacterBase:
	if _characters.is_empty():
		return null
	return _characters[_current]

func switch_by_name(name: String) -> void:
	var found_idx: int = -1
	for i in range(_characters.size()):
		if _characters[i].character_name == name:
			found_idx = i
			break
	if found_idx != -1:
		_switch_to(found_idx)

func set_party_order(order: Array[String]) -> void:
	party_names = order.duplicate()
	party_changed.emit()

# ── Camera ────────────────────────────────────────────────────────────────────
func _aim_cameras_at(ch: CharacterBase) -> void:
	if is_instance_valid(_iso_rig):
		if _iso_rig.has_method("set_target"):
			_iso_rig.set_target(ch)
		else:
			_iso_rig.set("_target", ch)
	if is_instance_valid(_tp_rig):
		if _tp_rig.has_method("set_target"):
			_tp_rig.set_target(ch)
		else:
			_tp_rig.set("_target", ch)

# ── Swap flash ────────────────────────────────────────────────────────────────
func _flash(pos: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var light := OmniLight3D.new()
	light.light_energy = 8.0
	light.omni_range   = 5.0
	light.light_color  = Color(0.6, 1.0, 0.8) if _current == 0 else Color(0.9, 0.3, 1.0)
	parent.add_child(light)
	light.global_position = pos + Vector3(0, 1, 0)
	get_tree().create_timer(0.25).timeout.connect(func(): light.queue_free())
