class_name CheckResult
extends RefCounted
## The full, inspectable outcome of one skill check.
##
## Section 36 of the design spec asks that the player always understands why
## something happened, so this carries the entire arithmetic - every modifier
## with a label - and the encounter screen renders it verbatim.

enum Tier { CRIT_FAILURE, FAILURE, SUCCESS, CRIT_SUCCESS }

var tier: int = Tier.FAILURE
var actor_name: String = ""
var stat_name: String = ""
var stat_value: int = 0
var final_chance: int = 0
var roll: int = 0
var crit_success_at: int = 0
var crit_failure_at: int = 0
var breakdown: Array = []       ## [{ "label": String, "value": int }]
var saved_by: String = ""       ## trait or power-up that rescued a failure
var was_saved: bool = false
var save_chance: float = 0.0    ## carried from prepare() to resolve()
var save_source: String = ""


func is_success() -> bool:
	return tier == Tier.SUCCESS or tier == Tier.CRIT_SUCCESS


func is_critical() -> bool:
	return tier == Tier.CRIT_SUCCESS or tier == Tier.CRIT_FAILURE


func outcome_key() -> String:
	match tier:
		Tier.CRIT_SUCCESS: return "crit_success"
		Tier.SUCCESS: return "success"
		Tier.CRIT_FAILURE: return "crit_failure"
		_: return "failure"


func tier_name() -> String:
	match tier:
		Tier.CRIT_SUCCESS: return "CRITICAL SUCCESS"
		Tier.SUCCESS: return "SUCCESS"
		Tier.CRIT_FAILURE: return "CRITICAL FAILURE"
		_: return "FAILURE"


func tier_color() -> Color:
	match tier:
		Tier.CRIT_SUCCESS: return Color("#6ee7a0")
		Tier.SUCCESS: return Color("#5fb878")
		Tier.CRIT_FAILURE: return Color("#8b2c28")
		_: return Color("#d9534f")


func add_modifier(label: String, value: int) -> void:
	if value == 0:
		return
	breakdown.append({"label": label, "value": value})
