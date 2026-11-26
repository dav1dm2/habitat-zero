extends AnimatedSprite3D

@onready var robot := get_parent() as CharacterBody3D

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var movement := robot.get_real_velocity()
	var ground_speed := Vector2(movement.x, movement.z).length()
	var pose := &"idle"
	var rate := 1.0
	match robot.state:
		"adormecido":
			pose = &"off"
		"escaneando":
			pose = &"scan"
		"fertilizando":
			pose = &"fertilize"
		"coletando amostras":
			pose = &"sample"
		"entregando amostras":
			pose = &"deliver"
		_:
			if ground_speed > 0.12:
				pose = &"drive"
				rate = clampf(ground_speed / robot.walk_speed, 0.35, 1.6)
	var camera := get_viewport().get_camera_3d()
	if camera != null and pose not in [&"off", &"idle"]:
		var direction: Vector3 = robot.visual_facing_hint()
		direction.y = 0.0
		var sideways := direction.dot(camera.global_basis.x)
		if absf(sideways) > 0.12:
			flip_h = sideways < 0.0
	speed_scale = rate
	if animation != pose:
		play(pose)
