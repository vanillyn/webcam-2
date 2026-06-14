extends Node3D






const CHARACTER_GLB := "res://assets/character.glb"



const BONE_HEAD        := "J_Bip_C_Head"
const BONE_NECK        := "J_Bip_C_Neck"
const BONE_UPPER_CHEST := "J_Bip_C_UpperChest"


const HEAD_YAW_LIMIT   := 35.0
const HEAD_PITCH_LIMIT := 20.0


const NECK_FACTOR  := 0.35
const SPINE_FACTOR := 0.15


const TRACK_SPEED := 3.5






const SIT_POSITION   := Vector3(-0.1, 0.0, -0.64)
const SIT_ROTATION_Y := 0.0





var _skeleton       : Skeleton3D = null
var _anim_player    : AnimationPlayer = null

var _head_bone  : int = -1
var _neck_bone  : int = -1
var _spine_bone : int = -1

var _target_head_rot  : Vector3 = Vector3.ZERO
var _current_head_rot : Vector3 = Vector3.ZERO
var _current_neck_rot : Vector3 = Vector3.ZERO
var _current_spine_rot: Vector3 = Vector3.ZERO

var _time      : float = 0.0
var _hit_shake : float = 0.0

var _model_loaded : bool = false





func _ready() -> void:
	position           = SIT_POSITION
	rotation_degrees.y = SIT_ROTATION_Y
	_load_character()


func _load_character() -> void:

	if not ResourceLoader.exists(CHARACTER_GLB):
		push_error(
			"[CharacterController] '%s' not found.\n"
			% CHARACTER_GLB
			+ "  → Copy your character.glb into res://assets/ and re-run."
		)
		_spawn_placeholder()
		return


	var packed : PackedScene = load(CHARACTER_GLB)
	if packed == null:
		push_error("[CharacterController] load() returned null for '%s'." % CHARACTER_GLB)
		_spawn_placeholder()
		return


	var instance : Node3D = packed.instantiate()
	if instance == null:
		push_error("[CharacterController] instantiate() returned null.")
		_spawn_placeholder()
		return




	var root_aabb := _get_rough_height(instance)
	if root_aabb > 5.0:
		instance.scale = Vector3.ONE * 0.01
		print("[CharacterController] Model height ~%.2f — applying 0.01 scale." % root_aabb)
	else:
		instance.scale = Vector3.ONE

	add_child(instance)


	_skeleton = _find_skeleton(instance)
	if _skeleton == null:
		push_warning("[CharacterController] No Skeleton3D found — bone tracking disabled.")
	else:
		_head_bone  = _skeleton.find_bone(BONE_HEAD)
		_neck_bone  = _skeleton.find_bone(BONE_NECK)
		_spine_bone = _skeleton.find_bone(BONE_UPPER_CHEST)

		if _head_bone == -1:
			push_warning(
				"[CharacterController] Bone '%s' not found.\n" % BONE_HEAD
				+ "  Available bones: %s" % _list_bones(_skeleton)
			)
		else:
			print("[CharacterController] Model ready. Head bone idx=%d" % _head_bone)


	_anim_player = _find_anim_player(instance)
	if _anim_player and _anim_player.has_animation("idle"):
		_anim_player.play("idle")
		print("[CharacterController] Playing 'idle' animation.")
	elif _anim_player and _anim_player.get_animation_list().size() > 0:
		var first := _anim_player.get_animation_list()[0]
		_anim_player.play(first)
		print("[CharacterController] Playing animation: '%s'" % first)

	_model_loaded = true
	print("[CharacterController] Character loaded successfully.")

	_apply_sit_pose()



func _get_rough_height(node: Node) -> float:
	var h := _collect_height(node)
	return h


func _collect_height(node: Node) -> float:
	var max_h := 0.0
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			max_h = maxf(max_h, mi.mesh.get_aabb().size.y)
	for child in node.get_children():
		max_h = maxf(max_h, _collect_height(child))
	return max_h



func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null



func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result != null:
			return result
	return null



func _list_bones(skel: Skeleton3D) -> String:
	var names : Array[String] = []
	for i in skel.get_bone_count():
		names.append(skel.get_bone_name(i))
	return ", ".join(names)



func _spawn_placeholder() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.18
	mesh.height = 1.4
	body.mesh   = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.82)
	body.material_override = mat
	body.position.y = 0.85
	add_child(body)
	push_warning("[CharacterController] Using placeholder mesh — no GLB found.")



func _apply_sit_pose() -> void:
	if _skeleton == null:
		return




	var pose_map : Dictionary = {

		"J_Bip_C_Hips":        Vector3(-10.0,  0.0,  0.0),
		"J_Bip_C_Spine":       Vector3(-14.0,  0.0,  0.0),
		"J_Bip_C_Chest":       Vector3( -8.0,  0.0,  0.0),
		"J_Bip_C_UpperChest":  Vector3( -4.0,  0.0,  0.0),



		"J_Bip_L_UpperLeg":    Vector3(-88.0,  6.0,  0.0),
		"J_Bip_L_LowerLeg":    Vector3( 78.0,  0.0,  0.0),
		"J_Bip_L_Foot":        Vector3( 12.0,  0.0,  0.0),
		"J_Bip_R_UpperLeg":    Vector3(-88.0, -6.0,  0.0),
		"J_Bip_R_LowerLeg":    Vector3( 78.0,  0.0,  0.0),
		"J_Bip_R_Foot":        Vector3( 12.0,  0.0,  0.0),



		"J_Bip_L_Shoulder":    Vector3(  8.0,  0.0,  6.0),

		"J_Bip_L_UpperArm":    Vector3(  0.0,  0.0, 22.0),

		"J_Bip_L_LowerArm":    Vector3(-68.0,  0.0,  0.0),

		"J_Bip_L_Hand":        Vector3(-10.0,  8.0,  0.0),

		"J_Bip_R_Shoulder":    Vector3(  8.0,  0.0, -6.0),
		"J_Bip_R_UpperArm":    Vector3(  0.0,  0.0,-22.0),
		"J_Bip_R_LowerArm":    Vector3(-68.0,  0.0,  0.0),
		"J_Bip_R_Hand":        Vector3(-10.0, -8.0,  0.0),
	}

	for bone_name: String in pose_map:
		var idx := _skeleton.find_bone(bone_name)
		if idx == -1:
			continue
		var rot_deg : Vector3 = pose_map[bone_name]
		var q := Quaternion.from_euler(Vector3(
			deg_to_rad(rot_deg.x),
			deg_to_rad(rot_deg.y),
			deg_to_rad(rot_deg.z)
		))
		_skeleton.set_bone_pose_rotation(idx, q)




func _process(delta: float) -> void:
	_time += delta

	if _skeleton == null or _head_bone == -1:
		return


	var vp_size := get_viewport().get_visible_rect().size
	var mouse   := get_viewport().get_mouse_position()
	var norm := Vector2(
		(mouse.x / vp_size.x) * 2.0 - 1.0,
		-((mouse.y / vp_size.y) * 2.0 - 1.0)
	)


	_target_head_rot = Vector3(
		-norm.y * HEAD_PITCH_LIMIT,
		 norm.x * HEAD_YAW_LIMIT,
		 0.0
	)


	if _hit_shake > 0.0:
		_hit_shake -= delta * 4.0
		var shake := _hit_shake * 8.0
		_target_head_rot += Vector3(
			sin(_time * 20.0) * shake,
			cos(_time * 17.0) * shake * 0.5,
			0.0
		)


	_target_head_rot.x += sin(_time * 0.8) * 0.6
	_target_head_rot.z  = sin(_time * 0.5) * 0.4


	_current_head_rot   = _current_head_rot.lerp(_target_head_rot,
		delta * TRACK_SPEED)
	_current_neck_rot   = _current_neck_rot.lerp(
		_target_head_rot * NECK_FACTOR,  delta * TRACK_SPEED * 0.7)
	_current_spine_rot  = _current_spine_rot.lerp(
		_target_head_rot * SPINE_FACTOR, delta * TRACK_SPEED * 0.4)


	_apply_bone_rotation(_head_bone,  _current_head_rot)
	if _neck_bone  != -1: _apply_bone_rotation(_neck_bone,  _current_neck_rot)
	if _spine_bone != -1: _apply_bone_rotation(_spine_bone, _current_spine_rot)


func _apply_bone_rotation(bone_idx: int, rot_deg: Vector3) -> void:
	if _skeleton == null or bone_idx < 0:
		return
	var current : Quaternion = _skeleton.get_bone_pose_rotation(bone_idx)
	var target  : Quaternion = Quaternion.from_euler(
		Vector3(
			deg_to_rad(rot_deg.x),
			deg_to_rad(rot_deg.y),
			deg_to_rad(rot_deg.z)
		)
	)
	_skeleton.set_bone_pose_rotation(bone_idx, current.slerp(target, 0.2))





func register_hit(direction: Vector3) -> void:
	_hit_shake = 1.0
	print("[CharacterController] Hit! direction=%s" % str(direction))
