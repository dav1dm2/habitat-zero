extends Node

const ARRIVAL_DISTANCE: float = 1.25
const MAX_LATERAL_OFFSET: float = 0.35

var _pending_door_path: NodePath
var _pending_lateral_offset: float = 0.0
var _transition_pending: bool = false


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)


func travel(destination_scene: String, destination_door_path: NodePath, source_door: Node3D, player: Node3D) -> void:
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
	_transition_pending = true

	var error := get_tree().change_scene_to_file(destination_scene)
	if error != OK:
		_transition_pending = false
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
	arrival_position.y = player.global_position.y

	player.global_position = arrival_position
	player.rotation.y = atan2(-inward_direction.x, -inward_direction.z)
	player.velocity = Vector3.ZERO
