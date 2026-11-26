@tool
extends "res://scripts/demo/campaign_room.gd"
## Cena de autoria salva; reconstrução de caminhos é sempre explícita.
signal navigation_rebuilt
@export_tool_button("Atualizar caminhos dos NPCs") var rebuild_action = rebuild_navigation
var _baking := false

func rebuild_navigation() -> void:
	if _baking:
		return
	_baking = true
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.75
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 38
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_baking_aabb = AABB(Vector3(-23, -2, -21), Vector3(46, 8, 42))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, func():
		get_node("Navegacao").navigation_mesh = mesh
		ResourceSaver.save(mesh, "res://resources/environments/habitat_1_navigation.res")
		_baking = false
		navigation_rebuilt.emit()
	)

func item_out_of_bounds(at: Vector3) -> bool:
	return absf(at.x) > 24.0 or absf(at.z) > 22.0 or at.y < -3.0
