extends Node
func _ready() -> void:
	for suite in ["menu_save","dream_finale","arrival_integration","habitat_1_integration"]:
		var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://tests/headless_menu_"+suite+".log"),"res://tests/"+suite+".tscn"])
		print("MENU_REGRESSION ",suite," PID ",OS.create_process(OS.get_executable_path(),args,false))
	get_tree().quit()
