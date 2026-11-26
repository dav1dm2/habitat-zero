extends StaticBody3D
const prompt_offset := Vector3.ZERO
@export var breaker_order := PackedInt32Array([1, 0, 2])
@export_range(0.0, 2.0, 0.05) var interaction_delay := 0.3
var _last_action := -10.0

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("hud_interactables")
	get_node("/root/ReserveState").changed.connect(_refresh)
	_refresh()

func interaction_prompt() -> String:
	var progress := get_node("/root/ReserveState")
	if progress.is_dream or progress.power_restored:
		return "E  •  Verificar painel elétrico"
	if progress.fuse_installed:
		return "E  •  Acessar disjuntores"
	return "M1  •  Instalar fusível equipado"

func interact(_actor: Node) -> void:
	var progress := get_node("/root/ReserveState")
	if progress.is_dream:
		get_node("/root/DemoInterface").show_status("O painel está completamente apagado.")
		return
	if progress.power_restored:
		get_node("/root/DemoInterface").show_status("Alimentação principal estável.")
	elif progress.fuse_installed:
		get_node("/root/DemoInterface").show_power(self)
	else:
		get_node("/root/DemoInterface").show_status("Fusível ausente. Equipe o fusível e use M1 no painel.")

func accept_item(definition: Resource, _actor: Node) -> bool:
	var progress := get_node("/root/ReserveState")
	if progress.is_dream or definition == null or definition.item_id != &"fuse" or progress.fuse_installed or progress.power_restored:
		return false
	progress.fuse_installed = true
	progress.changed.emit()
	get_node("/root/DemoInterface").show_power.call_deferred(self)
	return true

func press_breaker(index: int) -> bool:
	var progress := get_node("/root/ReserveState")
	var ui := get_node("/root/DemoInterface")
	var now := Time.get_ticks_msec() / 1000.0
	if progress.is_dream or not progress.fuse_installed or progress.power_restored or now - _last_action < interaction_delay or breaker_order.is_empty():
		return false
	_last_action = now
	if index != breaker_order[progress.breaker_progress]:
		progress.breaker_progress = 0
		ui.show_status("Sequência incorreta. Disjuntores reiniciados; o fusível permanece instalado.")
		ui.tone(180)
	else:
		progress.breaker_progress += 1
		ui.tone(400 + 160 * progress.breaker_progress)
	if progress.breaker_progress >= breaker_order.size():
		progress.power_restored = true
		ui.close_modal()
		ui.show_status("Energia restaurada. Buzzy: Olá? Pesquisador? O projetor do corredor voltou a funcionar!")
	progress.changed.emit()
	if not progress.power_restored:
		ui.show_power(self)
	return progress.power_restored

func _refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var progress := get_node("/root/ReserveState")
	var lamp := get_node_or_null("Lamp") as MeshInstance3D
	if lamp != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("7ad38a") if progress.power_restored else (Color("c3a969") if progress.fuse_installed else Color("a65e48"))
		mat.emission_enabled = not progress.is_dream
		if progress.is_dream:
			mat.albedo_color = Color("101419")
		mat.emission = mat.albedo_color
		lamp.material_override = mat
