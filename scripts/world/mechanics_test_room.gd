extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player/player.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/entities/items/world_item.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/constructions/transition_door.tscn")
const BUSH_SCRIPT: Script = preload("res://scripts/world/fertilizable_bush.gd")
const PANEL_SCRIPT: Script = preload("res://scripts/world/test_power_panel.gd")
const RADIATION_SCRIPT: Script = preload("res://scripts/world/radiation_zone.gd")
const ANIMAL_SCRIPT: Script = preload("res://scripts/world/test_animal.gd")
const FUSE: Resource = preload("res://resources/items/fuse.tres")
const FERTILIZER: Resource = preload("res://resources/items/fertilizer.tres")

var current_day: int = 1
var power_restored: bool = false
var briefing_heard: bool = false
var notebook_open: bool = false
var _status_label: Label
var _notebook_panel: PanelContainer
var _notebook_text: Label
var _player: CharacterBody3D
var _door_back: StaticBody3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_day = int(get_tree().root.get_meta("hz_mechanics_test_day", 1))
	_build_room()
	if current_day == 2:
		power_restored = true
		briefing_heard = true
		get_tree().root.set_meta("hz_test_fertilized", 5)
		for bush in get_tree().get_nodes_in_group("fertilizable_bushes"):
			bush.add_to_group("fertilized_bushes")
			var foliage := bush.get_node_or_null("Foliage") as MeshInstance3D
			if foliage != null:
				foliage.material_override = _material(Color(0.28, 0.62, 0.29))
	else:
		get_tree().root.remove_meta("hz_test_fertilized")
	_update_notebook()
	show_status("Dia 1 de teste — use o fusível no painel. Tab abre o caderno.")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_set_notebook_open(notebook_open == false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and notebook_open:
			_set_notebook_open(false)
			get_viewport().set_input_as_handled()


func restore_power() -> void:
	if power_restored:
		show_status("A energia já foi restaurada.")
		return
	power_restored = true
	for node in get_tree().get_nodes_in_group("radiation_zones"):
		node.set_physics_process(false)
	for node in get_tree().get_nodes_in_group("warning_lights"):
		if node is OmniLight3D:
			node.light_color = Color(0.2, 0.9, 0.35)
	_update_notebook()
	show_status("Energia restaurada. Buzzy está disponível no corredor.")


func hear_briefing() -> void:
	if not power_restored:
		show_status("Buzzy: primeiro precisamos de energia. Eu gosto de luzes. Geralmente.")
		return
	briefing_heard = true
	_update_notebook()
	show_status("Buzzy: fertilize os cinco arbustos marcados. Depois, registre o fim do dia no terminal de descanso.")


func on_bush_fertilized(_bush_id: int) -> void:
	var count := get_tree().get_nodes_in_group("fertilized_bushes").size()
	_update_notebook()
	if count >= 5:
		show_status("Cinco arbustos fertilizados. O cervo agora observa você em vez de fugir.")
	else:
		show_status("Arbustos fertilizados: %d/5. O fertilizante é consumido." % count)


func advance_day() -> void:
	if current_day != 1 or not power_restored or not briefing_heard or get_tree().get_nodes_in_group("fertilized_bushes").size() < 5:
		show_status("Ainda há tarefas do Dia 1 pendentes. Confira o caderno com Tab.")
		return
	get_tree().root.set_meta("hz_mechanics_test_day", 2)
	get_tree().root.set_meta("hz_test_fertilized", 5)
	current_day = 2
	for skunk in get_tree().get_nodes_in_group("test_skunks"):
		skunk.set_process(true)
	_update_notebook()
	show_status("Dia 2 de teste: o gambá agora protege os arbustos. Afaste-se para sair do alcance dele.")


func on_player_death() -> void:
	if current_day == 2:
		get_tree().root.set_meta("hz_mechanics_test_day", 2)
	else:
		get_tree().root.remove_meta("hz_mechanics_test_day")
		get_tree().root.remove_meta("hz_test_fertilized")
	get_tree().call_deferred("reload_current_scene")


func show_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _update_notebook() -> void:
	if _notebook_text == null:
		return
	var fertilizer_count := 5 if current_day == 2 else get_tree().get_nodes_in_group("fertilized_bushes").size()
	if current_day == 1:
		_notebook_text.text = "DIA 1 — TESTE DE MECÂNICAS\n\n%s  Restaurar a energia instalando o fusível\n%s  Ouvir o briefing de Buzzy\n%s  Fertilizar cinco arbustos (%d/5)\n\nEste caderno cobre apenas as mecânicas presentes nesta sala de teste.\nDepois, use o terminal de descanso para simular o Dia 2.\n\nM1 usa o item selecionado. E interage. Q solta." % ["✓" if power_restored else "□", "✓" if briefing_heard else "□", "✓" if fertilizer_count >= 5 else "□", fertilizer_count]
	else:
		_notebook_text.text = "DIA 2 — TESTE DE COMPORTAMENTO\n\n□  Observar o gambá protegendo os arbustos\n\nA tarefa principal do Dia 2 e o sonho final ainda serão definidos.\nEste marcador existe apenas para testar a reação territorial."


func _set_notebook_open(open: bool) -> void:
	notebook_open = open
	_notebook_panel.visible = open
	get_tree().paused = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var world_env := Environment.new()
	world_env.background_mode = Environment.BG_SKY
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color(0.23, 0.27, 0.3)
	world_env.ambient_light_energy = 0.65
	environment.environment = world_env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	light.light_energy = 1.15
	add_child(light)

	_add_box("Floor", Vector3(18.0, 0.5, 26.0), Vector3(0.0, -0.25, 0.0), Color(0.25, 0.29, 0.29))
	_add_box("NorthWall", Vector3(18.0, 4.0, 0.4), Vector3(0.0, 2.0, -13.0), Color(0.13, 0.18, 0.19))
	_add_box("WestWall", Vector3(0.4, 4.0, 26.0), Vector3(-9.0, 2.0, 0.0), Color(0.13, 0.18, 0.19))
	_add_box("EastWall", Vector3(0.4, 4.0, 26.0), Vector3(9.0, 2.0, 0.0), Color(0.13, 0.18, 0.19))
	_add_box("SouthWallLeft", Vector3(7.0, 4.0, 0.4), Vector3(-5.5, 2.0, 13.0), Color(0.13, 0.18, 0.19))
	_add_box("SouthWallRight", Vector3(7.0, 4.0, 0.4), Vector3(5.5, 2.0, 13.0), Color(0.13, 0.18, 0.19))
	_build_panel()
	_build_radiation_zone()
	_build_bushes()
	_build_animals()
	_build_fertilizer_pickups()
	_build_buzzy()
	_build_sleep_terminal()
	_build_door()
	_build_player()
	_build_hud()


func _build_panel() -> void:
	var panel := StaticBody3D.new()
	panel.name = "PowerPanel"
	panel.position = Vector3(0.0, 1.2, 0.7)
	panel.set_script(PANEL_SCRIPT)
	add_child(panel)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "PanelMesh"
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.8, 0.3)
	mesh_node.mesh = box
	mesh_node.material_override = _material(Color(0.24, 0.3, 0.32))
	panel.add_child(mesh_node)
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	lamp.mesh = sphere
	lamp.position = Vector3(0.0, 0.52, -0.17)
	lamp.material_override = _material(Color(0.85, 0.16, 0.1), true)
	panel.add_child(lamp)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.2, 1.8, 0.3)
	shape.shape = box_shape
	panel.add_child(shape)


func _build_radiation_zone() -> void:
	var zone := Area3D.new()
	zone.name = "RadiationZone"
	zone.set_script(RADIATION_SCRIPT)
	zone.position = Vector3(0.0, 1.1, 1.2)
	zone.add_to_group("radiation_zones")
	add_child(zone)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.5, 2.2, 3.0)
	shape.shape = box
	zone.add_child(shape)
	var warning := OmniLight3D.new()
	warning.name = "WarningLamp"
	warning.position = Vector3(0.0, 2.5, 2.7)
	warning.light_color = Color(1.0, 0.1, 0.05)
	warning.light_energy = 0.8
	warning.omni_range = 5.0
	warning.add_to_group("warning_lights")
	add_child(warning)


func _build_bushes() -> void:
	for index in range(5):
		var bush := StaticBody3D.new()
		bush.name = "FertilizableBush%d" % (index + 1)
		bush.position = Vector3(-5.0 + index * 2.5, 0.0, -7.0)
		bush.set_script(BUSH_SCRIPT)
		bush.set("bush_id", index)
		add_child(bush)
		var stem := MeshInstance3D.new()
		stem.name = "Stem"
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.12
		stem_mesh.bottom_radius = 0.18
		stem_mesh.height = 0.7
		stem.mesh = stem_mesh
		stem.position.y = 0.35
		stem.material_override = _material(Color(0.31, 0.25, 0.18))
		bush.add_child(stem)
		var foliage := MeshInstance3D.new()
		foliage.name = "Foliage"
		var foliage_mesh := SphereMesh.new()
		foliage_mesh.radius = 0.65
		foliage_mesh.height = 1.15
		foliage.mesh = foliage_mesh
		foliage.position.y = 0.95
		foliage.material_override = _material(Color(0.39, 0.38, 0.32))
		bush.add_child(foliage)
		var collision := CollisionShape3D.new()
		var collision_shape := BoxShape3D.new()
		collision_shape.size = Vector3(1.1, 1.5, 1.1)
		collision.shape = collision_shape
		collision.position.y = 0.75
		bush.add_child(collision)


func _build_animals() -> void:
	_add_animal("Deer", "deer", Vector3(-3.5, 0.0, -9.5), Color(0.49, 0.42, 0.34))
	_add_animal("Skunk", "skunk", Vector3(3.5, 0.0, -9.5), Color(0.23, 0.25, 0.27))


func _add_animal(node_name: String, kind: String, at: Vector3, tint: Color) -> void:
	var animal := Node3D.new()
	animal.name = node_name
	animal.position = at
	animal.set_script(ANIMAL_SCRIPT)
	animal.set("animal_kind", kind)
	if kind == "skunk":
		animal.add_to_group("test_skunks")
	add_child(animal)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38 if kind == "deer" else 0.3
	capsule.height = 1.1 if kind == "deer" else 0.65
	body.mesh = capsule
	body.position.y = capsule.height * 0.5
	body.material_override = _material(tint)
	animal.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24 if kind == "deer" else 0.2
	head_mesh.height = 0.42 if kind == "deer" else 0.36
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.9, -0.28)
	head.material_override = _material(tint.lightened(0.12))
	animal.add_child(head)


func _build_fertilizer_pickups() -> void:
	for index in range(5):
		var item := ITEM_SCENE.instantiate() as RigidBody3D
		item.name = "FertilizerPickup%d" % (index + 1)
		item.set("definition", FERTILIZER)
		item.position = Vector3(-3.2 + (index % 3) * 1.2, 0.2, 8.0 - floori(float(index) / 3.0) * 1.2)
		add_child(item)


func _build_buzzy() -> void:
	var buzzy := StaticBody3D.new()
	buzzy.name = "Buzzy"
	buzzy.position = Vector3(3.4, 1.0, 0.0)
	add_child(buzzy)
	buzzy.add_to_group("interactables")
	buzzy.set_script(preload("res://scripts/world/test_buzzy.gd"))
	var projection := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.76
	projection.mesh = mesh
	projection.material_override = _material(Color(0.1, 0.8, 1.0, 0.75), true)
	buzzy.add_child(projection)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	collision.shape = shape
	buzzy.add_child(collision)


func _build_sleep_terminal() -> void:
	var terminal := StaticBody3D.new()
	terminal.name = "RestTerminal"
	terminal.position = Vector3(6.8, 0.0, 8.2)
	terminal.add_to_group("interactables")
	terminal.set_script(preload("res://scripts/world/test_sleep_terminal.gd"))
	add_child(terminal)
	_add_child_box(terminal, Vector3(1.0, 1.3, 0.7), Color(0.36, 0.39, 0.4))
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = Vector3(1.0, 1.3, 0.7)
	shape.shape = collision
	terminal.add_child(shape)


func _build_door() -> void:
	_door_back = DOOR_SCENE.instantiate() as StaticBody3D
	_door_back.name = "DoorBackToPrototype"
	_door_back.position = Vector3(0.0, 0.0, 12.0)
	_door_back.set("destination_scene", "res://scenes/levels/prototype_room.tscn")
	_door_back.set("destination_door_path", NodePath("DoorToMechanicsTestRoom"))
	add_child(_door_back)


func _build_player() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.name = "Player"
	_player.position = Vector3(0.0, 0.9, 9.4)
	add_child(_player)
	var inventory: Node = _player.get_node("Inventory")
	inventory.call("set_slot_item", 0, FUSE)
	if current_day == 2:
		var restored_panel := get_node_or_null("PowerPanel")
		if restored_panel != null:
			restored_panel.call("accept_item", FUSE, _player)
		inventory.call("_refresh_hud")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MechanicsTestUI"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_status_label = Label.new()
	_status_label.name = "TestStatus"
	_status_label.position = Vector2(18.0, 110.0)
	_status_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_status_label)
	_notebook_panel = PanelContainer.new()
	_notebook_panel.name = "TaskNotebook"
	_notebook_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_notebook_panel.custom_minimum_size = Vector2(540.0, 280.0)
	_notebook_panel.visible = false
	layer.add_child(_notebook_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_notebook_panel.add_child(margin)
	_notebook_text = Label.new()
	_notebook_text.add_theme_font_size_override("font_size", 20)
	_notebook_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_notebook_text)


func _add_box(node_name: String, size: Vector3, at: Vector3, tint: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	add_child(body)
	_add_child_box(body, size, tint)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_child_box(parent: Node3D, size: Vector3, tint: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(tint)
	parent.add_child(mesh_node)


func _material(tint: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.82
	if emissive:
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.4
	return material
