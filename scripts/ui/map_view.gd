class_name MapView
extends Control
## Draws the prison as a journey: cell block on the left, outer wall on the
## right, connections as pipes running between them.
##
## Connection lines are drawn in _draw(); each room is a child node widget
## positioned in _layout(), so hit-testing and hover states are free.

signal room_chosen(node_id: String)

const NODE_W := 148.0
const NODE_H := 118.0
const GAP_X := 44.0
const GAP_Y := 26.0

var _widgets: Dictionary = {}
var _reachable: Array = []


func _ready() -> void:
	_reachable = Game.reachable_nodes()
	_build_nodes()
	resized.connect(_layout)
	_layout()


func required_size() -> Vector2:
	var layers: Array = Game.map.get("layers", [])
	var widest := 1
	for row in layers:
		widest = maxi(widest, (row as Array).size())
	return Vector2(
		layers.size() * (NODE_W + GAP_X) + GAP_X,
		widest * (NODE_H + GAP_Y) + GAP_Y * 2 + 40)


func _build_nodes() -> void:
	for child in get_children():
		child.queue_free()
	_widgets.clear()

	var nodes: Dictionary = Game.map.get("nodes", {})
	for node_id in nodes.keys():
		var widget := _make_node_widget(nodes[node_id])
		add_child(widget)
		_widgets[node_id] = widget

	custom_minimum_size = required_size()


func _make_node_widget(node_data: Dictionary) -> Control:
	var node_id := str(node_data.get("id", ""))
	var room: Dictionary = Content.get_room(str(node_data.get("room_id", "")))
	var state := str(node_data.get("state", "locked"))
	var path_type := int(node_data.get("path_type", PrisonGenerator.Path.SAFE))
	var is_reachable := _reachable.has(node_id)
	var gated := not PrisonGenerator.party_can_enter(node_data, Game.party)

	var room_color := Palette.of(str(room.get("color", "#5b6478")))
	var border := Palette.BORDER
	var bg := Palette.PANEL_DARK
	var text_color := Palette.TEXT_FAINT

	if state == "cleared":
		bg = Palette.darken(room_color, 0.62)
		border = Palette.with_alpha(Palette.SUCCESS, 0.5)
		text_color = Palette.TEXT_DIM
	elif state == "current":
		bg = Palette.darken(room_color, 0.35)
		border = Palette.ACCENT
		text_color = Palette.TEXT
	elif is_reachable:
		bg = Palette.darken(room_color, 0.45)
		border = PrisonGenerator.path_color(path_type)
		text_color = Palette.TEXT

	var panel := UIKit.panel(bg, border, 12)
	# Pinned to exactly the size _layout() places it at. Without this the blurb
	# and the gate text drive the minimum width past NODE_W and the nodes
	# overlap each other and the connection lines.
	panel.custom_minimum_size = Vector2(NODE_W, NODE_H)
	panel.clip_contents = true

	var gate: Dictionary = node_data.get("gate", {})
	var tooltip := "%s\n%s" % [str(room.get("name", "?")), str(room.get("blurb", ""))]
	if not gate.is_empty():
		tooltip += "\n%s" % str(gate.get("label", ""))
	panel.tooltip_text = tooltip

	var v := UIKit.vbox(4)
	panel.add_child(v)

	var head := UIKit.hbox(6)
	head.add_child(RoomIcon.new(str(room.get("icon", "bars")), text_color))
	var title := UIKit.label(str(room.get("name", "?")), 15, text_color)
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	v.add_child(head)

	# Chips are put in a row with a spacer so they hug their text instead of
	# stretching to the full width of the node.
	var chip_row := UIKit.hbox(0)
	if bool(node_data.get("is_final", false)):
		chip_row.add_child(UIKit.chip("ESCAPE", Palette.ACCENT))
	elif state != "cleared":
		chip_row.add_child(UIKit.chip(PrisonGenerator.path_label(path_type), PrisonGenerator.path_color(path_type)))
	else:
		chip_row.add_child(UIKit.chip("CLEARED", Palette.SUCCESS))
	chip_row.add_child(UIKit.spacer())
	v.add_child(chip_row)

	if not gate.is_empty() and state != "cleared":
		var gate_label := UIKit.label(str(gate.get("label", "")), 11,
			Palette.DANGER if gated else Palette.SUCCESS)
		gate_label.clip_text = true
		v.add_child(gate_label)

	if is_reachable and state != "cleared":
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.disabled = gated
		btn.tooltip_text = tooltip
		btn.pressed.connect(func() -> void:
			Audio.play("room_move")
			room_chosen.emit(node_id))
		btn.mouse_entered.connect(func() -> void: Audio.play("hover"))
		panel.add_child(btn)
		UIKit.pop_in(panel, 0.3, 0.04 * int(node_data.get("index", 0)))
	elif state == "locked":
		panel.modulate.a = 0.42

	return panel


func _layout() -> void:
	var layers: Array = Game.map.get("layers", [])
	var nodes: Dictionary = Game.map.get("nodes", {})
	var height: float = maxf(size.y, required_size().y)

	for layer_index in range(layers.size()):
		var row: Array = layers[layer_index]
		var x := GAP_X + layer_index * (NODE_W + GAP_X)
		var block_height := row.size() * NODE_H + maxi(0, row.size() - 1) * GAP_Y
		var top := (height - block_height) * 0.5
		for i in range(row.size()):
			var node_id: String = row[i]
			if not _widgets.has(node_id):
				continue
			var widget: Control = _widgets[node_id]
			widget.position = Vector2(x, top + i * (NODE_H + GAP_Y))
			widget.size = Vector2(NODE_W, NODE_H)
			var nd: Dictionary = nodes[node_id]
			nd["_x"] = x
			nd["_y"] = top + i * (NODE_H + GAP_Y)
	queue_redraw()


func _draw() -> void:
	var nodes: Dictionary = Game.map.get("nodes", {})
	if nodes.is_empty():
		return

	for node_id in nodes.keys():
		var n: Dictionary = nodes[node_id]
		if not n.has("_x"):
			continue
		var from := Vector2(float(n["_x"]) + NODE_W, float(n["_y"]) + NODE_H * 0.5)
		for child_id in n.get("connections", []):
			var c: Dictionary = nodes.get(str(child_id), {})
			if not c.has("_x"):
				continue
			var to := Vector2(float(c["_x"]), float(c["_y"]) + NODE_H * 0.5)

			var color := Palette.with_alpha(Palette.BORDER, 0.5)
			var width := 4.0
			if str(n.get("state", "")) == "cleared" and str(c.get("state", "")) == "cleared":
				color = Palette.with_alpha(Palette.SUCCESS, 0.45)
			elif str(n.get("state", "")) == "current":
				color = Palette.with_alpha(PrisonGenerator.path_color(int(c.get("path_type", 0))), 0.85)
				width = 6.0

			# An elbow rather than a diagonal, so it reads as prison plumbing.
			var mid_x := (from.x + to.x) * 0.5
			var pts := PackedVector2Array([
				from, Vector2(mid_x, from.y), Vector2(mid_x, to.y), to])
			draw_polyline(pts, color, width, true)
			draw_circle(to, width * 0.9, color)
