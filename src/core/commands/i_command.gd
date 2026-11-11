class_name ICommand
extends RefCounted
## Contrato del Patrón Command para garantizar que toda mutación sobre el documento
## sea reversible (Undo/Redo), trazable y auditable.

var timestamp_msec: int


func _init() -> void:
	timestamp_msec = Time.get_ticks_msec()


func get_action_name() -> String:
	return "Generic Command"


## Ejecuta la acción sobre el modelo de dominio. Devuelve true si tuvo efecto.
func execute() -> bool:
	return false


## Revierte exactamente el cambio realizado en execute().
func undo() -> void:
	pass


## Permite fusionar comandos consecutivos del mismo tipo (ej. al arrastrar un slider en el Inspector).
func can_merge_with(_other: ICommand) -> bool:
	return false


func merge_with(_other: ICommand) -> void:
	pass
