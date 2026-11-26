extends Node
var checks: Array = []
var tree: SceneTree
var session: Node
var progress: Node
var ui: Node
const FOREST := "res://scenes/levels/attis_forest.tscn"
const INTERIOR := "res://scenes/levels/attis_interior.tscn"

func run() -> void:
	tree = get_tree()
	session = get_node("/root/DemoSession")
	progress = get_node("/root/ReserveState")
	ui = get_node("/root/DemoInterface")
	progress.reset()
	session.campaign_started = false
	session.room_items.clear()
	session.storage.clear()
	tree.change_scene_to_file(FOREST)
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	var room := tree.current_scene
	var p: Node3D = room.get_node("Player")
	var inventory: Node = p.get_node("Inventory")
	check("Itens iniciais: carta e fusível", inventory.slots[0] != null and inventory.slots[0].item_id == &"arrival_letter" and inventory.slots[1].item_id == &"fuse")
	check("Névoa suavizada até 26 m", room.get_node("Ambiente_Nevoeiro").environment.fog_depth_end == 26.0)
	ui.show_letter()
	check("Carta arquivada e movimento bloqueado", progress.letter_read and p.controls_locked and ui.modal.visible)
	ui.close_modal()
	inventory.selected_slot = 0
	inventory._drop_selected_item()
	await tree.create_timer(2.5).timeout
	var items := items_in(room)
	check("Q libera slot e cria uma carta física", inventory.slots[0] == null and items.size() == 1 and items[0].definition.item_id == &"arrival_letter")
	check("Carta fina não atravessa o terreno após arremesso", items[0].global_position.y > -0.2 and items[0].global_position.z < 69.0)
	items[0].linear_velocity = Vector3.ZERO
	items[0].angular_velocity = Vector3.ZERO
	items[0].sleeping = true
	var letter_transform: Transform3D = items[0].global_transform
	await travel("DoorToInterior")
	letter_transform = session.room_items[FOREST][0].transform
	room = tree.current_scene
	p = room.get_node("Player")
	inventory = p.get_node("Inventory")
	check("Porta entra sem energia", room.scene_file_path == INTERIOR and not progress.power_restored)
	check("Chegada pareada e altura correta", p.global_position.distance_to(room.get_node("DoorExit/Arrival").global_position) < 0.7 and p.is_on_floor())
	check("Inventário preserva slot vazio e fusível", inventory.slots[0] == null and inventory.slots[1] != null and inventory.slots[1].item_id == &"fuse")
	var simulation := get_node("/root/ReserveSimulation")
	check("Robô tem base no carregador interno", simulation.base_room_key == INTERIOR and simulation.robot.global_position.distance_to(room.get_node("RobotBase").global_position) < 0.8)
	simulation.robot.interact(p)
	check("Robô não ativa antes da energia", not progress.robot_activated)
	var nav: RID = room.get_node("Navegacao").get_navigation_map()
	var route: PackedVector3Array = NavigationServer3D.map_get_path(nav, room.get_node("RobotBase").global_position, room.get_node("DoorExit/Arrival").global_position, true)
	check("Carregador conectado à saída pela navegação", not route.is_empty() and route[-1].distance_to(room.get_node("DoorExit/Arrival").global_position) < 1.5)
	p.global_position = room.get_node("PanelApproach").global_position
	p.velocity = Vector3.ZERO
	p.camera.look_at(room.get_node("PowerPanel").global_position)
	var health_before: float = p.health
	await tree.create_timer(0.6).timeout
	check("Radiação causa dano na sala de máquinas", p.health < health_before)
	inventory.selected_slot = 1
	inventory._use_selected_item()
	await tree.create_timer(0.15).timeout
	check("M1 instala e consome fusível", progress.fuse_installed and inventory.slots[1] == null)
	check("Painel abre interface 2D com mouse livre", ui.modal_kind == "power" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var panel: Node = room.get_node("PowerPanel")
	panel.interaction_delay = 0.0
	var damaged: float = p.health
	await tree.create_timer(0.6).timeout
	check("Puzzle não pausa radiação", p.health < damaged)
	panel.press_breaker(0)
	check("Erro reinicia disjuntores e preserva fusível", progress.breaker_progress == 0 and progress.fuse_installed and not progress.power_restored)
	ui.close_modal()
	await travel("DoorExit")
	room = tree.current_scene
	p = room.get_node("Player")
	items = items_in(room)
	check("Carta reaparece uma única vez no retorno", items.size() == 1 and items[0].definition.item_id == &"arrival_letter")
	print("LETTER_POSITION_RESTORE: ", {"saved":letter_transform.origin,"actual":items[0].global_position,"stored":session.room_items[FOREST][0]})
	check("Posição da carta preservada", items.size() == 1 and items[0].global_position.distance_to(letter_transform.origin) < 0.08)
	var rotation_error: float = items[0].global_basis.get_rotation_quaternion().angle_to(letter_transform.basis.get_rotation_quaternion()) if items.size() == 1 else INF
	print("LETTER_ROTATION_ERROR_RADIANS: ", rotation_error)
	check("Rotação da carta preservada com tolerância física de 0,02 rad", rotation_error < 0.02)
	check("Retorno usa porta alta, não spawn da estrada", p.position.z < -70 and p.position.y > 24)
	await travel("DoorToInterior")
	room = tree.current_scene
	p = room.get_node("Player")
	panel = room.get_node("PowerPanel")
	panel.interaction_delay = 0.0
	check("Fusível instalado persiste entre áreas", progress.fuse_installed and not progress.power_restored)
	p.global_position = room.get_node("PanelApproach").global_position
	ui.show_power(panel)
	# Invoke the real UI button callbacks, including the loop-bound index.
	for index in panel.breaker_order:
		ui.content.get_child(4 + index).pressed.emit()
	check("Sequência dos botões restaura energia", progress.power_restored and progress.breaker_progress == 3 and not ui.modal.visible)
	check("Iluminação interna acende", room.get_node("Iluminacao").get_child(0).light_energy > 1.0)
	damaged = p.health
	await tree.create_timer(0.7).timeout
	check("Conserto encerra dano radioativo", is_equal_approx(p.health, damaged))
	p.global_position = room.get_node("BuzzyApproach").global_position + Vector3.UP * 0.9
	p.velocity = Vector3.ZERO
	room.get_node("Buzzy").interact(p)
	check("Buzzy projeta e oferece briefing", room.get_node("Buzzy/Projection").visible and ui.modal_kind == "buzzy" and not progress.briefing_heard)
	for button in ui.action_buttons():
		if button is Button and button.text.begins_with("Entendido"):
			button.pressed.emit()
			break
	check("Confirmação registra briefing e tarefas", progress.briefing_heard and not ui.modal.visible)
	inventory = p.get_node("Inventory")
	room.get_node("FertilizerRepository").interact(p)
	check("Almoxarifado fornece quatro fertilizantes", inventory.slots.all(func(item): return item != null and item.item_id == &"fertilizer"))
	ui.show_storage()
	ui.content.get_child(2).pressed.emit()
	check("Depósito guarda sem duplicar", session.storage.size() == 1 and inventory.slots.filter(func(item):return item != null).size() == 3)
	ui.close_modal()
	simulation.robot.interact(p)
	check("Robô continua bloqueado no Dia 1 após energia", not progress.robot_activated)
	inventory.selected_slot = 1
	inventory._drop_selected_item()
	await tree.create_timer(0.3).timeout
	check("Item pode ser largado também no interior", items_in(room).size() == 1)
	await travel("DoorExit")
	room = tree.current_scene
	p = room.get_node("Player")
	check("Energia e briefing sobrevivem ao retorno", progress.power_restored and progress.briefing_heard)
	check("Cinco arbustos iniciais disponíveis", room.get_room_bushes().size() == 5)
	check("Depósito preservado entre cenas", session.storage.size() == 1)
	items = items_in(room)
	var letter: RigidBody3D = items[0]
	p.position = letter.position + Vector3(0,0.96,2.5)
	p.velocity = Vector3.ZERO
	p.camera.look_at(letter.global_position)
	p.get_node("Inventory")._pickup_aimed_item()
	await tree.process_frame
	check("Carta largada pode ser recolhida", items_in(room).is_empty() and p.get_node("Inventory").slots.any(func(item):return item != null and item.item_id == &"arrival_letter"))
	await travel("DoorToInterior")
	check("Item largado no interior persiste", items_in(tree.current_scene).size() == 1)
	await travel("DoorExit")
	room = tree.current_scene
	check("Carta recolhida não duplica na próxima visita", items_in(room).is_empty())
	p = room.get_node("Player")
	p.take_damage(1000)
	await tree.scene_changed
	await tree.create_timer(0.8).timeout
	room = tree.current_scene
	p = room.get_node("Player")
	inventory = p.get_node("Inventory")
	check("Morte reinicia na chegada de Attis", room.scene_file_path == FOREST and p.position.z > 65)
	check("Morte restaura carta e fusível iniciais", inventory.slots[0] != null and inventory.slots[0].item_id == &"arrival_letter" and inventory.slots[1] != null and inventory.slots[1].item_id == &"fuse")
	check("Morte apaga progresso do dia", not progress.power_restored and not progress.briefing_heard and not progress.fuse_installed and not progress.letter_read)
	check("Morte restaura mundo e depósito do checkpoint", items_in(room).is_empty() and session.storage.is_empty())
	check("Morte fecha modal e recupera vida", not ui.modal.visible and p.health == p.max_health and not p.controls_locked)
	await travel("DoorToInterior")
	room = tree.current_scene
	p = room.get_node("Player")
	p.global_position = room.get_node("PanelApproach").global_position
	p.velocity = Vector3.ZERO
	p.camera.look_at(room.get_node("PowerPanel").global_position)
	inventory = p.get_node("Inventory")
	inventory.selected_slot = 1
	inventory._use_selected_item()
	await tree.create_timer(0.1).timeout
	p.health = 0.1
	check("Interface aberta antes da morte radioativa", ui.modal_kind == "power")
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	room = tree.current_scene
	p = room.get_node("Player")
	check("Morte dentro do puzzle retorna à chegada", room.scene_file_path == FOREST and p.position.z > 65)
	check("Morte dentro do puzzle fecha interface e libera controle", not ui.modal.visible and not p.controls_locked and p.health == p.max_health)
	check("Fusível volta ao inventário após morte no painel", not progress.fuse_installed and p.get_node("Inventory").slots[1].item_id == &"fuse")
	await travel("DoorToInterior")
	room = tree.current_scene
	progress.power_restored = true
	progress.briefing_heard = true
	for id in range(1000,1005):
		progress.fertilize(id)
	room.get_node("Cama").interact(room.get_node("Player"))
	check("Cama não ignora análises pendentes", progress.day == 1 and not session.can_sleep())
	ui.close_modal()
	# Simulate the future analysis subsystem's completion signals, not a player shortcut.
	progress.register_analysis("attis")
	progress.register_analysis("habitat1")
	progress.register_analysis("attis")
	check("Análises registram duas origens sem duplicação", progress.analysed_samples.size() == 2 and session.can_sleep())
	room.get_node("Cama").interact(room.get_node("Player"))
	await session.woke_up
	await tree.process_frame
	check("Cama avança o dia após todos os critérios", progress.day == 2)
	check("Dia 2 disponibiliza dez arbustos", get_node("/root/ReserveSimulation").rooms[FOREST].get_room_bushes().size() == 10)
	room.get_node("Player").take_damage(1000)
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	room = tree.current_scene
	p = room.get_node("Player")
	check("Morte no Dia 2 restaura alojamento e dia correto", room.scene_file_path == INTERIOR and progress.day == 2 and p.global_position.distance_to(room.get_node("DayStart").global_position) < 0.3)
	check("Checkpoint do Dia 2 preserva energia/histórico e renova análises", progress.power_restored and progress.briefing_heard and progress.analysed_samples.is_empty() and progress.analysis_history["1"].size() == 2)
	var failed := checks.filter(func(item):return not item.passed)
	var file := FileAccess.open("res://tests/arrival_integration_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size()}, "  "))
	print("ARRIVAL_INTEGRATION: ", checks.size()-failed.size(), "/", checks.size(), " passed; ", failed)
	tree.quit(0 if failed.is_empty() else 1)

func travel(door_name: String) -> void:
	ui.close_modal()
	var room := tree.current_scene
	var door: Node3D = room.get_node(door_name)
	var p: Node3D = room.get_node("Player")
	p.global_position = door.get_node("Arrival").global_position
	p.velocity = Vector3.ZERO
	door.interact(p)
	await tree.scene_changed
	await tree.create_timer(0.5).timeout

func items_in(room: Node) -> Array:
	return tree.get_nodes_in_group("world_items").filter(func(item):return room.is_ancestor_of(item) and not item.is_queued_for_deletion() and item.definition.item_id != &"sample_collector")

func check(title: String, passed: bool) -> void:
	checks.append({"name":title,"passed":passed})
	print("CHECK ", "OK " if passed else "FAIL ", title)
