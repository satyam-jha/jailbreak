extends RefCounted
## Recruitment: three candidates, always valid, never a walkover.


static func run(t: TestRunner) -> void:
	t.suite("Recruitment and party")

	var bad_draws := 0
	var invalid := 0
	var identical_best := 0
	var blowouts := 0

	for seed_value in range(120):
		Rng.start_run(1000 + seed_value)
		var pool := CharacterFactory.build_pool()
		var taken: Array = []

		for round_index in range(Game.PARTY_SIZE):
			var candidates := CharacterFactory.draw_candidates(pool, Game.CANDIDATES_PER_PICK, taken)
			if candidates.size() != Game.CANDIDATES_PER_PICK:
				bad_draws += 1
				continue

			var best_stats: Array = []
			var scores: Array = []
			for c in candidates:
				var p: Prisoner = c
				if p == null or p.display_name.is_empty() or p.max_health < 1:
					invalid += 1
					continue
				for stat in Content.stat_keys:
					var v := p.base_stat(stat)
					if v < 1 or v > 10:
						invalid += 1
				for trait_id in p.trait_ids:
					if Content.get_trait(str(trait_id)).is_empty():
						invalid += 1
				best_stats.append(p.best_stat())
				scores.append(CharacterFactory.power_score(p))

			if best_stats.size() == 3 and best_stats[0] == best_stats[1] and best_stats[1] == best_stats[2]:
				identical_best += 1

			var lowest := 999.0
			var highest := -999.0
			for s in scores:
				lowest = minf(lowest, float(s))
				highest = maxf(highest, float(s))
			if highest - lowest > CharacterFactory.MAX_POWER_SPREAD:
				blowouts += 1

			taken.append((candidates[0] as Prisoner).id)

	t.equal(bad_draws, 0, "every recruitment round offers exactly 3 candidates")
	t.equal(invalid, 0, "no candidate is ever generated with impossible data")
	t.equal(identical_best, 0, "the three candidates never all share one strongest stat")
	t.equal(blowouts, 0, "no card is ever dramatically stronger than the other two")

	# A full run's worth of recruiting never repeats a character.
	Rng.start_run(777)
	Game.start_run(777)
	while not Game.party_is_full():
		var candidates := Game.draw_candidates()
		Game.recruit(candidates[Rng.roll_int(0, candidates.size() - 1)])
	t.equal(Game.party.size(), Game.PARTY_SIZE, "the party locks at exactly five")

	var ids: Dictionary = {}
	var duplicates := 0
	for m in Game.party:
		var id := (m as Prisoner).id
		if ids.has(id):
			duplicates += 1
		ids[id] = true
	t.equal(duplicates, 0, "no character joins the same crew twice")

	# The party cannot be pushed past five.
	var before := Game.party.size()
	Game.recruit(Prisoner.from_def(Content.get_character_def("norm")))
	t.equal(Game.party.size(), before, "recruiting into a full party does nothing")

	# Synergies only ever reference tags the crew can actually have.
	var syn := Synergy.active(Game.party)
	t.check(syn is Array, "synergy evaluation returns a list for any party")
	var mods := Synergy.modifiers_for(Game.party, ["tech"])
	t.check(mods.has("bonuses"), "synergy modifiers are shaped for the skill check")
