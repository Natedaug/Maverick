class_name PokerTableUI
extends Control
## Saloon table view. It presents legal actions supplied by the poker engine.

signal player_action_requested(action: int, target: int)
signal next_hand_requested

const INK := Color("#171612")
const WOOD := Color("#29241B")
const FELT := Color("#174A3A")
const BRASS := Color("#BD9655")
const PARCHMENT := Color("#F0D7A1")
const PAPER := Color("#FFF9E9")
const MUTED := Color("#B9B1A1")

var _player_name: Label
var _player_role: Label
var _player_stack: Label
var _opponent_name: Label
var _opponent_role: Label
var _opponent_stack: Label
var _board_cards: Array[PokerCardView] = []
var _player_cards: Array[PokerCardView] = []
var _opponent_cards: Array[PokerCardView] = []
var _pot_label: Label
var _turn_label: Label
var _message_label: Label
var _history_label: Label
var _call_button: Button
var _wager_button: Button
var _fold_button: Button
var _next_hand_button: Button
var _amount_input: SpinBox
var _wager_range: Label

func _ready() -> void:
	_build_interface()

func render(snapshot: Dictionary, message: String, history: Array[String] = []) -> void:
	var seats: Array = snapshot.get("seats", [])
	if seats.size() < 2:
		return
	var player: Dictionary = seats[0]
	var opponent: Dictionary = seats[1]
	var button_seat: int = snapshot.get("button", 0)
	var current_actor: int = snapshot.get("current_actor", -1)
	_player_name.text = "YOU"
	_opponent_name.text = "THE DRIFTER"
	_player_role.text = "DEALER · SMALL BLIND" if button_seat == 0 else "BIG BLIND"
	_opponent_role.text = "DEALER · SMALL BLIND" if button_seat == 1 else "BIG BLIND"
	_player_role.text += "   ·   YOUR TURN" if current_actor == 0 else ""
	_opponent_role.text += "   ·   ACTING" if current_actor == 1 else ""
	_player_stack.text = "STACK  %s%s" % [_format_amount(player.get("stack", 0)), "   ·   ALL IN" if player.get("all_in", false) else ""]
	_opponent_stack.text = "STACK  %s%s" % [_format_amount(opponent.get("stack", 0)), "   ·   ALL IN" if opponent.get("all_in", false) else ""]
	_update_card_row(_player_cards, player.get("cards", []))
	_update_card_row(_opponent_cards, opponent.get("cards", []))
	_update_card_row(_board_cards, snapshot.get("board", []), false)
	_pot_label.text = "POT  %s" % _format_amount(snapshot.get("pot", 0))
	_turn_label.text = "YOUR TURN" if current_actor == 0 else "DRIFTER'S TURN" if current_actor == 1 else "HAND COMPLETE"
	_message_label.text = message
	var visible_history := history.slice(maxi(0, history.size() - 4), history.size())
	_history_label.text = ""
	for i in range(visible_history.size()):
		if i > 0:
			_history_label.text += "\n"
		_history_label.text += visible_history[i]

	var stage: String = snapshot.get("stage", "preflop")
	var check_call_action := -1
	var call_amount := 0
	var wager_action := -1
	var wager_min := 1
	var wager_max := 1
	for option in snapshot.get("available_actions", []):
		var action: int = option.get("action", -1)
		if action == PokerBetting.Action.CHECK or action == PokerBetting.Action.CALL:
			check_call_action = action
			call_amount = option.get("amount", 0)
		elif action == PokerBetting.Action.BET or action == PokerBetting.Action.RAISE:
			wager_action = action
			wager_min = option.get("min_amount", 1)
			wager_max = option.get("max_amount", wager_min)
	var player_turn := current_actor == 0
	_fold_button.disabled = not player_turn
	_call_button.disabled = not player_turn or check_call_action < 0
	_call_button.text = "Check" if check_call_action == PokerBetting.Action.CHECK else "Call  %s" % _format_amount(call_amount)
	_call_button.set_meta("poker_action", check_call_action)
	_wager_button.disabled = not player_turn or wager_action < 0
	_wager_button.set_meta("poker_action", wager_action)
	_wager_button.set_meta("action_name", "Bet" if wager_action == PokerBetting.Action.BET else "Raise")
	_amount_input.min_value = wager_min
	_amount_input.max_value = maxi(wager_min, wager_max)
	_amount_input.value = wager_min
	_amount_input.editable = player_turn and wager_action >= 0
	_wager_range.text = "TARGET %s–%s" % [_format_amount(wager_min), _format_amount(wager_max)] if wager_action >= 0 else ""
	_update_wager_label(_amount_input.value)
	_next_hand_button.visible = stage == "showdown"

func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 34)
	for side in ["top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 20)
	add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margins.add_child(layout)
	var title := _label("DEVIL'S DRAW   ·   THE RUSTY SPUR", 24, PARCHMENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var opponent_panel := _make_seat_panel(false)
	layout.add_child(opponent_panel)
	var felt := _panel(FELT, BRASS)
	felt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(felt)
	var felt_style := felt.get_theme_stylebox("panel") as StyleBoxFlat
	felt_style.content_margin_left = 14
	felt_style.content_margin_right = 14
	felt_style.content_margin_top = 14
	felt_style.content_margin_bottom = 14
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 7)
	felt.add_child(center)

	_turn_label = _label("YOUR TURN", 14, PARCHMENT)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_centered(_turn_label))
	_pot_label = _label("POT  0", 20, PAPER)
	_pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_centered(_pot_label))
	var board_row := HBoxContainer.new()
	board_row.alignment = BoxContainer.ALIGNMENT_CENTER
	board_row.add_theme_constant_override("separation", 8)
	center.add_child(board_row)
	for i in range(5):
		var card := PokerCardView.new()
		board_row.add_child(card)
		_board_cards.append(card)
	_message_label = _label("A seat is waiting for you.", 16, PARCHMENT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_centered(_message_label))
	_history_label = _label("", 12, MUTED)
	_history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_centered(_history_label))

	var player_panel := _make_seat_panel(true)
	layout.add_child(player_panel)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)
	_fold_button = _action_button("Fold", Color("#62352A"))
	_fold_button.pressed.connect(func(): player_action_requested.emit(PokerBetting.Action.FOLD, 0))
	controls.add_child(_fold_button)
	_call_button = _action_button("Check", Color("#344B3C"))
	_call_button.pressed.connect(_emit_check_call)
	controls.add_child(_call_button)
	_amount_input = SpinBox.new()
	_amount_input.custom_minimum_size = Vector2(100, 42)
	_amount_input.min_value = 1
	_amount_input.max_value = 1000
	_amount_input.step = 10
	_amount_input.prefix = "to "
	_amount_input.value_changed.connect(_update_wager_label)
	controls.add_child(_amount_input)
	_wager_button = _action_button("Bet to 1", Color("#75603C"))
	_wager_button.pressed.connect(_emit_wager)
	controls.add_child(_wager_button)
	_wager_range = _label("", 11, MUTED)
	controls.add_child(_wager_range)
	_next_hand_button = _action_button("Next hand", Color("#344B3C"))
	_next_hand_button.pressed.connect(func(): next_hand_requested.emit())
	_next_hand_button.visible = false
	layout.add_child(_centered(_next_hand_button))

func _make_seat_panel(is_player: bool) -> PanelContainer:
	var panel := _panel(WOOD, Color("#715C3B"))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(_margin_box(content, 10))
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 2)
	content.add_child(identity)
	var name_label := _label("", 17, PAPER)
	identity.add_child(name_label)
	var role_label := _label("", 11, PARCHMENT)
	identity.add_child(role_label)
	var stack_label := _label("STACK  0", 15, PAPER)
	identity.add_child(stack_label)
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 5)
	content.add_child(cards_row)
	var views: Array[PokerCardView] = []
	for i in range(2):
		var card := PokerCardView.new()
		cards_row.add_child(card)
		views.append(card)
	if is_player:
		_player_name = name_label
		_player_role = role_label
		_player_stack = stack_label
		_player_cards = views
	else:
		_opponent_name = name_label
		_opponent_role = role_label
		_opponent_stack = stack_label
		_opponent_cards = views
	return panel

func _update_card_row(views: Array[PokerCardView], cards: Array, hidden_cards_use_back: bool = true) -> void:
	for i in range(views.size()):
		if i < cards.size():
			views[i].show_face(str(cards[i]))
		elif hidden_cards_use_back:
			views[i].show_back()
		else:
			views[i].show_empty()

func _emit_check_call() -> void:
	var action: int = _call_button.get_meta("poker_action", -1)
	if action >= 0:
		player_action_requested.emit(action, 0)

func _emit_wager() -> void:
	var action: int = _wager_button.get_meta("poker_action", -1)
	if action >= 0:
		player_action_requested.emit(action, int(_amount_input.value))

func _update_wager_label(value: float) -> void:
	if _wager_button == null:
		return
	var action_name: String = _wager_button.get_meta("action_name", "Bet")
	_wager_button.text = "%s to %s" % [action_name, _format_amount(int(value))]

func _format_amount(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	for i in range(digits.length()):
		formatted += digits.substr(i, 1)
		var remaining := digits.length() - i - 1
		if remaining > 0 and remaining % 3 == 0:
			formatted += ","
	return formatted

func _action_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(112, 42)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = BRASS
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.14)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover.duplicate())
	button.add_theme_stylebox_override("focus", hover.duplicate())
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel(background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _margin_box(child: Control, amount: int) -> MarginContainer:
	var wrapper := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		wrapper.add_theme_constant_override("margin_" + side, amount)
	wrapper.add_child(child)
	return wrapper

func _centered(child: Control) -> CenterContainer:
	var wrapper := CenterContainer.new()
	wrapper.add_child(child)
	return wrapper
