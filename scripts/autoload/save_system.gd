extends Node
## Autoload: SaveSystem
##
## Two files under user://: settings, which always exist, and one optional
## in-progress run. Both carry a version so the format can change later without
## crashing on somebody's old save.

const SAVE_VERSION := 1
const SETTINGS_PATH := "user://settings.json"
const RUN_PATH := "user://run.json"

var settings: Dictionary = {
	"version": SAVE_VERSION,
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.9,
	"text_speed": 1.0,
	"fullscreen": false,
	"show_check_maths": true,
}

signal settings_changed()


func _ready() -> void:
	load_settings()


## --- Settings ------------------------------------------------------------

func load_settings() -> void:
	var data := _read(SETTINGS_PATH)
	for key in data.keys():
		if settings.has(key):
			settings[key] = data[key]
	settings["version"] = SAVE_VERSION
	settings_changed.emit()


func save_settings() -> void:
	_write(SETTINGS_PATH, settings)
	settings_changed.emit()


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()


## --- Run ------------------------------------------------------------------

func has_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)


func save_run() -> bool:
	return _write(RUN_PATH, Game.to_dict())


func load_run() -> bool:
	var data := _read(RUN_PATH)
	if data.is_empty():
		return false
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("[SaveSystem] Ignoring a run saved by a different version.")
		return false
	return Game.from_dict(data)


func delete_run() -> void:
	if has_run():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


## --- File plumbing --------------------------------------------------------

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveSystem] Could not write " + path)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true
