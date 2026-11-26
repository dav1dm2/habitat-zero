extends Node
func _ready() -> void:
	get_tree().create_timer(30).timeout.connect(func():get_tree().quit(2))
	var runner := load("res://tests/check_menu_save.gd").new() as Node
	get_tree().root.add_child.call_deferred(runner)
	runner.probe.call_deferred()
