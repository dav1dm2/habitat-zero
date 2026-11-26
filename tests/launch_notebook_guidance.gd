extends Node
func _ready() -> void:
	var runner := load("res://tests/check_notebook_guidance.gd").new() as Node
	get_tree().root.add_child.call_deferred(runner)
	runner.run.call_deferred()
