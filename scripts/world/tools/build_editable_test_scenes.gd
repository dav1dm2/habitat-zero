extends SceneTree
## Conversão explícita: executar apenas para regenerar os cenários a partir dos builders.
## Não executar sobre cenas que receberam edição manual sem preservar essas mudanças.
func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	var progress := root.get_node("ReserveState")
	progress.reset()
	DirAccess.make_dir_recursive_absolute("res://resources/environments")
	for spec in [["NPCTestRange", "res://scripts/world/npc_test_range.gd", "res://scenes/levels/npc_test_range.tscn"], ["MechanicsTestRoom", "res://scripts/world/mechanics_test_room.gd", "res://scenes/levels/mechanics_test_room.tscn"]]:
		progress.day = 2 if spec[0] == "NPCTestRange" else 1
		var room := Node3D.new()
		room.set_script(load(spec[1]))
		room.name = spec[0]
		room.set_meta("authoring_build", true)
		root.add_child(room)
		_freeze(room)
		for index in range(4):
			await physics_frame
		if spec[0] == "NPCTestRange":
			var hills: MeshInstance3D = room.get_node("NavigationRegion3D/Hills")
			ResourceSaver.save(hills.mesh, "res://resources/environments/npc_test_hills.res")
			var collision: CollisionShape3D = room.get_node("NavigationRegion3D/TerrainCollision").get_child(0)
			ResourceSaver.save(collision.shape, "res://resources/environments/npc_test_ground_collision.res")
		progress.day = 1
		room.remove_meta("authoring_build")
		_own(room, room)
		var packed := PackedScene.new()
		var error := packed.pack(room)
		if error == OK:
			error = ResourceSaver.save(packed, spec[2])
		if error != OK:
			push_error("Falha ao gravar cena: %s, erro %d" % [spec[2], error])
			quit(1)
			return
		print("Cena editável gravada: ",spec[2]," · ",room.get_child_count()," filhos diretos")
		room.free()
	progress.reset()
	quit()

func _freeze(node: Node) -> void:
	if node is CharacterBody3D or node is Area3D or node.get_script() == preload("res://scripts/entities/npcs/animal_group.gd"):
		node.set_physics_process(false)
	for child in node.get_children():
		_freeze(child)

func _own(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			_own(child, scene_root)
