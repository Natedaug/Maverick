class_name PokerCardView
extends PanelContainer
## Reusable poker card face/back presentation for table and collection views.

const FACE_WIDTH := 66
const FACE_HEIGHT := 94

var _rank_label: Label
var _suit_label: Label
var _corner_label: Label
var _back_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(FACE_WIDTH, FACE_HEIGHT)
	_build_card()
	show_back()

func show_face(code: String) -> void:
	if not is_node_ready():
		return
	var rank := code.substr(0, code.length() - 1)
	var suit := code.substr(code.length() - 1, 1)
	if rank == "T":
		rank = "10"
	var symbols := {"s": "♠", "h": "♥", "d": "♦", "c": "♣"}
	var symbol: String = symbols.get(suit, suit)
	var color := Color("#B6443A") if suit == "h" or suit == "d" else Color("#282620")
	_rank_label.text = rank
	_rank_label.add_theme_color_override("font_color", color)
	_suit_label.text = symbol
	_suit_label.add_theme_color_override("font_color", color)
	_corner_label.text = "%s\n%s" % [rank, symbol]
	_corner_label.add_theme_color_override("font_color", color)
	_show_face_content(true)

func show_back() -> void:
	if not is_node_ready():
		return
	_show_face_content(false)

func show_empty() -> void:
	if not is_node_ready():
		return
	_rank_label.text = ""
	_suit_label.text = ""
	_corner_label.text = ""
	get_child(0).visible = true
	_back_label.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#245642")
	style.border_color = Color("#64806C")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	add_theme_stylebox_override("panel", style)

func _build_card() -> void:
	var face := MarginContainer.new()
	face.add_theme_constant_override("margin_left", 5)
	face.add_theme_constant_override("margin_right", 5)
	face.add_theme_constant_override("margin_top", 4)
	face.add_theme_constant_override("margin_bottom", 4)
	add_child(face)
	var face_stack := VBoxContainer.new()
	face_stack.add_theme_constant_override("separation", 0)
	face.add_child(face_stack)
	_rank_label = _label("A", 19)
	face_stack.add_child(_center_x(_rank_label))
	_suit_label = _label("♠", 35)
	_suit_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	face_stack.add_child(_center(_suit_label))
	_corner_label = _label("A\n♠", 10)
	_corner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	face_stack.add_child(_corner_label)
	_back_label = _label("✦\nRUSTY\nSPUR\n✦", 12)
	_back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_back_label.add_theme_color_override("font_color", Color("#E8D2A3"))
	_back_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_back_label)

func _show_face_content(show_face: bool) -> void:
	get_child(0).visible = show_face
	_back_label.visible = not show_face
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(7)
	style.set_border_width_all(2)
	if show_face:
		style.bg_color = Color("#FFF9E9")
		style.border_color = Color("#BD9655")
	else:
		style.bg_color = Color("#174A3A")
		style.border_color = Color("#BD9655")
	add_theme_stylebox_override("panel", style)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _center(child: Control) -> CenterContainer:
	var wrapper := CenterContainer.new()
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(child)
	return wrapper

func _center_x(child: Control) -> CenterContainer:
	var wrapper := CenterContainer.new()
	wrapper.add_child(child)
	return wrapper
