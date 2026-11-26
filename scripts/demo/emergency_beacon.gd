@tool
extends OmniLight3D
## Pulso lento, sem flash de corte; só o apagão inicial do Dia 1.
@export var pulse_period: float = 2.4
@export var peak_energy: float = 0.8
var clock := 0.0
func _ready() -> void:
	if not Engine.is_editor_hint():
		get_node("/root/ReserveState").changed.connect(_outage_changed)
		_outage_changed()

func _outage_changed() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var progress := get_node("/root/ReserveState")
	if progress.day != 1 or progress.power_restored or progress.is_dream:
		light_energy = 0
		var bulb := get_node_or_null("Bulb") as MeshInstance3D
		if bulb != null:
			bulb.visible = false

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		light_energy = peak_energy * 0.45
		return
	var progress := get_node("/root/ReserveState")
	var active: bool = progress.day == 1 and not progress.power_restored and not progress.is_dream
	clock += delta
	light_energy = peak_energy * (0.12 + 0.88 * pow((sin(clock*TAU/pulse_period)+1.0)*0.5,2.0)) if active else 0.0
	var bulb := get_node_or_null("Bulb") as MeshInstance3D
	if bulb != null:
		bulb.visible = active
