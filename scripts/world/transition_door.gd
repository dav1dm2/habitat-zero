extends StaticBody3D

const TRANSITION_MANAGER_SCRIPT = preload("res://scripts/world/scene_transition_manager.gd")
const TRANSITION_MANAGER_NAME: NodePath = NodePath("SceneTransitionManager")

@export_file("*.tscn") var destination_scene: String = ""
@export var destination_door_path: NodePath


func _ready() -> void:
	add_to_group("interactables")


func interact(_actor: Node) -> void:
	if destination_scene.is_empty():
		push_error("A porta '%s' não tem uma cena de destino configurada." % name)
		return

	var actor_3d := _actor as Node3D
	if actor_3d == null:
		push_error("A porta '%s' recebeu um ator que não é Node3D." % name)
		return

	var manager := get_tree().root.get_node_or_null(TRANSITION_MANAGER_NAME)
	if manager == null:
		manager = TRANSITION_MANAGER_SCRIPT.new()
		manager.name = "SceneTransitionManager"
		get_tree().root.add_child(manager)

	manager.call("travel", destination_scene, destination_door_path, self, actor_3d)
