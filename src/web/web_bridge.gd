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
##     {"type": "buy_gold" | "sell_gold" | "pay_dealer", "gold": n}
##     {"type": "borrow"} | {"type": "repay", "index": i} | {"type": "sleep"}
##
## Commands call PokerTable's public commands, which re-validate everything.

signal state_sent(json: String)

var last_state: Dictionary = {}

var _table: PokerTable
# JavaScriptObjects are untyped so their JS properties resolve dynamically.
var _host = null
var _command_callback = null  # keep a reference or JS drops it

## True when running in a browser page that defines window.maverickHost.
static func host_present() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("typeof window.maverickHost === 'object'", true))

func attach(table: PokerTable) -> void:
	_table = table
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
			_table.buy_in(int(command.get("chips", 0)))
		"action":
			var action := int(command.get("action", -1))
			if action < PokerBetting.Action.FOLD or action > PokerBetting.Action.RAISE:
				return false
			_table.player_action(action, int(command.get("amount", 0)))
		"next_hand":
			_table.next_hand()
		"leave":
			_table.leave_table()
		"save":
			_table.save_progress()
		"load":
			_table.load_progress()
		"buy_gold":
			_table.buy_gold(int(command.get("gold", 0)))
		"sell_gold":
			_table.sell_gold(int(command.get("gold", 0)))
		"pay_dealer":
			_table.pay_dealer(int(command.get("gold", 0)))
		"borrow":
			_table.borrow_marker()
		"repay":
			_table.repay_marker(int(command.get("index", -1)))
		"sleep":
			_table.sleep()
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
