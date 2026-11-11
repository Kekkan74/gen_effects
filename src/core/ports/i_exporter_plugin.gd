class_name IExporterPlugin
extends RefCounted
## Puerto Secundario (Adaptador de Salida) para exportar un OmniVFXDocument
## hacia formatos externos (Godot .tscn/.gdshader, Unreal Niagara/HLSL, Spritesheet PNG+JSON, .omnivfx)
## sin que el Kernel conozca los detalles de los motores de destino.


func get_exporter_id() -> StringName:
	return &"core.exporter.base"


func get_display_name() -> String:
	return "Base Exporter"


func get_target_engine() -> String:
	return "Agnostic"


func get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["omnivfx"])


## Valida si el documento cumple los requisitos para ser exportado por este plugin.
func can_export(document: Object) -> bool:
	return document != null


## Serializa o compila el documento en un Dictionary de artefactos de salida (útil en memoria y tests).
func build_export_payload(_document: Object, _options: Dictionary = {}) -> Dictionary:
	return {}


## Exporta a disco en la ruta indicada. Devuelve OK (0) o un código de Error de Godot.
func export_to_file(document: Object, target_path: String, options: Dictionary = {}) -> Error:
	if not can_export(document):
		return ERR_INVALID_DATA

	var payload := build_export_payload(document, options)
	if payload.is_empty():
		return ERR_CANT_CREATE

	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	return OK
