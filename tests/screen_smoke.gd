extends Node
## Renders every screen in sequence and saves a PNG of each.
##
##     godot --path . tests/screen_smoke.tscn
##
## The headless suite proves the rules are right; this proves the screens
## actually build and draw. It walks the real router and the real game state, so
## a broken layout, a missing node or a bad _draw() shows up as an error in the
## output and a blank or half-built image on disk.
##
## Screenshots land in user://screens/ - the absolute path is printed on exit.

const SHOT_DIR := "user://screens/"
## Long enough for the fade-in and the staggered card tweens to finish.
const SETTLE_SECONDS := 1.1

var _main: Control
var _shots: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run.call_deferred()


func _run() -> void:
	await _settle()
	await _shoot("01_main_menu")

	_main.call("go_to", "how_to_play")
	await _shoot("02_how_to_play")

	_main.call("go_to", "settings")
	await _shoot("03_settings")

	# A fixed seed so the screenshots are comparable between runs.
	Game.start_run(20260912)
	_main.call("go_to", "recruitment")
	await _shoot("04_choose_main_prisoner")

	while not Game.party_is_full():
		Game.recruit(Game.draw_candidates()[0])
	Game.lock_party_and_generate_prison()

	_main.call("go_to", "party", {"locking": true})
	await _shoot("05_party_locked")

	_main.call("go_to", "map")
	await _shoot("06_prison_map")

	var reachable := Game.reachable_nodes()
	if reachable.is_empty():
		push_error("[smoke] the starting room leads nowhere")
	else:
		_main.call("go_to", "encounter", {"node_id": str(reachable[0])})
		await _shoot("07_encounter")

		# Drive the encounter through to a resolved check, which is the most
		# complicated thing the UI draws: the modifier table and the roll bar.
		var screen: Node = _main.get("_current")
		var event: Dictionary = Game.current_event
		if screen != null and not event.is_empty():
			var choice := _first_usable_choice(event)
			if not choice.is_empty():
				screen.call("_on_choice_picked", choice)
				await _settle()
				var actor: Prisoner = null
				if not bool(choice.get("auto", false)):
					actor = EncounterEngine.best_actor(choice, Game.party)
				screen.call("_resolve", actor)
				await _shoot("08_check_result", 2.2)

		Game.clear_current_room()

	_main.call("go_to", "powerup")
	await _shoot("09_powerup_choice")

	_main.call("go_to", "escape")
	await _shoot("10_escape_routes")

	Game.finish_run("escaped", "ESCAPED",
		"You surface in a wet field four hundred metres beyond the wall, covered in something nobody will discuss.")
	_main.call("go_to", "summary")
	await _shoot("11_run_summary")

	print("\n%d screens rendered to %s" % [_shots.size(), ProjectSettings.globalize_path(SHOT_DIR)])
	for s in _shots:
		print("  " + str(s))
	get_tree().quit(0)


func _first_usable_choice(event: Dictionary) -> Dictionary:
	for choice in event.get("choices", []):
		if bool(EncounterEngine.choice_availability(choice, Game.party, Game.money)["available"]):
			return choice
	return {}


func _settle(seconds: float = SETTLE_SECONDS) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _shoot(shot_name: String, seconds: float = SETTLE_SECONDS) -> void:
	await _settle(seconds)
	var image := get_viewport().get_texture().get_image()
	var path := SHOT_DIR + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		push_error("[smoke] could not write %s (error %d)" % [path, err])
		return
	# A screen that renders as one flat colour is almost certainly broken.
	if _is_blank(image):
		push_error("[smoke] %s rendered blank" % shot_name)
	_shots.append("%s  (%dx%d)" % [shot_name, image.get_width(), image.get_height()])


func _is_blank(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	var step: int = maxi(1, image.get_width() / 40)
	for x in range(0, image.get_width(), step):
		for y in range(0, image.get_height(), step):
			if image.get_pixel(x, y) != first:
				return false
	return true
