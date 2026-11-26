extends Node
var tree: SceneTree
var room: Node3D
var p: CharacterBody3D
var checks: Array = []

func run() -> void:
	tree = get_tree()
	get_node("/root/ReserveState").reset()
	tree.change_scene_to_file("res://scenes/levels/attis_interior.tscn")
	await tree.scene_changed
	await tree.create_timer(.7).timeout
	room = tree.current_scene
	p = room.get_node("Player")
	var receipt_size: Vector3 = room.get_node("Estrutura/RecepcaoCompacta/Piso/Visual").mesh.size
	var bedroom_size: Vector3 = room.get_node("Estrutura/AlojamentoCompacto/Piso/Visual").mesh.size
	check("Recepção compacta",receipt_size.x * receipt_size.z <= 30)
	check("Alojamento de até 20 m² com beliche",bedroom_size.x * bedroom_size.z <= 20 and room.has_node("Alojamento/ColchaoSuperior"))
	check("Elevador removido",not room.has_node("Elevador") and room.has_node("CorredorDosHabitats"))
	check("Portas H1/H2 alinhadas na parede do corredor",absf(room.get_node("PortaHabitat1").position.z+16.15)<.01 and absf(room.get_node("PortaHabitat2").position.z+16.15)<.01)
	check("Painel dentro da sala de máquinas lateral",room.get_node("PowerPanel").position.x < -3 and room.get_node("PowerPanel").position.z > -11.8 and room.get_node("PowerPanel").position.z < -3)
	var health_start: float = p.health
	for marker in ["StorageApproach","RobotBase","PanelApproach","BuzzyApproach","LabApproach","BedApproach","Habitat1Approach","Habitat2Approach"]:
		var reached: bool = await walk_to(room.get_node(marker).global_position)
		check("Caminhada até "+marker,reached and p.is_on_floor())
		if marker == "RobotBase":
			await tree.create_timer(.6).timeout
			check("Recarga fora da radiação",is_equal_approx(p.health,health_start))
		if marker == "PanelApproach":
			var before: float = p.health
			await tree.create_timer(.6).timeout
			check("Radiação restrita à sala de máquinas",p.health < before)
		if marker in ["Habitat1Approach","Habitat2Approach"]:
			var h1: bool = marker == "Habitat1Approach"
			var door: Node3D = room.get_node("PortaHabitat1" if h1 else "PortaHabitat2")
			if h1:
				check("Porta H1 ligada à nova cena e retorno pareado",door.destination_scene == "res://scenes/levels/habitat_1.tscn" and door.destination_door_path == NodePath("DoorToInterior") and door.has_node("Arrival"))
			else:
				p.camera.look_at(door.global_position)
				p.get_node("Inventory")._pickup_aimed_item()
				check("E informa bloqueio de H2",get_node("/root/DemoInterface").notice.text.contains("Habitat 2") and tree.current_scene == room)
	var returned: bool = await walk_to(room.get_node("DoorExit/Arrival").global_position)
	check("Retorno à recepção caminhando",returned and p.is_on_floor())
	var fail := checks.filter(func(c):return not c.passed)
	var file := FileAccess.open("res://tests/interior_relayout_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":checks.size()-fail.size(),"failed":fail.size()},"  "))
	print("INTERIOR_RELAYOUT: ",checks.size()-fail.size(),"/",checks.size()," ",fail)
	tree.quit(0 if fail.is_empty() else 1)

func walk_to(target: Vector3) -> bool:
	var nav: RID = room.get_node("Navegacao").get_navigation_map()
	var path := NavigationServer3D.map_get_path(nav,p.global_position,target,true)
	if path.is_empty():
		return false
	var count := 0
	for point in path:
		while Vector2(point.x-p.position.x,point.z-p.position.z).length() > .3 and count < 900:
			var offset := point - p.global_position
			p.rotation.y = atan2(-offset.x,-offset.z)
			Input.action_press("move_forward")
			await tree.physics_frame
			count += 1
	Input.action_release("move_forward")
	for i in range(10):
		await tree.physics_frame
	return Vector2(target.x-p.position.x,target.z-p.position.z).length() < .8

func check(title: String, passed: bool) -> void:
	checks.append({"name":title,"passed":passed})
	print("RELAYOUT ","OK " if passed else "FAIL ",title)

func _exit_tree() -> void:
	Input.action_release("move_forward")
