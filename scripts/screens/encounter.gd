extends Screen
## A room, an event, a choice, and the consequences.
##
## Three states, rebuilt in place: pick a choice, pick who does it, watch it go
## wrong. The screen never hides the maths - the estimated success chance is on
## every choice button before you commit.

enum State { CHOICES, ACTOR, RESULT }

var _state: int = State.CHOICES
var _node_data: Dictionary = {}
var _event: Dictionary = {}
var _entry_changes: Array = []
var _entry_catches: Array = []
var _selected_choice: Dictionary = {}
var _report: Dictionary = {}
var _body: VBoxContainer


func _init() -> void:
	show_hud = true
	music_mood = "gameplay"


func build() -> void:
	var node_id := str(payload.get("node_id", ""))
	if node_id.is_empty():
		go("map")
		return

	_entry_changes = Game.enter_node(node_id)
	_entry_catches = Game.fire_catches("on_room_enter")
	_node_data = Game.node(node_id)
	_event = Game.current_event

	music_mood = "tension" if Game.heat >= 60 else "gameplay"
	Audio.play_music(music_mood)

	var root := UIKit.margin(24)
	add_child(root)

	var column := UIKit.vbox(12)
	root.add_child(column)

	column.add_child(_room_header())

	var scroller := UIKit.scroll()
	column.add_child(scroller)
	_body = UIKit.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(_body)

	_render()


## --- Header --------------------------------------------------------------

func _room_header() -> Control:
	var room: Dictionary = Content.get_room(str(_node_data.get("room_id", "")))
	var path_type := int(_node_data.get("path_type", 0))

	var box := UIKit.panel(Palette.PANEL, Palette.with_alpha(PrisonGenerator.path_color(path_type), 0.6), 14)
	var v := UIKit.vbox(8)
	box.add_child(v)

	var scene := RoomScene.new(str(room.get("id", "cell_block")))
	scene.custom_minimum_size.y = 110
	v.add_child(scene)

	var row := UIKit.hbox(10)
	row.add_child(RoomIcon.new(str(room.get("icon", "bars")), Palette.TEXT))
	row.add_child(UIKit.label(str(room.get("name", "?")), 24, Palette.TEXT))
	row.add_child(UIKit.chip(PrisonGenerator.path_label(path_type), PrisonGenerator.path_color(path_type)))
	if float(_node_data.get("reward_mult", 1.0)) > 1.0:
		row.add_child(UIKit.chip("x%.1f payout" % float(_node_data.get("reward_mult", 1.0)), Palette.ACCENT))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label("Day %d" % Game.day, 14, Palette.TEXT_FAINT))
	v.add_child(row)
	return box


## --- State rendering -----------------------------------------------------

func _clear_body() -> void:
	# Detach before freeing: queue_free() is deferred, so leaving the outgoing
	# nodes parented would make the container lay out both sets for a frame.
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


func _render() -> void:
	_clear_body()
	match _state:
		State.CHOICES: _render_choices()
		State.ACTOR: _render_actor_picker()
		State.RESULT: _render_result()


func _render_choices() -> void:
	if not _entry_changes.is_empty():
		_body.add_child(changes_panel(_entry_changes, "ON THE WAY IN"))
	for report in _entry_catches:
		_body.add_child(_catch_panel(report))

	if _event.is_empty():
		_body.add_child(UIKit.paragraph("Nothing happens here. Suspicious, but you will take it.", 18, Palette.TEXT_DIM))
		var onward := UIKit.primary_button("MOVE ON", 18)
		onward.pressed.connect(_finish_room)
		_body.add_child(onward)
		return

	var event_box := UIKit.panel(Palette.PANEL, Palette.BORDER, 14)
	var v := UIKit.vbox(8)
	event_box.add_child(v)
	v.add_child(UIKit.title(str(_event.get("title", "")), 26, Palette.ACCENT))
	v.add_child(UIKit.paragraph(str(_event.get("description", "")), 17, Palette.TEXT))
	_body.add_child(event_box)
	UIKit.pop_in(event_box, 0.25)

	_body.add_child(UIKit.section("What do you do?"))

	var choices: Array = _event.get("choices", [])
	var any_available := false
	for i in range(choices.size()):
		if bool(EncounterEngine.choice_availability(choices[i], Game.party, Game.money)["available"]):
			any_available = true
		var card := _choice_card(choices[i])
		_body.add_child(card)
		UIKit.pop_in(card, 0.22, 0.05 * i)

	# Safety valve: a crew can in principle meet none of an event's conditions.
	# Rather than strand the player, offer the universally available option.
	if not any_available:
		var stuck := UIKit.panel(Palette.PANEL_DARK, Palette.WARN, 12)
		var sv := UIKit.vbox(6)
		stuck.add_child(sv)
		sv.add_child(UIKit.paragraph(
			"Nobody in this crew can do any of that. You stand there for a while and then leave.",
			16, Palette.TEXT_DIM))
		var leave := UIKit.primary_button("STAND THERE, THEN LEAVE", 18)
		leave.pressed.connect(_walk_away)
		sv.add_child(leave)
		_body.add_child(stuck)


func _choice_card(choice: Dictionary) -> Control:
	var availability := EncounterEngine.choice_availability(choice, Game.party, Game.money)
	var available := bool(availability["available"])

	var box := UIKit.panel(
		Palette.PANEL_HI if available else Palette.PANEL_DARK,
		Palette.BORDER if available else Palette.darken(Palette.BORDER, 0.4), 12)

	var v := UIKit.vbox(5)
	box.add_child(v)

	var head := UIKit.hbox(10)
	var text := UIKit.paragraph(str(choice.get("text", "")), 18, Palette.TEXT if available else Palette.TEXT_FAINT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)

	if bool(choice.get("auto", false)):
		head.add_child(UIKit.chip("NO CHECK", Palette.TEAL))
	else:
		var stat := str(choice.get("stat", "luck"))
		head.add_child(UIKit.chip(stat.to_upper(), Palette.stat_color(stat)))
		if available:
			var estimate := _estimate(choice)
			head.add_child(UIKit.chip("%d%%" % estimate, _chance_color(estimate)))
	v.add_child(head)

	var notes := UIKit.hbox(8)
	if choice.has("hint"):
		notes.add_child(UIKit.label(str(choice["hint"]), 13, Palette.TEXT_FAINT))
	if int(choice.get("cost_money", 0)) > 0:
		notes.add_child(UIKit.chip("Costs $%d" % int(choice["cost_money"]), Palette.ACCENT))
	var difficulty := int(choice.get("difficulty", 0)) + int(_node_data.get("extra_difficulty", 0))
	if difficulty > 0:
		notes.add_child(UIKit.chip("Difficult", Palette.WARN))
	elif difficulty < 0:
		notes.add_child(UIKit.chip("Favourable", Palette.SUCCESS))
	if not available:
		notes.add_child(UIKit.label(str(availability["reason"]), 13, Palette.DANGER))
	notes.add_child(UIKit.spacer())
	v.add_child(notes)

	if available:
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(func() -> void:
			Audio.play("select")
			_on_choice_picked(choice))
		btn.mouse_entered.connect(func() -> void: Audio.play("hover"))
		box.add_child(btn)
	return box


## The honest odds for the crew's best candidate, shown before committing.
func _estimate(choice: Dictionary, actor: Prisoner = null) -> int:
	if bool(choice.get("auto", false)):
		return 100
	var who := actor if actor != null else EncounterEngine.best_actor(choice, Game.party)
	if who == null:
		return 0
	var contexts: Array = choice.get("tags", [])
	var difficulty := int(choice.get("difficulty", 0)) + int(_node_data.get("extra_difficulty", 0))
	var preview := SkillCheck.prepare(who, str(choice.get("stat", "luck")), contexts, difficulty, Game.build_situation(contexts))
	return preview.final_chance


func _chance_color(percent: int) -> Color:
	if percent >= 70:
		return Palette.SUCCESS
	if percent >= 45:
		return Palette.ACCENT
	return Palette.DANGER


func _on_choice_picked(choice: Dictionary) -> void:
	_selected_choice = choice
	if bool(choice.get("auto", false)):
		_resolve(null)
		return
	_state = State.ACTOR
	_render()


## --- Actor picker --------------------------------------------------------

func _render_actor_picker() -> void:
	var box := UIKit.panel(Palette.PANEL, Palette.BORDER, 14)
	var v := UIKit.vbox(6)
	box.add_child(v)
	v.add_child(UIKit.paragraph(str(_selected_choice.get("text", "")), 19, Palette.TEXT))
	var stat := str(_selected_choice.get("stat", "luck"))
	v.add_child(UIKit.label("This is a %s check. Who goes?" % stat.capitalize(), 15, Palette.stat_color(stat)))
	_body.add_child(box)

	var actors := EncounterEngine.eligible_actors(_selected_choice, Game.party)
	var grid := UIKit.hbox(10)
	grid.alignment = BoxContainer.ALIGNMENT_BEGIN
	for actor in actors:
		var wrapper := UIKit.vbox(4)
		var card := CharacterCard.new(actor, true)
		card.highlight_stat = stat
		card.chosen.connect(_resolve)
		wrapper.add_child(card)
		var estimate := _estimate(_selected_choice, actor)
		var chance_row := UIKit.hbox(6)
		chance_row.alignment = BoxContainer.ALIGNMENT_CENTER
		chance_row.add_child(UIKit.chip("%d%% likely" % estimate, _chance_color(estimate)))
		wrapper.add_child(chance_row)
		grid.add_child(wrapper)
	_body.add_child(grid)

	if actors.is_empty():
		_body.add_child(UIKit.paragraph("Nobody can do this. That was the risk.", 16, Palette.DANGER))

	var back := UIKit.button("PICK A DIFFERENT ACTION", 16)
	back.pressed.connect(func() -> void:
		Audio.play("click")
		_state = State.CHOICES
		_render())
	_body.add_child(back)


## --- Result --------------------------------------------------------------

func _resolve(actor: Prisoner) -> void:
	if actor == null and not bool(_selected_choice.get("auto", false)):
		actor = EncounterEngine.best_actor(_selected_choice, Game.party)
	_report = Game.resolve_choice(_selected_choice, actor)
	_state = State.RESULT
	_render()


func _render_result() -> void:
	var check: Variant = _report.get("result")
	var actor: Variant = _report.get("actor")

	if check != null:
		var panel := CheckPanel.new(check as CheckResult)
		_body.add_child(panel)

	var outcome: Dictionary = _report.get("outcome", {})
	var tier_color: Color = Palette.TEAL
	if check != null:
		tier_color = (check as CheckResult).tier_color()

	var story := UIKit.panel(Palette.PANEL, Palette.with_alpha(tier_color, 0.55), 14)
	var v := UIKit.vbox(8)
	story.add_child(v)

	var head := UIKit.hbox(12)
	if actor != null:
		var portrait := CharacterPortrait.new()
		portrait.setup(actor as Prisoner, _expression_for(check))
		portrait.show_background = false
		portrait.custom_minimum_size = Vector2(76, 92)
		head.add_child(portrait)
	var text_col := UIKit.vbox(6)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(UIKit.paragraph(str(outcome.get("text", "Nothing much happens.")), 18, Palette.TEXT))
	var quip := str(_report.get("quip", ""))
	if not quip.is_empty():
		text_col.add_child(UIKit.paragraph(quip, 15, Palette.ACCENT))
	head.add_child(text_col)
	v.add_child(head)
	_body.add_child(story)
	UIKit.pop_in(story, 0.3, 0.55)

	var changes: Array = _report.get("changes", [])
	if not changes.is_empty():
		_body.add_child(changes_panel(changes))

	for report in _report.get("catches", []):
		_body.add_child(_catch_panel(report))

	var over := Game.check_run_over()
	if over.is_empty():
		var button := UIKit.primary_button("CONTINUE", 19)
		button.pressed.connect(_finish_room)
		_body.add_child(button)
	else:
		Audio.play("defeat")
		var button := UIKit.primary_button("SEE THE DAMAGE", 19)
		button.pressed.connect(func() -> void: go("summary"))
		_body.add_child(button)


func _expression_for(check: Variant) -> String:
	if check == null:
		return "idle"
	var c := check as CheckResult
	match c.tier:
		CheckResult.Tier.CRIT_SUCCESS: return "happy"
		CheckResult.Tier.SUCCESS: return "happy"
		CheckResult.Tier.CRIT_FAILURE: return "out"
		_: return "sad"


func _catch_panel(report: Dictionary) -> Control:
	Audio.play("catch")
	var box := UIKit.panel(Palette.darken(Palette.DANGER_DARK, 0.35), Palette.DANGER, 14)
	var v := UIKit.vbox(6)
	box.add_child(v)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.chip("THE CATCH", Palette.DANGER))
	head.add_child(UIKit.label(str(report.get("powerup_name", "")), 17, Palette.TEXT))
	head.add_child(UIKit.spacer())
	v.add_child(head)
	v.add_child(UIKit.paragraph(str(report.get("reveal_text", "")), 16, Palette.TEXT))
	var changes: Array = report.get("changes", [])
	for c in changes:
		v.add_child(UIKit.label(str(c.get("text", "")), 14, Palette.DANGER))
	return box


## Used only when the crew qualifies for nothing in the room.
func _walk_away() -> void:
	Audio.play("failure")
	Game.add_heat(Game.scale_generated_heat(5))
	Game.log_line("The crew stood in the room doing nothing, which is not free.")
	if Game.check_run_over().is_empty():
		_finish_room()
	else:
		go("summary")


func _finish_room() -> void:
	Audio.play("click")
	Game.clear_current_room()
	SaveSystem.save_run()
	if Game.room_awards_powerup():
		go("powerup")
	else:
		go("map")
