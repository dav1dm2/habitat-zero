extends Node
## Estado de sessão e checkpoint diário. Itens físicos persistem entre visitas.
const FOREST := "res://scenes/levels/attis_forest.tscn"
const HABITAT := "res://scenes/levels/habitat_1.tscn"
const INTERIOR := "res://scenes/levels/attis_interior.tscn"
const MENU := "res://scenes/ui/main_menu.tscn"
signal woke_up(day: int)
signal day_restarting
var persistent_session := false
var sleeping := false
var _sleep_generation := 0
var campaign_started := false
var room_items: Dictionary = {}
var storage: Array[Resource] = []
var _checkpoint_items: Dictionary = {}
var _checkpoint_inventory: Dictionary = {}
var _checkpoint_storage: Array[Resource] = []
var _checkpoint_scene: String = FOREST
var _restore_inventory: Dictionary = {}
var _restarting := false
var _checkpoint_transform := Transform3D.IDENTITY
var _restore_transform := false

func _ready() -> void:
	get_tree().scene_changed.connect(_scene_changed)

func is_campaign(room: Node) -> bool:
	return room != null and room.scene_file_path in [FOREST, INTERIOR, HABITAT]

func _scene_changed() -> void:
	var room := get_tree().current_scene
	if is_campaign(room):
		prepare_room.call_deferred(room)
	elif room is Node3D:
		restore_items.call_deferred(room)

func prepare_room(room: Node3D) -> void:
	if not is_instance_valid(room) or not room.is_inside_tree() or room != get_tree().current_scene or room.get_meta("simulation_background", false) or room.get_meta("session_prepared", false):
		return
	room.set_meta("session_prepared", true)
	var player := room.get_node_or_null("Player")
	if player == null:
		return
	var inventory: Node = player.get_node("Inventory")
	var first_day_start := not campaign_started
	if not campaign_started:
		campaign_started = true
		inventory.import_inventory({"slots": [load("res://resources/items/arrival_letter.tres"), load("res://resources/items/fuse.tres"), null, null], "selected": 0})
		_checkpoint_inventory = copy_state(inventory.export_inventory())
		_checkpoint_scene = room.scene_file_path
		_checkpoint_transform = player.global_transform
		get_node("/root/ReserveState").checkpoint_day()
	elif not _restore_inventory.is_empty():
		inventory.import_inventory(_restore_inventory)
		_restore_inventory = {}
	if _restore_transform:
		player.global_transform = _checkpoint_transform
		player.velocity = Vector3.ZERO
		_restore_transform = false
	restore_items(room)
	if first_day_start:
		checkpoint_day(room)
	_restarting = false
	var progress := get_node("/root/ReserveState")
	if progress.day == 2 and not progress.day2_briefing_heard:
		get_node("/root/DemoInterface").show_buzzy.call_deferred()

func capture_items(room: Node) -> void:
	if room == null or room.scene_file_path.is_empty():
		return
	var entries: Array = []
	for item in get_tree().get_nodes_in_group("world_items"):
		if room.is_ancestor_of(item) and not item.is_queued_for_deletion() and item.definition != null:
			entries.append({"definition": item.definition, "transform": item.global_transform,
				"velocity": item.linear_velocity, "angular": item.angular_velocity, "sleeping": item.sleeping})
	room_items[room.scene_file_path] = entries

func restore_items(room: Node) -> void:
	if not room_items.has(room.scene_file_path):
		return
	for item in get_tree().get_nodes_in_group("world_items"):
		if room.is_ancestor_of(item):
			item.get_parent().remove_child(item)
			item.queue_free()
	for entry in room_items[room.scene_file_path]:
		var item: RigidBody3D = load("res://scenes/entities/items/world_item.tscn").instantiate()
		item.definition = entry.definition
		room.add_child(item)
		item.global_transform = entry.transform
		item.linear_velocity = entry.velocity
		item.angular_velocity = entry.angular
		item.sleeping = entry.sleeping

func checkpoint_day(room: Node) -> void:
	capture_items(room)
	_checkpoint_items = copy_state(room_items)
	_checkpoint_inventory = copy_state(room.get_node("Player/Inventory").export_inventory())
	_checkpoint_storage.assign(copy_state(storage))
	_checkpoint_scene = room.scene_file_path
	_checkpoint_transform = room.get_node("Player").global_transform
	get_node("/root/ReserveState").checkpoint_day()
	if persistent_session:
		if not get_node("/root/SaveSystem").write_checkpoint(export_checkpoint()):
			get_node("/root/DemoInterface").show_status(get_node("/root/SaveSystem").last_error)

func export_checkpoint() -> Dictionary:
	return {"progress":get_node("/root/ReserveState")._checkpoint.duplicate(true),"items":copy_state(_checkpoint_items),"inventory":copy_state(_checkpoint_inventory),"storage":copy_state(_checkpoint_storage),"scene":_checkpoint_scene,"transform":_checkpoint_transform}

func restart_day() -> void:
	if _restarting:
		return
	_restarting = true
	day_restarting.emit()
	sleeping = false
	_sleep_generation += 1
	get_node("/root/DreamFlow").reset_sequence()
	get_node("/root/DemoInterface").close_modal()
	room_items = copy_state(_checkpoint_items)
	storage.assign(copy_state(_checkpoint_storage))
	_restore_inventory = copy_state(_checkpoint_inventory)
	_restore_transform = true
	get_node("/root/ReserveState").restart_day()
	get_node("/root/ReserveSimulation").reset_robot()
	var manager := get_node_or_null("/root/SceneTransitionManager")
	if manager != null:
		manager.cancel_pending()
	get_tree().call_deferred("change_scene_to_file", _checkpoint_scene)

func can_sleep() -> bool:
	if get_node("/root/ReserveState").is_dream or sleeping:
		return false
	var progress := get_node("/root/ReserveState")
	var treated := 0
	for id in progress.fertilized_ids:
		if id >= 1000 and id < (1010 if progress.day >= 2 else 1005):
			treated += 1
	return progress.power_restored and progress.briefing_heard and treated >= (10 if progress.day >= 2 else 5) and "attis" in progress.analysed_samples and "habitat1" in progress.analysed_samples and (progress.day == 1 or (progress.robot_activated and progress.day2_briefing_heard))

func advance_day(room: Node) -> bool:
	if not can_sleep() or room.scene_file_path != INTERIOR:
		return false
	sleeping = true
	_sleep_generation += 1
	room.get_node("Player").controls_locked = true
	_sleep_to_next_day.call_deferred(room,_sleep_generation)
	return true

func _sleep_to_next_day(room: Node3D, token: int) -> void:
	var ui := get_node("/root/DemoInterface")
	ui.close_modal()
	var fade := get_node("/root/SceneTransitionManager")
	await fade.fade_to_black(0.5)
	if token != _sleep_generation or not is_instance_valid(room):
		return
	var progress := get_node("/root/ReserveState")
	if progress.day == 1:
		progress.begin_day(2)
	else:
		progress.begin_dream()
	var player := room.get_node("Player") as CharacterBody3D
	player.global_position = room.get_node("DayStart").global_position
	player.rotation.y = PI*0.5
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.health = player.max_health
	player.stamina = player.stamina_capacity
	player.health_bar.value = player.health
	player.stamina_bar.value = player.stamina
	player.flashlight.visible = false
	player.flashlight_status_label.text = "Lanterna desligada"
	if progress.is_dream:
		var inventory: Node = player.get_node("Inventory")
		var slot: int = inventory._find_empty_slot()
		if slot < 0:
			slot = 0
			storage.append(inventory.slots[0])
		inventory.set_slot_item(slot,load("res://resources/items/dream_letter.tres"))
		inventory.selected_slot = slot
		inventory._refresh_hud()
		get_node("/root/DreamFlow").configure_room(room)
	checkpoint_day(room)
	await get_tree().create_timer(0.3).timeout
	await fade.fade_from_black(0.55)
	if token != _sleep_generation or not is_instance_valid(player):
		return
	sleeping = false
	player.controls_locked = false
	woke_up.emit(progress.day)
	if progress.day == 2:
		ui.show_buzzy()
	else:
		ui.show_status("Um bilhete manchado está no inventário. M1 para ler. Tab abre o caderno.")

func start_new_game(enable_persistence: bool = false) -> void:
	if sleeping:
		return
	persistent_session = enable_persistence
	sleeping = true
	_sleep_generation += 1
	var fade := get_node("/root/SceneTransitionManager")
	await fade.fade_to_black(0.2)
	get_node("/root/DemoInterface").close_modal()
	get_node("/root/DreamFlow").reset_sequence()
	get_node("/root/ReserveState").reset()
	campaign_started = false
	room_items.clear()
	storage.clear()
	_restore_inventory.clear()
	_checkpoint_items.clear()
	_checkpoint_inventory.clear()
	_checkpoint_storage.clear()
	_restore_transform = false
	get_node("/root/ReserveSimulation").reset_robot()
	get_tree().change_scene_to_file(FOREST)
	await get_tree().scene_changed
	await get_tree().process_frame
	get_tree().current_scene.get_node("Player").controls_locked = true
	await fade.fade_from_black(0.4)
	sleeping = false
	get_tree().current_scene.get_node("Player").controls_locked = false

func recover_item(item: RigidBody3D) -> void:
	var room := get_tree().current_scene
	if room == null or not room.is_ancestor_of(item):
		return
	var marker := room.get_node_or_null("ItemRecovery") as Node3D
	var player := room.get_node_or_null("Player") as Node3D
	item.global_position = marker.global_position if marker != null else (player.global_position + Vector3.UP if player != null else Vector3(0, 2, 0))
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO

func copy_state(value: Variant) -> Variant:
	if value is Resource:
		return value.duplicate(true)
	if value is Dictionary:
		var copied := {}
		for key in value:
			copied[key] = copy_state(value[key])
		return copied
	if value is Array:
		var copied: Array = []
		for entry in value:
			copied.append(copy_state(entry))
		return copied
	return value

func continue_game() -> bool:
	if sleeping:
		return false
	var saved := get_node("/root/SaveSystem").read_checkpoint() as Resource
	if saved == null:
		return false
	var c: Dictionary = copy_state(saved.checkpoint)
	sleeping = true
	_sleep_generation += 1
	var fade := get_node("/root/SceneTransitionManager")
	await fade.fade_to_black(.25)
	get_node("/root/DemoInterface").close_modal()
	get_node("/root/DreamFlow").reset_sequence()
	get_node("/root/ReserveSimulation").clear_simulation()
	persistent_session = true
	campaign_started = true
	room_items = copy_state(c.items)
	storage.assign(copy_state(c.storage))
	_checkpoint_items = copy_state(c.items)
	_checkpoint_inventory = copy_state(c.inventory)
	_checkpoint_storage.assign(copy_state(c.storage))
	_checkpoint_scene = c.scene
	_checkpoint_transform = c.transform
	_restore_inventory = copy_state(c.inventory)
	_restore_transform = true
	get_node("/root/ReserveState").restore(c.progress)
	get_node("/root/ReserveState").checkpoint_day()
	get_tree().change_scene_to_file(_checkpoint_scene)
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	var player := get_tree().current_scene.get_node("Player")
	player.controls_locked = true
	await fade.fade_from_black(.4)
	sleeping = false
	player.controls_locked = get_node("/root/DemoInterface").modal.visible
	if not player.controls_locked:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true

func return_to_menu() -> void:
	if sleeping:
		return
	get_tree().paused = false
	sleeping = true
	_sleep_generation += 1
	var fade := get_node("/root/SceneTransitionManager")
	await fade.fade_to_black(.2)
	get_node("/root/DemoInterface").close_modal()
	get_node("/root/DreamFlow").reset_sequence()
	get_node("/root/ReserveSimulation").clear_simulation()
	get_tree().change_scene_to_file(MENU)
	await get_tree().scene_changed
	await fade.fade_from_black(.3)
	sleeping = false
	get_tree().current_scene.complete_entry()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
