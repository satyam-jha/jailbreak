extends RefCounted
## Plays complete runs headlessly, start to summary, with no UI involved.
##
## This is the test that matters most: it walks the exact code path the screens
## walk, across many seeds, and asserts that every run reaches an ending without
## stalling, softlocking, or producing impossible state.

const RUNS := 60
const MAX_ROOMS := 40


static func run(t: TestRunner) -> void:
	t.suite("Full run simulation")

	var endings: Dictionary = {}
	var stalled: Array = []
	var no_choice: Array = []
	var bad_state: Array = []
	var powerups_taken := 0
	var catches_fired := 0
	var total_rooms := 0
	var events_seen: Dictionary = {}

	for i in range(RUNS):
		var seed_value := 500000 + i * 13
		var outcome := _play_one(seed_value, t)

		if not str(outcome["stall"]).is_empty():
			stalled.append("seed %d: %s" % [seed_value, str(outcome["stall"])])
		no_choice.append_array(outcome["no_choice"])
		bad_state.append_array(outcome["bad_state"])
		endings[str(outcome["result"])] = int(endings.get(str(outcome["result"]), 0)) + 1
		powerups_taken += int(outcome["powerups"])
		catches_fired += int(outcome["catches"])
		total_rooms += int(outcome["rooms"])
		for eid in outcome["events"]:
			events_seen[str(eid)] = true

	t.check(stalled.is_empty(), "no run ever stalls (%s)" % str(stalled.slice(0, 3)))
	t.check(no_choice.is_empty(), "every encounter always offers at least one usable choice (%s)" % str(no_choice.slice(0, 3)))
	t.check(bad_state.is_empty(), "run state stays legal throughout (%s)" % str(bad_state.slice(0, 3)))
	t.equal(endings.get("", 0), 0, "every run reaches a definite ending")
	t.check(endings.has("escaped"), "some runs are won (%s)" % str(endings))
	t.check(endings.has("caught") or endings.has("disaster"), "some runs are lost (%s)" % str(endings))
	t.check(powerups_taken > RUNS, "power-ups are offered repeatedly across a run (%d over %d runs)" % [powerups_taken, RUNS])
	t.check(catches_fired > 0, "hidden catches do go off in real play (%d)" % catches_fired)
	t.check(total_rooms >= RUNS * 3, "runs last a reasonable number of rooms (%d total)" % total_rooms)
	t.check(events_seen.size() >= 15, "a wide spread of events actually fires (%d distinct)" % events_seen.size())

	# Replaying a seed reproduces the run exactly.
	var a := _play_one(123456, t)
	var b := _play_one(123456, t)
	t.equal(str(a["result"]), str(b["result"]), "replaying a seed reaches the same ending")
	t.equal(int(a["rooms"]), int(b["rooms"]), "replaying a seed clears the same number of rooms")
	t.equal(a["events"], b["events"], "replaying a seed fires the same events in the same order")


static func _play_one(seed_value: int, t: TestRunner) -> Dictionary:
	var report := {
		"result": "", "stall": "", "rooms": 0, "powerups": 0, "catches": 0,
		"no_choice": [], "bad_state": [], "events": [],
	}

	Game.start_run(seed_value)
	while not Game.party_is_full():
		var candidates := Game.draw_candidates()
		if candidates.is_empty():
			report["stall"] = "ran out of candidates"
			return report
		Game.recruit(candidates[Rng.roll_int(0, candidates.size() - 1)])
	Game.lock_party_and_generate_prison()

	var guard := 0
	while guard < MAX_ROOMS:
		guard += 1

		if Game.at_final_room():
			break

		var options: Array = []
		for node_id in Game.reachable_nodes():
			if PrisonGenerator.party_can_enter(Game.node(node_id), Game.party):
				options.append(node_id)
		if options.is_empty():
			report["stall"] = "no enterable room from %s" % Game.current_node_id
			return report

		var target: String = str(options[Rng.roll_int(0, options.size() - 1)])
		Game.enter_node(target)
		report["catches"] = int(report["catches"]) + Game.fire_catches("on_room_enter").size()

		var event := Game.current_event
		if not event.is_empty():
			(report["events"] as Array).append(str(event.get("id", "")))
			var usable: Array = []
			for choice in event.get("choices", []):
				if bool(EncounterEngine.choice_availability(choice, Game.party, Game.money)["available"]):
					usable.append(choice)
			if usable.is_empty():
				(report["no_choice"] as Array).append("seed %d, event %s" % [seed_value, str(event.get("id", ""))])
			else:
				var choice: Dictionary = usable[Rng.roll_int(0, usable.size() - 1)]
				var actor: Prisoner = null
				if not bool(choice.get("auto", false)):
					actor = EncounterEngine.best_actor(choice, Game.party)
				var result := Game.resolve_choice(choice, actor)
				report["catches"] = int(report["catches"]) + (result["catches"] as Array).size()

		_assert_legal_state(report, seed_value)

		if not Game.check_run_over().is_empty():
			report["result"] = Game.result
			report["rooms"] = Game.rooms_cleared
			return report

		Game.clear_current_room()
		report["rooms"] = Game.rooms_cleared

		if Game.room_awards_powerup():
			var offers := PowerupSystem.generate_offers(Game.owned_powerup_ids())
			if not offers.is_empty():
				var picked: Dictionary = offers[Rng.roll_int(0, offers.size() - 1)]
				var target_member: Prisoner = null
				if str((picked.get("def", {}) as Dictionary).get("target", "party")) == "one":
					target_member = Game.random_available_member()
				var taken := Game.take_powerup(picked, target_member)
				report["powerups"] = int(report["powerups"]) + 1
				report["catches"] = int(report["catches"]) + (taken["catches"] as Array).size()

		_assert_legal_state(report, seed_value)

	if guard >= MAX_ROOMS:
		report["stall"] = "hit the room guard without reaching the wall"
		return report

	# The escape.
	var routes := EscapeSystem.routes()
	var route: Dictionary = routes[Rng.roll_int(0, routes.size() - 1)]
	Game.escape_route_id = str(route.get("id", ""))
	report["catches"] = int(report["catches"]) + Game.fire_catches("at_escape").size()

	var results: Array = []
	for step_index in range(EscapeSystem.step_count(route)):
		var actor := Game.random_available_member()
		if actor == null:
			break
		var check := EscapeSystem.resolve_step(route, step_index, actor)
		if check == null:
			break
		EscapeSystem.apply_step_outcome(route, step_index, actor, check)
		results.append(check)

	var verdict := EscapeSystem.evaluate(route, results)
	Game.finish_run(str(verdict["result"]), str(verdict["headline"]), str(verdict["detail"]))

	_assert_legal_state(report, seed_value)
	var summary := Game.summary()
	if int(summary["score"]) < 0:
		(report["bad_state"] as Array).append("seed %d: negative score" % seed_value)

	report["result"] = Game.result
	report["rooms"] = Game.rooms_cleared
	return report


static func _assert_legal_state(report: Dictionary, seed_value: int) -> void:
	var problems: Array = report["bad_state"]
	if Game.heat < 0 or Game.heat > Game.MAX_HEAT:
		problems.append("seed %d: Heat out of range (%d)" % [seed_value, Game.heat])
	if Game.money < 0:
		problems.append("seed %d: negative money (%d)" % [seed_value, Game.money])
	if Game.party.size() != Game.PARTY_SIZE:
		problems.append("seed %d: party size drifted to %d" % [seed_value, Game.party.size()])
	for m in Game.party:
		var p: Prisoner = m
		if p.health < 0 or p.health > p.max_health:
			problems.append("seed %d: %s health out of range (%d/%d)" % [seed_value, p.id, p.health, p.max_health])
		if Content.get_status(p.status).is_empty():
			problems.append("seed %d: %s has unknown status %s" % [seed_value, p.id, p.status])
		for stat in Content.stat_keys:
			var value := p.effective_stat(stat)
			if value < 1 or value > 20:
				problems.append("seed %d: %s %s = %d" % [seed_value, p.id, stat, value])
