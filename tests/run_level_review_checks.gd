extends Node
func _ready() -> void:
	var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://tests/headless_level_review.log"),"res://tests/level_review_tools.tscn"])
	var pid := OS.create_process(OS.get_executable_path(),args,false)
	print("LEVEL_REVIEW_PID ",pid)
	get_tree().quit(0 if pid > 0 else 1)
