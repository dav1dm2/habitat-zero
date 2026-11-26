extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.25
@export var crouch_speed: float = 2.2
@export var crouch_height: float = 1.1
@export var crouch_head_height: float = -0.08
@export var crouch_transition_speed: float = 8.0
@export var stamina_capacity: float = 5.0
@export var stamina_drain_per_second: float = 1.25
@export var stamina_recovery_per_second: float = 0.9
@export var max_health: float = 100.0
@export var health_regen_delay: float = 20.0
@export var health_regen_per_second: float = 5.0
var _time_since_damage: float = 0.0
@export var jump_velocity: float = 4.0
@export var mouse_sensitivity: float = 0.002
@export var acceleration: float = 18.0
@export_category("Controle / gamepad")
@export var gamepad_look_speed: Vector2 = Vector2(160.0,120.0)
@export_range(1.0, 2.5, 0.1) var gamepad_look_curve: float = 1.4
@export var gamepad_invert_y: bool = false
var _crouch_toggled := false
var _sprint_toggled := false
@export_range(0.1, 1.0, 0.05) var max_auto_step_height: float = 0.45
@export var item_push_impulse: float = 0.08

const MAX_PITCH: float = 1.48353
var stamina: float = 5.0
var health: float = 100.0
var controls_locked: bool = false
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _standing_capsule_height: float
var _standing_collision_y: float
var _standing_head_y: float
var _suppress_jump_until_release := false
var _jump_requested: bool = false
var _jump_was_pressed: bool = false
var _item_push_cooldowns: Dictionary = {}

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var stamina_bar: ProgressBar = $Hud/StaminaPanel/VBoxContainer/StaminaBar
@onready var health_bar: ProgressBar = $Hud/StaminaPanel/VBoxContainer/HealthBar
@onready var inventory: Node = $Inventory
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var flashlight_status_label: Label = $Hud/FlashlightStatus
@onready var item_bump_area: Area3D = $ItemBumpArea

func _ready() -> void:
	stamina = stamina_capacity
	health = max_health
	stamina_bar.max_value = stamina_capacity
	stamina_bar.value = stamina
	health_bar.max_value = max_health
	health_bar.value = health
	# Keep the runtime crouch size local to this player instance.
	body_collision.shape = body_collision.shape.duplicate()
	var capsule := body_collision.shape as CapsuleShape3D
	_standing_capsule_height = capsule.height
	_standing_collision_y = body_collision.position.y
	_standing_head_y = head.position.y
	flashlight.visible = false
	flashlight_status_label.text = "Lanterna desligada"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_node("/root/ControllerSupport").device_changed.connect(_refresh_controls)
	_refresh_controls(false)
	clear_ui_input()

func _refresh_controls(_gamepad: bool) -> void:
	if not _gamepad:
		_crouch_toggled = false
		_sprint_toggled = false
	$Hud.refresh_controls(false)

func _update_gamepad_look(delta: float) -> void:
	if controls_locked:
		return
	var stick := Input.get_vector("look_left","look_right","look_up","look_down")
	if stick.is_zero_approx(): return
	stick = stick.normalized()*pow(stick.length(),gamepad_look_curve)
	rotate_y(-stick.x*deg_to_rad(gamepad_look_speed.x)*delta)
	camera.rotation.x = clampf(camera.rotation.x-stick.y*deg_to_rad(gamepad_look_speed.y)*delta*(-1.0 if gamepad_invert_y else 1.0),-MAX_PITCH,MAX_PITCH)

func clear_ui_input() -> void:
	_suppress_jump_until_release = Input.is_action_pressed("jump")
	_jump_requested = false
	_sprint_toggled = false
	inventory._use_trigger_held = Input.is_action_pressed("use_item")

func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return

	_time_since_damage = 0.0
	health = maxf(0.0, health - amount)
	health_bar.value = health
	if health <= 0.0:
		var active_scene := get_tree().current_scene
		if active_scene != null and active_scene.has_method("on_player_death"):
			active_scene.call("on_player_death")
		else:
			get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return
	if event.is_action_pressed("toggle_crouch"):
		_crouch_toggled = not _crouch_toggled
	if event.is_action_pressed("sprint_toggle"):
		_sprint_toggled = not _sprint_toggled
	if event.is_action_pressed("jump") and not event.is_echo() and not _suppress_jump_until_release:
		_jump_requested = true

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -MAX_PITCH, MAX_PITCH)

	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	elif event.is_action_pressed("toggle_flashlight"):
		flashlight.visible = not flashlight.visible
		flashlight_status_label.text = "Lanterna ligada" if flashlight.visible else "Lanterna desligada"
		return

	inventory.handle_input(event)

func _physics_process(delta: float) -> void:
	_update_gamepad_look(delta)
	_update_health_regen(delta)
	var crouching := not controls_locked and (Input.is_action_pressed("crouch") or _crouch_toggled)
	var capsule := body_collision.shape as CapsuleShape3D
	var wants_to_stand := not crouching
	var can_stand := _has_standing_clearance(capsule)
	var target_height := _standing_capsule_height if wants_to_stand and can_stand else crouch_height
	capsule.height = move_toward(capsule.height, target_height, crouch_transition_speed * delta)
	# Keep the capsule's bottom near the floor while its height changes.
	body_collision.position.y = _standing_collision_y + (capsule.height - _standing_capsule_height) * 0.5
	var target_head_y := crouch_head_height if target_height < _standing_capsule_height - 0.01 else _standing_head_y
	head.position.y = move_toward(head.position.y, target_head_y, crouch_transition_speed * delta)

	if not Input.is_action_pressed("jump"):
		_suppress_jump_until_release = false
	var jump_is_held := not controls_locked and not _suppress_jump_until_release and Input.is_action_pressed("jump")
	if jump_is_held and not _jump_was_pressed:
		_jump_requested = true
	_jump_was_pressed = jump_is_held
	var jump_pressed := not controls_locked and not _suppress_jump_until_release and (_jump_requested or Input.is_action_just_pressed("jump"))
	_jump_requested = false
	if is_on_floor():
		if jump_pressed and not crouching:
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	var input_vector := Vector2.ZERO if controls_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving := input_vector.length() > 0.1
	if not moving or crouching or controls_locked or stamina <= 0.0:
		_sprint_toggled = false
	var sprinting := not crouching and moving and (Input.is_action_pressed("sprint") or _sprint_toggled) and stamina > 0.0

	if sprinting:
		stamina = maxf(0.0, stamina - stamina_drain_per_second * delta)
	else:
		stamina = minf(stamina_capacity, stamina + stamina_recovery_per_second * delta)

	var speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
	var move_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var target_velocity := move_direction * speed * input_vector.length()
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	_try_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	_nudge_overlapping_items()
	move_and_slide()
	stamina_bar.value = stamina


func _has_standing_clearance(capsule: CapsuleShape3D) -> bool:
	if capsule.height >= _standing_capsule_height - 0.01:
		return true
	# Check only the space above the crouched player, so floor contact does not
	# prevent standing while a ceiling or beam still safely blocks the camera.
	var clearance := BoxShape3D.new()
	clearance.size = Vector3(capsule.radius * 1.9, _standing_capsule_height - crouch_height, capsule.radius * 1.9)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance
	var clearance_center_y := _standing_collision_y + crouch_height * 0.5
	query.transform = Transform3D(global_basis, global_position + Vector3.UP * clearance_center_y)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _try_step_up(horizontal_motion: Vector3) -> void:
	if not is_on_floor() or horizontal_motion.length_squared() < 0.0001 or max_auto_step_height <= 0.0:
		return
	if not test_move(global_transform, horizontal_motion):
		return

	var step_increment := 0.05
	var step_height := step_increment
	while step_height <= max_auto_step_height + 0.001:
		var lift_motion := Vector3.UP * step_height
		if test_move(global_transform, lift_motion):
			step_height += step_increment
			continue

		var raised_transform := global_transform.translated(lift_motion)
		if test_move(raised_transform, horizontal_motion):
			step_height += step_increment
			continue

		var landing_transform := raised_transform.translated(horizontal_motion)
		var landing_collision := KinematicCollision3D.new()
		var down_distance := step_height + floor_snap_length + 0.05
		if test_move(landing_transform, Vector3.DOWN * down_distance, landing_collision):
			if landing_collision.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
				global_position.y += step_height
				velocity.y = 0.0
				return
		step_height += step_increment


func _nudge_overlapping_items() -> void:
	var movement_direction := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var now := float(Time.get_ticks_msec()) / 1000.0
	for body in item_bump_area.get_overlapping_bodies():
		var item := body as RigidBody3D
		if item == null or not item.is_in_group("world_items"):
			continue

		var item_id := item.get_instance_id()
		var away_direction := item.global_position - global_position
		away_direction.y = 0.0
		if away_direction.length_squared() < 0.001 or movement_direction.length_squared() < 0.001:
			continue
		away_direction = away_direction.normalized()
		if movement_direction.dot(away_direction) < 0.25:
			continue
		if now < float(_item_push_cooldowns.get(item_id, 0.0)):
			continue

		item.sleeping = false
		item.apply_central_impulse(away_direction * item_push_impulse)
		_item_push_cooldowns[item_id] = now + 0.2


func _update_health_regen(delta: float) -> void:
	if health <= 0.0:
		return
	var previous := _time_since_damage
	_time_since_damage += delta
	var healing_time := maxf(0.0, _time_since_damage - health_regen_delay) - maxf(0.0, previous - health_regen_delay)
	if healing_time > 0.0 and health < max_health:
		health = minf(max_health, health + maxf(0.0, health_regen_per_second) * healing_time)
		health_bar.value = health
