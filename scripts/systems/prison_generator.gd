class_name PrisonGenerator
extends RefCounted
## Builds the run's prison as a layered directed graph.
##
## Layer 0 is always the Cell Block and the last layer is always the Outer Wall.
## Every layer in between offers two or three rooms, and each of those is tagged
## SAFE, RISKY or SECRET. Because each node is given a parent before any extra
## edges are added, the graph is connected by construction - but validate() is
## exported anyway and the test suite runs it over hundreds of seeds.

const START_ROOM := "cell_block"
const FINAL_ROOM := "outer_wall"

const MIN_LAYERS := 10
const MAX_LAYERS := 13

enum Path { SAFE, RISKY, SECRET }


static func generate(party: Array) -> Dictionary:
	var layer_count := Rng.roll_int(MIN_LAYERS, MAX_LAYERS)
	var nodes: Dictionary = {}
	var layers: Array = []
	var next_index := 0

	var room_pool := _build_room_pool()
	var pool_cursor := 0

	# Layer 0 - always the cell block, always a single node.
	var start_id := "n%d" % next_index
	next_index += 1
	nodes[start_id] = _make_node(start_id, START_ROOM, 0, 0, Path.SAFE, party)
	layers.append([start_id])

	# Intermediate layers.
	for layer in range(1, layer_count - 1):
		var width := Rng.roll_int(2, 3)
		var row: Array = []
		var path_types := _path_types_for_width(width)
		for i in range(width):
			var room_id: String = room_pool[pool_cursor % room_pool.size()]
			pool_cursor += 1
			var node_id := "n%d" % next_index
			next_index += 1
			nodes[node_id] = _make_node(node_id, room_id, layer, i, path_types[i], party)
			row.append(node_id)
		layers.append(row)

	# Final layer - the wall.
	var final_id := "n%d" % next_index
	nodes[final_id] = _make_node(final_id, FINAL_ROOM, layer_count - 1, 0, Path.SAFE, party)
	nodes[final_id]["is_final"] = true
	layers.append([final_id])

	_connect_layers(nodes, layers)

	var map := {
		"nodes": nodes,
		"layers": layers,
		"start": start_id,
		"final": final_id,
		"layer_count": layer_count,
	}

	# Mark the opening room as reachable; everything else unlocks as you move.
	nodes[start_id]["state"] = "current"
	return map


static func _build_room_pool() -> Array:
	var pool: Array = []
	for room_id in Content.room_order:
		# Only the wall is reserved. The cell block stays in the pool so that
		# events written for it can fire more than once per run - the crew can
		# always be routed back through their own wing.
		if room_id == FINAL_ROOM:
			continue
		pool.append(room_id)
	pool = Rng.shuffled(pool)
	# Long runs can outlast the pool, so append a second shuffled pass.
	pool.append_array(Rng.shuffled(pool))
	if pool.is_empty():
		pool = [START_ROOM]
	return pool


## Every layer gets at least one safe option so no run can become unplayable.
static func _path_types_for_width(width: int) -> Array:
	var types: Array = [Path.SAFE, Path.RISKY]
	if width >= 3:
		types.append(Path.SECRET if Rng.chance(45.0) else Path.RISKY)
	return Rng.shuffled(types)


static func _make_node(node_id: String, room_id: String, layer: int, index: int, path_type: int, party: Array) -> Dictionary:
	var room: Dictionary = Content.get_room(room_id)
	var node := {
		"id": node_id,
		"room_id": room_id,
		"layer": layer,
		"index": index,
		"path_type": path_type,
		"connections": [],
		"state": "locked",          # locked -> available -> current -> cleared
		"is_final": false,
		"danger": int(room.get("danger", 1)),
		"reward_mult": 1.0,
		"extra_difficulty": 0,
		"heat_on_enter": 0,
		"gate": {},
	}
	match path_type:
		Path.RISKY:
			node["reward_mult"] = 1.6
			node["extra_difficulty"] = 1
			node["heat_on_enter"] = 4
			node["danger"] = int(node["danger"]) + 1
		Path.SECRET:
			node["reward_mult"] = 2.2
			node["extra_difficulty"] = -1
			node["heat_on_enter"] = -4
			node["gate"] = _make_gate(room, party)
		_:
			node["reward_mult"] = 1.0
	return node


## Secret paths need somebody specific. The gate is drawn from what the party
## actually has where possible, so secret routes are a reward for composition
## rather than a random tax.
static func _make_gate(room: Dictionary, party: Array) -> Dictionary:
	var affinity: Array = room.get("affinity", [])
	var stat: String = str(Rng.pick(affinity)) if not affinity.is_empty() else str(Rng.pick(Content.stat_keys))

	if not party.is_empty() and Rng.chance(40.0):
		var holder: Variant = Rng.pick(party)
		if holder is Prisoner and not (holder as Prisoner).trait_ids.is_empty():
			var trait_id := str(Rng.pick((holder as Prisoner).trait_ids))
			return {"type": "trait", "trait": trait_id, "label": "Needs: %s" % Content.trait_name(trait_id)}

	var threshold := Rng.roll_int(7, 8)
	return {"type": "stat", "stat": stat, "value": threshold, "label": "Needs: %s %d+" % [stat.capitalize(), threshold]}


static func _connect_layers(nodes: Dictionary, layers: Array) -> void:
	for i in range(layers.size() - 1):
		var current: Array = layers[i]
		var next_row: Array = layers[i + 1]

		# Guarantee every node in the next layer has at least one way in.
		for child_id in next_row:
			var parent_id: String = str(Rng.pick(current))
			var parent_conns: Array = nodes[parent_id]["connections"]
			if not parent_conns.has(child_id):
				parent_conns.append(child_id)

		# Guarantee every node in this layer leads somewhere.
		for parent_id in current:
			var conns: Array = nodes[parent_id]["connections"]
			if conns.is_empty():
				conns.append(str(Rng.pick(next_row)))
			# A second exit sometimes, so the map branches rather than funnels.
			if next_row.size() > 1 and conns.size() < 2 and Rng.chance(55.0):
				var extra: String = str(Rng.pick(next_row))
				if not conns.has(extra):
					conns.append(extra)

		# Guarantee a way forward that no party composition can lock: every node
		# must lead to at least one room that is not behind a SECRET gate.
		for parent_id in current:
			var conns2: Array = nodes[parent_id]["connections"]
			var has_open := false
			for child_id2 in conns2:
				if int((nodes[str(child_id2)] as Dictionary).get("path_type", Path.SAFE)) != Path.SECRET:
					has_open = true
					break
			if not has_open:
				for candidate_id in next_row:
					if int((nodes[str(candidate_id)] as Dictionary).get("path_type", Path.SAFE)) != Path.SECRET:
						conns2.append(candidate_id)
						break


## --- Queries used by the map screen and the test suite -------------------

static func node_at(map: Dictionary, node_id: String) -> Dictionary:
	return (map.get("nodes", {}) as Dictionary).get(node_id, {})


static func path_label(path_type: int) -> String:
	match path_type:
		Path.RISKY: return "RISKY"
		Path.SECRET: return "SECRET"
		_: return "SAFE"


static func path_color(path_type: int) -> Color:
	match path_type:
		Path.RISKY: return Color("#e08c3a")
		Path.SECRET: return Color("#9b7fd4")
		_: return Color("#5fb878")


## True when at least one available crew member satisfies the node's gate.
static func party_can_enter(node: Dictionary, party: Array) -> bool:
	var gate: Dictionary = node.get("gate", {})
	if gate.is_empty():
		return true
	for member in party:
		if not (member is Prisoner):
			continue
		var p: Prisoner = member
		if not p.is_available():
			continue
		match str(gate.get("type", "")):
			"stat":
				if p.effective_stat(str(gate.get("stat", "luck"))) >= int(gate.get("value", 99)):
					return true
			"trait":
				if p.has_trait(str(gate.get("trait", ""))):
					return true
	return false


## Breadth-first reachability check. Used by tests/test_prison.gd to prove that
## every generated map has a walkable start-to-wall route.
static func validate(map: Dictionary) -> Dictionary:
	var nodes: Dictionary = map.get("nodes", {})
	var start: String = map.get("start", "")
	var final_id: String = map.get("final", "")

	if nodes.is_empty() or not nodes.has(start) or not nodes.has(final_id):
		return {"ok": false, "reason": "map is missing a start or final node"}

	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for child in (nodes[current] as Dictionary).get("connections", []):
			if not nodes.has(child):
				return {"ok": false, "reason": "node %s points at missing node %s" % [current, child]}
			if not seen.has(child):
				seen[child] = true
				queue.append(child)

	if not seen.has(final_id):
		return {"ok": false, "reason": "the outer wall is unreachable from the cell block"}

	var orphans: Array = []
	for node_id in nodes.keys():
		if not seen.has(node_id):
			orphans.append(node_id)
	if not orphans.is_empty():
		return {"ok": false, "reason": "disconnected nodes: %s" % str(orphans)}

	for node_id in nodes.keys():
		var n: Dictionary = nodes[node_id]
		if node_id == final_id:
			continue
		var conns: Array = n.get("connections", [])
		if conns.is_empty():
			return {"ok": false, "reason": "dead end at %s" % node_id}
		# A node whose every exit is gated could strand a party that cannot
		# satisfy any of those gates, so the generator must never produce one.
		var open_exit := false
		for child_id in conns:
			if int((nodes[str(child_id)] as Dictionary).get("path_type", Path.SAFE)) != Path.SECRET:
				open_exit = true
				break
		if not open_exit:
			return {"ok": false, "reason": "every exit from %s is behind a gate" % node_id}

	return {"ok": true, "reason": "", "reachable": seen.size()}
