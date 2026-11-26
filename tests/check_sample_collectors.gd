extends Node
var checks: Array = []
var tree: SceneTree
const FOREST := "res://scenes/levels/attis_forest.tscn"
const INTERIOR := "res://scenes/levels/attis_interior.tscn"

func run() -> Dictionary:
	tree = get_tree()
	var session := get_node("/root/DemoSession")
	var progress := get_node("/root/ReserveState")
	var ui := get_node("/root/DemoInterface")
	progress.reset()
	session.campaign_started = false
	session.room_items.clear()
	session.storage.clear()
	tree.change_scene_to_file(INTERIOR)
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	progress.power_restored = true
	progress.briefing_heard = true
	progress.changed.emit()
	var room := tree.current_scene
	var inv: Node = room.get_node("Player/Inventory")
	inv.import_inventory({})
	check("Duas unidades físicas no laboratório", items().size() == 2 and room.has_node("ColetorA") and room.has_node("ColetorB"))
	await aim(room.get_node("ColetorA"), Vector3(0, 0.2, 0))
	press("pickup_item")
	await tree.process_frame
	await aim(room.get_node("ColetorB"), Vector3(0, 0.2, 0))
	press("pickup_item")
	await tree.process_frame
	check("E recolhe dois coletores em slots separados", inv.slots[0] != null and inv.slots[1] != null and items().is_empty())
	if inv.slots[0] == null or inv.slots[1] == null:
		return finish()
	check("Estado independente", inv.slots[0] != inv.slots[1] and inv.slots[0].sample_ids.is_empty() and inv.slots[1].sample_ids.is_empty())
	await travel("DoorExit")
	room = tree.current_scene
	inv = room.get_node("Player/Inventory")
	check("Duas ferramentas atravessam a porta", inv.slots[0] != null and inv.slots[1] != null)
	var bushes: Array = [room.get_node("ArbustosDePesquisa/Arbusto01"),room.get_node("ArbustosDePesquisa/Arbusto02"),room.get_node("ArbustosDePesquisa/Arbusto03")]
	check("Todos os arbustos presentes permitem coleta", room.get_sample_bushes().size() == 40)
	inv.selected_slot = 0
	await aim(bushes[0], Vector3(0, 0.6, 0))
	press("use_item")
	check("M1 coleta sem consumir", inv.slots[0] != null and inv.slots[0].sample_ids.size() == 1 and inv.slots[1].sample_ids.is_empty())
	press("use_item")
	check("Repetir arbusto não aumenta contador", inv.slots[0].sample_ids.size() == 1)
	check("HUD mostra 1/3", inv.slot_views[0].caption.text.contains("1/3"))
	ui.show_notebook()
	check("Caderno acompanha 1/3", text_in(ui).contains("(1/3)"))
	ui.close_modal()
	check("Entrega incompleta recusada", inv.deliver_samples().contains("Traga") and inv.slots[0].sample_ids.size() == 1 and progress.analysed_samples.is_empty())
	# Guardar/recolher through the same storage buttons used by the player.
	ui.show_storage()
	for child in ui.content.get_children():
		if child is Button and child.text.begins_with("Guardar: Coletor"):
			child.pressed.emit()
			break
	check("Depósito preserva conteúdo", session.storage.size() == 1 and session.storage[0].sample_ids.size() == 1 and inv.slots[0] == null)
	for child in ui.content.get_children():
		if child is Button and child.text.begins_with("Recolher: Coletor"):
			child.pressed.emit()
			break
	ui.close_modal()
	check("Retirada preserva conteúdo", inv.slots[0] != null and inv.slots[0].sample_ids.size() == 1 and session.storage.is_empty())
	press("drop_item")
	await tree.process_frame
	var dropped: Node3D = items()[0]
	dropped.freeze = true
	dropped.global_position = bushes[0].global_position + Vector3(0, 1, 3)
	await aim(dropped, Vector3(0, 0.2, 0))
	press("pickup_item")
	await tree.process_frame
	check("Q/E preserva amostra sem duplicar", inv.slots[0] != null and inv.slots[0].sample_ids.size() == 1 and items().is_empty())
	for index in [1, 2]:
		await aim(bushes[index], Vector3(0, 0.6, 0))
		press("use_item")
	check("Três locais enchem apenas o primeiro coletor", inv.slots[0].sample_ids.size() == 3 and inv.slots[1].sample_ids.is_empty())
	press("use_item")
	check("Capacidade limitada a três", inv.slots[0].sample_ids.size() == 3 and inv.status_label.text.contains("cheio"))
	inv.selected_slot = 1
	await aim(bushes[0], Vector3(0, 0.6, 0))
	press("use_item")
	check("Segundo coletor não repete planta usada no mesmo dia", inv.slots[0].sample_ids.size() == 3 and inv.slots[1].sample_ids.is_empty())
	var other: Node = room.get_node("ArbustosDePesquisa/Arbusto04")
	await aim(other, Vector3(0, 0.6, 0))
	press("use_item")
	check("Outro arbusto fornece amostra ao segundo coletor", inv.slots[1].sample_ids.size() == 1)
	check("Não mistura origens", inv.slots[1].collect_sample("habitat1", 9).contains("outra área") and inv.slots[1].sample_ids.size() == 1)
	await travel("DoorToInterior")
	room = tree.current_scene
	inv = room.get_node("Player/Inventory")
	check("Retorno preserva 3/3 e 1/3, sem reposição de ferramentas", inv.slots[0].sample_ids.size() == 3 and inv.slots[1].sample_ids.size() == 1 and items().is_empty())
	await aim(room.get_node("Laboratorio"), Vector3(0, 0, 0))
	press("pickup_item")
	check("E na bancada conclui tarefa e esvazia coletor cheio", progress.analysed_samples == ["attis"] and inv.slots[0].sample_ids.is_empty() and inv.slots[0].sample_origin.is_empty())
	check("Entrega mantém as duas ferramentas e segundo conteúdo", inv.slots[0] != null and inv.slots[1].sample_ids.size() == 1)
	check("HUD volta a 0/3", inv.slot_views[0].caption.text.contains("0/3"))
	press("pickup_item")
	check("Não entrega parcial nem duplica conclusão", progress.analysed_samples.size() == 1 and inv.slots[1].sample_ids.size() == 1)
	ui.show_notebook()
	check("Caderno marca conclusão de Attis e tarefa do Habitat 1", text_in(ui).contains("✓ Coletar e entregar amostras de Attis (3/3)") and text_in(ui).contains("Coletar e entregar amostras do Habitat 1"))
	ui.close_modal()
	check("Sono aguarda Habitat 1", not session.can_sleep())
	# Checkpoint with different mutable tools in inventory, storage and world.
	session.storage.append(inv.slots[1])
	inv.set_slot_item(1, null)
	inv.selected_slot = 0
	press("drop_item")
	await tree.process_frame
	var checkpoint_item: Node = items()[0]
	checkpoint_item.freeze = true
	session.checkpoint_day(room)
	checkpoint_item.definition.collect_sample("attis", 4999)
	session.storage[0].empty_samples()
	session.restart_day()
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	inv = tree.current_scene.get_node("Player/Inventory")
	check("Morte restaura coletor largado e conteúdo do depósito", inv.slots[0] == null and items().size() == 1 and items()[0].definition.sample_ids.is_empty() and session.storage.size() == 1 and session.storage[0].sample_ids.size() == 1)
	check("Morte preserva conclusão no checkpoint", "attis" in progress.analysed_samples)
	# Mutate restored copy and verify checkpoint is reusable.
	items()[0].definition.collect_sample("attis", 4998)
	session.restart_day()
	await tree.scene_changed
	await tree.create_timer(0.7).timeout
	check("Segundo reinício não altera snapshot", items().size() == 1 and items()[0].definition.sample_ids.is_empty())
	return finish()

func aim(target: Node3D, offset: Vector3) -> void:
	var player: Node3D = tree.current_scene.get_node("Player")
	player.set_physics_process(false)
	player.global_position = target.global_position + Vector3(0, 0.6, 2.0)
	player.velocity = Vector3.ZERO
	var camera: Camera3D = player.get_node("Head/Camera3D")
	await tree.physics_frame
	await tree.physics_frame
	camera.look_at(target.global_position + offset, Vector3.UP)

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	tree.current_scene.get_node("Player/Inventory").handle_input(event)

func travel(door_name: String) -> void:
	get_node("/root/DemoInterface").close_modal()
	var room := tree.current_scene
	var player: Node3D = room.get_node("Player")
	var door: Node3D = room.get_node(door_name)
	player.set_physics_process(true)
	player.global_position = door.get_node("Arrival").global_position
	player.get_node("Head/Camera3D").rotation = Vector3.ZERO
	door.interact(player)
	await tree.scene_changed
	await tree.create_timer(0.7).timeout

func items() -> Array:
	return tree.get_nodes_in_group("world_items").filter(func(item):return tree.current_scene.is_ancestor_of(item) and not item.is_queued_for_deletion())

func text_in(ui: Node) -> String:
	var words := ""
	for child in ui.content.get_children():
		if child is Label:
			words += child.text + "\n"
	return words

func check(title: String, passed: bool) -> void:
	checks.append({"name": title, "passed": passed})
	print("SAMPLES ", "OK " if passed else "FAIL ", title)

func finish() -> Dictionary:
	var failed := checks.filter(func(c):return not c.passed)
	var result := {"checks": checks, "passed": checks.size() - failed.size(), "failed": failed.size()}
	var file := FileAccess.open("res://tests/sample_collectors_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	return result
