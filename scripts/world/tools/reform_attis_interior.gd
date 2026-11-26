extends Node
## Migração pontual do interior salvo. Preserva os equipamentos funcionais.
const PATH := "res://scenes/levels/attis_interior.tscn"
var maker: RefCounted
var root: Node3D
var serial := 0
var concrete: Material
var steel: Material
var paint: Material

func _ready() -> void:
	root = load(PATH).instantiate()
	if root.has_node("CorredorDosHabitats"):
		push_error("Reforma já aplicada. Não sobrescrever edições manuais.")
		get_tree().quit(1)
		return
	maker = load("res://scripts/world/tools/build_attis.gd").new()
	concrete = maker.material("ConcreteCompact", "646d69")
	steel = maker.material("TechnicalSteel", "394b4d")
	paint = maker.material("SafetyOchre", "b09b60")
	for name_text in ["Estrutura", "Sinalizacao", "Iluminacao", "Recepcao", "SalaDeMaquinas"]:
		var old := root.get_node_or_null(name_text)
		if old != null:
			old.free()
	build_structure()
	relocate_equipment()
	build_furnishing()
	build_signs_and_lights()
	root.set_meta("simulation_background", true)
	root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(root)
	await get_tree().physics_frame
	root.rebuild_navigation()
	await root.navigation_rebuilt
	root.remove_meta("simulation_background")
	root.process_mode = Node.PROCESS_MODE_INHERIT
	var error: int = maker.save_scene(root, PATH)
	print("ATTIS_INTERIOR_REFORM: ", {"error":error,"polygons":root.get_node("Navegacao").navigation_mesh.get_polygon_count()})
	get_tree().quit(error)

func box(parent: Node, title: String, at: Vector3, size: Vector3, mat: Material, solid: bool = true) -> Node3D:
	serial += 1
	if parent.has_node(title):
		title += str(serial)
	return maker.box(parent, title, at, size, mat, solid)

func span(parent: Node, a: Vector2, b: Vector2, title: String = "Parede") -> void:
	var midpoint := (a + b) * 0.5
	var size := Vector3(absf(a.x-b.x) + 0.24, 3.6, absf(a.y-b.y) + 0.24)
	box(parent, title, Vector3(midpoint.x,1.8,midpoint.y), size, concrete)

func side(parent: Node, fixed: float, first: float, last: float, gap: Vector2, vertical: bool) -> void:
	if gap == Vector2.ZERO:
		span(parent, Vector2(fixed,first) if vertical else Vector2(first,fixed), Vector2(fixed,last) if vertical else Vector2(last,fixed))
	else:
		if gap.x > first:
			span(parent, Vector2(fixed,first) if vertical else Vector2(first,fixed), Vector2(fixed,gap.x) if vertical else Vector2(gap.x,fixed))
		if gap.y < last:
			span(parent, Vector2(fixed,gap.y) if vertical else Vector2(gap.y,fixed), Vector2(fixed,last) if vertical else Vector2(last,fixed))

func shell(parent: Node, bounds: Rect2, openings: Dictionary) -> void:
	var x := bounds.position.x
	var z := bounds.position.y
	var end_x := bounds.end.x
	var end_z := bounds.end.y
	var middle := bounds.get_center()
	box(parent, "Piso", Vector3(middle.x,-0.18,middle.y),Vector3(bounds.size.x,0.36,bounds.size.y),maker.material("FloorCompact","424f4e"))
	box(parent, "Teto", Vector3(middle.x,3.7,middle.y),Vector3(bounds.size.x+0.25,0.2,bounds.size.y+0.25),concrete)
	side(parent,x,z,end_z,openings.get("west",Vector2.ZERO),true)
	side(parent,end_x,z,end_z,openings.get("east",Vector2.ZERO),true)
	side(parent,z,x,end_x,openings.get("north",Vector2.ZERO),false)
	side(parent,end_z,x,end_x,openings.get("south",Vector2.ZERO),false)

func build_structure() -> void:
	var structure: Node3D = maker.group(root,"Estrutura")
	var reception: Node3D = maker.group(structure,"RecepcaoCompacta")
	shell(reception,Rect2(-2.7,9.2,5.4,4.8),{"north":Vector2(-1.8,1.8),"south":Vector2(-1.8,1.8)})
	var hall: Node3D = maker.group(structure,"CorredorCentral")
	# The side-room shells provide the walls where they meet this spine.
	box(hall,"Piso",Vector3(0,-0.18,-1.3),Vector3(3.6,0.36,21),maker.material("FloorCompact","424f4e"))
	box(hall,"Teto",Vector3(0,3.7,-1.3),Vector3(3.85,0.2,21),concrete)
	span(hall,Vector2(-1.8,8.6),Vector2(-1.8,9.2))
	span(hall,Vector2(1.8,7.4),Vector2(1.8,9.2))
	span(hall,Vector2(1.8,-11.8),Vector2(1.8,-3))
	var store: Node3D = maker.group(structure,"Almoxarifado")
	shell(store,Rect2(-7.8,2.5,6,6.1),{"east":Vector2(4,6.8)})
	var lodging: Node3D = maker.group(structure,"AlojamentoCompacto")
	shell(lodging,Rect2(1.8,3,4,4.4),{"west":Vector2(4.1,6.5)})
	var lab: Node3D = maker.group(structure,"Laboratorio")
	shell(lab,Rect2(1.8,-3,8,6),{"west":Vector2(-1.4,1.4)})
	var charger: Node3D = maker.group(structure,"RecargaSegura")
	shell(charger,Rect2(-9.8,-3,8,5.5),{"east":Vector2(-1.4,1.4)})
	var machine: Node3D = maker.group(structure,"SalaDeMaquinas")
	shell(machine,Rect2(-9.8,-11.8,8,8.8),{"east":Vector2(-8.8,-6)})
	var habitat: Node3D = maker.group(root,"CorredorDosHabitats")
	box(habitat,"Piso",Vector3(0,-0.18,-14),Vector3(19.6,0.36,4.4),maker.material("FloorCompact","424f4e"))
	box(habitat,"Teto",Vector3(0,3.7,-14),Vector3(19.85,0.2,4.65),concrete)
	span(habitat,Vector2(-9.8,-16.2),Vector2(-9.8,-11.8))
	span(habitat,Vector2(9.8,-16.2),Vector2(9.8,-11.8))
	span(habitat,Vector2(1.8,-11.8),Vector2(9.8,-11.8))
	# Both habitat doors fit real openings in one wall; no elevator/shaft scene.
	span(habitat,Vector2(-9.8,-16.2),Vector2(-7.7,-16.2))
	span(habitat,Vector2(-4.3,-16.2),Vector2(4.3,-16.2))
	span(habitat,Vector2(7.7,-16.2),Vector2(9.8,-16.2))
	for at in [-6.0,6.0]:
		box(habitat,"VigaPorta",Vector3(at,3.35,-16.15),Vector3(3.7,0.35,0.5),steel)
		for x in [at-1.7,at+1.7]:
			box(habitat,"Batente",Vector3(x,1.65,-16.15),Vector3(0.18,3.3,0.5),steel)

func resize_equipment(node: Node3D, at: Vector3, size: Vector3) -> void:
	node.position = at
	node.rotation = Vector3.ZERO
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			child.mesh = child.mesh.duplicate()
			child.mesh.size = size
		elif child is CollisionShape3D and child.shape is BoxShape3D:
			child.shape = child.shape.duplicate()
			child.shape.size = size

func place_marker(title: String, at: Vector3) -> void:
	var node := root.get_node_or_null(title) as Node3D
	if node == null:
		node = Marker3D.new()
		node.name = title
		root.add_child(node)
	node.position = at

func relocate_equipment() -> void:
	root.get_node("Player").position = Vector3(0,0.96,11.4)
	place_marker("ItemRecovery",Vector3(0,1.3,11))
	place_marker("DayStart",Vector3(2.8,0.96,5.3))
	place_marker("PanelApproach",Vector3(-7.5,0.96,-8.2))
	place_marker("RobotBase",Vector3(-6,0.08,0))
	place_marker("LabApproach",Vector3(5.3,0.05,-0.5))
	place_marker("StorageApproach",Vector3(-3.1,0.05,6.8))
	place_marker("BedApproach",Vector3(2.8,0.05,5.3))
	place_marker("BuzzyApproach",Vector3(0,0.05,1.8))
	place_marker("Habitat1Approach",Vector3(-6,0.05,-14))
	place_marker("Habitat2Approach",Vector3(6,0.05,-14))
	root.get_node("PowerPanel").position = Vector3(-7.5,1.3,-10.9)
	root.get_node("RadiationZone").position = Vector3(-5.8,1.6,-7.45)
	for shape in root.get_node("RadiationZone").get_children():
		if shape is CollisionShape3D:
			shape.shape = shape.shape.duplicate()
			shape.shape.size = Vector3(7.35,3.6,8.15)
	root.get_node("Buzzy").position = Vector3(1.35,0.5,1.8)
	root.get_node("FertilizerRepository").position = Vector3(-6.6,0,4.5)
	resize_equipment(root.get_node("Deposito"),Vector3(-4.2,0.6,7.3),Vector3(1.8,1.2,0.85))
	resize_equipment(root.get_node("Laboratorio"),Vector3(7.5,0.6,0),Vector3(1.6,1.2,3.2))
	resize_equipment(root.get_node("Cama"),Vector3(4.7,0.30,5.2),Vector3(1,0.55,2.1))
	root.get_node("Cama/Rotulo").position = Vector3(-0.2,1.7,0)
	var h1 := root.get_node("Elevador") as Node3D
	h1.name = "PortaHabitat1"
	resize_equipment(h1,Vector3(-6,1.65,-16.15),Vector3(3.2,3.3,0.25))
	var sign := h1.get_node("Rotulo") as Label3D
	sign.position = Vector3(0,0.6,0.16)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.text = "HABITAT 1\nE / ACESSO"
	sign.font_size = 28
	var h2 := root.get_node("PortaHabitat2") as Node3D
	resize_equipment(h2,Vector3(6,1.65,-16.15),Vector3(3.2,3.3,0.25))
	h2.set_script(load("res://scripts/demo/demo_station.gd"))
	h2.station = 4
	var h2_sign := root.get_node("PlacaHabitat2") as Label3D
	h2_sign.position = Vector3(6,2.25,-15.99)
	h2_sign.rotation = Vector3.ZERO
	h2_sign.text = "HABITAT 2\nACESSO BLOQUEADO"
	h2_sign.font_size = 28
	root.get_node("EstacaoDeCarregamento/Plataforma").position = Vector3(-6,-0.015,0)
	root.get_node("EstacaoDeCarregamento/Fonte").position = Vector3(-8.4,0.8,-1.4)
	var robot := root.get_node_or_null("ServiceRobot") as Node3D
	if robot != null:
		robot.position = Vector3(-6,0.08,0)

func build_furnishing() -> void:
	var reception: Node3D = maker.group(root,"Recepcao")
	box(reception,"Balcao",Vector3(-1.7,0.58,10.1),Vector3(1.4,1.16,0.65),steel)
	box(reception,"Assento",Vector3(-1.7,0.42,11.3),Vector3(0.55,0.84,0.55),maker.material("Seat","55615b"))
	box(reception,"PainelRegistro",Vector3(-2.5,1.6,12.4),Vector3(0.12,0.75,0.8),steel,false)
	var machine: Node3D = maker.group(root,"SalaDeMaquinas")
	for z in [-9.7,-4.6]:
		box(machine,"Gerador",Vector3(-4,1.1,z),Vector3(1.6,2.2,2.4),steel)
		box(machine,"Tampa",Vector3(-4,2.28,z),Vector3(1.8,0.16,2.6),concrete,false)
		for i in range(5):
			box(machine,"Ventilacao",Vector3(-3.16,1.2,-.75+i*.3+z),Vector3(0.05,0.65,0.07),maker.material("Vent","172629"),false)
	var lab: Node3D = maker.group(root,"EquipamentosLaboratorio")
	box(lab,"BancadaAuxiliar",Vector3(5,0.55,-2.35),Vector3(4.1,1.1,0.8),steel)
	box(lab,"Prateleira",Vector3(8.9,2.3,-1),Vector3(0.6,0.15,3.3),steel,false)
	for i in range(4):
		box(lab,"Recipiente",Vector3(8.8,2.55,-2.0+i*.65),Vector3(.3,.35,.3),maker.material("Container","91aaa0"),false)
	box(lab,"Terminal",Vector3(5.2,1.45,-2.35),Vector3(.85,.65,.2),maker.material("Screen","263e43"),false)
	var storage: Node3D = maker.group(root,"PrateleirasAlmoxarifado")
	for y in [0.3,1.1,1.9]:
		box(storage,"Prateleira",Vector3(-7.15,y,6.8),Vector3(.65,.12,2.5),steel,false)
	for i in range(3):
		box(storage,"Caixa",Vector3(-7.1,0.6,6+i*.65),Vector3(.45,.5,.5),maker.material("Box","827963"),false)
	var sleeping: Node3D = maker.group(root,"Alojamento")
	box(sleeping,"ColchaoSuperior",Vector3(4.7,1.65,5.2),Vector3(1,.2,2.1),maker.material("Mattress","75817b"),false)
	for x in [4.2,5.2]:
		for z in [4.15,6.25]:
			box(sleeping,"EstruturaBeliche",Vector3(x,1.15,z),Vector3(.06,2.3,.06),steel,false)
	box(sleeping,"Armario",Vector3(5.05,1,3.5),Vector3(.95,2,.6),steel)
	box(sleeping,"MesaRetratil",Vector3(2.8,.75,6.85),Vector3(1,.1,.55),steel,false)
	var decor: Node3D = maker.group(root,"InfraestruturaIndustrial")
	for z in [7.8,2.9,-3.1,-10.8]:
		box(decor,"Viga",Vector3(0,3.4,z),Vector3(3.6,.28,.25),steel,false)
	for x in [-1.55,1.55]:
		pipe(decor,Vector3(x,3.18,8.9),Vector3(x,3.18,-14.5),.075,steel)
	pipe(decor,Vector3(-9.2,2.9,-11),Vector3(-9.2,2.9,-3.5),.12,paint)
	pipe(decor,Vector3(-9.2,2.9,-3.5),Vector3(-2.3,2.9,-3.5),.12,paint)
	for z in range(-10,10,2):
		box(decor,"FaixaDeCirculacao",Vector3(-1.3,.007,z),Vector3(.07,.008,1.3),paint,false)
	for i in range(7):
		var stripe: Node3D = box(decor,"AvisoNoPiso",Vector3(-1.8,.012,-8.65+i*.38),Vector3(.65,.01,.13),paint,false)
		stripe.rotation.y = .5
	# Door surrounds emphasize thresholds without placing loose panels in rooms.
	for spec in [[-1.8,5.4],[-1.8,0],[-1.8,-7.4],[1.8,5.3],[1.8,0]]:
		box(decor,"TravessaPorta",Vector3(spec[0],3.05,spec[1]),Vector3(.35,.28,3.1),steel,false)

func pipe(parent: Node, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var node: MeshInstance3D = maker.mesh_node(parent,"Tubulacao",mesh,(a+b)*.5,mat)
	node.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))

func build_signs_and_lights() -> void:
	var signs: Node3D = maker.group(root,"Sinalizacao")
	maker.label(signs,"OrientacaoInicial","ATTIS / POSTO 04\nMAQUINAS E HABITATS AO FUNDO",Vector3(0,2.75,9.2),25)
	for spec in [[-1.65,5.4,"ALMOXARIFADO / DEPOSITO",PI*.5],[-1.65,0,"RECARGA / MANUTENCAO",PI*.5],[-1.65,-7.4,"MAQUINAS\nRISCO DE RADIACAO",PI*.5],[1.65,5.3,"ALOJAMENTO / 02",-PI*.5],[1.65,0,"LABORATORIO",-PI*.5]]:
		var sign: Label3D = maker.label(signs,"Setor",spec[2],Vector3(spec[0],2.55,spec[1]),22)
		sign.rotation.y = spec[3]
	maker.label(signs,"AcessosHabitat","ACESSO AOS HABITATS\n1 ESQUERDA / 2 DIREITA",Vector3(0,2.85,-11.65),24)
	var lighting: Node3D = maker.group(root,"Iluminacao")
	for at in [Vector3(0,3.2,11.6),Vector3(0,3.2,5.2),Vector3(0,3.2,-3.5),Vector3(0,3.2,-10.3),Vector3(-5.8,3.2,-7),Vector3(-6,3.2,0),Vector3(-5,3.2,5.5),Vector3(6,3.2,0),Vector3(3.9,3.2,5.2),Vector3(-6,3.2,-14),Vector3(6,3.2,-14)]:
		var lamp := OmniLight3D.new()
		lamp.name = "Luminaria" + str(lighting.get_child_count())
		lamp.position = at
		lamp.light_color = Color("c2cfbd")
		lamp.light_energy = 0.04
		lamp.omni_range = 6.8
		lamp.add_to_group("campaign_lights",true)
		lamp.set_meta("powered_energy",1.05)
		lighting.add_child(lamp)
		box(lighting,"Calha",at+Vector3(0,.15,0),Vector3(1.1,.1,.22),maker.material("LightFitting","aab4a6"),false)
