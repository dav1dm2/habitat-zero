extends StaticBody3D
@export var action: String = "power"
func _ready() -> void:
	add_to_group("interactables")
func interact(_actor: Node) -> void:
	get_tree().current_scene.test_action(action)
