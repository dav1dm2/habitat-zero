extends Node
## Progressão da reserva em memória. O checkpoint representa o começo do dia.
signal changed

var is_dream: bool = false
var dream_letter_read: bool = false
var demo_finished: bool = false
var day: int = 1
var power_restored: bool = false
var briefing_heard: bool = false
var fertilized_ids: Array[int] = []
var robot_activated: bool = false
var robot_service_done: bool = false
var letter_read: bool = false
var fuse_installed: bool = false
var breaker_progress: int = 0
var day2_briefing_heard: bool = false
var analysis_history: Dictionary = {}
# Stable origin/plant identity -> last successful sampling day, shared by all tools.
var sampled_bush_days: Dictionary = {}
var analysed_samples: Array[String] = []
var _checkpoint: Dictionary = {}

func _ready() -> void:
	checkpoint_day()

func snapshot() -> Dictionary:
	return {"sampled_bush_days":sampled_bush_days.duplicate(), "dream":is_dream,"dream_letter":dream_letter_read,"finished":demo_finished,"day": day, "power": power_restored, "briefing": briefing_heard,
		"fertilized": fertilized_ids.duplicate(), "robot": robot_activated,
		"service": robot_service_done, "letter": letter_read,
		"fuse_installed": fuse_installed, "breakers": breaker_progress, "analyses": analysed_samples.duplicate(), "day2_briefing": day2_briefing_heard, "analysis_history": analysis_history.duplicate(true)}

func restore(data: Dictionary) -> void:
	sampled_bush_days = data.get("sampled_bush_days", {}).duplicate()
	is_dream = bool(data.get("dream",false))
	dream_letter_read = bool(data.get("dream_letter",false))
	demo_finished = bool(data.get("finished",false))
	day = int(data.get("day", 1))
	power_restored = bool(data.get("power", false))
	briefing_heard = bool(data.get("briefing", false))
	fertilized_ids.assign(data.get("fertilized", []))
	robot_activated = bool(data.get("robot", false))
	robot_service_done = bool(data.get("service", false))
	letter_read = bool(data.get("letter", false))
	fuse_installed = bool(data.get("fuse_installed", false))
	breaker_progress = int(data.get("breakers", 0))
	analysed_samples.assign(data.get("analyses", []))
	day2_briefing_heard = bool(data.get("day2_briefing", false))
	analysis_history = data.get("analysis_history", {}).duplicate(true)
	changed.emit()

func checkpoint_day() -> void:
	_checkpoint = snapshot().duplicate(true)

func restart_day() -> void:
	restore(_checkpoint)

func reset() -> void:
	restore({})
	checkpoint_day()

func fertilize(id: int) -> void:
	if id not in fertilized_ids:
		fertilized_ids.append(id)
		changed.emit()

func deer_tolerant() -> bool:
	return fertilized_ids.size() >= 5

func advance_test_day() -> void:
	day = 2
	checkpoint_day()
	changed.emit()

func register_analysis(origin: String) -> void:
	if origin in ["attis", "habitat1"] and origin not in analysed_samples:
		analysed_samples.append(origin)
		changed.emit()

func begin_day(value: int) -> void:
	analysis_history[str(day)] = analysed_samples.duplicate()
	day = value
	analysed_samples.clear()
	robot_activated = false
	robot_service_done = false
	day2_briefing_heard = false
	changed.emit()

func begin_dream() -> void:
	analysis_history[str(day)] = analysed_samples.duplicate()
	day = 3
	is_dream = true
	demo_finished = false
	dream_letter_read = false
	power_restored = false
	robot_activated = false
	fuse_installed = false
	breaker_progress = 0
	changed.emit()

func was_sampled_today(origin: String, id: int) -> bool:
	return int(sampled_bush_days.get("%s:%d" % [origin,id],0)) == day

func record_sample(origin: String, id: int) -> void:
	sampled_bush_days["%s:%d" % [origin,id]] = day
