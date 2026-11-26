extends Node
## Atalho de revisão: F6 inicia diretamente no despertar do sonho.
func run() -> void:
	var tree := get_tree()
	var session := get_node("/root/DemoSession")
	var progress := get_node("/root/ReserveState")
	progress.reset()
	session.campaign_started = true
	session.room_items.clear()
	session.storage.clear()
	progress.day = 2
	progress.begin_dream()
	session._restore_inventory = {"slots":[load("res://resources/items/dream_letter.tres"),null,null,null],"selected":0}
	tree.change_scene_to_file("res://scenes/levels/attis_interior.tscn")
	await tree.scene_changed
	await tree.create_timer(.3).timeout
	var room := tree.current_scene
	var player: Node3D = room.get_node("Player")
	player.global_position = room.get_node("DayStart").global_position
	player.rotation.y = PI*.5
	session.checkpoint_day(room)
	get_node("/root/DemoInterface").show_status("Um bilhete manchado está no inventário. M1 para ler. Tab abre o caderno.")
	queue_free()
