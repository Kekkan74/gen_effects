class_name CommandManager
extends RefCounted
## Gestor transaccional de Comandos (Undo / Redo + Fusión de Sliders + Notificación en EventBus).
## La UI nunca muta el OmniVFXDocument directamente; siempre envía un ICommand aquí.

var _undo_stack: Array[ICommand] = []
var _redo_stack: Array[ICommand] = []
var _max_history: int = 100
var _event_bus: EventBus


func _init(event_bus: EventBus = null, max_history: int = 100) -> void:
	_event_bus = event_bus
	_max_history = max(1, max_history)


## Ejecuta un comando, lo añade a la pila de Undo (o lo fusiona con el anterior si procede)
## y limpia la pila de Redo.
func execute_command(command: ICommand, allow_merge: bool = true) -> bool:
	if command == null:
		return false

	var ok := command.execute()
	if not ok:
		return false

	_redo_stack.clear()

	if allow_merge and not _undo_stack.is_empty():
		var top_cmd := _undo_stack.back()
		if top_cmd.can_merge_with(command):
			top_cmd.merge_with(command)
			_notify(EventBus.TOPIC_COMMAND_EXECUTED, top_cmd, true)
			return true

	_undo_stack.append(command)
	if _undo_stack.size() > _max_history:
		_undo_stack.pop_front()

	_notify(EventBus.TOPIC_COMMAND_EXECUTED, command, false)
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var cmd: ICommand = _undo_stack.pop_back()
	cmd.undo()
	_redo_stack.append(cmd)
	_notify(EventBus.TOPIC_COMMAND_UNDONE, cmd, false)
	return true


func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	var cmd: ICommand = _redo_stack.pop_back()
	cmd.execute()
	_undo_stack.append(cmd)
	_notify(EventBus.TOPIC_COMMAND_REDONE, cmd, false)
	return true


func get_undo_count() -> int:
	return _undo_stack.size()


func get_redo_count() -> int:
	return _redo_stack.size()


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func _notify(topic: StringName, cmd: ICommand, was_merged: bool) -> void:
	if _event_bus != null:
		_event_bus.publish(
			topic,
			{
				"action_name": cmd.get_action_name(),
				"merged": was_merged,
				"undo_count": _undo_stack.size(),
				"redo_count": _redo_stack.size(),
			},
			"command_manager"
		)
