extends Node3D
## Um grupo local; nunca comunica alerta a outros grupos da mesma espécie.
@export var has_eggs: bool = false
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
