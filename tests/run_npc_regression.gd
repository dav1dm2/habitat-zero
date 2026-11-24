extends SceneTree
## Executar: godot --headless --path . --fixed-fps 60 --script res://tests/run_npc_regression.gd
var failures: Array[String] = []
var checks: int = 0
var room: Node3D
var progress: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		print("FAIL: ", description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func place(actor: Node3D, x: float, z: float, lift: float = 0.05) -> void:
	actor.global_position = room.ground(x, z, lift)
	if actor is CharacterBody3D:
		actor.velocity = Vector3.ZERO

func _run() -> void:
	progress = root.get_node("ReserveState")
	progress.reset()
	room = load("res://scenes/levels/npc_test_range.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await frames(45)
	var player: CharacterBody3D = room.player
	player.set_physics_process(false)
	player.max_health = 10000
	player.health = 10000
	check(room.navigation_ready, "Navegação gerada em terreno irregular")
	check(room.region.navigation_mesh.get_polygon_count() > 10, "Malha tem polígonos transitáveis")
	check(get_nodes_in_group("animals").size() == 8, "Quatro espécies: cervo, gambá, três Kiwi e três Pukeko")
	var grounded := true
	for animal in get_nodes_in_group("animals"):
		grounded = grounded and animal.is_on_floor() and absf(animal.global_position.y - room.terrain_height(animal.global_position.x, animal.global_position.z)) < 0.25
	check(grounded, "Todos os animais apoiados nas colinas após queda inicial")
	var deer: CharacterBody3D = room.get_node("Deer")
	place(player, deer.global_position.x, deer.global_position.z + 2.0, 0.9)
	var start := deer.global_position
	await frames(40)
	check(deer.state == "fugindo" and deer.global_position.distance_to(start) > 0.6, "Cervo foge fisicamente da aproximação")
	room.test_action("fertilize")
	place(player, deer.global_position.x, deer.global_position.z + 2.0, 0.9)
	await frames(10)
	check(deer.state == "observando", "Cinco arbustos substituem fuga por tolerância")
	# Parede bloqueia percepção; navegação precisa ir até a passagem ao sul.
	place(deer, 3, -5)
	place(player, 7, -5, 0.9)
	await frames(2)
	check(not deer.can_see(player), "Parede impede detecção e ataque através dela")
	var map: RID = deer.agent.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, room.ground(2,-5), room.ground(9,-5), true)
	var uses_gap := false
	for point in path:
		if point.z > 2.5:
			uses_gap = true
	check(path.size() >= 3 and uses_gap, "Caminho entre lados contorna parede pela passagem")
	place(player, -34, 22, 0.9)
	place(deer, 2, -5)
	deer.home = room.ground(9, -5)
	deer.state = "retornando"
	deer._goal_timer = 0.0
	deer.walk_speed = 5.0
	await frames(500)
	check(deer.global_position.x > 6 and deer.global_position.distance_to(deer.home) < 2.0, "Cervo percorre caminho real ao redor da parede em terreno inclinado")
	deer.set_physics_process(false)
	var skunk: CharacterBody3D = room.get_node("Skunk")
	place(player, skunk.home.x, skunk.home.z + 1.0, 0.9)
	var health: float = player.health
	await frames(110)
	check(player.health == health, "Gambá não agride no Dia 1")
	room.test_action("day")
	place(skunk, skunk.home.x, skunk.home.z)
	place(player, skunk.home.x, skunk.home.z + 1.0, 0.9)
	health = player.health
	await frames(25)
	check(player.health == health and skunk.state == "aviso", "Gambá avisa antes de causar dano no Dia 2")
	await frames(90)
	check(player.health < health, "Gambá causa dano após preparação")
	place(player, -34, 22, 0.9)
	await frames(15)
	check(skunk.state in ["retornando", "comendo"], "Gambá abandona perseguição fora do território")
	skunk.set_physics_process(false)
	# Grupo de Kiwi: alerta, fuga e defesa com ovos.
	var kiwis: Array = room.kiwi_group.members
	place(player, 16, -7, 0.9)
	await frames(30)
	var fleeing := true
	for kiwi in kiwis:
		fleeing = fleeing and kiwi.state == "fugindo"
	check(fleeing, "Três Kiwi compartilham alerta e fogem juntos sem ovos")
	room.kiwi_group.set_eggs(true)
	for index in range(kiwis.size()):
		place(kiwis[index], 15.0 + index, -10)
		kiwis[index].walk_speed = 0.0
		kiwis[index].run_speed = 0.0
	place(player, 16, -9.1, 0.9)
	health = player.health
	await frames(25)
	check(player.health == health, "Kiwi com ovos avisa antes de atacar")
	await frames(90)
	check(player.health < health, "Kiwi defende ninho com ovos")
	place(player, 10, 18, 0.9)
	await frames(100)
	var defending := false
	for kiwi in kiwis:
		defending = defending or kiwi.state in ["vigia", "retornando"]
		kiwi.set_physics_process(false)
	check(defending, "Kiwi volta à guarda após afastamento")
	# Contato coletivo: fixar posições elimina variação do cerco durante o teste.
	var birds: Array = room.pukeko_group.members
	for bird in birds:
		bird.walk_speed = 0
		bird.run_speed = 0
	place(player, 24, 8, 0.9)
	place(birds[0], 24.8, 8)
	place(birds[1], 28, 8)
	place(birds[2], 24, 12)
	health = player.health
	await frames(120)
	check(room.pukeko_group.contact_count(player) == 1 and player.health == health, "Pukeko isolado em contato não causa dano")
	place(birds[1], 23.2, 8)
	await frames(12)
	check(room.pukeko_group.contact_count(player) == 2, "Dois contatos simultâneos reconhecidos no mesmo grupo")
	# Sair durante preparação deve cancelar o impacto dos dois atacantes.
	place(birds[1], 28, 8)
	await frames(45)
	check(player.health == health, "Perder segundo contato antes do impacto cancela dano")
	place(birds[1], 23.2, 8)
	await frames(90)
	check(player.health < health, "Dois Pukeko em contato permitem ataque com preparação")
	place(player, 10, 22, 0.9)
	await frames(110)
	check(not is_instance_valid(room.pukeko_group.target), "Grupo Pukeko esquece invasor fora da área")
	for bird in birds:
		bird.set_physics_process(false)
	# Proximidade horizontal não permite atacar através da parede ou de um patamar.
	place(skunk, 4.1, -5)
	place(player, 5.4, -5, 0.9)
	await frames(2)
	check(not skunk.in_attack_range(player), "Ataque em distância curta continua bloqueado pela parede")
	place(player, 4.1, -5, 4.0)
	check(not skunk.in_attack_range(player), "Jogador em outro patamar não é atingido pela distância horizontal")
	place(player, 10, 22, 0.9)
	# Buzzy só inicia após energia e não duplica progresso.
	progress.power_restored = false
	progress.briefing_heard = false
	room.get_node("Buzzy").interact(player)
	check(not progress.briefing_heard, "Buzzy não inicia briefing sem energia")
	room.test_action("power")
	room.get_node("Buzzy").interact(player)
	room.get_node("Buzzy").interact(player)
	check(progress.briefing_heard, "Buzzy registra briefing e permite lembrete")
	progress.fertilized_ids.clear()
	var robot: CharacterBody3D = room.get_node("ServiceRobot")
	# Uma parede impede trabalhar através dela, mesmo perto do alvo.
	var service: Node3D = room.get_node("NavigationRegion3D/ServiceTarget")
	var blocker: StaticBody3D = room._box("TemporaryBlocker", Vector3(0.3, 3, 3), room.ground(-3.2,15,1.5), Color.GRAY)
	place(robot, -4, 15)
	await frames(2)
	check(not robot._can_service(service), "Robô não executa serviço através de obstáculo sólido")
	blocker.queue_free()
	await frames(2)
	place(robot, -6, 15)
	robot.interact(player)
	await frames(350)
	check(progress.robot_service_done and robot.state == "aguardando", "Robô navega e conclui seu serviço")
	check(progress.fertilized_ids.is_empty(), "Robô não conclui a fertilização manual do jogador")
	# Checkpoint preserva Dia 1 e desfaz apenas eventos posteriores do Dia 2.
	for index in range(5):
		progress.fertilize(index)
	progress.advance_test_day()
	progress.fertilize(99)
	progress.restart_day()
	check(progress.day == 2 and progress.fertilized_ids.size() == 5 and progress.power_restored, "Reinício do Dia 2 preserva resultados do Dia 1 e remove progresso posterior")
	# Transições reais de ida e volta, usando a porta pareada existente.
	room.get_node("DoorBack").interact(player)
	await frames(10)
	check(current_scene.name == "MechanicsTestRoom", "Porta do cenário NPC retorna à sala mecânica")
	var mechanics: Node3D = current_scene
	mechanics.get_node("DoorToNPCTest").interact(mechanics.get_node("Player"))
	await frames(45)
	check(current_scene.name == "NPCTestRange", "Porta da sala mecânica entra no cenário NPC")
	check(progress.day == 2 and progress.deer_tolerant() and progress.robot_service_done, "Progresso de NPCs persiste após trocar de cena duas vezes")
	print("RESULTADO: %d verificações, %d falhas" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
