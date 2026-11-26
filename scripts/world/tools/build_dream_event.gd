extends Node
## Acrescenta apenas os recursos de evento, preservando a geometria aprovada.
const FOREST := "res://scenes/levels/attis_forest.tscn"
const INTERIOR := "res://scenes/levels/attis_interior.tscn"
func _ready() -> void:
	var maker: RefCounted = load("res://scripts/world/tools/build_attis.gd").new()
	var interior: Node3D = load(INTERIOR).instantiate()
	if not interior.has_node("MachineEmergency"):
		var beacon := OmniLight3D.new()
		beacon.name = "MachineEmergency"
		beacon.position = Vector3(-2.8,2.5,-7.4)
		beacon.light_color = Color("e63a30")
		beacon.light_energy = .6
		beacon.omni_range = 5.0
		beacon.omni_attenuation = 1.3
		beacon.set_script(load("res://scripts/demo/emergency_beacon.gd"))
		interior.add_child(beacon)
		var bulb := SphereMesh.new()
		bulb.radius = .09
		bulb.height = .18
		var mat: StandardMaterial3D = maker.material("EmergencyBulb","d73930")
		mat.emission_enabled = true
		mat.emission = Color("d73930")
		maker.mesh_node(beacon,"Bulb",bulb,Vector3.ZERO,mat)
	var error: int = maker.save_scene(interior,INTERIOR)
	interior.free()
	if error != OK:
		get_tree().quit(error)
		return
	var forest: Node3D = load(FOREST).instantiate()
	if forest.has_node("DreamEvent"):
		push_error("Evento já existe. Não sobrescrever edições manuais.")
		get_tree().quit(1)
		return
	forest.set_meta("simulation_background",true)
	forest.set_meta("authoring_build",true)
	forest.process_mode = Node.PROCESS_MODE_INHERIT
	for actor in forest.find_children("*","CharacterBody3D",true,false):
		actor.set_physics_process(false)
	add_child(forest)
	await get_tree().physics_frame
	var map: RID = forest.get_node("Navegacao").get_navigation_map()
	for i in range(3): await get_tree().process_frame
	NavigationServer3D.map_force_update(map)
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		push_error("Navegação de Attis não está sincronizada para autoria do evento.")
		get_tree().quit(1)
		return
	var event: Node3D = maker.group(forest,"DreamEvent")
	var corpses: Node3D = maker.group(event,"DeadSkunks")
	var circle: Node3D = maker.group(event,"DeerCircle")
	var center := Marker3D.new()
	center.name = "RitualCenter"
	center.position = floor_at(forest,map,Vector3(maker.trail_x(-5),maker.height_at(maker.trail_x(-5),-5),-5))
	event.add_child(center)
	var index := 0
	for z in [-70.0,-62.0,-52.0,-43.0,-34.0,-26.0,-18.0,-13.0,-10.0]:
		var x: float = 0.0 if z < -65 else maker.trail_x(z) + (-.7 if index%2==0 else .7)
		var point := floor_at(forest,map,Vector3(x,maker.height_at(x,z),z))
		var npc: Node3D = load("res://scenes/entities/npcs/skunk.tscn").instantiate()
		npc.name = "DeadSkunk%02d"%index
		npc.position = point+Vector3.UP*.02
		npc.event_only = true
		npc.event_state = "dead"
		npc.debug_labels = false
		corpses.add_child(npc)
		index += 1
	for i in range(7):
		var angle := PI*float(i)/6.0
		var desired := center.position+Vector3(cos(angle)*6.5,0,sin(angle)*6.5)
		var point := floor_at(forest,map,desired)
		var npc: Node3D = load("res://scenes/entities/npcs/deer.tscn").instantiate()
		npc.name = "RitualDeer%02d"%i
		npc.position = point+Vector3.UP*.02
		npc.event_only = true
		npc.event_state = "ritual_wait"
		npc.debug_labels = false
		circle.add_child(npc)
	var trigger := Marker3D.new()
	trigger.name = "TriggerApproach"
	trigger.position = floor_at(forest,map,center.position+Vector3(0,0,-8))
	event.add_child(trigger)
	event.visible = false
	event.process_mode = Node.PROCESS_MODE_DISABLED
	forest.remove_meta("simulation_background")
	forest.remove_meta("authoring_build")
	forest.process_mode = Node.PROCESS_MODE_INHERIT
	error = maker.save_scene(forest,FOREST)
	print("DREAM_EVENT_BUILD ",error," center ",center.position)
	get_tree().quit(error)

func floor_at(room: Node3D,map: RID,point: Vector3) -> Vector3:
	var near := NavigationServer3D.map_get_closest_point(map,point)
	var query := PhysicsRayQueryParameters3D.create(near+Vector3.UP*1.3,near-Vector3.UP*2,1)
	var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position",near)
