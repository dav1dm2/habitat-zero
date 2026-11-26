extends Node
func _ready() -> void:
	for suite in ["sampling_freedom","sample_collectors","dream_finale","day2_automation","habitat_1_integration"]:
		var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://tests/headless_sampling_camera_"+suite+".log"),"res://tests/"+suite+".tscn"])
		print("SAMPLING_CAMERA ",suite," PID ",OS.create_process(OS.get_executable_path(),args,false))
	get_tree().quit()
