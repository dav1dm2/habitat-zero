extends Node3D
@onready var reserve_state: Node = get_node("/root/ReserveState")
## Cenário temporário, separado do mapa final; F1–F6 são comandos de depuração.
const ANIMALS = [preload("res://scenes/entities/npcs/deer.tscn"), preload("res://scenes/entities/npcs/skunk.tscn"), preload("res://scenes/entities/npcs/kiwi.tscn"), preload("res://scenes/entities/npcs/pukeko.tscn")]
const GROUP = preload("res://scripts/entities/npcs/animal_group.gd")
const PLAYER = preload("res://scenes/entities/player/player.tscn")
var navigation_ready: bool = false
var region: NavigationRegion3D
var kiwi_group: Node3D
var pukeko_group: Node3D
var player: CharacterBody3D
var status_label: Label
var summary: Label
var _nest_eggs: Node3D

func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_layout()
	_build_npcs()
	_build_player()
	_build_ui()
	reserve_state.changed.connect(_refresh)
	_refresh()
	call_deferred("_bake")

func terrain_height(x: float, z: float) -> float:
	return 1.2 + 1.1 * sin(x * 0.12) * cos(z * 0.1) + 0.65 * sin(z * 0.22)

func ground(x: float, z: float, lift: float = 0.05) -> Vector3:
	return Vector3(x, terrain_height(x, z) + lift, z)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("667877")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a6b7b4")
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.0
	add_child(sun)

func _build_terrain() -> void:
	region = NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.agent_radius = 0.5
	nav.agent_height = 1.5
	nav.agent_max_climb = 0.25
	nav.agent_max_slope = 40.0
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	region.navigation_mesh = nav
	add_child(region)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-38, 38, 2):
		for z in range(-26, 26, 2):
			var a := ground(x, z, 0.0)
			var b := ground(x + 2, z, 0.0)
			var c := ground(x, z + 2, 0.0)
			var d := ground(x + 2, z + 2, 0.0)
			for point in [a, b, c, b, d, c]:
				var trail := absf(point.z - (5.0 + 2.0 * sin(point.x * 0.15))) < 2.0
				surface.set_color(Color("79745b") if trail else (Color("626e5e") if point.x < 5 else Color("617965")))
				surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	var instance := MeshInstance3D.new()
	instance.name = "Hills"
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	instance.material_override = mat
	region.add_child(instance)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	floor_body.add_child(shape)
	region.add_child(floor_body)
	# Limites físicos e separação com passagem; nada depende de uma sala plana.
	_box("NorthFence", Vector3(76, 4, 0.5), Vector3(0, 3, -26), Color("48524c"))
	_box("SouthFence", Vector3(76, 4, 0.5), Vector3(0, 3, 26), Color("48524c"))
	_box("WestFence", Vector3(0.5, 4, 52), Vector3(-38, 3, 0), Color("48524c"))
	_box("EastFence", Vector3(0.5, 4, 52), Vector3(38, 3, 0), Color("48524c"))
	_box("HabitatWallNorth", Vector3(0.6, 6, 29), Vector3(5, 3, -11.5), Color("697b79"))
	_box("HabitatWallSouth", Vector3(0.6, 6, 15), Vector3(5, 3, 18.5), Color("697b79"))

func _box(node_name: String, size: Vector3, at: Vector3, tint: Color, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	visual.material_override = mat
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	(region if parent == null else parent).add_child(body)
	return body

func _sign(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.009
	add_child(label)

func _build_layout() -> void:
	_box("RockOccluder", Vector3(3.0, 3, 3.5), ground(-17, -7, 1.5), Color("737777"))
	_box("FallenTrunk", Vector3(5, 1, 1), ground(-10, 1, 0.5), Color("524b3d"))
	_box("HabitatRock", Vector3(2, 2.4, 3), ground(28, -1, 1.2), Color("727f76"))
	for at in [Vector2(-30,-9), Vector2(-27,-15), Vector2(-8,-16), Vector2(-15,17), Vector2(-31,19), Vector2(-5,14)]:
		_box("Tree", Vector3(0.7, 5, 0.7), ground(at.x, at.y, 2.5), Color("4c4940"))
	_sign("ATTIS · fauna da superfície\nCervo / Gambá", ground(-23, 12, 3))
	_sign("HABITAT 1 →\nKiwi / Pukeko · aves não voadoras", ground(5, 7, 3))
	_sign("Kiwi · ninho (F4 alterna ovos)", ground(16, -11, 2.5))
	_sign("Pukeko · observe e recue\nDois contatos permitem ataque", ground(26, 14, 2.5))
	var bush_script := preload("res://scripts/world/fertilizable_bush.gd")
	for index in range(5):
		var x := -27.0 + index * 3.0
		var body := _box("Bush%d" % index, Vector3(0.9, 0.9, 0.9), ground(x, 10, 0.45), Color("88816a"))
		body.set_script(bush_script)
		body.bush_id = index
		body.get_child(0).name = "Foliage"
		body.add_to_group("fertilizable_bushes")
		body.add_to_group("interactables")
	var eggs := Node3D.new()
	eggs.name = "NestEggs"
	eggs.position = ground(16, -11)
	add_child(eggs)
	_nest_eggs = eggs
	for index in range(3):
		var egg := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.18
		mesh.height = 0.5
		egg.mesh = mesh
		egg.position = Vector3(index * 0.4 - 0.4, 0.25, 0)
		eggs.add_child(egg)
	_box("NestShade", Vector3(3.5, 0.25, 3.5), ground(16, -11, 2.5), Color("47554b"))
	_box("ShadePost", Vector3(0.25, 2.5, 0.25), ground(14.5, -12.5, 1.25), Color("47554b"))
	_box("ServiceTarget", Vector3(0.7, 0.8, 0.7), ground(-2, 15, 0.4), Color("528caa"))
	var console := _box("PowerConsole", Vector3(1, 1.2, 0.6), ground(-28, 8, 0.6), Color("b3944f"), self)
	console.set_script(preload("res://scripts/world/npc_test_console.gd"))
	console.add_to_group("interactables")
	_sign("E / F1 · energia", ground(-28, 8, 2.2))
	var door := preload("res://scenes/constructions/transition_door.tscn").instantiate() as StaticBody3D
	door.name = "DoorBack"
	door.position = ground(-32, 17)
	door.destination_scene = "res://scenes/levels/mechanics_test_room.tscn"
	door.destination_door_path = NodePath("DoorToNPCTest")
	add_child(door)
	_sign("E · voltar à sala mecânica", ground(-32, 17, 3))

func _spawn(species: int, at: Vector3, parent: Node = null) -> Node3D:
	var animal := ANIMALS[species].instantiate() as Node3D
	(parent if parent != null else self).add_child(animal)
	animal.global_position = at
	animal.home = at
	return animal

func _build_npcs() -> void:
	var deer := _spawn(0, ground(-23, -1, 0.3))
	deer.name = "Deer"
	var skunk := _spawn(1, ground(-8, -10, 0.3))
	skunk.name = "Skunk"
	kiwi_group = Node3D.new()
	kiwi_group.set_script(GROUP)
	kiwi_group.name = "KiwiGroup"
	kiwi_group.position = ground(16, -11)
	add_child(kiwi_group)
	for index in range(3):
		_spawn(2, ground(15 + index, -10, 0.3), kiwi_group)
	pukeko_group = Node3D.new()
	pukeko_group.set_script(GROUP)
	pukeko_group.name = "PukekoGroup"
	pukeko_group.position = ground(24, 8)
	add_child(pukeko_group)
	for index in range(3):
		var angle := index * TAU / 3.0
		_spawn(3, ground(24 + cos(angle) * 3, 8 + sin(angle) * 3, 0.3), pukeko_group)
	var buzzy := preload("res://scenes/entities/npcs/buzzy.tscn").instantiate() as Node3D
	buzzy.position = ground(-25, 8)
	add_child(buzzy)
	var robot := preload("res://scenes/entities/npcs/service_robot.tscn").instantiate() as Node3D
	robot.name = "ServiceRobot"
	robot.position = ground(-6, 15, 0.3)
	robot.service_target = NodePath("../NavigationRegion3D/ServiceTarget")
	add_child(robot)

func _build_player() -> void:
	player = PLAYER.instantiate() as CharacterBody3D
	player.name = "Player"
	player.position = ground(-28, 14, 1.0)
	add_child(player)
	player.get_node("Hud/Instructions").hide()
	var fertilizer := preload("res://resources/items/fertilizer.tres")
	for index in range(4):
		player.get_node("Inventory").set_slot_item(index, fertilizer)
	var pickup := preload("res://scenes/entities/items/world_item.tscn").instantiate() as RigidBody3D
	pickup.definition = fertilizer
	pickup.position = ground(-28, 12, 0.6)
	add_child(pickup)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 12)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var instructions := Label.new()
	instructions.text = "TESTE DE NPCs · geometria e visuais provisórios\nF1 energia · F2 cinco arbustos · F3 Dia 2\nF4 ovos Kiwi · F5 reiniciar dia · F6 novo teste\nWASD / mouse / Shift · E interagir · M1 fertilizante · Esc libera mouse"
	box.add_child(instructions)
	summary = Label.new()
	box.add_child(summary)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x = 630
	box.add_child(status_label)
	show_status("Preparando navegação...")

func _bake() -> void:
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation_ready = region.navigation_mesh.get_polygon_count() > 0
	show_status("Navegação pronta. Explore Attis e atravesse a passagem para o Habitat 1." if navigation_ready else "ERRO: navegação vazia.")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var actions := {KEY_F1: "power", KEY_F2: "fertilize", KEY_F3: "day", KEY_F4: "eggs", KEY_F5: "restart", KEY_F6: "reset"}
		if actions.has(event.keycode):
			test_action(actions[event.keycode])
			get_viewport().set_input_as_handled()

func test_action(action: String) -> void:
	match action:
		"power":
			reserve_state.power_restored = true
			reserve_state.changed.emit()
			show_status("Energia restaurada. E em Buzzy ou no robô.")
		"fertilize":
			for index in range(5):
				reserve_state.fertilize(index)
			show_status("Cinco arbustos concluídos: cervos tolerantes.")
		"day":
			reserve_state.advance_test_day()
			show_status("Dia 2 de teste: gambá territorial. Checkpoint diário registrado.")
		"eggs":
			kiwi_group.set_eggs(not kiwi_group.has_eggs)
			_refresh()
			show_status("Ovos no ninho: %s" % kiwi_group.has_eggs)
		"restart":
			on_player_death()
		"reset":
			reserve_state.reset()
			get_tree().reload_current_scene()

func _refresh() -> void:
	if summary != null:
		summary.text = "Dia %d · energia %s · arbustos %d/5 · ovos %s" % [reserve_state.day, reserve_state.power_restored, reserve_state.fertilized_ids.size(), kiwi_group.has_eggs]
	if _nest_eggs != null:
		_nest_eggs.visible = kiwi_group.has_eggs
	for bush in get_tree().get_nodes_in_group("fertilizable_bushes"):
		if bush.bush_id in reserve_state.fertilized_ids:
			bush.add_to_group("fertilized_bushes")
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("4d9556")
			bush.get_node("Foliage").material_override = mat

func on_bush_fertilized(id: int) -> void:
	reserve_state.fertilize(id)
	show_status("Fertilização %d/5" % reserve_state.fertilized_ids.size())

func on_player_death() -> void:
	reserve_state.restart_day()
	get_tree().call_deferred("reload_current_scene")

func show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
