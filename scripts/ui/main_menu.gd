extends Node3D
## A presentation-only copy of Attis; no Player, NPC AI or campaign scripts run here.
@export var camera_sway_distance: float = 0.55
@export var camera_sway_speed: float = 0.16
var _time := 0.0
var _busy := false
var _can_continue := false
var _camera_origin: Vector3
@onready var camera: Camera3D = $MenuCamera
@onready var ui: Control = $CanvasLayer/UI
@onready var column: VBoxContainer = $CanvasLayer/UI/Margin/Row/Scroll/Column
@onready var new_button: Button = %NewGame
@onready var continue_button: Button = %Continue
@onready var quit_button: Button = %Quit
@onready var status: Label = %SaveStatus

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_node("/root/ReserveSimulation").clear_simulation()
	preload("res://scripts/ui/menu_style.gd").apply(ui)
	_build_backdrop()
	_camera_origin = camera.position
	camera.look_at($CameraFocus.global_position)
	new_button.pressed.connect(_request_new_game)
	continue_button.pressed.connect(_continue_game)
	quit_button.pressed.connect(get_node("/root/Soundtrack").quit_game)
	%Overwrite.confirmed.connect(_new_game)
	%Overwrite.canceled.connect(func(): new_button.grab_focus())
	_refresh_save()
	get_node("/root/SaveSystem").save_changed.connect(_refresh_save)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	refresh_input_legend()
	if continue_button.disabled: new_button.grab_focus()
	else: continue_button.grab_focus()

func _fit_layout() -> void:
	var width := get_viewport().get_visible_rect().size.x
	$CanvasLayer/UI/Margin/Row/Scroll.custom_minimum_size.x = clampf(width*.36,290,420)
	%Title.add_theme_font_size_override("font_size",int(clampf(width*.045,34,58)))

func _refresh_save() -> void:
	var save := get_node("/root/SaveSystem")
	_can_continue = save.has_checkpoint()
	refresh_actions()
	status.text = save.summary()+"\nO progresso é salvo ao começar cada dia."

func refresh_actions() -> void:
	if not _busy:
		var locked: bool = get_node("/root/DemoSession").sleeping
		new_button.disabled = locked
		continue_button.disabled = locked or not _can_continue

func complete_entry() -> void:
	refresh_actions()
	if not continue_button.disabled: continue_button.grab_focus()
	elif not new_button.disabled: new_button.grab_focus()

func _process(delta: float) -> void:
	refresh_actions()
	_time += delta
	camera.position = _camera_origin + Vector3(sin(_time*camera_sway_speed)*camera_sway_distance,sin(_time*camera_sway_speed*.7)*.12,cos(_time*camera_sway_speed)*.15)
	camera.look_at($CameraFocus.global_position)

func _build_backdrop() -> void:
	var forest := load("res://scenes/levels/attis_forest.tscn").instantiate() as Node3D
	# Clear scripts BEFORE entering the tree; this scene must not prepare campaign state.
	_strip_preview(forest)
	forest.name = "ForestBackdrop"
	add_child(forest)
	var env := forest.get_node("Ambiente_Nevoeiro") as WorldEnvironment
	env.environment = env.environment.duplicate()
	env.environment.fog_depth_begin = 8
	env.environment.fog_depth_end = 55
	env.environment.ambient_light_energy = .75
	forest.get_node("LuzNublada").light_energy = 1.1
	forest.get_node("DreamEvent").hide()
	forest.get_node("Fauna").hide()
	# A saved authoring preview must never reveal event actors in the menu.

func _strip_preview(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		if child is CharacterBody3D or child is RigidBody3D or child is CanvasLayer:
			node.remove_child(child)
			child.free()
			continue
		_strip_preview(child)
	if node is NavigationRegion3D: node.enabled = false
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is Label3D: node.visible = false

func _request_new_game() -> void:
	if _busy or get_node("/root/DemoSession").sleeping: return
	if get_node("/root/SaveSystem").has_checkpoint():
		%Overwrite.popup_centered(Vector2i(450,180))
	else:
		_new_game()

func _set_busy() -> void:
	_busy = true
	new_button.disabled = true
	continue_button.disabled = true
	quit_button.disabled = true
	status.text = "Abrindo a reserva…"

func _new_game() -> void:
	if _busy or get_node("/root/DemoSession").sleeping: return
	_set_busy()
	get_node("/root/DemoSession").start_new_game(true)

func _continue_game() -> void:
	if _busy or get_node("/root/DemoSession").sleeping: return
	_set_busy()
	if not await get_node("/root/DemoSession").continue_game():
		_busy = false
		new_button.disabled = false
		quit_button.disabled = false
		_refresh_save()
		status.text = "O checkpoint não pôde ser aberto. Inicie uma nova partida."

func refresh_input_legend() -> void:
	var controller := get_node("/root/ControllerSupport")
	$CanvasLayer/UI/Margin/Row/Scroll/Column/Keys.text = "LS ou direcional · A confirmar · B voltar" if controller.using_gamepad else "Mouse ou ↑ ↓ / Enter para selecionar"
