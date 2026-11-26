extends Node
## Device-aware prompts and menu focus; gameplay uses the same InputMap actions as keyboard.
signal device_changed(gamepad: bool)
var using_gamepad := false
var active_device := -1
var _scroll_fraction := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui_bindings()
	device_changed.connect(_refresh_ui)
	Input.joy_connection_changed.connect(_connection_changed)
	get_tree().scene_changed.connect(_scene_changed)

func _ensure_ui_bindings() -> void:
	for action in ["ui_up","ui_down","ui_left","ui_right","ui_accept","ui_cancel"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	for pair in [["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B],["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = pair[1]
		if not InputMap.action_has_event(pair[0],event): InputMap.action_add_event(pair[0],event)
	for pair in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = pair[1]
		event.axis_value = pair[2]
		if not InputMap.action_has_event(pair[0],event): InputMap.action_add_event(pair[0],event)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		active_device = event.device
		_set_device(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > .28:
		active_device = event.device
		_set_device(true)
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		_set_device(false)

func _set_device(value: bool) -> void:
	if using_gamepad == value: return
	using_gamepad = value
	device_changed.emit(value)
	if value: focus_interface.call_deferred()

func _scene_changed() -> void:
	if using_gamepad: focus_interface.call_deferred()

func focus_interface() -> void:
	if not using_gamepad: return
	var window: Window = get_viewport().get_window()
	# ConfirmationDialog is its own viewport; never steal its focus for the menu behind it.
	for child in get_tree().current_scene.get_children() if get_tree().current_scene != null else []:
		if child is Window and child.visible:
			return
	var focus := window.gui_get_focus_owner()
	if is_instance_valid(focus) and focus.is_visible_in_tree(): return
	var menus := get_node("/root/GameMenus")
	if menus.panel.visible:
		menus.resume_button.grab_focus()
		return
	var ui := get_node("/root/DemoInterface")
	if ui.modal.visible:
		for button in ui.action_buttons():
			if button is Button and not button.disabled:
				button.grab_focus()
				return

func _process(delta: float) -> void:
	if not using_gamepad: return
	var ui := get_node("/root/DemoInterface")
	if not ui.modal.visible or get_tree().paused: return
	var scroll := ui.content.get_parent() as ScrollContainer
	if scroll == null: return
	var amount := Input.get_axis("look_up","look_down")
	_scroll_fraction += amount*600.0*delta
	var pixels := int(_scroll_fraction)
	_scroll_fraction -= pixels
	scroll.scroll_vertical += pixels

func _connection_changed(device: int, connected: bool) -> void:
	if connected or device != active_device: return
	active_device = -1
	_set_device(false)
	# Stop on disconnect rather than letting the player walk into a hazard.
	if get_tree().paused or not get_node("/root/DemoSession").is_campaign(get_tree().current_scene): return
	if get_node("/root/DemoSession").sleeping or get_node("/root/DreamFlow").input_locked: return
	var ui := get_node("/root/DemoInterface")
	if ui.modal.visible: ui.close_modal()
	var event := InputEventAction.new()
	event.action = "pause_game"
	event.pressed = true
	get_node("/root/GameMenus")._input(event)

func adapt_text(words: String) -> String:
	if not using_gamepad: return words
	for pair in [["Alt esquerdo","Y"],["Alt permite","Y permite"],["E  •","X  •"],["E na ","X na "],["E recolhe","X recolhe"],["E entrega","X entrega"],["E interage","X interage"],["E para ","X para "],["pressione E","pressione X"],["com E","com X"],["use E","use X"],["E no ","X no "],["M1","RT"],["com Q","com ↓"],["/ Tab","/ View"],["Tab abre","View abre"],["/ Esc","/ B"],["Esc pausa","Menu pausa"]]:
		words = words.replace(pair[0],pair[1])
	return words

func instructions() -> String:
	if using_gamepad:
		return "LS mover  |  RS olhar  |  LT correr / L3 alternar corrida  |  B ou R3 agachar  |  A pular  |  Y lanterna\nX interagir/recolher  |  RT usar  |  LB/RB trocar item  |  ↓ arremessar  |  View/↑ caderno  |  Menu pausa"
	return "WASD mover  |  Mouse olhar  |  Shift correr  |  Ctrl agachar  |  Space pular  |  Alt esquerdo lanterna\nE interagir/coletar  |  Q arremessar  |  M1 usar  |  Scroll ou 1-4 selecionar  |  Tab caderno  |  Esc pausa"

func _refresh_ui(_gamepad: bool) -> void:
	var ui := get_node("/root/DemoInterface")
	for control in ui.content.get_children() + ui.footer.get_children() + [ui.notice]:
		if control.has_meta("input_text"): control.text = adapt_text(control.get_meta("input_text"))
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("refresh_input_legend"):
		scene.refresh_input_legend()
