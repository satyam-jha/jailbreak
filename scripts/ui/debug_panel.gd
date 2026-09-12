class_name DebugPanel
extends PanelContainer
## Development tools, opened with F1. Everything here mutates the live run so
## that a specific situation can be reproduced without playing up to it.
##
## Game.debug_enabled gates the key; set it false (or delete this file and the
## two references to it in scripts/main.gd) for a release build.

var main: Node  ## the Main router; called dynamically to avoid a cyclic type reference

var _seed_input: LineEdit
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-330, 16)
	custom_minimum_size = Vector2(310, 0)
	add_theme_stylebox_override("panel", UIKit.stylebox(Palette.BG_DEEP, Palette.ACCENT, 12))

	var v := UIKit.vbox(6)
	add_child(v)

	var head := UIKit.hbox(8)
	head.add_child(UIKit.label("DEBUG", 16, Palette.ACCENT))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.label("F1 to close", 12, Palette.TEXT_FAINT))
	v.add_child(head)

	_status = UIKit.label("Every button here changes the live run.", 12, Palette.TEAL)
	v.add_child(_status)

	var seed_row := UIKit.hbox(6)
	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "seed"
	_seed_input.text = str(Game.seed_value)
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_input)
	seed_row.add_child(_small("Set seed", _cmd_set_seed))
	v.add_child(seed_row)

	v.add_child(_small("Regenerate party", _cmd_regenerate_party))
	v.add_child(_small("Regenerate prison", _cmd_regenerate_prison))

	var heat_row := UIKit.hbox(6)
	heat_row.add_child(_small("Heat 0", _cmd_heat_0))
	heat_row.add_child(_small("Heat 50", _cmd_heat_50))
	heat_row.add_child(_small("Heat 95", _cmd_heat_95))
	v.add_child(heat_row)

	var care_row := UIKit.hbox(6)
	care_row.add_child(_small("+$200", _cmd_add_money))
	care_row.add_child(_small("Heal party", _cmd_heal_party))
	care_row.add_child(_small("Damage party", _cmd_damage_party))
	v.add_child(care_row)

	v.add_child(_small("Give a random power-up", _cmd_give_powerup))
	v.add_child(_small("Force a new event here", _cmd_force_event))
	v.add_child(_small("Jump to the escape", _cmd_jump_to_escape))

	var end_row := UIKit.hbox(6)
	end_row.add_child(_small("Win run", _cmd_win))
	end_row.add_child(_small("Lose run", _cmd_lose))
	v.add_child(end_row)

	v.add_child(UIKit.paragraph(
		"Loaded: %d characters, %d traits, %d events, %d power-ups, %d catches, %d rooms" % [
			Content.character_defs.size(), Content.trait_defs.size(), Content.event_defs.size(),
			Content.powerup_defs.size(), Content.catch_defs.size(), Content.room_defs.size()],
		11, Palette.TEXT_FAINT))


func _small(text: String, action: Callable) -> Button:
	var b := UIKit.button(text, 13, 30)
	b.pressed.connect(_run.bind(action))
	return b


func _run(action: Callable) -> void:
	Audio.play("click")
	action.call()


func _say(text: String) -> void:
	_status.text = text


func _go(screen_name: String) -> void:
	if main != null and main.has_method("go_to"):
		main.call("go_to", screen_name)
	queue_free()


## --- Commands ------------------------------------------------------------

func _cmd_set_seed() -> void:
	var value := int(_seed_input.text)
	Game.start_run(value if value > 0 else -1)
	_go("recruitment")


func _cmd_regenerate_party() -> void:
	Game.start_run(Game.seed_value if Game.seed_value > 0 else -1)
	_go("recruitment")


func _cmd_regenerate_prison() -> void:
	if Game.party.is_empty():
		_say("Recruit a crew first.")
		return
	Game.lock_party_and_generate_prison()
	_go("map")


func _cmd_heat_0() -> void:
	_set_heat(0)


func _cmd_heat_50() -> void:
	_set_heat(50)


func _cmd_heat_95() -> void:
	_set_heat(95)


func _set_heat(value: int) -> void:
	Game.set_heat(value)
	_say("Heat set to %d (%s)." % [Game.heat, Game.heat_band_name()])


func _cmd_add_money() -> void:
	Game.add_money(200)
	_say("Money is now $%d." % Game.money)


func _cmd_heal_party() -> void:
	for m in Game.party:
		var p: Prisoner = m
		p.revive()
		p.heal_by(999)
		p.set_status("healthy")
	_say("Everybody is fine now.")


func _cmd_damage_party() -> void:
	for m in Game.party:
		(m as Prisoner).apply_damage(3)
	_say("Everybody is worse now.")


func _cmd_give_powerup() -> void:
	if Game.party.is_empty():
		_say("Recruit a crew first.")
		return
	var offers := PowerupSystem.generate_offers(Game.owned_powerup_ids(), 1)
	if offers.is_empty():
		_say("No power-ups left to give.")
		return
	Game.take_powerup(offers[0], Game.random_available_member())
	_say("Granted: %s" % str((offers[0].get("def", {}) as Dictionary).get("name", "?")))


func _cmd_force_event() -> void:
	if Game.map.is_empty():
		_say("No prison generated yet.")
		return
	var room_id := str(Game.current_node().get("room_id", "cell_block"))
	Game.current_event = EncounterEngine.pick_event(room_id, Game.heat, [], Game.party)
	_say("Rolled: %s" % str(Game.current_event.get("title", "nothing")))


func _cmd_jump_to_escape() -> void:
	if Game.map.is_empty():
		_say("No prison generated yet.")
		return
	Game.current_node_id = str(Game.map.get("final", ""))
	_go("escape")


func _cmd_win() -> void:
	Game.finish_run("escaped", "ESCAPED (DEBUG)",
		"The developer opened a door. This is not a legitimate escape and everybody involved knows it.")
	_go("summary")


func _cmd_lose() -> void:
	Game.finish_run("caught", "CAUGHT (DEBUG)",
		"The developer closed a door. Deeply unsporting.")
	_go("summary")
