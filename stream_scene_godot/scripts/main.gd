extends Node3D

@onready var streamd_client : Node     = $StreamdClient
@onready var character      : Node3D   = $World/CharacterRoot
@onready var chat_spawner   : Node3D   = $World/ChatSpawner
@onready var throw_manager  : Node3D   = $World/ThrowManager
@onready var camera         : Camera3D = $Camera3D
@onready var room_builder   : Node3D   = $World/RoomBuilder

const CAM_DESK_POS    := Vector3(0.963, 1.874, -0.468)
# const CAM_LOOK_TARGET := Vector3(0.0, 1.1, -10)

var _time            : float   = 0.0
var _shake_timer     : float   = 0.0
var _shake_origin    : Vector3 = CAM_DESK_POS
var _cam_settled_pos : Vector3 = CAM_DESK_POS

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 0.0))

	camera.position = CAM_DESK_POS
	_cam_settled_pos = CAM_DESK_POS

	streamd_client.message_received.connect(_on_streamd_message)
	streamd_client.connected.connect(_on_connected)
	room_builder.build()
	print("[Main] ready, waiting for streamd ws://localhost:8877")

func _on_connected() -> void:
	print("[Main] connected to streamd")

func _on_streamd_message(msg: Dictionary) -> void:
	var t : String = msg.get("type", "")
	match t:
		"init":
			var state : Dictionary = msg.get("state", {})
			room_builder.set_scene_mode(state.get("scene", "live"))
			for entry in state.get("chat", []):
				chat_spawner.spawn_message(entry.get("user", "?"), entry.get("text", ""))

		"chat":
			var user : String = msg.get("user", "?")
			var text : String = msg.get("text", "")
			chat_spawner.spawn_message(user, text)

			if text.begins_with("!throw"):
				var parts     := text.split(" ", false, 2)
				var item_name := parts[1] if parts.size() > 1 else ""
				throw_manager.throw_item(item_name)
			elif text.begins_with("!shake"):
				_begin_shake()

		"scene":
			room_builder.set_scene_mode(msg.get("value", "live"))

		"lightsoff":
			room_builder.set_lights_off(true)

		"lightson":
			room_builder.set_lights_off(false)

func _begin_shake() -> void:
	_shake_timer = 5.0
	_shake_origin = camera.position

func _process(delta: float) -> void:
	_time += delta

	if _shake_timer > 0.0:
		_shake_timer -= delta
		var intensity := clampf(_shake_timer / 5.0, 0.0, 1.0) * 0.045
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.6, intensity * 0.6),
			randf_range(-intensity * 0.3, intensity * 0.3)
		)
		camera.position = _shake_origin + offset
		if _shake_timer <= 0.0:
			_shake_timer = 0.0
	else:
		camera.position = camera.position.lerp(_cam_settled_pos, delta * 4.0)

	var drift := Vector3(
		sin(_time * 0.018) * 0.004,
		sin(_time * 0.032) * 0.002,
		0.0
	)
	if _shake_timer <= 0.0:
		camera.position = _cam_settled_pos + drift
