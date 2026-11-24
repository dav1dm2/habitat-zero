extends CharacterBody3D
@onready var reserve_state: Node = get_node("/root/ReserveState")
## Locomoção física e ações comuns. Os recursos de cada espécie são cenas separadas.
signal state_changed(value: String)
@export_enum("Cervo", "Gambá", "Kiwi", "Pukeko") var species: int = 0
@export var display_name: String = "Cervo"
@export var walk_speed: float = 1.3
@export var run_speed: float = 3.6
@export var attention_radius: float = 9.0
@export var fear_radius: float = 4.5
@export var territory_radius: float = 7.0
@export var attack_range: float = 1.65
@export var damage: float = 10.0
@export var debug_labels: bool = true

var state: String = "repouso"
var home: Vector3
var group_controller: Node3D
var player: Node3D
var _goal: Vector3
var _goal_timer: float = 0.0
var _action_timer: float = 0.0
var _warning_time: float = 0.0
var _attack_timer: float = -1.0
var _cooldown: float = 0.0
var _memory: float = 0.0
var _fleeing: bool = false
var _stuck_time: float = 0.0
var _last_position: Vector3
var _rng := RandomNumberGenerator.new()
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var label: Label3D = $StateLabel
@onready var visual: MeshInstance3D = $Visual

func _ready() -> void:
	home = global_position
	_goal = home
	_last_position = home
	_rng.seed = hash(str(get_path()))
	add_to_group("animals")
	if get_parent().has_method("register"):
		group_controller = get_parent()
		group_controller.register(self)
	label.visible = debug_labels
	var material := StandardMaterial3D.new()
	material.albedo_color = [Color("a78b65"), Color("515964"), Color("ac9867"), Color("424a71")][species]
	visual.material_override = material
	_set_state("vigia" if species >= 2 else "comendo")

func _physics_process(delta: float) -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	_goal_timer -= delta
	_action_timer -= delta
	_cooldown = maxf(0.0, _cooldown - delta)
	var map := agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		_apply_motion(Vector3.ZERO, delta)
		return
	_decide(delta)
	_update_attack(delta)
	var direction := Vector3.ZERO
	if not agent.is_navigation_finished():
		direction = agent.get_next_path_position() - global_position
		direction.y = 0.0
		if direction.length() > 0.12:
			direction = direction.normalized()
		else:
			direction = Vector3.ZERO
	var speed := run_speed if state in ["fugindo", "perseguindo"] else walk_speed
	if state in ["aviso", "atacando", "recuperando", "atenção", "observando", "vigia", "comendo"]:
		direction = Vector3.ZERO
	if _attack_timer >= 0.0:
		direction = Vector3.ZERO
	_apply_motion(direction * speed, delta)
	if direction.length_squared() > 0.1 and global_position.distance_to(_last_position) < 0.005:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time > 1.2:
		_goal_timer = 0.0
		_warning_time = 0.0
		_set_state("retornando")
		_set_goal(home)
		_stuck_time = 0.0
	_last_position = global_position
	label.text = "%s · %s" % [display_name, state]
	if player != null and state in ["atenção", "observando", "aviso", "cercando", "atacando"]:
		var gaze := player.global_position - global_position
		if Vector2(gaze.x, gaze.z).length() > 0.1:
			visual.rotation.y = atan2(gaze.x, gaze.z)

func _apply_motion(horizontal: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, horizontal.x, 10.0 * delta)
	velocity.z = move_toward(velocity.z, horizontal.z, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.1
	move_and_slide()

func can_see(actor: Node3D) -> bool:
	if not is_instance_valid(actor):
		return false
	var from := global_position + Vector3.UP * 0.55
	var to := actor.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func in_attack_range(actor: Node3D) -> bool:
	return is_instance_valid(actor) and global_position.distance_to(actor.global_position) <= attack_range and can_see(actor)

func _decide(delta: float) -> void:
	var valid_player := is_instance_valid(player)
	var visible := valid_player and can_see(player)
	var distance := global_position.distance_to(player.global_position) if valid_player else INF
	if visible and distance < attention_radius:
		_memory = 1.4
	else:
		_memory = maxf(0.0, _memory - delta)
	if species == 3:
		_decide_pukeko(delta)
		return
	if species == 2:
		_decide_kiwi(delta)
		return
	var tolerant: bool = species == 0 and reserve_state.deer_tolerant()
	var territorial: bool = species == 1 and reserve_state.day >= 2
	if territorial:
		var intruder := visible and player.global_position.distance_to(home) < territory_radius
		_defend(intruder, home, delta)
		return
	if tolerant:
		_fleeing = false
		if visible and distance < attention_radius:
			_set_state("observando")
			return
	elif visible and distance < fear_radius:
		_fleeing = true
	if _fleeing:
		if (distance > attention_radius or _memory <= 0.0):
			_fleeing = false
			_set_goal(home)
			_set_state("retornando")
		else:
			_set_state("fugindo")
			if _goal_timer <= 0.0:
				var away := global_position - player.global_position
				away.y = 0.0
				if away.length_squared() < 0.01:
					away = Vector3.FORWARD
				_set_goal(_choose_flee_goal(away.normalized()))
			return
	if visible and distance < attention_radius:
		_set_state("atenção")
	else:
		_routine()

func _choose_flee_goal(away: Vector3) -> Vector3:
	var best := global_position
	var best_score := -INF
	for angle in [0.0, -0.7, 0.7, -1.4, 1.4]:
		var candidate := global_position + away.rotated(Vector3.UP, angle) * 5.0
		var offset := candidate - home
		offset.y = 0.0
		if offset.length() > territory_radius + 3.0:
			candidate = home + offset.normalized() * (territory_radius + 3.0)
		candidate = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), candidate)
		var path := NavigationServer3D.map_get_path(agent.get_navigation_map(), global_position, candidate, true)
		if path.is_empty() or path[path.size() - 1].distance_to(candidate) > 1.0:
			continue
		var score := candidate.distance_to(player.global_position)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _decide_kiwi(delta: float) -> void:
	if group_controller == null:
		_routine()
		return
	var target := group_controller.target as Node3D
	if group_controller.has_eggs:
		var intruder := is_instance_valid(target) and target.global_position.distance_to(group_controller.global_position) < 5.0 and can_see(target)
		_defend(intruder, home, delta)
	elif is_instance_valid(target):
		cancel_attack()
		if not group_controller.fleeing:
			_set_state("atenção")
			return
		_set_state("fugindo")
		if _goal_timer <= 0.0:
			var offset := home - group_controller.global_position
			_set_goal(group_controller.flee_point + offset * 0.6)
	else:
		cancel_attack()
		_routine()

func _decide_pukeko(delta: float) -> void:
	if group_controller == null or not is_instance_valid(group_controller.target):
		cancel_attack()
		_warning_time = 0.0
		_return_or_idle("vigia")
		return
	var target := group_controller.target as Node3D
	if target.global_position.distance_to(group_controller.global_position) > group_controller.territory_radius:
		cancel_attack()
		_warning_time = 0.0
		_return_or_idle("vigia")
		return
	_warning_time += delta
	if group_controller.contact_count(target) >= 2 and _warning_time >= 0.85:
		_set_state("aviso")
		_try_attack()
	else:
		cancel_attack()
		_set_state("cercando")
		if _goal_timer <= 0.0:
			var index: int = group_controller.members.find(self)
			var angle := TAU * float(index) / maxf(1.0, group_controller.members.size())
			_set_goal(target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.05)

func _defend(intruder: bool, return_point: Vector3, delta: float) -> void:
	if not intruder:
		cancel_attack()
		_warning_time = 0.0
		if global_position.distance_to(return_point) > 0.8:
			_set_state("retornando")
			if _goal_timer <= 0.0:
				_set_goal(return_point)
		else:
			_set_state("vigia" if species == 2 else "comendo")
		return
	_warning_time += delta
	if _warning_time < 0.85:
		_set_state("aviso")
	elif in_attack_range(player):
		_set_state("aviso")
		_try_attack()
	else:
		cancel_attack()
		_set_state("perseguindo")
		if _goal_timer <= 0.0:
			_set_goal(player.global_position)

func _attack_allowed() -> bool:
	if not in_attack_range(player):
		return false
	if species == 0:
		return false
	if species == 1:
		return reserve_state.day >= 2 and player.global_position.distance_to(home) < territory_radius
	if species == 2:
		return group_controller != null and group_controller.has_eggs and player.global_position.distance_to(group_controller.global_position) < 5.0
	return group_controller != null and group_controller.contact_count(player) >= 2 and player.global_position.distance_to(group_controller.global_position) <= group_controller.territory_radius

func _try_attack() -> void:
	if _attack_timer < 0.0 and _cooldown <= 0.0 and _attack_allowed():
		_attack_timer = 0.45
		_set_state("atacando")

func _update_attack(delta: float) -> void:
	if _attack_timer < 0.0:
		return
	_set_state("atacando")
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		if _attack_allowed() and player.has_method("take_damage"):
			player.take_damage(damage)
		_attack_timer = -1.0
		_cooldown = 1.1
		_set_state("recuperando")

func cancel_attack() -> void:
	_attack_timer = -1.0

func _routine() -> void:
	if state == "retornando" and global_position.distance_to(home) > 1.0:
		if _goal_timer <= 0.0:
			_set_goal(home)
		return
	if _action_timer <= 0.0:
		_action_timer = _rng.randf_range(3.0, 5.0)
		if state == "andando":
			_set_state("comendo")
		else:
			_set_state("andando")
			_set_goal(home + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)))
	if state not in ["andando", "comendo"]:
		_set_state("comendo")

func _return_or_idle(idle_state: String) -> void:
	if global_position.distance_to(home) > 0.8:
		_set_state("retornando")
		if _goal_timer <= 0.0:
			_set_goal(home)
	else:
		_set_state(idle_state)

func _set_goal(point: Vector3) -> void:
	_goal = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), point)
	agent.target_position = _goal
	_goal_timer = 0.45

func _set_state(value: String) -> void:
	if state != value:
		state = value
		state_changed.emit(value)
