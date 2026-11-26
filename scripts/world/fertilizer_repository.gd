extends StaticBody3D
## Uma unidade por slot vazio. Estoque restaurável/infinito para o protótipo.
const FERTILIZER = preload("res://resources/items/fertilizer.tres")
const prompt_offset := Vector3(0.0, 0.6, 0.0)

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("hud_interactables")

func interaction_prompt() -> String:
	return "E  •  Recolher adubo"

func interact(actor: Node) -> void:
	var inventory := actor.get_node_or_null("Inventory")
	if inventory == null or not inventory.has_method("restock_empty_slots"):
		return
	var count: int = inventory.restock_empty_slots(FERTILIZER)
	var room := get_tree().current_scene
	if room != null and room.has_method("show_status"):
		room.show_status("Almoxarifado · Adubo recolhido (%d)" % count if count > 0 else "Almoxarifado · Inventário cheio")
