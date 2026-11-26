extends CanvasLayer

const Style = preload("res://scripts/ui/field_style.gd")

@onready var progress := get_node("/root/ReserveState")
@onready var support := get_node("/root/ControllerSupport")

func _ready() -> void:
	var glass := Color(0.054, 0.105, 0.114, 0.93)
	$StaminaPanel.add_theme_stylebox_override("panel", Style.plate(glass, Style.LINE, 9))
	for caption in [$StaminaPanel/VBoxContainer/HealthLabel, $StaminaPanel/VBoxContainer/StaminaLabel]:
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Style.TEXT)
	_meter($StaminaPanel/VBoxContainer/HealthBar, Color("d28678"))
	_meter($StaminaPanel/VBoxContainer/StaminaBar, Style.SIGNAL)
	for field in [$Location, $Instructions, $FlashlightStatus]:
		field.add_theme_font_size_override("font_size", 15)
		field.add_theme_color_override("font_color", Style.TEXT)
		field.add_theme_stylebox_override("normal", Style.plate(glass, Style.LINE, 7))
	$Location.add_theme_color_override("font_color", Style.WARM)
	$Instructions.add_theme_color_override("font_color", Style.MUTED)
	var overlay := Color(0.095, 0.095, 0.095, 0.72)
	var edge := Color(0.68, 0.68, 0.68, 0.20)
	for field in [$InventoryStatus, $InteractionHint]:
		field.add_theme_font_size_override("font_size", 14)
		field.add_theme_color_override("font_color", Color("d3d3d3"))
		field.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.55))
		field.add_theme_constant_override("outline_size", 2)
		field.add_theme_stylebox_override("normal", Style.plate(overlay, Color.TRANSPARENT, 6, 0))
	$InteractionArrow.add_theme_color_override("font_color", Color("c4c4c4"))
	$InteractionArrow.add_theme_constant_override("outline_size", 4)
	$InventoryPanel.add_theme_stylebox_override("panel", Style.plate(Color(0.10, 0.10, 0.10, 0.61), edge, 0))
	progress.changed.connect(_refresh_location)
	support.device_changed.connect(refresh_controls)
	get_viewport().size_changed.connect(_layout_vitals)
	_refresh_location.call_deferred()
	refresh_controls(false)
	_layout_vitals()

func _meter(bar: ProgressBar, color: Color) -> void:
	bar.custom_minimum_size.y = 5
	bar.add_theme_stylebox_override("background", Style.plate(Color("293c3f"), Color.TRANSPARENT, 0, 0))
	bar.add_theme_stylebox_override("fill", Style.plate(color, Color.TRANSPARENT, 0, 0))

func _refresh_location() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var area := "ATTIS"
	match scene.scene_file_path.get_file():
		"attis_forest.tscn":
			area = "FLORESTA DE ATTIS"
		"attis_interior.tscn":
			area = "POSTO ATTIS"
		"habitat_1.tscn":
			area = "HABITAT DAS AVES"
	$Location.text = "%s   /   DIA %02d" % [area, progress.day]

func refresh_controls(_gamepad: bool) -> void:
	$Instructions.text = "VIEW  Caderno   /   MENU  Pausa" if support.using_gamepad else "TAB  Caderno   /   ESC  Pausa"

func _layout_vitals() -> void:
	# Stack the meters over the slots when the two groups no longer fit side by side.
	var narrow := get_viewport().get_visible_rect().size.x < 950.0
	$StaminaPanel.offset_top = -178 if narrow else -98
	$StaminaPanel.offset_bottom = -102 if narrow else -22
