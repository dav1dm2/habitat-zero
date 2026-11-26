extends Node
const H1 := "res://scenes/levels/habitat_1.tscn"
const INTERIOR := "res://scenes/levels/attis_interior.tscn"
const FOREST := "res://scenes/levels/attis_forest.tscn"
var tree: SceneTree
var checks: Array = []
var room: Node3D
var p: CharacterBody3D
var inv: Node
var progress: Node
var session: Node

func run() -> void:
	tree = get_tree()
	progress = get_node("/root/ReserveState")
	session = get_node("/root/DemoSession")
	progress.reset()
	session.campaign_started = false
	session.room_items.clear()
	session.storage.clear()
	tree.change_scene_to_file(INTERIOR)
	await tree.scene_changed
	await tree.create_timer(0.6).timeout
	refresh()
	progress.power_restored = true
	progress.briefing_heard = true
	progress.changed.emit()
	inv.import_inventory({})
	await aim(room.get_node("ColetorA"),Vector3(0,0.2,0))
	press("pickup_item")
	await tree.process_frame
	await aim(room.get_node("ColetorB"),Vector3(0,0.2,0))
	press("pickup_item")
	await tree.process_frame
	check("Dois coletores físicos recolhidos",inv.slots[0] != null and inv.slots[1] != null)
	if inv.slots[0] == null or inv.slots[1] == null:
		finish()
		return
	await travel("DoorExit")
	inv.selected_slot = 0
	for i in range(1,4):
		await aim(room.get_node("ArbustosDePesquisa/Arbusto%02d"%i),Vector3(0,0.6,0))
		press("use_item")
	check("Attis 3/3 antes da visita ao habitat",inv.slots[0].sample_origin == "attis" and inv.slots[0].sample_ids.size() == 3)
	for id in range(1000,1005):
		progress.fertilize(id)
	await travel("DoorToInterior")
	await travel("PortaHabitat1")
	check("H1 acessível pela porta e reconhecido como campanha",room.scene_file_path == H1 and session.is_campaign(room))
	check("Chegada pareada na plataforma",p.position.distance_to(room.get_node("DoorToInterior/Arrival").global_position) < 0.5 and p.is_on_floor())
	check("Inventário preserva as duas origens independentes",inv.slots[0].sample_ids.size() == 3 and inv.slots[1].sample_ids.is_empty())
	var animals: Array = tree.get_nodes_in_group("animals").filter(func(a):return room.is_ancestor_of(a))
	check("Seis aves reais instanciadas",animals.size() == 6 and animals.filter(func(a):return a.species == 2).size() == 3 and animals.filter(func(a):return a.species == 3).size() == 3)
	var kiwi: Node3D = room.get_node("Fauna/KiwiGroup")
	var pack: Node3D = room.get_node("Fauna/CasuarioGroup")
	check("Grupos locais de três e ninho ocupado",kiwi.members.size() == 3 and pack.members.size() == 3 and kiwi.has_eggs)
	check("Plataforma fora do cerco",not pack.inside_habitat(p) and not is_instance_valid(pack.target))
	check("Três plantas de coleta, sem tarefa artificial de fertilização",room.get_sample_bushes().size() == 3 and room.get_room_bushes().is_empty())
	check("Robô mantém base interna durante visita",get_node("/root/ReserveSimulation").base_room_key == INTERIOR and is_instance_valid(get_node("/root/ReserveSimulation").robot) and get_node("/root/ReserveSimulation").rooms.size() == 3)
	check("Navegação persistida e teto/abertura presentes",room.get_node("Navegacao").navigation_mesh.get_polygon_count() > 20 and room.has_node("FormacaoRochosa/TetoComAberturaNatural") and room.has_node("FormacaoRochosa/CupulaDePesquisa"))
	# Walk the real collision geometry with normal movement. Isolate fauna while validating circulation.
	for animal in animals:
		animal.set_physics_process(false)
	kiwi.set_physics_process(false)
	pack.set_physics_process(false)
	p.set_physics_process(true)
	p.camera.rotation = Vector3.ZERO
	for point in ["CenterApproach","SampleApproach1","SampleApproach2","SampleApproach3","ObservationPoint"]:
		var reached: bool = await walk_to(room.get_node(point).global_position)
		check("Circulação física até "+point,reached and p.is_on_floor())
		if point.begins_with("Sample"):
			var i := int(point.right(1))
			var bush: Node3D = room.get_node("ArbustosDePesquisa/Arbusto%02d"%i)
			p.camera.look_at(bush.global_position+Vector3(0,0.7,0))
			if i == 1:
				inv.selected_slot = 0
				press("use_item")
				check("Coletor cheio de Attis não mistura H1",inv.slots[0].sample_ids.size() == 3 and inv.slots[0].sample_origin == "attis")
			inv.selected_slot = 1
			press("use_item")
			check("M1 coleta H1 %d/3 sem consumir"%i,inv.slots[1] != null and inv.slots[1].sample_ids.size() == i)
			press("use_item")
			check("Arbusto H1 repetido não duplica %d"%i,inv.slots[1].sample_ids.size() == i)
	# Independent physical behaviour in the actual map.
	for animal in animals:
		animal.set_physics_process(true)
	kiwi.set_physics_process(true)
	pack.set_physics_process(true)
	p.health = 10000
	p.max_health = 10000
	p.global_position = Vector3(0,1.56,14)
	await tree.create_timer(0.3).timeout
	check("Entrada continua permitindo observação segura",not is_instance_valid(pack.target))
	p.global_position = Vector3(0,0.93,0)
	await tree.create_timer(12.0).timeout
	check("Casuários detectam e se deslocam para o cerco",pack.pack_state in ["formando cerco","cercando","avançando"] and pack.target == p and pack.members.any(func(a):return a.global_position.distance_to(a.home)>1.0))
	check("Aves apoiadas no solo",animals.all(func(a):return a.is_on_floor() and a.position.y > -1))
	var minimum := INF
	for a in animals:
		for b in animals:
			if a != b:
				minimum = minf(minimum,a.global_position.distance_to(b.global_position))
	check("Espaçamento entre as aves",minimum > 0.9)
	# Deterministic attack condition check, then real group retreat on exit.
	for a in pack.members:
		a.set_physics_process(false)
	pack.set_physics_process(false)
	pack.pack_state = "avançando"
	pack.target = p
	p.global_position = Vector3(0,0.93,0)
	pack.members[0].global_position = Vector3(0.8,0.05,0)
	pack.members[1].global_position = Vector3(5,0.05,0)
	pack.members[2].global_position = Vector3(-5,0.05,0)
	await tree.physics_frame
	pack.members[0].player = p
	check("Casuário isolado não pode causar dano",pack.contact_count(p) == 1 and not pack.members[0]._attack_allowed())
	pack.members[1].global_position = Vector3(-0.8,0.05,0)
	await tree.physics_frame
	check("Dois contatos permitem ataque",pack.contact_count(p) == 2 and pack.members[0]._attack_allowed())
	var before: float = p.health
	pack.members[0]._try_attack()
	pack.members[0]._update_attack(0.5)
	check("Ataque aplica dano ao jogador",p.health < before)
	p.global_position = Vector3(0,1.56,14)
	pack.set_physics_process(true)
	for a in pack.members:
		a.set_physics_process(true)
	await tree.create_timer(0.3).timeout
	check("Saída do recinto encerra ataque e causa retirada",pack.pack_state == "fugindo")
	# Nests are optional detours; entering their territory warns/defends, leaving returns to guard.
	p.global_position = Vector3(-10.3,1.1,-9)
	await tree.create_timer(0.3).timeout
	check("Kiwi alerta o grupo ao aproximar do ninho",kiwi.target == p and kiwi.members.any(func(a):return a.state in ["aviso","perseguindo","atacando","recuperando"]))
	p.global_position = Vector3(0,1.56,14)
	await tree.create_timer(2).timeout
	check("Kiwi abandona perseguição ao recuar",kiwi.members.all(func(a):return a.state in ["vigia","retornando"]))
	await travel("DoorToInterior")
	check("Retorno às instalações preserva os dois coletores cheios",inv.slots[0].sample_ids.size() == 3 and inv.slots[1].sample_ids.size() == 3)
	check("Retorno olha para dentro do corredor",(-p.global_basis.z).dot(Vector3.BACK) > 0.99)
	await aim(room.get_node("Laboratorio"),Vector3.ZERO)
	inv.selected_slot = 1
	press("pickup_item")
	check("Bancada entrega H1 e esvazia somente a unidade selecionada",progress.analysed_samples == ["habitat1"] and inv.slots[1].sample_ids.is_empty() and inv.slots[0].sample_ids.size() == 3)
	check("Só H1 não libera descanso",not session.can_sleep())
	press("pickup_item")
	check("Bancada entrega Attis na segunda interação",progress.analysed_samples.size() == 2 and inv.slots[0].sample_ids.is_empty())
	check("Duas entregas e fertilização liberam descanso",session.can_sleep())
	var ui := get_node("/root/DemoInterface")
	ui.show_notebook()
	var text := ""
	for child in ui.content.get_children():
		if child is Label:
			text += child.text
	check("Caderno confirma as duas origens e orienta descanso",text.contains("✓ Coletar e entregar amostras de Attis") and text.contains("✓ Coletar e entregar amostras do Habitat 1") and text.contains("já pode descansar"))
	ui.close_modal()
	p.set_physics_process(true)
	room.get_node("Cama").interact(p)
	await session.woke_up
	await tree.process_frame
	check("Cama avança de verdade ao Dia 2",progress.day == 2 and session._checkpoint_scene == INTERIOR)
	# Full collector drop/cross/restore in the new scene.
	await travel("PortaHabitat1")
	for i in range(4,7):
		await aim(room.get_node("ArbustosDePesquisa/Arbusto%02d"%i),Vector3(0,0.7,0))
		inv.selected_slot = 0
		press("use_item")
	check("Coletor esvaziado pode ser reutilizado no H1",inv.slots[0].sample_ids.size() == 3 and inv.slots[0].sample_origin == "habitat1")
	press("drop_item")
	await tree.process_frame
	await travel("DoorToInterior")
	await travel("PortaHabitat1")
	var dropped: Array = tree.get_nodes_in_group("world_items").filter(func(a):return room.is_ancestor_of(a))
	check("Ferramenta largada no H1 persiste sem duplicação",dropped.size() == 1 and dropped[0].definition.sample_ids.size() == 3 and inv.slots[0] == null)
	p.take_damage(p.health+1)
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	refresh()
	check("Morte no H1 retorna ao checkpoint do alojamento",room.scene_file_path == INTERIOR and progress.day == 2 and inv.slots[0] != null and inv.slots[0].sample_ids.is_empty())
	check("Morte preserva histórico do Dia 1 e tarefas renovadas",progress.analysed_samples.is_empty() and progress.analysis_history["1"].size() == 2)
	await travel("PortaHabitat1")
	dropped = tree.get_nodes_in_group("world_items").filter(func(a):return room.is_ancestor_of(a))
	check("Morte não duplica coletor largado depois do checkpoint",dropped.is_empty())
	finish()

func refresh() -> void:
	room = tree.current_scene
	p = room.get_node("Player")
	inv = p.get_node("Inventory")

func aim(target: Node3D, offset: Vector3) -> void:
	p.set_physics_process(false)
	p.global_position = target.global_position + Vector3(0,0.6,2)
	p.velocity = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	p.camera.look_at(target.global_position+offset)

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	inv.handle_input(event)

func travel(door_name: String) -> void:
	get_node("/root/DemoInterface").close_modal()
	var door: Node3D = room.get_node(door_name)
	p.set_physics_process(true)
	p.global_position = door.get_node("Arrival").global_position
	p.camera.rotation = Vector3.ZERO
	door.interact(p)
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	refresh()

func walk_to(target: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(room.get_node("Navegacao").get_navigation_map(),p.global_position,target,true)
	if path.is_empty():
		return false
	var count := 0
	for point in path:
		while Vector2(point.x-p.position.x,point.z-p.position.z).length() > 0.3 and count < 1300:
			var offset := point-p.global_position
			p.rotation.y = atan2(-offset.x,-offset.z)
			Input.action_press("move_forward")
			await tree.physics_frame
			count += 1
	Input.action_release("move_forward")
	await tree.create_timer(0.2).timeout
	print("H1_WALK ", {"target":target,"position":p.global_position,"floor":p.is_on_floor(),"frames":count,"path":path})
	return Vector2(target.x-p.position.x,target.z-p.position.z).length() < 0.8

func check(title: String, value: bool) -> void:
	checks.append({"name":title,"passed":value})
	print("H1 ","OK " if value else "FAIL ",title)

func finish() -> void:
	var failed := checks.filter(func(c):return not c.passed)
	var file := FileAccess.open("res://tests/habitat_1_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size()},"  "))
	print("HABITAT_1_RESULT ",checks.size()-failed.size(),"/",checks.size()," ",failed)
	tree.quit(0 if failed.is_empty() else 1)

func _exit_tree() -> void:
	Input.action_release("move_forward")
