extends Node3D

const MAX_MESSAGES := 8
const FLOAT_DURATION := 5.0
const COLLAPSE_DELAY := 0.3


const SPAWN_AREA_X := 2.2
const SPAWN_Y_BASE := 1.2
const SPAWN_Y_STEP := 0.30
const SPAWN_Z      := -0.5


const CARD_W := 1.05
const CARD_H := 0.22
const CARD_D := 0.04


const COLOR_GLASS  := Color(0.063, 0.024, 0.039, 0.88)
const COLOR_BORDER := Color(0.878, 0.188, 0.290, 0.30)
const COLOR_TEXT   := Color(1.0, 0.953, 0.961)
const COLOR_USER   := Color(1.0, 0.761, 0.8)

var _cards: Array[Node3D] = []
var _card_index: int = 0


func _ready() -> void:
	pass


func spawn_message(user: String, text: String) -> void:

	if _cards.size() >= MAX_MESSAGES:
		var oldest: Node3D = _cards.pop_front()
		if is_instance_valid(oldest):
			_collapse_card(oldest, true)

	var card := _create_card(user, text, _cards.size())
	_cards.append(card)
	add_child(card)


	var timer := get_tree().create_timer(FLOAT_DURATION)
	timer.timeout.connect(_collapse_card.bind(card, false))


func _create_card(user: String, text: String, stack_idx: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ChatCard_%s" % user


	var x_spread := -SPAWN_AREA_X * 0.5 + (stack_idx % 5) * (SPAWN_AREA_X / 4.0)
	var y_pos    := SPAWN_Y_BASE + (stack_idx / 5) * SPAWN_Y_STEP * 2.5
	root.position = Vector3(x_spread, y_pos + 0.4, SPAWN_Z)


	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CARD_W, CARD_H, CARD_D)
	mesh_inst.mesh = mesh


	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_GLASS
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)


	_add_border(root)


	var label_node := _make_label_quad(user, text)
	label_node.position.z = CARD_D * 0.5 + 0.001
	root.add_child(label_node)


	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CARD_W, CARD_H, CARD_D)
	col.shape = shape
	body.add_child(col)
	root.add_child(body)

	root.set_meta("float_y", y_pos)
	root.set_meta("user", user)
	root.set_meta("alive", true)


	_animate_in(root, y_pos)

	return root


func _add_border(root: Node3D) -> void:
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = COLOR_BORDER
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


	var borders := [
		[Vector3(CARD_W, 0.008, CARD_D * 1.1),  Vector3(0, CARD_H * 0.5 + 0.004, 0)],
		[Vector3(CARD_W, 0.008, CARD_D * 1.1),  Vector3(0, -CARD_H * 0.5 - 0.004, 0)],
		[Vector3(0.008, CARD_H + 0.008, CARD_D * 1.1), Vector3(-CARD_W * 0.5 - 0.004, 0, 0)],
		[Vector3(0.008, CARD_H + 0.008, CARD_D * 1.1), Vector3(CARD_W * 0.5 + 0.004, 0, 0)],
	]
	for b in borders:
		var bmi := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = b[0]
		bmi.mesh = bmesh
		bmi.material_override = bmat
		bmi.position = b[1]
		root.add_child(bmi)


func _make_label_quad(user: String, text: String) -> MeshInstance3D:

	var sv := SubViewport.new()
	sv.size = Vector2i(512, 100)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.size = Vector2(512, 100)
	sv.add_child(bg)

	var user_label := Label.new()
	user_label.text = user
	user_label.position = Vector2(14, 6)
	user_label.add_theme_color_override("font_color", COLOR_USER)
	user_label.add_theme_font_size_override("font_size", 14)
	sv.add_child(user_label)

	var text_label := Label.new()
	text_label.text = text.substr(0, 80)
	text_label.position = Vector2(14, 28)
	text_label.size = Vector2(484, 62)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", COLOR_TEXT)
	text_label.add_theme_font_size_override("font_size", 18)
	sv.add_child(text_label)


	var vp_tex := ViewportTexture.new()
	vp_tex.viewport_path = sv.get_path()



	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CARD_W - 0.06, CARD_H - 0.04)
	plane.orientation = PlaneMesh.FACE_Z
	quad.mesh = plane

	var qmat := StandardMaterial3D.new()
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.albedo_texture = vp_tex
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material_override = qmat



	quad.set_meta("sv", sv)
	quad.ready.connect(func():

		var cl := CanvasLayer.new()
		cl.layer = -10
		cl.visible = false
		get_tree().root.add_child(cl)
		cl.add_child(sv)

		await get_tree().process_frame
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		quad.set_meta("canvas_layer", cl)
	)

	return quad


func _animate_in(card: Node3D, target_y: float) -> void:
	card.scale = Vector3(0.85, 0.85, 0.85)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "position:y", target_y, 0.35)
	tween.parallel().tween_property(card, "scale", Vector3.ONE, 0.35)


func _collapse_card(card: Node3D, immediate: bool) -> void:
	if not is_instance_valid(card):
		return
	if not card.get_meta("alive", false):
		return
	card.set_meta("alive", false)

	if immediate:
		card.queue_free()
		return



	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)


	tween.tween_property(card, "rotation_degrees:z",
		randf_range(-15.0, 15.0), 0.15)
	tween.tween_property(card, "rotation_degrees:z",
		randf_range(-60.0, 60.0), 0.25)
	tween.parallel().tween_property(card, "position:y",
		-0.2, 0.35)
	tween.parallel().tween_property(card, "rotation_degrees:x",
		randf_range(-30.0, 30.0), 0.35)

	tween.tween_callback(func(): _fade_and_free(card))


func _fade_and_free(card: Node3D) -> void:
	if not is_instance_valid(card):
		return
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector3(0.8, 0.0, 0.8), 0.2)
	tween.tween_callback(func():

		for child in card.get_children():
			if child is MeshInstance3D and child.has_meta("canvas_layer"):
				child.get_meta("canvas_layer").queue_free()
		if is_instance_valid(card):
			card.queue_free()
		_cards.erase(card)
	)
