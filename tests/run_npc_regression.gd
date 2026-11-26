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
	room.casuario_group.set_physics_process(false)
	var player: CharacterBody3D = room.player
	player.set_physics_process(false)
	player.max_health = 10000
	player.health = 10000
	var static_range := load("res://scenes/levels/npc_test_range.tscn") as PackedScene
	var static_mechanics := load("res://scenes/levels/mechanics_test_room.tscn") as PackedScene
	check(static_range.get_state().get_node_count() > 70 and static_mechanics.get_state().get_node_count() > 50, "As duas cenas contêm geometria e objetos antes de executar o jogo")
	check(room.navigation_ready, "Navegação gerada em terreno irregular")
	check(room.region.navigation_mesh.get_polygon_count() > 10, "Malha tem polígonos transitáveis")
	check(get_nodes_in_group("animals").size() == 8, "Quatro espécies: cervo, gambá, três Kiwi e três casuários")
	var grounded := true
	for animal in get_nodes_in_group("animals"):
		grounded = grounded and animal.is_on_floor() and absf(animal.global_position.y - room.terrain_height(animal.global_position.x, animal.global_position.z)) < 0.25
	check(grounded, "Todos os animais apoiados nas colinas após queda inicial")
	check(room.get_room_bushes().size() == 5, "Dia 1 começa com cinco arbustos")
	var simulation: Node = root.get_node("ReserveSimulation")
	var robot: CharacterBody3D = simulation.robot
	var robot_identity := robot.get_instance_id()
	var spacing_actors: Array[Node3D] = [robot]
	for kind in range(4):
		var actor := room.ANIMALS[kind].instantiate() as Node3D
		actor.position = room.ground(-32 + kind * 0.1, 21, 0.05)
		room.add_child(actor)
		spacing_actors.append(actor)
	robot.global_position = room.ground(-32, 21, 0.05)
	await frames(180)
	var spacing_ok := true
	for i in range(spacing_actors.size()):
		for j in range(i + 1, spacing_actors.size()):
			spacing_ok = spacing_ok and spacing_actors[i].global_position.distance_to(spacing_actors[j].global_position) >= 1.25
	check(spacing_ok, "Quatro espécies e robô se separam, mesmo em repouso, para acomodar billboards")
	check(is_equal_approx(robot.walk_speed, 1.9) and is_equal_approx(spacing_actors[1].walk_speed, 1.5) and is_equal_approx(spacing_actors[1].run_speed, 7.2), "Velocidades configuradas do robô e do cervo respeitam o balanceamento atual")
	for i in range(1, spacing_actors.size()):
		spacing_actors[i].queue_free()
	robot.global_position = room.get_node("RobotBase").global_position
	robot.navigation_relocated()
	await frames(2)
	var inventory: Node = player.get_node("Inventory")
	check(inventory.slots.all(func(item): return item == null), "Jogador começa sem consumíveis espalhados ou pré-entregues")
	var repository: Node3D = room.get_node("FertilizerRepository")
	player.camera.look_at(repository.global_position + Vector3.UP * 0.6)
	inventory._pickup_aimed_item()
	check(inventory.slots.all(func(item): return item != null and item.item_id == &"fertilizer"), "Interação por mira/E no saco preenche quatro slots vazios")
	var fuse := load("res://resources/items/fuse.tres")
	inventory.set_slot_item(0, fuse)
	inventory.set_slot_item(2, null)
	repository.interact(player)
	check(inventory.slots[0] == fuse and inventory.slots[2].item_id == &"fertilizer", "Reabastecer preserva ferramenta existente e preenche só slot livre")
	var before: Array = inventory.slots.duplicate()
	repository.interact(player)
	check(inventory.slots == before, "Repositório não sobrescreve inventário cheio")
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
	var reached_home := false
	for index in range(500):
		await physics_frame
		if deer.global_position.x > 6 and deer.global_position.distance_to(deer.home) < 1.5:
			reached_home = true
			break
	if not reached_home:
		print("ROUTE DETAIL ",deer.global_position," home ",deer.home," state ",deer.state)
	check(reached_home, "Cervo percorre caminho real ao redor da parede em terreno inclinado")
	deer.set_physics_process(false)
	var skunk: CharacterBody3D = room.get_node("Skunk")
	place(player, skunk.home.x, skunk.home.z + 1.0, 0.9)
	var health: float = player.health
	await frames(110)
	check(player.health == health, "Gambá não agride no Dia 1")
	room.test_action("day")
	await frames(5)
	check(room.get_room_bushes().size() == 10, "Dia 2 faz crescer mais cinco arbustos")
	room._refresh()
	check(room.get_room_bushes().size() == 10, "Atualizações do estado não duplicam crescimento")
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
	# Novo cerco amplo: entra no habitat longe dos membros e depois observa formação.
	var pack: Node3D = room.casuario_group
	var birds: Array = pack.members
	pack.members = pack.members.slice(0, 2)
	pack.set_physics_process(true)
	place(player, 10, 20, 0.9)
	await frames(3)
	check(pack.pack_state == "vigia" and not is_instance_valid(pack.target), "Dois casuários não iniciam o cerco")
	pack.register(birds[2])
	await frames(3)
	check(is_instance_valid(pack.target) and pack.pack_state == "formando cerco", "Casuário percebe invasor no habitat mesmo longe de todos os membros")
	health = player.health
	var minimum_distance := INF
	for index in range(1400):
		await physics_frame
		for bird in birds:
			minimum_distance = minf(minimum_distance, bird.global_position.distance_to(player.global_position))
		if pack.circle_locked:
			break
	check(pack.circle_locked and pack.pack_state == "cercando", "Casuários formam círculo por deslocamento real, sem posicionamento artificial")
	check(minimum_distance > pack.provocation_radius and player.health == health, "Formação contorna o jogador sem atravessar seu centro para atacar")
	for index in range(birds.size()):
		birds[index].walk_speed = 0
		birds[index].run_speed = 0
		var angle := TAU * float(index) / 3.0
		place(birds[index], 24 + cos(angle) * pack.circle_radius, 8 + sin(angle) * pack.circle_radius)
	place(player, 24, 8, 0.9)
	pack.pack_state = "formando cerco"
	pack.circle_locked = false
	pack.orbit_angle = 0
	var health_before_pack: float = player.health
	await frames(10)
	check(pack.circle_locked and pack.pack_state == "cercando", "Grupo monta cerco espaçado sem avançar diretamente sobre jogador")
	await frames(180)
	check(pack.pack_state == "cercando" and is_instance_valid(pack.target) and player.health == health_before_pack, "Cerco persiste além do antigo tempo de esquecimento, sem dano gratuito")
	check(birds[0].global_position.distance_to(birds[1].global_position) > 5.0, "Casuários mantêm espaço entre membros do círculo")
	place(birds[0], 24.8, 8)
	health = player.health
	await frames(90)
	check(pack.pack_state == "avançando" and birds[1].state == "aproximando para ataque", "Aproximação de um membro faz os demais avançarem")
	check(pack.contact_count(player) == 1 and player.health == health, "Casuário isolado continua sem causar dano")
	place(birds[1], 23.2, 8)
	await frames(12)
	check(pack.contact_count(player) == 2, "Dois contatos simultâneos reconhecidos no mesmo grupo")
	place(birds[1], 28, 8)
	await frames(45)
	check(player.health == health, "Perder segundo contato antes do impacto cancela dano")
	place(birds[1], 23.2, 8)
	await frames(90)
	check(player.health < health, "Dois casuários em contato permitem ataque com preparação")
	place(player, 30, 8, 0.9)
	await frames(3)
	check(pack.inside_habitat(player) and pack.pack_state == "fugindo", "Romper o círculo dentro do habitat provoca fuga coletiva")
	var old_distance: float = birds[0].global_position.distance_to(player.global_position)
	for bird in birds:
		bird.run_speed = 3.6
		bird.walk_speed = 1.8
	await frames(60)
	check(birds[0].global_position.distance_to(player.global_position) > old_distance + 0.5, "Fuga do Casuário afasta fisicamente o grupo do jogador")
	await frames(130)
	check(pack.pack_state == "vigia" and not is_instance_valid(pack.target), "Após fuga grupo volta à vigia sem reiniciar cerco imediatamente")
	# Reaquisição após repouso e abandono ao sair do habitat.
	await frames(310)
	check(is_instance_valid(pack.target), "Grupo pode iniciar novo encontro após intervalo de recuperação")
	place(player, 2, 8, 0.9)
	await frames(190)
	check(pack.pack_state == "vigia" and not is_instance_valid(pack.target), "Sair do habitat também encerra encontro e retorna à vigia")
	pack.pack_state = "avançando"
	pack.target = player
	pack.members.erase(birds[2])
	await frames(2)
	check(pack.pack_state == "fugindo", "Perder o terceiro casuário encerra o avanço")
	pack.register(birds[2])
	pack.set_physics_process(false)
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
	# Uma parede impede trabalhar através dela, mesmo perto do alvo.
	var service: Node3D = room.get_node("NavigationRegion3D/Bush6")
	var blocker: StaticBody3D = room._box("TemporaryBlocker", Vector3(0.3, 3, 3), room.ground(-9,8.2,1.5), Color.GRAY)
	place(robot, -9, 9.2)
	await frames(2)
	check(not robot._can_service(service), "Robô não executa serviço através de obstáculo sólido")
	blocker.queue_free()
	await frames(2)
	place(robot, -6, 15)
	robot.interact(player)
	var refilled := false
	var visited_mechanics := false
	for index in range(6500):
		await physics_frame
		refilled = refilled or robot.state == "repondo fertilizante"
		visited_mechanics = visited_mechanics or simulation.robot_room_key == simulation.MECHANICS
	check(progress.robot_service_done and progress.fertilized_ids.size() == 15, "Robô fertiliza os cinco arbustos novos e os cinco da sala mecânica")
	check(visited_mechanics and current_scene == room, "Robô atravessa a porta e trabalha na sala vizinha sem trocar a cena do jogador")
	check(simulation.robot_room_key == simulation.RANGE and robot.global_position.distance_to(room.get_node("RobotBase").global_position) < 1.0, "Robô volta fisicamente à base original após trabalho remoto")
	check(refilled, "Robô repõe consumível interno ao esgotar capacidade")
	check(robot.state == "na base", "Robô retorna à base após concluir as duas salas")
	var stock_before: Array = inventory.slots.duplicate()
	check(inventory.slots == before, "Trabalho do robô não retira consumíveis do inventário do jogador")
	# O jogador pode entrar e sair da área em que o mesmo robô está trabalhando.
	progress.fertilized_ids.erase(100)
	progress.changed.emit()
	for index in range(2400):
		await physics_frame
		if simulation.robot_room_key == simulation.MECHANICS:
			break
	check(simulation.robot_room_key == simulation.MECHANICS, "Robô retorna à outra sala quando surge trabalho remoto")
	room.get_node("DoorBack").interact(player)
	await frames(20)
	check(current_scene.name == "MechanicsTestRoom" and simulation.robot.get_instance_id() == robot_identity and robot.visible, "Jogador encontra o mesmo robô ao segui-lo para outra sala")
	current_scene.get_node("DoorToNPCTest").interact(current_scene.get_node("Player"))
	await frames(30)
	room = current_scene
	player = room.player
	player.set_physics_process(false)
	player.max_health = 10000
	player.health = 10000
	inventory = player.get_node("Inventory")
	for index in range(2400):
		await physics_frame
		if 100 in progress.fertilized_ids and simulation.robot_room_key == simulation.RANGE and robot.state == "na base":
			break
	check(100 in progress.fertilized_ids and robot.state == "na base", "Robô continua tarefa e retorna após jogador sair durante serviço")
	# Descoberta automática de novo trabalho após já estar ocioso.
	room._add_bush(10, -3, 11, 2)
	await room._bake()
	for index in range(800):
		await physics_frame
		if 10 in progress.fertilized_ids:
			break
	check(10 in progress.fertilized_ids, "Robô ocioso detecta arbusto adicional sem reativação")
	check(inventory.slots == stock_before, "Reposição interna não usa o repositório nem o jogador")
	# Arbusto inacessível não prende a fila; remover barreira libera o trabalho depois.
	room._add_bush(11, -3, 15, 2)
	room._add_bush(12, 1, 15, 2)
	var walls: Array[Node] = []
	for x in [-4.2, -1.8]:
		walls.append(room._box("BlockedBushWall", Vector3(0.3,3,2.7),room.ground(x,15,1.5),Color.GRAY))
	for z in [13.8, 16.2]:
		walls.append(room._box("BlockedBushWall", Vector3(2.7,3,0.3),room.ground(-3,z,1.5),Color.GRAY))
	await room._bake()
	for index in range(1500):
		await physics_frame
		if 12 in progress.fertilized_ids:
			break
	check(12 in progress.fertilized_ids and 11 not in progress.fertilized_ids, "Robô ignora arbusto cercado por paredes e trata outro acessível")
	for wall in walls:
		wall.queue_free()
	await frames(2)
	await room._bake()
	for index in range(1500):
		await physics_frame
		if 11 in progress.fertilized_ids:
			break
	check(11 in progress.fertilized_ids, "Robô retoma alvo quando obstáculo é removido")
	var checkpoint_count: int = progress.fertilized_ids.size()
	# Checkpoint preserva Dia 1 e desfaz apenas eventos posteriores do Dia 2.
	for index in range(5):
		progress.fertilize(index)
	progress.advance_test_day()
	progress.fertilize(99)
	progress.restart_day()
	check(progress.day == 2 and progress.fertilized_ids.size() == checkpoint_count and progress.power_restored, "Reinício do Dia 2 preserva resultados do Dia 1 e remove progresso posterior")
	# Regeneração pelo relógio real de física, sem reduzir a espera de 20 segundos.
	place(player, -34, 22, 0.9)
	player.max_health = 100
	player.health = 100
	player.take_damage(30)
	player.set_physics_process(true)
	await frames(1190)
	check(is_equal_approx(player.health, 70.0), "Vida não regenera antes de vinte segundos sem dano")
	await frames(40)
	check(player.health > 70.0, "Vida começa a regenerar depois de vinte segundos")
	player.take_damage(10)
	var damaged_health: float = player.health
	await frames(1190)
	check(is_equal_approx(player.health, damaged_health), "Novo dano reinicia a espera completa de regeneração")
	await frames(1600)
	check(is_equal_approx(player.health, player.max_health), "Regeneração completa respeita limite máximo de vida")
	player.set_physics_process(false)
	player.health = 0
	player._update_health_regen(60)
	check(player.health == 0.0, "Regeneração não revive jogador morto")
	player.health = 100
	# Transições preservam posição dos slots, vazios e seleção, sem novo fusível.
	inventory.set_slot_item(0, load("res://resources/items/fertilizer.tres"))
	inventory.set_slot_item(1, null)
	inventory.set_slot_item(2, fuse)
	inventory.set_slot_item(3, null)
	inventory.selected_slot = 2
	var expected_inventory: Dictionary = inventory.export_inventory()
	# Transições reais de ida e volta, usando a porta pareada existente.
	room.get_node("DoorBack").interact(player)
	await frames(10)
	check(current_scene.name == "MechanicsTestRoom", "Porta do cenário NPC retorna à sala mecânica")
	var mechanics: Node3D = current_scene
	var mechanics_player: CharacterBody3D = mechanics.get_node("Player")
	mechanics_player.set_physics_process(false)
	var world_fuses := get_nodes_in_group("world_items").filter(func(item):
		return mechanics.is_ancestor_of(item) and item.definition != null and item.definition.item_id == &"fuse"
	)
	check(world_fuses.size() == 1, "O fusível da sala reaparece uma única vez após voltar pela porta")
	check(mechanics_player.get_node("Inventory").export_inventory() == expected_inventory, "Ida para sala mecânica preserva slots, vazios e seleção")
	check(simulation.robot.get_instance_id() == robot_identity, "Trocar de cena não duplica nem recria o robô")
	check(mechanics.get_node("Deer").get_script() == load("res://scripts/entities/npcs/animal_controller.gd"), "Cervo mecânico usa controlador atual")
	check(mechanics.get_node("Skunk").get_script() == load("res://scripts/entities/npcs/animal_controller.gd"), "Gambá mecânico usa controlador atual")
	mechanics_player.global_position = mechanics.get_node("Deer").global_position + Vector3(0,0.9,2)
	await frames(20)
	check(mechanics.get_node("Deer").state == "observando", "Fertilização compartilhada torna cervo mecânico tolerante")
	mechanics.get_node("DoorBackToPrototype").interact(mechanics_player)
	await frames(15)
	check(current_scene.name == "PrototypeRoom", "Sala mecânica continua conectada ao protótipo original")
	check(current_scene.get_node("Player/Inventory").export_inventory() == expected_inventory, "Inventário persiste também ao voltar ao protótipo original")
	current_scene.get_node("DoorToMechanicsTestRoom").interact(current_scene.get_node("Player"))
	await frames(30)
	mechanics = current_scene
	check(mechanics.get_node("Player/Inventory").export_inventory() == expected_inventory, "Retorno do protótipo preserva inventário e seleção")
	mechanics.get_node("DoorToNPCTest").interact(mechanics.get_node("Player"))
	await frames(45)
	check(current_scene.name == "NPCTestRange", "Porta da sala mecânica entra no cenário NPC")
	check(current_scene.player.get_node("Inventory").export_inventory() == expected_inventory, "Volta à sala NPC preserva inventário sem substituir itens por iniciais")
	check(simulation.robot.get_instance_id() == robot_identity and simulation.rooms.size() == 2, "Ida e volta mantém um só robô e duas áreas simuladas")
	check(progress.day == 2 and progress.deer_tolerant() and progress.robot_service_done, "Progresso de NPCs persiste após trocar de cena duas vezes")
	print("RESULTADO: %d verificações, %d falhas" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
