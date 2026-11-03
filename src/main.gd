class_name Main
extends Control
## Boots the first playable Texas Hold'em table scene.

const TABLE_SCENE := preload("res://scenes/poker/poker_table.tscn")

func _ready() -> void:
	var table := TABLE_SCENE.instantiate() as Control
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(table)
