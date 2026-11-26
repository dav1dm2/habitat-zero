extends Node
var checks: Array = []
var measurements: Array = []
func run() -> void:
	var tree := get_tree()
	var arena := Node3D.new()
	arena.name = "SpeedArena"
	tree.root.add_child(arena)
	tree.current_scene = arena
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(48,.2,8)
	collision.shape = shape
	body.add_child(collision)
	body.position.y = -.1
	arena.add_child(body)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-23,0,-3),Vector3(23,0,-3),Vector3(23,0,3),Vector3(-23,0,3)])
	mesh.add_polygon(PackedInt32Array([0,3,2,1]))
	region.navigation_mesh = mesh
	arena.add_child(region)
	for i in range(5): await tree.physics_frame
	for species in ["deer","skunk","kiwi","casuario"]:
		var animal: CharacterBody3D = load("res://scenes/entities/npcs/"+species+".tscn").instantiate()
		var speed: float = animal.run_speed
		var walk: float = animal.walk_speed
		animal.set_script(load("res://tests/animal_speed_driver.gd"))
		animal.run_speed = speed
		animal.walk_speed = walk
		animal.position = Vector3(-20,.05,0)
		arena.add_child(animal)
		await tree.create_timer(.5).timeout
		var start := animal.position
		var before: int = Engine.get_physics_frames()
		await tree.create_timer(1.0).timeout
		var seconds: float = float(Engine.get_physics_frames()-before)/float(Engine.physics_ticks_per_second)
		var actual := Vector2(animal.position.x-start.x,animal.position.z-start.z).length()/seconds
		measurements.append({"species":species,"state":"fugindo","configured":speed,"measured":actual})
		check("Fuga real de "+species+" supera caminhada do jogador",actual > 5.0 and actual <= speed+.2)
		if species == "casuario":
			animal.position = Vector3(-20,.05,0)
			animal.measured_state = "aproximando para ataque"
			animal._goal_timer = 0
			await tree.create_timer(.5).timeout
			start = animal.position
			before = Engine.get_physics_frames()
			await tree.create_timer(1.0).timeout
			seconds = float(Engine.get_physics_frames()-before)/float(Engine.physics_ticks_per_second)
			actual = Vector2(animal.position.x-start.x,animal.position.z-start.z).length()/seconds
			measurements.append({"species":species,"state":"aproximando para ataque","measured":actual})
			check("Casuário usa corrida ao avançar para ataque",actual > 5.0)
		animal.free()
		await tree.physics_frame
	var fog: Environment = load("res://resources/environments/attis_fog.tres")
	check("Névoa inicia a 5 m e se estende a 26 m",fog.fog_depth_begin == 5 and fog.fog_depth_end == 26 and fog.fog_density < 1.0)
	var forest: Node3D = load("res://scenes/levels/attis_forest.tscn").instantiate()
	var scene_fog: Environment = forest.get_node("Ambiente_Nevoeiro").environment
	check("Cena principal usa a névoa suavizada",scene_fog.fog_depth_end == fog.fog_depth_end and scene_fog.fog_depth_begin == fog.fog_depth_begin)
	forest.free()
	var failed := checks.filter(func(c):return not c.passed)
	var f := FileAccess.open("res://tests/animal_speeds_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"measurements":measurements,"passed":checks.size()-failed.size(),"failed":failed.size()},"  "))
	print("ANIMAL_SPEEDS ",checks.size()-failed.size(),"/",checks.size()," ",measurements)
	tree.quit(0 if failed.is_empty() else 1)
func check(title: String,value: bool) -> void:
	checks.append({"name":title,"passed":value})
