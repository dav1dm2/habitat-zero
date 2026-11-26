extends Area3D

@export var damage_per_second: float = 2.24
@export var tick_seconds: float = 0.5

var _elapsed: float = 0.0


func _ready() -> void:
	collision_mask = 4


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < tick_seconds:
		return
	var elapsed_damage := damage_per_second * _elapsed
	_elapsed = 0.0
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.call("take_damage", elapsed_damage)
