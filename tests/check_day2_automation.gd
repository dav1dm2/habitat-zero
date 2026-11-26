extends Node
var tree: SceneTree
var progress: Node
var session: Node
var sim: Node
var ui: Node
var checks: Array = []
var deliveries: Array = []
var last_origins: Array = []
const INTERIOR := "res://scenes/levels/attis_interior.tscn"
const H1 := "res://scenes/levels/habitat_1.tscn"

func run() -> void:
	tree = get_tree()
	progress = get_node("/root/ReserveState")
	session = get_node("/root/DemoSession")
	sim = get_node("/root/ReserveSimulation")
	ui = get_node("/root/DemoInterface")
	progress.reset()
	session.campaign_started = false
	session.room_items.clear()
	session.storage.clear()
	tree.change_scene_to_file(INTERIOR)
	await tree.scene_changed
	await tree.create_timer(.8).timeout
	var room := tree.current_scene
	var p: Node3D = room.get_node("Player")
	var inv: Node = p.get_node("Inventory")
	progress.power_restored = true
	progress.briefing_heard = true
	progress.changed.emit()
	check("Três áreas de trabalho carregadas mesmo nas instalações",sim.rooms.size() == 3 and sim.rooms.has(H1))
	check("Dia 1 só tem três plantas visíveis no H1",sim.rooms[H1].get_node("ArbustosDePesquisa").get_children().filter(func(b):return b.visible and b.collision_layer != 0).size() == 3)
	sim.robot.interact(p)
	await tree.create_timer(.3).timeout
	check("Dia 1 não permite ativar robô",not progress.robot_activated and sim.robot.state == "adormecido")
	ui.show_buzzy()
	check("Buzzy explica trabalho manual no Dia 1",words().contains("hoje as tarefas são manuais"))
	ui.close_modal()
	# Day 1 is established test setup; transition uses the actual bed/session.
	for id in range(1000,1005): progress.fertilize(id)
	progress.register_analysis("attis")
	progress.register_analysis("habitat1")
	inv.import_inventory({})
	await aim(room.get_node("ColetorA"),Vector3(0,.2,0))
	press("pickup_item")
	await tree.process_frame
	await aim(room.get_node("ColetorB"),Vector3(0,.2,0))
	press("pickup_item")
	await tree.process_frame
	check("Dois coletores do jogador preservados",inv.slots[0] != null and inv.slots[1] != null)
	inv.slots[0].collect_sample("habitat1",2000,1)
	p.set_physics_process(true)
	room.get_node("Cama").interact(p)
	await session.woke_up
	await tree.process_frame
	await tree.process_frame
	check("Cama inicia Dia 2 e renova entregas",progress.day == 2 and progress.analysed_samples.is_empty() and progress.analysis_history["1"].size() == 2)
	check("Dia 2 anuncia automação imediatamente",ui.modal_kind == "buzzy" and words().contains("Agora você pode ativar o robô") and p.controls_locked)
	check("Dia 2 tem seis plantas no H1 sem duplicação",sim.rooms[H1].get_node("ArbustosDePesquisa").get_child_count() == 6 and sim.rooms[H1].get_node("ArbustosDePesquisa").get_children().all(func(b):return b.visible and b.collision_layer != 0))
	check("Dia 2 permite todos os arbustos presentes nas duas áreas",sim.rooms[sim.ATTIS].get_sample_bushes().size() == 45 and sim.rooms[H1].get_sample_bushes().size() == 6)
	check("Plantas do dia anterior continuam disponíveis para coleta",sim.rooms[H1].get_sample_bushes().has(sim.rooms[H1].get_node("ArbustosDePesquisa/Arbusto01")) and inv.slots[1].sample_ids.is_empty())
	check("Coletor antigo não pode misturar dia novo",inv.slots[0].collect_sample("habitat1",2003,2).contains("dia anterior") and inv.slots[0].sample_ids.size() == 1)
	check("Contador diário exclui amostras antigas",ui._sample_count("habitat1") == 0)
	sim.robot.interact(p)
	check("Ativação aguarda explicação de Buzzy",not progress.robot_activated)
	for child in ui.action_buttons():
		if child.text.begins_with("Entendido"):
			child.pressed.emit()
			break
	check("Confirmação libera automação",progress.day2_briefing_heard and not ui.modal.visible)
	await aim(room.get_node("Laboratorio"),Vector3.ZERO)
	inv.selected_slot = 0
	press("pickup_item")
	check("Bancada esvazia amostra antiga sem concluir hoje",inv.slots[0].sample_ids.is_empty() and progress.analysed_samples.is_empty())
	p.set_physics_process(true)
	# Checkpoint with daily tasks pending; later death must undo automation and deliveries.
	session.checkpoint_day(room)
	ui.show_notebook()
	check("Caderno mostra tarefas novas e ativação",words().contains("□ Ativar robô ajudante") and words().contains("Attis (0/3)") and words().contains("Habitat 1 (0/3)"))
	ui.close_modal()
	p.global_position = room.get_node("BuzzyApproach").global_position+Vector3.UP*.9
	sim.robot.interact(p)
	check("Dia 2 permite ativar robô",progress.robot_activated)
	progress.changed.connect(record_delivery)
	Engine.time_scale = 2.0
	await travel("PortaHabitat1")
	check("Visita do jogador ao H1 preserva ajudante",progress.robot_activated and sim.rooms.size() == 3 and sim.robot.sample_collectors.size() == 2)
	var visited: Array = []
	var trace: Array = []
	var elapsed := 0.0
	var next_trace := 0.0
	var returned := false
	while elapsed < 380:
		await tree.create_timer(.25).timeout
		elapsed += .25
		if sim.robot_room_key not in visited: visited.append(sim.robot_room_key)
		if elapsed >= next_trace:
			trace.append({"t":elapsed,"room":sim.robot_room_key,"pos":str(sim.room_for_robot().to_local(sim.robot.global_position)),"state":sim.robot.state,"stalled":sim.robot.stalled,"samples":sim.robot.sample_count(),"fertilized":progress.fertilized_ids.size(),"origins":progress.analysed_samples.duplicate()})
			next_trace = elapsed+2
		returned = progress.fertilized_ids.size() == 10 and progress.analysed_samples.size() == 2 and sim.robot_room_key == INTERIOR and sim.robot.state == "na base"
		if returned: break
	Engine.time_scale = 1.0
	var f := FileAccess.open("res://tests/day2_robot_trace.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"elapsed":elapsed,"visited":visited,"trace":trace,"deliveries":deliveries},"  "))
	check("Robô visita Attis e H1 sem trocar a cena do jogador",visited.has(sim.ATTIS) and visited.has(H1) and tree.current_scene.scene_file_path == H1)
	check("Robô fertiliza os cinco arbustos novos",progress.fertilized_ids.size() == 10)
	check("Robô coleta três de cada origem e entrega ambas",progress.analysed_samples.size() == 2 and deliveries.size() == 2)
	check("Entregas acontecem fisicamente na bancada",deliveries.size() == 2 and deliveries.all(func(d):return d.room == INTERIOR and d.lab_distance < .8))
	check("Robô retorna à base após concluir tudo",returned)
	check("Nenhum coletor do jogador foi consumido pelo robô",tree.current_scene.get_node("Player/Inventory").slots[0] != null and tree.current_scene.get_node("Player/Inventory").slots[1] != null and tree.current_scene.get_node("Player/Inventory").slots[0].sample_ids.is_empty())
	# Actual manual collection in three plants not yet used by the robot today.
	var current: Node3D = tree.current_scene
	inv = current.get_node("Player/Inventory")
	inv.selected_slot = 0
	for bush in current.get_sample_bushes().filter(func(b):return not progress.was_sampled_today(b.sample_origin,b.bush_id)).slice(0,3):
		await aim(bush,Vector3(0,.7,0))
		press("use_item")
	check("M1 coleta três plantas do H1 ainda não usadas pelo robô",inv.slots[0].sample_ids.size() == 3 and inv.slots[0].sample_day == 2)
	await travel("DoorToInterior")
	inv = tree.current_scene.get_node("Player/Inventory")
	await aim(tree.current_scene.get_node("Laboratorio"),Vector3.ZERO)
	press("pickup_item")
	check("Entrega concorrente não duplica conclusão",progress.analysed_samples.size() == 2 and inv.slots[0].sample_ids.is_empty())
	check("Tarefas do Dia 2 estão completas",session.can_sleep())
	# A partially filled robot buffer is discarded when player already completed that origin.
	sim.robot.sample_collectors["attis"].collect_sample("attis",1005,2)
	progress.changed.emit()
	check("Entrega do jogador cancela coleta redundante do robô",sim.robot.sample_collectors["attis"].sample_ids.is_empty())
	session.restart_day()
	await tree.scene_changed
	await tree.create_timer(.8).timeout
	check("Morte reinicia tarefas atuais sem perder histórico",progress.day == 2 and progress.analysed_samples.is_empty() and progress.analysis_history["1"].size() == 2 and not progress.robot_activated)
	check("Crescimento não duplica após reinício",sim.rooms[H1].get_node("ArbustosDePesquisa").get_child_count() == 6)
	finish()

func record_delivery() -> void:
	for origin in progress.analysed_samples:
		if origin not in last_origins:
			var room: Node3D = sim.room_for_robot()
			var marker := room.get_node_or_null("LabApproach") as Node3D
			deliveries.append({"origin":origin,"room":sim.robot_room_key,"lab_distance":sim.robot.global_position.distance_to(marker.global_position) if marker != null else INF})
	last_origins = progress.analysed_samples.duplicate()

func aim(target: Node3D, offset: Vector3) -> void:
	var p: CharacterBody3D = tree.current_scene.get_node("Player")
	p.set_physics_process(false)
	p.global_position = target.global_position+Vector3(0,.6,2)
	p.velocity = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	p.camera.look_at(target.global_position+offset)

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	tree.current_scene.get_node("Player/Inventory").handle_input(event)

func travel(name_text: String) -> void:
	ui.close_modal()
	var room: Node3D = tree.current_scene
	var p: CharacterBody3D = room.get_node("Player")
	var door: Node3D = room.get_node(name_text)
	p.set_physics_process(true)
	p.global_position = door.get_node("Arrival").global_position
	p.camera.rotation = Vector3.ZERO
	door.interact(p)
	await tree.scene_changed
	await tree.create_timer(.7).timeout

func words() -> String:
	var result := ""
	for child in ui.content.get_children():
		if child is Label: result += child.text+"\n"
	return result

func check(title: String, value: bool) -> void:
	checks.append({"name":title,"passed":value})
	print("DAY2 ","OK " if value else "FAIL ",title)

func finish() -> void:
	var failed := checks.filter(func(c):return not c.passed)
	var f := FileAccess.open("res://tests/day2_automation_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size()},"  "))
	print("DAY2_RESULT ",checks.size()-failed.size(),"/",checks.size()," ",failed)
	tree.quit(0 if failed.is_empty() else 1)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
