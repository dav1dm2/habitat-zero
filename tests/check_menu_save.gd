extends Node
var tree: SceneTree
var checks: Array = []
var save: Node
var session: Node
var progress: Node
var test_path: String
func check(label: String, ok: bool) -> void:
	checks.append({"name":label,"passed":ok})
	print("MENU ","OK " if ok else "FAIL ",label)
func wait_scene() -> void:
	await tree.scene_changed
	await tree.create_timer(.5).timeout
func run() -> void:
	tree = get_tree()
	save = get_node("/root/SaveSystem")
	session = get_node("/root/DemoSession")
	progress = get_node("/root/ReserveState")
	test_path = "user://test_menu_checkpoint_%d.tres" % OS.get_process_id()
	save.save_path = test_path
	tree.change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await wait_scene()
	var menu := tree.current_scene
	check("Menu abre sem save e desabilita Continuar",menu.get_node("%Continue").disabled and not save.has_checkpoint())
	check("Menu não inicia campanha nem cria simulação",not session.campaign_started and get_node("/root/ReserveSimulation").rooms.is_empty() and tree.get_nodes_in_group("animals").is_empty())
	check("Menu tem cenário real e câmera ativa",menu.has_node("ForestBackdrop/BaseNoTopo") and tree.root.get_camera_3d() == menu.get_node("MenuCamera"))
	check("Interface ocupa viewport e mostra ações",menu.ui.size.x > 0 and menu.get_node("%NewGame").text == "Novo jogo")
	var old_position: Vector3 = menu.camera.position
	await tree.create_timer(.2).timeout
	check("Câmera do fundo se movimenta",menu.camera.position.distance_to(old_position) > .001)
	menu.get_node("%NewGame").pressed.emit()
	await wait_scene()
	await tree.create_timer(.7).timeout
	check("Novo jogo inicia Dia 1 com carta e fusível",progress.day == 1 and tree.current_scene.scene_file_path == session.FOREST and tree.current_scene.get_node("Player/Inventory").slots[1].item_id == &"fuse")
	check("Dia 1 é salvo automaticamente em disco",save.has_checkpoint() and save.read_checkpoint().checkpoint.progress.day == 1)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_node("/root/GameMenus")._input(event)
	check("Esc pausa o mundo e mostra menu",tree.paused and get_node("/root/GameMenus").panel.visible)
	get_node("/root/GameMenus").resume()
	check("Retomar devolve controle e relógio",not tree.paused and not get_node("/root/GameMenus").panel.visible)
	progress.fertilize(1000)
	tree.current_scene.get_node("Player/Inventory").set_slot_item(1,null)
	await session.return_to_menu()
	menu = tree.current_scene
	check("Menu de retorno habilita Continuar",not menu.get_node("%Continue").disabled and get_node("/root/ReserveSimulation").rooms.is_empty())
	menu.get_node("%NewGame").pressed.emit()
	check("Novo jogo com save pede confirmação",menu.get_node("%Overwrite").visible and tree.current_scene == menu)
	menu.get_node("%Overwrite").hide()
	check("Cancelar preserva checkpoint",save.read_checkpoint().checkpoint.progress.day == 1)
	check("Continuar carrega checkpoint",await session.continue_game())
	check("Continuar descarta progresso parcial do dia",progress.fertilized_ids.is_empty() and tree.current_scene.get_node("Player/Inventory").slots[1].item_id == &"fuse")
	# Seed only daily objectives; use the real sleep transition and checkpoint capture.
	get_node("/root/DevelopmentTools").advance_development_day()
	await session.woke_up
	await tree.process_frame
	check("Despertar salva o Dia 2 e seu histórico",save.read_checkpoint().checkpoint.progress.day == 2 and progress.analysis_history.has("1"))
	get_node("/root/DemoInterface").close_modal()
	var inv: Node = tree.current_scene.get_node("Player/Inventory")
	inv.import_inventory({"slots":[load("res://resources/items/sample_collector.tres").duplicate(true),load("res://resources/items/fuse.tres"),null,null]})
	inv.slots[0].collect_sample("attis",3000,2)
	session.storage.append(load("res://resources/items/sample_collector.tres").duplicate(true))
	session.storage[0].collect_sample("habitat1",2000,2)
	# Explicit test checkpoint: exercises physical dropped items plus resources, not a new gameplay autosave.
	var world: RigidBody3D = load("res://scenes/entities/items/world_item.tscn").instantiate()
	world.definition = load("res://resources/items/sample_collector.tres").duplicate(true)
	world.definition.collect_sample("attis",3001,2)
	tree.current_scene.add_child(world)
	world.global_position = Vector3(0,1,0)
	session.checkpoint_day(tree.current_scene)
	var loaded: Resource = save.read_checkpoint()
	check("Save serializa coletores independentes e depósito",loaded.checkpoint.inventory.slots[0].sample_ids == [3000] and loaded.checkpoint.storage[0].sample_ids == [2000] and loaded.checkpoint.inventory.slots[0] != inv.slots[0])
	check("Save contém itens físicos e transformações",loaded.checkpoint.items[session.INTERIOR].any(func(i):return i.definition.sample_ids == [3001] and i.transform is Transform3D))
	check("Save preserva restrição diária por arbusto",loaded.checkpoint.progress.sampled_bush_days.get("attis:3000") == 2)
	var probe_result := test_path+".probe.json"
	var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://tests/headless_menu_probe.log"),"res://tests/probe_saved_day.tscn","--",test_path,probe_result])
	var pid := OS.create_process(OS.get_executable_path(),args,false)
	var waited := 0.0
	while pid > 0 and OS.is_process_running(pid) and waited < 25:
		await tree.create_timer(.1).timeout
		waited += .1
	var probe_data = JSON.parse_string(FileAccess.get_file_as_string(probe_result)) if FileAccess.file_exists(probe_result) else {}
	check("Outro processo Godot retoma o checkpoint em disco",probe_data is Dictionary and probe_data.get("passed",false))
	if FileAccess.file_exists(probe_result): DirAccess.remove_absolute(probe_result)

	await session.return_to_menu()
	progress.reset()
	session.room_items.clear()
	session.storage.clear()
	check("Continuar restaura Dia 2 a partir do arquivo",await session.continue_game())
	inv = tree.current_scene.get_node("Player/Inventory")
	check("Recarga restaura conteúdos e posição do checkpoint",inv.slots[0].sample_ids == [3000] and session.storage[0].sample_ids == [2000] and tree.current_scene.get_node("Player").global_transform.is_equal_approx(session._checkpoint_transform))
	get_node("/root/DemoInterface").close_modal()
	get_node("/root/DevelopmentTools").advance_development_day()
	await session.woke_up
	await tree.process_frame
	check("Sonho tem checkpoint persistente com carta e blecaute",save.read_checkpoint().checkpoint.progress.day == 3 and progress.is_dream and not progress.power_restored and save.read_checkpoint().checkpoint.inventory.slots.any(func(i):return i != null and i.item_id == &"dream_letter"))
	await session.return_to_menu()
	check("Continuar também retoma o sonho",await session.continue_game())
	check("Sonho restaurado ativa a apresentação de blecaute",progress.is_dream and get_node("/root/DreamFlow").phase == "awakened" and tree.current_scene.get_node("MachineEmergency").light_energy == 0)
	# Recovery of a known-good prior checkpoint without clobbering it with a corrupt primary.
	var file := FileAccess.open(test_path,FileAccess.WRITE)
	file.store_string("[gd_resource type=\"Resource\" format=3]\n[resource]\n")
	file.close()
	check("Save inválido recupera cópia anterior",save.has_checkpoint() and save.recovered_backup and save.read_checkpoint().checkpoint.progress.day == 2)
	var invalid: Dictionary = session.export_checkpoint()
	invalid.scene = "res://missing.tscn"
	check("Gravação inválida não substitui backup",not save.write_checkpoint(invalid) and save.has_checkpoint())
	# Test actual NPC attack damage through the controller helper, and radiation tuning.
	var skunk: Node = load("res://scenes/entities/npcs/skunk.tscn").instantiate()
	check("Dano ajustado dos animais",is_equal_approx(skunk.damage,13.2))
	skunk.free()
	check("Dano ajustado da radiação de campanha",is_equal_approx(tree.current_scene.get_node("RadiationZone").damage_per_second,1.78))
	for path in [test_path,test_path+".bak.tres",test_path+".pending.tres"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	save.save_path = save.DEFAULT_PATH
	session.persistent_session = false
	var failed := checks.filter(func(c):return not c.passed)
	FileAccess.open("res://tests/menu_save_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size()},"  "))
	print("MENU_RESULT ",checks.size()-failed.size(),"/",checks.size()," ",failed)
	get_node("/root/Soundtrack").quit_game(0 if failed.is_empty() else 1)

func probe() -> void:
	var args := OS.get_cmdline_user_args()
	var system := get_node("/root/SaveSystem")
	system.save_path = args[0]
	var restored: bool = await get_node("/root/DemoSession").continue_game()
	var inventory: Node = get_tree().current_scene.get_node("Player/Inventory")
	var ok: bool = restored and get_node("/root/ReserveState").day == 2 and inventory.slots[0].sample_ids == [3000] and get_node("/root/DemoSession").storage[0].sample_ids == [2000]
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify({"passed":ok}))
	get_node("/root/Soundtrack").quit_game(0 if ok else 1)
