class_name WebBridge
extends Node
## JSON message bridge between the Godot game and a Svelte host page.
##
## Godot owns all game state and rules. The host page only draws the interface
## and sends player intents. Protocol (all messages are JSON strings):
##
##   Godot -> page  window.maverickHost.receive(json)
##     {"type": "state", "snapshot": {...}, "message": "...", "history": [...],
##      "status": {...}, "phase": "" | "reveal_cards" | "settling" | "hand_over"}
##
##   page -> Godot  the callback passed to window.maverickHost.attachGodot(cb)
##     {"type": "ready"}                         resend the current state
##     {"type": "buy_in", "chips": 1000}
##     {"type": "action", "action": 0-4, "amount": 0}   PokerBetting.Action
##     {"type": "next_hand"} | {"type": "leave"} | {"type": "save"} | {"type": "load"}
##
## Commands are routed through PokerTableUI's existing signals, so the web and
## Godot-drawn interfaces share exactly one set of table entry points.

signal state_sent(json: String)

var last_state: Dictionary = {}

var _table: PokerTable
var _ui: PokerTableUI
# JavaScriptObjects are untyped so their JS properties resolve dynamically.
var _host = null
var _command_callback = null  # keep a reference or JS drops it

## True when running in a browser page that defines window.maverickHost.
static func host_present() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("typeof window.maverickHost === 'object'", true))

func attach(table: PokerTable, ui: PokerTableUI) -> void:
	_table = table
	_ui = ui
	_table.state_changed.connect(_on_state_changed)
	if host_present():
		var window = JavaScriptBridge.get_interface("window")
		_host = window.maverickHost
		_command_callback = JavaScriptBridge.create_callback(_on_js_command)
		_host.attachGodot(_command_callback)

## Apply one decoded command. Returns false for unknown or malformed input.
func handle_command(command: Dictionary) -> bool:
	match str(command.get("type", "")):
		"ready":
			if not last_state.is_empty():
				_send(last_state)
		"buy_in":
			_ui.buy_in_requested.emit(int(command.get("chips", 0)))
		"action":
			var action := int(command.get("action", -1))
			if action < PokerBetting.Action.FOLD or action > PokerBetting.Action.RAISE:
				return false
			_ui.player_action_requested.emit(action, int(command.get("amount", 0)))
		"next_hand":
			_ui.next_hand_requested.emit()
		"leave":
			_ui.leave_table_requested.emit()
		"save":
			_ui.save_requested.emit()
		"load":
			_ui.load_requested.emit()
		_:
			return false
	return true

func _on_js_command(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if typeof(parsed) == TYPE_DICTIONARY:
		handle_command(parsed)
	else:
		push_warning("WebBridge: ignoring malformed command %s" % str(args[0]))

func _on_state_changed(state: Dictionary) -> void:
	last_state = state.duplicate(true)
	last_state["type"] = "state"
	_send(last_state)

func _send(state: Dictionary) -> void:
	var json := JSON.stringify(state)
	state_sent.emit(json)
	if _host != null:
		_host.receive(json)
