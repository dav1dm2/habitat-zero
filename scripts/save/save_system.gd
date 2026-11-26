extends Node
signal save_changed
const DATA = preload("res://scripts/save/daily_checkpoint.gd")
const DEFAULT_PATH := "user://daily_checkpoint.tres"
var save_path := DEFAULT_PATH
var last_error := ""
var recovered_backup := false

func _valid(data: Resource) -> bool:
	if data == null or data.get_script() != DATA or data.format_version != 1:
		return false
	var c: Dictionary = data.checkpoint
	if not c.get("progress") is Dictionary or not c.get("inventory") is Dictionary or not c.get("items") is Dictionary or not c.get("storage") is Array or not c.get("transform") is Transform3D:
		return false
	if c.get("scene","") not in ["res://scenes/levels/attis_forest.tscn","res://scenes/levels/attis_interior.tscn"]:
		return false
	var day := int(c.progress.get("day",0))
	if day < 1 or day > 3 or bool(c.progress.get("dream",false)) != (day == 3):
		return false
	var slots = c.inventory.get("slots",[])
	if not (slots is Array and slots.size() == 4 and slots.all(_valid_item)):
		return false
	if not c.storage.all(func(item):return item != null and _valid_item(item)):
		return false
	for scene in c.items:
		if scene not in ["res://scenes/levels/attis_forest.tscn","res://scenes/levels/attis_interior.tscn","res://scenes/levels/habitat_1.tscn"] or not c.items[scene] is Array:
			return false
		for entry in c.items[scene]:
			if not entry is Dictionary or not _valid_item(entry.get("definition")) or entry.get("definition") == null or not entry.get("transform") is Transform3D or not entry.get("velocity") is Vector3 or not entry.get("angular") is Vector3:
				return false
	for key in ["fertilized","analyses"]:
		if not c.progress.get(key,[]) is Array:
			return false
	return true

func _valid_item(item: Variant) -> bool:
	return item == null or (item is Resource and item.get_script() == preload("res://scripts/entities/items/item_definition.gd") and item.sample_ids.size() <= 3 and item.sample_origin in ["","attis","habitat1"])

func read_checkpoint() -> Resource:
	recovered_backup = false
	for path in [save_path,save_path+".bak.tres"]:
		if not FileAccess.file_exists(path):
			continue
		var data := ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if _valid(data):
			recovered_backup = path != save_path
			return data
	return null

func has_checkpoint() -> bool:
	return read_checkpoint() != null

func summary() -> String:
	var data := read_checkpoint()
	if data == null:
		return "Nenhuma partida salva."
	return "Dia %d · início do dia%s" % [data.checkpoint.progress.day," · cópia recuperada" if recovered_backup else ""]

func write_checkpoint(checkpoint: Dictionary) -> bool:
	last_error = ""
	var data := DATA.new()
	data.saved_at = Time.get_datetime_string_from_system()
	data.checkpoint = checkpoint
	if not _valid(data):
		last_error = "Checkpoint inválido; o arquivo anterior foi preservado."
		return false
	var temp := save_path+".pending.tres"
	var error := ResourceSaver.save(data,temp)
	if error != OK:
		last_error = "Não foi possível gravar o checkpoint (%d)." % error
		return false
	# Only a validated primary may replace the known-good backup.
	if FileAccess.file_exists(save_path):
		var previous := ResourceLoader.load(save_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if _valid(previous):
			error = DirAccess.copy_absolute(save_path,save_path+".bak.tres")
			if error != OK:
				last_error = "Não foi possível preservar a cópia anterior (%d)." % error
				DirAccess.remove_absolute(temp)
				return false
	error = DirAccess.rename_absolute(temp,save_path)
	if error != OK:
		last_error = "Não foi possível substituir o checkpoint (%d)." % error
		return false
	save_changed.emit()
	return true
