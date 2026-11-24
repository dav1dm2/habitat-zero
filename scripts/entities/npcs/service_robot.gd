extends CharacterBody3D
@onready var reserve_state: Node = get_node("/root/ReserveState")
@export var service_target: NodePath
@export var service_range: float = 1.8
var state: String = "adormecido"
var service_time: float = 0.0
var repath_time: float = 0.0
var stalled: float = 0.0
var last_position: Vector3
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var label: Label3D = $StateLabel

func _ready() -> void:
	add_to_group("interactables")
	last_position = global_position

func interact(_actor: Node) -> void:
	if not reserve_state.power_restored:
		_status("Robô: sem energia. Use F1 no teste.")
		return
	reserve_state.robot_activated = true
	reserve_state.changed.emit()
	stalled = 0.0
	_status("Robô ativado. Serviço próprio: escanear e tratar a planta azul.")

func _physics_process(delta: float) -> void:
	var horizontal := Vector3.ZERO
	var target := get_node_or_null(service_target) as Node3D
	if not reserve_state.robot_activated:
		state = "adormecido"
	elif reserve_state.robot_service_done:
		state = "aguardando"
	elif target == null:
		state = "sem alvo"
	elif NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		repath_time -= delta
		if global_position.distance_to(target.global_position) < service_range and _can_service(target):
			state = "escaneando / tratando"
			service_time += delta
			if service_time >= 2.0:
				reserve_state.robot_service_done = true
				reserve_state.changed.emit()
		elif stalled >= 2.0:
			state = "caminho bloqueado · E tentar"
		else:
			state = "andando"
			if repath_time <= 0.0:
				agent.target_position = target.global_position
				repath_time = 0.5
			if not agent.is_navigation_finished():
				horizontal = agent.get_next_path_position() - global_position
				horizontal.y = 0.0
				horizontal = horizontal.normalized() * 1.8
			if global_position.distance_to(last_position) < 0.005:
				stalled += delta
			else:
				stalled = 0.0
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.1 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	last_position = global_position
	label.text = "Manutenção · %s" % state


func _can_service(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, target.global_position, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target or target.is_ancestor_of(hit.get("collider"))


func _status(message: String) -> void:
	var room := get_tree().current_scene
	if room != null and room.has_method("show_status"):
		room.call("show_status", message)
