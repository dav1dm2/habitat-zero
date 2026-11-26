@tool
extends AnimatedSprite3D
## Presentation follows the existing animal controller. It never changes its state or motion.

const FRAMES_96: SpriteFrames = preload("res://assets/characters/deer/deer_96.tres")
const FRAMES_128: SpriteFrames = preload("res://assets/characters/deer/deer_128.tres")
const FRAME_WORLD_SIZE := 1.25
## The hoof baseline sits at 7/8 of the atlas cell, or 3/8 below its center.
const HOOF_OFFSET_FROM_CENTER := 0.375
const MOVEMENT_THRESHOLD := 0.12

@export_range(0.5, 2.0, 0.05) var visual_scale := 1.3:
	set(value):
		visual_scale = value
		_apply_art_scale()

@onready var animal: CharacterBody3D = get_parent()

func _ready() -> void:
	_apply_art_scale()
	if Engine.is_editor_hint():
		preview_pose(false)
		return
	shaded = true
	_process(0.0)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var motion := animal.get_real_velocity()
	var speed := Vector2(motion.x, motion.z).length()
	var pose := &"neutro"
	var cadence := 1.0
	match animal.get("state"):
		"comendo":
			pose = &"pastoreio"
		"atenção":
			pose = &"alerta"
		"observando":
			pose = &"observando"
		"andando", "retornando":
			if speed > MOVEMENT_THRESHOLD:
				pose = &"passo"
				cadence = clampf(speed / float(animal.get("walk_speed")), 0.35, 1.5)
		"fugindo":
			pose = &"fuga"
			cadence = 0.0 if speed <= MOVEMENT_THRESHOLD else clampf(speed / float(animal.get("run_speed")), 0.35, 1.5)
		"ritual_wait":
			pose = &"ritual_espera"
		"ritual_approach":
			pose = &"ritual_espera"
			if speed > MOVEMENT_THRESHOLD:
				pose = &"ritual_passo"
				cadence = clampf(speed / float(animal.get("event_speed")), 0.35, 1.5)
	speed_scale = cadence
	if animation != pose:
		play(pose)

func preview_pose(bright: bool) -> void:
	var event_state: String = get_parent().get("event_state")
	animation = &"neutro" if event_state == "normal" else &"ritual_espera"
	frame = 0
	shaded = not bright

func set_art_resolution(resolution: int) -> void:
	var next_frames := FRAMES_128 if resolution == 128 else FRAMES_96
	if sprite_frames == next_frames:
		return
	var current_animation := animation
	var current_frame := frame
	var current_progress := frame_progress
	var playing := is_playing()
	sprite_frames = next_frames
	_apply_art_scale()
	animation = current_animation
	if playing:
		play()
	set_frame_and_progress(current_frame, current_progress)

func _apply_art_scale() -> void:
	var world_size := FRAME_WORLD_SIZE * visual_scale
	var resolution := 128.0 if sprite_frames == FRAMES_128 else 96.0
	pixel_size = world_size / resolution
	position.y = world_size * HOOF_OFFSET_FROM_CENTER
