extends Node
var level: Node3D
var player: CharacterBody3D
var builder: RefCounted
var elapsed := 0.0
var finished := false
func _ready() -> void:
	builder = load("res://scripts/world/tools/build_attis.gd").new()
	level = load("res://scenes/levels/attis_forest.tscn").instantiate()
	add_child(level)
	player = level.get_node("Player")
	Input.action_press("move_forward")
func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	var z := player.position.z - 3.0
	var target: Vector3 = builder.ground(builder.trail_x(z), z)
	var direction := target - player.position
	player.rotation.y = atan2(-direction.x, -direction.z)
	if player.position.z > -59 and elapsed < 65:
		return
	finished = true
	Input.action_release("move_forward")
	var hits := 0
	for z_sample in [-70.0, -20.0, 30.0, 65.0]:
		for side in [-1.0, 1.0]:
			var start: Vector3 = builder.ground(62 * side, z_sample, 1.5)
			var end: Vector3 = start + Vector3(7 * side, 0, 0)
			var query := PhysicsRayQueryParameters3D.create(start, end, 1)
			if not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				hits += 1
	var result := {"completed": player.position.z <= -59, "floor": player.is_on_floor(), "end": str(player.position), "seconds": elapsed, "fence_hits": hits, "fence_rays": 8}
	var file := FileAccess.open("res://tests/attis_walk_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("ATTIS_WALK: ",result)
	get_tree().quit()
func _exit_tree() -> void:
	Input.action_release("move_forward")
