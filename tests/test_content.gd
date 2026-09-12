extends RefCounted
## Content integrity. These catch the most common editing mistake - a typo in an
## id - before it turns into a silent zero somewhere in the maths.

const VALID_STATUSES := ["healthy", "injured", "scared", "angry", "exhausted", "suspicious", "unconscious"]
const OUTCOME_KEYS := ["crit_success", "success", "failure", "crit_failure"]


static func run(t: TestRunner) -> void:
	t.suite("Content")

	t.check(Content.load_errors.is_empty(), "every data file loaded (%s)" % str(Content.load_errors))
	t.check(Content.character_defs.size() >= 15, "at least 15 characters (%d)" % Content.character_defs.size())
	t.check(Content.trait_defs.size() >= 20, "at least 20 traits (%d)" % Content.trait_defs.size())
	t.check(Content.event_defs.size() >= 15, "at least 15 events (%d)" % Content.event_defs.size())
	t.check(Content.powerup_defs.size() >= 20, "at least 20 power-ups (%d)" % Content.powerup_defs.size())
	t.check(Content.catch_defs.size() >= 5, "at least 5 catches (%d)" % Content.catch_defs.size())
	t.check(Content.escape_routes.size() >= 3, "at least 3 escape routes (%d)" % Content.escape_routes.size())
	t.check(Content.room_defs.size() >= 10, "at least 10 room types (%d)" % Content.room_defs.size())

	var bad_trait_refs: Array = []
	var bad_stats: Array = []
	var seen_ids: Dictionary = {}
	var duplicate_ids: Array = []
	for c in Content.character_defs:
		var cid := str(c.get("id", ""))
		if seen_ids.has(cid):
			duplicate_ids.append(cid)
		seen_ids[cid] = true
		for trait_id in c.get("traits", []):
			if Content.get_trait(str(trait_id)).is_empty():
				bad_trait_refs.append("%s -> %s" % [cid, str(trait_id)])
		for stat in Content.stat_keys:
			var value := int((c.get("stats", {}) as Dictionary).get(stat, -1))
			if value < 1 or value > 10:
				bad_stats.append("%s.%s = %d" % [cid, stat, value])
	t.check(bad_trait_refs.is_empty(), "every character trait id exists (%s)" % str(bad_trait_refs))
	t.check(bad_stats.is_empty(), "every stat is present and within 1-10 (%s)" % str(bad_stats))
	t.check(duplicate_ids.is_empty(), "no duplicate character ids (%s)" % str(duplicate_ids))

	var bad_rooms: Array = []
	var bad_outcomes: Array = []
	var bad_status: Array = []
	for e in Content.event_defs:
		var eid := str(e.get("id", ""))
		for room_id in e.get("rooms", []):
			if str(room_id) != "any" and Content.room_defs.get(str(room_id), null) == null:
				bad_rooms.append("%s -> %s" % [eid, str(room_id)])
		var choices: Array = e.get("choices", [])
		if choices.is_empty():
			bad_outcomes.append("%s has no choices" % eid)
		for choice in choices:
			if bool(choice.get("auto", false)):
				if not choice.has("success"):
					bad_outcomes.append("%s auto-choice has no success block" % eid)
				continue
			if not Content.stat_keys.has(str(choice.get("stat", ""))):
				bad_outcomes.append("%s uses unknown stat %s" % [eid, str(choice.get("stat", ""))])
			for key in OUTCOME_KEYS:
				if not choice.has(key):
					bad_outcomes.append("%s is missing '%s'" % [eid, key])
					continue
				var status := str((choice[key] as Dictionary).get("status", ""))
				if not status.is_empty() and not VALID_STATUSES.has(status):
					bad_status.append("%s.%s -> %s" % [eid, key, status])
	t.check(bad_rooms.is_empty(), "every event room id exists (%s)" % str(bad_rooms))
	t.check(bad_outcomes.is_empty(), "every choice has all four outcomes (%s)" % str(bad_outcomes))
	t.check(bad_status.is_empty(), "every outcome status exists (%s)" % str(bad_status))

	# Every room must be able to produce an encounter, or the player would walk
	# into it and find nothing there.
	var starved: Array = []
	for room_id in Content.room_order:
		var found := false
		for e in Content.event_defs:
			var rooms: Array = e.get("rooms", [])
			if rooms.has(room_id) or rooms.has("any"):
				found = true
				break
		if not found:
			starved.append(room_id)
	t.check(starved.is_empty(), "every room has at least one possible event (%s)" % str(starved))

	var bad_routes: Array = []
	for r in Content.escape_routes:
		var steps: Array = r.get("steps", [])
		if steps.size() < 2:
			bad_routes.append("%s has %d steps" % [str(r.get("id", "")), steps.size()])
		if int(r.get("required_passes", 0)) > steps.size():
			bad_routes.append("%s needs more passes than it has steps" % str(r.get("id", "")))
		for s in steps:
			if not Content.stat_keys.has(str(s.get("stat", ""))):
				bad_routes.append("%s step uses unknown stat" % str(r.get("id", "")))
	t.check(bad_routes.is_empty(), "every escape route is winnable as written (%s)" % str(bad_routes))
