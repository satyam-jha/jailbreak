class_name CharacterFactory
extends RefCounted
## Turns the flat cast in characters.json into the three candidates offered at
## each recruitment step.
##
## Three rules keep the choice interesting (design spec section 11):
##   1. no character is offered twice in a run,
##   2. candidates are pushed to have different strongest stats, so the three
##      cards represent genuinely different plans,
##   3. stats are jittered by a net-zero amount, so the same character is not
##      identical every run, and nobody gets quietly buffed.

const JITTER_CHANCE := 70.0
const EXTRA_TRAIT_CHANCE := 22.0
const MAX_POWER_SPREAD := 11.0
const MAX_REDRAWS := 12
## How many of the closest-in-power candidates to choose randomly between.
const CLOSEST_WINDOW := 4


static func build_pool() -> Array:
	return Rng.shuffled(Content.character_defs)


## Draws `count` candidates from `pool`, removing what it takes.
##
## The first card is drawn freely; the rest are drawn from those that both bring
## a different strongest stat AND sit near the first card in overall power. That
## is what keeps the three cards a genuine choice rather than one obvious pick
## plus two also-rans.
static func draw_candidates(pool: Array, count: int, exclude_ids: Array = []) -> Array:
	var candidates: Array = []
	var used_best_stats: Array = []
	var target_power := 0.0

	while candidates.size() < count and not pool.is_empty():
		var index := _find_next_index(pool, exclude_ids, used_best_stats,
			target_power if not candidates.is_empty() else -1.0)
		if index < 0:
			break
		var def: Dictionary = pool[index]
		pool.remove_at(index)
		var candidate := make_candidate(def)
		if candidates.is_empty():
			target_power = power_score(candidate)
		used_best_stats.append(candidate.best_stat())
		candidates.append(candidate)

	# Last resort: if the spread is still too wide, re-roll the strongest card's
	# wildcard trait, which is the only part of generation that moves the score.
	var redraws := 0
	while candidates.size() > 1 and _power_spread(candidates) > MAX_POWER_SPREAD and redraws < MAX_REDRAWS:
		redraws += 1
		var strongest := _strongest_index(candidates)
		var rebuilt := Prisoner.from_def(Content.get_character_def(candidates[strongest].id))
		_apply_net_zero_jitter(rebuilt)
		candidates[strongest] = rebuilt

	return candidates


## Finds the next character to offer. `target_power` of -1 means "anything";
## otherwise entries are ranked by how close they are to that score, and one is
## chosen from the closest few so the pick stays varied between runs.
static func _find_next_index(pool: Array, exclude_ids: Array, used_best_stats: Array, target_power: float) -> int:
	var preferred: Array = []
	var fallback: Array = []
	for i in range(pool.size()):
		var def: Dictionary = pool[i]
		if exclude_ids.has(def.get("id", "")):
			continue
		fallback.append(i)
		if not used_best_stats.has(_def_best_stat(def)):
			preferred.append(i)

	var usable: Array = preferred if not preferred.is_empty() else fallback
	if usable.is_empty():
		return -1
	if target_power < 0.0:
		return int(usable[0])

	usable.sort_custom(func(a: int, b: int) -> bool:
		return absf(def_power_score(pool[a]) - target_power) < absf(def_power_score(pool[b]) - target_power))
	var window: int = mini(usable.size(), CLOSEST_WINDOW)
	return int(usable[Rng.roll_int(0, window - 1)])


## Power score straight from a definition, before a Prisoner is built from it.
## Mirrors power_score() so the two can be compared.
static func def_power_score(def: Dictionary) -> float:
	var total := 0.0
	var stats: Dictionary = def.get("stats", {})
	for s in Content.stat_keys:
		total += int(stats.get(s, 5))
	total += int(def.get("max_health", 10)) * 0.7
	for trait_id in def.get("traits", []):
		match str(Content.get_trait(str(trait_id)).get("polarity", "neutral")):
			"positive": total += 2.5
			"negative": total -= 2.0
	return total


static func _def_best_stat(def: Dictionary) -> String:
	var stats: Dictionary = def.get("stats", {})
	var best := ""
	var best_val := -1
	for s in Content.stat_keys:
		var v := int(stats.get(s, 5))
		if v > best_val:
			best_val = v
			best = s
	return best


## Builds one live Prisoner from a definition, with this run's variation.
static func make_candidate(def: Dictionary) -> Prisoner:
	var p := Prisoner.from_def(def)
	if p == null:
		return null

	if Rng.chance(JITTER_CHANCE):
		_apply_net_zero_jitter(p)

	if Rng.chance(EXTRA_TRAIT_CHANCE):
		_add_wildcard_trait(p)

	return p


## Moves one point from a random stat to another. Three rules keep this honest:
##
##   - the total never changes, so variation never becomes power creep;
##   - the character's signature stat is never touched, and nothing is raised to
##     within a point of it, so Big Dave can never jitter into a stealth expert
##     and the three cards keep their distinct strongest stats;
##   - nothing is reduced below 2.
static func _apply_net_zero_jitter(p: Prisoner) -> void:
	var signature := p.best_stat()
	var signature_value := p.base_stat(signature)
	var up := ""
	var down := ""

	for key in Rng.shuffled(Content.stat_keys):
		var stat := str(key)
		if stat == signature:
			continue
		if up.is_empty() and p.base_stat(stat) < signature_value - 1 and p.base_stat(stat) < 10:
			up = stat
		elif down.is_empty() and p.base_stat(stat) > 2:
			down = stat

	if up.is_empty() or down.is_empty() or up == down:
		return
	p.base_stats[up] = p.base_stat(up) + 1
	p.base_stats[down] = p.base_stat(down) - 1


## Occasionally a candidate turns up carrying something extra - good or bad.
static func _add_wildcard_trait(p: Prisoner) -> void:
	var options: Array = []
	for trait_id in Content.trait_defs.keys():
		if not p.has_trait(trait_id):
			options.append(trait_id)
	if options.is_empty():
		return
	# Keep it honest: a wildcard positive is balanced by a wildcard negative
	# roughly half the time, rather than always being a straight upgrade.
	var wanted_polarity := "positive" if Rng.chance(55.0) else "negative"
	var filtered: Array = []
	for trait_id in options:
		if str(Content.get_trait(trait_id).get("polarity", "neutral")) == wanted_polarity:
			filtered.append(trait_id)
	var chosen: Variant = Rng.pick(filtered if not filtered.is_empty() else options)
	if chosen != null:
		p.trait_ids.append(str(chosen))


## A rough "how good is this card" number, used only to avoid blowouts.
static func power_score(p: Prisoner) -> float:
	var total := 0.0
	for s in Content.stat_keys:
		total += p.base_stat(s)
	total += p.max_health * 0.7
	for trait_id in p.trait_ids:
		match str(Content.get_trait(trait_id).get("polarity", "neutral")):
			"positive": total += 2.5
			"negative": total -= 2.0
	return total


static func _power_spread(candidates: Array) -> float:
	var lowest := INF
	var highest := -INF
	for c in candidates:
		var score := power_score(c)
		lowest = minf(lowest, score)
		highest = maxf(highest, score)
	return highest - lowest


static func _strongest_index(candidates: Array) -> int:
	var best := 0
	var best_score := -INF
	for i in range(candidates.size()):
		var score := power_score(candidates[i])
		if score > best_score:
			best_score = score
			best = i
	return best
