extends CharacterBody3D
const DELIVERY_DURATION := 0.85

@onready var reserve_state: Node = get_node("/root/ReserveState")
@export var service_range: float = 2.25
@export var fertilizer_capacity: int = 3
@export var refill_duration: float = 3.0
@export var treatment_duration: float = 2.0
@export var walk_speed: float = 1.9
@export var max_step_height: float = 0.4
@export var personal_space: float = 1.6
var state: String = "adormecido"
var service_time: float = 0.0
var repath_time: float = 0.0
var stalled: float = 0.0
var last_position: Vector3
var fertilizer_stock: int = 3
var _target_kind: String = "fertilize"
var sample_collectors: Dictionary = {}
var _sample_day: int = 0
var _target: Node3D
var _approach: Vector3
var _approach_key: String = ""
var _scan_timer: float = 0.0
var _refill_timer: float = 0.0
var _delivery_time: float = 0.0
var _clock: float = 0.0
var _failed_approaches: Dictionary = {}
var _wanted_velocity := Vector3.ZERO
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var label: Label3D = $StateLabel

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("mobile_npcs")
	last_position = global_position
	fertilizer_stock = maxi(1, fertilizer_capacity)
	_sync_collectors()
	reserve_state.changed.connect(_on_work_changed)

func _on_work_changed() -> void:
	_scan_timer = 0.0
	_sync_collectors()

func navigation_relocated() -> void:
	_target = null
	_scan_timer = 0.0
	repath_time = 0.0
	stalled = 0.0
	service_time = 0.0
	_delivery_time = 0.0
	velocity = Vector3.ZERO
	last_position = global_position
	_failed_approaches.clear()
	agent.target_position = global_position

func interact(_actor: Node) -> void:
	if reserve_state.is_dream:
		_status("Sem energia.")
		return
	if reserve_state.day < 2:
		_status("Robô indisponível no Dia 1. Buzzy terá novas instruções no Dia 2.")
		return
	if get_node("/root/DemoSession").is_campaign(get_tree().current_scene) and not reserve_state.day2_briefing_heard:
		_status("Fale com Buzzy para receber as instruções de automação do Dia 2.")
		return
	if not reserve_state.power_restored:
		_status("Robô: sem energia.")
		return
	reserve_state.robot_activated = true
	reserve_state.changed.emit()
	stalled = 0.0
	_failed_approaches.clear()
	_status("Robô ativado: aplica adubo, coleta amostras em Attis/Habitat 1 e entrega no laboratório. Depois retorna à base.")

func interaction_prompt() -> String:
	var ready_to_activate: bool = reserve_state.day >= 2 and reserve_state.power_restored and reserve_state.day2_briefing_heard and not reserve_state.robot_activated
	return "E  •  Ativar robô ajudante" if ready_to_activate else "E  •  Verificar robô ajudante"

func _physics_process(delta: float) -> void:
	_clock += delta
	_scan_timer -= delta
	repath_time -= delta
	_wanted_velocity = Vector3.ZERO
	var simulation := get_node("/root/ReserveSimulation")
	var room: Node3D = simulation.room_for_robot()
	if reserve_state.day < 2 or not reserve_state.robot_activated or not reserve_state.power_restored:
		state = "adormecido"
		_delivery_time = 0.0
	elif fertilizer_stock <= 0:
		state = "repondo fertilizante"
		_refill_timer += delta
		if _refill_timer >= refill_duration:
			fertilizer_stock = maxi(1, fertilizer_capacity)
			_refill_timer = 0.0
	elif room != null and NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		_work(delta, room, simulation)
	var horizontal := preload("res://scripts/entities/npcs/npc_spacing.gd").velocity_for(self, _wanted_velocity, walk_speed, personal_space)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.1 if is_on_floor() else velocity.y - 9.8 * delta
	_try_step_up(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	if state in ["andando", "indo para outra sala", "retornando à base", "levando amostras ao laboratório"] and global_position.distance_to(last_position) < 0.005:
		stalled += delta
	else:
		stalled = 0.0
	last_position = global_position
	if label.visible:
		label.text = "Ajudante · %s · adubo %d/%d · amostras %d/6" % [state.replace("fertilizante", "adubo").replace("fertilizando", "adubando"), fertilizer_stock, fertilizer_capacity, sample_count()]

func _work(delta: float, room: Node3D, simulation: Node) -> void:
	_sync_collectors()
	if has_delivery():
		_target = null
		service_time = 0.0
		_follow_route(delta, simulation.route_for_robot(), simulation)
		return
	_delivery_time = 0.0
	if not _valid_target(_target) or not room.is_ancestor_of(_target):
		_target = null
		service_time = 0.0
		if _scan_timer <= 0.0:
			_target = _find_target()
			_scan_timer = 0.6
			stalled = 0.0
			repath_time = 0.0
	if _target == null:
		_follow_route(delta, simulation.route_for_robot(), simulation)
	elif global_position.distance_to(_target.global_position) < service_range and _can_service(_target):
		state = "escaneando" if service_time < 0.6 else ("coletando amostras" if _target_kind == "sample" else "fertilizando")
		service_time += delta
		if service_time >= treatment_duration:
			var completed := false
			if _target_kind == "sample":
				var tool: Resource = sample_collectors[_target.sample_origin]
				var before: int = tool.sample_ids.size()
				_target.collect_sample(tool)
				completed = tool.sample_ids.size() > before
			else:
				completed = _target.accept_item(preload("res://resources/items/fertilizer.tres"), self)
				if completed:
					fertilizer_stock -= 1
			if completed:
				reserve_state.robot_service_done = true
				reserve_state.changed.emit()
			_target = null
			service_time = 0.0
	elif stalled >= 1.2:
		_failed_approaches[_approach_key] = _clock + 8.0
		_target = null
		service_time = 0.0
		_scan_timer = 0.0
		state = "recalculando rota"
	else:
		state = "andando"
		_navigate(_approach)

func _follow_route(delta: float, route: Dictionary, simulation: Node) -> void:
	if route.is_empty():
		_delivery_time = 0.0
		state = "aguardando rota"
		return
	var point: Vector3 = route.point
	var offset := point - global_position
	offset.y = 0.0
	if offset.length() <= 0.7:
		if route.kind == "door":
			state = "atravessando porta"
			simulation.cross_door(route.door)
		elif route.kind == "delivery":
			state = "entregando amostras"
			_delivery_time += delta
			if _delivery_time < DELIVERY_DURATION:
				return
			_delivery_time = 0.0
			for origin in sample_collectors:
				var tool: Resource = sample_collectors[origin]
				if tool.sample_ids.size() == 3 and tool.sample_day == reserve_state.day:
					reserve_state.register_analysis(origin)
					tool.empty_samples()
			_scan_timer = 0.0
		else:
			state = "na base"
		return
	_delivery_time = 0.0
	state = "indo para outra sala" if route.kind == "door" else ("levando amostras ao laboratório" if route.kind == "delivery" else "retornando à base")
	if stalled > 1.2:
		repath_time = 0.0
	_navigate(point)

## Presentation uses the real service point, independently of the navigation goal.
func visual_facing_hint() -> Vector3:
	if state == "entregando amostras":
		var room: Node3D = get_node("/root/ReserveSimulation").room_for_robot()
		var bench := room.get_node_or_null("Laboratorio") as Node3D if room != null else null
		if bench != null:
			return bench.global_position - global_position
	elif is_instance_valid(_target) and state in ["escaneando", "fertilizando", "coletando amostras"]:
		return _target.global_position - global_position
	return get_real_velocity()

func _navigate(point: Vector3) -> void:
	if repath_time <= 0.0:
		agent.target_position = point
		repath_time = 0.5
	if not agent.is_navigation_finished():
		var direction := agent.get_next_path_position() - global_position
		direction.y = 0.0
		_wanted_velocity = direction.normalized() * walk_speed

func _valid_target(target: Node3D, kind: String = "") -> bool:
	if not is_instance_valid(target) or target.available_from_day > reserve_state.day:
		return false
	if kind.is_empty():
		kind = _target_kind
	if kind == "sample":
		return needs_sample(target)
	return target.can_fertilize and not target.is_in_group("fertilized_bushes")

func _find_target() -> Node3D:
	var room: Node3D = get_node("/root/ReserveSimulation").room_for_robot()
	if room == null:
		return null
	var best: Node3D
	var best_distance := INF
	var map := agent.get_navigation_map()
	var jobs: Array = []
	for bush in room.get_room_bushes():
		jobs.append({"bush":bush,"kind":"fertilize"})
	if room.has_method("get_sample_bushes"):
		for bush in room.get_sample_bushes():
			jobs.append({"bush":bush,"kind":"sample"})
	for job in jobs:
		var candidate: Node3D = job.bush
		if not _valid_target(candidate, job.kind):
			continue
		for index in range(16):
			var key := "%d:%d:%s" % [candidate.get_instance_id(), index, job.kind]
			if float(_failed_approaches.get(key, 0.0)) > _clock:
				continue
			var angle := TAU * float(index) / 16.0
			var point: Vector3 = candidate.global_position + Vector3(cos(angle)*1.65, -0.45, sin(angle)*1.65)
			point = NavigationServer3D.map_get_closest_point(map, point)
			if point.distance_to(candidate.global_position) > service_range-0.15 or not _can_service_from(point,candidate):
				continue
			var path := NavigationServer3D.map_get_path(map,global_position,point,true)
			if path.is_empty() or path[-1].distance_to(point) > 0.6:
				continue
			var distance := 0.0
			for step in range(1,path.size()):
				distance += path[step].distance_to(path[step-1])
			if distance < best_distance:
				best = candidate
				best_distance = distance
				_approach = point
				_approach_key = key
				_target_kind = job.kind
	return best

func _sync_collectors() -> void:
	if _sample_day != reserve_state.day:
		sample_collectors.clear()
		_sample_day = reserve_state.day
		for origin in ["attis", "habitat1"]:
			sample_collectors[origin] = preload("res://resources/items/sample_collector.tres").duplicate(true)
	# A player delivery cancels the matching robot collection, without duplicate credit.
	for origin in reserve_state.analysed_samples:
		if sample_collectors.has(origin):
			sample_collectors[origin].empty_samples()

func needs_sample(bush: Node3D) -> bool:
	if bush.sample_origin not in sample_collectors or bush.sample_origin in reserve_state.analysed_samples:
		return false
	var tool: Resource = sample_collectors[bush.sample_origin]
	return bush.available_from_day <= reserve_state.day and not reserve_state.was_sampled_today(bush.sample_origin,bush.bush_id) and tool.sample_ids.size() < 3 and bush.bush_id not in tool.sample_ids

func has_delivery() -> bool:
	for tool in sample_collectors.values():
		if tool.sample_ids.size() == 3:
			return true
	return false

func sample_count() -> int:
	var count := 0
	for tool in sample_collectors.values():
		count += tool.sample_ids.size()
	return count

func _try_step_up(motion: Vector3) -> void:
	if not is_on_floor() or motion.length_squared() < 0.0001 or not test_move(global_transform,motion):
		return
	var step := 0.05
	while step <= max_step_height + 0.001:
		var lift := Vector3.UP*step
		var raised := global_transform.translated(lift)
		if not test_move(global_transform,lift) and not test_move(raised,motion):
			var landing := KinematicCollision3D.new()
			if test_move(raised.translated(motion),Vector3.DOWN*(step+floor_snap_length),landing) and landing.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
				global_position.y += step
				velocity.y = 0.0
				return
		step += 0.05

func _can_service(target: Node3D) -> bool:
	return _can_service_from(global_position, target)

func _can_service_from(at: Vector3, target: Node3D) -> bool:
	var foliage := target.get_node_or_null("Foliage") as Node3D
	var aim := foliage.global_position if foliage != null else target.global_position + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, aim, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target or target.is_ancestor_of(hit.get("collider"))

func _status(message: String) -> void:
	var room := get_tree().current_scene
	if room != null and room.has_method("show_status"):
		room.call("show_status", message)
