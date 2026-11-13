class_name TestSpaceEconomy
extends RefCounted

const State = preload("res://scripts/construction/construction_state.gd")
const Document = preload("res://scripts/construction/construction_document.gd")
const Drawing = preload("res://scripts/core/drawing_document.gd")
const Catalog = preload("res://scripts/construction/construction_catalog.gd")
const Guide = preload("res://scripts/construction/construction_guide.gd")
const Market = preload("res://scripts/economy/art_market.gd")
const Ship = preload("res://scripts/economy/spaceship_catalog.gd")
const Transactions = preload("res://scripts/economy/progression_transactions.gd")
const Saves = preload("res://scripts/construction/construction_save_store.gd")
const ArtSamples = preload("res://tests/test_art_composition.gd")

static func run(t: Node) -> void:
	_test_legacy_migration(t)
	_test_village_income(t)
	_test_art_income(t)
	_test_art_titles(t)
	_test_titled_transactions(t)
	_test_reserved_funds(t)
	_test_invalid_restores(t)
	_test_durable_transactions(t)
	_test_complete_ship(t)

static func _test_village_income(t: Node) -> void:
	var state: State = State.new()
	var first: String = "rhombus_chocolates"
	var reward: int = State.village_reward_amount(first)
	var initial: Dictionary = state.serialize()
	var missing_path: String = "user://missing_village_save_%s/ledger.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	t.assert_false(Transactions.commit(state, "village_rewards", [first], missing_path).ok, "A failed won ledger save does not credit village funds")
	t.assert_eq(state.serialize(), initial, "A failed won ledger save leaves all live records intact")
	t.assert_false(Transactions.commit(state, "village_rewards", [first, "unknown"], missing_path, false).ok, "Unknown missions reject the entire reward batch")
	t.assert_eq(state.serialize(), initial, "An invalid village reward batch cannot pay a partial amount")
	var paid: Dictionary = Transactions.commit(state, "village_rewards", [first, first], missing_path, false)
	t.assert_true(bool(paid.ok), "A known completed mission can be credited")
	t.assert_eq(int(paid.price), reward, "A village reward is paid once even if the same ID is repeated")
	var first_part: Dictionary = Ship.all_parts()[0]
	var bought: Dictionary = Transactions.commit(state, "purchase_part", str(first_part.id), missing_path, false)
	t.assert_true(bool(bought.ok), "The first village mission alone can pay for a ship part")
	t.assert_eq(state.ship_available_funds(), reward - int(first_part.price), "The ship spends the same won balance that the village earned")
	t.assert_eq(state.my_house_budget(), State.INITIAL_BALANCE + reward - int(first_part.price), "The house budget shares the post-purchase balance")
	var restored: State = State.new()
	t.assert_true(restored.restore(_json_copy(state.serialize())), "Save restoration includes village income and the purchased part")
	var replay: Dictionary = Transactions.commit(restored, "village_rewards", [first], missing_path, false)
	t.assert_eq(int(replay.price), 0, "A reloaded ledger will not pay the mission again")
	var tampered: Dictionary = _json_copy(state.serialize())
	tampered.village_rewards.append(first)
	tampered.balance = int(tampered.balance) + reward
	t.assert_false(restored.restore(tampered), "Duplicate mission receipts cannot inflate the restored balance")
	var all_ids: Array[String] = []
	for quest: Dictionary in QuestCatalog.all_quests(): all_ids.append(str(quest.id))
	var all_rewards: Dictionary = Transactions.commit(restored, "village_rewards", all_ids, missing_path, false)
	t.assert_true(bool(all_rewards.ok), "All mission receipts fit the reward ledger")
	t.assert_ge(restored.village_income(), Ship.total_price(), "All village errands can fund the complete spaceship")
	for slot: Dictionary in Ship.all_parts():
		var upgrade: Dictionary = Ship.variants(str(slot.id))[1]
		t.assert_true(restored.purchase_ship_part(str(upgrade.id)).ok, "Village earnings can fund every advanced component")
	t.assert_true(restored.ship_complete(), "Twelve distinct slots unlock departure even when every base part was replaced")
	t.assert_eq(restored.ship_performance(), Ship.PART_COUNT * 2, "All installed advanced models contribute their performance")
	t.assert_eq(restored.ship_spent(), 1440000000, "The complete advanced ship costs exactly the combined model prices")
	t.assert_true(restored.launch_ship().ok, "A complete advanced ship can launch")
	t.assert_true(state.restore(_json_copy(restored.serialize())), "A launched advanced ship restores from its ledger")
	t.assert_true(state.launched and state.ship_complete(), "Reload preserves the advanced build and its completed ending")

static func _test_legacy_migration(t: Node) -> void:
	var original: State = State.new()
	t.assert_true(_earn_construction(original, 100), "Legacy fixture earns its money by completing a real construction offer")
	var legacy: Dictionary = _json_copy(original.serialize())
	t.assert_false(legacy.has("space_economy"), "An untouched existing construction save has no required space-economy fields")
	var restored: State = State.new()
	t.assert_true(restored.restore(legacy), "A pre-space construction ledger still restores")
	t.assert_eq(restored.balance, original.balance, "Migration preserves all previously earned money")
	t.assert_eq(restored.records, legacy.records, "Migration preserves already-paid construction records")
	t.assert_eq(restored.saved_balance(), State.INITIAL_BALANCE + restored.earned_profit(), "Missing optional economy fields contribute no invented earnings or expenses")
	t.assert_eq(restored.art_sales.size(), 0, "Migrated games start with no sold paintings")
	t.assert_eq(restored.purchased_ship_parts.size(), 0, "Migrated games start with no purchased spaceship parts")
	t.assert_false(restored.launched, "Migrated games do not start with a completed ending")
	var earliest: Dictionary = State.new().serialize()
	earliest.erase("progression_version")
	earliest.erase("contract_choice")
	earliest.erase("contract_grading_version")
	t.assert_true(restored.restore(_json_copy(earliest)), "The original v1 briefing without later progression metadata still migrates")
	t.assert_eq(restored.balance, State.INITIAL_BALANCE, "Original v1 seed money is preserved exactly")
	# This already-paid receipt predates structural composition checks. It has
	# five visible parts and 10% coverage, with its original two-million price.
	var historical_receipt: Dictionary = {"version": 1, "title": "이전의 다섯 도형 그림", "fingerprint": "a".repeat(64), "signature": "f00".repeat(72) + "00f".repeat(72) + "___".repeat(1296), "price": 2000000, "visible_shapes": 5, "families": 1, "colors": 2, "coverage": 0.1}
	t.assert_true(Market.validate_receipt(historical_receipt), "The old five-piece and eight-percent receipt rules still validate already-paid artworks")
	var previous_economy: Dictionary = State.new().serialize()
	previous_economy.balance = State.INITIAL_BALANCE + int(historical_receipt.price)
	previous_economy.space_economy = {"version": 1, "art_sales": [historical_receipt], "purchased_parts": [], "launched": false}
	t.assert_true(restored.restore(_json_copy(previous_economy)), "Stricter new-sale composition rules do not reject historical nine-field receipts")
	t.assert_eq(restored.art_sales[0].price, 2000000, "Loading historical artwork does not reprice its already-paid sale")
	t.assert_eq(restored.saved_balance(), State.INITIAL_BALANCE + 2000000, "Historical painting earnings remain part of the player's savings")

static func _test_art_income(t: Node) -> void:
	var state: State = State.new()
	var drawing: Drawing = _artwork()
	var quote: Dictionary = Market.quote(drawing)
	t.assert_true(quote.can_sell, "The sale fixture is a visible original composition accepted by the actual market")
	var before: Dictionary = drawing.serialize()
	var history: int = drawing.command_manager.undo_stack.size()
	var stages: Dictionary = state.stage_unlock_status(2)
	var sale: Dictionary = state.sell_art(drawing.serialize())
	t.assert_true(sale.ok, "A valid drawing can be sold through the state API")
	t.assert_eq(state.balance, State.INITIAL_BALANCE + int(quote.price), "A painting credits exactly its quoted price")
	t.assert_eq(state.saved_balance(), state.balance, "Painting income is included in persistent savings")
	t.assert_eq(state.art_income(), int(quote.price), "Painting income reconciles to its sale receipt")
	t.assert_eq(state.art_sales.size(), 1, "A successful sale appends one receipt")
	t.assert_true(Market.validate_receipt(state.art_sales[0]), "The state records a valid deterministic market receipt")
	t.assert_eq(drawing.serialize(), before, "Selling keeps the player's editable artwork intact")
	t.assert_eq(drawing.command_manager.undo_stack.size(), history, "Selling does not consume drawing Undo history")
	t.assert_eq(state.stage_unlock_status(2), stages, "Painting income does not rewrite construction-only stage achievements")
	var paid_balance: int = state.balance
	t.assert_false(state.sell_art(drawing.serialize()).ok, "Selling the same drawing twice cannot duplicate its payout")
	drawing.select_shape(int(drawing.shapes.front().id))
	t.assert_false(state.sell_art(drawing.serialize()).ok, "Selecting another shape does not turn a sold work into a new painting")
	drawing.move_selected(Vector2(drawing.get_selected().position) + Vector2(1, 0))
	t.assert_false(state.sell_art(drawing.serialize()).ok, "A one-pixel adjustment cannot farm another sale")
	drawing.undo()
	t.assert_false(state.sell_art(drawing.serialize()).ok, "Undo cannot reopen a previously paid artwork")
	t.assert_eq(state.balance, paid_balance, "All duplicate-sale attempts preserve the balance")
	t.assert_eq(state.art_sales.size(), 1, "Duplicate attempts never append additional receipts")
	var second: Drawing = _artwork(true)
	t.assert_true(state.sell_art(second.serialize()).ok, "A visibly different composition can earn a second payment")
	t.assert_eq(state.art_sales.size(), 2, "Distinct accepted paintings have distinct receipts")
	t.assert_eq(state.balance, State.INITIAL_BALANCE + state.art_income(), "Multiple sales still reconcile to exactly-once recorded income")
	var empty: Drawing = Drawing.new()
	t.assert_false(state.sell_art(empty.serialize()).ok, "An empty canvas cannot earn money")
	t.assert_false(state.sell_art({"version": 999}).ok, "Malformed drawing data is rejected before payment")
	var restored: State = State.new()
	t.assert_true(restored.restore(_json_copy(state.serialize())), "Painting receipts and money survive a JSON round trip")
	t.assert_eq(restored.balance, state.balance, "Restored painting income preserves exact integer won")
	t.assert_false(restored.sell_art(drawing.serialize()).ok, "Reloading does not reset sold-work protection")

static func _test_art_titles(t: Node) -> void:
	var state: State = State.new()
	var drawing: Drawing = _artwork()
	var quote: Dictionary = Market.quote(drawing)
	var sale: Dictionary = state.sell_art(drawing.serialize(), "  고향으로 가는 네모 🚀  ")
	t.assert_true(sale.ok, "A player can name a sold painting with Korean text and emoji")
	t.assert_eq(sale.receipt.title, "고향으로 가는 네모 🚀", "Sale titles discard surrounding spaces without changing the player's words")
	t.assert_eq(state.art_sales[0].title, "고향으로 가는 네모 🚀", "The ledger retains the actual player-supplied title")
	t.assert_eq(int(sale.price), int(quote.price), "Naming a work does not change its composition-based price")
	t.assert_eq(state.art_sales[0].size(), 9, "Custom titles use the existing receipt field without changing its schema")
	var before: Dictionary = state.serialize()
	t.assert_false(state.sell_art(drawing.serialize(), "새 이름으로 다시 팔기").ok, "Renaming the same painting cannot earn another payout")
	t.assert_eq(state.serialize(), before, "A duplicate painting under a different title changes neither money nor receipts")
	var second: Drawing = _artwork(true)
	t.assert_true(state.sell_art(second.serialize(), "고향으로 가는 네모 🚀").ok, "Distinct paintings may share a title because duplicate checks use the artwork itself")
	var restored: State = State.new()
	t.assert_true(restored.restore(_json_copy(state.serialize())), "Player-supplied titles survive a ledger JSON round trip")
	t.assert_eq(restored.art_sales[0].title, "고향으로 가는 네모 🚀", "Reloading preserves the exact Unicode sale title")
	t.assert_eq(restored.balance, state.balance, "Title persistence preserves exact earned income")
	t.assert_false(restored.sell_art(drawing.serialize(), "다시 불러온 제목").ok, "Reloading and renaming cannot bypass the sold-artwork record")
	var boundary: State = State.new()
	var longest_title: String = "가".repeat(Market.MAX_TITLE_LENGTH)
	t.assert_true(boundary.sell_art(drawing.serialize(), "  " + longest_title + "  ").ok, "An eighty-character Korean title is accepted after trimming surrounding spaces")
	t.assert_eq(boundary.art_sales[0].title, longest_title, "An accepted maximum-length title is stored completely rather than silently truncated")
	var invalid_titles: Array[String] = ["   ", "\t\n", String.chr(1), "제목\n다음 줄", "제목" + String.chr(127), "가".repeat(Market.MAX_TITLE_LENGTH + 1)]
	for invalid: String in invalid_titles:
		var unsold: State = State.new()
		var untouched: Dictionary = unsold.serialize()
		t.assert_false(unsold.sell_art(drawing.serialize(), invalid).ok, "Blank, control-containing and overlong titles are rejected before selling an original painting")
		t.assert_eq(unsold.serialize(), untouched, "Invalid title input cannot credit money or mark a painting as sold")
	var compatible: State = State.new()
	t.assert_true(compatible.sell_art(drawing.serialize()).ok, "Older direct callers can still omit a sale title")
	t.assert_eq(compatible.art_sales[0].title, "나의 작품 1", "Omitting a title keeps the original automatically numbered name")
	t.assert_true(compatible.sell_art(second.serialize(), "").ok, "The optional direct API's empty default remains backward compatible")
	t.assert_eq(compatible.art_sales[1].title, "나의 작품 2", "Automatic names continue numbering after prior sales")
	t.assert_true(restored.restore(_json_copy(compatible.serialize())), "Existing automatically titled receipts remain loadable")

static func _test_titled_transactions(t: Node) -> void:
	var state: State = State.new()
	state.set_my_house_mode(true)
	state.my_house_document.add_part("brick", Vector2(400, 550))
	var house: Document = state.my_house_document
	var house_history: int = house.command_manager.undo_stack.size()
	var drawing: Drawing = _artwork()
	var drawing_before: Dictionary = drawing.serialize()
	var drawing_history: int = drawing.command_manager.undo_stack.size()
	var path: String = "res://.godot/titled_art_%d.json" % Time.get_ticks_usec()
	var invalid_path: String = "res://.godot/missing_titled_art_%d/ledger.json" % Time.get_ticks_usec()
	var payload: Dictionary = {"document": drawing.serialize(), "title": "  지구에서 찾은 네모별  "}
	var before: Dictionary = state.serialize()
	t.assert_false(Transactions.commit(state, "sell_art", payload, invalid_path).ok, "A named painting is not sold when its ledger cannot be saved")
	t.assert_eq(state.serialize(), before, "A failed named sale preserves the balance and sold-artwork history")
	t.assert_true(state.my_house_document == house, "A failed named sale preserves the live private-house document")
	t.assert_eq(house.command_manager.undo_stack.size(), house_history, "A failed named sale preserves existing Undo history")
	var malformed: Array[Dictionary] = [
		{"document": drawing.serialize(), "title": ""},
		{"document": drawing.serialize(), "title": "  "},
		{"document": drawing.serialize()},
		{"document": drawing.serialize(), "title": null},
		{"document": drawing.serialize(), "title": 123},
		{"document": drawing.serialize(), "title": ["제목"]},
		{"document": drawing.serialize(), "title": "줄\n바꿈"},
		{"document": drawing.serialize(), "title": "가".repeat(Market.MAX_TITLE_LENGTH + 1)},
		{"document": "그림이 아님", "title": "제목"},
		{"title": "그림이 없는 제목"}
	]
	for invalid: Dictionary in malformed:
		t.assert_false(Transactions.commit(state, "sell_art", invalid, path).ok, "Explicit named-sale payloads require a valid document and nonblank string title")
		t.assert_eq(state.serialize(), before, "Malformed named-sale payloads cannot change money or reserve the artwork")
	t.assert_false(Saves.has_save(path), "Invalid title attempts never publish an economy save")
	var sale: Dictionary = Transactions.commit(state, "sell_art", payload, path)
	t.assert_true(sale.ok, "The same original painting can be sold after entering a valid title and restoring storage")
	t.assert_eq(sale.receipt.title, "지구에서 찾은 네모별", "The durable transaction returns the trimmed user title")
	t.assert_eq(state.art_sales[0].title, "지구에서 찾은 네모별", "Successful commit copies the named receipt into live economic state")
	t.assert_eq(state.art_sales.size(), 1, "Invalid and failed attempts do not create phantom sold paintings")
	t.assert_eq(state.balance, State.INITIAL_BALANCE + int(sale.price), "A retried named sale pays once at the accepted price")
	t.assert_eq(drawing.serialize(), drawing_before, "The financial API keeps original drawing data available to its caller after payment")
	t.assert_eq(drawing.command_manager.undo_stack.size(), drawing_history, "The financial API preserves drawing history until its caller finishes the sale flow")
	t.assert_true(state.my_house_document == house, "A named financial commit keeps the live private-house document")
	t.assert_eq(house.command_manager.undo_stack.size(), house_history, "A successful named sale preserves private-house Undo history")
	var restored: State = State.new()
	t.assert_true(Saves.load_into(path, restored).ok, "The published named-sale ledger reloads from disk")
	t.assert_eq(restored.art_sales[0].title, "지구에서 찾은 네모별", "Disk persistence retains the exact trimmed sale title")
	t.assert_eq(restored.balance, state.balance, "Named-sale disk persistence retains the exact payout")
	before = restored.serialize()
	var published: String = FileAccess.get_file_as_string(path)
	t.assert_false(Transactions.commit(restored, "sell_art", {"document": drawing.serialize(), "title": "다른 이름"}, path).ok, "A renamed sold painting is rejected by the durable transaction layer after reload")
	t.assert_eq(restored.serialize(), before, "Renaming a sold painting cannot mutate the restored financial ledger")
	t.assert_eq(FileAccess.get_file_as_string(path), published, "A renamed duplicate does not replace the valid on-disk ledger")
	var legacy: State = State.new()
	t.assert_true(Transactions.commit(legacy, "sell_art", drawing.serialize(), path, false).ok, "The transaction API still accepts the original unwrapped document payload")
	t.assert_eq(legacy.art_sales[0].title, "나의 작품 1", "Legacy transaction callers retain automatic artwork titles")
	_cleanup_save(path)

static func _test_reserved_funds(t: Node) -> void:
	var state: State = State.new()
	var first: Dictionary = Ship.all_parts().front()
	t.assert_gt(state.balance, int(first.price), "Seed money exceeds the cheapest part but is reserved for operating the business")
	t.assert_eq(state.ship_available_funds(), 0, "A new game has no earned spaceship funds")
	t.assert_false(state.purchase_ship_part(str(first.id)).ok, "The minimum thirty-million-won operating reserve cannot buy spaceship parts")
	t.assert_true(state.accept_contract(), "The reserve fixture accepts a real construction commission")
	var advance: int = int(state.current_contract().advance)
	t.assert_eq(state.balance, State.INITIAL_BALANCE + advance, "The building account includes the customer's advance")
	t.assert_eq(state.ship_available_funds(), 0, "An active customer's advance contributes no spendable spaceship funds")
	var untouched: Dictionary = state.serialize()
	t.assert_false(state.purchase_ship_part(str(first.id)).ok, "A large client advance cannot fund a spaceship purchase")
	t.assert_eq(state.serialize(), untouched, "A denied advance-funded purchase leaves the whole ledger unchanged")
	t.assert_true(_earn_construction(state, int(first.price)), "Real construction income eventually makes the first part affordable")
	state.set_my_house_mode(true)
	for row: int in range(2):
		for column: int in range(10):
			t.assert_gt(state.my_house_document.add_part("door", Vector2(100 + column * 180, 500 - row * 200)), 0, "Private-house materials are legally purchased and placed")
	var house: Dictionary = state.my_house_document.serialize()
	var house_cost: int = state.my_house_cost()
	t.assert_gt(house_cost, 0, "The private-house fixture reserves meaningful material costs")
	t.assert_eq(state.ship_available_funds(), maxi(0, state.saved_balance() - State.INITIAL_BALANCE - house_cost), "Spendable funds subtract both existing private-house materials and the operating reserve")
	t.assert_true(state.ship_available_funds() < int(first.price), "Private-house reservations make this otherwise affordable part unavailable")
	t.assert_false(state.purchase_ship_part(str(first.id)).ok, "Buying a part cannot consume money reserved by the existing private house")
	t.assert_eq(state.my_house_document.serialize(), house, "A rejected purchase preserves every private-house part")
	state.my_house_document.clear()
	state.set_my_house_mode(false)
	t.assert_true(state.select_contract(0) and state.accept_contract(), "A new active job can coexist with spaceship purchases")
	advance = int(state.current_contract().advance)
	state.document.add_part("brick", Vector2(500, 550))
	var construction: Document = state.document
	var construction_snapshot: Dictionary = construction.serialize()
	var construction_history: int = construction.command_manager.undo_stack.size()
	var stages: Dictionary = state.stage_unlock_status(3)
	var savings_before: int = state.saved_balance()
	var purchased: Dictionary = state.purchase_ship_part(str(first.id))
	t.assert_true(purchased.ok, "Earned unrestricted funds can buy a spaceship part during an active commission")
	t.assert_eq(state.saved_balance(), savings_before - int(first.price), "A purchase deducts exactly the listed price from savings")
	t.assert_eq(state.balance - state.saved_balance(), advance, "The customer's advance is preserved after a spaceship purchase")
	t.assert_true(state.saved_balance() >= State.INITIAL_BALANCE, "A successful purchase retains the full operating reserve")
	t.assert_true(state.document == construction, "Purchasing does not replace the live construction document")
	t.assert_eq(construction.serialize(), construction_snapshot, "Purchasing leaves the active job's geometry unchanged")
	t.assert_eq(construction.command_manager.undo_stack.size(), construction_history, "Purchasing leaves construction Undo commands intact")
	t.assert_eq(state.stage_unlock_status(3), stages, "Buying parts cannot revoke historical construction-stage achievements")
	untouched = state.serialize()
	t.assert_false(state.purchase_ship_part(str(first.id)).ok, "An owned spaceship part cannot be charged twice")
	t.assert_false(state.purchase_ship_part("unknown_part").ok, "An unknown spaceship part is rejected")
	t.assert_eq(state.serialize(), untouched, "Duplicate and unknown purchases do not alter money or ownership")
	var restored: State = State.new()
	t.assert_true(restored.restore(_json_copy(state.serialize())), "Purchases, historical earnings and an active advance reconcile on reload")
	t.assert_eq(restored.balance, state.balance, "Reloading preserves the exact post-purchase construction balance")
	t.assert_eq(restored.purchased_ship_parts, state.purchased_ship_parts, "Reloading preserves purchased part ownership")

static func _test_invalid_restores(t: Node) -> void:
	var state: State = State.new()
	state.sell_art(_artwork().serialize())
	state.accept_contract()
	state.document.add_part("brick", Vector2(500, 550))
	state.document.move_selected(Vector2(540, 550))
	state.set_my_house_mode(true)
	state.my_house_document.add_part("brick", Vector2(400, 550))
	var valid: Dictionary = _json_copy(state.serialize())
	var malformed: Array[Dictionary] = []
	var bad: Dictionary = valid.duplicate(true)
	bad.space_economy.art_sales[0].price += 100
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.art_sales[0].signature = "invalid"
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.art_sales.append(bad.space_economy.art_sales[0].duplicate(true))
	bad.balance += int(bad.space_economy.art_sales[0].price)
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.purchased_parts = ["unknown_part"]
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.purchased_parts = ["hull", "hull"]
	bad.balance -= int(Ship.part("hull").price) * 2
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.purchased_parts = ["hull", "hull_advanced"]
	bad.balance -= int(Ship.part("hull").price) + int(Ship.part("hull_advanced").price)
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.launched = true
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.launched = "true"
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.balance += 100
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.purchased_parts = ["hull"]
	bad.balance -= int(Ship.part("hull").price)
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.version = 999
	malformed.append(bad)
	bad = valid.duplicate(true)
	bad.space_economy.art_sales = "invalid"
	malformed.append(bad)
	for index: int in range(malformed.size()):
		var before: Dictionary = state.serialize()
		var document: Document = state.document
		var house: Document = state.my_house_document
		var undo_count: int = document.command_manager.undo_stack.size()
		var house_undo: int = house.command_manager.undo_stack.size()
		t.assert_false(state.restore(malformed[index]), "Malformed space ledger case %d is rejected before applying live fields" % index)
		t.assert_eq(state.serialize(), before, "Malformed ledger case %d leaves every financial and geometry field unchanged" % index)
		t.assert_true(state.document == document and state.my_house_document == house, "Rejected restore preserves both live document identities")
		t.assert_eq(document.command_manager.undo_stack.size(), undo_count, "Rejected restore preserves active construction Undo history")
		t.assert_eq(house.command_manager.undo_stack.size(), house_undo, "Rejected restore preserves private-house Undo history")

static func _test_durable_transactions(t: Node) -> void:
	var state: State = State.new()
	t.assert_true(_earn_construction(state, 25000000), "Transaction fixture earns sufficient funds through real commissions")
	state.select_contract(0)
	state.accept_contract()
	state.document.add_part("brick", Vector2(500, 550))
	state.document.move_selected(Vector2(540, 550))
	state.set_my_house_mode(true)
	state.my_house_document.add_part("brick", Vector2(400, 550))
	state.my_house_document.move_selected(Vector2(440, 550))
	state.my_house_document.undo()
	var drawing: Drawing = _artwork()
	var drawing_before: Dictionary = drawing.serialize()
	var drawing_history: int = drawing.command_manager.undo_stack.size()
	var path: String = "res://.godot/space_economy_%d.json" % Time.get_ticks_usec()
	var invalid_path: String = "res://.godot/missing_space_economy_%d/ledger.json" % Time.get_ticks_usec()
	var documents: Array[Document] = [state.document, state.my_house_document]
	var snapshots: Array[Dictionary] = [documents[0].serialize(), documents[1].serialize()]
	var undo_sizes: Array[int] = [documents[0].command_manager.undo_stack.size(), documents[1].command_manager.undo_stack.size()]
	var redo_sizes: Array[int] = [documents[0].command_manager.redo_stack.size(), documents[1].command_manager.redo_stack.size()]
	var before: Dictionary = state.serialize()
	var result: Dictionary = Transactions.commit(state, "sell_art", drawing.serialize(), invalid_path)
	t.assert_false(result.ok, "A painting sale is cancelled when its save cannot be written")
	t.assert_true(str(result.error).contains("저장"), "A failed durable sale explains the save failure")
	t.assert_eq(state.serialize(), before, "A failed sale credits no money and records no sold artwork")
	_assert_live_documents(t, state, documents, snapshots, undo_sizes, redo_sizes)
	result = Transactions.commit(state, "sell_art", drawing.serialize(), path)
	t.assert_true(result.ok, "The same painting remains sellable after storage becomes available")
	t.assert_eq(state.art_sales.size(), 1, "A committed durable sale creates exactly one receipt")
	_assert_live_documents(t, state, documents, snapshots, undo_sizes, redo_sizes)
	t.assert_eq(drawing.serialize(), drawing_before, "Durable sales preserve the original artwork")
	t.assert_eq(drawing.command_manager.undo_stack.size(), drawing_history, "Durable sales preserve drawing Undo history")
	var loaded: State = State.new()
	t.assert_true(Saves.load_into(path, loaded).ok, "A committed sale can be read from the published save")
	t.assert_eq(_json_copy(loaded.serialize()), _json_copy(state.serialize()), "The durable sale and live state have the same exact ledger and documents")
	before = state.serialize()
	result = Transactions.commit(state, "purchase_part", "hull", invalid_path)
	t.assert_false(result.ok, "A part purchase is cancelled when its save fails")
	t.assert_eq(state.serialize(), before, "A failed purchase neither deducts money nor grants the part")
	_assert_live_documents(t, state, documents, snapshots, undo_sizes, redo_sizes)
	t.assert_true(Transactions.commit(state, "purchase_part", "hull", path).ok, "Retrying a failed purchase succeeds once it can be durably saved")
	t.assert_eq(state.purchased_ship_parts, ["hull"], "Successful purchase records one owned part")
	t.assert_eq(state.my_house_document.budget_limit, state.saved_balance(), "Successful financial commit updates the private-house budget")
	_assert_live_documents(t, state, documents, snapshots, undo_sizes, redo_sizes)
	t.assert_true(Saves.load_into(path, loaded).ok, "A committed purchase can be restored from disk")
	t.assert_eq(_json_copy(loaded.serialize()), _json_copy(state.serialize()), "Disk and live state agree after buying the part")
	var legacy_ship: Dictionary = _json_copy(state.serialize())
	t.assert_true(loaded.restore(legacy_ship) and loaded.ship_design.is_empty(), "An older purchased ship uses its original design by default")
	legacy_ship.space_economy.design = {"hull": {"kind": "rhombus", "color": "e31881"}}
	t.assert_true(loaded.restore(legacy_ship), "The previous color design save is still loadable")
	t.assert_eq(loaded.purchased_ship_parts, ["hull"], "An older design retains its paid component")
	t.assert_eq(loaded.ship_design, legacy_ship.space_economy.design, "Restoring a legacy ledger preserves its existing design data")
	before = state.serialize()
	var upgrade_price: int = int(Ship.part("hull_advanced").price) - int(Ship.part("hull").price)
	t.assert_eq(state.ship_purchase_price("hull_advanced"), upgrade_price, "The upgrade quote credits the existing model's price")
	t.assert_false(Transactions.commit(state, "purchase_part", "hull_advanced", invalid_path).ok, "A failed save cannot install the higher-tier model")
	t.assert_eq(state.serialize(), before, "The failed upgrade preserves the whole save")
	var upgraded: Dictionary = Transactions.commit(state, "purchase_part", "hull_advanced", path)
	t.assert_true(upgraded.ok and upgraded.upgraded, "An owned hull can be upgraded and saved")
	t.assert_eq(int(upgraded.price), upgrade_price, "Upgrading charges only the quoted difference")
	t.assert_eq(state.balance, int(before.balance) - upgrade_price, "The old and new model are not both charged")
	t.assert_eq(state.purchased_ship_parts, ["hull_advanced"], "Upgrading replaces the old model without filling another slot")
	t.assert_eq(state.ship_spent(), Ship.part("hull_advanced").price, "Total investment equals the fitted model's price")
	t.assert_eq(state.ship_performance(), 2, "A higher tier raises the ship's actual performance score")
	t.assert_true(Saves.load_into(path, loaded).ok, "An upgraded ship reloads from disk")
	t.assert_eq(loaded.installed_ship_part("hull").id, "hull_advanced", "Reload keeps the exact upgraded model mounted in the same slot")
	var corrupted_design: Dictionary = _json_copy(loaded.serialize())
	corrupted_design.space_economy.design = {"nose": {"kind": "square", "color": "ffffff"}}
	t.assert_false(loaded.restore(corrupted_design), "A configuration for an unowned part cannot enter the ledger")
	corrupted_design.space_economy.design = {"hull_advanced": {"kind": "square", "color": "ffffff"}}
	t.assert_false(loaded.restore(corrupted_design), "New models do not accept legacy shape or color choices")
	corrupted_design = _json_copy(legacy_ship)
	corrupted_design.space_economy.design.hull.color = "e3188180"
	t.assert_false(loaded.restore(corrupted_design), "A save cannot make a purchased part translucent")
	_assert_live_documents(t, state, documents, snapshots, undo_sizes, redo_sizes)
	before = state.serialize()
	var published: String = FileAccess.get_file_as_string(path)
	t.assert_false(Transactions.commit(state, "purchase_part", "hull_advanced", path).ok, "Durable transaction layer rejects duplicate purchases")
	t.assert_false(Transactions.commit(state, "purchase_part", "hull", path).ok, "A cheaper duplicate cannot replace an installed upgraded model")
	t.assert_false(Transactions.commit(state, "sell_art", drawing.serialize(), path).ok, "Durable transaction layer also rejects a paid artwork")
	t.assert_false(Transactions.commit(state, "purchase_part", 7, path).ok, "A malformed purchase payload is rejected")
	t.assert_false(Transactions.commit(state, "sell_art", "wrong", path).ok, "A malformed sale payload is rejected")
	t.assert_false(Transactions.commit(state, "unknown", null, path).ok, "Unknown transaction actions are rejected")
	t.assert_eq(state.serialize(), before, "Rejected transactions cannot mutate the live account")
	t.assert_eq(FileAccess.get_file_as_string(path), published, "Rejected transactions do not replace the previously published save")
	_cleanup_save(path)

static func _test_complete_ship(t: Node) -> void:
	var state: State = State.new()
	t.assert_false(state.launch_ship().ok, "A fresh game cannot launch an unbuilt spaceship")
	t.assert_false(state.launched, "Premature launch does not set the ending flag")
	t.assert_true(_earn_construction(state, Ship.total_price()), "Repeated legal construction work can eventually pay for all twelve expensive parts")
	t.assert_gt(state.records.size(), 12, "Finishing the spaceship requires substantial play rather than one contract per part")
	var earned: int = state.earned_profit()
	var stages: Dictionary = state.stage_unlock_status(9)
	var spent: int = 0
	for part: Dictionary in Ship.all_parts():
		t.assert_false(state.launch_ship().ok, "Launch stays locked until the final missing part has been purchased")
		var before: int = state.balance
		t.assert_true(state.purchase_ship_part(str(part.id)).ok, "An earned spaceship component can be purchased individually")
		spent += int(part.price)
		t.assert_eq(state.balance, before - int(part.price), "Each component deducts its own exact catalog price")
		t.assert_eq(state.ship_spent(), spent, "Cumulative spending matches the owned components")
		t.assert_true(state.saved_balance() >= State.INITIAL_BALANCE, "Every step retains the minimum operating reserve")
	t.assert_eq(state.purchased_ship_parts.size(), 12, "The completed spaceship contains all twelve purchased parts")
	t.assert_true(state.ship_complete(), "The complete catalog ownership unlocks departure")
	t.assert_eq(state.saved_balance(), State.INITIAL_BALANCE + earned - Ship.total_price(), "The completed spaceship reconciles to income minus its full twelve-part price")
	t.assert_eq(state.stage_unlock_status(9), stages, "Even the complete expensive spaceship cannot remove earned construction access")
	var before_launch: Dictionary = state.serialize()
	var invalid_path: String = "res://.godot/missing_space_launch_%d/ledger.json" % Time.get_ticks_usec()
	t.assert_false(Transactions.commit(state, "launch", null, invalid_path).ok, "Departure waits for its completion flag to be durably saved")
	t.assert_eq(state.serialize(), before_launch, "A failed launch save preserves the complete unlaunched spaceship")
	var path: String = "res://.godot/space_launch_%d.json" % Time.get_ticks_usec()
	var launch: Dictionary = Transactions.commit(state, "launch", null, path)
	t.assert_true(launch.ok and not launch.replay, "The first successful saved launch reports a new departure")
	t.assert_true(state.launched, "The durable departure sets the ending flag")
	var restored: State = State.new()
	t.assert_true(Saves.load_into(path, restored).ok, "A completed spaceship and departure restore from disk")
	t.assert_true(restored.launched and restored.ship_complete(), "Reloaded completion keeps both all parts and the ending flag")
	t.assert_eq(restored.balance, state.balance, "Launching and reloading never invent an extra monetary reward")
	var completed: Dictionary = restored.serialize()
	var replay: Dictionary = restored.launch_ship()
	t.assert_true(replay.ok and replay.replay, "A completed player may replay the departure animation")
	t.assert_eq(restored.serialize(), completed, "Replaying departure does not change money, ownership or completed records")
	_cleanup_save(path)

static func _assert_live_documents(t: Node, state: State, documents: Array[Document], snapshots: Array[Dictionary], undo_sizes: Array[int], redo_sizes: Array[int]) -> void:
	t.assert_true(state.document == documents[0] and state.my_house_document == documents[1], "Financial transactions preserve both live document identities")
	for index: int in range(documents.size()):
		t.assert_eq(documents[index].serialize(), snapshots[index], "Financial transactions preserve existing geometry and selection")
		t.assert_eq(documents[index].command_manager.undo_stack.size(), undo_sizes[index], "Financial transactions preserve the complete Undo stack")
		t.assert_eq(documents[index].command_manager.redo_stack.size(), redo_sizes[index], "Financial transactions preserve the complete Redo stack")

static func _artwork(alternate: bool = false) -> Drawing:
	return ArtSamples.house(alternate)

static func _earn_construction(state: State, minimum_profit: int) -> bool:
	# Every won comes from the existing accept/build/evaluate/settle APIs. No
	# balances, paid records or market receipts are fabricated by this fixture.
	var iterations: int = 0
	while state.earned_profit() < minimum_profit and iterations < 100:
		if state.phase != "building":
			var choice: int = 0
			for candidate: int in range(Catalog.contract_count()):
				if bool(state.stage_unlock_status(candidate + 1).unlocked): choice = candidate
			if not state.select_contract(choice) or not state.accept_contract(): return false
		if not state.document.replace_parts(Guide.example_for_contract(state.current_contract())): return false
		var ids: Array[int] = []
		for part: Dictionary in state.document.parts: ids.append(int(part.id))
		var inspection: Dictionary = {"stable": true, "stable_ids": ids, "unsupported_ids": [], "revision": state.document.revision}
		if state.settle(inspection).is_empty(): return false
		iterations += 1
	return state.earned_profit() >= minimum_profit

static func _json_copy(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))

static func _cleanup_save(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
