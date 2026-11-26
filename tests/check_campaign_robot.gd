extends Node
var tree: SceneTree
var elapsed := 0.0
var treated := false
var done := false
var simulation: Node
var progress: Node
var checks: Array = []

func run() -> void:
	tree = get_tree()
	progress = get_node("/root/ReserveState")
	progress.reset()
	tree.change_scene_to_file("res://scenes/levels/attis_interior.tscn")
	await tree.scene_changed
	await tree.create_timer(0.8).timeout
	var room := tree.current_scene
	simulation = get_node("/root/ReserveSimulation")
	var map: RID = room.get_node("Navegacao").get_navigation_map()
	for marker_name in ["StorageApproach","BedApproach","LabApproach","PanelApproach","BuzzyApproach","Habitat1Approach","Habitat2Approach"]:
		var at: Vector3 = room.get_node(marker_name).global_position
		var path := NavigationServer3D.map_get_path(map, Vector3(0,0,11), at, true)
		checks.append({"point":str(at),"pass":not path.is_empty() and path[-1].distance_to(at) < 1.0})
	progress.day = 2
	progress.day2_briefing_heard = true
	progress.register_analysis("attis")
	progress.register_analysis("habitat1")
	progress.power_restored = true
	progress.briefing_heard = true
	for id in range(1000,1010):
		if id != 1004:
			progress.fertilize(id)
	progress.changed.emit()
	simulation.robot.interact(room.get_node("Player"))
	set_physics_process(true)

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if done:
		return
	elapsed += delta
	if 1004 in progress.fertilized_ids:
		treated = true
	var returned: bool = treated and simulation.robot_room_key == simulation.base_room_key and simulation.robot.state == "na base"
	if not returned and elapsed < 115:
		return
	done = true
	var result := {"treated":treated,"returned":returned,"seconds":elapsed,"state":simulation.robot.state,"robot_position":str(simulation.robot.global_position),"room":simulation.robot_room_key,"paths":checks}
	var file := FileAccess.open("res://tests/campaign_robot_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("CAMPAIGN_ROBOT: ",result)
	tree.quit(0 if returned else 1)
