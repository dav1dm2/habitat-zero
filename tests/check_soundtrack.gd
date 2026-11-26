extends Node

var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	if name == &"SoundtrackTest":
		var runner := Node.new()
		runner.set_script(get_script())
		get_tree().root.add_child.call_deferred(runner)
		runner.run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
	print("AUDIO ", "OK " if condition else "FAIL ", description)

func wait_until(condition: Callable, seconds: float = 2.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.025).timeout
	return bool(condition.call())

func run() -> void:
	var tree := get_tree()
	var audio := get_node("/root/Soundtrack")
	var progress := get_node("/root/ReserveState")
	var session := get_node("/root/DemoSession")
	var flow := get_node("/root/DreamFlow")
	var config: Resource = audio.settings
	var player: AudioStreamPlayer = audio.get_node("Music")
	var doors: AudioStreamPlayer = audio.get_node("Doors")
	var delay: Timer = audio.get_node("MusicDelay")

	check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("Effects") > 0, "Canais separados para música e efeitos")
	var streams: Array = config.menu_tracks + config.blackout_tracks + config.powered_tracks
	streams.append_array([config.dream_first, config.dream_second, config.ending_track, config.door_opening])
	check(streams.size() == 10 and streams.all(func(stream): return stream != null and stream.get_length() > 0.0), "Dez áudios originais carregados")

	tree.change_scene_to_file(session.MENU)
	await tree.scene_changed
	await tree.process_frame
	check(player.playing and player.stream in config.menu_tracks, "Menu começa a tocar imediatamente")
	var first := player.stream
	if first != null:
		player.seek(maxf(0.0, first.get_length() - 0.15))
	check(await wait_until(func(): return player.playing and player.stream != first and player.stream in config.menu_tracks), "Fim natural da primeira faixa troca para a outra")
	var starters := {}
	seed(59271)
	for trial in range(24):
		audio._stop_all()
		audio._sync()
		starters[player.stream] = true
	check(starters.size() == 2, "As duas faixas podem abrir o menu")

	await session.start_new_game(false)
	check(not player.playing and not delay.is_stopped() and delay.wait_time == 20.0, "Novo jogo espera 20 s de blecaute")
	delay.start(0.2)
	tree.paused = true
	var before_pause := delay.time_left
	await tree.create_timer(0.3).timeout
	check(is_equal_approx(delay.time_left, before_pause) and not player.playing, "Pausa congela espera")
	tree.paused = false
	check(await wait_until(func(): return player.playing and player.stream in config.blackout_tracks), "Blecaute começa no exterior")
	var blackout := player.stream

	var room := tree.current_scene
	room.get_node("DoorToInterior").interact(room.get_node("Player"))
	check(await wait_until(func(): return doors.playing and doors.stream == config.door_opening), "Uma travessia real toca o WAV de porta")
	await wait_until(func(): return session.is_campaign(tree.current_scene) and tree.current_scene.scene_file_path == session.INTERIOR)
	await wait_until(func(): return not tree.current_scene.get_node("Player").controls_locked)
	check(player.playing and player.stream == blackout and delay.is_stopped(), "A porta preserva a faixa e o relógio")
	check(await wait_until(func(): return not doors.playing, 3.0), "O efeito de porta termina sem repetir")

	var panel := tree.current_scene.get_node("PowerPanel")
	progress.fuse_installed = true
	panel.interaction_delay = 0
	for index in panel.breaker_order:
		panel.press_breaker(index)
		await tree.process_frame
	check(progress.power_restored and not player.playing and delay.wait_time == 20.0 and not delay.is_stopped(), "Restauração real do painel interrompe blecaute e inicia 20 s")
	delay.start(0.15)
	check(await wait_until(func(): return player.playing and player.stream in config.powered_tracks), "Toca música regular depois da espera")
	var regular := player.stream
	progress.begin_day(2)
	check(player.playing and player.stream == regular and delay.is_stopped(), "Faixa regular continua no Dia 2")
	progress.begin_dream()
	check(player.playing and player.stream == config.dream_first, "Sonho começa com primeira faixa imediatamente")
	player.seek(config.dream_first.get_length() - 0.15)
	check(await wait_until(func(): return not player.playing and not delay.is_stopped() and delay.wait_time == 15.0), "Fim natural da primeira faixa inicia 15 s de silêncio")
	delay.start(0.2)
	check(not player.playing, "Segunda faixa ainda não toca durante a espera")
	check(await wait_until(func(): return player.playing and player.stream == config.dream_second), "Segunda faixa toca depois da espera")

	progress.demo_finished = true
	flow._phase("finished")
	check(player.playing and player.stream == config.ending_track and delay.is_stopped(), "Fim do ritual troca imediatamente para faixa final")
	player.seek(config.ending_track.get_length() - 0.15)
	check(await wait_until(func(): return not player.playing and delay.is_stopped()), "Faixa final toca uma vez")
	await session.return_to_menu()
	check(player.playing and player.stream in config.menu_tracks, "Voltar ao menu troca de trilha")
	await session.start_new_game(false)
	var p := tree.current_scene.get_node("Player")
	session.restart_day()
	await tree.scene_changed
	await tree.process_frame
	check(not is_instance_valid(p) and not player.playing and delay.wait_time == 20.0 and delay.time_left > 19.0, "Morte reinicia o relógio do blecaute")
	delay.start(0.2)
	await tree.create_timer(0.05).timeout
	progress.power_restored = true
	progress.changed.emit()
	await tree.create_timer(0.25).timeout
	check(not player.playing and delay.wait_time == 20.0 and delay.time_left > 19.0, "Energia antecipada cancela o temporizador de blecaute")
	await session.return_to_menu()
	tree.paused = true
	audio.quit_game(0 if failures.is_empty() else 1)
	check(not player.playing and delay.is_stopped(), "Sair encerra a música mesmo com jogo pausado")
	if not failures.is_empty():
		tree.quit(1)
	print("AUDIO_RESULT %d/%d %s" % [checks - failures.size(), checks, failures])
