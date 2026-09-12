class_name Prisoner
extends RefCounted
## One member of the crew. Built from a block in data/characters.json, then
## mutated over the run by damage, status effects, power-ups and trait growth.
##
## Nothing in here knows about the UI. Portraits are drawn from `visual` by
## scripts/ui/character_portrait.gd.

var id: String = ""
var display_name: String = ""
var nickname: String = ""
var description: String = ""

var base_stats: Dictionary = {}      ## from JSON, never modified
var stat_bonuses: Dictionary = {}    ## power-ups and trait growth accumulate here
var trait_ids: Array = []
var own_tags: Array = []
var quips: Dictionary = {}
var visual: Dictionary = {}

var max_health: int = 10
var health: int = 10
var status: String = "healthy"
var status_rooms_left: int = -1

## Run bookkeeping, shown in the party screen and the summary.
var checks_attempted: int = 0
var checks_passed: int = 0


static func from_def(def: Dictionary) -> Prisoner:
	var p := Prisoner.new()
	p.id = def.get("id", "unknown")
	p.display_name = def.get("name", "Unnamed")
	p.nickname = def.get("nickname", "")
	p.description = def.get("description", "")
	p.base_stats = (def.get("stats", {}) as Dictionary).duplicate()
	p.trait_ids = (def.get("traits", []) as Array).duplicate()
	p.own_tags = (def.get("tags", []) as Array).duplicate()
	p.quips = (def.get("quips", {}) as Dictionary).duplicate(true)
	p.visual = (def.get("visual", {}) as Dictionary).duplicate()
	p.max_health = int(def.get("max_health", 10))
	p.health = p.max_health
	for k in p.base_stats.keys():
		p.stat_bonuses[k] = 0
	return p


## --- Stats ---------------------------------------------------------------

func base_stat(stat: String) -> int:
	return int(base_stats.get(stat, 5))


## Base + accumulated bonuses + whatever the current status is doing. This is
## the number every skill check actually uses.
func effective_stat(stat: String) -> int:
	var value := base_stat(stat) + int(stat_bonuses.get(stat, 0))
	var mods: Dictionary = Content.get_status(status).get("stat_mods", {})
	value += int(mods.get(stat, 0))
	return clampi(value, 1, 20)


func status_delta(stat: String) -> int:
	var mods: Dictionary = Content.get_status(status).get("stat_mods", {})
	return int(mods.get(stat, 0))


func add_stat_bonus(stat: String, amount: int) -> void:
	stat_bonuses[stat] = int(stat_bonuses.get(stat, 0)) + amount


func best_stat() -> String:
	var best := ""
	var best_val := -1
	for s in Content.stat_keys:
		var v := effective_stat(s)
		if v > best_val:
			best_val = v
			best = s
	return best


## --- Traits and tags -----------------------------------------------------

func has_trait(trait_id: String) -> bool:
	return trait_ids.has(trait_id)


func trait_names() -> Array:
	var out: Array = []
	for t in trait_ids:
		out.append(Content.trait_name(t))
	return out


## A character's own tags plus every tag contributed by their traits. Synergies
## match against this, which is why rewriting the cast does not break them.
func all_tags() -> Array:
	var out: Array = own_tags.duplicate()
	for t in trait_ids:
		for tag in Content.get_trait(t).get("tags", []):
			if not out.has(tag):
				out.append(tag)
	return out


## --- Condition -----------------------------------------------------------

func is_available() -> bool:
	return status != "unconscious" and health > 0


func is_hurt() -> bool:
	return health < max_health


func apply_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var reduction := 0
	for t in trait_ids:
		for e in Content.get_trait(t).get("effects", []):
			if e.get("type", "") == "damage_taken":
				reduction += int(e.get("value", 0))
	reduction += int(Game.global_damage_modifier())
	var actual: int = maxi(1, amount + reduction)
	health = maxi(0, health - actual)
	if health == 0:
		set_status("unconscious")
	elif status == "healthy":
		set_status("injured")
	return actual


func heal_by(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := health
	health = mini(max_health, health + amount)
	if health > 0 and status == "unconscious":
		status = "injured"
		status_rooms_left = -1
	if health >= max_health and status == "injured":
		set_status("healthy")
	return health - before


func revive() -> bool:
	if status != "unconscious":
		return false
	health = maxi(1, int(round(max_health * 0.5)))
	set_status("injured")
	return true


func set_status(new_status: String) -> void:
	if status == "unconscious" and new_status != "healthy" and new_status != "injured":
		return  # unconscious outranks everything short of a revive
	status = new_status
	status_rooms_left = int(Content.get_status(new_status).get("duration", -1))


## Called once per room. Temporary statuses decay back to healthy/injured.
func tick_room() -> void:
	if status_rooms_left > 0:
		status_rooms_left -= 1
		if status_rooms_left == 0:
			status = "injured" if health < max_health else "healthy"
			status_rooms_left = -1


func status_name() -> String:
	return Content.get_status(status).get("name", status.capitalize())


func status_color() -> Color:
	return Color(Content.get_status(status).get("color", "#888888"))


## --- Flavour -------------------------------------------------------------

func quip(kind: String) -> String:
	var lines: Array = quips.get(kind, [])
	if lines.is_empty():
		return ""
	return str(Rng.pick(lines))


func full_name() -> String:
	if nickname.is_empty():
		return display_name
	return "%s \"%s\"" % [display_name, nickname]


## --- Serialisation -------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": id,
		# base_stats and trait_ids are both mutated at recruitment time by
		# CharacterFactory (net-zero stat jitter, and the occasional wildcard
		# trait), so they cannot be rebuilt from characters.json on load.
		"base_stats": base_stats.duplicate(),
		"trait_ids": trait_ids.duplicate(),
		"stat_bonuses": stat_bonuses.duplicate(),
		"health": health,
		"max_health": max_health,
		"status": status,
		"status_rooms_left": status_rooms_left,
		"checks_attempted": checks_attempted,
		"checks_passed": checks_passed,
	}


static func from_dict(d: Dictionary) -> Prisoner:
	var def := Content.get_character_def(d.get("id", ""))
	if def.is_empty():
		return null
	var p := Prisoner.from_def(def)

	# JSON has no integer type, so everything comes back as a float. Coerce the
	# stat tables rather than trusting what the parser hands us.
	var saved_base: Dictionary = d.get("base_stats", {})
	for stat in saved_base.keys():
		p.base_stats[stat] = int(saved_base[stat])
	if d.has("trait_ids"):
		p.trait_ids = (d.get("trait_ids", []) as Array).duplicate()

	p.stat_bonuses = {}
	var saved_bonuses: Dictionary = d.get("stat_bonuses", {})
	for stat in saved_bonuses.keys():
		p.stat_bonuses[stat] = int(saved_bonuses[stat])
	p.max_health = int(d.get("max_health", p.max_health))
	p.health = int(d.get("health", p.health))
	p.status = d.get("status", "healthy")
	p.status_rooms_left = int(d.get("status_rooms_left", -1))
	p.checks_attempted = int(d.get("checks_attempted", 0))
	p.checks_passed = int(d.get("checks_passed", 0))
	return p
