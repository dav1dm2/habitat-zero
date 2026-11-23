extends Node3D

@export_enum("deer", "skunk") var animal_kind: String = "deer"
@export var flee_speed: float = 1.7
@export var flee_distance: float = 4.5
@export var territorial_radius: float = 3.0
@export var attack_radius: float = 1.25
@export var damage_per_second: float = 12.0

var _attack_cooldown: float = 0.0
var _home_position: Vector3


func _ready() -> void:
	_home_position = global_position


func _process(delta: float) -> void:
	var root := get_tree().current_scene
	var player := root.get_node_or_null("Player") as Node3D if root != null else null
	if player == null:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var offset := global_position - player.global_position
	offset.y = 0.0
	var distance := offset.length()
	var day_two := int(root.get("current_day")) == 2
	var fertilized := get_tree().get_nodes_in_group("fertilized_bushes").size() >= 5
	var from_home := player.global_position - _home_position
	from_home.y = 0.0
	if animal_kind == "skunk" and day_two and from_home.length() <= territorial_radius:
		if distance > attack_radius:
			global_position -= offset.normalized() * flee_speed * delta
		elif _attack_cooldown <= 0.0 and player.has_method("take_damage"):
			player.call("take_damage", damage_per_second)
			_attack_cooldown = 1.0
	elif distance < flee_distance and not (animal_kind == "deer" and fertilized):
		global_position += offset.normalized() * flee_speed * delta
