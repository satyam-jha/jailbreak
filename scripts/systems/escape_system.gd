class_name EscapeSystem
extends RefCounted
## The final escape: pick a route, then run its three checks in sequence.
##
## Failing a step hurts and raises Heat but does not end the run on the spot -
## you need `required_passes` of the three. That way the climax is a story with
## a middle, rather than a single coin flip.

const FAIL_DAMAGE := 2
const FAIL_HEAT := 12


static func routes() -> Array:
	return Content.escape_routes


## How well the current crew suits a route, as a 0-100 readout for the UI.
## Purely advisory - it never changes the maths.
static func route_fit(route: Dictionary, party: Array) -> int:
	var best_stats: Array = route.get("best_stats", [])
	if best_stats.is_empty() or party.is_empty():
		return 50
	var total := 0.0
	for stat in best_stats:
		var best := 0
		for m in party:
			var p: Prisoner = m
			if p.is_available():
				best = maxi(best, p.effective_stat(str(stat)))
		total += best
	var average := total / float(best_stats.size())
	return clampi(int(round((average / 10.0) * 100.0)), 0, 100)


static func step(route: Dictionary, index: int) -> Dictionary:
	var steps: Array = route.get("steps", [])
	if index < 0 or index >= steps.size():
		return {}
	return steps[index]


static func step_count(route: Dictionary) -> int:
	return (route.get("steps", []) as Array).size()


## Builds the situation for one escape step: the usual run modifiers, plus the
## route's own exposure to Heat and any escape-specific power-up bonuses.
static func build_situation(route: Dictionary, index: int) -> Dictionary:
	var step_def := step(route, index)
	var contexts: Array = step_def.get("tags", [])
	var situation := Game.build_situation(contexts)

	var scaling := float(route.get("heat_scaling", 0.0))
	if not is_zero_approx(scaling):
		var exposure := -int(round(Game.heat * scaling))
		if exposure != 0:
			var label := "%s exposure" % str(route.get("name", "Route"))
			if exposure > 0:
				label = "%s thrives on chaos" % str(route.get("name", "Route"))
			situation["bonuses"].append({"label": label, "value": exposure})

	var escape_bonus := Game.escape_modifier()
	if escape_bonus != 0:
		situation["bonuses"].append({"label": "Escape preparation", "value": escape_bonus})

	return situation


static func resolve_step(route: Dictionary, index: int, actor: Prisoner) -> CheckResult:
	var step_def := step(route, index)
	if step_def.is_empty() or actor == null:
		return null
	var situation := build_situation(route, index)
	return SkillCheck.resolve(
		actor,
		str(step_def.get("stat", "luck")),
		step_def.get("tags", []),
		int(step_def.get("difficulty", 0)),
		situation)


## Applies the consequences of one resolved step and returns change lines.
static func apply_step_outcome(route: Dictionary, index: int, actor: Prisoner, check: CheckResult) -> Array:
	var step_def := step(route, index)
	var changes: Array = []
	Game.checks_made += 1
	if check.is_critical():
		Game.criticals += 1

	if check.is_success():
		Game.guards_fooled += 1
		var relief := -6 if check.tier == CheckResult.Tier.CRIT_SUCCESS else -2
		Game.add_heat(relief)
		changes.append({"label": "Heat", "delta": relief, "good": true, "text": "Heat %d" % relief})
		Game.add_notable("%s handled '%s' on the way out." % [actor.display_name, str(step_def.get("title", "the escape"))])
	else:
		var extra := 1 if check.tier == CheckResult.Tier.CRIT_FAILURE else 0
		var dealt := actor.apply_damage(FAIL_DAMAGE + extra)
		var heat_gain := Game.scale_generated_heat(FAIL_HEAT + extra * 8, actor)
		Game.add_heat(heat_gain)
		changes.append({"label": "%s health" % actor.display_name, "delta": -dealt, "good": false,
			"text": "%s health -%d" % [actor.display_name, dealt]})
		changes.append({"label": "Heat", "delta": heat_gain, "good": false, "text": "Heat +%d" % heat_gain})
		if check.tier == CheckResult.Tier.CRIT_FAILURE:
			Game.disasters += 1
			Game.add_notable("%s comprehensively ruined '%s'." % [actor.display_name, str(step_def.get("title", "a step"))])

	return changes


## Did the crew make it? `results` is the list of CheckResults, in order.
static func evaluate(route: Dictionary, results: Array) -> Dictionary:
	var passes := 0
	for r in results:
		if r is CheckResult and (r as CheckResult).is_success():
			passes += 1
	var needed := int(route.get("required_passes", 2))
	var escaped := passes >= needed and not Game.everyone_is_down()

	var headline := "ESCAPED" if escaped else "CAUGHT"
	var detail := str(route.get("victory", "")) if escaped else str(route.get("defeat", ""))

	# A run that falls apart completely gets its own, funnier ending.
	if not escaped and Game.everyone_is_down():
		headline = "A TOTAL AND COMPREHENSIVE DISASTER"
		detail = "The crew reached the wall. The crew did not leave the wall. The crew is, at time of writing, still at the wall, horizontally."
	elif not escaped and passes == 0:
		headline = "CAUGHT, IMMEDIATELY"
		detail = "%s Not one part of it worked. Not one." % detail

	var outcome := "escaped"
	if not escaped:
		outcome = "disaster" if (Game.everyone_is_down() or passes == 0) else "caught"

	return {
		"escaped": escaped,
		"result": outcome,
		"passes": passes,
		"needed": needed,
		"headline": headline,
		"detail": detail,
	}
