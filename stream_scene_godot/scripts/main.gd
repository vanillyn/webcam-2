

extends Node3D

@onready var streamd_client: Node = $StreamdClient
@onready var character: Node3D = $World/CharacterRoot
@onready var chat_spawner: Node3D = $World/ChatSpawner
@onready var throw_manager: Node3D = $World/ThrowManager
@onready var camera: Camera3D = $Camera3D
@onready var room_builder: Node3D = $World/RoomBuilder


var _cam_base_pos: Vector3
var _cam_base_rot: Vector3
var _time: float = 0.0


var _cam_look_mouse: Vector2 = Vector2.ZERO

func _ready() -> void:
	_cam_base_pos = camera.position
	_cam_base_rot = camera.rotation_degrees


	streamd_client.message_received.connect(_on_streamd_message)
	streamd_client.connected.connect(_on_connected)


	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))


	room_builder.build()

	print("[Main] StreamScene ready. Waiting for streamd connection...")


func _on_connected() -> void:
	print("[Main] Connected to streamd!")


func _on_streamd_message(msg: Dictionary) -> void:
	var t: String = msg.get("type", "")

	match t:
		"init":
			var state: Dictionary = msg.get("state", {})

			for entry in state.get("chat", []):
				chat_spawner.spawn_message(entry.get("user", "?"), entry.get("text", ""))

		"chat":
			var user: String = msg.get("user", "?")
			var text: String = msg.get("text", "")
			chat_spawner.spawn_message(user, text)


			if text.begins_with("!throw"):
				var parts := text.split(" ", false, 2)
				var item_name := parts[1] if parts.size() > 1 else ""
				throw_manager.throw_item(item_name)

		"scene":
			room_builder.set_scene_mode(msg.get("value", "live"))

		"lightsoff":
			room_builder.set_lights_off(true)

		"lightson":
			room_builder.set_lights_off(false)


func _process(delta: float) -> void:
	_time += delta


	var drift_x := sin(_time * 0.018) * 0.04
	var drift_y := sin(_time * 0.032) * 0.015


	var viewport_size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var norm_mouse := (mouse / viewport_size) * 2.0 - Vector2.ONE
	_cam_look_mouse = _cam_look_mouse.lerp(norm_mouse * 0.6, delta * 1.2)

	camera.position = _cam_base_pos + Vector3(drift_x, drift_y, 0.0)
	camera.rotation_degrees = Vector3(
		_cam_base_rot.x + _cam_look_mouse.y * 0.3,
		_cam_base_rot.y + _cam_look_mouse.x * -0.4,
		_cam_base_rot.z
	)
