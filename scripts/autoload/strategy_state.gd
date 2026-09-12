extends Node
## Strategy 2.0: persistent consequences that make room decisions affect the rest of a run.

const MAX_LEVEL := 5
var suspicion: int = 0
var noise: int = 0
var intel: int = 0
var guard_attention: int = 0
var favors: int = 0
var flags: Dictionary = {}
var last_room_warning: String = ""

func reset() -> void:
	suspicion = 0
	noise = 0
	intel = 0
	guard_attention = 0
	favors = 0
	flags.clear()
	last_room_warning = ""

func enter_room(room_id: String) -> Dictionary:
	noise = maxi(0, noise - 1)
	if guard_attention > 0 and Game.heat < 40:
		guard_attention = maxi(0, guard_attention - 1)
	last_room_warning = _warning_text()
	if suspicion >= 4:
		flags["wanted"] = true
	if intel >= 3:
		flags["knows_security_patterns"] = true
	return summary()

func observe_outcome(outcome: Dictionary, result: Variant, actor: Prisoner) -> Dictionary:
	var heat_delta := int(outcome.get("heat", 0))
	var damage := int(outcome.get("damage", 0))
	var success := true
	var critical := false
	if result != null:
		success = (result as CheckResult).is_success()
		critical = (result as CheckResult).is_critical()
	var before := summary()
	if success:
		if heat_delta < 0:
			suspicion = maxi(0, suspicion - 1)
			intel = mini(MAX_LEVEL, intel + 1)
		elif heat_delta > 8:
			noise = mini(MAX_LEVEL, noise + 1)
		if critical:
			intel = mini(MAX_LEVEL, intel + 1)
			if "guard" in str(outcome.get("text", "")).to_lower():
				guard_attention = maxi(0, guard_attention - 1)
	else:
		noise = mini(MAX_LEVEL, noise + 1)
		suspicion = mini(MAX_LEVEL, suspicion + (2 if critical else 1))
		if damage > 0:
			flags["injury_known"] = true
		if heat_delta >= 10:
			guard_attention = mini(MAX_LEVEL, guard_attention + 1)
	var note_text := str(outcome.get("note", "")).to_lower()
	if success and ("guard" in note_text or "patrol" in note_text or "key" in note_text):
		favors = mini(MAX_LEVEL, favors + 1)
		intel = mini(MAX_LEVEL, intel + 1)
	last_room_warning = _warning_text()
	return {"before": before, "after": summary(), "changes": _diff(before, summary())}

func modify_situation(situation: Dictionary, contexts: Array) -> void:
	if suspicion >= 2:
		situation["bonuses"].append({"label": "Guard suspicion", "value": -suspicion * 2})
	if noise >= 2:
		situation["bonuses"].append({"label": "Crew noise", "value": -noise})
	if guard_attention >= 2:
		situation["bonuses"].append({"label": "Active patrols", "value": -guard_attention * 2})
	if intel >= 2 and _context_matches(contexts, ["tech", "security", "tunnel", "escape", "deception"]):
		situation["bonuses"].append({"label": "Prison intel", "value": mini(8, intel * 2)})
	if favors > 0 and _context_matches(contexts, ["social", "deception", "guard"]):
		situation["bonuses"].append({"label": "Inside favors", "value": mini(6, favors * 2)})

func choice_modifier(choice: Dictionary) -> Dictionary:
	var tags: Array = choice.get("tags", [])
	if suspicion >= 5 and (tags.has("social") or tags.has("deception")):
		return {"blocked": true, "reason": "The guards already know your faces. This approach is too exposed.", "stat": str(choice.get("stat", "luck"))}
	if guard_attention >= 5 and tags.has("physical"):
		return {"blocked": true, "reason": "The guards are waiting for someone to make a move.", "stat": str(choice.get("stat", "luck"))}
	return {"blocked": false, "reason": "", "stat": str(choice.get("stat", "luck"))}

func room_reward_multiplier() -> float:
	return 1.0 + float(suspicion + noise) * 0.05

func summary() -> Dictionary:
	return {"suspicion": suspicion, "noise": noise, "intel": intel, "guard_attention": guard_attention, "favors": favors, "wanted": bool(flags.get("wanted", false)), "knows_security_patterns": bool(flags.get("knows_security_patterns", false))}

func warning_text() -> String:
	return _warning_text()

func _warning_text() -> String:
	if guard_attention >= 4:
		return "GUARDS ARE ACTIVELY WATCHING THIS CREW"
	if suspicion >= 3:
		return "SOMEONE HAS STARTED ASKING QUESTIONS ABOUT YOU"
	if noise >= 3:
		return "THE CREW IS GETTING LOUD — FUTURE MISTAKES WILL COST MORE"
	if intel >= 3:
		return "YOU HAVE LEARNED ENOUGH TO ANTICIPATE SOME PATROLS"
	return ""

func _context_matches(contexts: Array, wanted: Array) -> bool:
	for tag in wanted:
		if contexts.has(tag):
			return true
	return false

func _diff(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for key in ["suspicion", "noise", "intel", "guard_attention", "favors"]:
		var a := int(before.get(key, 0))
		var b := int(after.get(key, 0))
		if a != b:
			out.append({"label": str(key).capitalize(), "delta": b - a, "good": b < a or key == "intel" or key == "favors", "text": "%s %s%d" % [str(key).capitalize(), "+" if b > a else "", b - a]})
	return out

func to_dict() -> Dictionary:
	return {"suspicion": suspicion, "noise": noise, "intel": intel, "guard_attention": guard_attention, "favors": favors, "flags": flags.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	suspicion = clampi(int(data.get("suspicion", 0)), 0, MAX_LEVEL)
	noise = clampi(int(data.get("noise", 0)), 0, MAX_LEVEL)
	intel = clampi(int(data.get("intel", 0)), 0, MAX_LEVEL)
	guard_attention = clampi(int(data.get("guard_attention", 0)), 0, MAX_LEVEL)
	favors = clampi(int(data.get("favors", 0)), 0, MAX_LEVEL)
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	last_room_warning = _warning_text()
