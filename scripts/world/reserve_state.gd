extends Node
## Progressão da reserva em memória. O checkpoint representa o começo do dia.
signal changed

var day: int = 1
var power_restored: bool = false
var briefing_heard: bool = false
var fertilized_ids: Array[int] = []
var robot_activated: bool = false
var robot_service_done: bool = false
var _checkpoint: Dictionary = {}

func _ready() -> void:
	checkpoint_day()

func snapshot() -> Dictionary:
	return {"day": day, "power": power_restored, "briefing": briefing_heard,
		"fertilized": fertilized_ids.duplicate(), "robot": robot_activated,
		"service": robot_service_done}

func restore(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	power_restored = bool(data.get("power", false))
	briefing_heard = bool(data.get("briefing", false))
	fertilized_ids.assign(data.get("fertilized", []))
	robot_activated = bool(data.get("robot", false))
	robot_service_done = bool(data.get("service", false))
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
