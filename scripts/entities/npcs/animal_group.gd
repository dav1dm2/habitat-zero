extends Node3D
## Um grupo local; nunca comunica alerta a outros grupos da mesma espécie.
const MIN_PACK_MEMBERS := 3

@export var predator_pack: bool = false
@export var habitat_bounds := AABB(Vector3(-19, -10, -34), Vector3(33, 30, 52))
@export var circle_radius: float = 5.0
@export var provocation_radius: float = 2.6
@export var escape_margin: float = 0.8
@export var retreat_duration: float = 3.0
@export var regroup_delay: float = 5.0
@export var has_eggs: bool = false
var pack_state: String = "vigia"
var circle_center: Vector3
var circle_locked: bool = false
var orbit_angle: float = 0.0
var _pack_timer: float = 0.0
var _pack_cooldown: float = 0.0
@export var territory_radius: float = 8.0
var members: Array[Node3D] = []
var target: Node3D
var alert_remaining: float = 0.0
var flee_point: Vector3
var _was_alert: bool = false
var fleeing: bool = false

func _ready() -> void:
	flee_point = global_position

func register(member: Node3D) -> void:
	if member not in members:
		members.append(member)

func _physics_process(delta: float) -> void:
	members = members.filter(func(m: Node3D) -> bool: return is_instance_valid(m))
	if predator_pack:
		_update_pack(delta)
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var detected := false
	if player != null:
		for member in members:
			if member.can_see(player) and member.global_position.distance_to(player.global_position) < member.attention_radius:
				detected = true
				break
		if player.global_position.distance_to(global_position) > territory_radius + 4.0:
			detected = false
	if detected:
		target = player
		alert_remaining = 1.4
	else:
		alert_remaining = maxf(0.0, alert_remaining - delta)
		if alert_remaining <= 0.0:
			target = null
	var alert := is_instance_valid(target)
	if not alert or has_eggs:
		fleeing = false
	elif not fleeing:
		for member in members:
			if member.global_position.distance_to(target.global_position) < member.fear_radius:
				fleeing = true
				break
	if alert and not _was_alert:
		var away := global_position - target.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = Vector3.FORWARD
		flee_point = global_position + away.normalized() * (territory_radius - 1.0)
	_was_alert = alert

func contact_count(actor: Node3D) -> int:
	var count := 0
	for member in members:
		if is_instance_valid(member) and member.in_attack_range(actor):
			count += 1
	return count

func set_eggs(value: bool) -> void:
	has_eggs = value
	for member in members:
		member.cancel_attack()


func inside_habitat(actor: Node3D) -> bool:
	if not is_instance_valid(actor):
		return false
	var at := to_local(actor.global_position)
	at.y = 0.0
	return habitat_bounds.has_point(at)

func _update_pack(delta: float) -> void:
	_pack_cooldown = maxf(0.0, _pack_cooldown - delta)
	if pack_state == "fugindo":
		_pack_timer -= delta
		if _pack_timer <= 0.0:
			pack_state = "vigia"
			target = null
			circle_locked = false
			_pack_cooldown = regroup_delay
		return
	if members.size() < MIN_PACK_MEMBERS:
		if pack_state != "vigia":
			_begin_retreat()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not inside_habitat(player):
		if is_instance_valid(target):
			_begin_retreat()
		return
	if pack_state == "vigia":
		if _pack_cooldown > 0.0:
			return
		target = player
		circle_center = player.global_position
		circle_locked = false
		pack_state = "formando cerco"
		orbit_angle = 0.0
	if not is_instance_valid(target):
		return
	if circle_locked:
		var offset := target.global_position - circle_center
		offset.y = 0.0
		if offset.length() > circle_radius + escape_margin:
			_begin_retreat()
			return
	elif pack_state == "formando cerco":
		circle_center = target.global_position
		var arranged := true
		for member in members:
			var offset := member.global_position - ring_destination(member)
			offset.y = 0.0
			arranged = arranged and offset.length() < 1.5
		if arranged:
			circle_locked = true
			pack_state = "cercando"
	# Aproximação de um membro compromete o grupo inteiro com o ataque.
	if pack_state != "avançando":
		for member in members:
			if member.can_see(target) and member.global_position.distance_to(target.global_position) < provocation_radius:
				pack_state = "avançando"
				circle_locked = true
				break
	if pack_state == "cercando":
		orbit_angle += delta * 0.12

func _begin_retreat() -> void:
	pack_state = "fugindo"
	_pack_timer = retreat_duration
	circle_locked = false
	for member in members:
		member.cancel_attack()
		member._goal_timer = 0.0

func ring_destination(member: Node3D) -> Vector3:
	var index := members.find(member)
	var angle := orbit_angle + TAU * float(index) / maxf(1.0, members.size())
	return _inside_point(circle_center + Vector3(cos(angle), 0.0, sin(angle)) * circle_radius)

func ring_position(member: Node3D) -> Vector3:
	var offset := member.global_position - circle_center
	offset.y = 0.0
	var current_angle := atan2(offset.z, offset.x)
	var index := members.find(member)
	var desired_angle := orbit_angle + TAU * float(index) / maxf(1.0, members.size())
	var difference := wrapf(desired_angle - current_angle, -PI, PI)
	# Chegar pela borda e percorrer arcos; nunca cortar pelo centro do cerco.
	if offset.length() > circle_radius + 1.0 or offset.length() < circle_radius - 0.8:
		return _inside_point(circle_center + Vector3(cos(current_angle), 0.0, sin(current_angle)) * circle_radius)
	var next_angle := current_angle + clampf(difference, -0.6, 0.6)
	return _inside_point(circle_center + Vector3(cos(next_angle), 0.0, sin(next_angle)) * circle_radius)

func assault_position(member: Node3D) -> Vector3:
	if not is_instance_valid(target):
		return member.home
	var index := members.find(member)
	var angle := TAU * float(index) / maxf(1.0, members.size())
	return _inside_point(target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.8)

func retreat_position(member: Node3D) -> Vector3:
	var away := member.global_position - (target.global_position if is_instance_valid(target) else circle_center)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	return _inside_point(member.global_position + away.normalized() * 5.0)

func _inside_point(point: Vector3) -> Vector3:
	var local := to_local(point)
	local.x = clampf(local.x, habitat_bounds.position.x + 0.8, habitat_bounds.end.x - 0.8)
	local.z = clampf(local.z, habitat_bounds.position.z + 0.8, habitat_bounds.end.z - 0.8)
	return to_global(local)
