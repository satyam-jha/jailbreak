class_name SkillCheck
extends RefCounted
## The single skill-check function the whole game routes through.
##
##     chance = BASE + (stat - 5) * PER_POINT
##              - difficulty * PER_DIFFICULTY
##              + trait modifiers + synergy + power-ups + Heat + luck
##
## clamped to MIN_CHANCE..MAX_CHANCE, then a d100 is rolled against it. The top slice of the
## success band is a critical success and the bottom slice of the failure band
## is a critical failure, so a strong character still cannot be certain.
##
## Tuning lives entirely in the constants below. These values were fitted with
## tools/balance_sim.py: a perfect-information optimiser wins about 73% of runs
## and random play about 17%, which leaves a real player somewhere in between.

const BASE_CHANCE := 34
const PER_POINT := 8
const PER_DIFFICULTY := 8
const MIN_CHANCE := 5
## Capped below 100 on purpose: a maxed-out character is reliable, never certain.
const MAX_CHANCE := 85

## What fraction of each band becomes a critical result, before modifiers.
const CRIT_SUCCESS_FRACTION := 0.15
const CRIT_FAILURE_FRACTION := 0.15

## Luck nudges every check slightly, on top of being a stat in its own right.
const LUCK_WEIGHT := 1.5


## `situation` is built by GameState.build_situation() and carries:
##   bonuses            Array of { label, value } already aggregated
##   crit_success_bonus int
##   crit_fail_bonus    int
##   save_chance        float
##   heat               int
## Works out the odds without rolling. The encounter screen calls this to show
## the player what a choice is actually worth before they commit to it.
static func prepare(actor: Prisoner, stat_name: String, contexts: Array, difficulty: int, situation: Dictionary) -> CheckResult:
	var res := CheckResult.new()
	res.actor_name = actor.display_name
	res.stat_name = stat_name
	res.stat_value = actor.effective_stat(stat_name)

	var chance := float(BASE_CHANCE)
	res.add_modifier("Base chance", BASE_CHANCE)

	var stat_part := (res.stat_value - 5) * PER_POINT
	chance += stat_part
	res.add_modifier("%s %d" % [stat_name.capitalize(), res.stat_value], stat_part)

	if difficulty != 0:
		var diff_part := -difficulty * PER_DIFFICULTY
		chance += diff_part
		res.add_modifier("Task difficulty", diff_part)

	# Luck always has a quiet say, even on a Strength check.
	if stat_name != "luck":
		var luck_part := int(round((actor.effective_stat("luck") - 5) * LUCK_WEIGHT))
		chance += luck_part
		res.add_modifier("Luck", luck_part)

	var crit_success_bonus := int(situation.get("crit_success_bonus", 0))
	var crit_fail_bonus := int(situation.get("crit_fail_bonus", 0))
	var save_chance := float(situation.get("save_chance", 0.0))

	# Traits belonging to this specific character.
	var trait_mods := collect_trait_modifiers(actor, contexts, int(situation.get("heat", 0)))
	for m in trait_mods.get("bonuses", []):
		chance += int(m["value"])
		res.add_modifier(m["label"], int(m["value"]))
	crit_success_bonus += int(trait_mods.get("crit_success_bonus", 0))
	crit_fail_bonus += int(trait_mods.get("crit_fail_bonus", 0))
	save_chance += float(trait_mods.get("save_chance", 0.0))

	# Everything that is true of the whole run: synergies, power-ups, Heat.
	for m in situation.get("bonuses", []):
		chance += int(m["value"])
		res.add_modifier(str(m["label"]), int(m["value"]))

	res.final_chance = clampi(int(round(chance)), MIN_CHANCE, MAX_CHANCE)

	# Critical bands, carved out of each side of the roll.
	res.crit_success_at = clampi(
		int(round(res.final_chance * CRIT_SUCCESS_FRACTION)) + crit_success_bonus,
		0, res.final_chance)
	var fail_band := 100 - res.final_chance
	res.crit_failure_at = clampi(
		100 - int(round(fail_band * CRIT_FAILURE_FRACTION)) - crit_fail_bonus + 1,
		res.final_chance + 1, 101)

	res.save_chance = save_chance
	res.save_source = str(trait_mods.get("save_source", situation.get("save_source", "sheer luck")))
	return res


## Prepares the check and then actually rolls it.
static func resolve(actor: Prisoner, stat_name: String, contexts: Array, difficulty: int, situation: Dictionary) -> CheckResult:
	var res := prepare(actor, stat_name, contexts, difficulty, situation)
	res.roll = Rng.roll_int(1, 100)

	if res.roll <= res.crit_success_at:
		res.tier = CheckResult.Tier.CRIT_SUCCESS
	elif res.roll <= res.final_chance:
		res.tier = CheckResult.Tier.SUCCESS
	elif res.roll >= res.crit_failure_at:
		res.tier = CheckResult.Tier.CRIT_FAILURE
	else:
		res.tier = CheckResult.Tier.FAILURE

	# A plain failure can still be rescued by Lucky Idiot, One Do-Over, and friends.
	if res.tier == CheckResult.Tier.FAILURE and res.save_chance > 0.0 and Rng.chance(res.save_chance):
		res.tier = CheckResult.Tier.SUCCESS
		res.was_saved = true
		res.saved_by = res.save_source

	actor.checks_attempted += 1
	if res.is_success():
		actor.checks_passed += 1

	return res


## Walks one character's traits and folds every effect that applies in this
## context into a single bundle. Contexts come from the encounter choice's tags.
static func collect_trait_modifiers(actor: Prisoner, contexts: Array, heat: int) -> Dictionary:
	var out := {
		"bonuses": [],
		"crit_success_bonus": 0,
		"crit_fail_bonus": 0,
		"save_chance": 0.0,
		"save_source": "",
	}
	for trait_id in actor.trait_ids:
		var t: Dictionary = Content.get_trait(trait_id)
		if t.is_empty():
			continue
		var t_name: String = t.get("name", trait_id)
		for e in t.get("effects", []):
			if not effect_applies(e, contexts, heat):
				continue
			match str(e.get("type", "")):
				"stat_bonus":
					# Converted into check percentage using the same scale as the stat itself.
					var v := int(e.get("value", 0)) * PER_POINT
					out["bonuses"].append({"label": t_name, "value": v})
				"check_bonus":
					out["bonuses"].append({"label": t_name, "value": int(e.get("value", 0))})
				"crit_success_chance":
					out["crit_success_bonus"] = int(out["crit_success_bonus"]) + int(e.get("value", 0))
				"crit_fail_chance":
					out["crit_fail_bonus"] = int(out["crit_fail_bonus"]) + int(e.get("value", 0))
				"save_chance":
					out["save_chance"] = float(out["save_chance"]) + float(e.get("value", 0))
					out["save_source"] = t_name
	return out


## An effect applies when its context list is empty (always) or intersects the
## choice's tags, and when the current Heat is inside any min/max it declares.
static func effect_applies(effect: Dictionary, contexts: Array, heat: int) -> bool:
	if effect.has("min_heat") and heat < int(effect["min_heat"]):
		return false
	if effect.has("max_heat") and heat > int(effect["max_heat"]):
		return false
	var required: Array = effect.get("contexts", [])
	if required.is_empty():
		return true
	for c in required:
		if contexts.has(c):
			return true
	return false
