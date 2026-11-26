extends Control

var _selected := false
var _divider := false

@onready var caption: Label = $Caption
@onready var icon: TextureRect = $Icon
@onready var number: Label = $Number

func show_item(position_index: int, name_text: String, texture: Texture2D, selected: bool) -> void:
	number.text = str(position_index + 1).pad_zeros(2)
	caption.text = name_text
	icon.texture = texture
	var brightness := 1.0 if selected else 0.76
	icon.modulate = Color(brightness, brightness, brightness, 1.0)
	caption.modulate = Color(1, 1, 1, 1) if selected else Color(0.84, 0.84, 0.84, 0.92)
	_selected = selected
	_divider = position_index > 0
	queue_redraw()

func _draw() -> void:
	if _divider:
		draw_line(Vector2(0, 10), Vector2(0, size.y - 10), Color(1, 1, 1, 0.19))
	if _selected:
		var midpoint := size.x * 0.5
		draw_line(Vector2(midpoint - 14, size.y - 3), Vector2(midpoint + 14, size.y - 3), Color(0.91, 0.91, 0.91, 0.84), 2)
