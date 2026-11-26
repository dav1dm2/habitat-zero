extends Node
## Temporário, exclusivo do executável do editor; não é controle de gameplay/exportação.
var enabled: bool = false
var busy := false
var overlay: Label
signal day_skipped(day: int)

func _ready() -> void:
	enabled = OS.has_feature("editor") and OS.is_debug_build()
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	overlay = Label.new()
	overlay.position = Vector2(24,96)
	overlay.add_theme_font_size_override("font_size",14)
	overlay.modulate = Color("d8bd7a")
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

func _process(_delta: float) -> void:
	var session := get_node("/root/DemoSession")
	var flow := get_node("/root/DreamFlow")
	var progress := get_node("/root/ReserveState")
	overlay.visible = session.is_campaign(get_tree().current_scene) and not progress.demo_finished and not flow.input_locked and not session.sleeping
	overlay.text = "DEV / Dia %d | F9 próximo dia | F10 inspecionar ritual: %s" % [progress.day,"LIGADO" if flow.development_inspection else "desligado"]
	var room := get_tree().current_scene
	if room != null and room.has_method("cycle_deer_art_resolution"):
		overlay.text += " | F7 resolução do cervo"

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not get_node("/root/DemoSession").is_campaign(get_tree().current_scene):
		return
	if event.keycode == KEY_F9 or event.physical_keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		advance_development_day()
	elif event.keycode == KEY_F10 or event.physical_keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		toggle_inspection()
	elif event.keycode == KEY_F7 or event.physical_keycode == KEY_F7:
		var room := get_tree().current_scene
		if room.has_method("cycle_deer_art_resolution") and not get_node("/root/DreamFlow").input_locked:
			get_viewport().set_input_as_handled()
			var resolution: int = room.cycle_deer_art_resolution()
			get_node("/root/DemoInterface").show_status("DEV: cervo %d × %d px" % [resolution, resolution])

func toggle_inspection() -> void:
	var flow := get_node("/root/DreamFlow")
	if not enabled or busy or flow.input_locked or get_node("/root/DemoSession").sleeping:
		return
	flow.development_inspection = not flow.development_inspection
	get_node("/root/DemoInterface").show_status("DEV: gatilho do ritual suspenso. Explore livremente; F10 reativa." if flow.development_inspection else "DEV: gatilho do ritual ativo.")

func advance_development_day() -> void:
	var session := get_node("/root/DemoSession")
	var flow := get_node("/root/DreamFlow")
	var fade := get_node("/root/SceneTransitionManager")
	var room := get_tree().current_scene
	if not enabled or busy or session.sleeping or flow.input_locked or fade._transition_pending or not session.is_campaign(room):
		return
	var progress := get_node("/root/ReserveState")
	if progress.day >= 3:
		get_node("/root/DemoInterface").show_status("DEV: Dia 3 é o desfecho. F10 suspende o gatilho antes do ritual; F5 reinicia o projeto pelo editor.")
		return
	busy = true
	flow.development_inspection = false
	get_node("/root/DemoInterface").close_modal()
	var player: CharacterBody3D = room.get_node("Player")
	player.controls_locked = true
	player.health = player.max_health
	player.health_bar.value = player.health
	# Skip only stages already defined for the current day; keep tools and physical items.
	progress.power_restored = true
	progress.fuse_installed = true
	progress.breaker_progress = 3
	progress.briefing_heard = true
	if progress.day == 2:
		progress.day2_briefing_heard = true
		progress.robot_activated = true
	for id in range(1000,1010 if progress.day == 2 else 1005):
		progress.fertilize(id)
	progress.register_analysis("attis")
	progress.register_analysis("habitat1")
	progress.changed.emit()
	if room.scene_file_path != session.INTERIOR:
		await fade.fade_to_black(.25)
		session.capture_items(room)
		session._restore_inventory = player.get_node("Inventory").export_inventory()
		get_node("/root/ReserveSimulation").prepare_player_travel()
		get_tree().change_scene_to_file(session.INTERIOR)
		await get_tree().scene_changed
		await get_tree().process_frame
		await get_tree().process_frame
		room = get_tree().current_scene
		room.get_node("Player").controls_locked = true
	if session.advance_day(room):
		await session.woke_up
		await get_tree().process_frame
		day_skipped.emit(progress.day)
	else:
		room.get_node("Player").controls_locked = false
		await fade.fade_from_black(.2)
	busy = false
