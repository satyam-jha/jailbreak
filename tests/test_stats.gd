extends RefCounted
## Stats, status effects and damage.


static func run(t: TestRunner) -> void:
	t.suite("Stats and status effects")

	var def := Content.get_character_def("big_dave")
	t.check(not def.is_empty(), "the sample character exists")
	var p := Prisoner.from_def(def)

	t.equal(p.effective_stat("strength"), p.base_stat("strength"), "a healthy character's effective stat is their base stat")

	p.add_stat_bonus("strength", 3)
	t.equal(p.effective_stat("strength"), mini(20, p.base_stat("strength") + 3), "power-up bonuses raise the effective stat")

	p.stat_bonuses["strength"] = 0
	p.set_status("injured")
	t.equal(p.effective_stat("strength"), maxi(1, p.base_stat("strength") - 2), "Injured applies -2 Strength")
	t.equal(p.status_delta("speed"), -1, "Injured also costs a point of Speed")

	p.set_status("angry")
	t.equal(p.status_delta("stealth"), -2, "Angry costs Stealth")
	t.equal(p.status_delta("strength"), 2, "Angry grants Strength")

	p.set_status("healthy")
	t.between(float(p.effective_stat("intelligence")), 1.0, 20.0, "effective stats stay inside 1-20")

	# Damage, unconsciousness and recovery.
	var q := Prisoner.from_def(Content.get_character_def("professor"))
	q.health = q.max_health
	var dealt := q.apply_damage(3)
	t.check(dealt >= 1, "damage is always at least 1 after reductions")
	t.equal(q.status, "injured", "taking damage makes a healthy character Injured")

	q.apply_damage(999)
	t.equal(q.health, 0, "health never goes below zero")
	t.equal(q.status, "unconscious", "zero health means unconscious")
	t.check(not q.is_available(), "unconscious characters cannot be sent on checks")

	t.check(q.revive(), "revive brings an unconscious character back")
	t.check(q.health > 0, "a revived character has health again")
	t.check(q.is_available(), "a revived character can act again")

	q.heal_by(999)
	t.equal(q.health, q.max_health, "healing is capped at max health")
	t.equal(q.status, "healthy", "a fully healed character is healthy again")

	# Temporary statuses decay on their own.
	q.set_status("scared")
	var duration := q.status_rooms_left
	t.check(duration > 0, "Scared is a temporary status")
	for i in range(duration):
		q.tick_room()
	t.equal(q.status, "healthy", "temporary statuses wear off after their duration")

	# Tags fold in trait tags, which is what synergies match on.
	var tagged := Prisoner.from_def(Content.get_character_def("sockets"))
	t.check(tagged.all_tags().has("tech"), "a character's tags include the tags of their traits")
