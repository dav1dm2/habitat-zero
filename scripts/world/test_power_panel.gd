extends StaticBody3D

func _ready() -> void:
	add_to_group("interactables")


func interact(_actor: Node) -> void:
	var root := get_tree().current_scene
	if root != null:
		root.call("show_status", "Painel sem energia. Mire nele e use o fusível com M1.")


func accept_item(definition: Resource, _actor: Node) -> bool:
	if definition == null or definition.get("item_id") != &"fuse":
		return false
	var lamp := get_node_or_null("Lamp") as MeshInstance3D
	if lamp == null:
		return false
	lamp.material_override = _indicator_material(Color(0.2, 0.95, 0.45), true)
	var root := get_tree().current_scene
	if root != null:
		root.call("restore_power")
	return true


func _indicator_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	return material
