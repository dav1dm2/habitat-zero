extends Resource

@export var item_id: StringName
@export var display_name: String = "Item de teste"
@export_range(0, 6, 1) var effect: int = 0
@export var pickup_color: Color = Color.WHITE

# Mutable contents belong to each physical collector, never to the shared template.
@export var sample_day: int = 0
@export var sample_origin: String = ""
@export var sample_ids: Array[int] = []
const SAMPLE_CAPACITY := 3

func inventory_name() -> String:
	if item_id == &"sample_collector":
		return "%s %d/%d" % [display_name, sample_ids.size(), SAMPLE_CAPACITY]
	return display_name

func collect_sample(origin: String, id: int, day: int = 0) -> String:
	var progress := Engine.get_main_loop().root.get_node_or_null("ReserveState") as Node
	if day == 0 and progress != null:
		day = progress.day
	if not sample_ids.is_empty() and sample_day != 0 and day != 0 and sample_day != day:
		return "Amostras do dia anterior: esvazie o coletor na bancada do laboratório."
	if sample_ids.size() >= SAMPLE_CAPACITY:
		return "Coletor cheio (3/3). Leve-o à bancada do laboratório e pressione E."
	if not sample_origin.is_empty() and sample_origin != origin:
		return "Este coletor já contém amostras de outra área. Use o outro coletor."
	if id in sample_ids:
		return "Este arbusto já foi amostrado neste coletor. Procure outro arbusto."
	if progress != null and day == progress.day and progress.was_sampled_today(origin,id):
		return "Este arbusto já forneceu uma amostra hoje. Procure outro; amanhã poderá coletar aqui novamente."
	sample_origin = origin
	if day != 0:
		sample_day = day
	sample_ids.append(id)
	if progress != null and day == progress.day:
		progress.record_sample(origin,id)
	return "Amostra coletada: %d/3.%s" % [sample_ids.size(), " Volte ao laboratório e use E na bancada." if sample_ids.size() == SAMPLE_CAPACITY else " Procure outro arbusto."]

func empty_samples() -> void:
	sample_ids.clear()
	sample_origin = ""
	sample_day = 0
