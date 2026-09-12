extends Node
## Autoload: Rng
##
## Every random decision in a run goes through here so that a run seed fully
## reproduces that run. Godot's Array.shuffle() and the global randi() use the
## engine's own generator and would break that, so seeded equivalents live here.

var seed_value: int = 0

var _rng := RandomNumberGenerator.new()


func start_run(explicit_seed: int = -1) -> int:
	if explicit_seed < 0:
		var boot := RandomNumberGenerator.new()
		boot.randomize()
		seed_value = boot.randi_range(100000, 9999999)
	else:
		seed_value = explicit_seed
	_rng.seed = seed_value
	_rng.state = seed_value
	return seed_value


func roll_int(from: int, to: int) -> int:
	if to < from:
		return from
	return _rng.randi_range(from, to)


func roll_float() -> float:
	return _rng.randf()


## Percentage roll. chance(75.0) is true roughly three times in four.
func chance(percent: float) -> bool:
	return _rng.randf() * 100.0 < percent


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## Seeded Fisher-Yates. Returns a new array; the input is left alone.
func shuffled(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Picks one entry using its "weight" field (default 1). Returns null if empty.
func weighted_pick(items: Array, weight_key: String = "weight") -> Variant:
	if items.is_empty():
		return null
	var total := 0.0
	for it in items:
		total += maxf(0.0, float(it.get(weight_key, 1)))
	if total <= 0.0:
		return pick(items)
	var target := _rng.randf() * total
	var running := 0.0
	for it in items:
		running += maxf(0.0, float(it.get(weight_key, 1)))
		if target <= running:
			return it
	return items[items.size() - 1]


## Picks up to `count` distinct entries by weight.
func weighted_sample(items: Array, count: int, weight_key: String = "weight") -> Array:
	var pool := items.duplicate()
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var chosen: Variant = weighted_pick(pool, weight_key)
		if chosen == null:
			break
		out.append(chosen)
		pool.erase(chosen)
	return out


func get_state() -> int:
	return int(_rng.state)


func set_state(s: int) -> void:
	_rng.state = s
