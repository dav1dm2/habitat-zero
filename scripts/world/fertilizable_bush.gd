extends StaticBody3D

@export var bush_id: int = 0
func _ready() -> void:
	add_to_group("fertilizable_bushes")
	add_to_group("interactables")


func interact(_actor: Node) -> void:
	var root := get_tree().current_scene
	if root != null:
		root.call("show_status", "Arbusto %d: use Fertilizante com M1" % (bush_id + 1))


func accept_item(definition: Resource, _actor: Node) -> bool:
	if definition == null or definition.get("item_id") != &"fertilizer" or is_in_group("fertilized_bushes"):
		return false
	add_to_group("fertilized_bushes")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.62, 0.29)
	material.roughness = 0.9
	var foliage := get_node_or_null("Foliage") as MeshInstance3D
	if foliage == null:
		return false
	foliage.material_override = material
	var root := get_tree().current_scene
	if root != null:
		root.call("on_bush_fertilized", bush_id)
	return true
