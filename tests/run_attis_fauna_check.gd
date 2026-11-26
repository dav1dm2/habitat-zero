extends Node
func _ready() -> void:
	var level = load("res://scenes/levels/attis_forest.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(1.0).timeout
	# Also verify the inspector rebake uses the current authored obstacles.
	level.rebuild_navigation()
	await level.navigation_rebuilt
	await get_tree().create_timer(0.5).timeout
	var p = level.get_node("Player")
	var results := []
	for animal in level.get_node("Fauna").get_children():
		p.position = Vector3(0,1,70)
		await get_tree().create_timer(0.3).timeout
		var start: Vector3 = animal.position
		var map: RID = animal.agent.get_navigation_map()
		var away := Vector3(0,0,2.8)
		var near: Vector3 = NavigationServer3D.map_get_closest_point(map, start + away)
		p.position = near + Vector3.UP * 0.95
		p.velocity = Vector3.ZERO
		await get_tree().create_timer(0.3).timeout
		var reaction: String = animal.state
		await get_tree().create_timer(0.8).timeout
		var travel := Vector2(animal.position.x-start.x, animal.position.z-start.z).length()
		results.append({"name":animal.name,"state":reaction,"moved":travel,"floor":animal.is_on_floor(),"pass":reaction == "fugindo" and travel > 0.2 and animal.is_on_floor()})
	var file := FileAccess.open("res://tests/attis_fauna_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	print("ATTIS_FAUNA_CHECK: ",results)
	get_tree().quit()
