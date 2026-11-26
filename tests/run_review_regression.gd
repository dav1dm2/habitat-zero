extends Node
func _ready() -> void:
	for suite in ["level_review_tools","dream_finale"]:
		var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://tests/headless_"+suite+".log"),"res://tests/"+suite+".tscn"])
		print("REVIEW_REGRESSION ",suite," PID ",OS.create_process(OS.get_executable_path(),args,false))
	get_tree().quit()
