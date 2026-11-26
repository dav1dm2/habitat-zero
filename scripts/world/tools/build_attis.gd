extends RefCounted
## Ferramenta explícita de autoria. Não é executada pelo nível.
## Não regenerar após edição manual sem preservar a cena existente.
const LEVEL := "res://scenes/levels/attis_forest.tscn"
const PROPS := "res://scenes/props/attis/"
var rng := RandomNumberGenerator.new()
var mats: Dictionary = {}

func height_at(x: float, z: float) -> float:
	var t := clampf((70.0 - z) / 135.0, 0.0, 1.0)
	var base := 24.0 * smoothstep(0.0, 1.0, t)
	var off_path := smoothstep(4.0, 20.0, absf(x - trail_x(z)))
	var waves := (2.1 * sin(x * 0.105) * sin(z * 0.067) + 1.4 * cos(x * 0.17 + z * 0.08)) * off_path
	return base + waves * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.82, 1.0, t))

func trail_x(z: float) -> float:
	var t := clampf((70.0 - z) / 135.0, 0.0, 1.0)
	return 16.0 * sin(t * TAU)

func ground(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + lift, z)

func material(key: String, color: String) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	mat.albedo_color = Color(color)
	mat.roughness = 1.0
	mats[key] = mat
	return mat

func group(parent: Node, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	parent.add_child(node)
	return node

func mesh_node(parent: Node, title: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node

func box(parent: Node, title: String, at: Vector3, size: Vector3, mat: Material, solid: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = title
	root.position = at
	parent.add_child(root)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node(root, "Visual", mesh, Vector3.ZERO, mat)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		root.add_child(collider)
	return root

func label(parent: Node, title: String, words: String, at: Vector3, size: int = 48) -> Label3D:
	var node := Label3D.new()
	node.name = title
	node.text = words
	node.position = at
	node.font_size = size
	node.pixel_size = 0.012
	node.modulate = Color("c6c6a9")
	node.outline_size = 3
	parent.add_child(node)
	return node

func own_nodes(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		if child.scene_file_path.is_empty():
			own_nodes(child, scene)

func save_scene(node: Node, path: String) -> Error:
	own_nodes(node, node)
	var packed := PackedScene.new()
	var error := packed.pack(node)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	return error

func append_box(surface: SurfaceTool, at: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	surface.append_from(mesh, 0, Transform3D(Basis.IDENTITY, at))

func append_branch(surface: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.35
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 5
	mesh.rings = 1
	var direction := (b - a).normalized()
	var basis := Basis(Quaternion(Vector3.UP, direction))
	surface.append_from(mesh, 0, Transform3D(basis, (a + b) * 0.5))

func make_dead_tree(index: int) -> void:
	var root := StaticBody3D.new()
	root.name = "DeadTree"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tall := 9.0 + index * 2.0
	append_branch(surface, Vector3.ZERO, Vector3(0.25, tall, 0.1), 0.5)
	for i in range(8):
		var angle := i * 2.4 + index
		var start := Vector3(0.0, 3.1 + i * 0.65, 0.0)
		var end := start + Vector3(cos(angle) * 2.4, 2.6, sin(angle) * 2.4)
		append_branch(surface, start, end, 0.19)
		append_branch(surface, end, end + Vector3(cos(angle + 0.6), 1.7, sin(angle + 0.6)), 0.075)
	mesh_node(root, "TroncoEGalhos", surface.commit(), Vector3.ZERO, material("Bark", "494a43"))
	var collider := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.48
	cylinder.height = tall
	collider.shape = cylinder
	collider.position.y = tall * 0.5
	root.add_child(collider)
	save_scene(root, PROPS + "dead_tree_%d.tscn" % index)
	root.free()

func apply_atlas(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		apply_atlas(child, mat)

func make_imported(name: String, category: String, texture_name: String, desired_height: float) -> void:
	var root := StaticBody3D.new()
	root.name = name
	var visual: Node3D = load("res://assets/external/retro_nature/%s/%s.glb" % [category, name]).instantiate()
	var atlas := StandardMaterial3D.new()
	atlas.albedo_texture = load("res://assets/external/retro_nature/%s/%s.png" % [category, texture_name])
	atlas.albedo_color = Color("aaa995")
	atlas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	atlas.alpha_scissor_threshold = 0.45
	atlas.cull_mode = BaseMaterial3D.CULL_DISABLED
	atlas.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	apply_atlas(visual, atlas)
	# GLB geometry is ~5 m tall for trees, ~1 m for bushes.
	var factor := desired_height / (5.5 if category == "trees" else 1.0)
	visual.scale = Vector3.ONE * factor
	root.add_child(visual)
	# Retain model as a regular editable sub-tree in the reusable wrapper.
	visual.scene_file_path = ""
	if category == "trees":
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.45
		shape.height = desired_height * 0.6
		collision.shape = shape
		collision.position.y = shape.height * 0.5
		root.add_child(collision)
	save_scene(root, PROPS + name + ".tscn")
	root.free()

func make_fence() -> void:
	var root := StaticBody3D.new()
	root.name = "FencePanel"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(surface, Vector3(0, 2, 0), Vector3(0.13, 4, 0.13))
	for y in [0.4, 1.3, 2.3, 3.3, 3.8]:
		append_box(surface, Vector3(2.5, y, 0), Vector3(5, 0.045, 0.045))
	for x in range(1, 11):
		append_box(surface, Vector3(x * 0.5, 1.95, 0), Vector3(0.025, 3.5, 0.025))
	mesh_node(root, "Grade", surface.commit(), Vector3.ZERO, material("Fence", "525b56"))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.08, 4.5, 0.2)
	collision.shape = shape
	collision.position = Vector3(2.5, 2, 0)
	root.add_child(collision)
	save_scene(root, PROPS + "fence_panel.tscn")
	root.free()

func build_terrain(parent: Node) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var soil := material("Soil", "656958")
	soil.vertex_color_use_as_albedo = true
	soil.albedo_color = Color.WHITE
	for x in range(-70, 70, 2):
		for z in range(-90, 80, 2):
			var a := ground(x, z)
			var b := ground(x + 2, z)
			var c := ground(x, z + 2)
			var d := ground(x + 2, z + 2)
			for point in [a, b, c, b, d, c]:
				var variation := 0.025 * sin(point.x * 1.7 + point.z * 0.4)
				surface.set_color(Color(0.28 + variation, 0.30 + variation, 0.25 + variation))
				surface.add_vertex(point)
	surface.generate_normals()
	var terrain := surface.commit()
	ResourceSaver.save(terrain, "res://resources/environments/attis_ground.res")
	mesh_node(parent, "Colina", terrain, Vector3.ZERO, soil)
	var body := StaticBody3D.new()
	body.name = "ColisaoDoTerreno"
	var collider := CollisionShape3D.new()
	collider.shape = terrain.create_trimesh_shape()
	body.add_child(collider)
	parent.add_child(body)
	var trail := SurfaceTool.new()
	trail.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-66, 77):
		var width := 3.2 if z > 56 else 2.5
		var a := ground(trail_x(z) - width, z, 0.06)
		var b := ground(trail_x(z) + width, z, 0.06)
		var c := ground(trail_x(z + 1) - width, z + 1, 0.06)
		var d := ground(trail_x(z + 1) + width, z + 1, 0.06)
		for p in [a, b, c, b, d, c]:
			trail.add_vertex(p)
	trail.generate_normals()
	mesh_node(parent, "TrilhaPrincipal", trail.commit(), Vector3.ZERO, material("Trail", "777160"))
	# A short curved branch joins the radio clearing.
	var branch := SurfaceTool.new()
	branch.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		var a := Vector2(-10.0 - i, -50.0 - i * 0.2)
		var b := Vector2(-11.0 - i, -50.2 - i * 0.2)
		for p in [ground(a.x, a.y - 1.5, 0.07), ground(b.x, b.y - 1.5, 0.07), ground(a.x, a.y + 1.5, 0.07), ground(b.x, b.y - 1.5, 0.07), ground(b.x, b.y + 1.5, 0.07), ground(a.x, a.y + 1.5, 0.07)]:
			branch.add_vertex(p)
	branch.generate_normals()
	mesh_node(parent, "DesvioRadio", branch.commit(), Vector3.ZERO, material("Trail", "777160"))

func build_entry(parent: Node) -> void:
	var base := ground(-7, 60)
	var booth := group(parent, "Guarita")
	booth.position = base
	var concrete := material("Concrete", "72776e")
	box(booth, "Piso", Vector3(0, 0.1, 0), Vector3(4.5, 0.3, 4.5), concrete)
	box(booth, "ParedeFundo", Vector3(0, 1.6, -2), Vector3(4.5, 3, 0.3), concrete)
	box(booth, "ParedeLateral", Vector3(-2.1, 1.6, 0), Vector3(0.3, 3, 4), concrete)
	box(booth, "Balcao", Vector3(0, 0.7, 1.9), Vector3(4.5, 1.2, 0.3), concrete)
	box(booth, "Cobertura", Vector3(0, 3.3, 0), Vector3(5.1, 0.35, 5.1), concrete)
	label(booth, "Placa", "RESERVA DE ATTIS\nCONTROLE DE ACESSO", Vector3(0, 2.5, 2.22), 31)
	var barrier := group(parent, "CancelaQuebrada")
	barrier.position = ground(4.5, 58)
	box(barrier, "Mecanismo", Vector3(0, 0.8, 0), Vector3(0.7, 1.6, 0.7), material("Yellow", "b2a067"))
	var arm := box(barrier, "BracoPartido", Vector3(-1, 1.3, 0), Vector3(2.3, 0.16, 0.18), material("Paint", "d0c8ab"))
	arm.rotation_degrees.z = -18
	var broken := box(parent, "PedacoCaido", ground(-2.4, 56, 0.18), Vector3(2.8, 0.16, 0.18), material("Paint", "d0c8ab"), false)
	broken.rotation_degrees.y = -28
	# A closed maintenance gate behind the drop-off seals the road boundary.
	box(parent, "PortaoDeRetorno", ground(0, 77, 2.1), Vector3(9, 4.4, 0.3), material("Gate", "4c5651"))
	label(parent, "AvisoRetorno", "ACESSO RESTRITO", ground(0, 76.8, 2.7), 36).rotation_degrees.y = 180

func build_base(parent: Node) -> void:
	var root := group(parent, "InstalacoesNaRocha")
	root.position = Vector3(0, 24, -69)
	var concrete := material("Concrete", "72776e")
	box(root, "Patamar", Vector3(0, -0.15, 3), Vector3(21, 0.4, 17), concrete)
	box(root, "AlaEsquerda", Vector3(-6.2, 2.8, 0), Vector3(5.4, 5.6, 12), concrete)
	box(root, "AlaDireita", Vector3(6.2, 2.8, 0), Vector3(5.4, 5.6, 12), concrete)
	box(root, "Laje", Vector3(0, 5.4, 0), Vector3(18, 1.1, 13), concrete)
	box(root, "ParedeInterna", Vector3(0, 2.5, -5.6), Vector3(7, 5, 0.5), material("DarkConcrete", "343d39"))
	box(root, "PortaProvisoria", Vector3(0, 1.8, -5.29), Vector3(3.8, 3.6, 0.15), material("Door", "4b5853"))
	label(root, "Identificacao", "ATTIS / POSTO 04", Vector3(0, 4.65, 6.6), 52)
	label(root, "PortaSemEnergia", "INSTALACOES\nACESSO INTERNO EM CONSTRUCAO", Vector3(0, 2.6, -5.15), 25)
	for x in [-4.2, 4.2]:
		box(root, "Pilar", Vector3(x, 2.5, 6), Vector3(0.65, 5, 0.8), concrete)
		box(root, "LuminariaApagada", Vector3(x, 3.7, 6.45), Vector3(0.35, 0.65, 0.2), material("LampOff", "9a9b83"), false)
	add_base_ramp(parent.get_parent())
	var rockmat := material("Rock", "535c56")
	for spec in [[-16, 7, -4, 12, 15, 17], [16, 8, -7, 14, 17, 18], [0, 9, -20, 22, 19, 9]]:
		var rock := SphereMesh.new()
		rock.radial_segments = 7
		rock.rings = 3
		rock.radius = 1
		rock.height = 2
		var node := mesh_node(root, "MacicoRochoso", rock, Vector3(spec[0], spec[1], spec[2]), rockmat)
		node.scale = Vector3(spec[3], spec[4], spec[5])
		node.create_trimesh_collision()

func add_base_ramp(root: Node) -> void:
	var parent: Node3D = root.get_node("BaseNoTopo")
	var old := parent.get_node_or_null("RampaDeAcesso")
	if old != null:
		old.free()
	var ramp := SurfaceTool.new()
	ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-10, 24.05, -57.5)
	var b := Vector3(10, 24.05, -57.5)
	var c := ground(-10, -51, -0.15)
	var d := ground(10, -51, -0.15)
	for point in [a,b,c,b,d,c]:
		ramp.add_vertex(point)
	for point in [Vector3(-10,24.05,-61),Vector3(10,24.05,-61),a,Vector3(10,24.05,-61),b,a]:
		ramp.add_vertex(point)
	ramp.generate_normals()
	var node := mesh_node(parent, "RampaDeAcesso", ramp.commit(), Vector3.ZERO, material("Concrete", "72776e"))
	node.create_trimesh_collision()

func build_radio(parent: Node) -> void:
	var root := group(parent, "EstacaoDeRadio")
	root.position = ground(-34, -55)
	var concrete := material("Concrete", "72776e")
	box(root, "Plataforma", Vector3(0, 0.2, 0), Vector3(11, 0.5, 11), concrete)
	box(root, "AbrigoTecnico", Vector3(-1, 1.8, 0), Vector3(5, 3.2, 4), material("Radio", "626e64"))
	box(root, "Porta", Vector3(-1, 1.5, 2.06), Vector3(1.4, 2.5, 0.1), material("Door", "4b5853"), false)
	label(root, "Identificacao", "RADIO / R-04\nSEM ENERGIA", Vector3(-1, 2.85, 2.09), 24)
	var mast := SurfaceTool.new()
	mast.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-1.0, 1.0]:
		append_branch(mast, Vector3(3 + x, 0.5, -2), Vector3(3, 23, -2), 0.12)
	for i in range(10):
		append_branch(mast, Vector3(2 + i * 0.045, i * 2 + 1, -2), Vector3(4 - i * 0.045, i * 2 + 2.5, -2), 0.045)
	append_branch(mast, Vector3(0, 19, -2), Vector3(6, 19, -2), 0.06)
	append_branch(mast, Vector3(1, 21, -2), Vector3(5, 21, -2), 0.06)
	mesh_node(root, "Antena", mast.commit(), Vector3.ZERO, material("Fence", "525b56"))

func fence_line(parent: Node, a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var count := ceili(length / 5.0)
	for i in range(count):
		var p := a.lerp(b, float(i) / count)
		var q := a.lerp(b, float(i + 1) / count)
		var start := ground(p.x, p.y, -0.3)
		var end := ground(q.x, q.y, -0.3)
		var node: Node3D = load(PROPS + "fence_panel.tscn").instantiate()
		parent.add_child(node)
		node.position = start
		var delta := end - start
		var x_axis := delta.normalized()
		var z_axis := x_axis.cross(Vector3.UP).normalized()
		var y_axis := z_axis.cross(x_axis).normalized()
		node.basis = Basis(x_axis * (delta.length() / 5.0), y_axis, z_axis)

func build_vegetation(parent: Node) -> void:
	var count := 0
	for i in range(1000):
		if count >= 165:
			break
		var x := rng.randf_range(-61, 61)
		var z := rng.randf_range(-63, 71)
		if absf(x - trail_x(z)) < 5.8 or (z < -48 and absf(x) < 22) or Vector2(x + 34, z + 55).length() < 10 or (z > 52 and absf(x) < 14):
			continue
		if z < -47 and x < -6 and x > -43:
			continue
		var filename := "dead_tree_%d" % (count % 3)
		if count % 5 == 0:
			filename = "tree03_winter"
		elif count % 7 == 0:
			filename = "tree05_winter"
		elif count % 11 == 0:
			filename = "tree01"
		var tree: Node3D = load(PROPS + filename + ".tscn").instantiate()
		tree.name = "Arvore_%03d" % count
		parent.add_child(tree)
		tree.position = ground(x, z, -0.12)
		tree.rotation.y = rng.randf_range(-PI, PI)
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.35)
		count += 1
	for i in range(35):
		var z := rng.randf_range(-45, 53)
		var x := trail_x(z) + rng.randf_range(5, 17) * (-1 if i % 2 == 0 else 1)
		var bush: Node3D = load(PROPS + "bush01_winter.tscn").instantiate()
		bush.name = "Arbusto_%02d" % i
		parent.add_child(bush)
		bush.position = ground(x, z)
		bush.rotation.y = rng.randf_range(-PI, PI)

func build_and_save() -> Dictionary:
	if FileAccess.file_exists(LEVEL):
		return {"error": "Attis já existe. Preservar edições manuais antes de regenerar."}
	rng.seed = 24112026
	DirAccess.make_dir_recursive_absolute(PROPS)
	for i in range(3):
		make_dead_tree(i)
	make_fence()
	make_imported("tree03_winter", "trees", "tree03_winter", 11)
	make_imported("tree05_winter", "trees", "tree05_winter", 12)
	make_imported("tree01", "trees", "tree01_fall", 10)
	make_imported("bush01_winter", "bushes", "bush1_winter", 1.1)
	var root := Node3D.new()
	root.name = "AttisForest"
	var environment := WorldEnvironment.new()
	environment.name = "Ambiente_Nevoeiro"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("89968c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8b5a4")
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color("89968c")
	env.fog_density = 0.012
	env.fog_sky_affect = 1.0
	ResourceSaver.save(env, "res://resources/environments/attis_fog.tres")
	environment.environment = env
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "LuzNublada"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("d7d3b1")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	root.add_child(sun)
	build_terrain(group(root, "TerrenoETrilhas"))
	build_entry(group(root, "EntradaDaReserva"))
	build_base(group(root, "BaseNoTopo"))
	build_radio(group(root, "Radio"))
	var perimeter := group(root, "Perimetro")
	fence_line(perimeter, Vector2(-65, 77), Vector2(-4.5, 77))
	fence_line(perimeter, Vector2(4.5, 77), Vector2(65, 77))
	fence_line(perimeter, Vector2(-65, 77), Vector2(-65, -86))
	fence_line(perimeter, Vector2(65, 77), Vector2(65, -86))
	fence_line(perimeter, Vector2(-65, -86), Vector2(65, -86))
	build_vegetation(group(root, "Vegetacao"))
	var markers := group(root, "Marcadores")
	for spec in [["Chegada", 0, 70], ["EntradaInstalacoes", 0, -61], ["ClareiraCervo", -21, 17], ["ClareiraGamba", 26, 32], ["BaseRobo", 7, -59], ["Radio", -28, -51]]:
		var marker := Marker3D.new()
		marker.name = spec[0]
		marker.position = ground(spec[1], spec[2], 1.0)
		markers.add_child(marker)
	var player: Node3D = load("res://scenes/entities/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = ground(0, 70, 1.0)
	root.add_child(player)
	var error := save_scene(root, LEVEL)
	var nodes := root.find_children("*", "", true, false).size()
	root.free()
	return {"error": error, "scene": LEVEL, "nodes": nodes, "size_m": "130 x 163", "rise_m": 24}
