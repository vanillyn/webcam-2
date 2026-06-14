


extends Node

signal message_received(msg: Dictionary)
signal connected
signal disconnected

const WS_URL := "ws://localhost:8877"
const RECONNECT_DELAY_BASE := 1.0
const RECONNECT_DELAY_MAX := 8.0

var _ws: WebSocketPeer = null
var _reconnect_timer: float = 0.0
var _reconnect_delay: float = 1.0
var _is_connected: bool = false


func _ready() -> void:
	_connect_ws()


func _connect_ws() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(WS_URL)
	if err != OK:
		push_warning("[StreamdClient] connect_to_url failed: %s" % str(err))
		_schedule_reconnect()
	else:
		print("[StreamdClient] Connecting to %s..." % WS_URL)


func _process(delta: float) -> void:
	if _ws == null:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_connect_ws()
		return

	_ws.poll()
	var state := _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_is_connected = true
				_reconnect_delay = RECONNECT_DELAY_BASE
				print("[StreamdClient] Connected!")
				connected.emit()

			while _ws.get_available_packet_count() > 0:
				var raw := _ws.get_packet()
				var text := raw.get_string_from_utf8()
				var json := JSON.new()
				if json.parse(text) == OK:
					message_received.emit(json.data)

		WebSocketPeer.STATE_CLOSED:
			if _is_connected:
				_is_connected = false
				disconnected.emit()
				print("[StreamdClient] Disconnected. Reconnecting in %.1fs..." % _reconnect_delay)
			_ws = null
			_schedule_reconnect()

		WebSocketPeer.STATE_CONNECTING:
			pass


func _schedule_reconnect() -> void:
	_reconnect_timer = _reconnect_delay
	_reconnect_delay = min(_reconnect_delay * 1.5, RECONNECT_DELAY_MAX)



func send_cmd(msg: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))
