extends StaticBody3D


func interact(_actor: Node) -> void:
	var root := get_tree().current_scene
	if root != null:
		root.call("hear_briefing")
