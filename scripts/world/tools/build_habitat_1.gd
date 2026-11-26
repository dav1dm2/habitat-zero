extends Node
## Ferramenta de autoria única. Recusa sobrescrever a cena após edição manual.
const PATH := "res://scenes/levels/habitat_1.tscn"
var maker: RefCounted
var room: Node3D
var stone: Material
var steel: Material
var green: Material
var serial := 0

func _ready() -> void:
	if FileAccess.file_exists(PATH):
		push_error("Habitat 1 já existe. Não sobrescrever edições manuais.")
		return
	maker = load("res://scripts/world/tools/build_attis.gd").new()
	stone = maker.material("HabitatRock", "616968")
	steel = maker.material("HabitatSteel", "3a5558")
	green = maker.material("HabitatLeaves", "6e9057")
	room = Node3D.new()
	room.name = "Habitat1"
	room.set_script(load("res://scripts/demo/habitat_1.gd"))
	room.set_meta("authoring_build", true)
	room.set_meta("simulation_background", true)
	room.process_mode = Node.PROCESS_MODE_DISABLED
	build_ground()
	build_cave()
	build_entry()
	build_ecology()
	build_technical()
	var environment := WorldEnvironment.new()
	environment.name = "Ambiente"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("aabdb6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b1c6a1")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	room.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "LuzDaAbertura"
	sun.rotation_degrees = Vector3(-68, -20, 0)
	sun.light_color = Color("e1e4b0")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	room.add_child(sun)
	var nav := NavigationRegion3D.new()
	nav.name = "Navegacao"
	room.add_child(nav)
	var player: Node3D = load("res://scenes/entities/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0, 1.62, 14.0)
	room.add_child(player)
	add_child(room)
	var progress := get_node("/root/ReserveState")
	var original_day: int = progress.day
	progress.day = 2
	room._apply_campaign_progress()
	await get_tree().physics_frame
	room.rebuild_navigation()
	await room.navigation_rebuilt
	progress.day = original_day
	room._apply_campaign_progress()
	room.remove_meta("authoring_build")
	room.remove_meta("simulation_background")
	room.process_mode = Node.PROCESS_MODE_INHERIT
	var error: int = maker.save_scene(room, PATH)
	print("HABITAT_1_BUILD ", {"error":error,"polygons":nav.navigation_mesh.get_polygon_count()})
	get_tree().quit(error)

func box(parent: Node, title: String, at: Vector3, size: Vector3, mat: Material, solid := true) -> Node3D:
	serial += 1
	return maker.box(parent, title + str(serial), at, size, mat, solid)

func height(x: float, z: float) -> float:
	var entry := smoothstep(10.0, 13.0, z) * (1.0 - smoothstep(3.0, 5.0, absf(x))) * 0.65
	var banks := smoothstep(9.0, 18.0, absf(x)) * (0.24 + 0.14 * sin(z * 0.6))
	return entry + banks

func at(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, height(x, z) + lift, z)

func marker(title: String, point: Vector3) -> void:
	var node := Marker3D.new()
	node.name = title
	node.position = point
	room.add_child(node)

func add_sign(parent: Node, title: String, words: String, point: Vector3, size := 26) -> Label3D:
	var node: Label3D = maker.label(parent, title, words, point, size)
	node.pixel_size = 0.003
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return node

func mesh_body(parent: Node, title: String, mesh: Mesh, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = title
	parent.add_child(body)
	maker.mesh_node(body, "Visual", mesh, Vector3.ZERO, mat)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)

func build_ground() -> void:
	var terrain: Node3D = maker.group(room, "Terreno")
	var soil: StandardMaterial3D = maker.material("HabitatSoil", "627453")
	soil.vertex_color_use_as_albedo = true
	soil.albedo_color = Color.WHITE
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-22, 22):
		for z in range(-20, 19):
			for p in [at(x,z), at(x+1,z), at(x,z+1), at(x+1,z), at(x+1,z+1), at(x,z+1)]:
				var trail := absf(Vector2(p.x / 13.5, p.z / 10.0).length() - 1.0) < 0.09 or absf(p.x) < 1.0
				var tint := Color("81816a") if trail else Color("536a47")
				surface.set_color(tint.lightened(0.025 * sin(p.x * 3 + p.z)))
				surface.add_vertex(p)
	surface.generate_normals()
	mesh_body(terrain, "Solo", surface.commit(), soil)
	# The floor rises gently to the access deck; no jumping needed.
	box(terrain,"Plataforma",Vector3(0,0.5,15),Vector3(6,0.3,4),steel)
	marker("ObservationPoint", Vector3(0,1.56,12.5))
	marker("CenterApproach", at(0,0,0.93))
	marker("WestApproach", at(-12,5,0.93))
	marker("NorthApproach", at(8,-9,0.93))
	marker("EastApproach", at(13,5,0.93))
	marker("NestApproach", at(-10,-8,0.93))
	marker("ItemRecovery", Vector3(0,1.0,14))

func build_cave() -> void:
	var cave: Node3D = maker.group(room, "FormacaoRochosa")
	# Faceted boundary leaves a real opening for the entrance at the south.
	for i in range(28):
		var angle := TAU * float(i) / 28.0
		var p := Vector3(cos(angle)*20.0, 3.8, sin(angle)*17.5)
		if p.z > 15 and absf(p.x) < 5:
			continue
		var node: Node3D = box(cave,"ParedeRochosa",p,Vector3(5.2,8.5+sin(i*1.7)*0.7,2.6+cos(i)*0.35),stone)
		node.rotation.y = -angle + PI * 0.5
		node.rotation.z = sin(i*2.3)*0.07
	# Roof ring slopes upward to an open, irregular daylight aperture.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a := TAU * float(i)/32
		var b := TAU * float(i+1)/32
		var outer_a := Vector3(cos(a)*22,7.2,sin(a)*19)
		var outer_b := Vector3(cos(b)*22,7.2,sin(b)*19)
		var inner_a := Vector3(2+cos(a)*6,11.5+sin(a*3)*0.5,-4+sin(a)*4.5)
		var inner_b := Vector3(2+cos(b)*6,11.5+sin(b*3)*0.5,-4+sin(b)*4.5)
		for p in [outer_a,inner_a,outer_b,inner_a,inner_b,outer_b]:
			surface.add_vertex(p)
	surface.generate_normals()
	var ceiling_mat := stone.duplicate() as StandardMaterial3D
	ceiling_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_body(cave,"TetoComAberturaNatural",surface.commit(),ceiling_mat)
	# Smaller glazed dome under the natural aperture, framing the planted bed.
	var dome := SphereMesh.new()
	dome.radius = 2.5
	dome.height = 3.0
	dome.is_hemisphere = true
	dome.radial_segments = 12
	dome.rings = 5
	var glass: StandardMaterial3D = maker.material("DomeGlass", "a5cbbb")
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.15
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	maker.mesh_node(cave,"CupulaDePesquisa",dome,Vector3(2,10.8,-4),glass)
	for i in range(6):
		var angle := TAU * i / 6.0
		box(cave,"AroCupula",Vector3(2+cos(angle)*2.5,9.6,-4+sin(angle)*2.5),Vector3(0.08,1.0,0.08),steel,false)

	var rim := TorusMesh.new()
	rim.inner_radius = 2.43
	rim.outer_radius = 2.55
	rim.rings = 18
	rim.ring_segments = 6
	maker.mesh_node(cave,"AroDaCupula",rim,Vector3(2,10.65,-4),steel)
	for i in range(6):
		var angle := TAU*i/6.0
		var start := Vector3(2+cos(angle)*2.5,10.65,-4+sin(angle)*2.5)
		var end := Vector3(2+cos(angle)*5.9,11.5,-4+sin(angle)*4.4)
		var tube := CylinderMesh.new()
		tube.top_radius = 0.055
		tube.bottom_radius = 0.055
		tube.height = start.distance_to(end)
		tube.radial_segments = 5
		var node: MeshInstance3D = maker.mesh_node(cave,"SuporteCupula%d"%i,tube,(start+end)*0.5,steel)
		node.quaternion = Quaternion(Vector3.UP,(end-start).normalized())

func build_entry() -> void:
	var entry: Node3D = maker.group(room, "AcessoEObservacao")
	for x in [-3.2, 3.2]:
		box(entry,"ParedeAcesso",Vector3(x,2.0,15.5),Vector3(0.4,4,4),steel)
		box(entry,"Corrimao",Vector3(x,1.55,12.4),Vector3(0.12,0.12,3.5),steel)
	box(entry,"TetoAcesso",Vector3(0,4.1,15.5),Vector3(6.8,0.3,4),steel)
	var door: StaticBody3D = maker.box(room,"DoorToInterior",Vector3(0,0,16.65),Vector3(3.2,3.3,0.2),steel)
	# Root at floor height, visual/collider raised to make a normal door.
	door.get_node("Visual").position.y = 2.25
	for child in door.get_children():
		if child is CollisionShape3D:
			child.position.y = 2.25
	door.set_script(load("res://scripts/world/transition_door.gd"))
	door.destination_scene = "res://scenes/levels/attis_interior.tscn"
	door.destination_door_path = NodePath("PortaHabitat1")
	var arrival := Marker3D.new()
	arrival.name = "Arrival"
	arrival.position = Vector3(0,1.56,-2.5)
	door.add_child(arrival)
	add_sign(entry,"Retorno","INSTALACOES / E VOLTAR",Vector3(0,2.7,16.3),25)
	add_sign(entry,"Aviso","HABITAT 1 / AVES TERRESTRES\nKiwis protegem ninhos. Mantenha distancia.\nCasuários cercam: rompa o circulo ou recue para a plataforma.",Vector3(-2.4,1.9,9.3),23)
	add_sign(entry,"Percurso","PERCURSO DE COLETA\nQuaisquer 3 arbustos / M1 com coletor\nEntregue 3/3 no laboratorio",Vector3(2.4,1.9,9.3),23)

func build_ecology() -> void:
	var flora: Node3D = maker.group(room, "Vegetacao")
	for i in range(36):
		var angle := TAU * i / 36.0
		var x := cos(angle) * (16.0 + sin(i)*0.7)
		var z := sin(angle) * 12.5
		if z > 10 and absf(x)<6:
			continue
		var mesh := SphereMesh.new()
		mesh.radius = 0.65 + float(i%3)*0.15
		mesh.height = 0.8
		mesh.radial_segments = 5
		mesh.rings = 3
		maker.mesh_node(flora,"Moita%02d"%i,mesh,at(x,z,0.4),green)
	# Small planted islands leave the central encounter and the ring path open.
	for spec in [Vector3(-9,0,1),Vector3(9,0,0),Vector3(-6,0,-13),Vector3(3,0,-13)]:
		for i in range(5):
			var x: float = spec.x + cos(i*2.4)*1.1
			var z: float = spec.z + sin(i*2.4)*1.1
			var stem := CylinderMesh.new()
			stem.top_radius = 0.045
			stem.bottom_radius = 0.08
			stem.height = 1.2 + i*0.13
			stem.radial_segments = 5
			maker.mesh_node(flora,"Haste%d_%d"%[serial,i],stem,at(x,z,stem.height*0.5),maker.material("Stems","79885c"))
			for j in range(3):
				var leaf := PrismMesh.new()
				leaf.size = Vector3(0.8,0.12,0.45)
				var node: MeshInstance3D = maker.mesh_node(flora,"Folha%d_%d_%d"%[serial,i,j],leaf,at(x,z,0.65+j*0.28),green)
				node.rotation = Vector3(-0.4, i*2.4+j*2.1, 0.2)
		serial += 1
	for point in [Vector3(-16,0,7),Vector3(15,0,-9),Vector3(-8,0,-14)]:
		var rock := SphereMesh.new()
		rock.radius = 1.4
		rock.height = 2.1
		rock.radial_segments = 5
		rock.rings = 3
		var boulder: Node3D = maker.group(flora,"Rocha%d"%serial)
		serial += 1
		boulder.position = at(point.x,point.z,0.2)
		mesh_body(boulder,"Bloco",rock,stone)
	var research: Node3D = maker.group(room,"ArbustosDePesquisa")
	for i in range(6):
		var points := [Vector2(-12,5),Vector2(8,-10),Vector2(13,5),Vector2(-12,1),Vector2(5,-11),Vector2(13,-1)]
		var point: Vector2 = points[i]
		var bush := StaticBody3D.new()
		bush.name = "Arbusto%02d" % (i+1)
		bush.position = at(point.x,point.y)
		bush.set_script(load("res://scripts/world/fertilizable_bush.gd"))
		bush.bush_id = 2000+i
		bush.sample_origin = "habitat1"
		bush.available_from_day = 1 if i < 3 else 2
		bush.visible = i < 3
		bush.collision_layer = 1 if i < 3 else 0
		bush.can_fertilize = false
		research.add_child(bush)
		var mesh := SphereMesh.new()
		mesh.radius = 0.75
		mesh.height = 1.4
		mesh.radial_segments = 7
		mesh.rings = 4
		maker.mesh_node(bush,"Foliage",mesh,Vector3(0,0.7,0),green)
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.7
		collision.shape = shape
		collision.position.y = 0.7
		bush.add_child(collision)
		add_sign(bush,"Sinalizacao","H1 / AMOSTRAS / %02d\nM1 COM COLETOR" % [i+1],Vector3(0,1.9,0),22)
		marker("SampleApproach%d"%(i+1),at(point.x,point.y+2.5,0.93))
	var refuge: Node3D = maker.group(room,"RecantoDosKiwis")
	box(refuge,"Abrigo",at(-13,-11,2.1),Vector3(6.2,0.8,4),stone)
	box(refuge,"RochaLateral",at(-16,-11,0.8),Vector3(1.3,2.0,4.0),stone)
	box(refuge,"Comedouro",at(-8,-12,0.2),Vector3(1.5,0.4,0.8),steel)
	var nest := TorusMesh.new()
	nest.inner_radius = 0.65
	nest.outer_radius = 1.0
	nest.rings = 12
	nest.ring_segments = 6
	maker.mesh_node(refuge,"Ninho",nest,at(-13,-10,0.15),maker.material("Nest","87745b"))
	for i in range(3):
		var egg := SphereMesh.new()
		egg.radius = 0.18
		egg.height = 0.5
		egg.radial_segments = 7
		egg.rings = 4
		maker.mesh_node(refuge,"Ovo%d"%i,egg,at(-13+(i-1)*0.35,-10,0.25),maker.material("Egg","bfcbb1"))
	add_sign(refuge,"AvisoNinho","NINHO OCUPADO\nObserve de longe / nao se aproxime",at(-10,-5,1.8),22)
	var fauna: Node3D = maker.group(room,"Fauna")
	for is_pack in [false,true]:
		var group := Node3D.new()
		group.name = "CasuarioGroup" if is_pack else "KiwiGroup"
		group.set_script(load("res://scripts/entities/npcs/animal_group.gd"))
		group.position = Vector3(0,0,0) if is_pack else at(-13,-10)
		group.predator_pack = is_pack
		group.has_eggs = not is_pack
		group.territory_radius = 6.0 if not is_pack else 18.0
		group.habitat_bounds = AABB(Vector3(-17,-10,-14),Vector3(34,30,24))
		fauna.add_child(group)
		var positions := [Vector2(-4,1),Vector2(4,-2),Vector2(0,-7)] if is_pack else [Vector2(-11,-10),Vector2(-14,-8),Vector2(-14,-12)]
		for i in range(3):
			var animal: Node3D = load("res://scenes/entities/npcs/casuario.tscn" if is_pack else "res://scenes/entities/npcs/kiwi.tscn").instantiate()
			animal.name = ("Casuario" if is_pack else "Kiwi") + str(i+1)
			animal.position = at(positions[i].x,positions[i].y,0.08) - group.position
			animal.debug_labels = false
			group.add_child(animal)

func build_technical() -> void:
	var technical: Node3D = maker.group(room,"Infraestrutura")
	box(technical,"ControleAmbiental",at(17,-1,1.0),Vector3(1.1,2.0,2.4),steel)
	box(technical,"Reservatorio",at(16,-5,1.3),Vector3(1.5,2.6,1.6),steel)
	add_sign(technical,"EstadoAmbiental","CONTROLE AMBIENTAL / H1\nIrrigacao e ventilacao",at(16,0,2.6),23)
	for x in [-17.0,17.0]:
		box(technical,"Tubulacao",Vector3(x,1.0,0),Vector3(0.12,0.12,23),steel,false)
		for z in [-9.0,-3.0,3.0,9.0]:
			box(technical,"Sensor",at(x,z,1.8),Vector3(0.3,0.4,0.25),maker.material("Sensor","b7b179"),false)
	for x in [-8.0,8.0]:
		box(technical,"Dreno",at(x,10,0.02),Vector3(2.5,0.04,0.4),steel,false)
	for point in [Vector3(-13,5,-3),Vector3(13,5,4),Vector3(0,5,12)]:
		var light := OmniLight3D.new()
		light.name = "Luminaria"
		light.position = point
		light.light_color = Color("adc3aa")
		light.light_energy = 1.0
		light.omni_range = 12
		light.add_to_group("campaign_lights", true)
		light.set_meta("powered_energy", 1.0)
		technical.add_child(light)
