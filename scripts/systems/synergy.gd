class_name Synergy
extends RefCounted
## Party synergies, matched against tags rather than character ids so they keep
## working after the cast is rewritten. See data/synergies.json.


## Every synergy the current party satisfies.
static func active(party: Array) -> Array:
	var tag_counts := count_tags(party)
	var out: Array = []
	for s in Content.synergy_defs:
		if _matches(s, tag_counts):
			out.append(s)
	return out


static func count_tags(party: Array) -> Dictionary:
	var counts: Dictionary = {}
	for member in party:
		if not (member is Prisoner):
			continue
		for tag in (member as Prisoner).all_tags():
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


static func _matches(s: Dictionary, tag_counts: Dictionary) -> bool:
	if s.has("requires_distinct_tags"):
		for tag in s["requires_distinct_tags"]:
			if int(tag_counts.get(tag, 0)) < 1:
				return false
		return true
	var needed := int(s.get("count", 1))
	for tag in s.get("requires_tags", []):
		if int(tag_counts.get(tag, 0)) >= needed:
			return true
	return false


## Folds the active synergies into check modifiers for one specific action.
static func modifiers_for(party: Array, contexts: Array) -> Dictionary:
	var out := {"bonuses": [], "crit_success_bonus": 0, "crit_fail_bonus": 0}
	for s in active(party):
		var s_name: String = s.get("name", s.get("id", "Synergy"))
		var s_contexts: Array = s.get("contexts", [])
		if _context_hit(s_contexts, contexts):
			var bonus := int(s.get("bonus", 0))
			if bonus != 0:
				out["bonuses"].append({"label": s_name, "value": bonus})
		var penalty_contexts: Array = s.get("penalty_contexts", [])
		if not penalty_contexts.is_empty() and _context_hit(penalty_contexts, contexts):
			var penalty := int(s.get("penalty", 0))
			if penalty != 0:
				out["bonuses"].append({"label": "%s (wrong tool)" % s_name, "value": penalty})
		out["crit_success_bonus"] = int(out["crit_success_bonus"]) + int(s.get("crit_success_bonus", 0))
		out["crit_fail_bonus"] = int(out["crit_fail_bonus"]) + int(s.get("crit_fail_bonus", 0))
	return out


static func _context_hit(required: Array, contexts: Array) -> bool:
	if required.is_empty():
		return true
	for c in required:
		if contexts.has(c):
			return true
	return false
