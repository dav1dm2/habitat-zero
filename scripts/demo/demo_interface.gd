extends CanvasLayer
## Interfaces curtas da fatia jogável. O mundo continua durante o puzzle.
const BUZZY_FRAMES: SpriteFrames = preload("res://assets/characters/buzzy/buzzy_frames.tres")
const Style = preload("res://scripts/ui/field_style.gd")
const LETTER := "Pesquisador,\n\nDeixamos Attis por último na sua rota. Agora gostaríamos de tê-la posto em primeiro lugar. O último contato, há dois dias, informou que a alimentação principal falhou e que não havia peças para o reparo. A reserva de energia duraria três dias, na melhor das hipóteses. Se acabar, podemos perder os espécimes.\n\nO fusível de reposição está com você. Entre no posto, procure a sala de máquinas e restabeleça a energia. Evite as áreas sinalizadas. O rádio local também perdeu a alimentação. Com o posto funcionando, procure a assistência da estação. Ela tem as tarefas de pesquisa."
var window: PanelContainer
var dim: ColorRect
var scroll: ScrollContainer
var modal: Control
var content: VBoxContainer
var footer: HBoxContainer
var notice: Label
var modal_kind := ""
var active_panel: Node
var _notice_time := 0.0

func _ready() -> void:
	layer = 30
	get_node("/root/ReserveState").changed.connect(_on_buzzy_power_changed)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	notice = Label.new()
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_color", Color("dedede"))
	notice.add_theme_stylebox_override("normal", Style.plate(Color(0.095, 0.095, 0.095, 0.77), Color(1, 1, 1, 0.15), 8))
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice.anchor_left = 0.22
	notice.anchor_right = 0.78
	notice.offset_top = -147
	notice.offset_bottom = -111
	root.add_child(notice)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	dim = ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.025, 0.91)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	window = PanelContainer.new()
	var panel := window
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	modal.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	stack.add_child(footer)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	modal.hide()
	preload("res://scripts/ui/menu_style.gd").apply(modal)
	get_tree().scene_changed.connect(close_modal)

func _process(delta: float) -> void:
	_notice_time = maxf(0.0, _notice_time - delta)
	notice.visible = _notice_time > 0
	if modal.visible and modal_kind == "power" and not is_instance_valid(active_panel):
		close_modal()

func _input(event: InputEvent) -> void:
	var flow := get_node("/root/DreamFlow")
	if flow.phase == "finished":
		return # Hand keyboard and gamepad events to the epilogue controls.
	if get_node("/root/DemoSession").sleeping or flow.input_locked:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	if not get_node("/root/DemoSession").is_campaign(get_tree().current_scene):
		return
	if event.is_action_pressed("notebook") and not event.is_echo():
		if modal.visible and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP:
			return # In an open interface, D-pad Up navigates rather than closing it.
		if modal.visible: close_modal()
		else: show_notebook()
		get_viewport().set_input_as_handled()
	elif modal.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game")):
		close_modal()
		get_viewport().set_input_as_handled()

func _player() -> Node:
	var room := get_tree().current_scene
	return room.get_node_or_null("Player") if room != null else null

func _begin(kind: String, title: String) -> void:
	for region in [content, footer]:
		for child in region.get_children():
			region.remove_child(child)
			child.queue_free()
	footer.visible = kind in ["letter", "dream_letter", "buzzy"]
	modal_kind = kind
	_style_window(kind)
	scroll.scroll_vertical = 0
	modal.show()
	var player := _player()
	if player != null:
		player.controls_locked = true
		player.velocity.x = 0
		player.velocity.z = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not title.is_empty():
		_text(title, 30, _title_color())

func _style_window(kind: String) -> void:
	var width := get_viewport().get_visible_rect().size.x
	var sides := 0.08 if width < 850.0 else 0.16
	window.anchor_left = sides
	window.anchor_right = 1.0 - sides
	window.anchor_top = 0.14 if kind == "buzzy" else 0.075
	window.anchor_bottom = 0.94
	if kind == "dream_letter":
		window.anchor_top = 0.17
		window.anchor_bottom = 0.84
	var fill := Style.PANEL
	var edge := Style.LINE
	dim.color = Color(0.018, 0.031, 0.035, 0.68)
	match kind:
		"buzzy":
			fill = Color("102327")
			edge = Color("58a5a1")
			dim.color.a = 0.46
		"letter":
			fill = Style.PAPER
			edge = Color("af8f58")
		"dream_letter":
			fill = Color("20191b")
			edge = Color("79514e")
	window.add_theme_stylebox_override("panel", Style.plate(fill, edge, 3, 2))

func _title_color() -> Color:
	match modal_kind:
		"letter": return Color("382b20")
		"dream_letter": return Color("e9c4a5")
	return Style.SIGNAL

func _text(words: String, size: int = 18, color: Color = Color.TRANSPARENT) -> Label:
	var label := Label.new()
	label.set_meta("input_text",words)
	label.text = get_node("/root/ControllerSupport").adapt_text(words)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("line_spacing", 5)
	var ink := Color("382b20") if modal_kind == "letter" else Style.TEXT
	label.add_theme_color_override("font_color", ink if color == Color.TRANSPARENT else color)
	content.add_child(label)
	return label

func _button(words: String, action: Callable) -> Button:
	var button := Button.new()
	button.set_meta("input_text",words)
	button.text = get_node("/root/ControllerSupport").adapt_text(words)
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	var target: Container = footer if footer.visible else content
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.add_child(button)
	if action_buttons().size() == 1:
		_focus_button.call_deferred(button)
	return button

func action_buttons() -> Array[Node]:
	return (content.get_children() + footer.get_children()).filter(func(node): return node is Button)

func _focus_button(button: Variant) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree() and modal.visible:
		button.grab_focus()

func close_modal() -> void:
	if modal == null:
		return
	modal.hide()
	active_panel = null
	modal_kind = ""
	var player := _player()
	if player != null:
		player.clear_ui_input()
		player.controls_locked = get_node("/root/DemoSession").sleeping or get_node("/root/DreamFlow").input_locked
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_status(words: String) -> void:
	notice.set_meta("input_text",words)
	notice.text = get_node("/root/ControllerSupport").adapt_text(words)
	_notice_time = 7.0
	notice.show()

func show_letter() -> void:
	var progress := get_node("/root/ReserveState")
	progress.letter_read = true
	progress.changed.emit()
	_begin("letter", "")
	_text("COMANDO DE RESERVAS   /   CYTHERIA", 14, Color("65492f"))
	_text("Ordem de serviço · Posto Attis", 30, _title_color())
	content.add_child(HSeparator.new())
	_text(LETTER, 17)
	_text("Comando de Reservas", 16, Color("65492f"))
	content.add_child(HSeparator.new())
	_text("Cópia arquivada no caderno. Solte a carta com Q para liberar o slot.", 14, Color("65492f"))
	_button("Fechar carta", close_modal)

func show_notebook() -> void:
	if get_node("/root/DreamFlow").input_locked or get_node("/root/DemoSession").sleeping:
		return
	var progress := get_node("/root/ReserveState")
	_begin("notebook", "Caderno / Dia %d" % progress.day)
	if progress.is_dream:
		_text("□ Investigar a floresta",24)
		_button("Consultar bilhete",show_dream_letter)
		_button("Voltar / Tab",close_modal)
		return
	_text("%s Restaurar a energia\n%s Conversar com Buzzy" % [_mark(progress.power_restored), _mark(progress.briefing_heard)])
	if progress.briefing_heard:
		var count := 0
		for id in progress.fertilized_ids:
			if id >= 1000 and id < 1010:
				count += 1
		var target := 10 if progress.day >= 2 else 5
		_text("%s Adubar os arbustos de Attis (%d/%d)" % [_mark(count >= target), count, target])
		_text("Almoxarifado: E recolhe adubo. Equipe o adubo e use M1 em um arbusto com estaca amarela. No Dia 1 o trabalho é manual.", 16)
		if progress.day >= 2:
			_text("%s Ouvir instruções de automação de Buzzy\n%s Ativar robô ajudante" % [_mark(progress.day2_briefing_heard), _mark(progress.robot_activated)])
			_text("Novos arbustos: cinco em Attis para adubação e três no H1 para amostras. O ajudante pode adubar, coletar nas duas áreas e entregar no laboratório; você pode cuidar da outra área enquanto ele trabalha.", 16)
		var delivered: bool = "attis" in progress.analysed_samples
		_text("%s Coletar e entregar amostras de Attis (%d/3)" % [_mark(delivered), 3 if delivered else _sample_count("attis")])
		_text("Laboratório: há dois coletores na bancada auxiliar. E recolhe, cada ferramenta ocupa um slot. Equipe uma e use M1 em quaisquer três arbustos distintos da área. Cada arbusto fornece uma amostra por dia, compartilhada entre os coletores e o robô. Volte com um coletor cheio e pressione E na bancada para entregar; ele retorna a 0/3.", 16)
		var habitat_delivered: bool = "habitat1" in progress.analysed_samples
		_text("%s Coletar e entregar amostras do Habitat 1 (%d/3)" % [_mark(habitat_delivered), 3 if habitat_delivered else _sample_count("habitat1")])
		_text("Entre pela porta H1 do corredor. Use um coletor vazio em três arbustos do habitat; não misture origens. Observe as aves, evite o ninho ocupado e recue para a plataforma se necessário.", 16)
		if delivered and habitat_delivered and count >= target and (progress.day == 1 or progress.robot_activated):
			_text("Objetivos disponíveis concluídos.", 20)
			_text("Dia 1: você já pode descansar no alojamento." if progress.day == 1 else "Você já pode descansar no alojamento.", 16)
	else:
		_text("Localize a sala de máquinas nas instalações. Equipe o fusível e use M1 no painel. Observe o aviso de radiação.")
	if progress.letter_read:
		_button("Consultar carta arquivada", show_letter)
	_button("Voltar / Tab", close_modal)

func _mark(done: bool) -> String:
	return "✓" if done else "□"

func show_power(panel: Node) -> void:
	active_panel = panel
	_begin("power", "Painel de alimentação / reinicialização")
	active_panel = panel
	var progress := get_node("/root/ReserveState")
	var names: Array[String] = []
	for index in panel.breaker_order:
		names.append(["A", "B", "C"][index])
	_text("DIAGRAMA DE PARTIDA:  " + " → ".join(names), 24)
	_text("Fusível instalado. Acione os disjuntores na ordem do diagrama.\nA radiação continua enquanto o painel está aberto. Esc fecha o painel.", 17)
	_text("Etapas confirmadas: %d/%d" % [progress.breaker_progress, panel.breaker_order.size()])
	for index in range(3):
		_button("Disjuntor " + ["A", "B", "C"][index] + "  /  ACIONAR", func():
			if is_instance_valid(panel):
				panel.press_breaker(index)
		)
	_button("Recuar do painel / Esc", close_modal)

func show_buzzy() -> void:
	var progress := get_node("/root/ReserveState")
	if not progress.power_restored or progress.is_dream:
		return
	_begin("buzzy", "")
	if progress.day >= 2 and not progress.day2_briefing_heard:
		_buzzy_greeting("Bom dia! As amostras de ontem já estão no arquivo. Eu chequei duas vezes. A noite é comprida quando a gente não dorme.")
		_text("Tem cinco arbustos novos para adubar em Attis e três plantas novas no Habitat 1. Precisamos de mais três amostras de cada área.")
		_text("Agora você pode ativar o robô com E na estação de carregamento. Ele aplica adubo, coleta e leva as amostras ao laboratório. Seus coletores continuam livres. Se quiser, você pode cuidar de uma área enquanto ele trabalha na outra.")
		_button("Entendido · dividir o trabalho", func():
			progress.day2_briefing_heard = true
			progress.changed.emit()
			close_modal()
			show_status("Automação disponível. Ative o robô com E na estação de carregamento.")
		)
	elif not progress.briefing_heard:
		_buzzy_greeting("Ah, é você que trouxe a luz! Eu ensaiei um ‘bem-vindo’ bem melhor. Mas eu disse tantas vezes para o corredor que perdeu a graça.")
		_text("O robô está indisponível e hoje as tarefas são manuais. Passe no almoxarifado: o adubo é para os cinco arbustos de estaca amarela em Attis.")
		_text("Deixei dois coletores reutilizáveis no laboratório. Leve um vazio para cada área: Attis e o Habitat 1, pela porta H1. Use M1 em três arbustos diferentes de cada área e entregue cada coletor cheio com E na bancada. Assim eu sei de onde veio cada amostra.")
		_button("Entendido · registrar a missão", func():
			progress.briefing_heard = true
			progress.changed.emit()
			close_modal()
			show_status("Briefing registrado. Consulte o caderno com Tab.")
		)
	else:
		_buzzy_greeting("Oi de novo! Se veio conferir o que falta, eu tenho o caderno aberto. Escolhi uma página que ainda aceita boas notícias.")
		if progress.day == 1:
			_text("O ajudante fica na base e hoje as tarefas são manuais. O adubo está no almoxarifado, e as estacas amarelas marcam onde aplicar.")
		else:
			_text("A estação de carregamento já aceita o comando: E no robô. Ele cuida da adubação e da coleta e leva as amostras ao laboratório.")
		_text("Um coletor vazio por área: Attis e Habitat 1, pela porta H1. Três arbustos distintos de cada lugar. Quando um coletor encher, entregue com E na bancada. O caderno mostra o que já entrou.")
		_button("Consultar tarefas", show_notebook)
		_button("Encerrar conversa", close_modal)

func _buzzy_greeting(words: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	var monitor := PanelContainer.new()
	monitor.custom_minimum_size = Vector2(120, 94)
	monitor.add_theme_stylebox_override("panel", Style.plate(Color("0a1c20"), Color("356c70"), 0))
	row.add_child(monitor)
	var portrait := AnimatedSprite2D.new()
	portrait.sprite_frames = BUZZY_FRAMES
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(60, 45)
	portrait.scale = Vector2.ONE * 1.04
	monitor.add_child(portrait)
	portrait.play(&"dialogue")
	var channel := VBoxContainer.new()
	channel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channel.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(channel)
	channel.add_child(Style.label("ASSISTÊNCIA LOCAL  /  CANAL ATIVO", 13, Style.SIGNAL))
	channel.add_child(Style.label("Buzzy", 29))
	_text(words, 21, Style.SIGNAL)
	content.add_child(HSeparator.new())

func _on_buzzy_power_changed() -> void:
	if modal_kind == "buzzy" and not get_node("/root/ReserveState").power_restored:
		close_modal()

func show_storage() -> void:
	var player := _player()
	if player == null:
		return
	var inventory: Node = player.get_node("Inventory")
	var session := get_node("/root/DemoSession")
	_begin("storage", "Depósito pessoal")
	_text("Guardar itens libera espaço nos quatro slots. O depósito mantém seu conteúdo entre visitas.", 17)
	for index in range(4):
		var item: Resource = inventory.slots[index]
		if item != null:
			_button("Guardar: " + item.inventory_name(), func():
				session.storage.append(inventory.slots[index])
				inventory.set_slot_item(index, null)
				show_storage()
			)
	for index in range(session.storage.size()):
		_button("Recolher: " + session.storage[index].inventory_name(), func():
			var empty: int = inventory._find_empty_slot()
			if empty >= 0:
				inventory.set_slot_item(empty, session.storage[index])
				session.storage.remove_at(index)
				show_storage()
			else:
				show_status("Inventário cheio.")
		)
	_button("Fechar depósito", close_modal)

func tone(frequency: float = 660.0) -> void:
	var bytes := PackedByteArray()
	var samples := 5512
	bytes.resize(samples)
	for i in range(samples):
		bytes[i] = int(128 + 35 * sin(TAU * frequency * i / 22050.0) * (1.0 - float(i) / samples))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.bus = &"Effects"
	audio.volume_db = -5
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func _sample_count(origin: String) -> int:
	# Count the fullest collector, never sum two partially filled tools.
	var count := 0
	var tools: Array = get_node("/root/DemoSession").storage.duplicate()
	var player := _player()
	if player != null:
		tools.append_array(player.get_node("Inventory").slots)
	for room_key in get_node("/root/DemoSession").room_items:
		if get_tree().current_scene != null and room_key == get_tree().current_scene.scene_file_path:
			continue
		for entry in get_node("/root/DemoSession").room_items[room_key]:
			tools.append(entry.definition)
	for item in get_tree().get_nodes_in_group("world_items"):
		tools.append(item.definition)
	var sim := get_node("/root/ReserveSimulation")
	if is_instance_valid(sim.robot):
		tools.append_array(sim.robot.sample_collectors.values())
	var day: int = get_node("/root/ReserveState").day
	for tool in tools:
		if tool != null and tool.item_id == &"sample_collector" and tool.sample_origin == origin and tool.sample_day in [0, day]:
			count = maxi(count, tool.sample_ids.size())
	return count

func show_dream_letter() -> void:
	var progress := get_node("/root/ReserveState")
	progress.dream_letter_read = true
	_begin("dream_letter","Bilhete manchado")
	var letter := Control.new()
	letter.set_script(load("res://scripts/demo/dream_letter_view.gd"))
	content.add_child(letter)
	_button("Guardar leitura",close_modal)
