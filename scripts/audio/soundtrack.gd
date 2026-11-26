extends Node

enum Phase { SILENT, MENU, BLACKOUT, POWERED, DREAM, ENDING }

const Settings = preload("res://scripts/audio/soundtrack_settings.gd")
var _phase := Phase.SILENT
var _playlist: Array[AudioStream] = []
var _track_index := 0
var _playing_dream_first := false
var _quitting := false
var _music := AudioStreamPlayer.new()
var _doors := AudioStreamPlayer.new()
var _delay := Timer.new()
@onready var settings := load("res://resources/audio/soundtrack.tres") as Settings
@onready var _progress := get_node("/root/ReserveState")
@onready var _session := get_node("/root/DemoSession")


func _ready() -> void:
	_music.name = "Music"
	_music.bus = &"Music"
	add_child(_music)
	_music.finished.connect(_music_finished)
	_doors.name = "Doors"
	_doors.bus = &"Effects"
	_doors.max_polyphony = 2
	add_child(_doors)
	_delay.name = "MusicDelay"
	_delay.one_shot = true
	add_child(_delay)
	_delay.timeout.connect(_play_pending_music)

	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(quit_game)
	get_tree().scene_changed.connect(_sync)
	_progress.changed.connect(_sync)
	_session.day_restarting.connect(_stop_all)
	get_node("/root/DreamFlow").phase_changed.connect(_dream_phase_changed)
	_sync.call_deferred()


func _exit_tree() -> void:
	_stop_all()
	_doors.stream = null


func quit_game(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	_stop_all()
	# Let the audio mixer release the stopped playback before Godot shuts down.
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(exit_code)


func play_door() -> void:
	if _quitting or settings.door_opening == null:
		return
	if _doors.stream != settings.door_opening:
		_doors.stream = settings.door_opening
	_doors.play()


func _dream_phase_changed(value: String) -> void:
	if value == "finished":
		_sync()


func _stop_all() -> void:
	_set_phase(Phase.SILENT)
	_doors.stop()


func _sync() -> void:
	if _quitting:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.scene_file_path == _session.MENU:
		_set_phase(Phase.MENU)
	elif not _session.is_campaign(scene):
		_set_phase(Phase.SILENT)
	elif _progress.demo_finished:
		_set_phase(Phase.ENDING)
	elif _progress.is_dream:
		_set_phase(Phase.DREAM)
	elif _progress.power_restored:
		_set_phase(Phase.POWERED)
	elif _progress.day == 1:
		_set_phase(Phase.BLACKOUT)
	else:
		_set_phase(Phase.SILENT)


func _set_phase(value: Phase) -> void:
	if _phase == value:
		return
	_phase = value
	_delay.stop()
	_music.stop()
	_music.stream = null
	_playlist.clear()
	_track_index = 0
	_playing_dream_first = false

	match _phase:
		Phase.MENU:
			_start_playlist(settings.menu_tracks, 0.0)
		Phase.BLACKOUT:
			_start_playlist(settings.blackout_tracks, settings.blackout_delay)
		Phase.POWERED:
			_start_playlist(settings.powered_tracks, settings.powered_delay)
		Phase.DREAM:
			_playing_dream_first = settings.dream_first != null
			_play(settings.dream_first if _playing_dream_first else settings.dream_second)
		Phase.ENDING:
			_play(settings.ending_track)


func _start_playlist(tracks: Array[AudioStream], delay: float) -> void:
	for track in tracks:
		if track != null:
			_playlist.append(track)
	if _playlist.is_empty():
		return
	_playlist.shuffle()
	if delay > 0.0:
		_delay.start(delay)
	else:
		_play_pending_music()


func _play_pending_music() -> void:
	if _phase == Phase.DREAM:
		_play(settings.dream_second)
	elif not _playlist.is_empty():
		_play(_playlist[_track_index])


func _play(stream: AudioStream) -> void:
	if stream != null:
		_music.stream = stream
		_music.play()


func _music_finished() -> void:
	if not _playlist.is_empty():
		_track_index = (_track_index + 1) % _playlist.size()
		_play_pending_music()
	elif _phase == Phase.DREAM and _playing_dream_first:
		_playing_dream_first = false
		if settings.dream_second != null and settings.dream_gap > 0.0:
			_delay.start(settings.dream_gap)
		else:
			_play_pending_music()
