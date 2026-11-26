@tool
extends "res://scripts/demo/campaign_room.gd"
## Layout salvo na cena; esta ferramenta atualiza apenas a navegação.
signal navigation_rebuilt
@export_tool_button("Atualizar caminhos dos NPCs") var rebuild_action = rebuild_navigation
var _baking := false
var _deer_art_resolution := 96

func cycle_deer_art_resolution() -> int:
	_deer_art_resolution = 128 if _deer_art_resolution == 96 else 96
	for group_path in ["Fauna", "DreamEvent/DeerCircle"]:
		for actor in get_node(group_path).get_children():
			var billboard := actor.get_node_or_null("EventSprite") as AnimatedSprite3D
			if billboard != null and billboard.has_method("set_art_resolution"):
				billboard.set_art_resolution(_deer_art_resolution)
	return _deer_art_resolution

func rebuild_navigation() -> void:
	if _baking:
		return
	var region := get_node_or_null("Navegacao") as NavigationRegion3D
	if region == null:
		push_error("Attis precisa do nó Navegacao para atualizar caminhos.")
		return
	_baking = true
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.75
	mesh.agent_height = 1.5
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 38.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_baking_aabb = AABB(Vector3(-64, -5, -85), Vector3(128, 65, 161))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, func() -> void:
		region.navigation_mesh = mesh
		var error := ResourceSaver.save(mesh, "res://resources/environments/attis_navigation.res")
		if error != OK:
			push_error("Não foi possível salvar os caminhos de Attis: %d" % error)
		_baking = false
		navigation_rebuilt.emit()
	)


@export_category("Prévia de level design — somente editor")
@export_enum("Dia 1 / normal", "Dia 2", "Dia 3 / edição clara", "Dia 3 / noite") var editor_day_preview: int = 0:
	set(value):
		editor_day_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			apply_editor_preview.call_deferred()
@export_tool_button("Prévia do desfecho com luz de edição") var preview_dream_action = preview_dream_for_editing
@export_tool_button("Restaurar prévia normal") var preview_normal_action = preview_normal
@export_storage var _editor_preview_applied := false
@export_storage var _editor_original_environment: Environment
@export_storage var _editor_original_sun_energy: float = 0.7

func _ready() -> void:
	if Engine.is_editor_hint():
		apply_editor_preview.call_deferred()
	else:
		restore_preview_for_game()
		super._ready()

func preview_dream_for_editing() -> void:
	editor_day_preview = 2

func preview_normal() -> void:
	editor_day_preview = 0

func apply_editor_preview() -> void:
	if not is_inside_tree() or not has_node("DreamEvent"):
		return
	var environment: WorldEnvironment = get_node("Ambiente_Nevoeiro")
	var sun: DirectionalLight3D = get_node("LuzNublada")
	if editor_day_preview != 0 and not _editor_preview_applied:
		_editor_original_environment = environment.environment
		_editor_original_sun_energy = sun.light_energy
		_editor_preview_applied = true
	if _editor_preview_applied and _editor_original_environment != null:
		environment.environment = _editor_original_environment.duplicate()
		sun.light_energy = _editor_original_sun_energy
	var dream := editor_day_preview >= 2
	get_node("DreamEvent").visible = dream
	get_node("Fauna").visible = not dream
	for group_path in ["DreamEvent/DeerCircle", "DreamEvent/DeadSkunks"]:
		for actor in get_node(group_path).get_children():
			var billboard := actor.get_node_or_null("EventSprite") as AnimatedSprite3D
			if billboard != null:
				billboard.preview_pose(editor_day_preview == 2)
	var bushes := get_node_or_null("ArbustosDePesquisa")
	if bushes != null:
		for bush in bushes.get_children():
			bush.visible = bush.get("available_from_day") <= (1 if editor_day_preview == 0 else 2)
	if editor_day_preview == 2:
		environment.environment.fog_enabled = false
		environment.environment.ambient_light_energy = .85
		sun.light_energy = 1.0
	elif editor_day_preview == 3:
		environment.environment.ambient_light_energy = .025
		environment.environment.ambient_light_color = Color("384558")
		environment.environment.background_color = Color("020307")
		environment.environment.fog_light_color = Color("101720")
		sun.light_energy = 0
	elif editor_day_preview == 0:
		_editor_preview_applied = false

func restore_preview_for_game() -> void:
	if _editor_preview_applied and _editor_original_environment != null:
		get_node("Ambiente_Nevoeiro").environment = _editor_original_environment.duplicate()
		get_node("LuzNublada").light_energy = _editor_original_sun_energy
	_editor_preview_applied = false
	if has_node("DreamEvent"):
		get_node("DreamEvent").visible = false
		get_node("DreamEvent").process_mode = Node.PROCESS_MODE_DISABLED
	get_node("Fauna").visible = true
