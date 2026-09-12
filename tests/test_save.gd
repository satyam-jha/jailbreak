extends RefCounted
## Save/load: the run state has to survive a round trip through JSON intact.


## JSON has no integer type, so a round trip turns every whole number into a
## float. Comparing the raw text would fail on that alone, which says nothing
## about whether the map still works - so compare the shape the game reads back,
## coerced the same way the game coerces it.
static func _map_shape(map: Dictionary) -> Array:
	var nodes: Dictionary = map.get("nodes", {})
	var ids: Array = nodes.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		var n: Dictionary = nodes[id]
		out.append([
			str(n.get("id", "")), str(n.get("room_id", "")),
			int(n.get("layer", 0)), int(n.get("index", 0)),
			int(n.get("path_type", 0)), bool(n.get("is_final", false)),
			str((n.get("gate", {}) as Dictionary).get("label", "")),
			(n.get("connections", []) as Array).duplicate(),
		])
	out.append([str(map.get("start", "")), str(map.get("final", "")), int(map.get("layer_count", 0))])
	return out



static func run(t: TestRunner) -> void:
	t.suite("Save and load")

	Game.start_run(606060)
	while not Game.party_is_full():
		Game.recruit(Game.draw_candidates()[0])
	Game.lock_party_and_generate_prison()

	# Make the state genuinely messy before saving it.
	Game.add_heat(37)
	Game.add_money(215)
	(Game.party[0] as Prisoner).apply_damage(4)
	(Game.party[1] as Prisoner).set_status("scared")
	(Game.party[2] as Prisoner).add_stat_bonus("stealth", 3)
	Game.take_powerup({
		"id": "guard_schedule", "def": Content.get_powerup("guard_schedule"),
		"catch_id": "counterfeit", "has_catch": true, "revealed": false,
		"rooms_since_taken": 2, "cancelled": false})
	Game.add_notable("Somebody did something regrettable in the laundry.")
	Game.rooms_cleared = 4
	Game.guards_fooled = 9

	var snapshot := Game.to_dict()

	# Round trip through actual JSON text, not just the dictionary, because that
	# is what the save file really goes through.
	var text := JSON.stringify(snapshot)
	var parsed: Variant = JSON.parse_string(text)
	t.check(typeof(parsed) == TYPE_DICTIONARY, "the run state serialises to valid JSON")

	var expected_heat := Game.heat
	var expected_money := Game.money
	var expected_party: Array = []
	for m in Game.party:
		var p: Prisoner = m
		expected_party.append([p.id, p.health, p.status, p.effective_stat("stealth")])
	var expected_map := _map_shape(Game.map)
	var expected_notable := Game.notable.duplicate()

	# Wipe the run, then restore it.
	Game.start_run(1)
	t.check(Game.party.is_empty(), "starting a new run clears the old one")

	t.check(Game.from_dict(parsed as Dictionary), "a serialised run loads back")
	t.equal(Game.heat, expected_heat, "Heat survives the round trip")
	t.equal(Game.money, expected_money, "money survives the round trip")
	t.equal(Game.seed_value, 606060, "the seed survives the round trip")
	t.equal(Game.rooms_cleared, 4, "progress counters survive the round trip")
	t.equal(Game.guards_fooled, 9, "run statistics survive the round trip")
	t.equal(_map_shape(Game.map), expected_map, "the generated prison survives the round trip")
	t.equal(Game.notable, expected_notable, "the story log survives the round trip")

	var restored_party: Array = []
	for m in Game.party:
		var p: Prisoner = m
		restored_party.append([p.id, p.health, p.status, p.effective_stat("stealth")])
	t.equal(restored_party, expected_party, "every crew member's health, status and stats survive")

	t.equal(Game.powerups.size(), 1, "power-ups survive the round trip")
	var offer: Dictionary = Game.powerups[0]
	t.equal(str(offer["id"]), "guard_schedule", "the restored power-up is the right one")
	t.check(bool(offer["has_catch"]), "a hidden catch stays attached across a save")
	t.equal(str(offer["catch_id"]), "counterfeit", "the specific catch stays attached across a save")
	t.equal(int(offer["rooms_since_taken"]), 2, "the catch's countdown is preserved")
	t.check(not bool(offer["revealed"]), "a hidden catch is still hidden after loading")

	# And the whole thing through the real file, in the real location.
	Game.start_run(606060)
	while not Game.party_is_full():
		Game.recruit(Game.draw_candidates()[0])
	Game.lock_party_and_generate_prison()
	Game.add_heat(11)
	var file_heat := Game.heat
	t.check(SaveSystem.save_run(), "the run writes to user://")
	t.check(SaveSystem.has_run(), "the save file exists afterwards")
	Game.start_run(2)
	t.check(SaveSystem.load_run(), "the run reads back from user://")
	t.equal(Game.heat, file_heat, "the file round trip preserves the run")
	SaveSystem.delete_run()
	t.check(not SaveSystem.has_run(), "deleting the save removes the file")

	# A save from a future version must be refused rather than half-applied.
	var future := Game.to_dict()
	future["version"] = SaveSystem.SAVE_VERSION + 99
	var f := FileAccess.open(SaveSystem.RUN_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(future))
	f.close()
	t.check(not SaveSystem.load_run(), "a save from an unknown version is refused")
	SaveSystem.delete_run()
