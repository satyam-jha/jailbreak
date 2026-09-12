class_name CrewScene
extends Control
## A diegetic snapshot of the five prisoners inside the current room.
##
## This is intentionally code-drawn so the project keeps its tiny, asset-free
## footprint. The room is the stage; portraits become actors on that stage.
## Screens can switch the mood after an action so success/failure is visible
## before the player continues.

const HEIGHT := 224.0
const ACTOR_SIZE := Vector2(82, 104)

var room_id := "cell_block"
var crew: Array = []
var mood := "idle"
var _time := 0.0
var _room: RoomScene
var _actors: Array[CharacterPortrait] = []
var _labels: Array[Label] = []
var _base_positions: Array[Vector2] = []
var _caption: Label

var _actions := [
	"WATCHING THE DOOR",
	"CHECKING THE WALL",
	"KEEPING LOOKOUT",
	"PRETENDING TO WORK",
	"ARGUING QUIETLY",
]

var _success_actions := [
	"NICE. THAT WORKED.",
	"ACTUALLY A GOOD IDEA.",
	"THE PLAN IS WORKING.",
	"NOBODY SAW THAT.",
	"KEEP MOVING.",
]

var _failure_actions := [
	"THAT WENT BADLY.",
	"WHO HAD THAT IDEA?",
	"WE SHOULD NOT HAVE DONE THAT.",
	"EVERYONE ACT NORMAL.",
	"THIS IS FINE. IT IS NOT FINE.",
]


func _init(id: String = "cell_block", party: Array = []) -> void:
	room_id = id
	crew = party
	custom_minimum_size = Vector2(0, HEIGHT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_room = RoomScene.new(room_id)
	_room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_room)

	# Dark glass layer makes the prisoners readable against busy room art.
	var shade := ColorRect.new()
	shade.color = Palette.with_alpha(Palette.BG_DEEP, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_actors()
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.position.y = HEIGHT - 27
	_caption.size.y = 20
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_update_caption()

	resized.connect(_layout_actors)
	_layout_actors()
	set_process(true)


func set_mood(value: String) -> void:
	mood = value
	_update_caption()
	for i in range(_labels.size()):
		_labels[i].text = _action_for(i)
		_labels[i].modulate = Palette.SUCCESS if mood == "success" else Palette.DANGER if mood == "failure" else Palette.TEXT_FAINT
	for i in range(_actors.size()):
		_actors[i].expression = _expression_for(i)
	queue_redraw()


func _build_actors() -> void:
	for child in _actors:
		child.queue_free()
	_actors.clear()
	for child in _labels:
		child.queue_free()
	_labels.clear()
	_base_positions.clear()

	var count := mini(crew.size(), 5)
	for i in range(count):
		var actor := CharacterPortrait.new()
		actor.setup(crew[i], _expression_for(i))
		actor.animate = true
		actor.show_background = false
		actor.custom_minimum_size = ACTOR_SIZE
		add_child(actor)
		_actors.append(actor)

		var tag := Label.new()
		tag.text = _action_for(i)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Palette.TEXT_FAINT)
		tag.size = Vector2(120, 18)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag)
		_labels.append(tag)


func _layout_actors() -> void:
	if _actors.is_empty() or size.x < 20.0:
		return
	var count := _actors.size()
	var spacing := minf(142.0, (size.x - 30.0) / maxf(1.0, float(count)))
	var total := spacing * count
	var start := (size.x - total) * 0.5 + (spacing - ACTOR_SIZE.x) * 0.5
	_base_positions.clear()
	for i in range(count):
		var p := Vector2(start + i * spacing, 75.0)
		_base_positions.append(p)
		_actors[i].position = p
		_labels[i].position = Vector2(p.x - 19, p.y + ACTOR_SIZE.y - 2)


func _process(delta: float) -> void:
	_time += delta
	for i in range(_actors.size()):
		if i >= _base_positions.size():
			continue
		var bob := sin(_time * (1.6 + i * 0.13) + i) * 2.2
		var sway := sin(_time * 0.8 + i * 1.7) * 1.4
		var target := _base_positions[i] + Vector2(sway, bob)
		if mood == "success":
			target.y -= absf(sin(_time * 4.0 + i)) * 5.0
		elif mood == "failure":
			target.x += sin(_time * 5.0 + i) * 2.5
		_actors[i].position = _actors[i].position.lerp(target, minf(1.0, delta * 8.0))
		_actors[i].rotation = sin(_time * 0.9 + i * 2.0) * 0.018 if mood == "idle" else 0.0

	# A quick pulse around the stage sells the room as an active game space.
	if fmod(_time, 0.25) < delta:
		queue_redraw()


func _draw() -> void:
	# Stage frame.
	draw_rect(Rect2(0, 0, size.x, HEIGHT), Palette.with_alpha(Palette.BG_DEEP, 0.10), false, 2.0)
	var light_alpha := 0.10
	if mood == "success":
		light_alpha = 0.16
	elif mood == "failure":
		light_alpha = 0.20 + 0.08 * absf(sin(_time * 6.0))
	draw_circle(Vector2(size.x * 0.5, 72), 110.0, Palette.with_alpha(Palette.TEXT, light_alpha))
	# Floor shadows under each prisoner.
	for i in range(_base_positions.size()):
		var center := _base_positions[i] + Vector2(ACTOR_SIZE.x * 0.5, ACTOR_SIZE.y - 2)
		draw_ellipse(center, Vector2(32, 7), Palette.with_alpha(Palette.BG_DEEP, 0.45))


func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)


func _action_for(index: int) -> String:
	if mood == "success":
		return _success_actions[index % _success_actions.size()]
	if mood == "failure":
		return _failure_actions[index % _failure_actions.size()]
	return _actions[index % _actions.size()]


func _expression_for(index: int) -> String:
	if mood == "success":
		return "happy" if index % 3 != 2 else "idle"
	if mood == "failure":
		return "scared" if index % 2 == 0 else "worried"
	return "idle"


func _update_caption() -> void:
	if _caption == null:
		return
	match mood:
		"success": _caption.text = "THE CREW MOVES ON — FOR ONCE, THE PLAN WORKED."
		"failure": _caption.text = "THE CREW IS TRYING VERY HARD TO LOOK INNOCENT."
		_: _caption.text = "THE CREW IS IN POSITION. TRY NOT TO RUIN THIS."
