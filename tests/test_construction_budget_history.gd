class_name TestConstructionBudgetHistory
extends RefCounted

const Document = preload("res://scripts/construction/construction_document.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")

static func run(t: Node) -> void:
	_test_undo_after_spending(t)
	_test_redo_after_spending(t)
	_test_ordinary_and_disabled_history(t)

static func _test_undo_after_spending(t: Node) -> void:
	var model: Document = Document.new()
	var price: int = int(Catalog.material("door").price)
	t.assert_gt(model.add_part("door", Vector2(500, 500)), 0, "Budget-history fixture buys a valid expensive material")
	var original_parts: Array[Dictionary] = model.parts.duplicate(true)
	model.delete_selected()
	model.budget_limit = price - 100
	var empty: Dictionary = model.serialize()
	var undo_count: int = model.command_manager.undo_stack.size()
	var changes: Array[int] = [0]
	model.changed.connect(func(): changes[0] += 1)
	model.undo()
	t.assert_eq(model.serialize(), empty, "Insufficient funds leave geometry, selection and revision unchanged")
	t.assert_eq(model.command_manager.undo_stack.size(), undo_count, "Unaffordable undo preserves the original undo command")
	t.assert_eq(model.command_manager.redo_stack.size(), 0, "Unaffordable undo does not add a redo command")
	t.assert_eq(changes[0], 1, "A rejected budget undo notifies the UI to show its explanation")
	t.assert_true(model.last_error.contains("자금"), "Rejected undo explains the insufficient funds")
	t.assert_true(model.last_error.contains("그림·집 수익"), "Rejected undo tells the player how to afford it later")
	model.undo()
	t.assert_eq(model.serialize(), empty, "Repeated rejected undo remains a no-op")
	t.assert_eq(model.command_manager.undo_stack.size(), undo_count, "Repeated rejection cannot consume history")
	model.budget_limit = price
	model.undo()
	t.assert_eq(model.parts, original_parts, "Earning enough money allows the same historical design to be restored")
	t.assert_eq(model.material_cost(), price, "Restored design can use exactly the available budget")
	t.assert_eq(model.command_manager.undo_stack.size(), undo_count - 1, "Affordable undo consumes exactly one command")
	t.assert_eq(model.command_manager.redo_stack.size(), 1, "Affordable undo adds exactly one redo command")
	t.assert_eq(model.last_error, "", "Successful undo clears the earlier budget error")
	var restored: Document = Document.new()
	restored.budget_limit = model.budget_limit
	t.assert_true(restored.restore(JSON.parse_string(JSON.stringify(model.serialize()))), "An affordable restored design still passes saved-document validation")

static func _test_redo_after_spending(t: Node) -> void:
	var model: Document = Document.new()
	var price: int = int(Catalog.material("door").price)
	model.add_part("door", Vector2(500, 500))
	var original_parts: Array[Dictionary] = model.parts.duplicate(true)
	model.undo()
	model.budget_limit = price - 100
	var empty: Dictionary = model.serialize()
	var changes: Array[int] = [0]
	model.changed.connect(func(): changes[0] += 1)
	model.redo()
	t.assert_eq(model.serialize(), empty, "Redo cannot spend money that is no longer available")
	t.assert_eq(model.command_manager.undo_stack.size(), 0, "Rejected redo keeps the undo stack unchanged")
	t.assert_eq(model.command_manager.redo_stack.size(), 1, "Rejected redo keeps its command available for later")
	t.assert_eq(changes[0], 1, "Rejected redo emits its budget explanation without applying a command")
	t.assert_true(model.last_error.contains("자금"), "Rejected redo explains the budget restriction")
	model.budget_limit = price + 100
	model.redo()
	t.assert_eq(model.parts, original_parts, "Redo succeeds after new earnings restore the budget")
	t.assert_eq(model.command_manager.undo_stack.size(), 1, "Successful redo records one undo command")
	t.assert_eq(model.command_manager.redo_stack.size(), 0, "Successful redo removes the pending redo command")
	t.assert_eq(model.last_error, "", "Successful redo clears the earlier budget explanation")

static func _test_ordinary_and_disabled_history(t: Node) -> void:
	var model: Document = Document.new()
	model.add_part("brick", Vector2(500, 550))
	var before_move: Array[Dictionary] = model.parts.duplicate(true)
	t.assert_true(model.move_selected(Vector2(540, 550)), "An ordinary history fixture moves a brick")
	var after_move: Array[Dictionary] = model.parts.duplicate(true)
	model.budget_limit = model.material_cost()
	model.undo()
	t.assert_eq(model.parts, before_move, "Ordinary geometry undo remains available at the exact material budget")
	model.redo()
	t.assert_eq(model.parts, after_move, "Ordinary geometry redo preserves its established behavior")
	model.editing_enabled = false
	var locked: Dictionary = model.serialize()
	var undo_count: int = model.command_manager.undo_stack.size()
	model.undo()
	t.assert_eq(model.serialize(), locked, "Completed or locked designs still cannot be undone")
	t.assert_eq(model.command_manager.undo_stack.size(), undo_count, "Disabled editing does not consume undo history")
	model.editing_enabled = true
	model.undo()
	model.editing_enabled = false
	locked = model.serialize()
	var redo_count: int = model.command_manager.redo_stack.size()
	model.redo()
	t.assert_eq(model.serialize(), locked, "Disabled editing still blocks redo")
	t.assert_eq(model.command_manager.redo_stack.size(), redo_count, "Disabled editing does not consume redo history")
