class_name PowerupSystem
extends RefCounted
## Builds the five-card power-up offer.
##
## The signature mechanic: exactly one of the five has a catch, and the catch is
## attached at offer time rather than baked into the power-up. That means "+2
## Stealth" can be clean in one run and cursed in the next, so the trap can
## never be memorised - only guessed at.

const OFFER_COUNT := 5


## Returns OFFER_COUNT offers, exactly one of which carries a hidden catch.
## An offer is { id, def, catch_id, has_catch, revealed, rooms_since_taken }.
static func generate_offers(owned_ids: Array, count: int = OFFER_COUNT) -> Array:
	var pool: Array = []
	for p in Content.powerup_defs:
		if not owned_ids.has(p.get("id", "")):
			pool.append(p)
	# If the player has somehow taken nearly everything, allow repeats rather
	# than shipping a short offer.
	if pool.size() < count:
		pool = Content.powerup_defs.duplicate()

	var chosen := Rng.shuffled(pool)
	var offers: Array = []
	for i in range(mini(count, chosen.size())):
		offers.append({
			"id": chosen[i].get("id", ""),
			"def": chosen[i],
			"catch_id": "",
			"has_catch": false,
			"revealed": false,
			"rooms_since_taken": 0,
			"cancelled": false,
		})

	if offers.is_empty():
		return offers

	var cursed_index := Rng.roll_int(0, offers.size() - 1)
	var catch_def: Variant = Rng.pick(Content.catch_defs)
	if catch_def != null:
		offers[cursed_index]["catch_id"] = catch_def.get("id", "")
		offers[cursed_index]["has_catch"] = true

	return offers


static func catch_for(offer: Dictionary) -> Dictionary:
	if not bool(offer.get("has_catch", false)):
		return {}
	return Content.get_catch(str(offer.get("catch_id", "")))


## Should this owned power-up's catch fire right now?
## `event` is one of: immediate, next_encounter, on_fail, on_crit_fail,
## delayed, at_escape, on_heat_above, on_room_enter.
static func catch_should_fire(offer: Dictionary, event: String, heat: int) -> bool:
	if not bool(offer.get("has_catch", false)) or bool(offer.get("revealed", false)):
		return false
	var c := catch_for(offer)
	if c.is_empty():
		return false
	var trigger := str(c.get("trigger", ""))
	match trigger:
		"immediate":
			return event == "immediate"
		"next_encounter":
			return event == "on_room_enter" and int(offer.get("rooms_since_taken", 0)) >= 1
		"on_fail":
			return event == "on_fail" or event == "on_crit_fail"
		"on_crit_fail":
			return event == "on_crit_fail"
		"at_escape":
			return event == "at_escape"
		"on_room_enter":
			return event == "on_room_enter"
		"on_heat_above":
			return event == "on_room_enter" and heat >= int(c.get("threshold", 100))
		"delayed":
			return event == "on_room_enter" and int(offer.get("rooms_since_taken", 0)) >= int(c.get("after", 1))
	return false


## The quiet nudge shown in the party screen once a catch has been carried for
## a while. Deliberately withheld on the room it is taken, so the hint is a
## mid-run "something is off" signal rather than a label on the trap card.
static func pending_hint(offer: Dictionary) -> String:
	if not bool(offer.get("has_catch", false)) or bool(offer.get("revealed", false)):
		return ""
	if int(offer.get("rooms_since_taken", 0)) < 1:
		return ""
	return str(catch_for(offer).get("hint_after", ""))
