extends Node
func _ready() -> void:
	var runner := load("res://tests/check_sample_collectors.gd").new() as Node
	get_tree().root.add_child.call_deferred(runner)
	await get_tree().process_frame
	var result: Dictionary = await runner.run()
	get_tree().quit(0 if result.failed == 0 else 1)
