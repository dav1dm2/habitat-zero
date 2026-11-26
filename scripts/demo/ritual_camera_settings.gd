extends Node3D
## Scene-owned cutscene settings. Move the two Marker3D children to frame the deer.
@export_range(0.2, 6.0, 0.1) var walk_speed: float = 2.1
@export_range(5.0, 180.0, 1.0) var turn_speed_degrees: float = 80.0
@export_range(0.1, 5.0, 0.1) var centered_duration: float = 0.9
@export_range(0.5, 10.0, 0.1) var deer_approach_duration: float = 3.2
