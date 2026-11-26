extends Node
## Direção do epílogo: movimentos roteirizados com navegação e colisão reais.
const EndingScreen = preload("res://scripts/ui/ending_screen.gd")
signal phase_changed(value: String)
var phase := "inactive"
var input_locked := false
var development_inspection := false
var _generation := 0
var _retry_delay := 0.0
var _end_canvas: CanvasLayer
var _active_room: Node3D
@export var trigger_distance: float = 10.0
@export var player_walk_speed: float = 2.1
@export var approach_duration: float = 3.2

func _ready() -> void:
	get_tree().scene_changed.connect(_scene_changed)
	get_node("/root/ReserveState").changed.connect(_progress_changed)

func _progress_changed() -> void:
	if not get_node("/root/ReserveState").is_dream:
		reset_sequence()

func _scene_changed() -> void:
	_generation += 1
	configure_room.call_deferred(get_tree().current_scene)

func _phase(value: String) -> void:
	phase = value
	phase_changed.emit(value)

func reset_sequence() -> void:
	development_inspection = false
	_generation += 1
	input_locked = false
	_active_room = null
	_phase("inactive")
	if is_instance_valid(_end_canvas):
		_end_canvas.queue_free()
		_end_canvas = null

func configure_room(room: Node) -> void:
	if not is_instance_valid(room) or room != get_tree().current_scene or not get_node("/root/ReserveState").is_dream or not get_node("/root/DemoSession").is_campaign(room):
		return
	if room.get_meta("simulation_background",false):
		return
	_active_room = room
	get_node("/root/ReserveSimulation").suspend_for_dream(room)
	# Unpowered means no emission or usable machines, including the power-panel bulb.
	var player_node := room.get_node_or_null("Player")
	for node in descendants(room):
		if node is Label3D:
			node.shaded = true
		if node is Light3D and (player_node == null or not player_node.is_ancestor_of(node)):
			node.light_energy = 0.0
		if node is MeshInstance3D:
			var material := node.material_override as StandardMaterial3D
			if material != null and material.emission_enabled:
				material = material.duplicate()
				material.emission_enabled = false
				node.material_override = material
	var environment := room.get_node_or_null("Ambiente") as WorldEnvironment
	if environment == null:
		environment = room.get_node_or_null("Ambiente_Nevoeiro") as WorldEnvironment
	if environment != null:
		environment.environment = environment.environment.duplicate()
		environment.environment.ambient_light_color = Color("384558")
		environment.environment.ambient_light_energy = 0.025 if room.scene_file_path.ends_with("attis_forest.tscn") else 0.0
		environment.environment.background_color = Color("020307")
		environment.environment.fog_light_color = Color("101720")
	var fauna := room.get_node_or_null("Fauna") as Node3D
	if fauna != null:
		fauna.visible = false
		fauna.process_mode = Node.PROCESS_MODE_DISABLED
		for animal in fauna.get_children():
			if animal is CharacterBody3D:
				animal.collision_layer = 0
				animal.remove_from_group("animals")
				animal.remove_from_group("mobile_npcs")
	var event := room.get_node_or_null("DreamEvent") as Node3D
	if event != null:
		event.visible = true
		event.process_mode = Node.PROCESS_MODE_INHERIT
		for actor in descendants(event):
			if actor is CharacterBody3D and actor.has_method("activate_event"):
				actor.activate_event()
		_phase("exploring")
	else:
		_phase("awakened")

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func _physics_process(delta: float) -> void:
	_retry_delay = maxf(0.0,_retry_delay-delta)
	if development_inspection or phase != "exploring" or _retry_delay > 0 or not is_instance_valid(_active_room):
		return
	var player := _active_room.get_node_or_null("Player") as CharacterBody3D
	var center := _active_room.get_node_or_null("DreamEvent/RitualCenter") as Marker3D
	var trigger := _active_room.get_node_or_null("DreamEvent/RitualCenter/RitualTrigger") as Area3D
	var radius := trigger_distance
	var origin: Vector3 = center.global_position if center != null else Vector3.ZERO
	if trigger != null:
		var collision := trigger.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null and collision.shape is SphereShape3D:
			# Uniform sphere scale is exposed on the area; radius is also editable on its shape.
			radius = collision.shape.radius * maxf(absf(trigger.global_basis.get_scale().x),maxf(absf(trigger.global_basis.get_scale().y),absf(trigger.global_basis.get_scale().z)))
		origin = trigger.global_position
	if player != null and center != null and player.global_position.distance_to(origin) < radius:
		_run_ritual(player,center)

func _run_ritual(player: CharacterBody3D, center: Marker3D) -> void:
	if input_locked:
		return
	_generation += 1
	var token := _generation
	input_locked = true
	get_node("/root/DemoInterface").close_modal()
	player.controls_locked = true
	player.set_physics_process(false)
	player.get_node("Hud").visible = false
	player.velocity = Vector3.ZERO
	_phase("walking_to_center")
	var room: Node3D = _active_room
	var target := center.global_position
	var map: RID = room.get_node("Navegacao").get_navigation_map()
	var path := NavigationServer3D.map_get_path(map,player.global_position,target,true)
	var elapsed := 0.0
	for point in path:
		while Vector2(point.x-player.global_position.x,point.z-player.global_position.z).length() > 0.18 and elapsed < 25.0:
			await get_tree().physics_frame
			if token != _generation or not is_instance_valid(player):
				return
			var delta := get_physics_process_delta_time()
			elapsed += delta
			var offset := point-player.global_position
			offset.y = 0
			player.velocity.x = offset.normalized().x*_camera_setting("walk_speed",player_walk_speed)
			player.velocity.z = offset.normalized().z*_camera_setting("walk_speed",player_walk_speed)
			player.velocity.y = -0.1 if player.is_on_floor() else player.velocity.y-9.8*delta
			player._try_step_up(Vector3(player.velocity.x,0,player.velocity.z)*delta)
			player.move_and_slide()
			_update_ritual_camera(player,"WalkLookTarget",delta)
	player.velocity = Vector3.ZERO
	if path.is_empty() or Vector2(target.x-player.global_position.x,target.z-player.global_position.z).length() > 0.8:
		push_warning("Ritual: caminho ao centro bloqueado; controle devolvido para nova aproximação.")
		input_locked = false
		player.controls_locked = false
		player.set_physics_process(true)
		player.get_node("Hud").visible = true
		_retry_delay = 2
		_phase("exploring")
		return
	_phase("centered")
	await _hold_ritual_camera(player,"FinalLookTarget",_camera_setting("centered_duration",0.9),token)
	if token != _generation or not is_instance_valid(room):
		return
	# All NPCs receive the new presentation/movement state in the same frame.
	for deer in room.get_node("DreamEvent/DeerCircle").get_children():
		var inward: Vector3 = deer.global_position-center.global_position
		inward.y = 0
		deer.event_goal = NavigationServer3D.map_get_closest_point(map,center.global_position+inward.normalized()*3.1)
		deer.set_event_state("ritual_approach")
	_phase("deer_approaching")
	await _hold_ritual_camera(player,"FinalLookTarget",_camera_setting("deer_approach_duration",approach_duration),token)
	if token != _generation:
		return
	var ritual_frame: Texture2D
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			ritual_frame = ImageTexture.create_from_image(image)
	_phase("fading_out")
	await get_node("/root/SceneTransitionManager").fade_to_black(0.65)
	if token != _generation:
		return
	get_node("/root/ReserveState").demo_finished = true
	_phase("finished")
	show_ending(ritual_frame)

func _camera_setting(property: String, fallback: float) -> float:
	var settings := _active_room.get_node_or_null("DreamEvent/RitualCamera") if is_instance_valid(_active_room) else null
	return float(settings.get(property)) if settings != null else fallback

func _camera_target(marker_name: String) -> Vector3:
	var marker := _active_room.get_node_or_null("DreamEvent/RitualCamera/"+marker_name) as Node3D
	if marker != null:
		return marker.global_position
	# Compatibility for an older scene: frame the middle of the initial semicircle.
	var center := Vector3.ZERO
	var deer := _active_room.get_node("DreamEvent/DeerCircle").get_children()
	for actor in deer:
		center += actor.global_position + Vector3.UP * 1.3
	return center / maxf(1.0,deer.size())

func _update_ritual_camera(player: CharacterBody3D, marker_name: String, delta: float) -> void:
	var direction: Vector3 = _camera_target(marker_name)-player.camera.global_position
	var horizontal := Vector2(direction.x,direction.z).length()
	if horizontal < 0.05:
		return
	var max_turn := deg_to_rad(_camera_setting("turn_speed_degrees",80.0))*delta
	var yaw := atan2(-direction.x,-direction.z)
	var pitch := clampf(atan2(direction.y,horizontal),-player.MAX_PITCH,player.MAX_PITCH)
	# Retain the incoming pose. Each axis turns by a bounded amount, also at phase changes.
	player.rotation.y += clampf(wrapf(yaw-player.rotation.y,-PI,PI),-max_turn,max_turn)
	player.camera.rotation.x = move_toward(player.camera.rotation.x,pitch,max_turn)

func _hold_ritual_camera(player: CharacterBody3D, marker_name: String, duration: float, token: int) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		if token != _generation or not is_instance_valid(player):
			return
		var delta := get_physics_process_delta_time()
		elapsed += delta
		_update_ritual_camera(player,marker_name,delta)

func show_ending(ritual_frame: Texture2D = null) -> void:
	_end_canvas = CanvasLayer.new()
	_end_canvas.layer = 110
	add_child(_end_canvas)
	var screen := EndingScreen.new()
	screen.ritual_frame = ritual_frame
	_end_canvas.add_child(screen)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
