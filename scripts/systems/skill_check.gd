class_name SkillCheck
extends RefCounted
## The single skill-check function the whole game routes through.
## Strategy 2.0 adds persistent suspicion, noise, patrol pressure and earned
## intelligence to the same situation bundle used by every check.

const BASE_CHANCE := 34
const PER_POINT := 8
const PER_DIFFICULTY := 8
const MIN_CHANCE := 5
const MAX_CHANCE := 85
const CRIT_SUCCESS_FRACTION := 0.15
const CRIT_FAILURE_FRACTION := 0.15
const LUCK_WEIGHT := 1.5

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
	if stat_name != "luck":
		var luck_part := int(round((actor.effective_stat("luck") - 5) * LUCK_WEIGHT))
		chance += luck_part
		res.add_modifier("Luck", luck_part)
	var crit_success_bonus := int(situation.get("crit_success_bonus", 0))
	var crit_fail_bonus := int(situation.get("crit_fail_bonus", 0))
	var save_chance := float(situation.get("save_chance", 0.0))
	var trait_mods := collect_trait_modifiers(actor, contexts, int(situation.get("heat", 0)))
	for m in trait_mods.get("bonuses", []):
		chance += int(m["value"])
		res.add_modifier(m["label"], int(m["value"]))
	crit_success_bonus += int(trait_mods.get("crit_success_bonus", 0))
	crit_fail_bonus += int(trait_mods.get("crit_fail_bonus", 0))
	save_chance += float(trait_mods.get("save_chance", 0.0))
	for m in situation.get("bonuses", []):
		chance += int(m["value"])
		res.add_modifier(str(m["label"]), int(m["value"]))
	# Append only the new Strategy bonuses, so existing GameState bonuses are not doubled.
	var bonus_count_before := (situation.get("bonuses", []) as Array).size()
	Strategy.modify_situation(situation, contexts)
	var bonuses: Array = situation.get("bonuses", [])
	for i in range(bonus_count_before, bonuses.size()):
		var m: Dictionary = bonuses[i]
		chance += int(m.get("value", 0))
		res.add_modifier(str(m.get("label", "Strategy")), int(m.get("value", 0)))
	res.final_chance = clampi(int(round(chance)), MIN_CHANCE, MAX_CHANCE)
	res.crit_success_at = clampi(int(round(res.final_chance * CRIT_SUCCESS_FRACTION)) + crit_success_bonus, 0, res.final_chance)
	var fail_band := 100 - res.final_chance
	res.crit_failure_at = clampi(100 - int(round(fail_band * CRIT_FAILURE_FRACTION)) - crit_fail_bonus + 1, res.final_chance + 1, 101)
	res.save_chance = save_chance
	res.save_source = str(trait_mods.get("save_source", situation.get("save_source", "sheer luck")))
	return res

static func resolve(actor: Prisoner, stat_name: String, contexts: Array, difficulty: int, situation: Dictionary) -> CheckResult:
	var res := prepare(actor, stat_name, contexts, difficulty, situation)
	res.roll = Rng.roll_int(1, 100)
	if res.roll <= res.crit_success_at: res.tier = CheckResult.Tier.CRIT_SUCCESS
	elif res.roll <= res.final_chance: res.tier = CheckResult.Tier.SUCCESS
	elif res.roll >= res.crit_failure_at: res.tier = CheckResult.Tier.CRIT_FAILURE
	else: res.tier = CheckResult.Tier.FAILURE
	if res.tier == CheckResult.Tier.FAILURE and res.save_chance > 0.0 and Rng.chance(res.save_chance):
		res.tier = CheckResult.Tier.SUCCESS
		res.was_saved = true
		res.saved_by = res.save_source
	actor.checks_attempted += 1
	if res.is_success(): actor.checks_passed += 1
	return res

static func collect_trait_modifiers(actor: Prisoner, contexts: Array, heat: int) -> Dictionary:
	var out := {"bonuses": [], "crit_success_bonus": 0, "crit_fail_bonus": 0, "save_chance": 0.0, "save_source": ""}
	for trait_id in actor.trait_ids:
		var t: Dictionary = Content.get_trait(trait_id)
		if t.is_empty(): continue
		var t_name: String = t.get("name", trait_id)
		for e in t.get("effects", []):
			if not effect_applies(e, contexts, heat): continue
			match str(e.get("type", "")):
				"stat_bonus": out["bonuses"].append({"label": t_name, "value": int(e.get("value", 0)) * PER_POINT})
				"check_bonus": out["bonuses"].append({"label": t_name, "value": int(e.get("value", 0))})
				"crit_success_chance": out["crit_success_bonus"] = int(out["crit_success_bonus"]) + int(e.get("value", 0))
				"crit_fail_chance": out["crit_fail_bonus"] = int(out["crit_fail_bonus"]) + int(e.get("value", 0))
				"save_chance":
					out["save_chance"] = float(out["save_chance"]) + float(e.get("value", 0))
					out["save_source"] = t_name
	return out

static func effect_applies(effect: Dictionary, contexts: Array, heat: int) -> bool:
	if effect.has("min_heat") and heat < int(effect["min_heat"]): return false
	if effect.has("max_heat") and heat > int(effect["max_heat"]): return false
	var required: Array = effect.get("contexts", [])
	if required.is_empty(): return true
	for c in required:
		if contexts.has(c): return true
	return false
