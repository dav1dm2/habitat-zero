extends StaticBody3D

@export var can_fertilize: bool = true
@export var bush_id: int = 0
@export var sample_origin: String = ""
@export var sampling_day: int = 0 # Legacy scene metadata; no longer restricts sampling.
@export var available_from_day: int = 1
func _ready() -> void:
	if can_fertilize:
		add_to_group("fertilizable_bushes")
	if not sample_origin.is_empty():
		add_to_group("sample_bushes")
	add_to_group("interactables")


func interact(_actor: Node) -> void:
	var root := _room()
	if root != null:
		root.call("show_status", "Use M1 com o Coletor de amostras." if not can_fertilize else "Arbusto %d: M1 com adubo%s" % [bush_id + 1, " ou Coletor de amostras" if not sample_origin.is_empty() else ""])

func tool_prompt(tool: Resource) -> String:
	var progress := get_node("/root/ReserveState")
	if progress.is_dream or available_from_day > progress.day or tool == null:
		return ""
	if tool.item_id == &"fertilizer" and can_fertilize:
		return "Arbusto já adubado" if is_in_group("fertilized_bushes") else "M1  •  Aplicar adubo"
	if tool.item_id == &"sample_collector" and not sample_origin.is_empty():
		return "M1  •  Coletar amostra"
	return ""


func accept_item(definition: Resource, _actor: Node) -> bool:
	if get_node("/root/ReserveState").is_dream:
		return false
	if not can_fertilize or definition == null or definition.get("item_id") != &"fertilizer" or is_in_group("fertilized_bushes"):
		return false
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.62, 0.29)
	material.roughness = 0.9
	var foliage := get_node_or_null("Foliage") as MeshInstance3D
	if foliage == null:
		return false
	add_to_group("fertilized_bushes")
	foliage.material_override = material
	var root := _room()
	if root != null:
		root.call("on_bush_fertilized", bush_id)
	return true


func _room() -> Node:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("on_bush_fertilized"):
			return ancestor
		ancestor = ancestor.get_parent()
	return null

func collect_sample(tool: Resource) -> String:
	if get_node("/root/ReserveState").is_dream:
		return "Investigue a floresta."
	if tool == null or tool.item_id != &"sample_collector" or sample_origin.is_empty():
		return "Use um coletor de amostras nesta área."
	var day: int = get_node("/root/ReserveState").day
	if available_from_day > day:
		return "Arbusto indisponível."
	return tool.collect_sample(sample_origin, bush_id, day)
