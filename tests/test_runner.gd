extends Node

const TestGeometry = preload("res://tests/test_quadrilateral_math.gd")
const TestLearningActivities = preload("res://tests/test_learning.gd")
const TestDocument = preload("res://tests/test_character_document.gd")
const TestJournal = preload("res://tests/test_quest_journal.gd")
const TestWorld = preload("res://tests/test_world_game.gd")
const TestApp = preload("res://tests/test_app_integration.gd")
const TestSound = preload("res://tests/test_sound_manager.gd")
const TestSave = preload("res://tests/test_save_store.gd")
const TestAdventure = preload("res://tests/test_adventure_state.gd")
const TestCombat = preload("res://tests/test_world_player_combat.gd")
const TestRpg = preload("res://tests/test_rpg_integration.gd")
const TestUiTheme = preload("res://tests/test_ui_theme.gd")
const TestUiUsability = preload("res://tests/test_ui_usability.gd")
const TestFocusedUi = preload("res://tests/test_focused_ui.gd")
const TestStarfront = preload("res://tests/test_starfront_presentation.gd")
const TestGeneratedButtons = preload("res://tests/test_generated_buttons.gd")
const TestDrawing = preload("res://tests/test_drawing_studio.gd")
const TestDrawingDocumentFeatures = preload("res://tests/test_drawing_document_features.gd")
const TestDrawingGestures = preload("res://tests/test_drawing_gestures.gd")
const TestDrawingGallery = preload("res://tests/test_drawing_gallery.gd")
const TestHome = preload("res://tests/test_home_navigation.gd")
const TestConstructionModel = preload("res://tests/test_construction_model.gd")
const TestConstructionPhysics = preload("res://tests/test_construction_physics.gd")
const TestConstructionIntegration = preload("res://tests/test_construction_integration.gd")
const TestConstructionFacade = preload("res://tests/test_construction_facade.gd")
const TestGeneratedArtwork = preload("res://tests/test_generated_art.gd")
const TestConstructionProgression = preload("res://tests/test_construction_progression.gd")
const TestConstructionAwards = preload("res://tests/test_construction_awards.gd")
const TestConstructionLanguage = preload("res://tests/test_construction_language.gd")
const TestConstructionGameUi = preload("res://tests/test_construction_game_ui.gd")
var passed_count: int = 0
var failed_count: int = 0
var test_failures: Array[String] = []

func _ready() -> void:
	print("Starting Quadrilateral World Headless Test Suite")
	print("[Suite] Quadrilateral geometry and classification")
	TestGeometry.run(self)
	print("[Suite] Guide-aligned manipulation, explanation, history and touch access")
	await TestLearningActivities.run(self)
	print("[Suite] Drawing, templates, constrained gestures and undo")
	TestDocument.run(self)
	print("[Suite] Generated artwork sources and atlas references")
	TestGeneratedArtwork.run(self)
	print("[Suite] Home navigation and free quadrilateral drawing")
	await TestDrawing.run(self)
	TestDrawingDocumentFeatures.run(self)
	await TestDrawingGestures.run(self)
	await TestDrawingGallery.run(self)
	await TestHome.run(self)
	print("[Suite] Construction commissions, real openings, economy and gravity")
	TestConstructionModel.run(self)
	TestConstructionProgression.run(self)
	TestConstructionAwards.run(self)
	TestConstructionLanguage.run(self)
	await TestConstructionGameUi.run(self)
	TestConstructionFacade.run(self)
	await TestConstructionPhysics.run(self)
	await TestConstructionIntegration.run(self)
	print("[Suite] Curriculum, quests, inventory and save validation")
	TestJournal.run(self)
	print("[Suite] Save schema and corrupt file handling")
	TestSave.run(self)
	print("[Suite] RPG progression, inventory and side-profile combat")
	TestAdventure.run(self)
	await TestCombat.run(self)
	print("[Suite] World, pickups, physics and navigation")
	await TestWorld.run(self)
	print("[Suite] App integration, save/load and workshop-world round trip")
	await TestApp.run(self)
	await TestRpg.run(self)
	print("[Suite] UI contrast, responsive layout and keyboard navigation")
	await TestUiTheme.run(self)
	await TestUiUsability.run(self)
	await TestFocusedUi.run(self)
	await TestGeneratedButtons.run(self)
	await TestStarfront.run(self)
	print("[Suite] Sound synthesis")
	TestSound.run(self)
	await get_tree().process_frame
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	for failure: String in test_failures: print("FAIL: " + failure)
	get_tree().quit(0 if failed_count == 0 else 1)

func assert_true(condition: bool, message: String = "") -> void:
	if condition: passed_count += 1
	else:
		failed_count += 1
		test_failures.append(message)

func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assert_true(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func assert_float_approx(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> void:
	assert_true(absf(actual - expected) <= epsilon, "%s (expected %s, got %s)" % [message, expected, actual])

func assert_not_null(value: Variant, message: String = "") -> void:
	assert_true(value != null, message)

func assert_gt(actual: Variant, expected: Variant, message: String = "") -> void:
	assert_true(actual > expected, message)

func assert_ge(actual: Variant, expected: Variant, message: String = "") -> void:
	assert_true(actual >= expected, message)

func assert_lt(actual: Variant, expected: Variant, message: String = "") -> void:
	assert_true(actual < expected, message)

func assert_le(actual: Variant, expected: Variant, message: String = "") -> void:
	assert_true(actual <= expected, message)
