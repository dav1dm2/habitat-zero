extends StaticBody3D

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("npc_spacing_obstacles")
	get_node("/root/ReserveState").changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var on: bool = get_node("/root/ReserveState").power_restored
	if has_node("StateLabel"):
		$StateLabel.text = "Buzzy / E conversar" if on else "Projetor sem energia"

func interaction_prompt() -> String:
	return "E  •  Conversar com Buzzy" if get_node("/root/ReserveState").power_restored else "E  •  Verificar projetor"

func interact(_actor: Node) -> void:
	var ui := get_node("/root/DemoInterface")
	if get_node("/root/ReserveState").power_restored:
		ui.show_buzzy()
	elif get_node("/root/ReserveState").is_dream:
		ui.show_status("O projetor está apagado.")
	else:
		ui.show_status("Projetor sem energia. A sala de máquinas fica ao fundo do corredor.")
