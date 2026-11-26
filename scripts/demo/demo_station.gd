extends StaticBody3D
@export_enum("Depósito", "Cama", "Porta Habitat 1", "Laboratório", "Porta Habitat 2") var station: int = 0
const prompt_offset := Vector3.ZERO

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("hud_interactables")

func interaction_prompt() -> String:
	match station:
		0: return "E  •  Abrir depósito pessoal"
		1: return "E  •  Descansar"
		2: return "E  •  Consultar acesso ao Habitat 1"
		3: return "E  •  Entregar amostras"
		4: return "E  •  Verificar acesso ao Habitat 2"
	return ""

func interact(_actor: Node) -> void:
	var ui := get_node("/root/DemoInterface")
	if get_node("/root/ReserveState").is_dream:
		ui.show_status("Tudo está sem energia.")
		return
	match station:
		0:
			ui.show_storage()
		1:
			if not get_node("/root/DemoSession").advance_day(get_tree().current_scene):
				ui.show_notebook()
				ui.show_status("Conclua as tarefas do dia e as entregas das duas áreas antes de descansar.")
		2:
			ui.show_status("Use a porta H1 no corredor dos habitats para entrar no recinto das aves.")
		3:
			ui.show_status(_actor.get_node("Inventory").deliver_samples())
		4:
			ui.show_status("Habitat 2 / acesso bloqueado.")
