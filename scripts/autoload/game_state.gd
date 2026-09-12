extends Node
## Autoload: Game
##
## Everything that is true about the current run. Screens read from here and
## call into here; they never talk to each other. The whole object round-trips
## through to_dict()/from_dict() so a run can be saved mid-escape.

signal heat_changed(new_heat: int, delta: int)
signal money_changed(new_money: int, delta: int)
signal party_changed()
signal notable_added(line: String)
signal run_finished(result: String)

enum Phase { MENU, RECRUIT, MAP, ENCOUNTER, POWERUP, ESCAPE, SUMMARY }

const PARTY_SIZE := 5
const CANDIDATES_PER_PICK := 3
const STARTING_MONEY := 60
const STARTING_HEAT := 10
const MAX_HEAT := 100

## How much harder a loud prison makes everything, at Heat 100.
const HEAT_PRESSURE_AT_MAX := 15

## The clock. Every room raises Heat a little regardless of how it goes, and
## more so the deeper into the prison you are - this is what stops a careful
## crew from simply taking forever. Together with EffectResolver's relief scale
## it is the main dial for how long a run stays survivable.
const HEAT_DRIFT_BASE := 3.0
const HEAT_DRIFT_PER_LAYER := 0.8

var phase: int = Phase.MENU
var seed_value: int = 0

var party: Array = []
var candidate_pool: Array = []
var current_candidates: Array = []

var heat: int = STARTING_HEAT
var money: int = STARTING_MONEY
var day: int = 1

var map: Dictionary = {}
var current_node_id: String = ""
var pending_node_id: String = ""

var powerups: Array = []              ## taken offers (see PowerupSystem)
var used_event_ids: Array = []
var current_event: Dictionary = {}

var rooms_cleared: int = 0
var guards_fooled: int = 0
var last_room_succeeded: bool = true
var checks_made: int = 0
var criticals: int = 0
var disasters: int = 0

var notable: Array = []
var run_log: Array = []

var result: String = ""               ## escaped | caught | disaster
var result_headline: String = ""
var result_detail: String = ""
var escape_route_id: String = ""

var debug_enabled: bool = true


## --- Run lifecycle -------------------------------------------------------

func start_run(explicit_seed: int = -1) -> void:
	seed_value = Rng.start_run(explicit_seed)
	phase = Phase.RECRUIT
	party.clear()
	candidate_pool = CharacterFactory.build_pool()
	current_candidates.clear()
	heat = STARTING_HEAT
	money = STARTING_MONEY
	day = 1
	map = {}
	current_node_id = ""
	pending_node_id = ""
	powerups.clear()
	used_event_ids.clear()
	current_event = {}
	rooms_cleared = 0
	guards_fooled = 0
	last_room_succeeded = true
	checks_made = 0
	criticals = 0
	disasters = 0
	notable.clear()
	run_log.clear()
	result = ""
	result_headline = ""
	result_detail = ""
	escape_route_id = ""
	heat_changed.emit(heat, 0)
	money_changed.emit(money, 0)
	party_changed.emit()


func draw_candidates() -> Array:
	var taken_ids: Array = []
	for m in party:
		taken_ids.append((m as Prisoner).id)
	current_candidates = CharacterFactory.draw_candidates(candidate_pool, CANDIDATES_PER_PICK, taken_ids)
	return current_candidates


func recruit(p: Prisoner) -> void:
	if p == null or party.size() >= PARTY_SIZE:
		return
	party.append(p)
	current_candidates.clear()
	party_changed.emit()


func party_is_full() -> bool:
	return party.size() >= PARTY_SIZE


func lock_party_and_generate_prison() -> void:
	map = PrisonGenerator.generate(party)
	current_node_id = str(map.get("start", ""))
	phase = Phase.MAP
	log_line("The crew is locked in. Seed %d." % seed_value)


## --- Resources -----------------------------------------------------------

func add_heat(delta: int) -> void:
	if delta == 0:
		return
	var before := heat
	heat = clampi(heat + delta, 0, MAX_HEAT)
	if heat != before:
		heat_changed.emit(heat, heat - before)


func set_heat(value: int) -> void:
	add_heat(clampi(value, 0, MAX_HEAT) - heat)


func add_money(delta: int) -> void:
	if delta == 0:
		return
	var before := money
	money = maxi(0, money + delta)
	if money != before:
		money_changed.emit(money, money - before)


func heat_band() -> Dictionary:
	return Content.heat_band(heat)


func heat_band_name() -> String:
	return str(heat_band().get("name", ""))


func heat_color() -> Color:
	return Color(str(heat_band().get("color", "#888888")))


## Heat the crew generates is reduced by calming traits and power-ups, and
## increased by nothing - catches raise Heat directly instead.
func scale_generated_heat(amount: int, actor: Prisoner = null) -> int:
	if amount <= 0:
		return amount
	var multiplier := 1.0
	if actor != null:
		for trait_id in actor.trait_ids:
			for e in Content.get_trait(trait_id).get("effects", []):
				if str(e.get("type", "")) == "heat_multiplier":
					multiplier += float(e.get("value", 0.0))
	for offer in powerups:
		for e in _offer_effects(offer):
			if str(e.get("type", "")) == "heat_multiplier":
				multiplier += float(e.get("value", 0.0))
	multiplier = clampf(multiplier, 0.2, 2.0)
	return maxi(1, int(round(amount * multiplier)))


func global_damage_modifier() -> int:
	var total := 0
	for offer in powerups:
		for e in _offer_effects(offer):
			if str(e.get("type", "")) == "damage_taken":
				total += int(e.get("value", 0))
	return total


## --- Party helpers -------------------------------------------------------

func available_members() -> Array:
	var out: Array = []
	for m in party:
		if (m as Prisoner).is_available():
			out.append(m)
	return out


func random_available_member() -> Prisoner:
	var pool := available_members()
	if pool.is_empty():
		if party.is_empty():
			return null
		return party[0]
	return Rng.pick(pool)


func member_by_id(id: String) -> Prisoner:
	for m in party:
		if (m as Prisoner).id == id:
			return m
	return null


func everyone_is_down() -> bool:
	return available_members().is_empty()


func party_tag_counts() -> Dictionary:
	return Synergy.count_tags(party)


func active_synergies() -> Array:
	return Synergy.active(party)


## --- Standing modifiers --------------------------------------------------

## Effects from a taken power-up, plus the standing penalty of its catch once
## that catch has revealed itself. A cancelled power-up contributes nothing.
func _offer_effects(offer: Dictionary) -> Array:
	if bool(offer.get("cancelled", false)):
		return []
	var out: Array = (offer.get("def", {}) as Dictionary).get("effects", []).duplicate()
	if bool(offer.get("revealed", false)):
		out.append_array(PowerupSystem.catch_for(offer).get("effects", []))
	return out


func _offer_label(offer: Dictionary) -> String:
	return str((offer.get("def", {}) as Dictionary).get("name", "Power-up"))


## Builds the situation bundle handed to SkillCheck.resolve().
func build_situation(contexts: Array) -> Dictionary:
	var situation := {
		"heat": heat,
		"bonuses": [],
		"crit_success_bonus": 0,
		"crit_fail_bonus": 0,
		"save_chance": 0.0,
		"save_source": "",
	}

	# A prison on alert makes everything harder.
	var pressure := -int(round((float(heat) / float(MAX_HEAT)) * HEAT_PRESSURE_AT_MAX))
	if pressure != 0:
		situation["bonuses"].append({"label": "Prison %s" % heat_band_name(), "value": pressure})

	var syn := Synergy.modifiers_for(party, contexts)
	situation["bonuses"].append_array(syn["bonuses"])
	situation["crit_success_bonus"] = int(situation["crit_success_bonus"]) + int(syn["crit_success_bonus"])
	situation["crit_fail_bonus"] = int(situation["crit_fail_bonus"]) + int(syn["crit_fail_bonus"])

	for offer in powerups:
		var label := _offer_label(offer)
		for e in _offer_effects(offer):
			if not SkillCheck.effect_applies(e, contexts, heat):
				continue
			match str(e.get("type", "")):
				"check_bonus":
					situation["bonuses"].append({"label": label, "value": int(e.get("value", 0))})
				"crit_success_chance":
					situation["crit_success_bonus"] = int(situation["crit_success_bonus"]) + int(e.get("value", 0))
				"crit_fail_chance":
					situation["crit_fail_bonus"] = int(situation["crit_fail_bonus"]) + int(e.get("value", 0))
				"save_chance":
					situation["save_chance"] = float(situation["save_chance"]) + float(e.get("value", 0))
					situation["save_source"] = label

	return situation


## Extra percentage applied to every check during the final escape.
func escape_modifier() -> int:
	var total := 0
	for offer in powerups:
		for e in _offer_effects(offer):
			if str(e.get("type", "")) == "escape_bonus":
				total += int(e.get("value", 0))
	return total


## --- Map movement --------------------------------------------------------

func current_node() -> Dictionary:
	return PrisonGenerator.node_at(map, current_node_id)


func node(node_id: String) -> Dictionary:
	return PrisonGenerator.node_at(map, node_id)


func reachable_nodes() -> Array:
	var out: Array = []
	for child_id in current_node().get("connections", []):
		out.append(str(child_id))
	return out


## Called when the player commits to moving into a room.
func enter_node(node_id: String) -> Array:
	var target := node(node_id)
	if target.is_empty():
		return []
	pending_node_id = node_id
	phase = Phase.ENCOUNTER

	var changes: Array = []
	day += 1
	last_room_succeeded = true

	for m in party:
		(m as Prisoner).tick_room()

	var drift := int(round(HEAT_DRIFT_BASE + int(target.get("layer", 0)) * HEAT_DRIFT_PER_LAYER))
	if drift > 0:
		add_heat(drift)
		changes.append({"label": "Heat", "delta": drift, "good": false,
			"text": "Another day in here  +%d Heat" % drift})

	var enter_heat := int(target.get("heat_on_enter", 0))
	if enter_heat != 0:
		add_heat(enter_heat)
		changes.append({"label": "Heat", "delta": enter_heat, "good": enter_heat < 0,
			"text": "Heat %s%d" % ["+" if enter_heat > 0 else "", enter_heat]})

	# Standing per-room effects from power-ups and revealed catches.
	for offer in powerups:
		offer["rooms_since_taken"] = int(offer.get("rooms_since_taken", 0)) + 1
		for e in _offer_effects(offer):
			match str(e.get("type", "")):
				"money_per_room":
					var cash := int(e.get("value", 0))
					add_money(cash)
					changes.append({"label": "Money", "delta": cash, "good": cash > 0,
						"text": "%s +$%d" % [_offer_label(offer), cash]})
				"heat_decay":
					var decay := -int(e.get("value", 0))
					add_heat(decay)
					changes.append({"label": "Heat", "delta": decay, "good": true,
						"text": "%s %d Heat" % [_offer_label(offer), decay]})
				"heat_per_room":
					var gain := int(e.get("value", 0))
					add_heat(gain)
					changes.append({"label": "Heat", "delta": gain, "good": false,
						"text": "Something you are carrying +%d Heat" % gain})

	current_event = EncounterEngine.pick_event(str(target.get("room_id", "")), heat, used_event_ids, party)
	if not current_event.is_empty():
		var eid := str(current_event.get("id", ""))
		if not used_event_ids.has(eid):
			used_event_ids.append(eid)

	return changes


## Catches that want to fire on entering a room. Returns firing reports.
func fire_catches(event_name: String) -> Array:
	var reports: Array = []
	for offer in powerups:
		if PowerupSystem.catch_should_fire(offer, event_name, heat):
			var catch_def := PowerupSystem.catch_for(offer)
			var changes := EffectResolver.apply_catch(catch_def, offer)
			reports.append({
				"powerup_name": _offer_label(offer),
				"reveal_text": str(catch_def.get("reveal_text", "")),
				"changes": changes,
			})
			add_notable("The catch on %s finally showed itself." % _offer_label(offer))
	return reports


## Marks the room finished and opens the doors it leads to.
func clear_current_room() -> void:
	var n := node(pending_node_id if not pending_node_id.is_empty() else current_node_id)
	if n.is_empty():
		return
	n["state"] = "cleared"
	current_node_id = str(n.get("id", current_node_id))
	pending_node_id = ""
	rooms_cleared += 1
	for child_id in n.get("connections", []):
		var child := node(str(child_id))
		if not child.is_empty() and str(child.get("state", "locked")) == "locked":
			child["state"] = "available"
	phase = Phase.MAP


func at_final_room() -> bool:
	return bool(current_node().get("is_final", false))


## --- Encounter resolution ------------------------------------------------

## Runs one encounter choice end to end and returns everything the result
## screen needs to explain what just happened.
func resolve_choice(choice: Dictionary, actor: Prisoner) -> Dictionary:
	var contexts: Array = choice.get("tags", [])
	var node_data := node(pending_node_id if not pending_node_id.is_empty() else current_node_id)
	var reward_mult := float(node_data.get("reward_mult", 1.0))
	var extra_difficulty := int(node_data.get("extra_difficulty", 0))

	var changes: Array = []

	var cost := int(choice.get("cost_money", 0))
	if cost > 0:
		add_money(-cost)
		changes.append({"label": "Money", "delta": -cost, "good": false, "text": "Money -%d" % cost})

	var report := {
		"auto": bool(choice.get("auto", false)),
		"actor": actor,
		"result": null,
		"outcome": {},
		"changes": changes,
		"catches": [],
		"quip": "",
	}

	var outcome: Dictionary = {}

	if bool(choice.get("auto", false)):
		outcome = choice.get("success", {})
	else:
		var difficulty := int(choice.get("difficulty", 0)) + extra_difficulty
		var situation := build_situation(contexts)
		var check := SkillCheck.resolve(actor, str(choice.get("stat", "luck")), contexts, difficulty, situation)
		report["result"] = check
		checks_made += 1
		if check.is_critical():
			criticals += 1
		if check.tier == CheckResult.Tier.CRIT_FAILURE:
			disasters += 1
		last_room_succeeded = check.is_success()
		if check.is_success():
			guards_fooled += 1
		outcome = choice.get(check.outcome_key(), choice.get("failure", {}))
		changes.append_array(EffectResolver.apply_trait_reactions(actor, check, contexts))
		report["quip"] = actor.quip("success" if check.is_success() else "failure")

	report["outcome"] = outcome
	changes.append_array(EffectResolver.apply_outcome(outcome, actor, reward_mult))

	var check_result: Variant = report["result"]
	if check_result != null and not (check_result as CheckResult).is_success():
		var trigger := "on_crit_fail" if (check_result as CheckResult).tier == CheckResult.Tier.CRIT_FAILURE else "on_fail"
		report["catches"] = fire_catches(trigger)

	log_line(str(outcome.get("text", "")))
	return report


## A room qualifies for a power-up if the crew is still standing AND the
## encounter actually went their way. Failing a room costs you the reward.
func room_awards_powerup() -> bool:
	return not everyone_is_down() and last_room_succeeded


func take_powerup(offer: Dictionary, target: Prisoner = null) -> Dictionary:
	var changes := EffectResolver.apply_powerup(offer, target)
	powerups.append(offer)
	var immediate := fire_catches("immediate")
	phase = Phase.MAP
	return {"changes": changes, "catches": immediate}


func owned_powerup_ids() -> Array:
	var out: Array = []
	for offer in powerups:
		out.append(str(offer.get("id", "")))
	return out


## --- Endings -------------------------------------------------------------

## Checked after every encounter. Returns "" while the run is still alive.
func check_run_over() -> String:
	if everyone_is_down():
		finish_run("disaster", "THE ENTIRE CREW IS ON THE FLOOR",
			"Nobody is standing. The escape is technically still on, in the sense that nobody has formally cancelled it.")
		return "disaster"
	if heat >= MAX_HEAT:
		var downed := party.size() - available_members().size()
		if downed >= 3:
			finish_run("disaster", "LOCKDOWN, AND MOST OF YOU ARE UNCONSCIOUS",
				"Heat hit 100 while %d of the crew were already horizontal. The guards found them first, which at least saved everyone the walk." % downed)
			return "disaster"
		finish_run("caught", "LOCKDOWN",
			"Heat hit 100. Every door in the building agreed on something at the same time, and none of them agreed with you.")
		return "caught"
	return ""


func finish_run(new_result: String, headline: String, detail: String) -> void:
	result = new_result
	result_headline = headline
	result_detail = detail
	phase = Phase.SUMMARY
	run_finished.emit(result)


func final_score() -> int:
	var score := rooms_cleared * 420
	score += guards_fooled * 130
	score += money * 3
	score += criticals * 260
	score += maxi(0, (100 - heat)) * 12
	for m in party:
		var p: Prisoner = m
		if p.is_available():
			score += 200
		score += p.health * 15
	if result == "escaped":
		score *= 2
	return score


func summary() -> Dictionary:
	return {
		"result": result,
		"headline": result_headline,
		"detail": result_detail,
		"seed": seed_value,
		"days": day,
		"rooms_cleared": rooms_cleared,
		"guards_fooled": guards_fooled,
		"checks_made": checks_made,
		"criticals": criticals,
		"disasters": disasters,
		"heat": heat,
		"money": money,
		"notable": notable.duplicate(),
		"score": final_score(),
		"route": escape_route_id,
	}


## --- Log -----------------------------------------------------------------

func log_line(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	run_log.append({"day": day, "text": text})


func add_notable(line: String) -> void:
	if line.strip_edges().is_empty():
		return
	notable.append(line)
	notable_added.emit(line)


## --- Save / load ---------------------------------------------------------

func to_dict() -> Dictionary:
	var members: Array = []
	for m in party:
		members.append((m as Prisoner).to_dict())
	var stored_powerups: Array = []
	for offer in powerups:
		stored_powerups.append({
			"id": offer.get("id", ""),
			"catch_id": offer.get("catch_id", ""),
			"has_catch": offer.get("has_catch", false),
			"revealed": offer.get("revealed", false),
			"rooms_since_taken": offer.get("rooms_since_taken", 0),
			"cancelled": offer.get("cancelled", false),
		})
	return {
		"version": SaveSystem.SAVE_VERSION,
		"seed": seed_value,
		"rng_state": Rng.get_state(),
		"phase": phase,
		"party": members,
		"heat": heat,
		"money": money,
		"day": day,
		"map": map,
		"current_node_id": current_node_id,
		"pending_node_id": pending_node_id,
		"powerups": stored_powerups,
		"used_event_ids": used_event_ids.duplicate(),
		"rooms_cleared": rooms_cleared,
		"guards_fooled": guards_fooled,
		"last_room_succeeded": last_room_succeeded,
		"checks_made": checks_made,
		"criticals": criticals,
		"disasters": disasters,
		"notable": notable.duplicate(),
		"run_log": run_log.duplicate(true),
		"result": result,
		"escape_route_id": escape_route_id,
	}


func from_dict(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	seed_value = int(d.get("seed", 0))
	Rng.start_run(seed_value)
	Rng.set_state(int(d.get("rng_state", seed_value)))

	party.clear()
	for entry in d.get("party", []):
		var p := Prisoner.from_dict(entry)
		if p != null:
			party.append(p)

	heat = clampi(int(d.get("heat", STARTING_HEAT)), 0, MAX_HEAT)
	money = maxi(0, int(d.get("money", STARTING_MONEY)))
	day = int(d.get("day", 1))
	map = d.get("map", {})
	current_node_id = str(d.get("current_node_id", ""))
	pending_node_id = str(d.get("pending_node_id", ""))
	phase = int(d.get("phase", Phase.MAP))

	powerups.clear()
	for entry in d.get("powerups", []):
		var pid := str(entry.get("id", ""))
		var pdef := Content.get_powerup(pid)
		if pdef.is_empty():
			continue
		powerups.append({
			"id": pid,
			"def": pdef,
			"catch_id": str(entry.get("catch_id", "")),
			"has_catch": bool(entry.get("has_catch", false)),
			"revealed": bool(entry.get("revealed", false)),
			"rooms_since_taken": int(entry.get("rooms_since_taken", 0)),
			"cancelled": bool(entry.get("cancelled", false)),
		})

	used_event_ids = d.get("used_event_ids", []).duplicate()
	rooms_cleared = int(d.get("rooms_cleared", 0))
	guards_fooled = int(d.get("guards_fooled", 0))
	last_room_succeeded = bool(d.get("last_room_succeeded", true))
	checks_made = int(d.get("checks_made", 0))
	criticals = int(d.get("criticals", 0))
	disasters = int(d.get("disasters", 0))
	notable = d.get("notable", []).duplicate()
	run_log = d.get("run_log", []).duplicate(true)
	result = str(d.get("result", ""))
	escape_route_id = str(d.get("escape_route_id", ""))

	heat_changed.emit(heat, 0)
	money_changed.emit(money, 0)
	party_changed.emit()
	return true
