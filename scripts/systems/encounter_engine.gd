class_name EncounterEngine
extends RefCounted
## Selects which encounter fires in a room, and works out which choices the
## current crew is actually allowed to take.


## Picks a weighted event valid for this room and Heat level, preferring ones
## the run has not seen. Returns {} only if events.json is empty.
static func pick_event(room_id: String, heat: int, used_ids: Array, party: Array) -> Dictionary:
	var fresh: Array = []
	var seen: Array = []
	for e in Content.event_defs:
		if not _event_valid(e, room_id, heat, party):
			continue
		if used_ids.has(e.get("id", "")):
			seen.append(e)
		else:
			fresh.append(e)

	var pool: Array = fresh if not fresh.is_empty() else seen
	if pool.is_empty():
		# Nothing matched this room at this Heat - fall back to anything at all
		# rather than leaving the player staring at an empty screen.
		for e in Content.event_defs:
			if _rooms_match(e, room_id) or (e.get("rooms", []) as Array).has("any"):
				pool.append(e)
	if pool.is_empty():
		pool = Content.event_defs
	if pool.is_empty():
		return {}

	var chosen: Variant = Rng.weighted_pick(pool)
	return chosen if chosen != null else {}


static func _event_valid(e: Dictionary, room_id: String, heat: int, party: Array) -> bool:
	if not _rooms_match(e, room_id):
		return false
	if heat < int(e.get("min_heat", 0)):
		return false
	if heat > int(e.get("max_heat", 100)):
		return false
	if bool(e.get("requires_injured", false)) and not _anyone_hurt(party):
		return false
	return true


static func _rooms_match(e: Dictionary, room_id: String) -> bool:
	var rooms: Array = e.get("rooms", [])
	if rooms.is_empty():
		return true
	return rooms.has(room_id) or rooms.has("any")


static func _anyone_hurt(party: Array) -> bool:
	for m in party:
		if m is Prisoner and ((m as Prisoner).is_hurt() or not (m as Prisoner).is_available()):
			return true
	return false


## --- Choice gating -------------------------------------------------------

## Returns { "available": bool, "reason": String } for one choice. Locked
## choices are still shown, with the requirement spelled out, so the player can
## see what a different party would have unlocked.
static func choice_availability(choice: Dictionary, party: Array, money: int) -> Dictionary:
	var cost := int(choice.get("cost_money", 0))
	if cost > money:
		return {"available": false, "reason": "Costs $%d - you have $%d" % [cost, money]}

	var requires: Dictionary = choice.get("requires", {})
	if requires.has("trait"):
		var trait_id := str(requires["trait"])
		if eligible_actors(choice, party).is_empty():
			return {"available": false, "reason": "Needs somebody with %s" % Content.trait_name(trait_id)}

	if requires.has("stat"):
		for stat in (requires["stat"] as Dictionary).keys():
			var needed := int(requires["stat"][stat])
			if eligible_actors(choice, party).is_empty():
				return {"available": false, "reason": "Needs %s %d+" % [str(stat).capitalize(), needed]}

	if eligible_actors(choice, party).is_empty():
		return {"available": false, "reason": "Nobody is in a fit state for this"}

	return {"available": true, "reason": ""}


## Which crew members may be sent on this choice.
static func eligible_actors(choice: Dictionary, party: Array) -> Array:
	var requires: Dictionary = choice.get("requires", {})
	var out: Array = []
	for member in party:
		if not (member is Prisoner):
			continue
		var p: Prisoner = member
		if not p.is_available():
			continue
		if requires.has("trait") and not p.has_trait(str(requires["trait"])):
			continue
		var stat_ok := true
		for stat in (requires.get("stat", {}) as Dictionary).keys():
			if p.effective_stat(str(stat)) < int(requires["stat"][stat]):
				stat_ok = false
				break
		if not stat_ok:
			continue
		out.append(p)
	return out


## The crew member most likely to pull this choice off - used to pre-select a
## sensible default so the player is never forced to compare six numbers.
static func best_actor(choice: Dictionary, party: Array) -> Prisoner:
	var actors := eligible_actors(choice, party)
	if actors.is_empty():
		return null
	var stat := str(choice.get("stat", "luck"))
	var best: Prisoner = actors[0]
	for a in actors:
		if (a as Prisoner).effective_stat(stat) > best.effective_stat(stat):
			best = a
	return best


static func choice_tags(choice: Dictionary) -> Array:
	return choice.get("tags", [])
