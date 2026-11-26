extends Node
func _ready() -> void:
	var runner := load("res://tests/check_interior_relayout.gd").new() as Node
	get_tree().root.add_child.call_deferred(runner)
	runner.run.call_deferred()
