extends Node
## Migração explícita, sem regenerar o cenário externo aprovado.
var maker: RefCounted
const FOREST := "res://scenes/levels/attis_forest.tscn"
const INTERIOR := "res://scenes/levels/attis_interior.tscn"

func _ready() -> void:
	if FileAccess.file_exists(INTERIOR):
		push_error("Interior já existe. Preservar edições antes de executar a migração novamente.")
		get_tree().quit(1)
		return
	maker = load("res://scripts/world/tools/build_attis.gd").new()
	var interior := create_interior()
	interior.set_meta("simulation_background", true)
	interior.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	add_child(interior)
	await get_tree().physics_frame
	interior.rebuild_navigation()
	await interior.navigation_rebuilt
	interior.remove_meta("simulation_background")
	interior.get_node("Player").process_mode = Node.PROCESS_MODE_INHERIT
	var error: int = maker.save_scene(interior, INTERIOR)
	print("INTERIOR_SAVED: ", error)
	interior.queue_free()
	await get_tree().process_frame
	var forest: Node3D = load(FOREST).instantiate()
	forest.set_meta("simulation_background", true)
	forest.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	add_child(forest)
	for animal in forest.get_node("Fauna").get_children():
		animal.set_physics_process(false)
	var old: Node = forest.get_node_or_null("BaseNoTopo/InstalacoesNaRocha/PortaProvisoria")
	if old != null:
		old.free()
	old = forest.get_node_or_null("BaseNoTopo/InstalacoesNaRocha/PortaSemEnergia")
	if old != null:
		old.free()
	create_door(forest, "DoorToInterior", Vector3(0, 24.05, -74.1), PI, INTERIOR, "DoorExit")
	marker(forest, "RobotBase", Vector3(7, 24.1, -60))
	marker(forest, "ItemRecovery", Vector3(0, 1.3, 69))
	create_bushes(forest)
	var env: Environment = forest.get_node("Ambiente_Nevoeiro").environment
	env = env.duplicate()
	env.background_color = Color("777b7d")
	env.fog_light_color = Color("777b7d")
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 5.0
	env.fog_depth_end = 26.0
	env.fog_depth_curve = 1.2
	ResourceSaver.save(env, "res://resources/environments/attis_fog.tres")
	forest.get_node("Ambiente_Nevoeiro").environment = env
	forest.rebuild_navigation()
	await forest.navigation_rebuilt
	forest.remove_meta("simulation_background")
	forest.get_node("Player").process_mode = Node.PROCESS_MODE_INHERIT
	error = maker.save_scene(forest, FOREST)
	print("FOREST_INTEGRATED: ", error)
	get_tree().quit(error)

func marker(parent: Node, name_text: String, at: Vector3) -> void:
	var node := Marker3D.new()
	node.name = name_text
	node.position = at
	parent.add_child(node)

func create_door(parent: Node, title: String, at: Vector3, angle: float, destination: String, counterpart: String) -> void:
	var root := StaticBody3D.new()
	root.name = title
	root.position = at
	root.rotation.y = angle
	root.set_script(load("res://scripts/world/transition_door.gd"))
	root.destination_scene = destination
	root.destination_door_path = NodePath(counterpart)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.4, 3.6, 0.2)
	maker.mesh_node(root, "Porta", mesh, Vector3(0, 1.8, 0), maker.material("Door", "465450"))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position.y = 1.8
	root.add_child(collision)
	marker(root, "Arrival", Vector3(0, 0.96, -1.7))
	var sign: Label3D = maker.label(root, "Placa", "E / ENTRAR" if destination == INTERIOR else "E / FLORESTA DE ATTIS", Vector3(0, 2.25, -0.14), 28)
	sign.rotation.y = PI
	parent.add_child(root)

func create_bushes(forest: Node3D) -> void:
	var group: Node3D = maker.group(forest, "ArbustosDePesquisa")
	for i in range(10):
		var z := 43.0 - (i % 5) * 22.0 - (5.0 if i >= 5 else 0.0)
		var x: float = maker.trail_x(z) + (5.0 if i % 2 == 0 else -5.0)
		var bush := StaticBody3D.new()
		bush.name = "Arbusto%02d" % (i + 1)
		bush.set_script(load("res://scripts/world/fertilizable_bush.gd"))
		bush.bush_id = 1000 + i
		bush.available_from_day = 1 if i < 5 else 2
		bush.position = maker.ground(x, z)
		var mesh := SphereMesh.new()
		mesh.radius = 0.65
		mesh.height = 1.0
		mesh.radial_segments = 7
		mesh.rings = 3
		maker.mesh_node(bush, "Foliage", mesh, Vector3(0, 0.6, 0), maker.material("Bush", "777458"))
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.65
		collision.shape = shape
		collision.position.y = 0.6
		bush.add_child(collision)
		maker.label(bush, "Sinalizacao", "PESQUISA / %02d" % (i + 1), Vector3(0, 1.6, 0), 20).billboard = BaseMaterial3D.BILLBOARD_ENABLED
		group.add_child(bush)

func create_interior() -> Node3D:
	var root := Node3D.new()
	root.name = "AttisInterior"
	root.set_script(load("res://scripts/demo/attis_interior.gd"))
	var world := WorldEnvironment.new()
	world.name = "Ambiente"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("171d20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("abb7b2")
	env.ambient_light_energy = 0.1
	world.environment = env
	root.add_child(world)
	var layout: Node3D = maker.group(root, "Estrutura")
	var concrete: Material = maker.material("InteriorConcrete", "59625f")
	var floor_mat: Material = maker.material("Floor", "3f4949")
	maker.box(layout, "Piso", Vector3(0, -0.25, -9), Vector3(30, 0.5, 48), floor_mat)
	maker.box(layout, "Teto", Vector3(0, 4.5, -9), Vector3(30, 0.5, 48), concrete)
	for x in [-15, 15]:
		maker.box(layout, "ParedeExterna", Vector3(x, 2.1, -9), Vector3(0.5, 4.4, 48), concrete)
	maker.box(layout, "Fundo", Vector3(0, 2.1, -33), Vector3(30, 4.4, 0.5), concrete)
	for x in [-8.4, 8.4]:
		maker.box(layout, "Entrada", Vector3(x, 2.1, 14), Vector3(13.2, 4.4, 0.5), concrete)
	# Reception narrows into a straight, readable central passage.
	for x in [-9.3, 9.3]:
		maker.box(layout, "LimiteRecepcao", Vector3(x, 2.1, 5), Vector3(11.4, 4.4, 0.4), concrete)
	for x in [-3.7, 3.7]:
		for span in [[3.0, 4.0], [-10.0, 4.0], [-19.9, 1.8]]:
			maker.box(layout, "Corredor", Vector3(x, 2.1, span[0]), Vector3(0.35, 4.4, span[1]), concrete)
	# West laboratory/store; east accommodation.
	for x in [-9.5, 9.5]:
		for z in [1.0, -9.0]:
			maker.box(layout, "Divisoria", Vector3(x, 2.1, z), Vector3(11, 4.4, 0.35), concrete)
	# Back rooms: safe charger to the left; irradiated machinery to the right.
	maker.box(layout, "MaquinasLateral", Vector3(-3.8, 2.1, -26.7), Vector3(0.4, 4.4, 12), concrete)
	for x in [-3.0, 9.0]:
		maker.box(layout, "EntradaMaquinas", Vector3(x, 2.1, -21), Vector3(2.0 if x < 0 else 12.0, 4.4, 0.35), concrete)
	var signs: Node3D = maker.group(root, "Sinalizacao")
	maker.label(signs, "BoasVindas", "ATTIS / POSTO 04\nSALA DE MAQUINAS AO FUNDO", Vector3(0, 3.25, 5.1), 34)
	maker.label(signs, "AvisoRadiacao", "PERIGO / RADIACAO\nEXPOSICAO LIMITADA", Vector3(0, 2.8, -20.7), 30)
	maker.label(signs, "Armazem", "ALMOXARIFADO / LABORATORIO", Vector3(-3.4, 2.8, -3), 22).rotation.y = PI * 0.5
	maker.label(signs, "Quarto", "ALOJAMENTO", Vector3(3.4, 2.8, -4), 26).rotation.y = -PI * 0.5
	maker.label(signs, "Carregamento", "RECARGA / MANUTENCAO", Vector3(-9, 2.8, -20), 28)
	var lighting: Node3D = maker.group(root, "Iluminacao")
	for at in [Vector3(0,3.8,10),Vector3(0,3.8,-3),Vector3(0,3.8,-16),Vector3(8,3.8,-26),Vector3(-9,3.8,-25),Vector3(-9,3.8,-4),Vector3(9,3.8,-4)]:
		var lamp := OmniLight3D.new()
		lamp.name = "Luminaria"
		lamp.position = at
		lamp.light_color = Color("b8c7b3")
		lamp.light_energy = 0.04
		lamp.omni_range = 10
		lamp.add_to_group("campaign_lights", true)
		lamp.set_meta("powered_energy", 1.4)
		lighting.add_child(lamp)
	# Familiar silhouettes only; all objects remain native editable nodes.
	var reception: Node3D = maker.group(root, "Recepcao")
	maker.box(reception, "Balcao", Vector3(-6, 0.6, 9), Vector3(5, 1.2, 1.4), maker.material("Furniture", "4c5b56"))
	var machines: Node3D = maker.group(root, "SalaDeMaquinas")
	for x in [7, 11]:
		maker.box(machines, "Gerador", Vector3(x, 1.3, -26), Vector3(2, 2.6, 3.8), maker.material("Machine", "475350"))
	var panel: Node3D = maker.box(root, "PowerPanel", Vector3(0, 1.3, -30), Vector3(2.4, 2.1, 0.5), maker.material("Panel", "3b4c50"))
	panel.set_script(load("res://scripts/demo/demo_power_panel.gd"))
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.15
	lamp_mesh.height = 0.3
	maker.mesh_node(panel, "Lamp", lamp_mesh, Vector3(0, 0.5, 0.35), maker.material("Indicator", "985b46"))
	maker.label(panel, "Rotulo", "ALIMENTACAO\nM1 FUSIVEL / E PAINEL", Vector3(0, 0.0, 0.3), 20)
	var zone := Area3D.new()
	zone.name = "RadiationZone"
	zone.position = Vector3(5, 1.6, -26.5)
	zone.set_script(load("res://scripts/world/radiation_zone.gd"))
	zone.damage_per_second = 1.78
	zone.add_to_group("radiation_zones", true)
	var zshape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(16.8, 4, 10)
	zshape.shape = volume
	zone.add_child(zshape)
	root.add_child(zone)
	var charger: Node3D = maker.group(root, "EstacaoDeCarregamento")
	maker.box(charger, "Plataforma", Vector3(-9, 0.005, -25), Vector3(3, 0.01, 3), maker.material("Charger", "5b786f"), false)
	maker.box(charger, "Fonte", Vector3(-12.5, 0.8, -27), Vector3(1.5, 1.6, 1.3), maker.material("Machine", "475350"))
	marker(root, "RobotBase", Vector3(-9, 0.08, -25))
	var robot: Node3D = load("res://scenes/entities/npcs/service_robot.tscn").instantiate()
	robot.position = Vector3(-9, 0.08, -25)
	root.add_child(robot)
	robot.process_mode = Node.PROCESS_MODE_DISABLED
	# Restore normal processing in the packed placeholder; simulation replaces it at runtime.
	robot.process_mode = Node.PROCESS_MODE_INHERIT
	var buzzy: Node3D = maker.box(root, "Buzzy", Vector3(2.5, 0.5, -13), Vector3(0.8, 1, 0.8), maker.material("Projector", "3c5d65"))
	buzzy.set_script(load("res://scripts/demo/demo_buzzy.gd"))
	var projection := preload("res://scenes/entities/npcs/buzzy_projection.tscn").instantiate() as AnimatedSprite3D
	projection.position.y = 1.1
	buzzy.add_child(projection)
	maker.label(buzzy, "StateLabel", "Buzzy", Vector3(0, 1.8, 0), 25).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var repository: Node3D = load("res://scenes/entities/items/fertilizer_repository.tscn").instantiate()
	repository.position = Vector3(-10, 0, -2)
	root.add_child(repository)
	create_station(root, "Deposito", Vector3(-6,0.6,-7), Vector3(2,1.2,1), 0, "E / DEPOSITO PESSOAL")
	create_station(root, "Laboratorio", Vector3(-12,0.6,-6), Vector3(2,1.2,2.5), 3, "E / BANCADA DE ANALISE")
	create_station(root, "Cama", Vector3(10,0.35,-5), Vector3(2,0.7,3), 1, "E / DESCANSAR")
	create_station(root, "Elevador", Vector3(10,1.6,-17), Vector3(3,3.2,0.8), 2, "HABITAT 1 / E")
	maker.box(root, "PortaHabitat2", Vector3(14.7,1.8,-12), Vector3(0.3,3.6,3), maker.material("Door", "465450"))
	maker.label(root, "PlacaHabitat2", "HABITAT 2 / FECHADO", Vector3(14.4,2.3,-12), 22).rotation.y = -PI * 0.5
	create_door(root, "DoorExit", Vector3(0,0,13.6), 0, FOREST, "DoorToInterior")
	marker(root, "ItemRecovery", Vector3(0,1.3,10))
	var player: Node3D = load("res://scenes/entities/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0,0.96,11)
	root.add_child(player)
	var nav := NavigationRegion3D.new()
	nav.name = "Navegacao"
	root.add_child(nav)
	return root

func create_station(root: Node, title: String, at: Vector3, size: Vector3, action: int, words: String) -> void:
	var station: Node3D = maker.box(root, title, at, size, maker.material("Furniture", "4c5b56"))
	station.set_script(load("res://scripts/demo/demo_station.gd"))
	station.station = action
	maker.label(station, "Rotulo", words, Vector3(0, size.y * 0.5 + 0.55, 0), 23).billboard = BaseMaterial3D.BILLBOARD_ENABLED
