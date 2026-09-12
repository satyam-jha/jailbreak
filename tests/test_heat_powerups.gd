extends RefCounted
## Heat clamping, power-up offers, the hidden catch, and effect application.


static func run(t: TestRunner) -> void:
	t.suite("Heat, resources and power-ups")

	Game.start_run(4242)
	while not Game.party_is_full():
		var candidates := Game.draw_candidates()
		Game.recruit(candidates[0])

	# Heat is clamped at both ends, whatever is thrown at it.
	Game.set_heat(50)
	Game.add_heat(-9999)
	t.equal(Game.heat, 0, "Heat never drops below 0")
	Game.add_heat(9999)
	t.equal(Game.heat, Game.MAX_HEAT, "Heat never rises above 100")
	Game.set_heat(50)
	t.equal(Game.heat, 50, "Heat can be set directly")

	# Every point of 0-100 lands in exactly one band.
	var unbanded := 0
	for value in range(0, 101):
		var band := Content.heat_band(value)
		if band.is_empty() or str(band.get("name", "")).is_empty():
			unbanded += 1
	t.equal(unbanded, 0, "every Heat value 0-100 maps to a band")

	# Money never goes negative.
	Game.add_money(-99999)
	t.equal(Game.money, 0, "money never goes negative")
	Game.add_money(120)
	t.equal(Game.money, 120, "money adds normally")

	# Calming effects reduce generated Heat but never invert it.
	Game.set_heat(20)
	var calm := Prisoner.from_def(Content.get_character_def("silky_pete"))
	var scaled := Game.scale_generated_heat(10, calm)
	t.check(scaled < 10 and scaled >= 1, "Unreasonably Calm reduces generated Heat without eliminating it (%d)" % scaled)
	t.equal(Game.scale_generated_heat(-8, calm), -8, "Heat reductions are never scaled away")

	# --- Power-up offers -------------------------------------------------
	var offers_wrong_size := 0
	var wrong_catch_count := 0
	var duplicate_offers := 0
	var catch_ids: Dictionary = {}
	var cursed_positions: Dictionary = {}
	var cursed_powerups: Dictionary = {}

	for i in range(400):
		Rng.start_run(9000 + i)
		var offers := PowerupSystem.generate_offers([])
		if offers.size() != PowerupSystem.OFFER_COUNT:
			offers_wrong_size += 1
			continue
		var with_catch := 0
		var seen: Dictionary = {}
		for index in range(offers.size()):
			var offer: Dictionary = offers[index]
			if seen.has(offer["id"]):
				duplicate_offers += 1
			seen[offer["id"]] = true
			if bool(offer["has_catch"]):
				with_catch += 1
				cursed_positions[index] = true
				cursed_powerups[str(offer["id"])] = true
				catch_ids[str(offer["catch_id"])] = true
				if PowerupSystem.catch_for(offer).is_empty():
					wrong_catch_count += 1
		if with_catch != 1:
			wrong_catch_count += 1

	t.equal(offers_wrong_size, 0, "every offer is exactly 5 cards")
	t.equal(wrong_catch_count, 0, "exactly one card carries a real catch, every time")
	t.equal(duplicate_offers, 0, "a single offer never repeats a power-up")
	t.equal(cursed_positions.size(), PowerupSystem.OFFER_COUNT, "the trapped card appears in every position")
	t.check(cursed_powerups.size() > 10, "the catch is attached to many different power-ups, so it cannot be memorised (%d)" % cursed_powerups.size())
	t.check(catch_ids.size() >= 5, "many different catches are used (%d)" % catch_ids.size())

	# Already-owned power-ups are not offered again.
	Rng.start_run(5150)
	var owned: Array = []
	for p in Content.powerup_defs.slice(0, 6):
		owned.append(str(p.get("id", "")))
	var fresh := PowerupSystem.generate_offers(owned)
	var repeats := 0
	for offer in fresh:
		if owned.has(str(offer["id"])):
			repeats += 1
	t.equal(repeats, 0, "power-ups you already hold are not offered again")

	# --- Effects actually apply ------------------------------------------
	Game.start_run(1234)
	while not Game.party_is_full():
		Game.recruit(Game.draw_candidates()[0])

	var before_stealth := (Game.party[0] as Prisoner).effective_stat("stealth")
	var quiet_shoes := {"id": "quiet_shoes", "def": Content.get_powerup("quiet_shoes"),
		"catch_id": "", "has_catch": false, "revealed": false, "rooms_since_taken": 0, "cancelled": false}
	Game.take_powerup(quiet_shoes)
	t.equal((Game.party[0] as Prisoner).effective_stat("stealth"), before_stealth + 2, "a party stat power-up applies to the whole crew")

	var money_before := Game.money
	var cash := {"id": "cash_roll", "def": Content.get_powerup("cash_roll"),
		"catch_id": "", "has_catch": false, "revealed": false, "rooms_since_taken": 0, "cancelled": false}
	Game.take_powerup(cash)
	t.equal(Game.money, money_before + 80, "a money power-up pays out immediately")

	# A standing check bonus reaches the skill check.
	var plain := Game.build_situation(["tech"])
	var mystery := {"id": "mystery_key", "def": Content.get_powerup("mystery_key"),
		"catch_id": "", "has_catch": false, "revealed": false, "rooms_since_taken": 0, "cancelled": false}
	Game.take_powerup(mystery)
	var boosted := Game.build_situation(["tech"])
	var plain_total := 0
	for m in plain["bonuses"]:
		plain_total += int(m["value"])
	var boosted_total := 0
	for m in boosted["bonuses"]:
		boosted_total += int(m["value"])
	t.equal(boosted_total - plain_total, 15, "a standing check bonus reaches the skill check")

	# --- Catch triggers ---------------------------------------------------
	var delayed_catch := Content.get_catch("counterfeit")
	var offer := {"id": "cash_roll", "def": Content.get_powerup("cash_roll"),
		"catch_id": "counterfeit", "has_catch": true, "revealed": false,
		"rooms_since_taken": 0, "cancelled": false}
	t.check(not PowerupSystem.catch_should_fire(offer, "on_room_enter", 0), "a delayed catch holds off at first")
	offer["rooms_since_taken"] = int(delayed_catch.get("after", 2))
	t.check(PowerupSystem.catch_should_fire(offer, "on_room_enter", 0), "a delayed catch fires once its rooms have passed")
	t.equal(PowerupSystem.pending_hint(offer).is_empty(), false, "a carried catch eventually leaks a hint")

	var fresh_offer := {"id": "cash_roll", "def": Content.get_powerup("cash_roll"),
		"catch_id": "counterfeit", "has_catch": true, "revealed": false,
		"rooms_since_taken": 0, "cancelled": false}
	t.check(PowerupSystem.pending_hint(fresh_offer).is_empty(), "the hint is withheld on the room the card is taken")

	var money_at_reveal := Game.money
	EffectResolver.apply_catch(delayed_catch, offer)
	t.check(bool(offer["revealed"]), "firing a catch marks it revealed")
	t.check(Game.money < money_at_reveal, "the counterfeit catch actually costs money")
	t.check(not PowerupSystem.catch_should_fire(offer, "on_room_enter", 0), "a revealed catch never fires twice")

	# A cancelling catch switches its power-up off.
	var one_use := Content.get_catch("one_use_only")
	var cancel_offer := {"id": "quiet_shoes", "def": Content.get_powerup("quiet_shoes"),
		"catch_id": "one_use_only", "has_catch": true, "revealed": false,
		"rooms_since_taken": 3, "cancelled": false}
	EffectResolver.apply_catch(one_use, cancel_offer)
	t.check(bool(cancel_offer["cancelled"]), "the single-use catch cancels its power-up")
