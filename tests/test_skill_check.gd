extends RefCounted
## The skill check: clamping, trait modifiers, critical bands and determinism.


static func _plain_situation() -> Dictionary:
	return {"heat": 0, "bonuses": [], "crit_success_bonus": 0, "crit_fail_bonus": 0, "save_chance": 0.0, "save_source": ""}


## A subject with no traits and every stat at 5, for testing the raw arithmetic.
## Using a real character here would quietly fold their traits into the result -
## Norm, for instance, carries Morning Person, worth a flat +12 at low Heat.
static func _blank_subject() -> Prisoner:
	var p := Prisoner.from_def(Content.get_character_def("norm"))
	p.trait_ids.clear()
	for stat in Content.stat_keys:
		p.base_stats[stat] = 5
	return p


static func run(t: TestRunner) -> void:
	t.suite("Skill checks")
	Rng.start_run(424242)

	var p := _blank_subject()

	var mid := SkillCheck.prepare(p, "strength", [], 0, _plain_situation())
	t.equal(mid.final_chance, SkillCheck.BASE_CHANCE, "a 5 in the stat with no modifiers is the base chance")

	p.base_stats["strength"] = 10
	var strong := SkillCheck.prepare(p, "strength", [], 0, _plain_situation())
	t.equal(strong.final_chance, SkillCheck.BASE_CHANCE + 5 * SkillCheck.PER_POINT, "each point above 5 is worth PER_POINT")

	# Clamping at both ends - a 10 is never certain, a 1 is never hopeless.
	p.base_stats["strength"] = 10
	p.base_stats["luck"] = 10
	var ceiling := SkillCheck.prepare(p, "strength", [], -5, _plain_situation())
	t.equal(ceiling.final_chance, SkillCheck.MAX_CHANCE, "success chance is clamped at MAX_CHANCE")
	t.check(ceiling.final_chance < 100, "a maxed-out character still cannot be certain")

	p.base_stats["strength"] = 1
	p.base_stats["luck"] = 1
	var floor_check := SkillCheck.prepare(p, "strength", [], 6, _plain_situation())
	t.equal(floor_check.final_chance, SkillCheck.MIN_CHANCE, "success chance is clamped at MIN_CHANCE")
	t.check(floor_check.final_chance > 0, "even a hopeless check has a chance")

	# Difficulty makes things harder, and negative difficulty makes them easier.
	p = _blank_subject()
	var easy := SkillCheck.prepare(p, "stealth", [], -1, _plain_situation())
	var hard := SkillCheck.prepare(p, "stealth", [], 1, _plain_situation())
	t.check(easy.final_chance > hard.final_chance, "higher difficulty lowers the chance")
	t.equal(easy.final_chance - hard.final_chance, 2 * SkillCheck.PER_DIFFICULTY, "difficulty is worth PER_DIFFICULTY each way")

	# Traits only apply in their declared context.
	var techie := Prisoner.from_def(Content.get_character_def("sockets"))
	var in_context := SkillCheck.prepare(techie, "intelligence", ["tech"], 0, _plain_situation())
	var out_of_context := SkillCheck.prepare(techie, "intelligence", ["physical"], 0, _plain_situation())
	t.check(in_context.final_chance > out_of_context.final_chance, "Keyboard Warrior only helps on technical work")
	var labels: Array = []
	for m in in_context.breakdown:
		labels.append(str(m["label"]))
	t.check(labels.has("Keyboard Warrior"), "the contributing trait is named in the breakdown")

	# Heat-gated trait effects. Difficulty 2 keeps both checks clear of the
	# MAX_CHANCE ceiling, where the comparison would be meaningless, and empty
	# contexts keep Twitch's Fast Hands out of it.
	var owl := Prisoner.from_def(Content.get_character_def("twitch"))
	var calm := _plain_situation()
	var panicked := _plain_situation()
	panicked["heat"] = 80
	var calm_check := SkillCheck.prepare(owl, "speed", [], 2, calm)
	var panicked_check := SkillCheck.prepare(owl, "speed", [], 2, panicked)
	t.check(calm_check.final_chance < SkillCheck.MAX_CHANCE, "the Night Owl comparison is below the chance ceiling")
	t.equal(panicked_check.final_chance - calm_check.final_chance, 15, "Night Owl only switches on at high Heat")

	# Situation modifiers are carried through and shown.
	var boosted := _plain_situation()
	boosted["bonuses"] = [{"label": "Test bonus", "value": 20}]
	var with_bonus := SkillCheck.prepare(p, "charisma", [], 0, boosted)
	var without_bonus := SkillCheck.prepare(p, "charisma", [], 0, _plain_situation())
	t.equal(with_bonus.final_chance - without_bonus.final_chance, 20, "situation bonuses are added directly")

	# Critical bands sit inside their own halves of the roll.
	t.check(with_bonus.crit_success_at <= with_bonus.final_chance, "the critical success band is inside the success band")
	t.check(with_bonus.crit_failure_at > with_bonus.final_chance, "the critical failure band is outside the success band")

	# Every tier is reachable, and the tier always agrees with the roll. The
	# subject must be trait-free: Slippery Customer narrows the critical failure
	# band to nothing, and Lucky Idiot converts plain failures into successes.
	Rng.start_run(99)
	var seen := {}
	var disagreements := 0
	for i in range(4000):
		var subject := _blank_subject()
		subject.base_stats["luck"] = 6
		var res := SkillCheck.resolve(subject, "luck", [], Rng.roll_int(-2, 2), _plain_situation())
		seen[res.tier] = true
		if not res.was_saved:
			var should_succeed := res.roll <= res.final_chance
			if should_succeed != res.is_success():
				disagreements += 1
	t.equal(disagreements, 0, "the verdict always matches the roll against the chance")
	t.equal(seen.size(), 4, "all four result tiers occur")

	# Same seed, same rolls.
	Rng.start_run(31337)
	var first: Array = []
	for i in range(25):
		first.append(SkillCheck.resolve(_blank_subject(), "luck", [], 0, _plain_situation()).roll)
	Rng.start_run(31337)
	var second: Array = []
	for i in range(25):
		second.append(SkillCheck.resolve(_blank_subject(), "luck", [], 0, _plain_situation()).roll)
	t.equal(first, second, "the same seed produces the same rolls")
