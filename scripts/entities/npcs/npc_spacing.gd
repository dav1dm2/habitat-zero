extends RefCounted
## Separação comum para animais e robô, inclusive quando estão parados.
static func velocity_for(actor: CharacterBody3D, desired: Vector3, speed: float, personal_space: float) -> Vector3:
	var result := desired
	var separation := Vector3.ZERO
	for other in actor.get_tree().get_nodes_in_group("mobile_npcs") + actor.get_tree().get_nodes_in_group("npc_spacing_obstacles"):
		if other == actor or not is_instance_valid(other) or not other.is_inside_tree():
			continue
		var away: Vector3 = actor.global_position - other.global_position
		if absf(away.y) > 1.6:
			continue
		away.y = 0.0
		var distance := away.length()
		if distance >= personal_space:
			continue
		if distance < 0.01:
			away = Vector3.RIGHT if actor.get_instance_id() > other.get_instance_id() else Vector3.LEFT
		else:
			away /= distance
		var closing := result.dot(-away)
		if closing > 0.0:
			result += away * closing * clampf((personal_space - distance) / 0.5, 0.0, 1.0)
		separation += away * ((personal_space - distance) / personal_space) * speed * 2.5
	result += separation
	return result.limit_length(speed)
