extends StaticBody3D

@export_file("*.tscn") var destination_scene: String = ""


func _ready() -> void:
	add_to_group("interactables")


func interact(_actor: Node) -> void:
	if destination_scene.is_empty():
		push_error("A porta '%s' não tem uma cena de destino configurada." % name)
		return

	var error := get_tree().change_scene_to_file(destination_scene)
	if error != OK:
		push_error("Não foi possível abrir '%s' (erro %d)." % [destination_scene, error])
