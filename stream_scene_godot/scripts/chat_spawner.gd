extends Node3D

const MAX_MESSAGES    : int   = 8
const FLOAT_DURATION  : float = 544.0

const SPAWN_AREA_X : float = 0.911
const SPAWN_Y_BASE : float = 1.981
const SPAWN_Y_STEP : float = 0.045
const SPAWN_Z      : float = 0.575

const CARD_W : float = 1.0
const CARD_H : float = 0.20
const CARD_D : float = 0.03

const COLOR_GLASS  := Color(0.063, 0.024, 0.039, 0.82)
const COLOR_BORDER := Color(0.878, 0.188, 0.290, 0.45)
const COLOR_TEXT   := Color(1.0,   0.953, 0.961, 1.0)
const COLOR_USER   := Color(1.0,   0.761, 0.800, 1.0)

var _cards      : Array[Node3D] = []
var _card_index : int           = 0

func _ready() -> void:
	pass

func spawn_message(user: String, text: String) -> void:
	if _cards.size() >= MAX_MESSAGES:
		var oldest : Node3D = _cards.pop_front()
		if is_instance_valid(oldest):
			_collapse_card(oldest, true)

	var card := _create_card(user, text, _cards.size())
	_cards.append(card)
	add_child(card)

	var timer := get_tree().create_timer(FLOAT_DURATION)
	timer.timeout.connect(_collapse_card.bind(card, false))

func _create_card(user: String, text: String, stack_idx: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ChatCard_%d" % stack_idx

	var col_idx   := stack_idx % 5
	var row_idx   := stack_idx / 5
	var x_spread  := -SPAWN_AREA_X * 0.5 + col_idx * (SPAWN_AREA_X / 4.0)
	var y_pos     := SPAWN_Y_BASE + row_idx * SPAWN_Y_STEP * 2.4
	root.position  = Vector3(x_spread, y_pos + 0.35, SPAWN_Z)

	# glass background box
	var bg_mi   := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(CARD_W, CARD_H, CARD_D)
	bg_mi.mesh   = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color     = COLOR_GLASS
	bg_mat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.blend_mode       = BaseMaterial3D.BLEND_MODE_MIX
	bg_mat.cull_mode        = BaseMaterial3D.CULL_DISABLED
	bg_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.flags_do_not_receive_shadows = true
	bg_mi.material_override = bg_mat
	root.add_child(bg_mi)

	_add_border(root)

	# username Label3D - clean, no SubViewport needed
	var user_label := Label3D.new()
	user_label.text             = user.to_lower()
	user_label.font_size        = 18
	user_label.modulate         = COLOR_USER
	user_label.billboard        = BaseMaterial3D.BILLBOARD_DISABLED 
	user_label.double_sided     = true
	user_label.no_depth_test    = false
	user_label.render_priority  = 1
	user_label.pixel_size       = 0.0018
	user_label.position         = Vector3(-CARD_W * 0.44, CARD_H * 0.18, CARD_D * 0.5 + 0.002)
	user_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(user_label)

	# message text Label3D
	var text_label := Label3D.new()
	var clamped    := text.substr(0, 72)
	text_label.text             = clamped
	text_label.font_size        = 22
	text_label.modulate         = COLOR_TEXT
	text_label.billboard        = BaseMaterial3D.BILLBOARD_DISABLED
	text_label.double_sided     = true
	text_label.no_depth_test    = false
	text_label.render_priority  = 1
	text_label.pixel_size       = 0.0016
	text_label.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	text_label.width            = 560.0
	text_label.position         = Vector3(-CARD_W * 0.44, -CARD_H * 0.08, CARD_D * 0.5 + 0.002)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(text_label)

	root.set_meta("float_y", y_pos)
	root.set_meta("alive",   true)

	_animate_in(root, y_pos)
	return root

func _add_border(root: Node3D) -> void:
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color  = COLOR_BORDER
	bmat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED

	var borders : Array = [
		[Vector3(CARD_W, 0.007, CARD_D * 1.1), Vector3(0,  CARD_H * 0.5 + 0.0035, 0)],
		[Vector3(CARD_W, 0.007, CARD_D * 1.1), Vector3(0, -CARD_H * 0.5 - 0.0035, 0)],
		[Vector3(0.007, CARD_H + 0.007, CARD_D * 1.1), Vector3(-CARD_W * 0.5 - 0.0035, 0, 0)],
		[Vector3(0.007, CARD_H + 0.007, CARD_D * 1.1), Vector3( CARD_W * 0.5 + 0.0035, 0, 0)],
	]
	for b in borders:
		var bmi   := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size           = b[0]
		bmi.mesh             = bmesh
		bmi.material_override = bmat
		bmi.position         = b[1]
		root.add_child(bmi)

func _animate_in(card: Node3D, target_y: float) -> void:
	card.scale = Vector3(0.82, 0.82, 0.82)
	var tween  := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "position:y", target_y,  0.32)
	tween.parallel().tween_property(card, "scale", Vector3.ONE, 0.32)

func _collapse_card(card: Node3D, immediate: bool) -> void:
	if not is_instance_valid(card):
		return
	if not card.get_meta("alive", false):
		return
	card.set_meta("alive", false)

	if immediate:
		_cards.erase(card)
		card.queue_free()
		return

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card, "rotation_degrees:z", randf_range(-18.0, 18.0), 0.14)
	tween.tween_property(card, "rotation_degrees:z", randf_range(-65.0, 65.0), 0.24)
	tween.parallel().tween_property(card, "position:y", -0.3,  0.34)
	tween.parallel().tween_property(card, "rotation_degrees:x", randf_range(-32.0, 32.0), 0.34)
	tween.tween_callback(func(): _fade_and_free(card))

func _fade_and_free(card: Node3D) -> void:
	if not is_instance_valid(card):
		return
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector3(0.8, 0.0, 0.8), 0.18)
	tween.tween_callback(func():
		if is_instance_valid(card):
			card.queue_free()
		_cards.erase(card)
	)
