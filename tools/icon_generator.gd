@tool
extends Node

const CHAR_DATA: Array = [
	{ "path": "res://scripts/characters/raptor/raptor_character.gd",		"file": "raptor.png" },
	{ "path": "res://scripts/characters/dragon/dragon_character.gd",		"file": "dragon.png" },
	{ "path": "res://scripts/characters/warrior/warrior_character.gd",	"file": "warrior.png" },
	{ "path": "res://scripts/characters/beyordeath/beyordeath_character.gd","file": "beyordeath.png" },
]
const OUT := "res://assets/icon_character/"

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_run()

func _run() -> void:
	for d in CHAR_DATA:
		var path: String = d["path"] as String
		var fname: String = d["file"] as String
		var ScriptClass = load(path)
		if not ScriptClass:
			push_error("Cannot load: ", path)
			continue
		var ch: CharacterBase = ScriptClass.new()
		if not ch:
			push_error("Cannot instantiate: ", path)
			continue
		await _snap(ch, OUT.path_join(fname))
	print("=== All icons generated ===")
	queue_free()

func _snap(ch: CharacterBase, out: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)

	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(2.0, 2.2, 2.0), Vector3.ZERO)

	for p in [Vector3(3, 6, 4), Vector3(-3, 4, -2)]:
		var lt := DirectionalLight3D.new()
		vp.add_child(lt)
		lt.look_at_from_position(p, Vector3.ZERO)
		lt.light_energy = 1.5 if p.z > 0 else 0.6

	ch.position = Vector3.ZERO
	ch.set_meta("no_world_hp_bar", true)
	vp.add_child(ch)

	await RenderingServer.frame_post_draw

	var img: Image = vp.get_texture().get_image()
	if img:
		var r := img.save_png(out)
		if r == OK:
			print("Saved: ", out)
		else:
			push_error("Save failed: ", out, " err=", r)
	vp.queue_free()
	await get_tree().process_frame
