extends Node
## Mantém um robô real e as três áreas da campanha carregadas, sem trocar a cena do jogador.
const RANGE := "res://scenes/levels/npc_test_range.tscn"
const MECHANICS := "res://scenes/levels/mechanics_test_room.tscn"
const ATTIS := "res://scenes/levels/attis_forest.tscn"
const HABITAT := "res://scenes/levels/habitat_1.tscn"
const INTERIOR := "res://scenes/levels/attis_interior.tscn"
const ROBOT = preload("res://scenes/entities/npcs/service_robot.tscn")
var rooms: Dictionary = {}
var active_room: Node3D
var robot: CharacterBody3D
var robot_room_key: String = RANGE
var base_room_key: String = RANGE
var _robot_local: Vector3 = Vector3(-6, 1.1, 15)
var _initialized: bool = false
var _changing: bool = false
var _campaign_mode: bool = false

func _ready() -> void:
	get_tree().scene_changed.connect(_scene_changed)

func _scene_changed() -> void:
	call_deferred("_settle_scene")

func _settle_scene() -> void:
	if get_tree().current_scene != null and get_tree().current_scene.get_meta("menu_scene",false):
		clear_simulation()
		return
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		return
	if scene != null and scene.has_method("get_room_key"):
		register_active_room(scene)
	else:
		_configure(null)

func register_active_room(room: Node3D) -> void:
	if room.get_meta("authoring_build", false) or room.get_meta("simulation_background", false):
		return
	if active_room == room and rooms.size() == (3 if _campaign_mode else 2) and not _changing:
		return
	_configure(room)

func prepare_player_travel() -> void:
	_capture_position()
	_changing = true
	if is_instance_valid(robot):
		robot.set_physics_process(false)

func _capture_position() -> void:
	var current = rooms.get(robot_room_key)
	if is_instance_valid(robot) and is_instance_valid(current):
		_robot_local = current.to_local(robot.global_position)

func _configure(room: Node3D) -> void:
	if get_node("/root/ReserveState").is_dream:
		suspend_for_dream(room)
		return
	_capture_position()
	var campaign: bool = room != null and room.get_room_key() in [ATTIS, INTERIOR, HABITAT]
	if campaign != _campaign_mode:
		_campaign_mode = campaign
		base_room_key = INTERIOR if campaign else RANGE
		robot_room_key = base_room_key
		_initialized = false
		if is_instance_valid(robot):
			robot.free()
			robot = null
	for old in rooms.values():
		if is_instance_valid(old) and old != room and old.get_meta("simulation_background", false):
			old.get_parent().remove_child(old)
			old.queue_free()
	rooms.clear()
	active_room = room
	if room != null:
		rooms[room.get_room_key()] = room
	var offset := 400.0
	var keys: Array = [ATTIS, INTERIOR, HABITAT] if campaign else [RANGE, MECHANICS]
	for key in keys:
		if rooms.has(key):
			continue
		var background := load(key).instantiate() as Node3D
		background.set_meta("simulation_background", true)
		background.position.x = offset
		offset += 400.0
		_strip_background(background, true)
		add_child(background)
		background.visible = false
		_strip_background(background, false)
		rooms[key] = background
	if not is_instance_valid(robot):
		robot = ROBOT.instantiate() as CharacterBody3D
		robot.name = "ReserveRobot"
		add_child(robot)
	for current in rooms.values():
		var placeholder: Node = current.get_node_or_null("ServiceRobot")
		if placeholder != null:
			placeholder.get_parent().remove_child(placeholder)
			placeholder.queue_free()
	var destination := room_for_robot()
	if not _initialized:
		_robot_local = destination.to_local(destination.get_node("RobotBase").global_position)
		_initialized = true
	robot.process_mode = Node.PROCESS_MODE_INHERIT
	robot.get_node("StateLabel").visible = not campaign
	robot.collision_layer = 8
	robot.collision_mask = 9
	robot.global_position = destination.to_global(_robot_local)
	robot.visible = destination == active_room
	robot.navigation_relocated()
	robot.set_physics_process(true)
	_changing = false

func _strip_background(node: Node, before_ready: bool) -> void:
	for child in node.get_children():
		if before_ready and (child.name == "Player" or child.name == "ServiceRobot" or child is WorldEnvironment):
			node.remove_child(child)
			child.free()
			continue
		if child is CanvasLayer:
			child.visible = false
		if child is CharacterBody3D or child is Area3D:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.collision_layer = 0
			child.collision_mask = 0
			if not before_ready:
				child.remove_from_group("animals")
				child.remove_from_group("mobile_npcs")
		if not before_ready and child.get_script() == preload("res://scripts/entities/npcs/animal_group.gd"):
			child.set_physics_process(false)
		_strip_background(child, before_ready)

func room_for_robot() -> Node3D:
	var room = rooms.get(robot_room_key)
	return room as Node3D if is_instance_valid(room) else null

func pending_in(room: Node3D) -> bool:
	if not is_instance_valid(room):
		return false
	var progress := get_node("/root/ReserveState")
	for bush in room.get_room_bushes():
		if bush.available_from_day <= progress.day and not bush.is_in_group("fertilized_bushes"):
			return true
	if room.has_method("get_sample_bushes"):
		for bush in room.get_sample_bushes():
			if bush.sample_origin not in progress.analysed_samples and robot.needs_sample(bush):
				return true
	return false

func _doors(room: Node3D) -> Array[Node]:
	var result: Array[Node] = []
	for child in room.get_children():
		if child is StaticBody3D and child.get_script() == preload("res://scripts/world/transition_door.gd") and rooms.has(child.destination_scene):
			result.append(child)
	return result

func door_approach(door: Node3D) -> Vector3:
	var marker := door.get_node_or_null("Arrival") as Node3D
	var point := marker.global_position - Vector3.UP * 0.9 if marker != null else door.global_position - door.global_basis.z * 1.5
	var room: Node3D = door.get_parent()
	return NavigationServer3D.map_get_closest_point(room.get_node("Navegacao").get_navigation_map(), point) if room.has_node("Navegacao") else point

func route_for_robot() -> Dictionary:
	var current := room_for_robot()
	if current == null:
		return {}
	var desired := ""
	if robot.has_delivery() and _campaign_mode:
		desired = INTERIOR
		if robot_room_key == INTERIOR:
			return {"kind":"delivery", "point":current.get_node("LabApproach").global_position}
	else:
		for key in rooms:
			if key != robot_room_key and pending_in(rooms[key]):
				desired = key
				break
	if desired.is_empty() and robot_room_key != base_room_key:
		desired = base_room_key
	if desired.is_empty():
		return {"kind":"base", "point":current.get_node("RobotBase").global_position}
	# Rooms form a graph: Attis -> installations -> H1, never a direct jump.
	var queue: Array = [{"key":robot_room_key,"first":null}]
	var visited: Array = [robot_room_key]
	while not queue.is_empty():
		var step: Dictionary = queue.pop_front()
		for door in _doors(rooms[step.key]):
			var first: Node3D = door if step.first == null else step.first
			if door.destination_scene == desired:
				return {"kind":"door", "door":first,"point":door_approach(first)}
			if door.destination_scene not in visited:
				visited.append(door.destination_scene)
				queue.append({"key":door.destination_scene,"first":first})
	return {}

func cross_door(door: Node3D) -> void:
	var destination: Node3D = rooms.get(door.destination_scene)
	if not is_instance_valid(destination):
		return
	var counterpart := destination.get_node_or_null(door.destination_door_path) as Node3D
	if counterpart == null:
		return
	robot_room_key = door.destination_scene
	var at := door_approach(counterpart) + Vector3.UP * 0.05
	robot.global_position = at
	robot.visible = destination == active_room
	_robot_local = destination.to_local(at)
	robot.navigation_relocated()

func reset_robot() -> void:
	robot_room_key = base_room_key
	_initialized = false
	if is_instance_valid(robot):
		robot.queue_free()
		robot = null
	call_deferred("_settle_scene")


func _exit_tree() -> void:
	rooms.clear()
	active_room = null
	robot = null

func suspend_for_dream(room: Node3D) -> void:
	for old in rooms.values():
		if is_instance_valid(old) and old != room and old.get_meta("simulation_background",false):
			old.get_parent().remove_child(old)
			old.queue_free()
	rooms.clear()
	active_room = room
	if room != null:
		rooms[room.scene_file_path] = room
	if is_instance_valid(robot):
		robot.visible = false
		robot.process_mode = Node.PROCESS_MODE_DISABLED
		robot.collision_layer = 0
		robot.collision_mask = 0
	_changing = false

func clear_simulation() -> void:
	for room in rooms.values():
		if is_instance_valid(room) and room.get_meta("simulation_background",false):
			room.get_parent().remove_child(room)
			room.queue_free()
	rooms.clear()
	active_room = null
	if is_instance_valid(robot):
		robot.get_parent().remove_child(robot)
		robot.queue_free()
	robot = null
	_initialized = false
	_changing = false
	_campaign_mode = false
	base_room_key = RANGE
	robot_room_key = RANGE
