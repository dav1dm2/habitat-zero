extends Node

const Appearance = preload("res://scripts/entities/items/item_appearance.gd")
const SLOT_COUNT: int = 4
const PICKUP_RANGE: float = 4.5
const USE_RANGE: float = 8.0
const THROW_FORWARD_IMPULSE: float = 4.0
const THROW_UP_IMPULSE: float = 1.8
const PAINT_MARK_GROUP: StringName = &"test_paint_marks"
const EFFECT_PAINT_BLUE: int = 1
const EFFECT_ERASE_PAINT: int = 2
const EFFECT_FERTILIZER: int = 3
const EFFECT_FUSE: int = 4
const EFFECT_SAMPLE: int = 6
const WORLD_ITEM_SCENE: PackedScene = preload("res://scenes/entities/items/world_item.tscn")

var slots: Array[Resource] = [null, null, null, null]
var selected_slot: int = 0
var _status_time := 0.0
var _use_trigger_held := false

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
@onready var status_label: Label = player.get_node("Hud/InventoryStatus") as Label
@onready var interaction_hint: Label = player.get_node("Hud/InteractionHint") as Label
@onready var interaction_arrow: Label = player.get_node("Hud/InteractionArrow") as Label
@onready var slot_views := player.get_node("Hud/InventoryPanel/Slots").get_children()


func _ready() -> void:
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed("use_item"):
		_use_trigger_held = false
	if _status_time > 0.0:
		_status_time -= delta
		if _status_time <= 0.0:
			status_label.hide()
	interaction_hint.hide()
	interaction_arrow.hide()
	if player.controls_locked or (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_node("/root/ControllerSupport").using_gamepad) or not camera.current:
		return
	if get_node("/root/DemoSession").sleeping or get_node("/root/DreamFlow").input_locked:
		return
	var viewport := camera.get_viewport().get_visible_rect()
	var hit := _raycast(PICKUP_RANGE)
	var aimed := hit.get("collider") as Node3D
	var words := _aimed_prompt(aimed)
	if not words.is_empty():
		_show_interaction_hint(words, viewport.get_center(), viewport)
		return

	var nearest_distance := PICKUP_RANGE
	var nearest_prompt := ""
	var nearest_point := Vector2.ZERO
	var room := get_tree().current_scene
	if room == null:
		return
	for target: Node3D in get_tree().get_nodes_in_group("hud_interactables"):
		if not room.is_ancestor_of(target) or not target.is_visible_in_tree():
			continue
		var anchor: Vector3 = target.to_global(target.prompt_offset)
		var distance := camera.global_position.distance_to(anchor)
		if distance >= nearest_distance or camera.is_position_behind(anchor):
			continue
		var screen := camera.unproject_position(anchor)
		if not viewport.grow(-26.0).has_point(screen):
			continue
		if _ray_to(anchor).get("collider") != target:
			continue
		nearest_distance = distance
		nearest_prompt = target.interaction_prompt()
		nearest_point = screen
	if not nearest_prompt.is_empty():
		_show_interaction_hint("Mire · " + nearest_prompt, nearest_point, viewport)


func _aimed_prompt(target: Node3D) -> String:
	if target == null:
		return ""
	if target.has_method("interaction_prompt"):
		return target.interaction_prompt()
	if target.has_method("tool_prompt"):
		return target.tool_prompt(slots[selected_slot])
	if target.is_in_group("world_items") and target.definition != null:
		return "E  •  Recolher " + target.definition.inventory_name()
	return ""


func _show_interaction_hint(words: String, point: Vector2, viewport: Rect2) -> void:
	var below := point.y < viewport.end.y - 112.0
	interaction_hint.text = get_node("/root/ControllerSupport").adapt_text(words)
	interaction_hint.reset_size()
	interaction_hint.position = Vector2(
		clampf(point.x - interaction_hint.size.x * 0.5, 8.0, viewport.end.x - interaction_hint.size.x - 8.0),
		point.y + 36.0 if below else point.y - interaction_hint.size.y - 36.0
	)
	interaction_arrow.text = "↑" if below else "↓"
	interaction_arrow.position = Vector2(point.x - 12.0, point.y + 14.0 if below else point.y - 37.0)
	interaction_hint.show()
	interaction_arrow.show()


func handle_input(event: InputEvent) -> void:
	if get_node("/root/DemoSession").sleeping or get_node("/root/DreamFlow").input_locked:
		return
	if event.is_action_pressed("pickup_item"):
		_pickup_aimed_item()
		return
	if event.is_action_pressed("drop_item"):
		_drop_selected_item()
		return
	if event is InputEventJoypadMotion and event.is_action("use_item"):
		if not event.is_action_pressed("use_item"):
			_use_trigger_held = false
			return
		if _use_trigger_held: return
		_use_trigger_held = true
	if event.is_action_pressed("use_item"):
		_use_selected_item()
		return

	if event.is_action_pressed("next_item"):
		_select_slot((selected_slot+1)%SLOT_COUNT)
		return
	if event.is_action_pressed("previous_item"):
		_select_slot(posmod(selected_slot-1,SLOT_COUNT))
		return
	for slot_index in range(SLOT_COUNT):
		if event.is_action_pressed("select_slot_%d" % (slot_index + 1)):
			_select_slot(slot_index)
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_slot(posmod(selected_slot - 1, SLOT_COUNT))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_slot((selected_slot + 1) % SLOT_COUNT)


func set_slot_item(slot_index: int, definition: Resource) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	slots[slot_index] = definition
	_refresh_hud()
	return true


func _pickup_aimed_item() -> void:
	var hit := _raycast(PICKUP_RANGE)
	if hit.is_empty():
		_set_status("Mire em um item ou porta próxima e pressione E")
		return

	var target := hit.get("collider") as Node
	if target != null and target.is_in_group("interactables"):
		if target.has_method("interact"):
			target.call("interact", player)
		return

	var empty_slot := _find_empty_slot()
	if empty_slot == -1:
		_set_status("Inventário cheio: solte um item com Q")
		return

	var world_item := hit.get("collider") as RigidBody3D
	if world_item == null:
		_set_status("Mire em um item próximo para recolhê-lo")
		return

	var definition := world_item.get("definition") as Resource
	if definition == null:
		_set_status("Mire em um item próximo para recolhê-lo")
		return
	slots[empty_slot] = definition
	var collected_name: String = definition.get("display_name")
	world_item.queue_free()
	_refresh_hud()
	_set_status("Coletado: %s" % collected_name)


func _drop_selected_item() -> void:
	var definition: Resource = slots[selected_slot]
	if definition == null:
		_set_status("O slot selecionado está vazio")
		return

	var dropped_item := WORLD_ITEM_SCENE.instantiate() as RigidBody3D
	dropped_item.set("definition", definition)
	get_tree().current_scene.add_child(dropped_item)
	var forward := -camera.global_transform.basis.z
	dropped_item.global_position = camera.global_position + forward * 0.8 - Vector3.UP * 0.4
	dropped_item.apply_central_impulse(forward * THROW_FORWARD_IMPULSE + Vector3.UP * THROW_UP_IMPULSE)
	dropped_item.apply_torque_impulse(Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8), randf_range(-0.8, 0.8)))
	slots[selected_slot] = null
	_refresh_hud()
	_set_status("Arremessado: %s" % definition.get("display_name"))


func _use_selected_item() -> void:
	var definition: Resource = slots[selected_slot]
	if definition == null:
		_set_status("Selecione um item antes de usar M1")
		return

	var effect: int = definition.get("effect")
	if effect == 5:
		get_node("/root/DemoInterface").show_dream_letter() if definition.item_id == &"dream_letter" else get_node("/root/DemoInterface").show_letter()
		return
	if effect == 0:
		_set_status("%s ainda não tem uma função de teste" % definition.get("display_name"))
		return

	var hit := _raycast(USE_RANGE)
	if hit.is_empty():
		_set_status("Mire em uma superfície ao alcance")
		return

	match effect:
		EFFECT_PAINT_BLUE:
			_create_blue_mark(hit)
			_set_status("Marca azul aplicada")
		EFFECT_ERASE_PAINT:
			_erase_near_hit(hit.get("position", Vector3.ZERO))
		EFFECT_SAMPLE:
			var target := hit.get("collider") as Node
			if target != null and target.has_method("collect_sample"):
				_set_status(target.collect_sample(definition))
			else:
				_set_status("Mire em um arbusto para coletar uma amostra.")
			_refresh_hud()
		EFFECT_FERTILIZER, EFFECT_FUSE:
			var target := hit.get("collider") as Node
			if target != null and target.has_method("accept_item") and target.call("accept_item", definition, player):
				slots[selected_slot] = null
				_refresh_hud()
				_set_status("Usado: %s" % definition.get("display_name"))
			else:
				_set_status("Esse item só funciona no equipamento indicado")


func _create_blue_mark(hit: Dictionary) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "BlueTestMark"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.28
	disc.height = 0.012
	disc.radial_segments = 32
	mark.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.28, 1.0, 1.0)
	material.roughness = 0.5
	mark.material_override = material
	mark.add_to_group(PAINT_MARK_GROUP)
	get_tree().current_scene.add_child(mark)

	var normal: Vector3 = hit.get("normal", Vector3.UP).normalized()
	var surface_point: Vector3 = hit.get("position", Vector3.ZERO)
	mark.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), surface_point + normal * 0.012)


func _erase_near_hit(hit_position: Vector3) -> void:
	var closest_mark: Node3D
	var closest_distance := 0.65
	for candidate in get_tree().get_nodes_in_group(PAINT_MARK_GROUP):
		var mark := candidate as Node3D
		if mark == null:
			continue
		var distance := mark.global_position.distance_to(hit_position)
		if distance <= closest_distance:
			closest_mark = mark
			closest_distance = distance

	if closest_mark == null:
		_set_status("Nenhuma marca azul perto do ponto mirado")
		return
	closest_mark.queue_free()
	_set_status("Colorido apagado")


func _raycast(max_distance: float) -> Dictionary:
	return _ray_to(camera.global_position - camera.global_transform.basis.z * max_distance)


func _ray_to(end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, end)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _find_empty_slot() -> int:
	for index in range(SLOT_COUNT):
		if slots[index] == null:
			return index
	return -1


func _select_slot(slot_index: int) -> void:
	selected_slot = clampi(slot_index, 0, SLOT_COUNT - 1)
	_refresh_hud()
	var definition: Resource = slots[selected_slot]
	_set_status("Slot %d: %s" % [selected_slot + 1, definition.get("display_name") if definition != null else "Vazio"])


func _refresh_hud() -> void:
	for index in range(SLOT_COUNT):
		var definition: Resource = slots[index]
		var caption := "—"
		var icon: Texture2D
		if definition != null:
			caption = definition.display_name
			if definition.item_id == &"sample_collector":
				caption = "Sonda %d/3" % definition.sample_ids.size()
			icon = Appearance.icon_for(definition.item_id)
		slot_views[index].show_item(index, caption, icon, index == selected_slot)


func _set_status(message: String) -> void:
	status_label.text = get_node("/root/ControllerSupport").adapt_text(message)
	status_label.show()
	_status_time = 3.0


func restock_empty_slots(definition: Resource) -> int:
	if definition == null:
		return 0
	var added := 0
	for index in range(SLOT_COUNT):
		if slots[index] == null:
			slots[index] = definition
			added += 1
	_refresh_hud()
	_set_status("Adubo recolhido (%d)" % added if added > 0 else "Inventário cheio")
	return added


func export_inventory() -> Dictionary:
	return {"slots": slots.duplicate(), "selected": selected_slot}

func import_inventory(data: Dictionary) -> void:
	var saved: Array = data.get("slots", [])
	for index in range(SLOT_COUNT):
		slots[index] = saved[index] if index < saved.size() else null
	selected_slot = clampi(int(data.get("selected", 0)), 0, SLOT_COUNT - 1)
	_refresh_hud()

func deliver_samples() -> String:
	var current_day: int = get_node("/root/ReserveState").day
	# Deliver one full tool at a time; selected tool has priority.
	var order: Array[int] = [selected_slot]
	for index in range(SLOT_COUNT):
		if index != selected_slot:
			order.append(index)
	for index in order:
		var tool: Resource = slots[index]
		if tool != null and tool.item_id == &"sample_collector" and not tool.sample_ids.is_empty() and tool.sample_day not in [0, current_day]:
			tool.empty_samples()
			_refresh_hud()
			return "Amostras antigas descartadas. Coletor esvaziado: 0/3. Colete as amostras do dia atual."
		if tool != null and tool.item_id == &"sample_collector" and tool.sample_origin in ["attis", "habitat1"] and tool.sample_ids.size() == 3:
			var progress := get_node("/root/ReserveState")
			var origin: String = tool.sample_origin
			progress.register_analysis(origin)
			tool.empty_samples()
			_refresh_hud()
			return "Amostras de %s entregues. Tarefa concluída. Coletor esvaziado: 0/3." % ("Attis" if origin == "attis" else "Habitat 1")
	return "Traga um coletor cheio (3/3) de Attis ou do Habitat 1. Recolha as ferramentas na bancada auxiliar; use M1 em três arbustos diferentes."
