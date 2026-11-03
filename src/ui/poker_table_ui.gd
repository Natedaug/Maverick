class_name PokerTableUI
extends Control
## Small, responsive first-pass saloon table interface.

signal player_action_requested(action: int, target: int)
signal next_hand_requested

var _player_label: Label
var _opponent_label: Label
var _board_label: Label
var _pot_label: Label
var _message_label: Label
var _fold_button: Button
var _check_call_button: Button
var _wager_button: Button
var _next_hand_button: Button
var _amount_input: SpinBox

func _ready() -> void:
	_build_interface()

func render(snapshot: Dictionary, message: String) -> void:
	var seats: Array = snapshot.get("seats", [])
	if seats.size() < 2:
		return
	var player: Dictionary = seats[0]
	var opponent: Dictionary = seats[1]
	_player_label.text = "YOU     %s chips\n%s" % [str(player.get("stack", 0)), _format_cards(player.get("cards", []))]
	var opponent_cards: Array = opponent.get("cards", [])
	var opponent_hand := _format_cards(opponent_cards) if not opponent_cards.is_empty() else "[ hidden ]   [ hidden ]"
	_opponent_label.text = "THE DRIFTER     %s chips\n%s" % [str(opponent.get("stack", 0)), opponent_hand]
	_board_label.text = _format_cards(snapshot.get("board", []), "   ")
	if _board_label.text.is_empty():
		_board_label.text = "—   —   —   —   —"
	_pot_label.text = "POT     %s" % str(snapshot.get("pot", 0))
	_message_label.text = message

	var is_player_turn: bool = snapshot.get("current_actor", -1) == 0
	var stage: String = snapshot.get("stage", "preflop")
	var check_call_action := -1
	var wager_action := -1
	var wager_min := 1
	var wager_max := 1
	for option in snapshot.get("available_actions", []):
		var action: int = option.get("action", -1)
		if action == PokerBetting.Action.CHECK or action == PokerBetting.Action.CALL:
			check_call_action = action
		elif action == PokerBetting.Action.BET or action == PokerBetting.Action.RAISE:
			wager_action = action
			wager_min = option.get("min_amount", 1)
			wager_max = option.get("max_amount", wager_min)
	_fold_button.disabled = not is_player_turn
	_check_call_button.disabled = not is_player_turn or check_call_action < 0
	_check_call_button.text = "Check" if check_call_action == PokerBetting.Action.CHECK else "Call"
	_wager_button.disabled = not is_player_turn or wager_action < 0
	_wager_button.text = "Bet" if wager_action == PokerBetting.Action.BET else "Raise"
	_amount_input.min_value = wager_min
	_amount_input.max_value = maxi(wager_min, wager_max)
	_amount_input.value = wager_min
	_amount_input.editable = is_player_turn and wager_action >= 0
	_wager_button.set_meta("poker_action", wager_action)
	_check_call_button.set_meta("poker_action", check_call_action)
	_next_hand_button.visible = stage == "showdown"

func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#171612")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 36)
	margins.add_theme_constant_override("margin_right", 36)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_bottom", 24)
	add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margins.add_child(layout)

	var title := _label("DEVIL'S DRAW     ·     THE RUSTY SPUR", 27, Color("#f0d7a1"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var opponent_panel := _panel(Color("#29241b"), Color("#715c3b"))
	layout.add_child(opponent_panel)
	_opponent_label = _label("THE DRIFTER", 20, Color("#eee5d2"))
	_opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_panel.add_child(_padded(_opponent_label, 12))

	var felt := _panel(Color("#174a3a"), Color("#bd9655"))
	felt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(felt)
	var felt_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		felt_margin.add_theme_constant_override("margin_" + side, 24)
	felt.add_child(felt_margin)
	var table_content := VBoxContainer.new()
	table_content.add_theme_constant_override("separation", 12)
	table_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	felt_margin.add_child(table_content)

	_pot_label = _label("POT     0", 22, Color("#f2d28f"))
	_pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_content.add_child(_centered(_pot_label))
	_board_label = _label("—   —   —   —   —", 31, Color("#fff9e9"))
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_content.add_child(_centered(_board_label))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_content.add_child(spacer)

	_message_label = _label("A seat is waiting for you.", 17, Color("#f0d7a1"))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_content.add_child(_centered(_message_label))

	_player_label = _label("YOU", 20, Color("#eee5d2"))
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_player_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	layout.add_child(controls)
	_fold_button = _button("Fold")
	_fold_button.pressed.connect(func(): player_action_requested.emit(PokerBetting.Action.FOLD, 0))
	controls.add_child(_fold_button)
	_check_call_button = _button("Check")
	_check_call_button.pressed.connect(_emit_check_call)
	controls.add_child(_check_call_button)
	_amount_input = SpinBox.new()
	_amount_input.custom_minimum_size.x = 110
	_amount_input.min_value = 1
	_amount_input.max_value = 1000
	_amount_input.step = 10
	controls.add_child(_amount_input)
	_wager_button = _button("Bet")
	_wager_button.pressed.connect(_emit_wager)
	controls.add_child(_wager_button)
	_next_hand_button = _button("Next hand")
	_next_hand_button.pressed.connect(func(): next_hand_requested.emit())
	_next_hand_button.visible = false
	layout.add_child(_centered(_next_hand_button))

func _emit_check_call() -> void:
	var action: int = _check_call_button.get_meta("poker_action", -1)
	if action >= 0:
		player_action_requested.emit(action, 0)

func _emit_wager() -> void:
	var action: int = _wager_button.get_meta("poker_action", -1)
	if action >= 0:
		player_action_requested.emit(action, int(_amount_input.value))

func _format_cards(cards: Array, separator: String = "   ") -> String:
	var displayed: Array[String] = []
	for code in cards:
		var value: String = str(code)
		if value.length() < 2:
			continue
		var rank := value.substr(0, value.length() - 1)
		var suit := value.substr(value.length() - 1, 1)
		if rank == "T":
			rank = "10"
		var symbols := {"s": "♠", "h": "♥", "d": "♦", "c": "♣"}
		displayed.append("[%s%s]" % [rank, symbols.get(suit, suit)])
	return separator.join(displayed)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(100, 44)
	return button

func _panel(background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _padded(child: Control, amount: int) -> MarginContainer:
	var wrapper := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		wrapper.add_theme_constant_override("margin_" + side, amount)
	wrapper.add_child(child)
	return wrapper

func _centered(child: Control) -> CenterContainer:
	var wrapper := CenterContainer.new()
	wrapper.add_child(child)
	return wrapper
