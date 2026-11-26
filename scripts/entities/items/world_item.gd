extends RigidBody3D

const Appearance = preload("res://scripts/entities/items/item_appearance.gd")

@export var definition: Resource

@onready var display_mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group("world_items")
	linear_damp = 1.2
	angular_damp = 3.5
	can_sleep = true
	continuous_cd = true
	if definition == null:
		return

	if definition.get("item_id") == &"sample_collector":
		definition = definition.duplicate(true)

	if Appearance.apply_model(definition.item_id, display_mesh, $CollisionShape3D):
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = definition.get("pickup_color")
	material.roughness = 0.65
	display_mesh.material_override = material
	if definition.get("item_id") in [&"arrival_letter", &"dream_letter"]:
		var paper := BoxMesh.new()
		paper.size = Vector3(0.35, 0.025, 0.46)
		display_mesh.mesh = paper
		var paper_shape := BoxShape3D.new()
		# A slightly thicker invisible collider keeps a thrown sheet stable on trimesh ground.
		paper_shape.size = Vector3(0.35, 0.06, 0.46)
		$CollisionShape3D.shape = paper_shape

func _physics_process(_delta: float) -> void:
	var room := get_tree().current_scene
	var outside := global_position.y < -25.0
	if room != null and room.has_method("item_out_of_bounds"):
		outside = outside or room.item_out_of_bounds(global_position)
	if outside:
		var session := get_node_or_null("/root/DemoSession")
		if session != null:
			session.recover_item(self)
