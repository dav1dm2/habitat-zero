extends Resource
## Trusted local checkpoint container; mutable tools and Transform3D are saved as resources.
@export var format_version: int = 1
@export var saved_at: String = ""
@export var checkpoint: Dictionary = {}
