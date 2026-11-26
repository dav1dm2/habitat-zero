@tool
extends AnimatedSprite3D
## Reads the animal controller without moving the body or timing its damage.

const FRAME_PIXELS := 128.0
const PAW_OFFSET_FROM_CENTER := 0.25
const MOVEMENT_THRESHOLD := 0.12
const RECOVERY_POSE_SECONDS := 0.24

@export_range(0.25, 3.0, 0.01) var frame_world_size := 1.55:
	set(value):
		frame_world_size = value
		_apply_art_scale()

@export_range(0.5, 2.0, 0.05) var visual_scale := 1.0:
	set(value):
		visual_scale = value
		_apply_art_scale()

@onready var animal: CharacterBody3D = get_parent()
var _recovery_left := 0.0

func _ready() -> void:
	_apply_art_scale()
	preview_pose(false)
	if not Engine.is_editor_hint():
		animal.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_recovery_left = maxf(0.0, _recovery_left - delta)
	var motion := animal.get_real_velocity()
	var speed := Vector2(motion.x, motion.z).length()
	var pose := &"neutro"
	var cadence := 1.0
	match animal.get("state"):
		"comendo":
			pose = &"farejar"
		"atenção", "observando":
			pose = &"alerta"
		"andando", "retornando":
			if speed > MOVEMENT_THRESHOLD:
				pose = &"passo"
				cadence = clampf(speed / float(animal.get("walk_speed")), 0.35, 1.5)
		"fugindo":
			pose = &"fuga"
			cadence = 0.0 if speed <= MOVEMENT_THRESHOLD else clampf(speed / float(animal.get("run_speed")), 0.35, 1.5)
		"cercando":
			pose = &"cerco" if speed > MOVEMENT_THRESHOLD else &"cerco_parado"
			cadence = clampf(speed / float(animal.get("walk_speed")), 0.35, 1.5)
		"perseguindo", "aproximando para ataque":
			pose = &"corrida" if speed > MOVEMENT_THRESHOLD else &"aviso"
			cadence = clampf(speed / float(animal.get("run_speed")), 0.35, 1.5)
		"aviso":
			pose = &"recuo" if _recovery_left > 0.0 else &"aviso"
		"atacando":
			pose = &"bote"
		"recuperando":
			pose = &"recuo"
		"dead":
			pose = _still_pose()
	speed_scale = cadence
	if pose in [&"passo", &"fuga", &"cerco"]:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var sideways := motion.dot(camera.global_basis.x)
			if absf(sideways) > MOVEMENT_THRESHOLD:
				flip_h = sideways > 0.0
	else:
		flip_h = false
	if animation != pose:
		play(pose)

func preview_pose(bright: bool) -> void:
	stop()
	animation = _still_pose()
	frame = 0
	flip_h = false
	shaded = not bright

func _still_pose() -> StringName:
	if get_parent().get("event_state") == "dead" and sprite_frames.has_animation(&"morto"):
		return &"morto"
	return &"neutro"

func _on_state_changed(value: String) -> void:
	if value == "recuperando":
		_recovery_left = RECOVERY_POSE_SECONDS

func _apply_art_scale() -> void:
	var world_size := frame_world_size * visual_scale
	pixel_size = world_size / FRAME_PIXELS
	position.y = world_size * PAW_OFFSET_FROM_CENTER
