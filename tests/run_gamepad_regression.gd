extends Node
func _ready() -> void:
	for suite in ["gamepad","menu_save","dream_finale","sample_collectors"]:
		var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://tests/headless_gamepad_"+suite+".log"),"res://tests/"+suite+".tscn"])
		print("GAMEPAD_REGRESSION ",suite," PID ",OS.create_process(OS.get_executable_path(),args,false))
	get_tree().quit()
