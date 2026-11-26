extends Node
var tree: SceneTree
var support: Node
var checks: Array = []
var test_path: String
const DEVICE := 77
func check(label: String, ok: bool) -> void:
	checks.append({"name":label,"passed":ok})
	print("GAMEPAD ","OK " if ok else "FAIL ",label)
func button(index: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
func tap(index: int) -> void:
	button(index)
	await tree.process_frame
	button(index,false)
	await tree.process_frame
func wait_scene(path: String) -> bool:
	var elapsed := 0.0
	while elapsed < 8:
		if tree.current_scene != null and tree.current_scene.scene_file_path == path and not get_node("/root/DemoSession").sleeping:
			await tree.create_timer(.2).timeout
			return true
		await tree.create_timer(.05).timeout
		elapsed += .05
	return false
func run() -> void:
	tree = get_tree()
	support = get_node("/root/ControllerSupport")
	test_path = "user://test_gamepad_%d.tres" % OS.get_process_id()
	get_node("/root/SaveSystem").save_path = test_path
	tree.change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await tree.scene_changed
	await tree.create_timer(.5).timeout
	check("Mapas preservam teclado e incluem analógico",InputMap.action_get_events("move_forward").any(func(e):return e is InputEventKey) and InputMap.action_get_events("move_forward").any(func(e):return e is InputEventJoypadMotion))
	check("Ações cobrem inventário, caderno e pausa",["next_item","previous_item","notebook","pause_game","toggle_crouch","sprint_toggle"].all(func(a):return InputMap.has_action(a)))
	check("Deadzones separadas para movimento e olhar",is_equal_approx(InputMap.action_get_deadzone("move_left"),.18) and is_equal_approx(InputMap.action_get_deadzone("look_left"),.2))
	var menu := tree.current_scene
	await tap(JOY_BUTTON_DPAD_DOWN)
	check("Gamepad ativa dicas Xbox no menu",support.using_gamepad and menu.get_node("CanvasLayer/UI/Margin/Row/Scroll/Column/Keys").text.contains("A confirmar"))
	menu.get_node("%NewGame").grab_focus()
	await tap(JOY_BUTTON_A)
	check("A inicia novo jogo sem mouse",await wait_scene("res://scenes/levels/attis_forest.tscn"))
	var player: CharacterBody3D = tree.current_scene.get_node("Player")
	check("A de confirmar não causa pulo ao entrar",player.velocity.y <= .1)
	button(JOY_BUTTON_A,false)
	await tree.create_timer(.3).timeout
	check("HUD muda para controle",player.get_node("Hud/Instructions").text.contains("VIEW"))
	axis(JOY_AXIS_LEFT_X,.1)
	await tree.create_timer(.2).timeout
	check("Pequeno ruído no analógico não move jogador",absf(player.velocity.x) < .05 and absf(player.velocity.z) < .05)
	axis(JOY_AXIS_LEFT_X,.6)
	await tree.create_timer(.3).timeout
	var partial_speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	axis(JOY_AXIS_LEFT_X,1.0)
	await tree.create_timer(.3).timeout
	var full_speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	check("Inclinação do analógico controla velocidade",partial_speed > .3 and full_speed > partial_speed+.5 and full_speed <= player.walk_speed+.1)
	axis(JOY_AXIS_LEFT_X,0)
	await tree.create_timer(.2).timeout
	var yaw: float = player.rotation.y
	var pitch: float = player.camera.rotation.x
	axis(JOY_AXIS_RIGHT_X,.8)
	axis(JOY_AXIS_RIGHT_Y,-.6)
	await tree.create_timer(.3).timeout
	axis(JOY_AXIS_RIGHT_X,0)
	axis(JOY_AXIS_RIGHT_Y,0)
	check("Analógico direito olha horizontal e verticalmente",player.rotation.y < yaw-.1 and player.camera.rotation.x > pitch+.1)
	player.controls_locked = true
	yaw = player.rotation.y
	axis(JOY_AXIS_RIGHT_X,1)
	await tree.create_timer(.15).timeout
	axis(JOY_AXIS_RIGHT_X,0)
	check("Câmera manual respeita bloqueios de interface/cutscene",is_equal_approx(yaw,player.rotation.y))
	player.controls_locked = false
	await tap(JOY_BUTTON_Y)
	check("Y alterna lanterna",player.flashlight.visible)
	await tap(JOY_BUTTON_B)
	await tree.create_timer(.2).timeout
	check("B alterna agachamento sem precisar segurar",player._crouch_toggled and player.body_collision.shape.height < player._standing_capsule_height)
	await tap(JOY_BUTTON_B)
	axis(JOY_AXIS_LEFT_Y,-1)
	await tap(JOY_BUTTON_LEFT_STICK)
	await tree.create_timer(.3).timeout
	check("L3 alterna corrida e gasta estamina",player._sprint_toggled and player.stamina < player.stamina_capacity)
	axis(JOY_AXIS_LEFT_Y,0)
	await tree.create_timer(.15).timeout
	check("Parar encerra corrida alternada",not player._sprint_toggled)
	axis(JOY_AXIS_LEFT_Y,-1)
	axis(JOY_AXIS_TRIGGER_LEFT,1)
	await tree.create_timer(.2).timeout
	check("LT também permite correr segurando",Vector2(player.velocity.x,player.velocity.z).length() > player.walk_speed+.2)
	axis(JOY_AXIS_LEFT_Y,0)
	axis(JOY_AXIS_TRIGGER_LEFT,0)
	var inv: Node = player.get_node("Inventory")
	inv.selected_slot = 0
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	check("RB seleciona próximo slot",inv.selected_slot == 1)
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check("LB seleciona slot anterior",inv.selected_slot == 0)
	# View opens a focusable notebook, D-pad Up navigates within it, B closes it.
	await tap(JOY_BUTTON_BACK)
	var ui := get_node("/root/DemoInterface")
	check("View abre caderno com foco de botão",ui.modal.visible and ui.modal_kind == "notebook" and tree.root.gui_get_focus_owner() is Button)
	await tap(JOY_BUTTON_DPAD_UP)
	check("Direcional para cima navega sem fechar caderno",ui.modal.visible)
	yaw = player.rotation.y
	axis(JOY_AXIS_RIGHT_X,1)
	await tree.create_timer(.15).timeout
	axis(JOY_AXIS_RIGHT_X,0)
	check("Analógico não move câmera atrás do caderno",is_equal_approx(yaw,player.rotation.y))
	await tap(JOY_BUTTON_B)
	check("B fecha caderno e libera jogador",not ui.modal.visible and not player.controls_locked)
	await tap(JOY_BUTTON_START)
	check("Menu/Start pausa e foca Retomar",tree.paused and get_node("/root/GameMenus").panel.visible and tree.root.gui_get_focus_owner() == get_node("/root/GameMenus").resume_button)
	await tap(JOY_BUTTON_B)
	check("B retoma pela pausa",not tree.paused and not get_node("/root/GameMenus").panel.visible)
	# Physical inventory interaction through X and right trigger.
	inv.import_inventory({"slots":[load("res://resources/items/sample_collector.tres").duplicate(true),load("res://resources/items/fuse.tres"),null,null]})
	var bush: Node3D = tree.current_scene.get_node("ArbustosDePesquisa/Arbusto04")
	player.global_position = bush.global_position+Vector3(0,.6,2)
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.camera.look_at(bush.global_position+Vector3.UP*.6)
	await tree.physics_frame
	axis(JOY_AXIS_TRIGGER_RIGHT,.8)
	await tree.create_timer(.08).timeout
	check("RT coleta amostra física sem consumir ferramenta",inv.slots[0] != null and inv.slots[0].sample_ids.size() == 1)
	# Changing aim while still holding RT must not sample another bush through trigger noise.
	var next: Node3D = tree.current_scene.get_node("ArbustosDePesquisa/Arbusto05")
	player.global_position = next.global_position+Vector3(0,.6,2)
	player.camera.look_at(next.global_position+Vector3.UP*.6)
	await tree.physics_frame
	axis(JOY_AXIS_TRIGGER_RIGHT,.9)
	await tree.create_timer(.08).timeout
	check("Oscilação do gatilho segurado não repete uso",inv.slots[0].sample_ids.size() == 1)
	axis(JOY_AXIS_TRIGGER_RIGHT,0)
	await tree.physics_frame
	axis(JOY_AXIS_TRIGGER_RIGHT,.8)
	await tree.create_timer(.08).timeout
	check("Soltar e apertar RT permite nova coleta",inv.slots[0].sample_ids.size() == 2)
	axis(JOY_AXIS_TRIGGER_RIGHT,0)
	inv.selected_slot = 1
	await tap(JOY_BUTTON_DPAD_DOWN)
	var item: RigidBody3D
	for node in tree.get_nodes_in_group("world_items"):
		if tree.current_scene.is_ancestor_of(node) and node.definition.item_id == &"fuse": item = node
	check("Direcional para baixo arremessa item",inv.slots[1] == null and is_instance_valid(item))
	if is_instance_valid(item):
		item.freeze = true
		item.global_position = player.camera.global_position-player.camera.global_basis.z*1.5
		await tree.physics_frame
		await tap(JOY_BUTTON_X)
	check("X recolhe item físico",inv.slots[1] != null and inv.slots[1].item_id == &"fuse")
	check("Dicas de interação usam X e RT",support.adapt_text("E  •  Coletar / M1").contains("X  •") and support.adapt_text("M1").contains("RT"))
	var keyboard := InputEventKey.new()
	keyboard.keycode = KEY_1
	keyboard.pressed = true
	Input.parse_input_event(keyboard)
	await tree.process_frame
	var key_release := keyboard.duplicate()
	key_release.pressed = false
	Input.parse_input_event(key_release)
	await tree.process_frame
	check("Teclado reassume dicas e slots",not support.using_gamepad and inv.selected_slot == 0 and player.get_node("Hud/Instructions").text.contains("TAB"))
	player.set_physics_process(true)
	support.active_device = DEVICE
	support._set_device(true)
	support._connection_changed(DEVICE,false)
	check("Desconexão do controle pausa campanha",tree.paused and not support.using_gamepad)
	support.active_device = DEVICE
	support._connection_changed(DEVICE,false)
	check("Desconexão não desfaz pausa já aberta",tree.paused)
	get_node("/root/GameMenus").resume()
	for path in [test_path,test_path+".bak.tres",test_path+".pending.tres"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	get_node("/root/DemoSession").persistent_session = false
	var failed := checks.filter(func(c):return not c.passed)
	FileAccess.open("res://tests/gamepad_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size()},"  "))
	print("GAMEPAD_RESULT ",checks.size()-failed.size(),"/",checks.size()," ",failed)
	tree.quit(0 if failed.is_empty() else 1)
