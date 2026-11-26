extends Node
func run() -> void:
	var tree := get_tree()
	var progress := get_node("/root/ReserveState")
	progress.reset()
	progress.day = 2
	progress.power_restored = true
	progress.robot_activated = true
	progress.day2_briefing_heard = true
	progress.register_analysis("attis")
	progress.register_analysis("habitat1")
	for id in range(1000,1010): progress.fertilize(id)
	tree.change_scene_to_file("res://scenes/levels/attis_forest.tscn")
	await tree.scene_changed
	await tree.create_timer(.8).timeout
	var sim := get_node("/root/ReserveSimulation")
	sim.robot_room_key = sim.ATTIS
	var robot: CharacterBody3D = sim.robot
	robot.global_position = Vector3(0,24.5,-50)
	robot.navigation_relocated()
	var rows: Array = []
	for i in range(80):
		await tree.create_timer(.25).timeout
		if sim.robot_room_key != sim.ATTIS: break
		if i%4 == 0 or robot.stalled > .5:
			var hits: Array = []
			for j in range(robot.get_slide_collision_count()):
				var c := robot.get_slide_collision(j)
				hits.append({"collider":str(c.get_collider().get_path()),"point":c.get_position(),"normal":c.get_normal()})
			rows.append({"pos":robot.position,"state":robot.state,"stalled":robot.stalled,"hits":hits})
	var result := {"room":sim.robot_room_key,"rows":rows}
	var f := FileAccess.open("res://tests/top_robot_diagnostic.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	print("TOP_DIAGNOSTIC ",result)
	tree.quit()
