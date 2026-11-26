extends StaticBody3D
@onready var reserve_state: Node = get_node("/root/ReserveState")
@onready var label: Label3D = $StateLabel

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("npc_spacing_obstacles")
	reserve_state.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	label.text = "Buzzy · E conversar" if reserve_state.power_restored else "Emissor sem energia"

func interact(_actor: Node) -> void:
	if not reserve_state.power_restored:
		_status("Emissor: restaure a energia no console de teste (F1).")
		return
	if not reserve_state.briefing_heard:
		reserve_state.briefing_heard = true
		reserve_state.changed.emit()
		_status("Buzzy: Bem-vindo! Fertilize os cinco arbustos. No Habitat 1, respeite os ninhos e evite ficar cercado. O seguro não cobre curiosidade.")
	else:
		_status("Buzzy: %d/%d arbustos. Kiwi protege ovos; Casuário prefere reuniões em grupo. Com você no centro." % [get_tree().current_scene.get_room_bushes().filter(func(bush): return bush.is_in_group("fertilized_bushes")).size(), 10 if reserve_state.day >= 2 else 5])


func _status(message: String) -> void:
	var room := get_tree().current_scene
	if room != null and room.has_method("show_status"):
		room.call("show_status", message)
