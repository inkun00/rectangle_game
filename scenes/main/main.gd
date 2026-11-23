class_name QuadrilateralApp
extends Node

const StartupQuestions = preload("res://scripts/learning/learning_question_bank.gd")
const StartupQuestionSet = preload("res://scripts/learning/startup_question_set.gd")
const StartupDailyCompletion = preload("res://scripts/learning/startup_daily_completion.gd")
const StartupLearning = preload("res://scenes/learning/learning_gate.gd")

var testing: bool = false
var _art_sale_transaction: Callable = ProgressionTransactions.commit
var _art_submission_busy: bool = false
var _art_publications: ArtPublicationStore = ArtPublicationStore.new()
var _art_upload_transport: Callable = Callable()
var _art_upload_busy: bool = false
var _building_upload_busy: bool = false
var _building_png_busy: bool = false
var _building_png_directory: String = "user://published_buildings"
var _building_png_renderer: Callable = Callable()
const ENDING_ACTIVITY_TARGET: int = 10
const ENDING_PNG_DIRECTORY: String = "user://story_endings"
const EndingDialog = preload("res://scenes/ui/story_completion_dialog.gd")
var _ending_dialog: StoryCompletionDialog
var _ending_scene: StoryEnding
var _ending_branch: String = ""
var _ending_offer: Dictionary = {}
var _ending_busy: bool = false
var _ship_png_busy: bool = false
var _ending_png_directory: String = ENDING_PNG_DIRECTORY
var _ending_png_renderer: Callable = Callable()
var learning_progress: LearningProgress = LearningProgress.new()
var _learning_screen: LearningStudio
var _startup_learning: StartupLearning
var _startup_question: Dictionary = {}
var _startup_variants: Array[int] = []
var _startup_type_index: int = 0
var journal: QuestJournal
var adventure: AdventureState
var world: QuadrilateralWorld
var _sound: SoundManager
var _ui: Control
var _ui_layer: CanvasLayer
var _ui_scale: float = 1.0
var _compact_hud: bool = false
var _identity_panel: PanelContainer
var _region_panel: PanelContainer
var _quest_panel: PanelContainer
var _quest_heading: Label
var _quest_open_button: Button
var _hud_bottom: PanelContainer
var _hud_actions: HBoxContainer
var _touch_row: HBoxContainer
var _touch_buttons: Dictionary = {}
var _touch_fingers: Dictionary = {}
var _hud_controls: Label
var _hud_buttons: Array[Button] = []
var _modal_panel: PanelContainer
var _modal_height: float = 680.0
var _modal_scroll: ScrollContainer
var _modal_close: Button
var _modal_focus_before: Control
var _journal_filter: String = "active"
var _home_screen: HomePage
var _drawing_screen: DrawingStudio
var _construction_screen: ConstructionStudio
var _world_hud: Control
var _modal_overlay: Control
var _modal_body: VBoxContainer
var _toast: Label
var _toast_timer: Timer
var _autosave: Timer
var _world_stats: Label
var _world_region: Label
var _active_quests: Label
var _health_label: Label
var _xp_label: Label
var _level_label: Label
var _health_bar: ProgressBar
var _xp_bar: ProgressBar
var _potion_button: Button
var _pickup_button: Button
var _guidance: Label
var _story_label: Label
var _tracked_quest: String = ""
var _guidance_clock: float = 0.0
var _world_data: Dictionary = {}
var _in_world: bool = false
## The v1 save format includes the retired editor. Preserve old artwork on subsequent saves.
var _legacy_editor: Dictionary = {"version": 1, "template_id": "robot", "shapes": [], "selected_id": -1}
var _restoring: bool = false
var _save_clock: float = 0.0
var _tutorial: TutorialDirector
var _opening_screen: OpeningIntro
var _opening_preferences: OpeningPreferences = OpeningPreferences.new()
var _space_screen: SpaceHangar
## Production web builds mount each feature before its first screen is built.
var defer_feature_screens_for_testing: bool = false
var show_startup_learning_for_testing: bool = false
var startup_completion_path: String = StartupDailyCompletion.SAVE_PATH
var _resource_pack_loader: Callable = Callable()
var _defer_features: bool = false
var _economy_state: ConstructionState
var _construction_load_result: Dictionary = {}
var _feature_navigation: int = 0
var _feature_request: String = ""
var _feature_loading_overlay: Control
var _feature_loading_label: Label
var _feature_focus_before: Control

func _ready() -> void:
	get_window().title = QuadTheme.GAME_TITLE
	if not testing and not learning_progress.load_file():
		learning_progress.touch_controls = DisplayServer.is_touchscreen_available()
	journal = QuestJournal.new()
	adventure = AdventureState.new()
	_defer_features = defer_feature_screens_for_testing or (not testing and WebResourcePacks.is_web_delivery())
	_economy_state = ConstructionState.new()
	if not testing: _load_publications()
	if _defer_features and not testing:
		_construction_load_result = ConstructionSaveStore.load_into(ConstructionStudio.SAVE_PATH, _economy_state)
	_economy_state.changed.connect(_economy_changed)
	_sound = SoundManager.new()
	add_child(_sound)
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Theme.new()
	_ui.theme.default_font = QuadTheme.FONT
	ButtonArt.install(_ui.theme)
	get_window().theme = _ui.theme
	_ui_layer.add_child(_ui)
	_build_home()
	if not _defer_features:
		# Restore the ledger before the drawing screen checks its saved commission time.
		_build_construction()
		_build_drawing()
		_build_space()
	_build_learning()
	_build_world_hud()
	_build_toast()
	_autosave = Timer.new()
	_autosave.one_shot = true
	_autosave.wait_time = 0.7
	_autosave.timeout.connect(func(): _save(false))
	add_child(_autosave)
	_tutorial = TutorialDirector.new()
	add_child(_tutorial)
	_tutorial.setup(self)
	_economy_changed()
	journal.changed.connect(_journal_changed)
	adventure.changed.connect(_adventure_changed)
	get_viewport().size_changed.connect(func(): call_deferred("_responsive"))
	if not testing: _load(false)
	_journal_changed()
	_adventure_changed()
	learning_progress.changed.connect(_learning_changed)
	if (not testing or show_startup_learning_for_testing) and not StartupDailyCompletion.completed_today(startup_completion_path):
		_start_learning_gate()
	else:
		_start_game_session()

func _start_learning_gate() -> void:
	_leave_activity()
	_startup_type_index = 0
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	_startup_variants = StartupQuestionSet.pick(random)
	_startup_learning = StartupLearning.new()
	_startup_learning.answer_submitted.connect(_answer_startup_question)
	_ui.add_child(_startup_learning)
	_responsive()
	_present_startup_question()

func _present_startup_question(feedback: String = "") -> void:
	var type_id: String = StartupQuestions.TYPES[_startup_type_index]
	_startup_question = StartupQuestions.question(type_id, _startup_variants[_startup_type_index])
	_startup_learning.present(_startup_question, _startup_type_index + 1, StartupQuestions.TYPES.size(), feedback)

func _answer_startup_question(correct: bool) -> void:
	if not is_instance_valid(_startup_learning): return
	if not correct:
		var hint: String = str(_startup_question.hint)
		_startup_variants[_startup_type_index] = StartupQuestions.next_index(_startup_variants[_startup_type_index])
		_present_startup_question("앞 문제의 힌트 · " + hint + " 같은 주제의 새 문제를 풀어 봐요.")
		return
	_startup_type_index += 1
	if _startup_type_index < StartupQuestions.TYPES.size():
		_present_startup_question("맞았어요! 다음 문제를 풀어 보세요.")
		return
	var saved: bool = StartupDailyCompletion.mark_completed(startup_completion_path)
	_startup_learning.hide()
	_startup_learning.queue_free()
	_startup_learning = null
	_start_game_session()
	if not saved:
		_show_toast("오늘의 풀이 기록을 저장하지 못했어요. 다음에 열면 문제가 다시 나올 수 있어요.")

func _start_game_session() -> void:
	_show_home()
	# Rendering smoke tests use command-line flags, never bypass player-facing validation.
	if "--quad-preview-world" in OS.get_cmdline_user_args():
		_enter_world()
	elif "--quad-preview-drawing" in OS.get_cmdline_user_args():
		_show_drawing()
	elif "--quad-preview-construction" in OS.get_cmdline_user_args():
		_show_construction()
	else:
		if not testing: _opening_preferences.load_file()
		if _opening_preferences.should_offer(testing, OS.get_cmdline_user_args()):
			_show_opening()

func _build_home() -> void:
	_home_screen = HomePage.new()
	_home_screen.drawing_requested.connect(_show_drawing)
	_home_screen.adventure_requested.connect(_enter_world)
	_home_screen.construction_requested.connect(_show_construction)
	_home_screen.notebook_requested.connect(_show_notebook)
	_home_screen.tutorials_requested.connect(_show_tutorials)
	_home_screen.opening_requested.connect(_show_opening)
	_home_screen.ending_choice_requested.connect(_show_ending_choices)
	_ui.add_child(_home_screen)

func _build_learning() -> void:
	_learning_screen = LearningStudio.new()
	_learning_screen.progress = learning_progress
	_learning_screen.home_requested.connect(_show_home)
	_learning_screen.drawing_requested.connect(_show_drawing)
	_learning_screen.hide()
	_ui.add_child(_learning_screen)

func _show_learning(id: String = "") -> void:
	if is_instance_valid(_startup_learning): return
	_leave_activity()
	_learning_screen.show()
	_learning_screen.open_lesson(learning_progress.next_lesson() if id.is_empty() else id)
	_responsive()
	_tutorial.visit("learning")

func _learning_changed() -> void:
	if world != null:
		world.peaceful = learning_progress.peaceful or (_tutorial.active and _tutorial.mode == "world")
		if not learning_progress.touch_controls: _clear_touch_inputs()
	if is_instance_valid(_touch_row):
		_touch_row.visible = learning_progress.touch_controls
		_layout_hud(_ui_size())
	if not testing: learning_progress.save_file()

func _build_drawing() -> void:
	if is_instance_valid(_drawing_screen): return
	_drawing_screen = DrawingStudio.new()
	_drawing_screen.testing = testing
	_drawing_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawing_screen.home_requested.connect(_show_home)
	_drawing_screen.hide()
	_ui.add_child(_drawing_screen)
	_drawing_screen.configure_economy(_economy_state)
	_drawing_screen.art_commission_requested.connect(_accept_art_commission)
	_drawing_screen.art_sale_requested.connect(_sell_art)
	_drawing_screen.drawing_exhibition_requested.connect(_exhibit_drawing)
	_drawing_screen.art_upload_retry_requested.connect(_retry_art_uploads)
	if not testing:
		var restored: Dictionary = _load_publications()
		if bool(restored.ok):
			_drawing_screen.sale_author_name = _art_publications.last_author()
			_retry_art_uploads.call_deferred()
		else: _drawing_screen.set_upload_status(str(restored.error))
	if _tutorial != null: _tutorial.bind_drawing()

func _build_construction() -> void:
	if is_instance_valid(_construction_screen): return
	_construction_screen = ConstructionStudio.new()
	_construction_screen.testing = testing
	_construction_screen.state = _economy_state
	_construction_screen.load_on_ready = not _defer_features
	_construction_screen.home_requested.connect(_show_home)
	_construction_screen.building_publication_requested.connect(_publish_building)
	_construction_screen.building_upload_retry_requested.connect(_retry_building_uploads)
	_construction_screen.earth_ending_requested.connect(_finish_earth_house)
	_construction_screen.hide()
	_ui.add_child(_construction_screen)
	if not testing:
		var restored: Dictionary = _load_publications()
		if bool(restored.ok):
			_construction_screen.publication_author_name = _art_publications.last_author()
			_retry_building_uploads.call_deferred()
		else: _construction_screen.set_building_upload_status(str(restored.error))
	if _tutorial != null: _tutorial.bind_construction()
	if bool(_construction_load_result.get("recovered", false)):
		_construction_screen._set_status(str(_construction_load_result.get("message", "건축 기록을 복구했어요.")))
	elif not _construction_load_result.is_empty() and not bool(_construction_load_result.get("ok", false)) and ConstructionSaveStore.has_save(_economy_save_path()):
		_construction_screen._set_status(str(_construction_load_result.get("error", "건축 기록을 확인하지 못했어요.")))
	_economy_changed()

func _build_space() -> void:
	if is_instance_valid(_space_screen): return
	_space_screen = SpaceHangar.new()
	_space_screen.state = _economy_state
	_space_screen.managed_endings = true
	_space_screen.home_requested.connect(_show_home)
	_space_screen.drawing_requested.connect(_show_drawing)
	_space_screen.construction_requested.connect(_show_construction)
	_space_screen.village_requested.connect(_enter_world)
	_space_screen.purchase_requested.connect(_purchase_ship_part)
	_space_screen.appearance_requested.connect(_save_ship_appearance)
	_space_screen.export_requested.connect(_save_ship_png)
	_space_screen.launch_requested.connect(_launch_ship)
	_space_screen.hide()
	_ui.add_child(_space_screen)
	_economy_changed()

func _economy_changed() -> void:
	var earth: Dictionary = _art_publications.ending_entry("earth")
	var space: Dictionary = _art_publications.ending_entry("space")
	if is_instance_valid(_home_screen):
		var has_saved_ending: bool = not earth.is_empty() or not space.is_empty() or _economy_state.launched
		_home_screen.set_ending_progress(_economy_state.art_sales.size(), _economy_state.records.size(), ENDING_ACTIVITY_TARGET, has_saved_ending)
	if is_instance_valid(_construction_screen):
		var unlocked: bool = _ending_unlocked() or not earth.is_empty()
		if _construction_screen.earth_ending_unlocked != unlocked:
			_construction_screen.earth_ending_unlocked = unlocked
			_construction_screen._refresh()
	if is_instance_valid(_space_screen):
		_space_screen.ending_saved = space.get("status") == "published"
		_space_screen.refresh()

func _ending_unlocked() -> bool:
	return _economy_state.art_sales.size() + _economy_state.records.size() >= ENDING_ACTIVITY_TARGET

func _ending_locked_message() -> String:
	return "그림과 건축 의뢰 완료를 합쳐 %d회 달성하면 엔딩을 선택할 수 있어요." % ENDING_ACTIVITY_TARGET

func _show_ending_choices() -> void:
	if is_instance_valid(_startup_learning): return
	var earth: Dictionary = _art_publications.ending_entry("earth")
	var space: Dictionary = _art_publications.ending_entry("space")
	var unlocked: bool = _ending_unlocked()
	if not unlocked and earth.is_empty() and space.is_empty() and not _economy_state.launched:
		_show_toast(_ending_locked_message())
		return
	var body: VBoxContainer = _open_modal(HomePage.ENDING_CHOICE_TITLE)
	var guidance: String = "나만의 작품을 만들거나 사각이의 다음 이야기를 골라요." if unlocked else _ending_locked_message()
	body.add_child(QuadTheme.paragraph(guidance, 18, QuadTheme.INK))
	var home_card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
	var home_note: String = "지구에 남아 살 집을 지어요.\n집 짓기 자금 · %s" % ConstructionCatalog.format_won(_economy_state.my_house_available_balance())
	home_card.add_child(QuadTheme.paragraph(_ending_branch_note(earth, home_note), 17, QuadTheme.INK))
	var earth_button: Button = QuadTheme.button("나만의 집 짓기" if earth.is_empty() and unlocked else "지구에 남기", _choose_ending_branch.bind("earth"))
	earth_button.name = "ChooseEarthEnding"
	earth_button.disabled = not unlocked and earth.is_empty()
	home_card.add_child(earth_button)
	if unlocked and not earth.is_empty():
		var edit_home: Button = QuadTheme.button("나만의 집 짓기", _show_earth_house)
		edit_home.name = "OpenPersonalHouse"
		home_card.add_child(edit_home)
	if unlocked:
		var art_card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
		art_card.add_child(QuadTheme.paragraph("사각형으로 원하는 그림을 그리거나 명화 밑그림을 꾸며요.", 17, QuadTheme.INK))
		var art_button: Button = QuadTheme.button("나만의 그림", _show_drawing.bind(true))
		art_button.name = "OpenPersonalDrawing"
		art_card.add_child(art_button)
	var ship_card: VBoxContainer = QuadTheme.card(body, Color("eef4fa"), 14)
	var ship_note: String = "부품 12종을 골라 우주선을 만들어요.\n우주선 자금 · %s" % ConstructionCatalog.format_won(_economy_state.ship_available_funds())
	if _economy_state.launched and not unlocked: ship_note = "완성한 우주선으로 출발 이야기를 다시 봐요."
	ship_card.add_child(QuadTheme.paragraph(_ending_branch_note(space, ship_note), 17, QuadTheme.INK))
	var space_button: Button = QuadTheme.button("사각성으로 돌아가기", _choose_ending_branch.bind("space"))
	space_button.name = "ChooseSpaceEnding"
	space_button.disabled = not unlocked and space.is_empty() and not _economy_state.launched
	ship_card.add_child(space_button)
	if unlocked and not space.is_empty():
		var edit_ship: Button = QuadTheme.button("우주선 제작소 열기", _open_ship_workshop)
		edit_ship.name = "OpenShipWorkshop"
		ship_card.add_child(edit_ship)
	var keep_earning: Button = QuadTheme.button("계속 돈 모으기", _close_modal)
	keep_earning.name = "KeepEarning"
	body.add_child(keep_earning)

func _ending_branch_note(entry: Dictionary, description: String) -> String:
	if entry.is_empty(): return description
	return "완성한 작품이 나오는 엔딩을 다시 봐요." if entry.status == "published" else "저장한 작품으로 패들릿 등록을 이어서 해요."

func _choose_ending_branch(branch: String) -> void:
	if is_instance_valid(_startup_learning): return
	_close_modal()
	if not _art_publications.ending_entry(branch).is_empty():
		_resume_ending(branch)
	elif branch == "earth":
		await _show_earth_house()
	else:
		await _show_space(_economy_state.launched and not _ending_unlocked())

func _open_ship_workshop() -> void:
	_close_modal()
	await _show_space()

func _economy_save_path() -> String:
	return _construction_screen.save_path if is_instance_valid(_construction_screen) else ConstructionStudio.SAVE_PATH

func _accept_art_commission(id: String) -> void:
	if not is_instance_valid(_drawing_screen) or not _drawing_screen.is_visible_in_tree(): return
	if _drawing_screen.is_personal_drawing or _drawing_screen.tutorial_blocked or _drawing_screen._sale_pending or _art_submission_busy: return
	var result: Dictionary = ProgressionTransactions.commit(_economy_state, "accept_art_commission", id, _economy_save_path(), not testing)
	_drawing_screen.show_art_commission_result(result)

func _sell_art(data: Dictionary) -> void:
	if not is_instance_valid(_drawing_screen) or _art_submission_busy: return
	if not _drawing_screen.is_visible_in_tree() or _drawing_screen.is_personal_drawing or _drawing_screen.tutorial_blocked:
		_drawing_screen.show_sale_result({"ok": false, "error": "사각형 그림 화면에서 의뢰를 제출해 주세요."})
		return
	var commission: String = _economy_state.art_commission_id
	var revision: Variant = data.get("commission_revision")
	if commission.is_empty() or not revision is int or revision != _economy_state.art_commission_revision:
		_drawing_screen.show_sale_result({"ok": false, "error": "지금 맡은 그림 의뢰를 확인하고 다시 제출해 주세요."})
		return
	var metadata_error: String = ArtSubmissionMetadata.validation_error(data.get("author"), data.get("title"), data.get("description"))
	if not data.get("document") is Dictionary or not metadata_error.is_empty():
		_drawing_screen.show_sale_result({"ok": false, "error": metadata_error if not metadata_error.is_empty() else "그림을 확인해 주세요."})
		return
	var artwork: DrawingDocument = DrawingDocument.new()
	if not artwork.restore(data.document):
		_drawing_screen.show_sale_result({"ok": false, "error": "제출할 그림을 확인하지 못했어요."})
		return
	var offer: Dictionary = _economy_state.quote_art_commission(artwork)
	if not bool(offer.can_sell):
		_drawing_screen.show_sale_result({"ok": false, "error": str(offer.reason)})
		return
	_art_submission_busy = true
	var bytes: PackedByteArray = await _drawing_screen.render_sale_png(data.document)
	_art_submission_busy = false
	if not is_instance_valid(_drawing_screen): return
	if commission != _economy_state.art_commission_id or revision != _economy_state.art_commission_revision:
		_drawing_screen.show_sale_result({"ok": false, "error": "의뢰가 바뀌었어요. 지금 맡은 의뢰에 그림을 다시 제출해 주세요."})
		return
	if not _drawing_screen.is_visible_in_tree() or _drawing_screen.document.serialize() != data.document:
		_drawing_screen.show_sale_result({"ok": false, "error": "제출할 그림을 다시 확인해 주세요. 지금 그림은 그대로예요."})
		return
	var image_saved: Dictionary = SoldArtStore.save_png(bytes, str(data.title), _drawing_screen.sold_art_directory)
	if not bool(image_saved.ok):
		_drawing_screen.show_sale_result(image_saved)
		return
	# Persist the exact image and its publication metadata before payment. A
	# failed ledger write leaves this entry ineligible for uploading.
	var prepared: Dictionary = _art_publications.prepare(data, offer, image_saved, bytes)
	if not bool(prepared.ok):
		_drawing_screen.show_sale_result(prepared)
		return
	# A durable PNG precedes payment and clearing. Failed payment leaves both
	# the editable drawing and its exported copy available for a safe retry.
	var result: Dictionary = _art_sale_transaction.call(_economy_state, "sell_art", data, _economy_save_path(), not testing)
	if bool(result.get("ok", false)):
		result["png_path"] = str(image_saved.path)
		result["filename"] = str(image_saved.filename)
		if OS.has_feature("web"):
			JavaScriptBridge.download_buffer(bytes, str(image_saved.filename), "image/png")
	_drawing_screen.show_sale_result(result)
	if bool(result.get("ok", false)): _retry_art_uploads()

func _exhibit_drawing(data: Dictionary) -> void:
	if _art_submission_busy or not is_instance_valid(_drawing_screen) or not _drawing_screen.is_visible_in_tree(): return
	var error: String = ArtSubmissionMetadata.validation_error(data.get("author"), data.get("title"), data.get("description"))
	if not error.is_empty():
		_drawing_screen.show_exhibition_result({"ok": false, "error": error})
		return
	if _drawing_screen.document.shapes.is_empty() or data.get("document") != _drawing_screen.document.serialize():
		_drawing_screen.show_exhibition_result({"ok": false, "error": "전시할 그림을 다시 확인해 주세요."})
		return
	var restored: Dictionary = _load_publications()
	if not bool(restored.ok):
		_drawing_screen.show_exhibition_result(restored)
		return
	_art_submission_busy = true
	var bytes: PackedByteArray = await _drawing_screen.render_sale_png(data.document)
	_art_submission_busy = false
	if not is_instance_valid(_drawing_screen): return
	if not _drawing_screen.is_visible_in_tree() or data.document != _drawing_screen.document.serialize() or bytes.is_empty():
		_drawing_screen.show_exhibition_result({"ok": false, "error": "그림을 저장하지 못했어요. 그림을 확인하고 다시 시도해 주세요."})
		return
	var fingerprint: String = ("drawing:" + ArtPublicationStore._digest(bytes)).sha256_text()
	var previous: Dictionary = _art_publications.find_entry(fingerprint)
	if not previous.is_empty():
		_drawing_screen.show_exhibition_result({"ok": true, "message": "이 그림의 전시 기록을 찾았어요."})
		if previous.status == "pending": _retry_art_uploads()
		else: _drawing_screen.set_upload_status("이미 전시한 그림이에요.", _art_publications.pending(_economy_state.art_sales).size(), str(previous.post_url), _art_upload_busy)
		return
	var saved: Dictionary = SoldArtStore.save_png(bytes, str(data.title), _drawing_screen.sold_art_directory)
	if not bool(saved.ok):
		_drawing_screen.show_exhibition_result(saved)
		return
	var offer: Dictionary = {"kind": "drawing", "price": 0, "fingerprint": fingerprint}
	var prepared: Dictionary = _art_publications.prepare(data, offer, saved, bytes)
	if not bool(prepared.ok):
		_drawing_screen.show_exhibition_result(prepared)
		return
	_drawing_screen.show_exhibition_result({"ok": true, "message": "전시할 그림을 PNG로 저장했어요."})
	_retry_art_uploads()

func _publish_building(data: Dictionary) -> void:
	if _building_png_busy or not is_instance_valid(_construction_screen) or not _construction_screen.is_visible_in_tree(): return
	var offer: Dictionary = _construction_screen.building_publication_offer()
	var metadata_error: String = ArtSubmissionMetadata.validation_error(data.get("author"), data.get("title"), data.get("description"), true)
	if not metadata_error.is_empty():
		_construction_screen.show_building_publication_result({"ok": false, "error": metadata_error})
		return
	if not _matches_building_offer(data, offer):
		_construction_screen.show_building_publication_result({"ok": false, "error": "완성한 건물과 금액을 다시 확인해 주세요."})
		return
	var restored: Dictionary = _load_publications()
	if not bool(restored.ok):
		_construction_screen.show_building_publication_result(restored)
		return
	# Ignore selection and edit history when recognizing a previously posted design.
	var parts: Array = offer.document.parts.duplicate(true)
	for part: Dictionary in parts: part.erase("id")
	offer["fingerprint"] = JSON.stringify([offer.kind, offer.price, parts]).sha256_text()
	var previous: Dictionary = _art_publications.find_entry(str(offer.fingerprint))
	if not previous.is_empty():
		if previous.status == "pending":
			_construction_screen.show_building_publication_result({"ok": true})
			_retry_building_uploads()
		else:
			_construction_screen.show_building_publication_result({"ok": true, "message": "이미 패들릿에 올린 건물이에요."})
			_construction_screen.set_building_upload_status("이미 패들릿에 올린 건물이에요.", _art_publications.pending(_economy_state.art_sales, true).size(), str(previous.post_url), _building_upload_busy)
		return
	_building_png_busy = true
	var bytes: PackedByteArray
	if _building_png_renderer.is_valid():
		bytes = await _building_png_renderer.call(offer.document.duplicate(true))
	else:
		bytes = await _construction_screen.render_building_publication_png(offer.document)
	_building_png_busy = false
	if not is_instance_valid(_construction_screen): return
	if not _construction_screen.is_visible_in_tree() or not _matches_building_offer(data, _construction_screen.building_publication_offer()):
		_construction_screen.show_building_publication_result({"ok": false, "error": "건물 설계가 바뀌었어요. 완성한 건물을 다시 확인해 주세요."})
		return
	if bytes.is_empty():
		_construction_screen.show_building_publication_result({"ok": false, "error": "건물 PNG를 만들지 못했어요. 다시 시도해 주세요."})
		return
	var saved: Dictionary = SoldArtStore.save_png(bytes, str(data.title), _building_png_directory)
	if not bool(saved.ok):
		_construction_screen.show_building_publication_result(saved)
		return
	var prepared: Dictionary = _art_publications.prepare(data, offer, saved, bytes)
	if not bool(prepared.ok):
		_construction_screen.show_building_publication_result(prepared)
		return
	if OS.has_feature("web"): JavaScriptBridge.download_buffer(bytes, str(saved.filename), "image/png")
	_construction_screen.show_building_publication_result({
		"ok": true, "author": str(prepared.entry.author), "filename": str(saved.filename),
		"png_path": str(saved.path)
	})
	_retry_building_uploads()

func _matches_building_offer(data: Dictionary, offer: Dictionary) -> bool:
	return bool(offer.get("ok", false)) and data.get("document") == offer.document and data.get("kind") == offer.kind and data.get("price") == offer.price

func _load_publications() -> Dictionary:
	return {"ok": true} if _art_publications.loaded else _art_publications.load_file()

func _retry_art_uploads() -> void:
	await _retry_publications(false)

func _retry_building_uploads() -> void:
	await _retry_publications(true)

func _set_publication_status(buildings: bool, message: String, pending: int = 0, post_url: String = "", busy: bool = false) -> void:
	if buildings and is_instance_valid(_construction_screen):
		_construction_screen.set_building_upload_status(message, pending, post_url, busy)
	elif not buildings and is_instance_valid(_drawing_screen):
		_drawing_screen.set_upload_status(message, pending, post_url, busy)

func _retry_publications(buildings: bool) -> void:
	if buildings and (_building_upload_busy or not is_instance_valid(_construction_screen)): return
	if not buildings and (_art_upload_busy or not is_instance_valid(_drawing_screen)): return
	var restored: Dictionary = _load_publications()
	if not bool(restored.ok):
		_set_publication_status(buildings, str(restored.error))
		return
	var pending: Array[Dictionary] = _art_publications.pending(_economy_state.art_sales, buildings)
	if pending.is_empty():
		_set_publication_status(buildings, "")
		return
	if buildings: _building_upload_busy = true
	else: _art_upload_busy = true
	var directory: String = _building_png_directory if buildings else _drawing_screen.sold_art_directory
	var last_url: String = ""
	var moderated: bool = false
	var error: String = ""
	var attempted: Dictionary = {}
	while true:
		# Re-read between requests so sales completed during an upload are also
		# sent. Attempt each ID only once in this batch, including unresolved ones.
		pending = _art_publications.pending(_economy_state.art_sales, buildings)
		var entry: Dictionary = {}
		for candidate: Dictionary in pending:
			if not attempted.has(candidate.id):
				entry = candidate
				break
		if entry.is_empty(): break
		attempted[entry.id] = true
		var progress: String = "패들릿에 건물을 등록하고 있어요…" if buildings else "패들릿에 그림을 등록하고 있어요…"
		_set_publication_status(buildings, progress, pending.size(), "", true)
		var bytes: PackedByteArray = _art_publications.read_png(entry, directory)
		if bytes.is_empty():
			error = "저장한 PNG를 찾지 못했어요. 원본 파일을 확인해 주세요."
			continue
		var result: Dictionary
		if _art_upload_transport.is_valid():
			result = await _art_upload_transport.call(entry.duplicate(true), bytes)
		elif testing:
			result = {"ok": false, "error": "테스트에서는 패들릿에 실제 그림을 등록하지 않아요."}
		else:
			result = await PadletUploader.upload(self, entry, bytes)
		if not bool(result.get("ok", false)):
			error = str(result.get("error", "패들릿 등록을 다시 시도해 주세요."))
			if bool(result.get("item_error", false)): continue
			break
		last_url = str(result.get("post_url", ""))
		var saved: Dictionary = _art_publications.mark_published(str(entry.id), last_url)
		if not bool(saved.ok):
			error = "패들릿 등록 결과를 저장하지 못했어요. 다시 시도하면 같은 게시물을 확인해요."
			continue
		moderated = moderated or bool(result.get("moderation_pending", false))
	if buildings: _building_upload_busy = false
	else: _art_upload_busy = false
	var remaining: int = _art_publications.pending(_economy_state.art_sales, buildings).size()
	if not error.is_empty():
		_set_publication_status(buildings, "패들릿 등록 대기 %d개 · %s" % [remaining, error], remaining)
	else:
		_set_publication_status(buildings, "패들릿 등록 완료 · 보드 관리자 승인 대기" if moderated else "패들릿에 작품을 등록했어요.", remaining, last_url)

func _purchase_ship_part(id: String) -> void:
	if _ending_busy or not is_instance_valid(_space_screen) or not _space_screen.is_visible_in_tree(): return
	if not _ending_unlocked():
		_space_screen.show_transaction_result({"ok": false, "error": _ending_locked_message()})
		return
	var result: Dictionary = ProgressionTransactions.commit(_economy_state, "purchase_part", id, _economy_save_path(), not testing)
	_space_screen.show_transaction_result(result)

func _save_ship_appearance(appearance: Dictionary) -> void:
	if _ending_busy or not is_instance_valid(_space_screen) or not _space_screen.is_visible_in_tree(): return
	if not _ending_unlocked():
		_space_screen.show_appearance_result({"ok": false, "error": _ending_locked_message()})
		return
	var result: Dictionary = ProgressionTransactions.commit(_economy_state, "set_ship_appearance", appearance, _economy_save_path(), not testing)
	_space_screen.show_appearance_result(result)

func _save_ship_png() -> void:
	if _ship_png_busy or _ending_busy or testing or not _ending_unlocked(): return
	var offer: Dictionary = _current_ending_offer("space")
	if not bool(offer.ok): return
	_ship_png_busy = true
	_space_screen.show_appearance_result({"ok": true, "message": "지금 조립한 우주선을 PNG로 저장하고 있어요…"})
	var bytes: PackedByteArray = await _render_ending_png("space", offer)
	_ship_png_busy = false
	var directory: String = "user://saved_spaceships"
	if not OS.has_feature("web"):
		var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if not pictures.is_empty() and DirAccess.dir_exists_absolute(pictures):
			directory = pictures.path_join("사각형 월드").path_join("완성한 우주선")
	var result: Dictionary = SoldArtStore.save_png(bytes, "나의 우주선", directory)
	if bool(result.ok):
		if OS.has_feature("web"): JavaScriptBridge.download_buffer(bytes, str(result.filename), "image/png")
		result["message"] = "우주선 PNG를 저장했어요." if OS.has_feature("web") else "우주선 PNG 저장 · " + str(result.path)
	_space_screen.show_appearance_result(result)

func _launch_ship() -> void:
	if not is_instance_valid(_space_screen) or not _space_screen.is_visible_in_tree(): return
	if _economy_state.launched and _art_publications.ending_entry("space").is_empty():
		_space_screen.play_launch()
		return
	_open_ending_project("space")

func _finish_earth_house() -> void:
	if not is_instance_valid(_construction_screen) or not _construction_screen.is_visible_in_tree(): return
	_open_ending_project("earth")

func _current_ending_offer(branch: String) -> Dictionary:
	if branch == "earth" and is_instance_valid(_construction_screen) and _construction_screen.is_visible_in_tree():
		return _construction_screen.earth_ending_offer()
	if branch == "space" and is_instance_valid(_space_screen) and _space_screen.is_visible_in_tree() and _economy_state.ship_complete():
		return {"ok": true, "kind": "spaceship", "price": _economy_state.ship_spent(), "parts": _economy_state.purchased_ship_parts.duplicate(), "performance": _economy_state.ship_performance(), "appearance": _economy_state.ship_appearance.duplicate(true)}
	return {"ok": false, "error": "사각형 부품 12개를 모아 우주선을 완성해 주세요."}

func _open_ending_project(branch: String) -> void:
	if _ending_busy: return
	var restored: Dictionary = _load_publications()
	if not bool(restored.ok):
		_show_toast(str(restored.error))
		return
	var entry: Dictionary = _art_publications.ending_entry(branch)
	if not entry.is_empty():
		_resume_ending(branch)
		return
	if not _ending_unlocked():
		_show_toast(_ending_locked_message())
		return
	var offer: Dictionary = _current_ending_offer(branch)
	if not bool(offer.ok):
		if branch == "space": _space_screen.show_transaction_result(offer)
		else: _construction_screen._set_status(str(offer.error))
		return
	_ending_branch = branch
	_ending_offer = offer
	_ensure_ending_dialog()
	_ending_dialog.open_project(branch, int(offer.price), _art_publications.last_author())

func _ensure_ending_dialog() -> void:
	if is_instance_valid(_ending_dialog): return
	_ending_dialog = EndingDialog.new()
	_ending_dialog.theme = _ui.theme
	_ending_dialog.submission_requested.connect(_submit_ending_project)
	_ui.add_child(_ending_dialog)

func _resume_ending(branch: String) -> void:
	if _ending_busy: return
	var entry: Dictionary = _art_publications.ending_entry(branch)
	if entry.is_empty(): return
	if entry.status == "published":
		_show_story_ending(branch, entry)
		return
	_ending_branch = branch
	_ending_offer.clear()
	_ensure_ending_dialog()
	_ending_dialog.open_project(branch, int(entry.price), "", true)

func _submit_ending_project(metadata: Dictionary) -> void:
	if _ending_busy or not is_instance_valid(_ending_dialog) or not _ending_dialog.visible: return
	var branch: String = _ending_branch
	var entry: Dictionary = _art_publications.ending_entry(branch)
	_ending_busy = true
	if entry.is_empty():
		var error: String = EndingDialog.validation_error(branch, metadata.get("author"), metadata.get("title"), metadata.get("description"))
		if not error.is_empty():
			_ending_failed(error, false)
			return
		if _current_ending_offer(branch) != _ending_offer:
			_ending_failed("완성 작품이 바뀌었어요. 닫고 현재 작품으로 다시 열어 주세요.", false)
			return
		_ending_dialog.show_progress("완성한 작품을 PNG로 저장하고 있어요…")
		var bytes: PackedByteArray = await _render_ending_png(branch, _ending_offer)
		if bytes.is_empty() or _current_ending_offer(branch) != _ending_offer:
			_ending_failed("완성 작품 PNG를 저장하지 못했어요. 작품을 확인하고 다시 시도해 주세요.", false)
			return
		# Preserve the current project before writing the durable publication record.
		if not testing:
			var saved_project: Dictionary = ConstructionSaveStore.save(_economy_save_path(), _economy_state)
			if not bool(saved_project.ok):
				_ending_failed(str(saved_project.error), false)
				return
		var saved: Dictionary = SoldArtStore.save_png(bytes, str(metadata.title), _ending_png_directory)
		if not bool(saved.ok):
			_ending_failed(str(saved.error), false)
			return
		var publication: Dictionary = _ending_offer.duplicate(true)
		publication["fingerprint"] = ("story-ending:" + branch).sha256_text()
		if branch == "space":
			publication["ports"] = SpaceshipCanvas.exhaust_layout(publication.parts, publication.appearance)
		var prepared: Dictionary = _art_publications.prepare(metadata, publication, saved, bytes)
		if not bool(prepared.ok):
			_ending_failed(str(prepared.error), false)
			return
		entry = prepared.entry
		if OS.has_feature("web"): JavaScriptBridge.download_buffer(bytes, str(saved.filename), "image/png")
		_economy_changed()
	await _upload_ending_project(branch, entry)

func _render_ending_png(branch: String, offer: Dictionary) -> PackedByteArray:
	if _ending_png_renderer.is_valid(): return await _ending_png_renderer.call(branch, offer.duplicate(true))
	if branch == "space": return await SpaceshipCanvas.export_png(get_tree(), offer.parts, offer.appearance)
	var model: ConstructionDocument = ConstructionDocument.new()
	model.budget_limit = _economy_state.my_house_budget()
	if not model.restore(offer.document): return PackedByteArray()
	return await ConstructionExporter.export_ending_png(get_tree(), model)

func _upload_ending_project(branch: String, entry: Dictionary) -> void:
	var bytes: PackedByteArray = _art_publications.read_png(entry, _ending_png_directory)
	if bytes.is_empty():
		_ending_failed("저장한 완성 PNG를 찾지 못했어요.", true)
		return
	_ending_dialog.show_progress("패들릿에 완성 작품을 올리고 있어요…")
	var result: Dictionary
	if _art_upload_transport.is_valid(): result = await _art_upload_transport.call(entry.duplicate(true), bytes)
	elif testing: result = {"ok": false, "error": "테스트에서는 실제 게시물을 만들지 않아요."}
	else: result = await PadletUploader.upload(self, entry, bytes)
	if not bool(result.get("ok", false)):
		_ending_failed(str(result.get("error", "패들릿 등록을 마치지 못했어요.")) + " 저장한 작품으로 다시 시도할 수 있어요.", true)
		return
	var saved: Dictionary = _art_publications.mark_published(str(entry.id), str(result.get("post_url", "")))
	if not bool(saved.ok):
		_ending_failed(str(saved.error), true)
		return
	var show_now: bool = is_instance_valid(_ending_dialog) and _ending_dialog.visible
	_ending_busy = false
	_ending_dialog.hide()
	_economy_changed()
	if show_now: _show_story_ending(branch, _art_publications.ending_entry(branch))
	else: _show_toast("작품을 올렸어요. 메인 화면에서 엔딩을 다시 볼 수 있어요.")

func _ending_failed(message: String, saved: bool) -> void:
	_ending_busy = false
	_ending_dialog.show_failure(message, saved)

func _show_story_ending(branch: String, entry: Dictionary) -> void:
	if entry.is_empty(): return
	var bytes: PackedByteArray = _art_publications.read_png(entry, _ending_png_directory)
	var screen: StoryEnding = StoryEnding.new()
	if not screen.configure(branch, bytes, str(entry.title), str(entry.post_url), int(entry.get("performance", 12)), entry.get("ports", [])):
		screen.free()
		_show_toast("엔딩에 쓸 완성 PNG를 열지 못했어요.")
		return
	_leave_activity()
	_ending_scene = screen
	_ending_scene.home_requested.connect(_show_home)
	_ui.add_child(_ending_scene)
	_responsive()

func _show_space(replay_legacy: bool = false) -> void:
	if not _ending_unlocked() and not (replay_legacy and _economy_state.launched):
		_show_toast(_ending_locked_message())
		return
	if not await _ensure_feature("space"): return
	_build_space()
	_leave_activity()
	_space_screen.show()
	_space_screen.refresh()
	_responsive()
	if replay_legacy: _launch_ship()

func _ensure_feature(feature: String) -> bool:
	if is_instance_valid(_startup_learning): return false
	if not _defer_features: return true
	_feature_navigation += 1
	var ticket: int = _feature_navigation
	if not _feature_request.is_empty() and _feature_request != feature and not _resource_pack_loader.is_valid():
		WebResourcePacks.cancel(_feature_request)
	_feature_request = feature
	_show_feature_loading(feature)
	if world != null and _in_world: world.set_controls_enabled(false)
	var available: bool = false
	if _resource_pack_loader.is_valid():
		available = bool(await _resource_pack_loader.call(feature))
	else:
		available = await WebResourcePacks.ensure(feature)
	if ticket != _feature_navigation: return false
	_feature_request = ""
	_clear_feature_loading()
	if not available:
		_restore_feature_controls()
		_show_toast("자료를 내려받지 못했어요. 연결을 확인하고 다시 눌러 주세요.")
	return available

func _show_feature_loading(feature: String) -> void:
	var captions: Dictionary = {"drawing": "그림 도구", "construction": "집 짓기 재료", "space": "우주선 제작소", "adventure": "마을 주민 심부름하기"}
	if not is_instance_valid(_feature_loading_overlay):
		_feature_focus_before = get_viewport().gui_get_focus_owner()
		var shade: ColorRect = ColorRect.new()
		shade.name = "FeatureLoading"
		shade.color = Color(0.02, 0.04, 0.07, 0.88)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		shade.z_index = 2000
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ui.add_child(shade)
		_feature_loading_overlay = shade
		var center: CenterContainer = CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.add_child(center)
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", StarfrontArt.panel(0, 24))
		center.add_child(panel)
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 18)
		panel.add_child(column)
		_feature_loading_label = QuadTheme.paragraph("", 21, QuadTheme.INK)
		_feature_loading_label.custom_minimum_size.x = 300.0
		column.add_child(_feature_loading_label)
		var cancel_button: Button = QuadTheme.button("취소 · Esc", _cancel_feature_navigation)
		column.add_child(cancel_button)
		cancel_button.grab_focus()
	_feature_loading_label.text = str(captions.get(feature, "놀이 자료")) + "를 준비하고 있어요…"
	if _tutorial != null: _tutorial.refresh.call_deferred()

func _clear_feature_loading() -> void:
	if is_instance_valid(_feature_loading_overlay):
		_feature_loading_overlay.hide()
		_feature_loading_overlay.queue_free()
	_feature_loading_overlay = null
	_feature_loading_label = null
	if is_instance_valid(_feature_focus_before) and _feature_focus_before.is_visible_in_tree(): _feature_focus_before.grab_focus()
	_feature_focus_before = null
	if _tutorial != null: _tutorial.refresh.call_deferred()

func _restore_feature_controls() -> void:
	if world != null and _in_world:
		world.set_controls_enabled(not is_instance_valid(_modal_overlay) and (_tutorial == null or not _tutorial.blocks_gameplay()))

func _cancel_feature_navigation() -> void:
	_feature_navigation += 1
	if not _feature_request.is_empty() and not _resource_pack_loader.is_valid():
		WebResourcePacks.cancel(_feature_request)
	_feature_request = ""
	_clear_feature_loading()
	_restore_feature_controls()

func _leave_activity() -> void:
	_cancel_feature_navigation()
	if is_instance_valid(_ending_dialog): _ending_dialog.hide()
	if is_instance_valid(_ending_scene):
		_ending_scene.hide()
		_ending_scene.queue_free()
		_ending_scene = null
	if is_instance_valid(_opening_screen):
		_opening_screen.dismiss()
		_opening_screen.queue_free()
		_opening_screen = null
	if _tutorial != null: _tutorial.cancel()
	_clear_touch_inputs()
	_close_modal()
	var save_adventure: bool = _in_world
	if is_instance_valid(_drawing_screen) and _drawing_screen.visible:
		_drawing_screen.cancel_gesture()
		if not testing: _drawing_screen.save_drawing(false)
	if is_instance_valid(_construction_screen) and _construction_screen.visible:
		_construction_screen.cancel_activity()
	if world != null:
		_world_data = world.serialize()
		world.set_controls_enabled(false)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.hide()
		world.camera.enabled = false
	_in_world = false
	_home_screen.hide()
	if is_instance_valid(_drawing_screen): _drawing_screen.hide()
	if is_instance_valid(_construction_screen): _construction_screen.hide()
	if is_instance_valid(_space_screen): _space_screen.hide()
	if is_instance_valid(_learning_screen): _learning_screen.hide()
	_world_hud.hide()
	if _toast != null: _toast.hide()
	if save_adventure: _save(false)

func _show_home() -> void:
	if is_instance_valid(_startup_learning): return
	_leave_activity()
	_home_screen.show()
	_responsive()
	_home_screen.focus_primary()

func _show_opening() -> void:
	if is_instance_valid(_startup_learning): return
	_leave_activity()
	_opening_screen = OpeningIntro.new()
	_opening_screen.sound_enabled = _sound.sound_enabled
	_opening_screen.closed.connect(_opening_closed)
	_opening_screen.sound_changed.connect(func(enabled: bool): _sound.sound_enabled = enabled)
	_ui.add_child(_opening_screen)
	_responsive()

func _opening_closed(reason: String) -> void:
	if reason in ["completed", "skipped"]:
		_opening_preferences.seen = true
		if not testing: _opening_preferences.save_file()
	_show_home()
	if reason == "unavailable":
		_show_toast("영상을 재생할 수 없어요. 메인 화면에서 바로 시작해 주세요.")

func _show_drawing(personal: bool = false) -> void:
	if personal and not _ending_unlocked():
		_show_toast(_ending_locked_message())
		return
	if not await _ensure_feature("drawing"): return
	_build_drawing()
	_leave_activity()
	if not _drawing_screen.open_workspace(personal):
		_show_home()
		_show_toast("그림 기록을 열지 못했어요. 메인 화면에서 다시 시도해 주세요.")
		return
	_drawing_screen.show()
	_responsive()
	_tutorial.visit("masterpiece" if personal and _drawing_screen.document.drawing_mode == "masterpiece" else "drawing")

func _show_construction() -> void:
	await _open_construction(false)

func _show_earth_house() -> void:
	if not _ending_unlocked():
		_show_toast(_ending_locked_message())
		return
	await _open_construction(true)

func _open_construction(personal: bool) -> void:
	if not await _ensure_feature("construction"): return
	_build_construction()
	_leave_activity()
	if personal: _construction_screen.open_personal_mode()
	else: _construction_screen.open_commission_mode()
	_construction_screen.show()
	_responsive()
	_tutorial.visit("my_house" if personal else "construction")

func _process(delta: float) -> void:
	if _in_world:
		_guidance_clock += delta
		if _guidance_clock >= 0.15:
			_guidance_clock = 0.0
			_refresh_world_guidance()
		_save_clock += delta
		if _save_clock > 10.0:
			_save_clock = 0.0
			_save(false)

func _build_world_hud() -> void:
	_world_hud = Control.new()
	_world_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_hud.visible = false
	_ui.add_child(_world_hud)
	_identity_panel = PanelContainer.new()
	_identity_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 14))
	_world_hud.add_child(_identity_panel)
	var identity: HBoxContainer = HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	_identity_panel.add_child(identity)
	var portrait: AtlasTexture = AtlasTexture.new()
	portrait.atlas = load(SagakiArt.SHEET_PATH) as Texture2D
	portrait.region = Rect2(24, 18, 174, 142)
	portrait.filter_clip = true
	var portrait_view: TextureRect = GameArt.view(portrait, Vector2(60, 52))
	portrait_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	identity.add_child(portrait_view)
	var character_info: VBoxContainer = VBoxContainer.new()
	character_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_info.add_theme_constant_override("separation", 4)
	identity.add_child(character_info)
	_level_label = QuadTheme.label("", 22, QuadTheme.INK)
	character_info.add_child(_level_label)
	var gauges: GridContainer = GridContainer.new()
	gauges.columns = 2
	gauges.add_theme_constant_override("h_separation", 10)
	gauges.add_theme_constant_override("v_separation", 3)
	character_info.add_child(gauges)
	_health_label = QuadTheme.label("", 16, Color("ffbab0"))
	_xp_label = QuadTheme.label("", 16, QuadTheme.TEAL)
	gauges.add_child(_health_label)
	gauges.add_child(_xp_label)
	_health_bar = _rpg_bar(Color("ff6b79"), 7)
	_xp_bar = _rpg_bar(Color("74dfb0"), 7)
	gauges.add_child(_health_bar)
	gauges.add_child(_xp_bar)
	_region_panel = PanelContainer.new()
	_region_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 14))
	_world_hud.add_child(_region_panel)
	var region_info: VBoxContainer = VBoxContainer.new()
	region_info.add_theme_constant_override("separation", 5)
	_region_panel.add_child(region_info)
	_world_region = QuadTheme.paragraph("초록 마을", 22, QuadTheme.INK)
	_world_region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_world_region)
	_world_stats = QuadTheme.label("", 16, StarfrontArt.AMBER)
	_world_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_world_stats)
	_story_label = QuadTheme.paragraph("", 16, QuadTheme.MUTED)
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_info.add_child(_story_label)
	_quest_panel = PanelContainer.new()
	_quest_panel.add_theme_stylebox_override("panel", GameArt.panel(1, 16))
	_world_hud.add_child(_quest_panel)
	var qv: VBoxContainer = VBoxContainer.new()
	qv.add_theme_constant_override("separation", 8)
	_quest_panel.add_child(qv)
	var quest_header: HBoxContainer = HBoxContainer.new()
	quest_header.add_theme_constant_override("separation", 8)
	qv.add_child(quest_header)
	_quest_heading = QuadTheme.label("지금의 부탁", 18, QuadTheme.TEAL)
	_quest_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_header.add_child(_quest_heading)
	_quest_open_button = _rpg_button("수첩 J", _show_journal)
	_quest_open_button.tooltip_text = "부탁 수첩 열기"
	quest_header.add_child(_quest_open_button)
	_active_quests = QuadTheme.paragraph("", 17, Color("f7edd7"))
	qv.add_child(_active_quests)
	_guidance = QuadTheme.paragraph("", 16, StarfrontArt.AMBER)
	qv.add_child(_guidance)
	_hud_bottom = PanelContainer.new()
	_hud_bottom.add_theme_stylebox_override("panel", GameArt.panel(1, 12))
	_world_hud.add_child(_hud_bottom)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_hud_bottom.add_child(column)
	_hud_actions = HBoxContainer.new()
	_hud_actions.add_theme_constant_override("separation", 8)
	_hud_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_hud_actions)
	_pickup_button = _rpg_button("줍기 G", _pickup_nearest, 9)
	_add_hud_action(_pickup_button, "줍기 G", true)
	_add_hud_action(_rpg_button("대화 E", func():
		if world != null: world.interact(), 15), "대화 E", true)
	_add_hud_action(_rpg_button("공격 Z / F", func():
		if world != null: world.player.begin_attack(), 14), "공격 Z / F", false)
	_potion_button = _rpg_button("회복약 Q", _use_potion, 8)
	_add_hud_action(_potion_button, "회복약 Q", false)
	_add_hud_action(_rpg_button("가방 I", _show_inventory, 11), "가방 I", true)
	_add_hud_action(_rpg_button("메뉴", _show_game_menu), "메뉴", true)
	_touch_row = HBoxContainer.new()
	_touch_row.name = "TouchMovementControls"
	_touch_row.add_theme_constant_override("separation", 10)
	column.add_child(_touch_row)
	for action: String in ["left", "right", "jump"]:
		var caption: String = str({"left": "← 왼쪽", "right": "오른쪽 →", "jump": "점프"}[action])
		var button: Button = _rpg_button(caption, Callable())
		_touch_buttons[action] = button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_down.connect(func():
			if world != null: world.player.set_touch_control(action, true))
		button.button_up.connect(func():
			if world != null: world.player.set_touch_control(action, false))
		_touch_row.add_child(button)
	var touch_attack: Button = _rpg_button("공격", func():
		if world != null: world.player.begin_attack())
	touch_attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_touch_buttons["attack"] = touch_attack
	_touch_row.add_child(touch_attack)
	_touch_row.visible = learning_progress.touch_controls
	_hud_controls = QuadTheme.paragraph("", 16, QuadTheme.MUTED)
	_hud_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hud_controls)
	for panel: PanelContainer in [_identity_panel, _region_panel, _quest_panel, _hud_bottom]:
		panel.minimum_size_changed.connect(func(): call_deferred("_fit_hud_heights"))

func _add_hud_action(button: Button, caption: String, keep_compact: bool) -> void:
	button.set_meta("caption", caption)
	button.set_meta("compact", keep_compact)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_buttons.append(button)
	_hud_actions.add_child(button)

func _layout_hud(area: Vector2) -> void:
	if _identity_panel == null: return
	_compact_hud = area.x < 1180.0
	var touch_compact: bool = _compact_hud and learning_progress.touch_controls
	var narrow: bool = area.x < 640.0
	var gutter: float = 12.0 if _compact_hud else 20.0
	var identity_width: float = area.x - gutter * 2.0 if narrow else 332.0
	_identity_panel.position = Vector2(gutter, gutter)
	_identity_panel.size = Vector2(identity_width, 116)
	var region_width: float = area.x - gutter * 2.0 if narrow else (area.x - identity_width - gutter * 3.0 if _compact_hud else 360.0)
	_region_panel.position = Vector2(gutter if narrow else (area.x - region_width - gutter if _compact_hud else area.x * 0.5 - 180.0), 136.0 if narrow else gutter)
	_region_panel.size = Vector2(region_width, 90.0)
	_story_label.visible = not _compact_hud
	_quest_heading.get_parent().visible = not _compact_hud
	_active_quests.visible = not touch_compact
	_quest_panel.position = Vector2(gutter if _compact_hud else area.x - 340.0 - gutter, 240.0 if narrow else (144.0 if _compact_hud else gutter))
	_quest_panel.size = Vector2(minf(470.0, area.x - gutter * 2.0) if _compact_hud else 340.0, 0)
	for button: Button in _hud_buttons:
		var show_button: bool = not _compact_hud or bool(button.get_meta("compact", false))
		button.visible = show_button
		button.icon = button.get_meta("art_icon") if not _compact_hud and button.has_meta("art_icon") else null
		button.add_theme_font_size_override("font_size", 17 if _compact_hud else 18)
		var caption: String = str(button.get_meta("caption", button.text))
		button.text = caption.get_slice(" ", 0) if narrow else caption
	if _potion_button != null: _potion_button.text = "회복약 %d  Q" % adventure.potions
	_hud_controls.text = "방향키 이동 · Space 점프 · Z / F 공격 · Q 회복 · Tab 메뉴" if _compact_hud else "방향키 이동   ·   Space 점프   ·   J 부탁 수첩   ·   M 지도   ·   Tab 메뉴"
	_hud_controls.visible = not learning_progress.touch_controls
	call_deferred("_fit_hud_heights")

func _fit_hud_heights() -> void:
	# Wrapped text can become shorter after a resize; positioned panels must shrink too.
	for panel: PanelContainer in [_identity_panel, _region_panel, _quest_panel]:
		panel.size.y = panel.get_combined_minimum_size().y
	var gutter: float = 12.0 if _compact_hud else 20.0
	var area: Vector2 = _ui_size()
	if _compact_hud:
		var below_status: float = _identity_panel.get_rect().end.y + gutter
		if area.x < 640.0:
			_region_panel.position.y = below_status
			below_status = _region_panel.get_rect().end.y + gutter
		_quest_panel.position.y = below_status
	var hotbar_width: float = minf(1000.0, area.x - gutter * 2.0)
	_hud_bottom.size = Vector2(hotbar_width, _hud_bottom.get_combined_minimum_size().y)
	_hud_bottom.position = Vector2((area.x - hotbar_width) * 0.5, area.y - _hud_bottom.size.y - gutter)
	_layout_toast()

func _rpg_bar(tint: Color, height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(48, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	var back: StyleBoxTexture = StarfrontArt.gauge(7)
	back.modulate_color = Color("505565")
	var fill: StyleBoxTexture = StarfrontArt.gauge(6 if tint.r > tint.g else 7)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _rpg_button(text: String, callback: Callable, item_index: int = -1) -> Button:
	var button: Button = QuadTheme.button(text, callback)
	ButtonArt.apply(button, false, 18)
	button.focus_mode = Control.FOCUS_NONE
	if item_index >= 0:
		button.icon = GameArt.item(item_index)
		button.set_meta("art_icon", button.icon)
	return button

func _build_toast() -> void:
	_toast = QuadTheme.label("", 17, Color.WHITE)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_left = -370
	_toast.offset_right = 370
	_toast.offset_top = -174
	_toast.offset_bottom = -126
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", QuadTheme.style(Color("213b42f0"), 12, Color.TRANSPARENT, 12))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_ui.add_child(_toast)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 3.5
	_toast_timer.timeout.connect(func(): _toast.hide())
	add_child(_toast_timer)

func _show_toast(message: String) -> void:
	if _toast == null: return
	_toast.text = message
	_layout_toast()
	_toast.show()
	_ui.move_child(_toast, _ui.get_child_count() - 1)
	_toast_timer.start()

func _layout_toast() -> void:
	if _toast == null: return
	var toast_width: float = minf(740.0, _ui.size.x - 32.0)
	_toast.offset_left = -toast_width * 0.5
	_toast.offset_right = toast_width * 0.5
	var gap: float = _ui.size.y - _hud_bottom.position.y + 8.0 if _in_world else 24.0
	_toast.offset_bottom = -gap
	_toast.offset_top = -gap - maxf(48.0, _toast.get_combined_minimum_size().y)

func _journal_changed() -> void:
	if _world_stats == null: return
	_world_stats.text = "%d 코인   ·   친구 %d / %d" % [journal.coins, journal.completed_count(), QuestCatalog.all_quests().size()]
	var lines: PackedStringArray = PackedStringArray()
	for quest: Dictionary in QuestCatalog.all_quests():
		var id: String = String(quest["id"])
		var state: String = journal.quest_state(id)
		if state == "active" or state == "ready":
			lines.append(("● " if state == "ready" else "· ") + journal.progress_text(id))
	var shown_count: int = 1 if _compact_hud else 3
	if lines.size() > shown_count:
		var remaining: int = lines.size() - shown_count
		lines.resize(shown_count)
		lines.append("외 %d개의 부탁  ·  J로 모두 보기" % remaining)
	if lines.is_empty():
		_active_quests.text = "주민 곁에서 E를 눌러 부탁을 받아요." if journal.completed_count() < QuestCatalog.all_quests().size() else "모든 주민을 도왔어요!\n이야기 수첩에서 여행을 돌아봐요."
	else: _active_quests.text = "\n\n".join(lines)
	if not _restoring and _autosave != null: _autosave.start()

func _adventure_changed() -> void:
	if _health_label == null: return
	_health_label.text = "체력 %d/%d" % [adventure.hp, adventure.max_hp]
	_xp_label.text = "경험 %d/%d" % [adventure.xp_in_level(), adventure.xp_for_next_level()]
	_level_label.text = "사각이  ·  Lv. %d" % adventure.level
	_health_bar.max_value = adventure.max_hp
	_health_bar.value = adventure.hp
	_xp_bar.max_value = adventure.xp_for_next_level()
	_xp_bar.value = adventure.xp_in_level()
	_potion_button.text = "회복약 %d  Q" % adventure.potions
	if world != null: world.player.set_health(adventure.hp, adventure.max_hp, false)
	if not _restoring and _autosave != null: _autosave.start()

func _on_player_damaged(amount: int) -> void:
	adventure.damage(amount)

func _on_player_defeated() -> void:
	adventure.heal(adventure.max_hp)
	world.recover_at_checkpoint()
	_show_toast("쉼터에서 기운을 회복했어요. 코인과 모은 물건은 그대로예요!")

func _on_enemy_defeated(enemy_id: String) -> void:
	var old_level: int = adventure.level
	if adventure.record_enemy_defeat(enemy_id):
		_sound.play_create()
		_show_toast("레벨 업! LV. %d · 체력을 모두 회복했어요." % adventure.level if adventure.level > old_level else "사각형 몬스터를 물리쳤어요! +20 경험치")

func _use_potion() -> void:
	if adventure.use_potion():
		_sound.play_create()
		_show_toast("회복약으로 체력을 회복했어요.")
	else:
		_show_toast("체력이 이미 가득해요." if adventure.hp >= adventure.max_hp else "회복약이 없어요. 초록 마을의 상점을 찾아가요!")

func _pickup_nearest() -> void:
	if world == null or not _in_world or is_instance_valid(_modal_overlay): return
	if not world.pickup_nearest():
		_show_toast("물건 옆으로 다가가 G를 눌러요. 위쪽 발판은 Space로 올라갈 수 있어요.")

func _on_item_collected(label: String, quest_id: String, count: int, required: int) -> void:
	_sound.play_create()
	var quest: Dictionary = QuestCatalog.get_quest(quest_id)
	if journal.accepted.has(quest_id): _tracked_quest = quest_id
	var next_step: String = "모두 모았어요! %s에게 돌아가요." % str(quest["npc_name"]) if journal.can_turn_in(quest_id) else "가방 I에서 확인해요."
	if not journal.accepted.has(quest_id): next_step = "%s의 부탁에 쓸 수 있어요." % str(quest["npc_name"])
	_show_toast("주웠어요! %s  %d / %d\n%s" % [label, count, required, next_step])
	_refresh_world_guidance()

func _refresh_world_guidance() -> void:
	if world == null or not _in_world or _guidance == null: return
	var region: Dictionary = QuadrilateralWorld.region_at(world.player.position.x)
	var story: Dictionary = QuestCatalog.region_story(str(region["id"]))
	_story_label.text = str(story.get("title", "")) + "  ·  H 이야기"
	var nearby: Dictionary = world.nearby_pickup()
	_pickup_button.tooltip_text = "물건 옆에서 G를 눌러 주워요" if nearby.is_empty() else str(nearby.get("label", "물건")) + " 줍기"
	if _tracked_quest.is_empty() or journal.quest_state(_tracked_quest) == "completed":
		_tracked_quest = ""
		for quest: Dictionary in QuestCatalog.all_quests():
			if journal.quest_state(str(quest["id"])) in ["active", "ready"]:
				_tracked_quest = str(quest["id"])
				break
	var waypoint: Dictionary = _quest_waypoint(_tracked_quest)
	if not nearby.is_empty():
		_guidance.text = "G 줍기  ·  " + str(nearby.get("label", "물건"))
	elif not waypoint.is_empty():
		var offset: Vector2 = Vector2(waypoint["position"]) - world.player.position
		var direction: String = "왼쪽" if offset.x < -70.0 else ("오른쪽" if offset.x > 70.0 else "바로 근처")
		var vertical: String = " · 위쪽 발판으로 점프" if offset.y < -90.0 else ""
		_guidance.text = "%s\n%s %d걸음%s" % [waypoint["name"], direction, maxi(1, ceili(absf(offset.x) / 40.0)), vertical]
	else:
		_guidance.text = "빛나는 물건에 다가가거나 G로 주워요."

func _quest_waypoint(quest_id: String) -> Dictionary:
	if world == null or quest_id.is_empty(): return {}
	var quest: Dictionary = QuestCatalog.get_quest(quest_id)
	if quest.is_empty(): return {}
	if journal.quest_state(quest_id) != "active":
		for npc: Dictionary in world.npcs:
			if str(npc["quest"]) == quest_id:
				return {"position": npc["position"], "name": str(npc["name"]) + "에게 E로 대화"}
	var nearest: Dictionary = {}
	var distance: float = INF
	var collected: Array = world.serialize().get("collected", [])
	for item: Dictionary in world.collectibles:
		if str(item["quest"]) != quest_id or collected.has(str(item["id"])): continue
		var item_distance: float = world.player.position.distance_to(Vector2(item["position"]))
		if item_distance < distance:
			distance = item_distance
			nearest = {"position": item["position"], "name": str(item["label"]) + " 찾기"}
	return nearest

func _region_completed(region_id: String) -> bool:
	var total: int = 0
	for quest: Dictionary in QuestCatalog.all_quests():
		if str(quest["region"]) != region_id: continue
		total += 1
		if not journal.completed.has(str(quest["id"])): return false
	return total > 0

func _show_story() -> void:
	var body: VBoxContainer = _open_modal("이야기 수첩  ·  꺼진 별빛을 찾아서")
	body.add_child(QuadTheme.paragraph("사각형 축제를 앞두고 먼 성곽의 별빛이 꺼졌어요. 마을에서 만난 친구들의 작은 부탁이 항구, 설원, 성곽으로 이어져요. 여섯 지역을 자유롭게 탐험하며 이야기를 완성해 보세요.", 19, QuadTheme.INK))
	for region: Dictionary in QuadrilateralWorld.REGION_DATA:
		var id: String = str(region["id"])
		var story: Dictionary = QuestCatalog.region_story(id)
		var done: int = 0
		var total: int = 0
		for quest: Dictionary in QuestCatalog.all_quests():
			if str(quest["region"]) == id:
				total += 1
				if journal.completed.has(str(quest["id"])): done += 1
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 16)
		card.add_child(QuadTheme.label("%s  ·  %d / %d" % [story.get("title", region["name"]), done, total], 20, QuadTheme.TEAL))
		card.add_child(QuadTheme.paragraph(str(story.get("intro", "")), 17, QuadTheme.INK))
		if done == total:
			card.add_child(QuadTheme.paragraph("이야기 완성\n" + str(story.get("outro", "")), 17, QuadTheme.TEAL))
		else:
			card.add_child(QuadTheme.paragraph("주민들의 부탁을 마치면 다음 이야기가 기록돼요.", 14))
	body.add_child(QuadTheme.button("여행 지도 펼치기", _show_map, true))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal))

func _show_inventory() -> void:
	_tutorial.call_deferred("notify", "world_inventory")
	var body: VBoxContainer = _open_modal("모험가의 가방  ·  LV. %d" % adventure.level)
	var balance: HBoxContainer = HBoxContainer.new()
	balance.add_child(GameArt.view(GameArt.item(9)))
	balance.add_child(QuadTheme.label("%d 코인  ·  주민 %d / %d명 도움" % [journal.coins, journal.completed_count(), QuestCatalog.all_quests().size()], 21))
	body.add_child(balance)
	var medicine: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 16)
	var potion_row: HBoxContainer = HBoxContainer.new()
	potion_row.add_child(GameArt.view(GameArt.item(8), Vector2(64, 72)))
	potion_row.add_child(QuadTheme.paragraph("회복약 × %d\n체력 40 회복 · 단축키 Q\n현재 체력 %d / %d" % [adventure.potions, adventure.hp, adventure.max_hp], 17, QuadTheme.INK))
	medicine.add_child(potion_row)
	var use_button: Button = QuadTheme.button("회복약 사용", func():
		_use_potion()
		_show_inventory(), true)
	use_button.disabled = adventure.potions <= 0 or adventure.hp >= adventure.max_hp
	medicine.add_child(use_button)
	if use_button.disabled:
		medicine.add_child(QuadTheme.paragraph("체력이 가득해요. 다쳤을 때 사용해요." if adventure.hp >= adventure.max_hp else "회복약이 없어요. 초록 마을 잡화점에서 살 수 있어요.", 17))
	body.add_child(QuadTheme.label("퀘스트 물품", 22))
	var slots: GridContainer = GridContainer.new()
	slots.columns = 2 if _ui_size().x < 850.0 else 3
	slots.add_theme_constant_override("h_separation", 10)
	slots.add_theme_constant_override("v_separation", 10)
	body.add_child(slots)
	var found: bool = false
	for quest: Dictionary in QuestCatalog.all_quests():
		var target: String = String(quest["target"])
		var count: int = int(journal.inventory.get(target, 0))
		if count <= 0: continue
		found = true
		var slot: PanelContainer = PanelContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", StarfrontArt.panel(4, 12))
		slots.add_child(slot)
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		slot.add_child(content)
		content.add_child(GameArt.view(GameArt.quest_item(quest), Vector2(52, 52)))
		content.add_child(QuadTheme.paragraph("%s × %d" % [str(quest["item_name"]), count], 17, QuadTheme.INK))
		content.add_child(QuadTheme.paragraph("전달 준비 완료" if journal.can_turn_in(str(quest["id"])) else "모은 물건", 15, QuadTheme.TEAL))
	if not found:
		body.add_child(QuadTheme.paragraph("아직 모은 물건이 없어요. 빛나는 물건 옆에서 G를 누르거나 가까이 다가가 주워요. 부탁을 받기 전에도 모을 수 있어요.", 17))
	body.add_child(QuadTheme.button("부탁 수첩에서 필요한 물건 보기", _show_journal, true))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal))

func _show_service(service_id: String) -> void:
	if service_id == "travel":
		_show_travel()
		return
	var is_shop: bool = service_id == "shop"
	var body: VBoxContainer = _open_modal("네모 잡화점" if is_shop else "따뜻한 모험가 쉼터", 460.0)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(GameArt.view(GameArt.item(8) if is_shop else GameArt.cell("environment_atlas", 2, 4, 3), Vector2(120, 130)))
	row.add_child(QuadTheme.paragraph("모험을 떠나기 전에 가방을 채워요.\n회복약 한 병은 체력을 40 회복해요." if is_shop else "따뜻한 쉼터에서 쉬었다 가세요.\n휴식하면 체력을 모두 회복해요.", 21, QuadTheme.INK))
	body.add_child(row)
	body.add_child(QuadTheme.label("보유 코인 %d  ·  회복약 %d  ·  HP %d / %d" % [journal.coins, adventure.potions, adventure.hp, adventure.max_hp], 18))
	var cost: int = AdventureState.POTION_COST if is_shop else AdventureState.REST_COST
	var caption: String = ("%d 코인으로 회복약 구입" if is_shop else "%d 코인으로 충분히 쉬기") % cost
	if not is_shop and adventure.hp == 0:
		cost = 0
		caption = "무료로 기운 되찾기"
	var action: Button = QuadTheme.button(caption, func():
		if is_shop and adventure.purchase_potion(journal):
			_show_service(service_id)
			_show_toast("회복약 한 병을 가방에 넣었어요.")
		elif not is_shop and adventure.rest(journal):
			_close_modal()
			_show_toast("푹 쉬고 체력을 모두 회복했어요!")
		else:
			_show_service(service_id), true)
	body.add_child(action)
	var unavailable: String = ""
	if not is_shop and adventure.hp >= adventure.max_hp: unavailable = "체력이 가득해요. 다쳤을 때 쉬어 가요."
	elif is_shop and adventure.potions >= AdventureState.MAX_POTIONS: unavailable = "가방에 회복약이 가득해요."
	elif journal.coins < cost: unavailable = "%d코인이 더 필요해요. 주민의 부탁을 도와 코인을 모아요." % (cost - journal.coins)
	if not unavailable.is_empty():
		action.disabled = true
		body.add_child(QuadTheme.paragraph(unavailable, 16, StarfrontArt.AMBER))
	body.add_child(QuadTheme.button("다음에 다시 올게요", _close_modal))

func _show_travel() -> void:
	var body: VBoxContainer = _open_modal("사각형 관문  ·  빠른 이동")
	body.add_child(QuadTheme.paragraph("직접 방문한 지역의 관문으로 이동할 수 있어요. 처음 가는 길은 걸어서 발견해 보세요.", 18))
	for info: Dictionary in QuadrilateralWorld.REGION_DATA:
		var region_id: String = String(info["id"])
		var known: bool = adventure.discovered_regions.has(region_id)
		var button: Button = QuadTheme.button(String(info["name"]) + ("로 이동" if known else "  ·  아직 발견하지 않았어요"), func():
			if world != null and world.travel_to(region_id):
				_close_modal()
				_show_toast(String(info["name"]) + "에 도착했어요."))
		button.disabled = not known
		body.add_child(button)
	body.add_child(QuadTheme.button("걸어서 계속 탐험", _close_modal))

func _enter_world() -> void:
	if not await _ensure_feature("adventure"): return
	_leave_activity()
	if world == null:
		world = QuadrilateralWorld.new()
		world.setup(journal)
		add_child(world)
		world.interaction_requested.connect(_talk_to_npc)
		world.hint_requested.connect(_show_toast)
		world.item_collected.connect(_on_item_collected)
		world.region_changed.connect(func(region: String): _world_region.text = region)
		world.progress_changed.connect(func(): _autosave.start())
		world.service_requested.connect(_show_service)
		world.enemy_defeated.connect(_on_enemy_defeated)
		world.player.damaged.connect(_on_player_damaged)
		world.player.defeated.connect(_on_player_defeated)
		world.configure_adventure(adventure)
		if not _world_data.is_empty(): world.restore(_world_data)
	else:
		world.show()
		world.process_mode = Node.PROCESS_MODE_INHERIT
		world.set_controls_enabled(true)
	_in_world = true
	world.peaceful = learning_progress.peaceful
	_world_hud.show()
	_responsive()
	_adventure_changed()
	_world_region.text = world.get_current_region()
	_sound.play_create()
	_show_toast("E로 주민의 부탁을 받고 G로 물건을 주워요. 심부름을 마치면 집·우주선 자금이 쌓여요.")
	_refresh_world_guidance()
	_save(false)
	_tutorial.visit("world")

func _talk_to_npc(npc_id: String) -> void:
	for quest: Dictionary in QuestCatalog.all_quests():
		if String(quest["npc_id"]) == npc_id:
			_show_quest_dialog(quest)
			return

func _show_quest_dialog(quest: Dictionary) -> void:
	var id: String = String(quest["id"])
	var body: VBoxContainer = _open_modal(String(quest["npc_name"]) + "의 부탁")
	body.add_theme_constant_override("separation", 10)
	var portrait_row: HBoxContainer = HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 20)
	portrait_row.add_child(GameArt.view(GameArt.quest_npc(quest), Vector2(60, 68)))
	var identity: VBoxContainer = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(identity)
	identity.add_child(QuadTheme.label(String(quest["npc_name"]), 23, QuadTheme.TEAL))
	var reward_won: String = ConstructionCatalog.format_won(ConstructionState.village_reward_amount(id))
	identity.add_child(QuadTheme.paragraph("심부름 보상 %s · %d 코인 · %d 경험치" % [reward_won, int(quest["reward"]), int(quest["reward"]) * 2], 15))
	body.add_child(portrait_row)
	body.add_child(QuadTheme.label(String(quest["title"]), 25))
	var state: String = journal.quest_state(id)
	if state == "completed":
		body.add_child(QuadTheme.paragraph(str(quest.get("completion_story", "도와줘서 고마워요! 덕분에 별빛을 향해 한 걸음 더 나아갔어요.")) + "\n\n" + String(quest["explanation"]), 17, QuadTheme.INK))
	elif state == "ready":
		portrait_row.hide()
		body.add_child(QuadTheme.paragraph(String(quest["question"]), 20, QuadTheme.INK))
		var diagram: LearningCanvas = LearningCanvas.new()
		diagram.configure_question(id)
		body.add_child(diagram)
		var measure_row: HFlowContainer = HFlowContainer.new()
		measure_row.add_theme_constant_override("h_separation", 8)
		measure_row.add_theme_constant_override("v_separation", 6)
		body.add_child(measure_row)
		diagram.add_measure_buttons(measure_row)
		var measurements: Label = QuadTheme.paragraph("", 16, QuadTheme.INK)
		measurements.hide()
		diagram.changed.connect(func():
			measurements.visible = not diagram.measure_tools.tool_kind.is_empty()
			measurements.text = diagram.measurement_text())
		body.add_child(measurements)
		var feedback: Label = QuadTheme.paragraph("", 16, QuadTheme.TEAL)
		feedback.hide()
		var options: Array = quest["options"]
		for index: int in range(options.size()):
			var button: Button = QuadTheme.button(String(options[index]), Callable())
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.pressed.connect(func():
				var answer: Dictionary = journal.answer_quest(id, index)
				feedback.text = String(answer["message"])
				feedback.show()
				if bool(answer["correct"]):
					_sound.play_fanfare()
					_show_quest_success(quest, answer)
				else: _sound.play_click())
			body.add_child(button)
		body.add_child(feedback)
	else:
		body.add_child(QuadTheme.paragraph(String(quest["description"]), 18, QuadTheme.INK))
		if str(quest.get("story_description", "")) != str(quest.description):
			body.add_child(QuadTheme.button("이야기 더 읽기", func():
				var story: VBoxContainer = _open_modal(str(quest.npc_name) + "의 이야기")
				story.add_child(QuadTheme.paragraph(str(quest.story_description), 19, QuadTheme.INK))
				story.add_child(QuadTheme.button("부탁으로 돌아가기", _show_quest_dialog.bind(quest), true))))
		body.add_child(QuadTheme.paragraph("탐험 목표  ·  " + journal.progress_text(id), 16, QuadTheme.TEAL))
		body.add_child(QuadTheme.label("보상  ·  %s · %d 코인" % [reward_won, int(quest["reward"])], 15))
		if state == "available":
			body.add_child(QuadTheme.button("제가 도와드릴게요!", func():
				journal.accept_quest(id)
				_tracked_quest = id
				_close_modal()
				_sound.play_create()
				_show_toast("이미 물건을 모두 모았어요! 이 주민에게 다시 E로 대화해 전달해요." if journal.can_turn_in(id) else "부탁을 받았어요! 물건 옆에서 G로 줍고, 다 모으면 주민에게 돌아와요."), true))
		else:
			body.add_child(QuadTheme.paragraph("가까이에서 G를 눌러 물건을 줍거나 표식을 조사해요. 높은 곳은 Space로 올라가요. 다 모으면 다시 찾아와 주세요.", 15))
	body.add_child(QuadTheme.button("계속 탐험하기", _close_modal))

func _show_quest_success(quest: Dictionary, answer: Dictionary) -> void:
	adventure.claim_quest(String(quest["id"]))
	# Publish the quest receipt first. The economy can replay any missing
	# payouts from the completed journal, including after an interrupted save.
	var paid: Dictionary = _save(false)
	var body: VBoxContainer = _open_modal("고마워요, 사각이!")
	body.add_child(QuadTheme.label(String(quest["title"]) + " 완료", 24, QuadTheme.TEAL))
	body.add_child(QuadTheme.paragraph(String(answer["message"]), 18, QuadTheme.INK))
	body.add_child(QuadTheme.label("+ %d 코인  ·  도와준 친구 %d / %d" % [int(answer["reward"]), journal.completed_count(), QuestCatalog.all_quests().size()], 20, QuadTheme.TEAL))
	if bool(paid.get("ok", false)):
		body.add_child(QuadTheme.paragraph("집 짓기와 우주선 제작에 쓸 돈이 들어왔어요. +%s" % ConstructionCatalog.format_won(ConstructionState.village_reward_amount(str(quest.id))), 17, QuadTheme.INK))
	else:
		body.add_child(QuadTheme.paragraph("자금 기록을 저장하지 못했어요. 저장 공간을 확인하고 메뉴에서 다시 저장해 주세요.", 17, QuadTheme.INK))
	var chapter: Dictionary = QuestCatalog.region_story(str(quest["region"]))
	if _region_completed(str(quest["region"])):
		body.add_child(QuadTheme.paragraph(str(chapter.get("outro", "")), 18, QuadTheme.INK))
	if journal.completed_count() == QuestCatalog.all_quests().size():
		body.add_child(QuadTheme.paragraph("모든 지역에 별빛이 돌아왔어요! 서로 다른 사각형들의 성질을 알아본 덕분이에요. H로 이야기 수첩을 펼쳐 모험을 다시 읽어 보세요.", 18, QuadTheme.INK))
	body.add_child(QuadTheme.button("심부름 계속하기", _close_modal, true))

func _show_game_menu() -> void:
	var body: VBoxContainer = _open_modal("모험 메뉴")
	body.add_child(QuadTheme.paragraph("심부름 수입 %s · 집과 우주선을 만들 때 쓸 수 있어요." % ConstructionCatalog.format_won(_economy_state.village_income()), 17))
	var routes: GridContainer = _menu_grid(body)
	_add_menu_action(routes, "부탁 수첩  J", _show_journal, 4)
	_add_menu_action(routes, "여행 지도  M", _show_map, 10)
	_add_menu_action(routes, "모험가의 가방  I", _show_inventory, 11)
	_add_menu_action(routes, "이야기 수첩  H", _show_story, 23)
	_add_menu_action(routes, "사각형 도감", _show_notebook, 7)
	_add_menu_action(routes, "수학 직접 해 보기", _show_learning, 6)
	body.add_child(QuadTheme.label("탐험 설정", 18, QuadTheme.TEAL))
	var settings: VBoxContainer = VBoxContainer.new()
	settings.add_theme_constant_override("separation", 6)
	body.add_child(settings)
	var peaceful: CheckButton = CheckButton.new()
	peaceful.text = "편안한 탐험 · 몬스터에 닿아도 다치지 않아요"
	ButtonArt.apply(peaceful)
	peaceful.custom_minimum_size.y = 48
	peaceful.button_pressed = learning_progress.peaceful
	peaceful.toggled.connect(func(enabled: bool):
		learning_progress.peaceful = enabled
		learning_progress.changed.emit())
	settings.add_child(peaceful)
	var touch: CheckButton = CheckButton.new()
	touch.text = "화면에 이동·점프 버튼 표시"
	ButtonArt.apply(touch)
	touch.custom_minimum_size.y = 48
	touch.button_pressed = learning_progress.touch_controls
	touch.toggled.connect(func(enabled: bool):
		learning_progress.touch_controls = enabled
		learning_progress.changed.emit())
	settings.add_child(touch)
	var sound: CheckButton = CheckButton.new()
	sound.text = "효과음 켜기"
	ButtonArt.apply(sound)
	sound.custom_minimum_size.y = 48
	sound.button_pressed = _sound.sound_enabled
	sound.toggled.connect(func(enabled: bool): _sound.sound_enabled = enabled)
	settings.add_child(sound)
	body.add_child(QuadTheme.label("기록과 도움말", 18, QuadTheme.TEAL))
	var records: GridContainer = _menu_grid(body)
	_add_menu_action(records, "심부름 기록 저장", func(): _save(true))
	_add_menu_action(records, "심부름 기록 불러오기", func(): _load(true))
	_add_menu_action(records, "조작 방법", _show_controls)
	_add_menu_action(records, "튜토리얼 다시 보기", func(): _replay_tutorial("world"))
	_add_menu_action(records, "모든 모드 안내", _show_tutorials)
	_add_menu_action(records, "메인으로", _show_home)
	body.add_child(QuadTheme.button("심부름 계속하기", _close_modal, true))

func _menu_grid(parent: VBoxContainer) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_to_group(&"responsive_menu_grid")
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid

func _add_menu_action(grid: GridContainer, caption: String, action: Callable, item_index: int = -1) -> void:
	var button: Button = QuadTheme.button(caption, action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if item_index >= 0:
		button.icon = GameArt.item(item_index)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("h_separation", 12)
		button.custom_minimum_size.y = 56
	grid.add_child(button)

func _show_controls() -> void:
	var body: VBoxContainer = _open_modal("조작 방법")
	body.add_child(QuadTheme.paragraph("방향키 / A·D로 좌우 이동\nSpace / W / 위쪽 방향키로 점프\nG로 가까운 물건 줍기 · E로 주민과 대화\nZ / F로 바라보는 방향 공격\nQ로 회복약 사용", 20, QuadTheme.INK))
	body.add_child(QuadTheme.paragraph("가방 I · 부탁 수첩 J · 지도 M · 이야기 H\nTab / Esc로 메뉴 열기\n메뉴에서는 Tab으로 이동 · Enter로 선택 · Esc로 닫기", 18, QuadTheme.INK))
	body.add_child(QuadTheme.paragraph("물건은 가까이 닿아도 모을 수 있어요. 부탁을 받기 전에 주워도 괜찮아요. 위쪽 물건은 발판에 올라가 찾아보세요.", 18))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal, true))

func _show_tutorials() -> void:
	if is_instance_valid(_startup_learning): return
	_tutorial.cancel()
	var body: VBoxContainer = _open_modal("함께 해 보는 모드 안내")
	body.add_child(QuadTheme.paragraph("직각이와 이야기하며 직접 해 봐요. 언제든 건너뛸 수 있고, 지금 만든 작품과 모험은 그대로 이어져요.", 18))
	for context: String in TutorialCatalog.MODE_IDS:
		if context in ["masterpiece", "my_house"]: continue
		var status: String = str(_tutorial.progress.statuses.get(context, ""))
		var suffix: String = " · 다시 보기" if not status.is_empty() else " · 처음 해 보기"
		body.add_child(QuadTheme.button(TutorialCatalog.title(context) + suffix, _replay_tutorial.bind(context)))

func _replay_tutorial(context: String) -> void:
	if not TutorialCatalog.MODE_IDS.has(context): return
	var current: String = _tutorial.current_context()
	if context in ["masterpiece", "my_house"] and context != current: return
	_close_modal(false)
	if context != current:
		match context:
			"learning": _show_learning()
			"drawing":
				await _show_drawing()
				if not is_instance_valid(_drawing_screen) or not _drawing_screen.visible: return
			"construction":
				await _show_construction()
				if not is_instance_valid(_construction_screen) or not _construction_screen.visible: return
			"world":
				await _enter_world()
				if not _in_world: return
	_tutorial.start(context)

func _show_journal(filter: String = "active") -> void:
	_tutorial.call_deferred("notify", "world_journal")
	_journal_filter = filter if filter in ["active", "available", "completed", "all"] else "active"
	var body: VBoxContainer = _open_modal("나의 부탁 수첩")
	body.add_child(QuadTheme.paragraph("물건을 다 모으면 주민에게 돌아가 도형 이야기를 나눠요. ‘이 목표 안내’를 누르면 가는 방향을 알려 줘요.", 17))
	var filters: HFlowContainer = HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 8)
	body.add_child(filters)
	var captions: Dictionary = {"active": "진행 중", "available": "새 부탁", "completed": "완료", "all": "전체"}
	var counts: Dictionary = {"active": 0, "available": 0, "completed": 0, "all": QuestCatalog.all_quests().size()}
	for quest: Dictionary in QuestCatalog.all_quests():
		var state: String = journal.quest_state(str(quest["id"]))
		var group: String = "active" if state == "ready" else state
		counts[group] = int(counts[group]) + 1
	for key: String in ["active", "available", "completed", "all"]:
		filters.add_child(QuadTheme.button("%s%s %d" % ["● " if key == _journal_filter else "", captions[key], counts[key]], func(): _show_journal(key), key == _journal_filter))
	var shown: int = 0
	for quest: Dictionary in QuestCatalog.all_quests():
		var state: String = journal.quest_state(String(quest["id"]))
		var group: String = "active" if state == "ready" else state
		if _journal_filter != "all" and _journal_filter != group: continue
		shown += 1
		var status: String = {"available": "아직 만나지 않았어요", "active": "탐험 중", "ready": "주민에게 돌아가요", "completed": "완료"}.get(state, "")
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
		card.add_child(QuadTheme.paragraph(String(quest["npc_name"]) + "  ·  " + status, 17, QuadTheme.TEAL))
		card.add_child(QuadTheme.paragraph(String(quest["title"]), 21, QuadTheme.INK))
		card.add_child(QuadTheme.paragraph(journal.progress_text(String(quest["id"])), 17))
		if state == "completed": card.add_child(QuadTheme.paragraph(String(quest["explanation"]), 17))
		else: card.add_child(QuadTheme.button("이 목표 안내", func():
			_tracked_quest = str(quest["id"])
			_close_modal()
			_refresh_world_guidance()))
	if shown == 0:
		body.add_child(QuadTheme.paragraph("진행 중인 부탁이 없어요. 지도에서 주민을 찾고 E로 이야기해 보세요." if _journal_filter == "active" else "이곳에 기록된 부탁이 아직 없어요. 새로운 친구를 만나 보세요.", 18, QuadTheme.INK))
		body.add_child(QuadTheme.button("지도에서 주민 찾기", _show_map, true))
	body.add_child(QuadTheme.button("여섯 지역의 이야기 보기", _show_story))
	body.add_child(QuadTheme.button("모험 계속하기", _close_modal))

func _show_notebook() -> void:
	if is_instance_valid(_startup_learning): return
	var body: VBoxContainer = _open_modal("사각형 탐험 도감")
	body.add_child(QuadTheme.paragraph("색과 방향보다 변과 각을 살펴봐요. 주제를 골라 직접 재고 확인할 수 있어요.", 18))
	for id: String in LearningCatalog.IDS:
		var entry: Dictionary = LearningCatalog.lesson(id)
		var title: String = str(entry.title)
		var done: String = " · 활동 완료" if learning_progress.completed.has(id) else ""
		var button: Button = QuadTheme.button(title + done + "\n" + str(entry.goal), func(): _show_learning(id))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(button)
	body.add_child(QuadTheme.button("닫기", _close_modal))

func _show_map() -> void:
	var body: VBoxContainer = _open_modal("세계 지도")
	body.add_child(QuadTheme.paragraph("마을과 숲을 지나, 항구에서 설원과 별빛 성곽까지!\n방향키로 이동 · Space로 발판 오르기 · G로 줍기", 19, QuadTheme.INK))
	if world != null:
		var map: WorldMapView = WorldMapView.new()
		map.points = world.navigation_points()
		map.player_x = world.player.position.x
		var waypoint: Dictionary = _quest_waypoint(_tracked_quest)
		if not waypoint.is_empty(): map.target_x = Vector2(waypoint["position"]).x
		body.add_child(map)
	for region: Dictionary in QuadrilateralWorld.REGION_DATA:
		var id: String = str(region["id"])
		var known: bool = adventure.discovered_regions.has(id)
		var card: VBoxContainer = QuadTheme.card(body, Color("edf5ef"), 14)
		card.add_child(QuadTheme.label(str(region["name"]) + ("  ·  발견" if known else "  ·  새로운 여행지"), 21))
		card.add_child(QuadTheme.paragraph(str(region["subtitle"]), 16, QuadTheme.TEAL))
		for quest: Dictionary in QuestCatalog.all_quests():
			if str(quest["region"]) != id: continue
			card.add_child(QuadTheme.paragraph("%s · %s\n%s" % [quest["npc_name"], quest["title"], journal.progress_text(str(quest["id"]))], 15))
		if known and world != null:
			card.add_child(QuadTheme.button("관문으로 이동", func():
				world.travel_to(id)
				_close_modal()))
	body.add_child(QuadTheme.button("탐험 계속하기", _close_modal))

func _open_modal(title: String, preferred_height: float = 680.0) -> VBoxContainer:
	_clear_touch_inputs()
	if not is_instance_valid(_modal_overlay):
		_modal_focus_before = get_viewport().gui_get_focus_owner()
	_close_modal(false)
	if world != null and _in_world: world.set_controls_enabled(false)
	_modal_overlay = Control.new()
	if _tutorial != null: _tutorial.refresh.call_deferred()
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_modal_overlay)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.09, 0.13, 0.70)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.add_child(dim)
	_modal_panel = PanelContainer.new()
	_modal_height = preferred_height
	_modal_panel.add_theme_stylebox_override("panel", QuadTheme.style(QuadTheme.PAPER, 22, QuadTheme.BORDER, 20))
	_modal_overlay.add_child(_modal_panel)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_modal_panel.add_child(outer)
	var header: HBoxContainer = HBoxContainer.new()
	outer.add_child(header)
	var heading: Label = QuadTheme.paragraph(title, 26, QuadTheme.INK)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_modal_close = QuadTheme.button("닫기 Esc", _close_modal)
	_modal_close.custom_minimum_size.x = 124.0
	header.add_child(_modal_close)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_scroll.follow_focus = true
	outer.add_child(_modal_scroll)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 18)
	_modal_scroll.add_child(_modal_body)
	_layout_modal()
	call_deferred("_focus_modal")
	return _modal_body

func _layout_modal() -> void:
	if not is_instance_valid(_modal_panel): return
	var area: Vector2 = _ui_size()
	var margin: float = 12.0 if area.x < 640.0 else 24.0
	var panel_size: Vector2 = Vector2(minf(760.0, area.x - margin * 2.0), minf(_modal_height, area.y - margin * 2.0))
	_fit_modal_content(_modal_panel, maxf(100.0, panel_size.x - 64.0))
	_modal_panel.size = panel_size
	_modal_panel.position = (area - panel_size) * 0.5

func _fit_modal_content(parent: Node, width: float) -> void:
	for child: Node in parent.get_children():
		if child is GridContainer and child.is_in_group(&"responsive_menu_grid"):
			(child as GridContainer).columns = 1 if width < 430.0 else 2
		if child is Control:
			var control: Control = child as Control
			if control.custom_minimum_size.x > width:
				control.custom_minimum_size.x = width
		if child is Label:
			var label: Label = child as Label
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if label.get_theme_font_size("font_size") < 16:
				label.add_theme_font_size_override("font_size", 17)
		elif child is Button:
			var button: Button = child as Button
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = maxf(48.0, button.custom_minimum_size.y)
			if parent is HFlowContainer:
				button.custom_minimum_size.x = minf(width, QuadTheme.FONT.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40.0)
		_fit_modal_content(child, width)

func _focus_modal() -> void:
	if not is_instance_valid(_modal_overlay): return
	_layout_modal()
	var controls: Array[Control] = []
	for node: Node in _modal_panel.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.focus_mode != Control.FOCUS_ALL or not control.is_visible_in_tree(): continue
		if control is BaseButton and (control as BaseButton).disabled: continue
		controls.append(control)
	if controls.is_empty(): return
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	_modal_close.grab_focus()

func _close_modal(restore_focus: bool = true) -> void:
	if is_instance_valid(_modal_overlay):
		_modal_overlay.hide()
		_modal_overlay.queue_free()
		_modal_overlay = null
	_modal_panel = null
	_modal_scroll = null
	_modal_close = null
	if restore_focus:
		if is_instance_valid(_modal_focus_before) and _modal_focus_before.is_visible_in_tree():
			_modal_focus_before.grab_focus()
		_modal_focus_before = null
	if world != null and _in_world: world.set_controls_enabled(_tutorial == null or not _tutorial.blocks_gameplay())
	if _tutorial != null: _tutorial.refresh.call_deferred()

func _sync_village_rewards() -> Dictionary:
	var unclaimed: Array[String] = []
	for id: String in journal.completed:
		if not _economy_state.village_rewards.has(id): unclaimed.append(id)
	if unclaimed.is_empty(): return {"ok": true}
	return ProgressionTransactions.commit(_economy_state, "village_rewards", unclaimed, _economy_save_path(), not testing)

func _save(notify_user: bool) -> Dictionary:
	if _restoring: return {"ok": false}
	var error: Error = OK
	if not testing:
		if world != null: _world_data = world.serialize()
		error = WorldSaveStore.save_game(_legacy_editor, journal.serialize(), _world_data, WorldSaveStore.SAVE_PATH, adventure.serialize())
	var result: Dictionary = _sync_village_rewards() if error == OK else {"ok": false}
	if notify_user:
		_show_toast("심부름 기록을 저장했어요." if bool(result.ok) else "저장 공간을 확인해 주세요. 저장하지 못했어요.")
	return result

func _load(notify_user: bool, path: String = WorldSaveStore.SAVE_PATH) -> bool:
	var data: Dictionary = WorldSaveStore.load_game(path)
	if data.is_empty():
		if notify_user: _show_toast("아직 저장한 심부름 기록이 없어요.")
		return false
	var legacy_document: CharacterDocument = CharacterDocument.new()
	var candidate_journal: QuestJournal = QuestJournal.new()
	var candidate_adventure: AdventureState = AdventureState.new()
	if not legacy_document.restore(data["editor"]) or not candidate_journal.restore(data["journal"]) or not QuadrilateralWorld.is_valid_save(data["world"]):
		if notify_user: _show_toast("심부름 기록을 읽지 못했어요. 현재 진행 상황은 그대로예요.")
		return false
	if data.has("adventure") and not candidate_adventure.restore(data["adventure"]):
		if notify_user: _show_toast("모험가 정보를 읽을 수 없어요. 현재 상태는 유지돼요.")
		return false
	if not data.has("adventure"):
		for quest_id: String in candidate_journal.completed: candidate_adventure.claim_quest(quest_id)
	for claimed_id: String in candidate_adventure.claimed_quests:
		if not candidate_journal.completed.has(claimed_id): return false
	_restoring = true
	_legacy_editor = legacy_document.serialize()
	journal.restore(data["journal"])
	adventure.restore(candidate_adventure.serialize())
	_world_data = data["world"].duplicate(true)
	if world != null:
		world.restore(_world_data)
		world.configure_adventure(adventure)
	_restoring = false
	_sync_village_rewards()
	if notify_user: _show_toast("심부름 기록을 불러왔어요.")
	return true

func _responsive() -> void:
	if _ui == null or _ui_layer == null: return
	var window: Window = get_window()
	var creation_visible: bool = is_instance_valid(_startup_learning) or (is_instance_valid(_home_screen) and (_home_screen.visible or (is_instance_valid(_drawing_screen) and _drawing_screen.visible) or (is_instance_valid(_construction_screen) and _construction_screen.visible) or (is_instance_valid(_learning_screen) and _learning_screen.visible) or (is_instance_valid(_space_screen) and _space_screen.visible) or is_instance_valid(_opening_screen) or is_instance_valid(_ending_scene)))
	var desired_size: Vector2i = Vector2i(maxi(window.size.x, 800), maxi(window.size.y, 600)) if creation_visible else Vector2i(1600, 900)
	# Embedded drawing palettes use the root window's scale, outside the HUD layer.
	if is_instance_valid(_drawing_screen) and _drawing_screen.visible:
		desired_size = window.size.max(Vector2i.ONE)
	if window.content_scale_size != desired_size:
		window.content_scale_size = desired_size
	# Counter only the UI stretch. World coordinates and player artwork stay intact.
	var stretch: Vector2 = get_viewport().get_stretch_transform().get_scale()
	stretch = Vector2(maxf(stretch.x, 0.01), maxf(stretch.y, 0.01))
	_ui_scale = 1.0 / stretch.y
	_ui_layer.scale = Vector2(1.0 / stretch.x, 1.0 / stretch.y)
	_ui.position = Vector2.ZERO
	_ui.size = get_viewport().get_visible_rect().size * stretch
	_layout_hud(_ui.size)
	_layout_modal()
	_layout_toast()
	_journal_changed()
	_refresh_world_guidance()
	if _tutorial != null: _tutorial.refresh.call_deferred()

func _ui_size() -> Vector2:
	return _ui.size if _ui != null and _ui.size.x > 0.0 else get_viewport().get_visible_rect().size

func _input(event: InputEvent) -> void:
	if is_instance_valid(_startup_learning):
		if event is InputEventKey and event.keycode == KEY_ESCAPE: get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_feature_loading_overlay):
		if event is InputEventKey:
			if event.pressed and not event.echo and event.keycode == KEY_ESCAPE: _cancel_feature_navigation()
			if event.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_opening_screen):
		if _opening_screen.handle_key(event): get_viewport().set_input_as_handled()
		return
	if _tutorial != null and _tutorial.blocks_gameplay(): return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_screen_touch(event)
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and is_instance_valid(_modal_overlay):
		_close_modal()
		get_viewport().set_input_as_handled()
	elif _in_world and not is_instance_valid(_modal_overlay) and event.keycode in [KEY_TAB, KEY_ESCAPE]:
		_show_game_menu()
		get_viewport().set_input_as_handled()

func _handle_screen_touch(event: InputEvent) -> void:
	if _tutorial != null and _tutorial.blocks_gameplay(): return
	var index: int = event.index
	if event is InputEventScreenTouch and not event.pressed:
		if not _touch_fingers.has(index): return
		_touch_fingers.erase(index)
		_sync_touch_fingers()
		get_viewport().set_input_as_handled()
		return
	if not _in_world or world == null or not learning_progress.touch_controls or is_instance_valid(_modal_overlay): return
	var action: String = ""
	for id: String in _touch_buttons:
		var button: Button = _touch_buttons[id]
		var local: Vector2 = button.get_global_transform_with_canvas().affine_inverse() * event.position
		if button.is_visible_in_tree() and Rect2(Vector2.ZERO, button.size).has_point(local):
			action = id
			break
	if action.is_empty() and not _touch_fingers.has(index): return
	var previous: String = str(_touch_fingers.get(index, ""))
	_touch_fingers[index] = action
	_sync_touch_fingers()
	if action == "attack" and previous != action: world.player.begin_attack()
	get_viewport().set_input_as_handled()

func _sync_touch_fingers() -> void:
	if world == null: return
	for action: String in ["left", "right", "jump"]:
		world.player.set_touch_control(action, _touch_fingers.values().has(action))

func _clear_touch_inputs() -> void:
	_touch_fingers.clear()
	if world != null: world.player.clear_touch_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _clear_touch_inputs()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(_startup_learning): return
	if is_instance_valid(_feature_loading_overlay): return
	if is_instance_valid(_opening_screen): return
	if is_instance_valid(_ending_scene) or (is_instance_valid(_ending_dialog) and _ending_dialog.visible): return
	if is_instance_valid(_space_screen) and _space_screen.visible: return
	if _tutorial != null and _tutorial.blocks_gameplay(): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if (is_instance_valid(_drawing_screen) and _drawing_screen.visible) or (is_instance_valid(_construction_screen) and _construction_screen.visible) or (is_instance_valid(_learning_screen) and _learning_screen.visible): return
	if event.keycode == KEY_ESCAPE:
		_close_modal()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_modal_overlay): return
	if not _in_world: return
	if event.ctrl_pressed and event.keycode == KEY_S:
		_save(true)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_J: _show_journal()
	elif event.keycode == KEY_M: _show_map()
	elif event.keycode == KEY_I: _show_inventory()
	elif event.keycode == KEY_H: _show_story()
	elif event.keycode == KEY_Q: _use_potion()
