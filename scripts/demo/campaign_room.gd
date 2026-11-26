@tool
extends Node3D
## Progressão comum às cenas da campanha, sem construir geometria em execução.
var _death_pending := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	get_node("/root/ReserveState").changed.connect(_apply_campaign_progress)
	_apply_campaign_progress()
	if not get_meta("simulation_background", false):
		get_node("/root/DemoSession").prepare_room.call_deferred(self)

func get_room_key() -> String:
	return scene_file_path

func get_room_bushes(include_inactive: bool = false) -> Array[Node]:
	if not is_inside_tree():
		return []
	var result: Array[Node] = []
	var progress := get_node("/root/ReserveState")
	for bush in get_tree().get_nodes_in_group("fertilizable_bushes"):
		if is_ancestor_of(bush) and (include_inactive or bush.available_from_day <= progress.day):
			result.append(bush)
	return result

func _apply_campaign_progress() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var progress := get_node("/root/ReserveState")
	for bush in get_room_bushes(true):
		var active: bool = bush.available_from_day <= progress.day
		bush.visible = active
		bush.collision_layer = (32 if bush.has_node("SamplingHitbox") else 1) if active else 0
		var done: bool = bush.bush_id in progress.fertilized_ids
		if done:
			bush.add_to_group("fertilized_bushes")
		else:
			bush.remove_from_group("fertilized_bushes")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("4c8651") if done else Color("777458")
		bush.get_node("Foliage").material_override = mat
	for bush in get_tree().get_nodes_in_group("sample_bushes"):
		if is_ancestor_of(bush):
			var active: bool = bush.available_from_day <= progress.day
			bush.visible = active
			bush.collision_layer = (32 if bush.has_node("SamplingHitbox") else 1) if active else 0
	for lamp in get_tree().get_nodes_in_group("campaign_lights"):
		if is_ancestor_of(lamp):
			lamp.light_energy = float(lamp.get_meta("powered_energy", 1.3)) if progress.power_restored else (0.0 if progress.is_dream else 0.04)
	var world := get_node_or_null("Ambiente") as WorldEnvironment
	if world != null:
		world.environment.ambient_light_energy = 0.42 if progress.power_restored else (0.0 if progress.is_dream else 0.10)
	var radio_sign := get_node_or_null("Radio/EstacaoDeRadio/Identificacao/Texto") as Label3D
	if radio_sign != null:
		radio_sign.text = "RÁDIO / R-04\nENERGIA RESTABELECIDA" if progress.power_restored else "RÁDIO / R-04\nSEM ENERGIA"
	for zone in get_tree().get_nodes_in_group("radiation_zones"):
		if is_ancestor_of(zone):
			zone.set_physics_process(not progress.is_dream and not progress.power_restored and not get_meta("simulation_background", false))

func on_bush_fertilized(id: int) -> void:
	get_node("/root/ReserveState").fertilize(id)
	show_status("Arbusto tratado. Progresso registrado no caderno.")

func show_status(words: String) -> void:
	if not get_meta("simulation_background", false):
		get_node("/root/DemoInterface").show_status(words)

func on_player_death() -> void:
	if _death_pending:
		return
	_death_pending = true
	get_node("/root/DemoSession").restart_day.call_deferred()

func item_out_of_bounds(at: Vector3) -> bool:
	if scene_file_path.ends_with("attis_forest.tscn"):
		return absf(at.x) > 66.0 or at.z < -87.0 or at.z > 78.0 or at.y < -3.0
	return false

func get_sample_bushes() -> Array[Node]:
	var result: Array[Node] = []
	var day: int = get_node("/root/ReserveState").day
	for bush in get_tree().get_nodes_in_group("sample_bushes"):
		if is_ancestor_of(bush) and bush.available_from_day <= day:
			result.append(bush)
	return result
