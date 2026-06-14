







extends Node3D


const CHARACTER_GLB := "res://assets/character.glb"


const HEAD_YAW_LIMIT   := 35.0
const HEAD_PITCH_LIMIT := 20.0
const NECK_FACTOR      := 0.35
const SPINE_FACTOR     := 0.15


const TRACK_SPEED := 3.5



const SIT_POSITION := Vector3(-0.1, 0.0, 0.55)
const SIT_ROTATION_Y := 180.0

var _skeleton: Skeleton3D = null
var _head_bone: int   = -1
var _neck_bone: int   = -1
var _spine_bone: int  = -1


var _target_head_rot: Vector3  = Vector3.ZERO
var _current_head_rot: Vector3 = Vector3.ZERO
var _current_neck_rot: Vector3 = Vector3.ZERO
var _current_spine_rot: Vector3 = Vector3.ZERO


var _time: float = 0.0


var _hit_shake: float = 0.0


func _ready() -> void:
	position = SIT_POSITION
	rotation_degrees.y = SIT_ROTATION_Y
	_load_character()


func _load_character() -> void:
	if not ResourceLoader.exists(CHARACTER_GLB):
		push_error("[Character] GLB not found at: %s — copy your character.glb to assets/" % CHARACTER_GLB)
		_spawn_placeholder()
		return

	var scene: PackedScene = load(CHARACTER_GLB)
	var instance: Node3D = scene.instantiate()



	instance.scale = Vector3.ONE * 0.01

	add_child(instance)


	_skeleton = _find_skeleton(instance)
	if _skeleton == null:
		push_warning("[Character] No Skeleton3D found in model.")
		return

	_head_bone  = _skeleton.find_bone("J_Bip_C_Head")
	_neck_bone  = _skeleton.find_bone("J_Bip_C_Neck")
	_spine_bone = _skeleton.find_bone("J_Bip_C_UpperChest")

	if _head_bone == -1:
		push_warning("[Character] Head bone 'J_Bip_C_Head' not found — head tracking disabled.")
	else:
		print("[Character] Model loaded. Head bone idx: %d" % _head_bone)


func _spawn_placeholder() -> void:

	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.18
	mesh.height = 1.4
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.82)
	body.material_override = mat
	body.position.y = 0.85
	add_child(body)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null


func _process(delta: float) -> void:
	_time += delta

	if _skeleton == null or _head_bone == -1:
		return


	var vp_size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()


	var norm := Vector2(
		(mouse.x / vp_size.x) * 2.0 - 1.0,
		-((mouse.y / vp_size.y) * 2.0 - 1.0)
	)




	_target_head_rot = Vector3(
		-norm.y * HEAD_PITCH_LIMIT,
		norm.x  * HEAD_YAW_LIMIT,
		0.0
	)


	if _hit_shake > 0.0:
		_hit_shake -= delta * 4.0
		var shake_amt := _hit_shake * 8.0
		_target_head_rot += Vector3(
			sin(_time * 20.0) * shake_amt,
			cos(_time * 17.0) * shake_amt * 0.5,
			0.0
		)


	_target_head_rot.x += sin(_time * 0.8) * 0.6
	_target_head_rot.z  = sin(_time * 0.5) * 0.4


	_current_head_rot  = _current_head_rot.lerp(_target_head_rot,          delta * TRACK_SPEED)
	_current_neck_rot  = _current_neck_rot.lerp(_target_head_rot * NECK_FACTOR,  delta * TRACK_SPEED * 0.7)
	_current_spine_rot = _current_spine_rot.lerp(_target_head_rot * SPINE_FACTOR, delta * TRACK_SPEED * 0.4)


	_apply_bone_rotation(_head_bone,  _current_head_rot)

	if _neck_bone != -1:
		_apply_bone_rotation(_neck_bone, _current_neck_rot)

	if _spine_bone != -1:
		_apply_bone_rotation(_spine_bone, _current_spine_rot)


func _apply_bone_rotation(bone_idx: int, rot_deg: Vector3) -> void:
	if _skeleton == null or bone_idx < 0:
		return
	var current: Quaternion = _skeleton.get_bone_pose_rotation(bone_idx)
	var target: Quaternion = Quaternion.from_euler(
		Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	)

	_skeleton.set_bone_pose_rotation(bone_idx, current.slerp(target, 0.2))



func register_hit(direction: Vector3) -> void:
	_hit_shake = 1.0
	print("[Character] Ouch! Hit from direction: %s" % str(direction))
