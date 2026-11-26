extends Node
var checks: Array = []
func _ready() -> void:
	run.call_deferred()
func check(label: String, ok: bool) -> void:
	checks.append({"name":label,"passed":ok})
	print("FREEDOM ","OK " if ok else "FAIL ",label)
func run() -> void:
	var progress := get_node("/root/ReserveState")
	progress.reset()
	get_node("/root/DemoSession").campaign_started = false
	get_tree().change_scene_to_file("res://scenes/levels/attis_forest.tscn")
	await get_tree().scene_changed
	await get_tree().create_timer(.8).timeout
	var room := get_tree().current_scene
	var bushes: Array = room.get_sample_bushes()
	check("Todos os 35 decorativos e cinco arbustos iniciais permitem coleta",bushes.size() == 40)
	var bush: Node3D = room.get_node("Vegetacao/Arbusto_00")
	var tool: Resource = load("res://resources/items/sample_collector.tres").duplicate(true)
	var other: Resource = load("res://resources/items/sample_collector.tres").duplicate(true)
	bush.collect_sample(tool)
	check("Arbusto decorativo fornece amostra",tool.sample_ids.size() == 1 and tool.sample_origin == "attis")
	bush.collect_sample(other)
	check("Outro coletor não repete arbusto no mesmo dia",other.sample_ids.is_empty())
	tool.empty_samples()
	bush.collect_sample(tool)
	check("Esvaziar não libera arbusto usado no dia",tool.sample_ids.is_empty())
	var saved: Dictionary = progress.snapshot()
	progress.restore(saved)
	check("Checkpoint preserva registro diário",progress.was_sampled_today("attis",bush.bush_id))
	room.get_node("ArbustosDePesquisa/Arbusto04").collect_sample(tool)
	check("Planta antes exclusiva de fertilização fornece amostra",tool.sample_ids.size() == 1)
	var count: int = tool.sample_ids.size()
	room.get_node("ArbustosDePesquisa/Arbusto06").collect_sample(tool)
	check("Planta ainda não surgida não fornece amostra",tool.sample_ids.size() == count)
	progress.begin_day(2)
	progress.changed.emit()
	tool.empty_samples()
	bush.collect_sample(tool)
	check("Mesmo arbusto volta a fornecer no dia seguinte",tool.sample_ids.size() == 1)
	check("Dia 2 permite todos os 45 arbustos presentes",room.get_sample_bushes().size() == 45)
	var robot: Node = get_node("/root/ReserveSimulation").robot
	robot._sync_collectors()
	check("Robô respeita planta usada pelo jogador",not robot.needs_sample(bush))
	var robot_bush: Node3D = room.get_node("ArbustosDePesquisa/Arbusto01")
	check("Robô aceita planta do dia anterior",robot.needs_sample(robot_bush))
	robot_bush.collect_sample(robot.sample_collectors["attis"])
	robot_bush.collect_sample(other)
	check("Jogador não repete planta usada pelo robô",other.sample_ids.is_empty())
	# Verify actual ray selection of the new nonblocking vegetation hitbox.
	await get_tree().physics_frame
	var point := bush.to_global(Vector3(0,.55,0))
	var query := PhysicsRayQueryParameters3D.create(point+Vector3(0,0,.7),point,32)
	var hit: Dictionary = room.get_node("Player").get_world_3d().direct_space_state.intersect_ray(query)
	check("Arbusto decorativo tem alvo físico para M1 sem bloquear caminhada",hit.get("collider") == bush and bush.collision_layer == 32)
	get_tree().change_scene_to_file("res://scenes/levels/habitat_1.tscn")
	await get_tree().scene_changed
	await get_tree().create_timer(.7).timeout
	room = get_tree().current_scene
	check("Habitat 1 permite seis plantas no Dia 2",room.get_sample_bushes().size() == 6)
	tool.empty_samples()
	for plant in room.get_sample_bushes().slice(0,3): plant.collect_sample(tool)
	check("Três plantas antigas completam coleta do Dia 2 no H1",tool.sample_ids.size() == 3 and tool.sample_origin == "habitat1")
	progress.reset()
	check("Nova campanha limpa registro de plantas",progress.sampled_bush_days.is_empty())
	var failed := checks.filter(func(c):return not c.passed)
	var result := {"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size()}
	FileAccess.open("res://tests/sampling_freedom_result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FREEDOM_RESULT ",result.passed,"/",checks.size()," ",failed)
	get_tree().quit(0 if failed.is_empty() else 1)
