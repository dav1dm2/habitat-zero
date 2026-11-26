extends Node
func run() -> void:
	var tree := get_tree()
	var progress := get_node("/root/ReserveState")
	progress.reset()
	tree.change_scene_to_file("res://scenes/levels/attis_interior.tscn")
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	progress.power_restored = true
	progress.briefing_heard = true
	for id in range(1000,1005):
		progress.fertilize(id)
	var ui := get_node("/root/DemoInterface")
	ui.show_notebook()
	var words: String = text_in(ui)
	var checks := {
		"active_attis_collection_task": words.contains("□ Coletar e entregar amostras de Attis (0/3)"),
		"collector_instructions": words.contains("dois coletores") and words.contains("três arbustos distintos") and words.contains("pressione E na bancada"),
		"habitat_task_explained": words.contains("Coletar e entregar amostras do Habitat 1") and words.contains("porta H1"),
		"sleep_criteria_preserved": not get_node("/root/DemoSession").can_sleep()
	}
	ui.close_modal()
	tree.current_scene.get_node("Cama").interact(tree.current_scene.get_node("Player"))
	checks["bed_explains_block"] = ui.notice.text.contains("duas áreas")
	tree.current_scene.get_node("Laboratorio").interact(tree.current_scene.get_node("Player"))
	checks["bench_explains_no_delivery"] = ui.notice.text.contains("Traga um coletor cheio")
	progress.briefing_heard = false
	ui.show_buzzy()
	checks["buzzy_limits_current_tasks"] = text_in(ui).contains("dois coletores de amostras reutilizáveis")
	ui.close_modal()
	var passed := 0
	for value in checks.values():
		if value:
			passed += 1
	var file := FileAccess.open("res://tests/notebook_guidance_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":passed,"total":checks.size()},"  "))
	print("NOTEBOOK_GUIDANCE: ",passed,"/",checks.size()," ",checks)
	tree.quit(0 if passed == checks.size() else 1)

func text_in(ui: Node) -> String:
	var words := ""
	for child in ui.content.get_children():
		if child is Label:
			words += child.text + "\n"
	return words
