extends CanvasLayer
var panel: Control
var resume_button: Button
var checkpoint_label: Label
var controls_legend: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	preload("res://scripts/ui/menu_style.gd").apply(panel)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(.015,.025,.025,.94)
	panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 320
	box.add_theme_constant_override("separation",14)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override("font_size",30)
	box.add_child(title)
	resume_button = _button(box,"Retomar",resume)
	_button(box,"Menu principal",_menu)
	_button(box,"Controles",_toggle_controls)
	_button(box,"Sair do jogo",get_node("/root/Soundtrack").quit_game)
	controls_legend = Label.new()
	controls_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_legend.add_theme_font_size_override("font_size", 14)
	box.add_child(controls_legend)
	controls_legend.hide()
	get_node("/root/ControllerSupport").device_changed.connect(_refresh_controls)
	checkpoint_label = Label.new()
	checkpoint_label.add_theme_font_size_override("font_size",14)
	box.add_child(checkpoint_label)
	panel.hide()

func _button(box: Control, words: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = words
	button.pressed.connect(action)
	box.add_child(button)
	return button

func _toggle_controls() -> void:
	_refresh_controls(false)
	controls_legend.visible = not controls_legend.visible
	controls_legend.custom_minimum_size.x = clampf(get_viewport().get_visible_rect().size.x - 90, 260, 560) if controls_legend.visible else 0.0

func _refresh_controls(_gamepad: bool) -> void:
	controls_legend.text = get_node("/root/ControllerSupport").instructions()

func _input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pause_game") or event.is_echo():
		return
	if panel.visible:
		resume()
		get_viewport().set_input_as_handled()
		return
	var session := get_node("/root/DemoSession")
	if not session.is_campaign(get_tree().current_scene): return
	if get_node("/root/DemoInterface").modal.visible: return
	get_viewport().set_input_as_handled()
	if session.sleeping or get_node("/root/DreamFlow").input_locked or get_node("/root/SceneTransitionManager")._transition_pending:
		return
	panel.show()
	checkpoint_label.text = "Continuar retoma o início do Dia %d.\nO trabalho deste dia não é salvo ao sair." % get_node("/root/ReserveState").day
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()

func resume() -> void:
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player != null: player.clear_ui_input()
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _menu() -> void:
	panel.hide()
	get_tree().paused = false
	get_node("/root/DemoSession").return_to_menu()
