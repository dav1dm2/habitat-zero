@tool
extends "res://scripts/demo/campaign_room.gd"
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
	mesh.agent_height = 1.5
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 38
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, func():
		get_node("Navegacao").navigation_mesh = mesh
		ResourceSaver.save(mesh, "res://resources/environments/attis_interior_navigation.res")
		_baking = false
		navigation_rebuilt.emit()
	)
