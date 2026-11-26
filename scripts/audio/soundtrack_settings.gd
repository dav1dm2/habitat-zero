extends Resource
## Configuração editável em resources/audio/soundtrack.tres.

@export_group("Menu principal")
@export var menu_tracks: Array[AudioStream] = []

@export_group("Dia 1 — blecaute")
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:s") var blackout_delay := 20.0
@export var blackout_tracks: Array[AudioStream] = []

@export_group("Energia restaurada")
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:s") var powered_delay := 20.0
@export var powered_tracks: Array[AudioStream] = []

@export_group("Sonho e desfecho")
@export var dream_first: AudioStream
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:s") var dream_gap := 15.0
@export var dream_second: AudioStream
@export var ending_track: AudioStream

@export_group("Efeitos")
@export var door_opening: AudioStream
