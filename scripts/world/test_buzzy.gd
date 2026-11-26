extends StaticBody3D


func interact(_actor: Node) -> void:
	var root := get_tree().current_scene
	if root != null:
		root.call("hear_briefing")


func _ready() -> void:
	add_to_group("npc_spacing_obstacles")
