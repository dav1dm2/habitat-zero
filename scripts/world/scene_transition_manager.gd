extends Node

const ARRIVAL_DISTANCE: float = 1.25
const MAX_LATERAL_OFFSET: float = 0.35

var _pending_door_path: NodePath
var _pending_lateral_offset: float = 0.0
var _transition_pending: bool = false
var _player_state: Dictionary = {}
var _fade: ColorRect
var _fade_tween: Tween
var _with_fade := false


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)


func travel(destination_scene: String, destination_door_path: NodePath, source_door: Node3D, player: Node3D) -> void:
	if _transition_pending or get_node("/root/DemoSession").sleeping or get_node("/root/DreamFlow").input_locked:
		return
	if destination_scene.is_empty():
		push_error("A transição não tem uma cena de destino configurada.")
		return
	if destination_door_path.is_empty():
		push_error("A transição não tem uma porta de chegada configurada.")
		return

	_pending_door_path = destination_door_path
	_pending_lateral_offset = clampf(
		source_door.to_local(player.global_position).x,
		-MAX_LATERAL_OFFSET,
		MAX_LATERAL_OFFSET
	)
	var inventory := player.get_node_or_null("Inventory")
	_player_state = {"inventory": inventory.export_inventory() if inventory != null else {},
		"health": player.health, "stamina": player.stamina, "regen": player._time_since_damage}
	_transition_pending = true
	_with_fade = get_node("/root/DemoSession").is_campaign(get_tree().current_scene)
	player.controls_locked = true
	get_node("/root/DemoInterface").close_modal()
	player.controls_locked = true
	get_node("/root/Soundtrack").play_door()
	if _with_fade:
		await _fade_to(1.0)
	if not _transition_pending or not is_instance_valid(player) or not is_instance_valid(source_door):
		return
	get_node("/root/DemoSession").capture_items(get_tree().current_scene)
	var simulation := get_tree().root.get_node_or_null("ReserveSimulation")
	if simulation != null:
		simulation.prepare_player_travel()
	var error := get_tree().change_scene_to_file(destination_scene)
	if error != OK:
		_transition_pending = false
		player.controls_locked = false
		if _with_fade:
			_fade_to(0.0)
		push_error("Não foi possível abrir '%s' (erro %d)." % [destination_scene, error])


func _on_scene_changed() -> void:
	if not _transition_pending:
		return

	_transition_pending = false
	var scene_root := get_tree().current_scene
	if scene_root == null:
		push_error("A transição terminou sem uma cena ativa.")
		return

	var destination_door := scene_root.get_node_or_null(_pending_door_path) as Node3D
	var player := scene_root.get_node_or_null("Player") as CharacterBody3D
	if destination_door == null or player == null:
		push_error("A cena '%s' precisa conter a porta de chegada '%s' e um nó Player." % [scene_root.name, _pending_door_path])
		return

	var inward_direction := -destination_door.global_basis.z.normalized()
	var lateral_direction := destination_door.global_basis.x.normalized()
	var arrival_position := destination_door.global_position
	arrival_position += inward_direction * ARRIVAL_DISTANCE
	arrival_position += lateral_direction * _pending_lateral_offset
	var marker := destination_door.get_node_or_null("Arrival") as Node3D
	if marker != null:
		arrival_position = marker.global_position + lateral_direction * _pending_lateral_offset
		inward_direction = -marker.global_basis.z.normalized()
	else:
		arrival_position.y = player.global_position.y

	player.global_position = arrival_position
	player.rotation.y = atan2(-inward_direction.x, -inward_direction.z)
	player.velocity = Vector3.ZERO
	if not _player_state.is_empty():
		player.get_node("Inventory").import_inventory(_player_state.inventory)
		player.health = _player_state.health
		player.stamina = _player_state.stamina
		player._time_since_damage = _player_state.regen
		player.health_bar.value = player.health
		player.stamina_bar.value = player.stamina
	_player_state = {}
	player.controls_locked = true
	if _with_fade:
		await _fade_to(0.0)
	if is_instance_valid(player):
		player.controls_locked = false

func _fade_to(alpha: float, duration: float = 0.18) -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", alpha, duration)
	await _fade_tween.finished

func cancel_pending() -> void:
	_transition_pending = false
	_player_state = {}
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	if _fade != null:
		_fade.color.a = 0.0

func fade_to_black(duration: float = 0.45) -> void:
	await _fade_to(1.0,duration)

func fade_from_black(duration: float = 0.45) -> void:
	await _fade_to(0.0,duration)
