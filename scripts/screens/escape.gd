extends Screen
## The climax. Pick a route, then run its three checks, choosing who takes each
## one. Two passes out of three gets you over the wall.

enum State { ROUTE, ACTOR, STEP_RESULT, DONE }

var _state: int = State.ROUTE
var _route: Dictionary = {}
var _step_index: int = 0
var _results: Array = []
var _last_check: CheckResult
var _last_changes: Array = []
var _escape_catches: Array = []
var _body: VBoxContainer


func _init() -> void:
	show_hud = true
	music_mood = "escape"


func build() -> void:
	Audio.play_music("escape")
	var column := page("THE ESCAPE", "Three things have to go right. Two of them will do.")

	var scroller := UIKit.scroll()
	column.add_child(scroller)
	_body = UIKit.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(_body)
	_render()


func _clear_body() -> void:
	# Detach before freeing: queue_free() is deferred, so leaving the outgoing
	# nodes parented would make the container lay out both sets for a frame.
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


func _render() -> void:
	_clear_body()
	match _state:
		State.ROUTE: _render_routes()
		State.ACTOR: _render_actor_picker()
		State.STEP_RESULT: _render_step_result()
		State.DONE: _render_done()


## --- Route selection -----------------------------------------------------

func _render_routes() -> void:
	_body.add_child(UIKit.label("CHOOSE HOW THIS ENDS", 14, Palette.ACCENT))

	var row := UIKit.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var routes := EscapeSystem.routes()
	for i in range(routes.size()):
		var card := _route_card(routes[i])
		row.add_child(card)
		UIKit.pop_in(card, 0.3, 0.07 * i)
	_body.add_child(row)


func _route_card(route: Dictionary) -> Control:
	var color := Palette.of(str(route.get("color", "#5f7ba8")))
	var fit := EscapeSystem.route_fit(route, Game.party)

	var box := UIKit.panel(Palette.PANEL, Palette.with_alpha(color, 0.7), 14)
	# Four cards have to share the width, so they divide it evenly rather than
	# each taking whatever its longest line needs.
	box.custom_minimum_size = Vector2(236, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(8)
	box.add_child(v)

	var head := UIKit.hbox(8)
	head.add_child(RoomIcon.new(str(route.get("icon", "star")), color))
	var route_name := UIKit.label(str(route.get("name", "?")), 20, Palette.TEXT)
	route_name.clip_text = true
	route_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(route_name)
	v.add_child(head)

	v.add_child(UIKit.paragraph(str(route.get("tagline", "")), 14, Palette.TEXT_DIM))

	v.add_child(UIKit.section("Suits", color))
	var stats_row := HFlowContainer.new()
	stats_row.add_theme_constant_override("h_separation", 6)
	stats_row.add_theme_constant_override("v_separation", 4)
	for stat in route.get("best_stats", []):
		stats_row.add_child(UIKit.chip(str(stat).to_upper(), Palette.stat_color(str(stat))))
	v.add_child(stats_row)

	v.add_child(UIKit.stat_row("Crew fit", "%d%%" % fit, _fit_color(fit)))

	var scaling := float(route.get("heat_scaling", 0.0))
	var heat_note := "Heat does not affect this route."
	if scaling > 0.0:
		heat_note = "Gets harder as Heat rises."
	elif scaling < 0.0:
		heat_note = "Gets EASIER as Heat rises."
	v.add_child(UIKit.paragraph(heat_note, 13, Palette.WARN if scaling > 0.0 else Palette.SUCCESS))

	v.add_child(UIKit.section("The plan", color))
	var steps := UIKit.vbox(2)
	for i in range(EscapeSystem.step_count(route)):
		var s := EscapeSystem.step(route, i)
		var line := UIKit.hbox(6)
		line.add_child(UIKit.label("%d." % (i + 1), 13, Palette.TEXT_FAINT))
		# Clipped, so a long step name cannot widen the card - and through it the
		# whole window, which would drag the status bar off the right edge.
		var step_title := UIKit.label(str(s.get("title", "")), 13, Palette.TEXT_DIM)
		step_title.clip_text = true
		step_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_title.tooltip_text = str(s.get("title", ""))
		line.add_child(step_title)
		line.add_child(UIKit.chip(str(s.get("stat", "")).to_upper(), Palette.stat_color(str(s.get("stat", "luck")))))
		steps.add_child(line)
	v.add_child(steps)

	var take := UIKit.primary_button("GO", 18)
	take.pressed.connect(func() -> void:
		Audio.play("confirm")
		_choose_route(route))
	v.add_child(take)
	return box


func _fit_color(fit: int) -> Color:
	if fit >= 75:
		return Palette.SUCCESS
	if fit >= 55:
		return Palette.ACCENT
	return Palette.DANGER


func _choose_route(route: Dictionary) -> void:
	_route = route
	Game.escape_route_id = str(route.get("id", ""))
	Game.phase = Game.Phase.ESCAPE
	_escape_catches = Game.fire_catches("at_escape")
	_step_index = 0
	_results.clear()
	_state = State.ACTOR
	_render()


## --- Per-step actor picker -----------------------------------------------

func _render_actor_picker() -> void:
	for report in _escape_catches:
		_body.add_child(_catch_panel(report))
	_escape_catches.clear()

	var step_def := EscapeSystem.step(_route, _step_index)
	var stat := str(step_def.get("stat", "luck"))

	_body.add_child(_progress_strip())

	var box := UIKit.panel(Palette.PANEL, Palette.with_alpha(Palette.of(str(_route.get("color", "#5f7ba8"))), 0.7), 14)
	var v := UIKit.vbox(6)
	box.add_child(v)
	v.add_child(UIKit.label("STEP %d OF %d" % [_step_index + 1, EscapeSystem.step_count(_route)], 13, Palette.TEXT_FAINT))
	v.add_child(UIKit.title(str(step_def.get("title", "")), 26, Palette.TEXT))
	v.add_child(UIKit.paragraph("A %s check. Send whoever has the best shot." % stat.capitalize(), 15, Palette.stat_color(stat)))
	_body.add_child(box)

	var actors := Game.available_members()
	if actors.is_empty():
		_body.add_child(UIKit.paragraph("Nobody is standing. This is going to be brief.", 17, Palette.DANGER))
		var skip := UIKit.primary_button("WATCH IT HAPPEN", 18)
		skip.pressed.connect(func() -> void:
			_state = State.DONE
			_render())
		_body.add_child(skip)
		return

	var row := UIKit.hbox(10)
	for actor in actors:
		var wrapper := UIKit.vbox(4)
		var card := CharacterCard.new(actor, true)
		card.highlight_stat = stat
		card.chosen.connect(_run_step)
		wrapper.add_child(card)
		var preview := SkillCheck.prepare(
			actor, stat, step_def.get("tags", []),
			int(step_def.get("difficulty", 0)),
			EscapeSystem.build_situation(_route, _step_index))
		wrapper.add_child(UIKit.chip("%d%% likely" % preview.final_chance, _fit_color(preview.final_chance)))
		row.add_child(wrapper)
	_body.add_child(row)


func _progress_strip() -> Control:
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(str(_route.get("name", "")).to_upper(), 14, Palette.ACCENT))
	for i in range(EscapeSystem.step_count(_route)):
		var color := Palette.PANEL_HI
		if i < _results.size():
			color = Palette.SUCCESS if (_results[i] as CheckResult).is_success() else Palette.DANGER
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(56, 8)
		pip.add_theme_stylebox_override("panel", UIKit.stylebox(color, Palette.BORDER, 4, 0))
		row.add_child(pip)
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label("Need %d of %d" % [
		int(_route.get("required_passes", 2)), EscapeSystem.step_count(_route)], 13, Palette.TEXT_DIM))
	return row


func _run_step(actor: Prisoner) -> void:
	_last_check = EscapeSystem.resolve_step(_route, _step_index, actor)
	if _last_check == null:
		_state = State.DONE
		_render()
		return
	_last_changes = EscapeSystem.apply_step_outcome(_route, _step_index, actor, _last_check)
	_results.append(_last_check)
	_state = State.STEP_RESULT
	_render()


func _render_step_result() -> void:
	var step_def := EscapeSystem.step(_route, _step_index)
	_body.add_child(_progress_strip())
	_body.add_child(CheckPanel.new(_last_check))

	var text := str(step_def.get("success", "")) if _last_check.is_success() else str(step_def.get("failure", ""))
	var box := UIKit.panel(Palette.PANEL, Palette.with_alpha(_last_check.tier_color(), 0.6), 14)
	var v := UIKit.vbox(6)
	box.add_child(v)
	v.add_child(UIKit.paragraph(text, 18, Palette.TEXT))
	_body.add_child(box)
	UIKit.pop_in(box, 0.3, 0.55)

	if not _last_changes.is_empty():
		_body.add_child(changes_panel(_last_changes))

	_step_index += 1
	var more := _step_index < EscapeSystem.step_count(_route)
	var button := UIKit.primary_button("NEXT STEP" if more else "THE MOMENT OF TRUTH", 19)
	button.pressed.connect(func() -> void:
		Audio.play("click")
		_state = State.ACTOR if more else State.DONE
		_render())
	_body.add_child(button)


## --- Verdict -------------------------------------------------------------

func _render_done() -> void:
	var verdict := EscapeSystem.evaluate(_route, _results)
	var escaped := bool(verdict["escaped"])

	Game.finish_run(str(verdict["result"]), str(verdict["headline"]), str(verdict["detail"]))
	SaveSystem.delete_run()

	Audio.play("victory" if escaped else "defeat")
	Audio.play_music("victory" if escaped else "defeat")

	var box := UIKit.panel(Palette.PANEL, Palette.SUCCESS if escaped else Palette.DANGER, 16)
	var v := UIKit.vbox(10)
	box.add_child(v)
	v.add_child(UIKit.title(str(verdict["headline"]), 40, Palette.SUCCESS if escaped else Palette.DANGER))
	v.add_child(UIKit.paragraph(str(verdict["detail"]), 18, Palette.TEXT))
	v.add_child(UIKit.paragraph("%d of %d steps went your way. You needed %d." % [
		int(verdict["passes"]), EscapeSystem.step_count(_route), int(verdict["needed"])], 15, Palette.TEXT_DIM))
	_body.add_child(box)
	UIKit.pop_in(box, 0.4)

	var crew := UIKit.hbox(10)
	crew.alignment = BoxContainer.ALIGNMENT_CENTER
	for member in Game.party:
		var frame := UIKit.panel(Palette.PANEL_DARK, Palette.BORDER, 12)
		var portrait := CharacterPortrait.new()
		var p: Prisoner = member
		portrait.setup(p, "happy" if escaped and p.is_available() else CharacterPortrait.expression_for_status(p.status))
		portrait.animate = true
		portrait.custom_minimum_size = Vector2(110, 136)
		frame.add_child(portrait)
		crew.add_child(frame)
	_body.add_child(crew)

	var onward := UIKit.primary_button("RUN SUMMARY", 20)
	onward.pressed.connect(func() -> void:
		Audio.play("click")
		go("summary"))
	_body.add_child(onward)


func _catch_panel(report: Dictionary) -> Control:
	Audio.play("catch")
	var box := UIKit.panel(Palette.darken(Palette.DANGER_DARK, 0.35), Palette.DANGER, 14)
	var v := UIKit.vbox(6)
	box.add_child(v)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.chip("THE CATCH, AT THE WORST MOMENT", Palette.DANGER))
	head.add_child(UIKit.label(str(report.get("powerup_name", "")), 17, Palette.TEXT))
	head.add_child(UIKit.spacer())
	v.add_child(head)
	v.add_child(UIKit.paragraph(str(report.get("reveal_text", "")), 16, Palette.TEXT))
	for c in report.get("changes", []):
		v.add_child(UIKit.label(str(c.get("text", "")), 14, Palette.DANGER))
	return box
