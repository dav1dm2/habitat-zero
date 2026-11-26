extends RefCounted

const MODELS := {
	&"fuse": ["fuse", Vector3(0.57, 0.22, 0.22)],
	&"fertilizer": ["fertilizer", Vector3(0.49, 0.23, 0.30)],
	&"sample_collector": ["sample_probe", Vector3(0.73, 0.29, 0.33)],
}
const PAPER_ICONS := {
	&"arrival_letter": "letter",
	&"dream_letter": "dream_letter",
}

static func apply_model(item_id: StringName, mount: MeshInstance3D, collision: CollisionShape3D) -> bool:
	if not MODELS.has(item_id):
		return false
	var appearance: Array = MODELS[item_id]
	var scene := load("res://scenes/entities/items/models/%s.tscn" % appearance[0]) as PackedScene
	mount.mesh = null
	mount.add_child(scene.instantiate())
	var shape := BoxShape3D.new()
	shape.size = appearance[1]
	collision.shape = shape
	return true

static func icon_for(item_id: StringName) -> Texture2D:
	var name: String = MODELS[item_id][0] if MODELS.has(item_id) else PAPER_ICONS.get(item_id, "")
	if name.is_empty():
		return null
	return load("res://assets/items/icons/%s.png" % name) as Texture2D
