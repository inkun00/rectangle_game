class_name TestConstructionGameUi
extends RefCounted

const Studio = preload("res://scenes/construction/construction_studio.gd")
const State = preload("res://scripts/construction/construction_state.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")
const Language = preload("res://scripts/construction/construction_language.gd")
const AwardFixture = preload("res://tests/test_construction_awards.gd")
const Canvas = preload("res://scenes/construction/construction_canvas.gd")

static func run(t: Node) -> void:
	await _test_first_stage_and_help(t)
	await _test_completed_house_gallery(t)

static func _test_first_stage_and_help(t: Node) -> void:
	var studio: Studio = Studio.new()
	studio.testing = true
	t.add_child(studio)
	await _frames(t, 3)
	t.assert_true(studio.canvas.use_2d_background, "Construction mode uses a 2D front-elevation backdrop matching the 2D house")
	t.assert_not_null(studio._client_grid, "On-screen client board exposes the 3x3 client grid")
	if studio._client_grid != null:
		t.assert_eq(studio._client_grid.columns, 3, "Client board arranges clients in a 3x3 grid")
		t.assert_eq(studio._client_grid.get_child_count(), 9, "Client board renders all 9 stage clients")
	studio._show_client_offer_modal(0)
	t.assert_true(studio._modal.visible, "Clicking a client opens the commission detail and acceptance confirmation modal")
	t.assert_true(_text(studio._modal).contains("보유 자산"), "Client detail modal displays the player's held assets and acceptability")
	t.assert_not_null(_button(studio._modal, "이 의뢰 수락하고 시작"), "Affordable client modal offers an explicit acceptance confirmation button")
	studio._show_client_offer_modal(8)
	t.assert_true(_text(studio._modal).contains("수락 불가"), "Higher-stage client modal clearly indicates insufficient assets")
	studio._show_stages()
	for choice: int in range(Catalog.contract_count()):
		var offer: Dictionary = Catalog.contract(choice)
		var button: Button = _button(studio._modal, Language.simplify(str(offer.title)))
		t.assert_not_null(button, "All nine client offers are reachable from the 3x3 stage chooser")
		if button != null:
			t.assert_eq(button.disabled, int(offer.stage) > 1, "A new company can select only first-stage clients based on initial assets")
	var before: Dictionary = studio.state.serialize()
	var locked: Button = _button(studio._modal, Language.simplify(str(Catalog.contract(8).title)))
	if locked != null: locked.pressed.emit()
	t.assert_eq(studio.state.serialize(), before, "A locked offer callback cannot skip the actual financial stage gate")
	studio._close_modal()
	studio._accept_contract()
	t.assert_eq(studio.state.phase, "building", "Accepting the visible first-stage offer opens building")
	t.assert_eq(studio._allowed_families(), ["square", "rectangle", "trapezoid", "parallelogram", "rhombus"], "The first stage allows all five quadrilateral families")
	var visible: int = 0
	for id: String in studio._material_buttons:
		if not studio._material_buttons[id].visible: continue
		visible += 1
		t.assert_true(str(Catalog.material(id).kind) in ["square", "rectangle", "trapezoid", "parallelogram", "rhombus"], "The live first-stage material shelf exposes all five shape families")
	t.assert_gt(visible, 0, "The simple first-stage shelf still contains usable materials")
	t.assert_true(studio._material_buttons.roof_flat_wide.visible, "The first stage visibly offers a real flat rectangular roof")
	var pan_btn: Button = _button(studio, "화면 이동")
	t.assert_not_null(pan_btn, "Studio toolbar exposes a dedicated screen pan button")
	if pan_btn != null:
		pan_btn.pressed.emit()
		t.assert_true(studio.canvas.pan_tool, "Clicking the screen pan button enables pan mode")
		t.assert_true(studio._status.text.contains("화면 이동"), "Pan mode activation is reported in the status feedback")
	studio.canvas.pan_by(Vector2(50, -30))
	t.assert_eq(studio.canvas.pan, Vector2(50, -30), "Pan_by moves the screen viewport")
	# In pan mode: clicking on objects does NOT select them, dragging pans the screen
	var click_press: InputEventMouseButton = InputEventMouseButton.new()
	click_press.button_index = MOUSE_BUTTON_LEFT
	click_press.pressed = true
	click_press.position = studio.canvas.artwork_to_screen(Vector2(500, 500))
	studio.canvas._gui_input(click_press)
	t.assert_eq(studio.canvas.document.selected_id, -1, "In pan mode, left clicking does not select parts")
	var before_drag_pan: Vector2 = studio.canvas.pan
	var drag_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	drag_motion.relative = Vector2(40, -30)
	studio.canvas._gui_input(drag_motion)
	t.assert_eq(studio.canvas.pan, before_drag_pan + Vector2(40, -30), "In pan mode, dragging mouse pans screen view")
	var click_release: InputEventMouseButton = InputEventMouseButton.new()
	click_release.button_index = MOUSE_BUTTON_LEFT
	click_release.pressed = false
	studio.canvas._gui_input(click_release)
	t.assert_false(studio.canvas._panning, "Releasing mouse button ends screen pan drag")
	studio.canvas.select_tool()
	t.assert_false(studio.canvas.pan_tool, "Selecting select tool resets pan mode")
	if pan_btn != null:
		t.assert_false(pan_btn.button_pressed, "Pan button resets pressed state when returning to select tool")
	studio._show_help()
	var help: String = _text(studio._modal_body)
	t.assert_true(help.contains("부탁 카드"), "Actual help describes a commission as a readable request card")
	var next: Button = _button(studio._modal, "다음 설명")
	t.assert_not_null(next, "Short help steps expose a next action")
	if next != null: next.pressed.emit()
	next = _button(studio._modal, "다음 설명")
	if next != null: next.pressed.emit()
	t.assert_true(_text(studio._modal_body).contains("가로 받침"), "The third help step explains structural support using child-friendly terminology")
	t.assert_true(studio._costs.text.contains("집 전체 약속한 돈  100,000,000원"), "The full contract amount is explicitly labeled")
	t.assert_true(studio._costs.text.contains("먼저 받은 돈  40,000,000원"), "The displayed advance equals the actual forty-million-won payment")
	studio._show_glossary()
	var glossary: String = _text(studio._modal_body)
	for term: String in ["가로 받침", "누르는 무게", "먼저 받는 돈", "평행", "보상 받기"]:
		t.assert_true(glossary.contains(term), "The visible glossary exposes a meaningful explanation: " + term)
	t.assert_false(studio.canvas.editing_enabled, "Reading the glossary owns input while a house is being built")
	studio.free()
	await t.get_tree().process_frame

static func _test_completed_house_gallery(t: Node) -> void:
	var company: State = _earned_company(t)
	var studio: Studio = Studio.new()
	studio.testing = true
	studio.state = company
	var path: String = "res://.godot/construction_game_ui_%d.json" % Time.get_ticks_usec()
	studio.save_path = path
	t.add_child(studio)
	await _frames(t, 3)
	studio._close_modal()
	studio._start_inspection()
	for frame: int in range(300):
		await t.get_tree().physics_frame
		if not studio.canvas.inspection_running: break
	await _frames(t, 2)
	t.assert_true(bool(studio._last_report.get("stable", false)), "The award UI fixture passes a real physics inspection")
	t.assert_true(bool(company.evaluate(studio._last_report).can_submit), "The highest-stage award UI uses a genuinely deliverable house")
	studio._submit()
	await _frames(t, 2)
	t.assert_eq(company.phase, "settled", "The completed-house popup follows an atomic legitimate settlement")
	t.assert_eq(int(company.last_result.get("award", {}).get("tier", 0)), 5, "A real high-quality house receives its saved fifth-tier badge")
	t.assert_true(_text(studio._modal).contains("명예의 전당"), "The actual completion popup announces hall-of-fame selection")
	var export: Button = _button(studio._modal, "배지와 함께 PNG 저장")
	t.assert_not_null(export, "An awarded completed house exposes the badge PNG action")
	var completed: Dictionary = company.serialize()
	if export != null: export.pressed.emit()
	t.assert_false(studio._exporting, "The PNG action returns safely in a headless test session")
	t.assert_eq(company.serialize(), completed, "Opening an image export never edits the paid house or its money")
	studio._show_hall()
	await _frames(t, 2)
	t.assert_true(studio._hall_only, "The hall button opens a filtered gallery rather than the whole ledger")
	t.assert_gt(_previews(studio._modal_body).size(), 0, "Earned award records render their real house previews in the hall")
	var awarded_index: int = company.records.size() - 1
	studio._show_record(awarded_index)
	await _frames(t, 2)
	t.assert_not_null(_button(studio._modal, "배지와 함께 PNG 저장"), "Reopening a saved awarded house keeps its earned badge export action")
	studio._close_modal()
	t.assert_true(company.select_contract(0), "A successful high-stage builder can return to a first-stage client")
	_finish_offer(t, company)
	var repeat_index: int = company.records.size() - 1
	t.assert_true(repeat_index > 0, "The repeated first offer has a different project index")
	t.assert_true(studio.save_game(false), "The completed repeated-offer ledger saves through the actual UI")
	t.assert_true(studio.load_game(false), "The actual UI restores repeated offers and award metadata")
	studio._show_record(repeat_index)
	await _frames(t, 2)
	var previews: Array[Canvas] = _previews(studio._modal_body)
	t.assert_eq(previews.size(), 1, "Opening the repeated saved offer shows exactly its actual house")
	if not previews.is_empty():
		t.assert_eq(previews[0].document.budget_limit, int(Catalog.contract(0).material_budget), "Saved house previews reconstruct the chosen offer's budget rather than the project index")
		t.assert_eq(previews[0].document.material_cost(), int(company.records[repeat_index].material_cost), "The repeated saved preview retains the paid material geometry")
	t.assert_true(_text(studio._modal).contains(str(Catalog.contract(0).client)), "The repeated saved house retains its original client")
	t.assert_not_null(_button(studio._modal, "집 PNG 저장"), "A lower-stage repeated house exports without an unearned badge")
	t.assert_eq(int(company.records[repeat_index].award.tier), 0, "Returning to stage one never invents a hall badge")
	studio._close_modal()
	studio._enter_my_house_mode()
	t.assert_true(company.my_house_mode, "Entering My Own House mode switches the studio to personal building")
	t.assert_eq(company.my_house_budget(), company.saved_balance(), "My Own House mode is funded by the player's earned commission assets")
	studio._add_material("foundation")
	studio._add_material("wall_panel")
	t.assert_gt(company.my_house_cost(), 0, "Placing materials in My Own House mode uses the earned asset budget")
	t.assert_eq(company.my_house_available_balance(), company.my_house_budget() - company.my_house_cost(), "Available personal budget deducts placed My Own House parts")
	t.assert_true(studio._my_house_export.visible, "My Own House mode exposes the PNG save button")
	studio._export_my_house()
	t.assert_false(studio._exporting, "Exporting My Own House to PNG completes safely in headless mode")
	t.assert_true(studio.save_game(false), "My Own House design saves alongside commission progress")
	t.assert_true(studio.load_game(false), "My Own House design restores cleanly from save")
	t.assert_eq(studio.state.my_house_document.parts.size(), 2, "Restored My Own House preserves placed personal building parts")
	studio._exit_my_house_mode()
	t.assert_false(studio.state.my_house_mode, "Exiting My Own House mode returns to client commission mode")
	studio.free()
	await t.get_tree().process_frame
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)

static func _earned_company(t: Node) -> State:
	var company: State = State.new()
	for stage: int in range(1, 10):
		var attempts: int = 0
		while not bool(company.stage_unlock_status(stage).unlocked) and attempts < 20:
			t.assert_true(company.repeat_contract(), "Lower-stage paid work can fund the next legitimate UI fixture stage")
			_finish_offer(t, company)
			attempts += 1
		t.assert_true(company.stage_unlock_status(stage).unlocked, "Each UI fixture stage is earned through real paid ledger entries")
		t.assert_true(company.select_contract(stage - 1), "The UI fixture chooses an actually unlocked offer")
		if stage < 9:
			_finish_offer(t, company)
		else:
			t.assert_true(company.accept_contract(), "The highest UI fixture offer is accepted under normal rules")
			t.assert_true(company.document.replace_parts(AwardFixture.excellent_document().parts), "The highest UI fixture buys its real affordable house")
	return company

static func _finish_offer(t: Node, company: State) -> void:
	t.assert_true(company.accept_contract(), "A repeated UI fixture commission can be accepted exactly once")
	t.assert_true(company.document.replace_parts(Guide.example_for_contract(company.current_contract())), "UI fixture earnings come from valid catalog houses")
	var ids: Array[int] = []
	for part: Dictionary in company.document.parts: ids.append(int(part.id))
	var report: Dictionary = {"stable": true, "stable_ids": ids, "unsupported_ids": [], "revision": company.document.revision}
	t.assert_false(company.settle(report).is_empty(), "Every UI fixture profit is backed by a validated paid house record")

static func _previews(node: Node) -> Array[Canvas]:
	var result: Array[Canvas] = []
	for child: Node in node.get_children():
		if child is Canvas: result.append(child as Canvas)
		result.append_array(_previews(child))
	return result

static func _text(node: Node) -> String:
	var result: String = str(node.text) + "\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result += _text(child)
	return result

static func _button(node: Node, text: String) -> Button:
	if node is Button and str(node.text) == text: return node as Button
	for child: Node in node.get_children():
		var found: Button = _button(child, text)
		if found != null: return found
	return null

static func _frames(t: Node, count: int) -> void:
	for frame: int in range(count): await t.get_tree().process_frame
