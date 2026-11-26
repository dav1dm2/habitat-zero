extends Control

const Style = preload("res://scripts/ui/field_style.gd")
const DEER = preload("res://assets/characters/deer/deer_128.tres")

var ritual_frame: Texture2D
var replay_button: Button
var _photo: TextureRect
var _column: VBoxContainer
var _margin: MarginContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preload("res://scripts/ui/menu_style.gd").apply(self)

	_photo = TextureRect.new()
	_photo.texture = ritual_frame
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo.modulate = Color(0.78, 0.90, 0.86, 0.53)
	add_child(_photo)

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("101b1e"), Color(0.05, 0.08, 0.09, 0.13)])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_to = Vector2(0.79, 0)
	var shade := TextureRect.new()
	shade.texture = fade
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 32)
	add_child(_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_margin.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_column.add_theme_constant_override("separation", 12)
	scroll.add_child(_column)
	_column.add_child(Style.label("RESERVA DE ATTIS   /   FIM DA DEMO", 14, Style.WARM))
	var title := Style.label("HABITAT\nZERO", 52)
	title.name = "EndingTitle"
	_column.add_child(title)
	_column.add_child(HSeparator.new())
	replay_button = _action("Replay", "Jogar novamente", _replay)
	_action("Menu", "Menu principal", get_node("/root/DemoSession").return_to_menu)
	_action("Quit", "Sair do jogo", get_node("/root/Soundtrack").quit_game)
	replay_button.grab_focus.call_deferred()
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	_margin.offset_right = clampf(size.x * 0.42, 280, 520)
	queue_redraw()

func _action(id: String, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 43
	button.pressed.connect(callback)
	_column.add_child(button)
	return button

func _replay() -> void:
	var session := get_node("/root/DemoSession")
	session.start_new_game(session.persistent_session)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("192529"))
	var center := Vector2(size.x * 0.73, size.y * 0.62)
	var span := minf(size.x * 0.24, size.y * 0.44)
	var deer: Texture2D = DEER.get_frame_texture(&"ritual_espera", 0)
	for i in range(5):
		draw_arc(center, span * (0.6 + i * 0.16), PI, TAU, 64, Color(0.40, 0.56, 0.53, 0.19), 1.0, true)
	for i in range(7):
		var angle := PI + (float(i) + 0.35) * PI / 6.7
		var at := center + Vector2.from_angle(angle) * span * 0.82
		var side := clampf(span * 0.31, 25.0, 110.0)
		draw_texture_rect(deer, Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color(0.46, 0.63, 0.61, 0.87))
	draw_line(Vector2(size.x * 0.44, center.y + 40), Vector2(size.x - 26, center.y + 40), Color(0.40, 0.56, 0.53, 0.20))
