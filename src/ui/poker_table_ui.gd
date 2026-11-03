class_name PokerTableUI
extends Control
## Responsive saloon table presentation. Poker legality stays in the engine.

@export var sound_enabled := true
@export var reduced_motion := false
@export_range(-36.0, 0.0, 1.0) var sound_volume_db := -18.0

signal player_action_requested(action: int, target: int)
signal next_hand_requested
signal buy_in_requested(chips: int)
signal leave_table_requested
signal save_requested
signal load_requested

const INK := Color("#171612")
const WOOD := Color("#29241B")
const FELT := Color("#174A3A")
const BRASS := Color("#BD9655")
const PARCHMENT := Color("#F0D7A1")
const PAPER := Color("#FFF9E9")
const MUTED := Color("#D1C8B7")
const CHIP_RED := Color("#A74336")

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
var _pot_row: HBoxContainer
var _shared_info_row: HBoxContainer
var _turn_label: Label
var _message_label: Label
var _history_label: Label
var _status_label: Label
var _call_button: Button
var _wager_button: Button
var _fold_button: Button
var _next_hand_button: Button
var _wager_slider: HSlider
var _wager_range: Label
var _target_label: Label
var _preset_buttons: Array[Button] = []
var _preset_grid: GridContainer
var _action_grid: GridContainer
var _controls: VBoxContainer
var _content: VBoxContainer
var _table_scroll: ScrollContainer
var _buyin_panel: PanelContainer
var _player_panel: PanelContainer
var _buyin_amount: SpinBox
var _buyin_button: Button
var _buyin_status: Label
var _settings_status_label: Label
var _pause_button: Button
var _settings_overlay: Control
var _settings_panel: PanelContainer
var _settings_sound_toggle: Button
var _settings_motion_toggle: Button
var _settings_leave_button: Button
var _outer_margins: MarginContainer
var _title: Label
var _felt_panel: PanelContainer
var _felt_content_style: StyleBoxFlat
var _center_content: VBoxContainer
var _board_grid: GridContainer
var _seat_padding: Array[MarginContainer] = []
var _seat_grids: Array[GridContainer] = []
var _chip_piles: Array[Control] = []
var _pot_amount := 0
var _player_commitment := 0
var _wager_min := 1
var _wager_max := 1
var _wager_unit := 1
var _wager_action := -1
var _call_action := -1
var _current_actor := -1
var _last_world_status: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _effects_layer: Control
var _sound_streams: Dictionary = {}

func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func render(snapshot: Dictionary = {}, message: String = "", history: Array[String] = [], world_status: Dictionary = {}) -> void:
	var previous_snapshot := _last_snapshot.duplicate(true)
	_last_world_status = world_status
	_buyin_status.text = _world_summary(world_status)
	var seats: Array = snapshot.get("seats", [])
	var seated := not snapshot.is_empty() and seats.size() >= 2
	_table_scroll.visible = seated
	_player_panel.visible = seated
	_controls.visible = seated
	_status_label.visible = seated
	_buyin_panel.visible = not seated
	_settings_leave_button.disabled = not bool(world_status.get("session_active", false))
	_settings_leave_button.visible = bool(world_status.get("session_active", false))
	if not seated:
		var wallet := int(world_status.get("wallet_balance", 0))
		var rate := float(world_status.get("wallet_units_per_chip", 1.0))
		var affordable_chips := int(floor(float(wallet) / rate)) if rate > 0.0 else 0
		_buyin_amount.max_value = maxf(1.0, float(affordable_chips))
		var default_buy_in := int(world_status.get("buy_in_chips", 1000))
		_buyin_amount.value = clampi(default_buy_in, 1, int(_buyin_amount.max_value))
		_buyin_button.disabled = rate <= 0.0 or wallet < int(ceil(_buyin_amount.value * rate))
		_last_snapshot.clear()
		return

	var player: Dictionary = seats[0]
	var opponent: Dictionary = seats[1]
	_player_commitment = int(player.get("street_commitment", 0))
	var button_seat: int = snapshot.get("button", 0)
	_current_actor = int(snapshot.get("current_actor", -1))
	if _current_actor == 0 and int(previous_snapshot.get("current_actor", -1)) != 0:
		_play_feedback_sound("turn")
	_player_name.text = str(player.get("name", "YOU"))
	_opponent_name.text = str(opponent.get("name", "THE DRIFTER"))
	_player_role.text = _seat_role(0, button_seat, _current_actor, player)
	_opponent_role.text = _seat_role(1, button_seat, _current_actor, opponent)
	# Milestone 3 tell: the rival's recent decision rhythm (never its cards).
	var rival_label := str(world_status.get("rival_label", ""))
	if not rival_label.is_empty():
		_opponent_role.text += "  ·  %s" % rival_label.to_upper()
	_player_stack.text = "STACK  %s" % _format_amount(int(player.get("stack", 0)))
	_opponent_stack.text = "STACK  %s" % _format_amount(int(opponent.get("stack", 0)))
	_set_chip_pile(_chip_piles[0], int(opponent.get("stack", 0)))
	_set_chip_pile(_chip_piles[2], int(player.get("stack", 0)))
	_update_card_row(_player_cards, player.get("cards", []))
	_update_card_row(_opponent_cards, opponent.get("cards", []))
	_update_card_row(_board_cards, snapshot.get("board", []), false)
	_animate_changed_cards(previous_snapshot, snapshot)
	_pot_amount = int(snapshot.get("pot", 0))
	_pot_label.text = "POT  %s" % _format_amount(_pot_amount)
	_set_chip_pile(_chip_piles[1], _pot_amount)
	_turn_label.text = "YOUR TURN" if _current_actor == 0 else "%s IS ACTING" % _opponent_name.text if _current_actor == 1 else "HAND COMPLETE"
	_message_label.text = message if not message.is_empty() else ("Choose an action." if _current_actor == 0 else "Watch the table.")
	_history_label.text = "  ·  ".join(history.slice(maxi(0, history.size() - 3), history.size()))
	_status_label.text = _world_summary(world_status)
	_settings_status_label.text = _world_summary(world_status)
	_configure_actions(snapshot)
	_apply_responsive_layout()
	_animate_chip_state_change(previous_snapshot, snapshot)
	_last_snapshot = snapshot.duplicate(true)

func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_outer_margins = MarginContainer.new()
	_outer_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_outer_margins)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 7)
	_outer_margins.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	_title = _label("DEVIL'S DRAW  ·  THE RUSTY SPUR", 28, PARCHMENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_pause_button = _action_button("Pause / Settings", Color("#484236"))
	_pause_button.custom_minimum_size = Vector2(170, 46)
	_pause_button.pressed.connect(func(): _settings_overlay.visible = true)
	header.add_child(_pause_button)
	_buyin_panel = _panel(WOOD, BRASS)
	_buyin_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_buyin_panel)
	_build_buyin_panel()
	_table_scroll = ScrollContainer.new()
	_table_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_table_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_table_scroll.add_child(_content)
	_content.add_child(_make_seat_panel(false))
	_felt_panel = _panel(FELT, BRASS)
	_felt_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_felt_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_felt_panel)
	_felt_content_style = _felt_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_center_content = VBoxContainer.new()
	_center_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_content.add_theme_constant_override("separation", 7)
	_felt_panel.add_child(_center_content)
	_turn_label = _label("YOUR TURN", 18, PARCHMENT)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_content.add_child(_turn_label)
	_pot_row = HBoxContainer.new()
	_pot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pot_row.add_theme_constant_override("separation", 10)
	_center_content.add_child(_pot_row)
	_add_chip_pile(_pot_row)
	_pot_label = _label("POT  0", 26, PAPER)
	_pot_row.add_child(_pot_label)
	_board_grid = GridContainer.new()
	_board_grid.columns = 5
	_board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_grid.add_theme_constant_override("h_separation", 8)
	_board_grid.add_theme_constant_override("v_separation", 8)
	_center_content.add_child(_centered(_board_grid))
	for i in range(5):
		var card := PokerCardView.new()
		_board_grid.add_child(card)
		_board_cards.append(card)
	_message_label = _label("A seat is waiting for you.", 19, PARCHMENT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_content.add_child(_centered(_message_label))
	_history_label = _label("", 16, MUTED)
	_history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center_content.add_child(_centered(_history_label))
	_center_content.remove_child(_turn_label)
	_center_content.remove_child(_pot_row)
	_shared_info_row = HBoxContainer.new()
	_shared_info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_shared_info_row.add_theme_constant_override("separation", 14)
	root.add_child(_shared_info_row)
	_shared_info_row.add_child(_turn_label)
	_shared_info_row.add_child(_pot_row)
	_player_panel = _make_seat_panel(true)
	root.add_child(_player_panel)
	_status_label = _label("", 16, MUTED)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)
	_controls = VBoxContainer.new()
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls.add_theme_constant_override("separation", 5)
	root.add_child(_controls)
	_build_action_dock()
	_effects_layer = Control.new()
	_effects_layer.name = "FeedbackEffects"
	_effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_layer.z_index = 20
	add_child(_effects_layer)
	_build_settings_overlay()

func _build_buyin_panel() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_buyin_panel.add_child(box)
	var heading := _label("TAKE A SEAT", 30, PARCHMENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var body := _label("Choose your stake before the next hand is dealt.", 19, PAPER)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	_buyin_status = _label("Wallet and town standing will appear here.", 17, MUTED)
	_buyin_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_buyin_status)
	_buyin_amount = SpinBox.new()
	_buyin_amount.min_value = 1
	_buyin_amount.max_value = 10000
	_buyin_amount.value = 1000
	_buyin_amount.step = 1
	_buyin_amount.custom_minimum_size = Vector2(180, 48)
	_buyin_amount.prefix = "Buy-in  "
	_buyin_amount.value_changed.connect(func(_value: float): _update_buy_in_validity())
	box.add_child(_centered(_buyin_amount))
	_buyin_button = _action_button("Buy in", Color("#344B3C"))
	_buyin_button.custom_minimum_size = Vector2(220, 52)
	_buyin_button.pressed.connect(func(): buy_in_requested.emit(int(_buyin_amount.value)))
	box.add_child(_centered(_buyin_button))

func _build_action_dock() -> void:
	var sizing := VBoxContainer.new()
	sizing.add_theme_constant_override("separation", 4)
	_controls.add_child(sizing)
	_target_label = _label("BET TO 1", 22, PAPER)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sizing.add_child(_target_label)
	var bounds_row := HBoxContainer.new()
	sizing.add_child(bounds_row)
	_wager_range = _label("MIN 1", 16, MUTED)
	bounds_row.add_child(_wager_range)
	_wager_slider = HSlider.new()
	_wager_slider.name = "WagerSlider"
	_wager_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wager_slider.min_value = 1
	_wager_slider.max_value = 1
	_wager_slider.step = 1
	_wager_slider.focus_mode = Control.FOCUS_ALL
	_wager_slider.value_changed.connect(_on_slider_changed)
	_wager_slider.gui_input.connect(_on_slider_gui_input)
	bounds_row.add_child(_wager_slider)
	var plus := _action_button("−", Color("#484236"))
	plus.custom_minimum_size = Vector2(48, 44)
	plus.pressed.connect(func(): _step_wager(-1))
	bounds_row.add_child(plus)
	var minus := _action_button("+", Color("#484236"))
	minus.custom_minimum_size = Vector2(48, 44)
	minus.pressed.connect(func(): _step_wager(1))
	bounds_row.add_child(minus)
	var max_label := _label("MAX 1", 16, MUTED)
	bounds_row.add_child(max_label)
	_wager_range.set_meta("max_label", max_label)
	_preset_grid = GridContainer.new()
	_preset_grid.columns = 6
	_preset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_grid.add_theme_constant_override("h_separation", 5)
	_preset_grid.add_theme_constant_override("v_separation", 4)
	sizing.add_child(_preset_grid)
	var names := ["¼ POT", "⅓ POT", "½ POT", "¾ POT", "POT", "ALL-IN"]
	var fractions := [0.25, 0.333333, 0.5, 0.75, 1.0, -1.0]
	for i in range(names.size()):
		var button := _action_button(names[i], Color("#484236"))
		button.custom_minimum_size = Vector2(82, 44)
		button.set_meta("pot_fraction", fractions[i])
		button.pressed.connect(_on_preset_pressed.bind(button))
		_preset_grid.add_child(button)
		_preset_buttons.append(button)
	_action_grid = GridContainer.new()
	_action_grid.columns = 3
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", 6)
	_action_grid.add_theme_constant_override("v_separation", 5)
	_controls.add_child(_action_grid)
	_fold_button = _action_button("Fold", Color("#62352A"))
	_fold_button.name = "FoldButton"
	_fold_button.custom_minimum_size = Vector2(110, 48)
	_fold_button.pressed.connect(func(): player_action_requested.emit(PokerBetting.Action.FOLD, 0))
	_action_grid.add_child(_fold_button)
	_call_button = _action_button("Check", Color("#344B3C"))
	_call_button.name = "CallCheckButton"
	_call_button.custom_minimum_size = Vector2(140, 48)
	_call_button.pressed.connect(_emit_check_call)
	_action_grid.add_child(_call_button)
	_wager_button = _action_button("Bet to 1", Color("#75603C"))
	_wager_button.name = "WagerButton"
	_wager_button.custom_minimum_size = Vector2(170, 48)
	_wager_button.pressed.connect(_emit_wager)
	_action_grid.add_child(_wager_button)
	_next_hand_button = _action_button("Next hand", Color("#344B3C"))
	_next_hand_button.custom_minimum_size = Vector2(170, 48)
	_next_hand_button.pressed.connect(func(): next_hand_requested.emit())
	_next_hand_button.visible = false
	_action_grid.add_child(_next_hand_button)

func _build_settings_overlay() -> void:
	_settings_overlay = Control.new()
	_settings_overlay.name = "PauseSettingsOverlay"
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.z_index = 40
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.visible = false
	add_child(_settings_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.035, 0.025, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_overlay.add_child(center)
	var panel := _panel(WOOD, BRASS)
	_settings_panel = _panel(WOOD, BRASS)
	_settings_panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(_settings_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var margins := _margin_box(content, 18)
	_settings_panel.add_child(margins)
	var heading := _label("PAUSE / SETTINGS", 26, PARCHMENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var explanation := _label("Finish the hand before saving or loading. Closing the table returns your remaining chips to your wallet.", 18, PAPER)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(explanation)
	_settings_status_label = _label("", 16, MUTED)
	_settings_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_settings_status_label)
	var save_progress := _action_button("Save Progress", Color("#484236"))
	save_progress.custom_minimum_size = Vector2(250, 48)
	save_progress.pressed.connect(func():
		_settings_overlay.hide()
		save_requested.emit())
	content.add_child(_centered(save_progress))
	var load_progress := _action_button("Load Progress", Color("#484236"))
	load_progress.custom_minimum_size = Vector2(250, 48)
	load_progress.pressed.connect(func():
		_settings_overlay.hide()
		load_requested.emit())
	content.add_child(_centered(load_progress))
	_settings_sound_toggle = _action_button("Mute sound", Color("#484236"))
	_settings_sound_toggle.toggle_mode = true
	_settings_sound_toggle.button_pressed = not sound_enabled
	_settings_sound_toggle.toggled.connect(_on_sound_toggled)
	content.add_child(_centered(_settings_sound_toggle))
	_settings_motion_toggle = _action_button("Reduced motion", Color("#484236"))
	_settings_motion_toggle.toggle_mode = true
	_settings_motion_toggle.button_pressed = reduced_motion
	_settings_motion_toggle.toggled.connect(_on_motion_toggled)
	content.add_child(_centered(_settings_motion_toggle))
	_settings_leave_button = _action_button("Leave Table", Color("#62352A"))
	_settings_leave_button.pressed.connect(func():
		_settings_overlay.hide()
		leave_table_requested.emit())
	content.add_child(_centered(_settings_leave_button))
	var resume := _action_button("Resume Hand", Color("#344B3C"))
	resume.pressed.connect(func(): _settings_overlay.hide())
	content.add_child(_centered(resume))

func _apply_responsive_layout() -> void:
	if _outer_margins == null:
		return
	var narrow := size.x < 640.0
	var compact := size.x < 900.0 or size.y < 700.0
	var very_short := size.y < 560.0
	var margin := 8 if narrow else 16 if compact else 28
	for side in ["left", "right"]:
		_outer_margins.add_theme_constant_override("margin_" + side, margin)
	_outer_margins.add_theme_constant_override("margin_top", 4 if very_short else 8 if compact else 16)
	_outer_margins.add_theme_constant_override("margin_bottom", 4 if very_short else 8 if compact else 16)
	_title.text = "DEVIL'S DRAW\nTHE RUSTY SPUR" if narrow else "DEVIL'S DRAW  ·  THE RUSTY SPUR"
	_title.add_theme_font_size_override("font_size", 20 if narrow else 25 if compact else 29)
	_pause_button.text = "Settings" if narrow else "Pause / Settings"
	_pause_button.custom_minimum_size = Vector2(100 if narrow else 170, 46)
	_settings_panel.custom_minimum_size.x = clampf(size.x - 32.0, 280.0, 420.0)
	_preset_grid.columns = 3 if narrow else 6
	_action_grid.columns = 2 if narrow else 3
	_board_grid.columns = 3 if narrow else 5
	for button in [_fold_button, _call_button, _wager_button, _next_hand_button]:
		button.custom_minimum_size.x = 140 if narrow else 170 if button == _wager_button else 140
	for preset in _preset_buttons:
		preset.custom_minimum_size.x = 98 if narrow else 82
	for padding in _seat_padding:
		var inset := 4 if narrow else 9 if compact else 14
		for side in ["left", "right", "top", "bottom"]:
			padding.add_theme_constant_override("margin_" + side, inset)
	for seat_grid in _seat_grids:
		seat_grid.columns = 1 if narrow else 2
		seat_grid.add_theme_constant_override("h_separation", 8 if narrow else 12)
		seat_grid.add_theme_constant_override("v_separation", 5)
	_felt_content_style.content_margin_left = 8 if narrow else 14
	_felt_content_style.content_margin_right = 8 if narrow else 14
	_felt_content_style.content_margin_top = 6 if compact else 14
	_felt_content_style.content_margin_bottom = 6 if compact else 14
	_center_content.add_theme_constant_override("separation", 3 if very_short else 6 if compact else 10)
	_turn_label.add_theme_font_size_override("font_size", 16 if compact else 19)
	_pot_label.add_theme_font_size_override("font_size", 23 if compact else 27)
	_message_label.add_theme_font_size_override("font_size", 18)
	_history_label.visible = not narrow and not very_short
	_status_label.add_theme_font_size_override("font_size", 16)
	_content.add_theme_constant_override("separation", 5 if compact else 9)
	var hole_card_size := Vector2(68, 96) if narrow else Vector2(82, 116) if compact else Vector2(92, 132)
	var hole_rank_size := 25 if narrow else 29 if compact else 32
	var hole_suit_size := 31 if narrow else 36 if compact else 40
	var hole_corner_size := 13 if narrow else 15 if compact else 16
	for card in _player_cards + _opponent_cards:
		card.set_card_size(hole_card_size, hole_rank_size, hole_suit_size, hole_corner_size)
	var board_card_size := Vector2(58, 82) if narrow else Vector2(70, 100) if compact else Vector2(76, 108)
	var board_rank_size := 24 if narrow else 26 if compact else 28
	var board_suit_size := 29 if narrow else 32 if compact else 34
	var board_corner_size := 13 if narrow else 14
	for card in _board_cards:
		card.set_card_size(board_card_size, board_rank_size, board_suit_size, board_corner_size)
	for pile_index in [0, 2]:
		_chip_piles[pile_index].custom_minimum_size.x = 44 if narrow else 54
	for label in [_player_name, _opponent_name]:
		label.add_theme_font_size_override("font_size", 21 if narrow else 24)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [_player_role, _opponent_role]:
		label.add_theme_font_size_override("font_size", 15 if narrow else 16)
	for label in [_player_stack, _opponent_stack]:
		label.add_theme_font_size_override("font_size", 20 if narrow else 23)
	_wager_slider.custom_minimum_size.y = 34 if narrow else 28
	_wager_range.add_theme_font_size_override("font_size", 15)
	if _buyin_panel != null:
		_buyin_panel.custom_minimum_size.y = maxf(280.0, size.y - 100.0)

func _make_seat_panel(is_player: bool) -> PanelContainer:
	var panel := _panel(WOOD, Color("#715C3B"))
	panel.name = "PlayerSeatPanel" if is_player else "OpponentSeatPanel"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margins := _margin_box(grid, 10)
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(margins)
	_seat_padding.append(margins)
	_seat_grids.append(grid)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 8)
	var pile := _new_chip_pile()
	identity_row.add_child(pile)
	_chip_piles.append(pile)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 2)
	var name_label := _label("", 24, PAPER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(name_label)
	var role_label := _label("", 16, PARCHMENT)
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(role_label)
	var stack_label := _label("STACK  0", 23, PAPER)
	identity.add_child(stack_label)
	grid.add_child(identity_row)
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 5)
	grid.add_child(cards_row)
	var views: Array[PokerCardView] = []
	for i in range(2):
		var card := PokerCardView.new()
		card.name = ("PlayerHoleCard" if is_player else "OpponentHoleCard") + str(i + 1)
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

func _configure_actions(snapshot: Dictionary) -> void:
	_call_action = -1
	_wager_action = -1
	var call_amount := 0
	_wager_min = 1
	_wager_max = 1
	for option in snapshot.get("available_actions", []):
		var action := int(option.get("action", -1))
		if action == PokerBetting.Action.CHECK or action == PokerBetting.Action.CALL:
			_call_action = action
			call_amount = int(option.get("amount", 0))
		elif action == PokerBetting.Action.BET or action == PokerBetting.Action.RAISE:
			_wager_action = action
			_wager_min = int(option.get("min_amount", 1))
			_wager_max = int(option.get("max_amount", _wager_min))
	_wager_max = maxi(_wager_min, _wager_max)
	_wager_unit = maxi(1, int(snapshot.get("legal_wager_unit", 1)))
	var player_turn := _current_actor == 0
	var complete := str(snapshot.get("stage", "")) == "showdown"
	_fold_button.visible = not complete
	_fold_button.disabled = not player_turn
	_call_button.visible = not complete
	_call_button.disabled = not player_turn or _call_action < 0
	_call_button.text = "Check" if _call_action == PokerBetting.Action.CHECK else "Call %s" % _format_amount(call_amount)
	_call_button.set_meta("poker_action", _call_action)
	_call_button.set_meta("call_amount", call_amount)
	_wager_button.visible = not complete
	_wager_button.disabled = not player_turn or _wager_action < 0
	_wager_button.set_meta("poker_action", _wager_action)
	_wager_button.set_meta("action_name", "Bet" if _wager_action == PokerBetting.Action.BET else "Raise")
	_wager_slider.visible = not complete
	_wager_range.visible = not complete
	_wager_slider.min_value = _wager_min
	_wager_slider.max_value = _wager_max
	_wager_slider.step = 1
	_wager_slider.editable = player_turn and _wager_action >= 0
	_wager_slider.value = clampi(int(_wager_slider.value), _wager_min, _wager_max)
	_wager_range.text = "MIN %s" % _format_amount(_wager_min)
	(_wager_range.get_meta("max_label") as Label).text = "MAX %s" % _format_amount(_wager_max)
	for preset in _preset_buttons:
		preset.disabled = not player_turn or _wager_action < 0
	_next_hand_button.visible = complete
	_update_wager_label(_wager_slider.value)

func _on_slider_changed(value: float) -> void:
	_update_wager_label(value)

func _on_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var span := _wager_slider.max_value - _wager_slider.min_value
		var ratio := 0.0 if _wager_slider.size.x <= 0.0 or span <= 0.0 else clampf((_wager_slider.value - _wager_slider.min_value) / span, 0.0, 1.0)
		var thumb_x := ratio * _wager_slider.size.x
		if absf(event.position.x - thumb_x) > 16.0:
			_step_wager(1 if event.position.x > thumb_x else -1)
			_wager_slider.accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT or event.keycode == KEY_UP:
			_step_wager(1)
			_wager_slider.accept_event()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_DOWN:
			_step_wager(-1)
			_wager_slider.accept_event()

func _step_wager(direction: int) -> void:
	if _wager_action < 0:
		return
	_wager_slider.value = clampi(int(_wager_slider.value) + direction * _wager_unit, _wager_min, _wager_max)

func _on_preset_pressed(button: Button) -> void:
	var fraction := float(button.get_meta("pot_fraction", 0.5))
	var target := _wager_max
	if fraction >= 0.0:
		target = int(round(float(_pot_amount) * fraction))
		if _wager_action == PokerBetting.Action.RAISE:
			var call_amount := int(_call_button.get_meta("call_amount", 0))
			target = _player_commitment + call_amount + int(round(float(_pot_amount + call_amount) * fraction))
		# Presets use conventional pot fractions, then snap and clamp to engine bounds.
		target = _wager_min + int(round(float(target - _wager_min) / float(_wager_unit))) * _wager_unit
	_wager_slider.value = clampi(target, _wager_min, _wager_max)

func _emit_check_call() -> void:
	if _call_action >= 0:
		player_action_requested.emit(_call_action, 0)

func _emit_wager() -> void:
	if _wager_action >= 0:
		player_action_requested.emit(_wager_action, int(_wager_slider.value))

func _update_wager_label(value: float) -> void:
	if _wager_button == null:
		return
	var action_name := "Bet" if _wager_action == PokerBetting.Action.BET else "Raise"
	var target := int(value)
	_wager_button.text = "%s to %s" % [action_name, _format_amount(target)]
	_target_label.text = "%s TO %s" % [action_name.to_upper(), _format_amount(target)]

func _seat_role(index: int, button_seat: int, actor: int, player: Dictionary) -> String:
	var role := "DEALER · SMALL BLIND" if index == button_seat else "BIG BLIND"
	if actor == index:
		role += "  ·  ACTING NOW"
	if player.get("all_in", false):
		role += "  ·  ALL IN"
	return role

func _world_summary(status: Dictionary) -> String:
	var session := "SESSION ACTIVE" if status.get("session_active", false) else "NO SESSION"
	return "WALLET %s   ·   %s   ·   REP %s   ·   TABLE %s   ·   %s" % [
		_format_amount(int(status.get("wallet_balance", 0))),
	str(status.get("town_state", "Devil's Draw")),
	str(status.get("reputation", "—")),
	str(status.get("poker_volume", "—")),
	session]

func _update_card_row(views: Array[PokerCardView], cards: Array, hidden_cards_use_back: bool = true) -> void:
	for i in range(views.size()):
		if i < cards.size():
			views[i].show_face(str(cards[i]))
		elif hidden_cards_use_back:
			views[i].show_back()
		else:
			views[i].show_empty()

func _animate_changed_cards(previous: Dictionary, current: Dictionary) -> void:
	var prior_seats: Array = previous.get("seats", [])
	var seats: Array = current.get("seats", [])
	var delay := 0.0
	if seats.size() >= 2:
		var prior_player: Array = _seat_card_visuals(prior_seats[0]) if prior_seats.size() >= 2 else []
		var prior_opponent: Array = _seat_card_visuals(prior_seats[1]) if prior_seats.size() >= 2 else []
		var player_visuals := _seat_card_visuals(seats[0])
		var opponent_visuals := _seat_card_visuals(seats[1])
		delay = _animate_card_row(_player_cards, player_visuals, prior_player, delay)
		delay = _animate_card_row(_opponent_cards, opponent_visuals, prior_opponent, delay)
	var old_board: Array = previous.get("board", [])
	_animate_card_row(_board_cards, current.get("board", []), old_board, delay)

func _seat_card_visuals(seat: Dictionary) -> Array:
	var visuals: Array = seat.get("cards", []).duplicate()
	var hidden_count := int(seat.get("hidden_cards", 0))
	for i in range(hidden_count):
		visuals.append("__BACK__")
	return visuals

func _animate_card_row(views: Array[PokerCardView], cards: Array, old_cards: Array, start_delay: float) -> float:
	var delay := start_delay
	var reduced_sound_played := false
	for i in range(mini(views.size(), cards.size())):
		if i >= old_cards.size() or str(cards[i]) != str(old_cards[i]):
			var sound_kind := "flip" if i < old_cards.size() and str(old_cards[i]) == "__BACK__" else "deal"
			if reduced_motion:
				if not reduced_sound_played:
					_play_feedback_sound(sound_kind)
					reduced_sound_played = true
			else:
				_animate_card_reveal(views[i], delay, sound_kind)
			delay += 0.095
	return delay

func _animate_card_reveal(card: PokerCardView, delay: float, sound_kind: String) -> void:
	card.pivot_offset = card.size * 0.5
	card.modulate.a = 0.0
	card.scale = Vector2(0.82, 0.82)
	card.rotation_degrees = -7.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func(): _play_feedback_sound(sound_kind))
	tween.tween_property(card, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "rotation_degrees", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_chip_state_change(previous: Dictionary, current: Dictionary) -> void:
	var seats: Array = current.get("seats", [])
	if seats.size() < 2:
		return
	var current_pot := int(current.get("pot", 0))
	var previous_pot := int(previous.get("pot", 0))
	if previous.is_empty():
		# The first visible pot contains the posted blinds; animate those from seats.
		for seat_index in range(seats.size()):
			var posted := int(seats[seat_index].get("street_commitment", 0))
			if posted > 0:
				_animate_chip_transfer(_seat_chip_pile(seat_index), _chip_piles[1], posted)
		return
	var old_seats: Array = previous.get("seats", [])
	if current_pot > previous_pot:
		for seat_index in range(seats.size()):
			var old_seat := _find_seat(old_seats, int(seats[seat_index].get("id", seat_index)))
			if old_seat.is_empty():
				continue
			var contributed := int(old_seat.get("stack", 0)) - int(seats[seat_index].get("stack", 0))
			if contributed > 0:
				_animate_chip_transfer(_seat_chip_pile(seat_index), _chip_piles[1], contributed)
	elif previous_pot > 0 and current_pot == 0 and str(current.get("stage", "")) == "showdown":
		for seat_index in range(seats.size()):
			var old_seat := _find_seat(old_seats, int(seats[seat_index].get("id", seat_index)))
			if old_seat.is_empty():
				continue
			var winnings := int(seats[seat_index].get("stack", 0)) - int(old_seat.get("stack", 0))
			if winnings > 0:
				_animate_chip_transfer(_chip_piles[1], _seat_chip_pile(seat_index), winnings, true)

func _find_seat(seats: Array, seat_id: int) -> Dictionary:
	for seat in seats:
		if int(seat.get("id", -1)) == seat_id:
			return seat
	return {}

func _seat_chip_pile(seat_index: int) -> Control:
	return _chip_piles[2] if seat_index == 0 else _chip_piles[0]

func _animate_chip_transfer(source: Control, destination: Control, amount: int, payout: bool = false) -> void:
	var count := clampi(int(ceil(log(float(amount) + 1.0) / log(10.0))), 1, 4)
	if reduced_motion:
		_play_feedback_sound("pot" if payout else "chips")
		return
	_play_feedback_sound("pot" if payout else "chips")
	var effect_origin := _effects_layer.global_position
	var start: Vector2 = source.global_position + source.size * 0.5 - effect_origin
	var finish: Vector2 = destination.global_position + destination.size * 0.5 - effect_origin
	for i in range(count):
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(18, 18)
		chip.size = Vector2(18, 18)
		var style := StyleBoxFlat.new()
		style.bg_color = CHIP_RED if i % 2 == 0 else Color("#D8C495")
		style.border_color = PAPER
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		chip.add_theme_stylebox_override("panel", style)
		_effects_layer.add_child(chip)
		chip.position = start - chip.size * 0.5 + Vector2(float(i) * 3.0, 0.0)
		var tween := create_tween()
		tween.tween_interval(float(i) * 0.045)
		tween.tween_method(_update_chip_flight.bind(chip, start, finish), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(chip, "scale", Vector2(0.8, 0.8), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(chip.queue_free)

func _update_chip_flight(progress: float, chip: Control, start: Vector2, finish: Vector2) -> void:
	var point := start.lerp(finish, progress)
	point.y -= sin(progress * PI) * 32.0
	chip.position = point - chip.size * 0.5

func _play_feedback_sound(kind: String) -> void:
	if not sound_enabled:
		return
	var stream: AudioStreamWAV = _sound_streams.get(kind)
	if stream == null:
		stream = _make_feedback_sound(kind)
		_sound_streams[kind] = stream
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = sound_volume_db
	player.finished.connect(player.queue_free)
	_effects_layer.add_child(player)
	player.play()

func _make_feedback_sound(kind: String) -> AudioStreamWAV:
	const RATE := 22050
	var duration := 0.095 if kind == "deal" else 0.105 if kind == "flip" else 0.22 if kind == "chips" else 0.32 if kind == "turn" else 0.28
	var samples := PackedByteArray()
	var total := int(RATE * duration)
	samples.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var pulse_times: Array[float] = []
	match kind:
		"flip": pulse_times = [0.0, 0.038]
		"chips": pulse_times = [0.0, 0.045, 0.091, 0.143]
		"turn": pulse_times = [0.0, 0.16]
		"pot": pulse_times = [0.0, 0.055, 0.115, 0.18]
	var resonance_hz := 1250.0 if kind == "deal" else 1750.0 if kind == "flip" else 1480.0 if kind == "chips" else 760.0 if kind == "turn" else 1050.0
	var lowpass_noise := 0.0
	for i in range(total):
		var time := float(i) / float(RATE)
		var transient := 0.0
		for pulse_time in pulse_times:
			if time >= pulse_time:
				var age := time - pulse_time
				transient += exp(-age * (48.0 if kind == "turn" else 72.0))
		var raw_noise := rng.randf_range(-1.0, 1.0)
		lowpass_noise = lerpf(lowpass_noise, raw_noise, 0.32)
		var sound := 0.0
		if kind == "deal":
			var swish := sin(PI * clampf(time / duration, 0.0, 1.0))
			sound = (raw_noise * 0.72 + lowpass_noise * 0.28) * pow(swish, 0.55) * 0.34
			sound += sin(TAU * resonance_hz * time) * exp(-time * 45.0) * 0.045
		else:
			sound = (raw_noise * 0.62 + lowpass_noise * 0.38) * transient * 0.27
			sound += sin(TAU * resonance_hz * time) * transient * 0.11
		var value := clampf(sound, -1.0, 1.0)
		samples.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = samples
	return stream

func _on_sound_toggled(muted: bool) -> void:
	sound_enabled = not muted
	_settings_sound_toggle.text = "Unmute sound" if muted else "Mute sound"

func _on_motion_toggled(enabled: bool) -> void:
	reduced_motion = enabled
	_settings_motion_toggle.text = "Reduced motion: On" if enabled else "Reduced motion: Off"

func _update_buy_in_validity() -> void:
	if _buyin_button == null:
		return
	var wallet := int(_last_world_status.get("wallet_balance", 0))
	var rate := float(_last_world_status.get("wallet_units_per_chip", 1.0))
	_buyin_button.disabled = rate <= 0.0 or wallet < int(ceil(_buyin_amount.value * rate))

func _new_chip_pile() -> Control:
	var pile := HBoxContainer.new()
	pile.custom_minimum_size.x = 54
	pile.alignment = BoxContainer.ALIGNMENT_CENTER
	pile.add_theme_constant_override("separation", -13)
	return pile

func _add_chip_pile(parent: Control) -> void:
	var pile := _new_chip_pile()
	parent.add_child(pile)
	_chip_piles.append(pile)

func _set_chip_pile(pile: Control, amount: int) -> void:
	for child in pile.get_children():
		child.queue_free()
	var count := 0 if amount <= 0 else clampi(int(ceil(log(float(amount) + 1.0) / log(10.0))), 1, 5)
	for i in range(count):
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(23, 23)
		var outline := StyleBoxFlat.new()
		outline.bg_color = CHIP_RED if i % 2 == 0 else Color("#D8C495")
		outline.border_color = PAPER
		outline.set_border_width_all(2)
		outline.set_corner_radius_all(12)
		chip.add_theme_stylebox_override("panel", outline)
		pile.add_child(chip)

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
	button.custom_minimum_size = Vector2(100, 44)
	button.add_theme_font_size_override("font_size", 18)
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
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
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
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(child)
	return wrapper
