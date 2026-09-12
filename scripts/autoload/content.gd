extends Node
## Autoload: Content
##
## Loads every file in res://data/ once at startup and hands the rest of the
## game plain Dictionaries and Arrays. Nothing else in the project reads from
## disk, so swapping in new content means editing JSON and relaunching.
##
## Web/mobile export note: .json has no Godot importer, so the export preset's
## "Filters to export non-resource files" must include *.json. See docs/README.md.

signal content_loaded()

const DATA_DIR := "res://data/"

var stat_keys: Array = ["strength", "intelligence", "stealth", "charisma", "luck", "speed"]

var character_defs: Array = []
var trait_defs: Dictionary = {}
var room_defs: Dictionary = {}
var room_order: Array = []
var heat_bands: Array = []
var event_defs: Array = []
var powerup_defs: Array = []
var catch_defs: Array = []
var status_defs: Dictionary = {}
var synergy_defs: Array = []
var escape_routes: Array = []

var load_errors: Array = []
var loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	load_errors.clear()

	var chars := _read_json("characters.json")
	character_defs = chars.get("characters", [])
	if chars.has("stat_keys"):
		stat_keys = chars["stat_keys"]

	for t in _read_json("traits.json").get("traits", []):
		trait_defs[t.get("id", "")] = t

	var rooms := _read_json("rooms.json")
	for r in rooms.get("rooms", []):
		room_defs[r.get("id", "")] = r
		room_order.append(r.get("id", ""))
	heat_bands = rooms.get("heat_bands", [])

	event_defs = _read_json("events.json").get("events", [])
	powerup_defs = _read_json("powerups.json").get("powerups", [])
	catch_defs = _read_json("catches.json").get("catches", [])

	for s in _read_json("status_effects.json").get("statuses", []):
		status_defs[s.get("id", "")] = s

	synergy_defs = _read_json("synergies.json").get("synergies", [])
	escape_routes = _read_json("escape_routes.json").get("routes", [])

	loaded = true
	for err in load_errors:
		push_error("[Content] " + err)
	content_loaded.emit()


func _read_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		load_errors.append("Missing data file: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		# Some export configurations hand .json to the resource importer instead
		# of leaving it as a plain file. Try that route before giving up.
		var imported: Variant = ResourceLoader.load(path)
		if imported is JSON and typeof((imported as JSON).data) == TYPE_DICTIONARY:
			return (imported as JSON).data
		load_errors.append("Could not open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("Malformed JSON in " + file_name)
		return {}
	return parsed


## --- Lookups -------------------------------------------------------------

func get_character_def(id: String) -> Dictionary:
	for c in character_defs:
		if c.get("id", "") == id:
			return c
	return {}


func get_trait(id: String) -> Dictionary:
	return trait_defs.get(id, {})


func trait_name(id: String) -> String:
	return get_trait(id).get("name", id)


func get_room(id: String) -> Dictionary:
	return room_defs.get(id, {"id": id, "name": id.capitalize(), "color": "#5b6478", "danger": 1, "affinity": [], "tags": [], "blurb": ""})


func get_status(id: String) -> Dictionary:
	return status_defs.get(id, status_defs.get("healthy", {}))


func get_powerup(id: String) -> Dictionary:
	for p in powerup_defs:
		if p.get("id", "") == id:
			return p
	return {}


func get_catch(id: String) -> Dictionary:
	for c in catch_defs:
		if c.get("id", "") == id:
			return c
	return {}


func get_escape_route(id: String) -> Dictionary:
	for r in escape_routes:
		if r.get("id", "") == id:
			return r
	return {}


func heat_band(heat: int) -> Dictionary:
	for b in heat_bands:
		if heat >= int(b.get("min", 0)) and heat <= int(b.get("max", 100)):
			return b
	if heat_bands.is_empty():
		return {"name": "UNKNOWN", "color": "#888888", "flavor": ""}
	return heat_bands[heat_bands.size() - 1]


func stat_label(stat: String) -> String:
	return stat.substr(0, 3).to_upper()
