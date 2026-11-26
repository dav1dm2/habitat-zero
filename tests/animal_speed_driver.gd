extends "res://scripts/entities/npcs/animal_controller.gd"
var measured_state := "fugindo"
func _decide(_delta: float) -> void:
	_set_state(measured_state)
	if _goal_timer <= 0.0:
		_set_goal(Vector3(20,0,0))
