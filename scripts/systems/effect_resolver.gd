class_name EffectResolver
extends RefCounted
## The one place where data turns into state changes.
##
## Encounter outcomes, power-up effects, trait reactions and hidden catches all
## describe themselves as small dictionaries; this reads them and applies them
## to the run. Every function returns a list of human-readable change lines so
## the UI can show the player exactly what moved and by how much.
##
## A change line is { "label": String, "delta": int, "good": bool, "text": String }.

## Talking a prison down is harder than winding it up: Heat reductions written
## in the content are applied at this fraction of their face value, while Heat
## increases land in full. Without it a competent crew simply drives Heat to
## zero and the run loses all its tension. Raise it to make runs gentler.
const HEAT_RELIEF_SCALE := 0.5


static func _line(label: String, delta: int, good: bool) -> Dictionary:
	var sign_text := "+" if delta > 0 else ""
	return {
		"label": label,
		"delta": delta,
		"good": good,
		"text": "%s %s%d" % [label, sign_text, delta],
	}


static func _note(text: String) -> Dictionary:
	return {"label": "", "delta": 0, "good": true, "text": text}


## --- Encounter outcomes --------------------------------------------------

## Applies one outcome block from events.json. `reward_mult` comes from the map
## node, so risky and secret rooms genuinely pay better.
static func apply_outcome(outcome: Dictionary, actor: Prisoner, reward_mult: float = 1.0) -> Array:
	var changes: Array = []

	if outcome.has("heat"):
		var heat_delta := int(outcome["heat"])
		if heat_delta > 0:
			heat_delta = Game.scale_generated_heat(heat_delta, actor)
		elif heat_delta < 0:
			heat_delta = -maxi(1, int(round(-heat_delta * HEAT_RELIEF_SCALE)))
		if heat_delta != 0:
			Game.add_heat(heat_delta)
			changes.append(_line("Heat", heat_delta, heat_delta < 0))

	if outcome.has("money"):
		var money_delta := int(outcome["money"])
		if money_delta > 0:
			money_delta = int(round(money_delta * reward_mult))
		if money_delta != 0:
			Game.add_money(money_delta)
			changes.append(_line("Money", money_delta, money_delta > 0))

	if outcome.has("damage") and actor != null:
		var dealt := actor.apply_damage(int(outcome["damage"]))
		if dealt > 0:
			changes.append(_line("%s health" % actor.display_name, -dealt, false))

	if outcome.has("heal"):
		var healed_total := 0
		for member in Game.party:
			healed_total += (member as Prisoner).heal_by(int(outcome["heal"]))
		if healed_total > 0:
			changes.append(_line("Crew health", healed_total, true))

	if outcome.has("status") and actor != null:
		var status_id := str(outcome["status"])
		actor.set_status(status_id)
		changes.append(_note("%s is now %s." % [actor.display_name, actor.status_name()]))

	if outcome.has("note"):
		Game.add_notable("%s %s" % [actor.display_name if actor != null else "The crew", str(outcome["note"])])

	return changes


## --- Trait reactions -----------------------------------------------------

## Traits that fire *after* a check resolves: extra cash, extra Heat, and the
## permanent stat growth from things like Gym Bro.
static func apply_trait_reactions(actor: Prisoner, result: CheckResult, contexts: Array) -> Array:
	var changes: Array = []
	if actor == null:
		return changes
	var succeeded := result.is_success()

	for trait_id in actor.trait_ids:
		var t: Dictionary = Content.get_trait(trait_id)
		if t.is_empty():
			continue
		var t_name := str(t.get("name", trait_id))
		for e in t.get("effects", []):
			if not SkillCheck.effect_applies(e, contexts, Game.heat):
				continue
			var roll_ok: bool = not e.has("chance") or Rng.chance(float(e["chance"]))
			match str(e.get("type", "")):
				"money_on_success":
					if succeeded and roll_ok:
						var gain := int(e.get("value", 0))
						Game.add_money(gain)
						changes.append(_line("%s: money" % t_name, gain, gain > 0))
				"money_on_fail":
					if not succeeded and roll_ok:
						var loss := int(e.get("value", 0))
						Game.add_money(loss)
						changes.append(_line("%s: money" % t_name, loss, loss > 0))
				"heat_on_success":
					if succeeded:
						var hs := Game.scale_generated_heat(int(e.get("value", 0)), actor)
						Game.add_heat(hs)
						changes.append(_line("%s: Heat" % t_name, hs, hs < 0))
				"heat_on_fail":
					if not succeeded:
						var hf := Game.scale_generated_heat(int(e.get("value", 0)), actor)
						Game.add_heat(hf)
						changes.append(_line("%s: Heat" % t_name, hf, hf < 0))
				"grow_stat":
					var wanted := str(e.get("on", "success"))
					var matched := (wanted == "success" and succeeded) or (wanted == "failure" and not succeeded)
					if matched and roll_ok:
						var stat := str(e.get("stat", "strength"))
						var amount := int(e.get("value", 1))
						actor.add_stat_bonus(stat, amount)
						changes.append(_line("%s: %s" % [t_name, stat.capitalize()], amount, amount > 0))
	return changes


## --- Power-ups -----------------------------------------------------------

## Applies a taken power-up. Run-level effects are registered with GameState and
## consulted on every future check; one-off effects land immediately.
static func apply_powerup(offer: Dictionary, target: Prisoner = null) -> Array:
	var changes: Array = []
	var def: Dictionary = offer.get("def", {})
	var scope := str(def.get("target", "party"))

	for e in def.get("effects", []):
		match str(e.get("type", "")):
			"stat_bonus":
				var stat := str(e.get("stat", "strength"))
				var amount := int(e.get("value", 0))
				if scope == "one" and target != null:
					target.add_stat_bonus(stat, amount)
					changes.append(_line("%s: %s" % [target.display_name, stat.capitalize()], amount, amount > 0))
				else:
					for m in Game.party:
						(m as Prisoner).add_stat_bonus(stat, amount)
					changes.append(_line("Crew %s" % stat.capitalize(), amount, amount > 0))
			"max_health":
				var hp := int(e.get("value", 0))
				for m in Game.party:
					var p: Prisoner = m
					p.max_health = maxi(1, p.max_health + hp)
					p.health = mini(p.max_health, p.health + maxi(0, hp))
				changes.append(_line("Crew max health", hp, hp > 0))
			"heal":
				var healed := 0
				for m in Game.party:
					healed += (m as Prisoner).heal_by(int(e.get("value", 0)))
				if healed > 0:
					changes.append(_line("Crew health", healed, true))
			"revive":
				for m in Game.party:
					var p2: Prisoner = m
					if p2.revive():
						changes.append(_note("%s is back on their feet." % p2.display_name))
			"money":
				var cash := int(e.get("value", 0))
				Game.add_money(cash)
				changes.append(_line("Money", cash, cash > 0))
			"heat":
				var h := int(e.get("value", 0))
				Game.add_heat(h)
				changes.append(_line("Heat", h, h < 0))
			"damage":
				var dmg := int(e.get("value", 0))
				for m in Game.party:
					(m as Prisoner).apply_damage(dmg)
				changes.append(_line("Crew health", -dmg, false))
			"status":
				var sid := str(e.get("value", "scared"))
				for m in Game.party:
					(m as Prisoner).set_status(sid)
				changes.append(_note("The whole crew is %s." % Content.get_status(sid).get("name", sid)))
			_:
				# Everything else is a standing modifier consulted during checks.
				pass
	return changes


## --- Catches -------------------------------------------------------------

## Fires a hidden catch: reveals it and applies the damage, financial or
## otherwise. Returns the change lines; the reveal text is on the catch itself.
static func apply_catch(catch_def: Dictionary, offer: Dictionary) -> Array:
	var changes: Array = []
	for e in catch_def.get("effects", []):
		match str(e.get("type", "")):
			"money":
				var cash := int(e.get("value", 0))
				Game.add_money(cash)
				changes.append(_line("Money", cash, cash > 0))
			"heat":
				var h := int(e.get("value", 0))
				Game.add_heat(h)
				changes.append(_line("Heat", h, h < 0))
			"damage":
				var dmg := int(e.get("value", 0))
				var victim := Game.random_available_member()
				if victim != null:
					var dealt := victim.apply_damage(dmg)
					changes.append(_line("%s health" % victim.display_name, -dealt, false))
			"status":
				var sid := str(e.get("value", "scared"))
				var v2 := Game.random_available_member()
				if v2 != null:
					v2.set_status(sid)
					changes.append(_note("%s is now %s." % [v2.display_name, v2.status_name()]))
			"stat_bonus":
				var stat := str(e.get("stat", "speed"))
				var amount := int(e.get("value", 0))
				for m in Game.party:
					(m as Prisoner).add_stat_bonus(stat, amount)
				changes.append(_line("Crew %s" % stat.capitalize(), amount, amount > 0))
			"cancel_powerup":
				offer["cancelled"] = true
				changes.append(_note("%s no longer works." % str((offer.get("def", {}) as Dictionary).get("name", "It"))))
			_:
				# check_bonus / escape_bonus / heat_per_room are standing penalties
				# read back by GameState while the run continues.
				pass
	offer["revealed"] = true
	return changes
