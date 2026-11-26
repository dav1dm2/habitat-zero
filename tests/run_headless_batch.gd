extends Node
## Tests run in independent headless Godot processes, avoiding window occlusion throttling.
const SUITES := ["arrival_integration", "habitat_1_integration", "day2_automation", "dream_finale"]
var entries: Array = []
var started: float
func _ready() -> void:
	started = Time.get_unix_time_from_system()
	for suite in SUITES:
		var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://tests/headless_"+suite+".log"),"res://tests/"+suite+".tscn"])
		var pid := OS.create_process(OS.get_executable_path(),args,false)
		entries.append({"suite":suite,"pid":pid})
	var file := FileAccess.open("res://tests/headless_batch_status.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"started":started,"entries":entries,"complete":false},"  "))
	file.close()
	set_process(true)
func _process(_delta: float) -> void:
	if entries.any(func(e):return e.pid > 0 and OS.is_process_running(e.pid)):
		return
	var file := FileAccess.open("res://tests/headless_batch_status.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"started":started,"entries":entries,"complete":true},"  "))
	print("HEADLESS_BATCH_DONE ",entries)
	get_tree().quit()
