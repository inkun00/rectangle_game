class_name CommandManager
extends RefCounted

## Commands carry values rather than scene nodes. Weak targets avoid reference cycles.
signal state_changed

var undo_stack: Array[RefCounted] = []
var redo_stack: Array[RefCounted] = []
var max_history: int = 80

class SnapshotCommand extends RefCounted:
	var target: WeakRef
	var method: StringName
	var before: Dictionary
	var after: Dictionary

	func _init(object: Object, apply_method: StringName, old_state: Dictionary, new_state: Dictionary) -> void:
		target = weakref(object)
		method = apply_method
		before = old_state.duplicate(true)
		after = new_state.duplicate(true)

	func execute() -> void:
		var object: Object = target.get_ref()
		if is_instance_valid(object):
			object.call(method, after.duplicate(true))

	func undo() -> void:
		var object: Object = target.get_ref()
		if is_instance_valid(object):
			object.call(method, before.duplicate(true))

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

func push_snapshot(object: Object, method: StringName, before: Dictionary, after: Dictionary) -> void:
	push_and_execute(SnapshotCommand.new(object, method, before, after))

func push_and_execute(command: RefCounted) -> void:
	command.call("execute")
	undo_stack.append(command)
	if undo_stack.size() > max_history:
		undo_stack.pop_front()
	redo_stack.clear()
	state_changed.emit()

func undo() -> void:
	if undo_stack.is_empty():
		return
	var command: RefCounted = undo_stack.pop_back()
	command.call("undo")
	redo_stack.append(command)
	state_changed.emit()

func redo() -> void:
	if redo_stack.is_empty():
		return
	var command: RefCounted = redo_stack.pop_back()
	command.call("execute")
	undo_stack.append(command)
	state_changed.emit()

func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()
	state_changed.emit()
