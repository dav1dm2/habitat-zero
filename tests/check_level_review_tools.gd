extends Node
var checks: Array = []
var tree: SceneTree
func run() -> void:
	tree = get_tree()
	var progress := get_node("/root/ReserveState")
	var session := get_node("/root/DemoSession")
	var dev := get_node("/root/DevelopmentTools")
	var flow := get_node("/root/DreamFlow")
	progress.reset()
	session.campaign_started = false
	session.room_items.clear()
	session.storage.clear()
	tree.change_scene_to_file(session.FOREST)
	await tree.scene_changed
	await tree.create_timer(.7).timeout
	var room: Node3D = tree.current_scene
	check("Atalhos disponíveis no executável do editor",dev.enabled)
	check("Jogo inicia normal sem prévia do editor vazar",progress.day == 1 and not room.get_node("DreamEvent").visible and room.get_node("Fauna").visible)
	var inv: Node = room.get_node("Player/Inventory")
	inv.set_slot_item(2,load("res://resources/items/sample_collector.tres").duplicate(true))
	var event := InputEventKey.new()
	event.keycode = KEY_F9
	event.pressed = true
	dev._input(event)
	dev._input(event)
	check("Duplo F9 é protegido durante transição",dev.busy)
	await dev.day_skipped
	await tree.process_frame
	room = tree.current_scene
	check("F9 avança Dia 1 para Dia 2 sem tarefas manuais",progress.day == 2 and room.scene_file_path == session.INTERIOR and not session.sleeping and not dev.busy)
	check("Atalho preserva inventário e renova metas",room.get_node("Player/Inventory").slots[2].item_id == &"sample_collector" and progress.analysed_samples.is_empty() and progress.analysis_history["1"].size() == 2)
	check("Dia 2 mantém robô inicialmente desligado",not progress.robot_activated)
	dev._input(event)
	await dev.day_skipped
	await tree.process_frame
	room = tree.current_scene
	check("Segundo F9 entra no sonho com bilhete e tarefa",progress.day == 3 and progress.is_dream and room.get_node("Player/Inventory").slots.any(func(r):return r != null and r.item_id == &"dream_letter"))
	dev._input(event)
	check("F9 não cria um Dia 4",progress.day == 3 and not dev.busy)
	get_node("/root/DemoInterface").close_modal()
	var player: CharacterBody3D = room.get_node("Player")
	var door: Node3D = room.get_node("DoorExit")
	player.global_position = door.get_node("Arrival").global_position
	door.interact(player)
	await tree.scene_changed
	await tree.create_timer(.7).timeout
	room = tree.current_scene
	player = room.get_node("Player")
	event.keycode = KEY_F10
	dev._input(event)
	check("F10 ativa inspeção livre no sonho",flow.development_inspection and not flow.input_locked)
	player.global_position = room.get_node("DreamEvent/TriggerApproach").global_position+Vector3.UP*.95
	await tree.create_timer(.3).timeout
	check("Inspeção suspende o gatilho sem travar jogador",flow.phase == "exploring" and not player.controls_locked and not flow.input_locked)
	dev._input(event)
	await tree.physics_frame
	await tree.physics_frame
	check("F10 reativa o ritual ao aproximar",not flow.development_inspection and flow.input_locked)
	var day: int = progress.day
	event.keycode = KEY_F9
	dev._input(event)
	check("Avançar dia não interrompe cutscene",progress.day == day and flow.input_locked and not dev.busy)
	session.restart_day()
	await tree.scene_changed
	await tree.create_timer(.6).timeout
	check("Reinício limpa modo de inspeção",not flow.development_inspection and not flow.input_locked)
	# Exercise editor preview logic directly and save it as if Ctrl+S was pressed.
	var source: Node3D = load(session.FOREST).instantiate()
	source.set_meta("simulation_background",true)
	source.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(source)
	var original_fog: bool = source.get_node("Ambiente_Nevoeiro").environment.fog_enabled
	var original_energy: float = source.get_node("LuzNublada").light_energy
	source.editor_day_preview = 2
	source.apply_editor_preview()
	check("Prévia clara mostra corpos e cervos sem fauna normal",source.get_node("DreamEvent").visible and not source.get_node("Fauna").visible)
	check("Prévia clara permite ver arredores sem neblina",not source.get_node("Ambiente_Nevoeiro").environment.fog_enabled and source.get_node("LuzNublada").light_energy >= 1)
	var actors: Array = source.get_node("DreamEvent/DeadSkunks").get_children()+source.get_node("DreamEvent/DeerCircle").get_children()
	check("Dezesseis sprites existem no cenário editável",actors.size() == 16 and actors.all(func(a):return a.has_node("EventSprite") and a.get_node("EventSprite").visible and not a.get_node("Visual").visible))
	var area: Area3D = source.get_node("DreamEvent/RitualCenter/RitualTrigger")
	check("Gatilho tem volume editável sem colisão de gameplay",area.get_node("CollisionShape3D").shape.radius == 10 and not area.monitoring and area.collision_layer == 0)
	var packed := PackedScene.new()
	packed.pack(source)
	ResourceSaver.save(packed,"res://tests/_saved_level_preview.tscn")
	var clone: Node3D = load("res://tests/_saved_level_preview.tscn").instantiate()
	clone.set_meta("simulation_background",true)
	clone.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(clone)
	check("Salvar prévia clara não altera ambiente de execução",clone.get_node("Ambiente_Nevoeiro").environment.fog_enabled == original_fog and is_equal_approx(clone.get_node("LuzNublada").light_energy,original_energy))
	check("Salvar prévia não ativa final em dia normal",not clone.get_node("DreamEvent").visible and clone.get_node("Fauna").visible)
	source.editor_day_preview = 3
	source.apply_editor_preview()
	check("Prévia noturna aplica iluminação do sonho",source.get_node("LuzNublada").light_energy == 0 and source.get_node("Ambiente_Nevoeiro").environment.fog_enabled)
	source.editor_day_preview = 0
	source.apply_editor_preview()
	check("Restaurar prévia devolve ambiente e fauna normal",not source.get_node("DreamEvent").visible and source.get_node("Fauna").visible and is_equal_approx(source.get_node("LuzNublada").light_energy,original_energy))
	clone.free()
	source.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/_saved_level_preview.tscn"))
	var previous_enabled: bool = dev.enabled
	dev.enabled = false
	dev.advance_development_day()
	check("Atalhos desabilitados não alteram estado",not dev.busy and progress.day == day)
	dev.enabled = previous_enabled
	var failed := checks.filter(func(c):return not c.passed)
	var f := FileAccess.open("res://tests/level_review_tools_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size()},"  "))
	print("LEVEL_REVIEW_TOOLS ",checks.size()-failed.size(),"/",checks.size()," ",failed)
	tree.quit(0 if failed.is_empty() else 1)
func check(title: String,value: bool) -> void:
	checks.append({"name":title,"passed":value})
	print("REVIEW ","OK " if value else "FAIL ",title)
