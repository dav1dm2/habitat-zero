extends Node
var tree: SceneTree
var progress: Node
var session: Node
var flow: Node
var ui: Node
var checks: Array = []
var phases: Array = []
var trace: Array = []
var camera_tracking := false
var previous_view: Vector2
var max_camera_step := 0.0
const INTERIOR := "res://scenes/levels/attis_interior.tscn"
const FOREST := "res://scenes/levels/attis_forest.tscn"

func run() -> void:
	tree = get_tree()
	progress = get_node("/root/ReserveState")
	session = get_node("/root/DemoSession")
	flow = get_node("/root/DreamFlow")
	ui = get_node("/root/DemoInterface")
	progress.reset()
	session.campaign_started = false
	session.room_items.clear()
	session.storage.clear()
	tree.change_scene_to_file(INTERIOR)
	await tree.scene_changed
	await tree.create_timer(.7).timeout
	var room := tree.current_scene
	var player: CharacterBody3D = room.get_node("Player")
	var beacon: OmniLight3D = room.get_node("MachineEmergency")
	var values: Array[float] = []
	for i in range(12):
		await tree.create_timer(.2).timeout
		values.append(beacon.light_energy)
	check("Emergência vermelha pulsa suavemente no Dia 1",values.max() < 1.0 and values.max()-values.min() > .4 and beacon.light_color.r > beacon.light_color.g*2)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0,1.8,-7.4),beacon.global_position,1)
	check("Luz e abertura da sala de máquinas visíveis do corredor",player.get_world_3d().direct_space_state.intersect_ray(query).is_empty() and Vector3(0,1.8,-7.4).distance_to(beacon.global_position) < beacon.omni_range)
	var bgforest: Node3D = get_node("/root/ReserveSimulation").rooms[FOREST]
	check("Evento invisível e desativado nos dias normais",not bgforest.get_node("DreamEvent").visible and bgforest.get_node("DreamEvent").process_mode == Node.PROCESS_MODE_DISABLED)
	progress.power_restored = true
	progress.briefing_heard = true
	progress.changed.emit()
	await tree.process_frame
	check("Restaurar energia apaga luz de emergência",beacon.light_energy == 0)
	for id in range(1000,1005): progress.fertilize(id)
	progress.register_analysis("attis")
	progress.register_analysis("habitat1")
	check("Primeiro descanso aceito",session.advance_day(room))
	check("Sono trava controles e recusa segundo acionamento",session.sleeping and player.controls_locked and not session.advance_day(room))
	await tree.create_timer(.26).timeout
	check("Sono usa escurecimento gradual antes de mudar dia",get_node("/root/SceneTransitionManager")._fade.color.a > .1 and progress.day == 1)
	await session.woke_up
	await tree.process_frame
	check("Despertar do Dia 2 restaura visibilidade",progress.day == 2 and get_node("/root/SceneTransitionManager")._fade.color.a == 0 and not session.sleeping)
	ui.close_modal()
	check("Metas pendentes impedem sonho antecipado",not session.advance_day(room))
	# Existing routine is validated by the daily automation suite; stage its completion.
	progress.day2_briefing_heard = true
	progress.robot_activated = true
	for id in range(1005,1010): progress.fertilize(id)
	progress.register_analysis("attis")
	progress.register_analysis("habitat1")
	var inv: Node = player.get_node("Inventory")
	var objects: Array = [load("res://resources/items/fertilizer.tres"),load("res://resources/items/sample_collector.tres").duplicate(true),load("res://resources/items/empty_probe.tres"),load("res://resources/items/arrival_letter.tres")]
	inv.import_inventory({"slots":objects})
	check("Descanso final aceito após metas do Dia 2",session.advance_day(room))
	await session.woke_up
	await tree.process_frame
	check("Despertar como Dia 3 inicia sonho e mantém histórico",progress.day == 3 and progress.is_dream and progress.analysis_history["2"].size() == 2)
	check("Inventário cheio recebe carta sem destruir item",inv.slots[0].item_id == &"dream_letter" and session.storage.has(objects[0]) and inv.slots[1] == objects[1])
	check("Checkpoint do sonho inclui carta e blecaute",session._checkpoint_inventory.slots[0].item_id == &"dream_letter" and session._checkpoint_scene == INTERIOR and not progress.power_restored)
	check("Luz de emergência e iluminação elétrica apagadas no sonho",beacon.light_energy == 0 and flow.descendants(room).filter(func(n):return n is Light3D and not player.is_ancestor_of(n)).all(func(n):return n.light_energy == 0))
	check("Lanterna continua funcional, desligada no despertar",not player.flashlight.visible and player.flashlight.light_energy > 0)
	check("Robô não trabalha no sonho",not progress.robot_activated and get_node("/root/ReserveSimulation").robot.process_mode == Node.PROCESS_MODE_DISABLED)
	var panel: Node = room.get_node("PowerPanel")
	check("Fusível não restaura o blecaute do sonho",not panel.accept_item(load("res://resources/items/fuse.tres"),player))
	progress.fuse_installed = true
	check("Disjuntores também não restauram energia",not panel.press_breaker(1) and not progress.power_restored)
	progress.fuse_installed = false
	ui.show_notebook()
	var words := ui_text()
	check("Tab tem uma única tarefa de investigar",words.contains("Investigar a floresta") and words.count("□") == 1 and not words.contains("Fertilizar") and not words.contains("Restaurar a energia"))
	ui.close_modal()
	inv._use_selected_item()
	check("M1 abre bilhete irregular em vez da carta de missão",ui.modal_kind == "dream_letter" and progress.dream_letter_read and ui.content.get_child(1).get_script().resource_path.ends_with("dream_letter_view.gd"))
	ui.close_modal()
	inv._drop_selected_item()
	await tree.process_frame
	ui.show_notebook()
	ui.show_dream_letter()
	check("Bilhete continua consultável depois de largado",ui.modal_kind == "dream_letter")
	ui.close_modal()
	await travel("DoorExit")
	room = tree.current_scene
	player = room.get_node("Player")
	inv = player.get_node("Inventory")
	check("Mesma floresta passa ao modo noturno",room.scene_file_path == FOREST and flow.phase == "exploring" and room.get_node("Ambiente_Nevoeiro").environment.ambient_light_energy < .05)
	check("Névoa mantém parâmetros aprovados",room.get_node("Ambiente_Nevoeiro").environment.fog_depth_end == 26 and room.get_node("Ambiente_Nevoeiro").environment.fog_depth_begin == 5)
	var event := InputEventAction.new()
	event.action = "toggle_flashlight"
	event.pressed = true
	player._unhandled_input(event)
	check("Alt permite iluminar a floresta noturna",player.flashlight.visible and player.flashlight.light_energy > 0)
	var corpses := room.get_node("DreamEvent/DeadSkunks").get_children()
	var deer := room.get_node("DreamEvent/DeerCircle").get_children()
	check("Trilha contém nove NPCs mortos e começa na entrada",corpses.size() == 9 and corpses[0].global_position.distance_to(room.get_node("DoorToInterior/Arrival").global_position) < 5)
	check("Sete cervos em semicírculo substituem fauna cotidiana",deer.size() == 7 and not room.get_node("Fauna").visible and tree.get_nodes_in_group("animals").filter(func(a):return room.is_ancestor_of(a)).size() == 16)
	check("Corpos usam estado e sprite próprios sem ataque",corpses.all(func(a):return a.event_state == "dead" and a.presentation_state == &"dead" and a.get_node("EventSprite").visible and not a._attack_allowed()))
	var positions: Array = corpses.map(func(a):return a.global_position)
	await tree.create_timer(.5).timeout
	check("Gambás mortos permanecem no mesmo lugar",corpses.all(func(a):return a.global_position.distance_to(positions[corpses.find(a)]) < .04))
	check("Cervos aguardam ritual com sinal de apresentação",deer.all(func(a):return a.event_state == "ritual_wait" and a.presentation_state == &"ritual_wait" and not a._attack_allowed()))
	flow.phase_changed.connect(func(value):phases.append(value))
	# Follow the real trail with standard movement until the proximity event takes over.
	var trigger: Node3D = room.get_node("DreamEvent/TriggerApproach")
	await walk_to_event(player,trigger.global_position)
	check("Aproximação pela trilha inicia cutscene",flow.input_locked and flow.phase == "walking_to_center" and player.controls_locked and not player.is_physics_processing())
	var copy: Dictionary = inv.export_inventory()
	event.action = "drop_item"
	inv.handle_input(event)
	ui.show_notebook()
	ui.close_modal()
	check("Inventário e Tab não liberam controle durante ritual",inv.export_inventory() == copy and player.controls_locked and not ui.modal.visible)
	# Restart mid-cutscene: no stale coroutine may finish or retain input locks.
	session.restart_day()
	await tree.scene_changed
	await tree.create_timer(.8).timeout
	room = tree.current_scene
	player = room.get_node("Player")
	check("Reinício durante ritual devolve controle no alojamento",room.scene_file_path == INTERIOR and not flow.input_locked and not player.controls_locked and player.is_physics_processing())
	check("Checkpoint restaura bilhete do sonho sem duplicação",player.get_node("Inventory").slots.filter(func(item):return item != null and item.item_id == &"dream_letter").size() == 1 and progress.is_dream and progress.day == 3)
	await travel("DoorExit")
	room = tree.current_scene
	player = room.get_node("Player")
	inv = player.get_node("Inventory")
	corpses = room.get_node("DreamEvent/DeadSkunks").get_children()
	deer = room.get_node("DreamEvent/DeerCircle").get_children()
	check("Retorno após reinício não duplica NPCs de evento",tree.get_nodes_in_group("animals").filter(func(a):return room.is_ancestor_of(a)).size() == 16)
	phases.clear()
	check("Alvos e parâmetros de câmera editáveis existem na cena",room.has_node("DreamEvent/RitualCamera/WalkLookTarget") and room.has_node("DreamEvent/RitualCamera/FinalLookTarget") and room.get_node("DreamEvent/RitualCamera").turn_speed_degrees > 0)
	# Resume at the approach marker as controlled test setup; cutscene locomotion remains physical.
	player.global_position = room.get_node("DreamEvent/TriggerApproach").global_position+Vector3.UP*.9
	player.rotation.y = 0.6
	player.camera.rotation.x = 0.4
	previous_view = Vector2(player.rotation.y,player.camera.rotation.x)
	max_camera_step = 0.0
	camera_tracking = true
	await tree.physics_frame
	await tree.physics_frame
	check("Evento pode começar novamente após cancelamento",flow.phase == "walking_to_center" and flow.input_locked)
	var timer := 0.0
	while flow.phase == "walking_to_center" and timer < 28:
		await tree.physics_frame
		timer += get_physics_process_delta_time()
		trace.append(player.global_position)
	check("Jogador caminha fisicamente e para no centro",flow.phase == "centered" and Vector2(player.position.x-room.get_node("DreamEvent/RitualCenter").position.x,player.position.z-room.get_node("DreamEvent/RitualCenter").position.z).length() < .8 and trace.size() > 10)
	var before: Array = deer.map(func(a):return a.global_position)
	while flow.phase == "centered": await tree.process_frame
	var look_direction: Vector3 = (flow._camera_target("FinalLookTarget")-player.camera.global_position).normalized()
	check("Câmera enquadra alvo do semicírculo após acomodar",(-player.camera.global_basis.z).dot(look_direction) > .99)
	check("Cervos mudam juntos para aproximação ritual",deer.all(func(a):return a.event_state == "ritual_approach" and a.presentation_state == &"ritual_approach"))
	await tree.create_timer(1.5).timeout
	check("Todos os cervos se aproximam por movimento real",deer.all(func(a):return a.global_position.distance_to(before[deer.find(a)]) > .4))
	var waited := 0.0
	while flow.phase != "finished" and waited < 8:
		await tree.create_timer(.1).timeout
		waited += .1
	camera_tracking = false
	check("Câmera gira suavemente sem salto entre fases",max_camera_step < deg_to_rad(4))
	check("Fade encerra a demo antes de contato",progress.demo_finished and flow.phase == "finished" and deer.all(func(a):return a.global_position.distance_to(player.global_position) > 2.0))
	var ending = flow._end_canvas.get_child(0)
	check("Fade conclui e mostra o epílogo com opção de repetir",get_node("/root/SceneTransitionManager")._fade.color.a == 1 and ending != null and ending.find_child("EndingTitle", true, false) != null and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	check("Sequência executou fases na ordem",phases == ["walking_to_center","centered","deer_approaching","fading_out","finished"])
	check("Nenhum cervo aplicou dano na cutscene",player.health == player.max_health)
	await tree.process_frame
	var replay: Button = ending.replay_button
	check("Epílogo dá foco à opção de repetir", replay.has_focus())
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	Input.parse_input_event(confirm)
	await tree.process_frame
	confirm.pressed = false
	Input.parse_input_event(confirm)
	var replay_wait := 0.0
	while tree.current_scene == room and replay_wait < 3.0:
		await tree.create_timer(.05).timeout
		replay_wait += .05
	await tree.create_timer(.7).timeout
	check("A do gamepad repete a demo e limpa o sonho",not progress.is_dream and progress.day == 1 and not flow.input_locked and tree.current_scene.scene_file_path == FOREST and not tree.current_scene.get_node("DreamEvent").visible)
	finish()

func walk_to_event(player: CharacterBody3D,target: Vector3) -> void:
	var room := tree.current_scene
	var path := NavigationServer3D.map_get_path(room.get_node("Navegacao").get_navigation_map(),player.global_position,target,true)
	var count := 0
	for point in path:
		while Vector2(point.x-player.position.x,point.z-player.position.z).length() > .3 and count < 2800 and not flow.input_locked:
			var offset := point-player.global_position
			player.rotation.y = atan2(-offset.x,-offset.z)
			Input.action_press("move_forward")
			await tree.physics_frame
			count += 1
		if flow.input_locked: break
	Input.action_release("move_forward")

func travel(name_text: String) -> void:
	var room := tree.current_scene
	var player: Node3D = room.get_node("Player")
	var door: Node3D = room.get_node(name_text)
	player.global_position = door.get_node("Arrival").global_position
	door.interact(player)
	await tree.scene_changed
	await tree.create_timer(.8).timeout

func ui_text() -> String:
	var result := ""
	for node in ui.content.get_children():
		if node is Label: result += node.text+"\n"
	return result

func check(title: String,value: bool) -> void:
	checks.append({"name":title,"passed":value})
	print("DREAM ","OK " if value else "FAIL ",title)

func finish() -> void:
	var failed := checks.filter(func(c):return not c.passed)
	var f := FileAccess.open("res://tests/dream_finale_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size(),"phases":phases,"walk_frames":trace.size()},"  "))
	print("DREAM_RESULT ",checks.size()-failed.size(),"/",checks.size()," ",failed)
	tree.quit(0 if failed.is_empty() else 1)

func _exit_tree() -> void:
	Input.action_release("move_forward")

func _physics_process(_delta: float) -> void:
	if not camera_tracking or not is_instance_valid(tree.current_scene):
		return
	var player := tree.current_scene.get_node_or_null("Player")
	if player == null:
		return
	var view := Vector2(player.rotation.y,player.camera.rotation.x)
	max_camera_step = maxf(max_camera_step,maxf(absf(wrapf(view.x-previous_view.x,-PI,PI)),absf(view.y-previous_view.y)))
	previous_view = view
