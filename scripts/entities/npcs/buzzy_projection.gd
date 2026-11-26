extends AnimatedSprite3D
## The projector follows the reserve power and the active dialogue.

@onready var _reserve := get_node("/root/ReserveState")
@onready var _ui := get_node("/root/DemoInterface")
@onready var _height := position.y
var _elapsed := 0.0
var _until_glitch := 9.0

func _ready() -> void:
	_reserve.changed.connect(_refresh_power)
	_refresh_power()

func _refresh_power() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var powered: bool = _reserve.power_restored and not _reserve.is_dream
	if powered == visible:
		return
	visible = powered
	if powered:
		_elapsed = 0.0
		_until_glitch = 9.0
		play(&"glitch")
	else:
		stop()
		position.y = _height

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	position.y = _height + sin(_elapsed * 2.5) * 0.04
	if animation == &"glitch" and is_playing():
		return
	var wanted := &"dialogue" if _ui.modal_kind == "buzzy" else &"idle"
	if wanted == &"idle":
		_until_glitch -= delta
		if _until_glitch <= 0.0:
			_until_glitch = 9.0
			wanted = &"glitch"
	if animation != wanted:
		play(wanted)
