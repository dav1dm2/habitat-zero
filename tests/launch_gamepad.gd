extends Node
func _ready() -> void:
	get_tree().create_timer(90,true).timeout.connect(func():get_tree().quit(2))
	var runner := load("res://tests/check_gamepad.gd").new() as Node
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)
	runner.run.call_deferred()
