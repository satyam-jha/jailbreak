#!/usr/bin/env python3
"""Balance and data-integrity simulator for Jailbreak.

This is a deliberate second implementation of the rules in scripts/systems/,
written in Python so that content can be checked and tuned without launching
the engine. It reads the same files in data/, so a typo, an unwinnable event or
a badly skewed win rate shows up here in a second rather than after a playtest.

    python3 tools/balance_sim.py            # 4000 runs, summary
    python3 tools/balance_sim.py --runs 500 --verbose

It approximates the game rather than replacing it: the authoritative rules are
the GDScript. If you change a formula in scripts/systems/skill_check.gd, change
the mirror in check_chance() below or this tool will quietly start lying.
"""

import argparse
import json
import os
import random
import statistics
import sys
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

STATS = ["strength", "intelligence", "stealth", "charisma", "luck", "speed"]

# Mirrors of the constants in the GDScript.
BASE_CHANCE = int(os.environ.get("JB_BASE", 34))
PER_POINT, PER_DIFFICULTY = 8, 8
MIN_CHANCE = 5
MAX_CHANCE = int(os.environ.get("JB_MAX", 85))
ESCAPE_EXTRA = int(os.environ.get("JB_ESCDIFF", 0))
STAT_CAP = int(os.environ.get("JB_STATCAP", 20))
HEAT_RELIEF_SCALE = float(os.environ.get("JB_RELIEF", 0.5))
CRIT_FRACTION = 0.15
LUCK_WEIGHT = 1.5
HEAT_PRESSURE_AT_MAX = 15
PARTY_SIZE, CANDIDATES, OFFER_COUNT = 5, 3, 5
STARTING_HEAT, STARTING_MONEY, MAX_HEAT = 10, 60, 100
MIN_LAYERS, MAX_LAYERS = 10, 13
HEAT_DRIFT_BASE = float(os.environ.get("JB_DRIFT", 3))
HEAT_DRIFT_PER_LAYER = float(os.environ.get("JB_DRIFTL", 0.8))
SAFE, RISKY, SECRET = 0, 1, 2


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as handle:
        return json.load(handle)


class Content:
    def __init__(self):
        chars = load("characters.json")
        self.characters = chars["characters"]
        self.traits = {t["id"]: t for t in load("traits.json")["traits"]}
        rooms = load("rooms.json")
        self.rooms = {r["id"]: r for r in rooms["rooms"]}
        self.room_order = [r["id"] for r in rooms["rooms"]]
        self.heat_bands = rooms["heat_bands"]
        self.events = load("events.json")["events"]
        self.powerups = load("powerups.json")["powerups"]
        self.catches = load("catches.json")["catches"]
        self.statuses = {s["id"]: s for s in load("status_effects.json")["statuses"]}
        self.synergies = load("synergies.json")["synergies"]
        self.routes = load("escape_routes.json")["routes"]


C = Content()


class Prisoner:
    def __init__(self, definition):
        self.id = definition["id"]
        self.name = definition["name"]
        self.base = dict(definition["stats"])
        self.bonus = {s: 0 for s in STATS}
        self.traits = list(definition["traits"])
        self.tags = list(definition.get("tags", []))
        self.max_health = definition["max_health"]
        self.health = self.max_health
        self.status = "healthy"
        self.status_rooms = -1

    def stat(self, key):
        mods = C.statuses[self.status].get("stat_mods", {})
        return max(1, min(STAT_CAP, self.base.get(key, 5) + self.bonus.get(key, 0) + mods.get(key, 0)))

    def available(self):
        return self.status != "unconscious" and self.health > 0

    def all_tags(self):
        out = list(self.tags)
        for t in self.traits:
            for tag in C.traits[t].get("tags", []):
                if tag not in out:
                    out.append(tag)
        return out

    def damage(self, amount, global_mod=0):
        if amount <= 0:
            return 0
        reduction = global_mod + sum(
            e.get("value", 0)
            for t in self.traits
            for e in C.traits[t].get("effects", [])
            if e.get("type") == "damage_taken"
        )
        actual = max(1, amount + reduction)
        self.health = max(0, self.health - actual)
        if self.health == 0:
            self.set_status("unconscious")
        elif self.status == "healthy":
            self.set_status("injured")
        return actual

    def heal(self, amount):
        before = self.health
        self.health = min(self.max_health, self.health + amount)
        if self.health > 0 and self.status == "unconscious":
            self.status, self.status_rooms = "injured", -1
        if self.health >= self.max_health and self.status == "injured":
            self.set_status("healthy")
        return self.health - before

    def set_status(self, status):
        if self.status == "unconscious" and status not in ("healthy", "injured"):
            return
        self.status = status
        self.status_rooms = C.statuses.get(status, {}).get("duration", -1)

    def tick(self):
        if self.status_rooms > 0:
            self.status_rooms -= 1
            if self.status_rooms == 0:
                self.status = "injured" if self.health < self.max_health else "healthy"
                self.status_rooms = -1


def effect_applies(effect, contexts, heat):
    if "min_heat" in effect and heat < effect["min_heat"]:
        return False
    if "max_heat" in effect and heat > effect["max_heat"]:
        return False
    required = effect.get("contexts", [])
    return not required or any(c in contexts for c in required)


class Run:
    """One playthrough."""

    def __init__(self, rng, issues):
        self.rng = rng
        self.issues = issues
        self.heat = STARTING_HEAT
        self.money = STARTING_MONEY
        self.party = []
        self.powerups = []
        self.used_events = []
        self.rooms_cleared = 0
        self.criticals = 0
        self.disasters = 0
        self.catches_fired = 0
        self.events_seen = []
        self.result = ""
        self.peak_heat = STARTING_HEAT
        self.last_room_won = True

    # --- resources -------------------------------------------------------
    def add_heat(self, delta):
        self.heat = max(0, min(MAX_HEAT, self.heat + delta))
        self.peak_heat = max(self.peak_heat, self.heat)

    def add_money(self, delta):
        self.money = max(0, self.money + delta)

    def offer_effects(self, offer):
        if offer.get("cancelled"):
            return []
        out = list(offer["def"].get("effects", []))
        if offer.get("revealed"):
            out += offer.get("catch", {}).get("effects", [])
        return out

    def scale_heat(self, amount, actor=None):
        if amount <= 0:
            return amount
        multiplier = 1.0
        if actor:
            for t in actor.traits:
                for e in C.traits[t].get("effects", []):
                    if e.get("type") == "heat_multiplier":
                        multiplier += e.get("value", 0.0)
        for offer in self.powerups:
            for e in self.offer_effects(offer):
                if e.get("type") == "heat_multiplier":
                    multiplier += e.get("value", 0.0)
        return max(1, round(amount * max(0.2, min(2.0, multiplier))))

    def damage_modifier(self):
        return sum(
            e.get("value", 0)
            for offer in self.powerups
            for e in self.offer_effects(offer)
            if e.get("type") == "damage_taken"
        )

    # --- synergies -------------------------------------------------------
    def tag_counts(self):
        counts = Counter()
        for member in self.party:
            for tag in member.all_tags():
                counts[tag] += 1
        return counts

    def active_synergies(self):
        counts = self.tag_counts()
        out = []
        for s in C.synergies:
            if "requires_distinct_tags" in s:
                if all(counts[tag] >= 1 for tag in s["requires_distinct_tags"]):
                    out.append(s)
            elif any(counts[tag] >= s.get("count", 1) for tag in s.get("requires_tags", [])):
                out.append(s)
        return out

    # --- the skill check -------------------------------------------------
    def situation(self, contexts):
        bonuses = []
        crit_success = crit_fail = 0
        save = 0.0

        pressure = -round((self.heat / MAX_HEAT) * HEAT_PRESSURE_AT_MAX)
        if pressure:
            bonuses.append(pressure)

        for s in self.active_synergies():
            if not s.get("contexts") or any(c in contexts for c in s["contexts"]):
                bonuses.append(s.get("bonus", 0))
            pen_ctx = s.get("penalty_contexts", [])
            if pen_ctx and any(c in contexts for c in pen_ctx):
                bonuses.append(s.get("penalty", 0))
            crit_success += s.get("crit_success_bonus", 0)
            crit_fail += s.get("crit_fail_bonus", 0)

        for offer in self.powerups:
            for e in self.offer_effects(offer):
                if not effect_applies(e, contexts, self.heat):
                    continue
                kind = e.get("type")
                if kind == "check_bonus":
                    bonuses.append(e.get("value", 0))
                elif kind == "crit_success_chance":
                    crit_success += e.get("value", 0)
                elif kind == "crit_fail_chance":
                    crit_fail += e.get("value", 0)
                elif kind == "save_chance":
                    save += e.get("value", 0)
        return {"bonuses": bonuses, "crit_success": crit_success, "crit_fail": crit_fail, "save": save}

    def trait_mods(self, actor, contexts):
        bonuses, crit_success, crit_fail, save = [], 0, 0, 0.0
        for trait_id in actor.traits:
            for e in C.traits[trait_id].get("effects", []):
                if not effect_applies(e, contexts, self.heat):
                    continue
                kind = e.get("type")
                if kind == "stat_bonus":
                    bonuses.append(e.get("value", 0) * PER_POINT)
                elif kind == "check_bonus":
                    bonuses.append(e.get("value", 0))
                elif kind == "crit_success_chance":
                    crit_success += e.get("value", 0)
                elif kind == "crit_fail_chance":
                    crit_fail += e.get("value", 0)
                elif kind == "save_chance":
                    save += e.get("value", 0)
        return bonuses, crit_success, crit_fail, save

    def check(self, actor, stat, contexts, difficulty):
        chance = BASE_CHANCE + (actor.stat(stat) - 5) * PER_POINT - difficulty * PER_DIFFICULTY
        if stat != "luck":
            chance += round((actor.stat("luck") - 5) * LUCK_WEIGHT)

        t_bonuses, t_crit_s, t_crit_f, t_save = self.trait_mods(actor, contexts)
        chance += sum(t_bonuses)

        sit = self.situation(contexts)
        chance += sum(sit["bonuses"])

        final = max(MIN_CHANCE, min(MAX_CHANCE, round(chance)))
        crit_success_at = max(0, min(final, round(final * CRIT_FRACTION) + sit["crit_success"] + t_crit_s))
        crit_fail_at = max(final + 1, min(101, 100 - round((100 - final) * CRIT_FRACTION) - sit["crit_fail"] - t_crit_f + 1))

        roll = self.rng.randint(1, 100)
        if roll <= crit_success_at:
            tier = "crit_success"
        elif roll <= final:
            tier = "success"
        elif roll >= crit_fail_at:
            tier = "crit_failure"
        else:
            tier = "failure"

        save_chance = sit["save"] + t_save
        if tier == "failure" and save_chance > 0 and self.rng.random() * 100 < save_chance:
            tier = "success"

        if tier in ("crit_success", "crit_failure"):
            self.criticals += 1
        if tier == "crit_failure":
            self.disasters += 1
        return tier, final, roll

    # --- outcomes --------------------------------------------------------
    def apply_outcome(self, outcome, actor, reward_mult=1.0):
        if "heat" in outcome:
            delta = outcome["heat"]
            if delta > 0:
                self.add_heat(self.scale_heat(delta, actor))
            else:
                self.add_heat(-max(1, round(-delta * HEAT_RELIEF_SCALE)))
        if "money" in outcome:
            delta = outcome["money"]
            self.add_money(round(delta * reward_mult) if delta > 0 else delta)
        if "damage" in outcome and actor:
            actor.damage(outcome["damage"], self.damage_modifier())
        if "heal" in outcome:
            for m in self.party:
                m.heal(outcome["heal"])
        if "status" in outcome and actor:
            actor.set_status(outcome["status"])

    def apply_trait_reactions(self, actor, tier, contexts):
        succeeded = tier in ("success", "crit_success")
        for trait_id in actor.traits:
            for e in C.traits[trait_id].get("effects", []):
                if not effect_applies(e, contexts, self.heat):
                    continue
                rolled = "chance" not in e or self.rng.random() * 100 < e["chance"]
                kind = e.get("type")
                if kind == "money_on_success" and succeeded and rolled:
                    self.add_money(e.get("value", 0))
                elif kind == "money_on_fail" and not succeeded and rolled:
                    self.add_money(e.get("value", 0))
                elif kind == "heat_on_success" and succeeded:
                    self.add_heat(self.scale_heat(e.get("value", 0), actor))
                elif kind == "heat_on_fail" and not succeeded:
                    self.add_heat(self.scale_heat(e.get("value", 0), actor))
                elif kind == "grow_stat":
                    wanted = e.get("on", "success")
                    hit = (wanted == "success" and succeeded) or (wanted == "failure" and not succeeded)
                    if hit and rolled:
                        actor.bonus[e["stat"]] = actor.bonus.get(e["stat"], 0) + e.get("value", 1)


def build_prison(run):
    rng = run.rng
    layer_count = rng.randint(MIN_LAYERS, MAX_LAYERS)
    pool = [r for r in C.room_order if r != "outer_wall"]
    rng.shuffle(pool)
    pool = pool + pool

    nodes, layers, index, cursor = {}, [], 0, 0

    def make(room_id, layer, i, path):
        nonlocal index
        node_id = "n%d" % index
        index += 1
        room = C.rooms[room_id]
        node = {
            "id": node_id, "room_id": room_id, "layer": layer, "index": i, "path": path,
            "connections": [], "reward": 1.0, "extra_difficulty": 0, "heat_on_enter": 0,
            "gate": {}, "is_final": False,
        }
        if path == RISKY:
            node.update(reward=1.6, extra_difficulty=1, heat_on_enter=4)
        elif path == SECRET:
            node.update(reward=2.2, extra_difficulty=-1, heat_on_enter=-4)
            affinity = room.get("affinity") or STATS
            if run.party and rng.random() < 0.4:
                holder = rng.choice(run.party)
                if holder.traits:
                    node["gate"] = {"type": "trait", "trait": rng.choice(holder.traits)}
            if not node["gate"]:
                node["gate"] = {"type": "stat", "stat": rng.choice(affinity), "value": rng.randint(7, 8)}
        nodes[node_id] = node
        return node_id

    start = make("cell_block", 0, 0, SAFE)
    layers.append([start])

    for layer in range(1, layer_count - 1):
        width = rng.randint(2, 3)
        types = [SAFE, RISKY]
        if width >= 3:
            types.append(SECRET if rng.random() < 0.45 else RISKY)
        rng.shuffle(types)
        row = []
        for i in range(width):
            row.append(make(pool[cursor % len(pool)], layer, i, types[i]))
            cursor += 1
        layers.append(row)

    final = make("outer_wall", layer_count - 1, 0, SAFE)
    nodes[final]["is_final"] = True
    layers.append([final])

    for i in range(len(layers) - 1):
        current, following = layers[i], layers[i + 1]
        for child in following:
            parent = rng.choice(current)
            if child not in nodes[parent]["connections"]:
                nodes[parent]["connections"].append(child)
        for parent in current:
            conns = nodes[parent]["connections"]
            if not conns:
                conns.append(rng.choice(following))
            if len(following) > 1 and len(conns) < 2 and rng.random() < 0.55:
                extra = rng.choice(following)
                if extra not in conns:
                    conns.append(extra)
        for parent in current:
            conns = nodes[parent]["connections"]
            if not any(nodes[c]["path"] != SECRET for c in conns):
                for candidate in following:
                    if nodes[candidate]["path"] != SECRET:
                        conns.append(candidate)
                        break

    return {"nodes": nodes, "layers": layers, "start": start, "final": final, "layer_count": layer_count}


def validate_map(prison):
    nodes = prison["nodes"]
    seen, queue = {prison["start"]}, [prison["start"]]
    while queue:
        current = queue.pop(0)
        for child in nodes[current]["connections"]:
            if child not in seen:
                seen.add(child)
                queue.append(child)
    if prison["final"] not in seen:
        return "wall unreachable"
    if len(seen) != len(nodes):
        return "disconnected nodes"
    for node_id, node in nodes.items():
        if node_id == prison["final"]:
            continue
        if not node["connections"]:
            return "dead end at %s" % node_id
        if not any(nodes[c]["path"] != SECRET for c in node["connections"]):
            return "every exit from %s is gated" % node_id
    return ""


def can_enter(node, party):
    gate = node.get("gate")
    if not gate:
        return True
    for m in party:
        if not m.available():
            continue
        if gate["type"] == "stat" and m.stat(gate["stat"]) >= gate["value"]:
            return True
        if gate["type"] == "trait" and gate["trait"] in m.traits:
            return True
    return False


def eligible(choice, party):
    requires = choice.get("requires", {})
    out = []
    for m in party:
        if not m.available():
            continue
        if "trait" in requires and requires["trait"] not in m.traits:
            continue
        if any(m.stat(s) < v for s, v in requires.get("stat", {}).items()):
            continue
        out.append(m)
    return out


def pick_event(run, room_id):
    fresh, seen = [], []
    for e in run.events_pool:
        rooms = e.get("rooms", [])
        if rooms and room_id not in rooms and "any" not in rooms:
            continue
        if run.heat < e.get("min_heat", 0) or run.heat > e.get("max_heat", 100):
            continue
        if e.get("requires_injured") and not any(m.health < m.max_health or not m.available() for m in run.party):
            continue
        (seen if e["id"] in run.used_events else fresh).append(e)
    pool = fresh or seen
    if not pool:
        return None
    weights = [max(0.001, e.get("weight", 1)) for e in pool]
    return run.rng.choices(pool, weights=weights, k=1)[0]


def make_offers(run):
    pool = [p for p in C.powerups if p["id"] not in {o["id"] for o in run.powerups}] or list(C.powerups)
    chosen = run.rng.sample(pool, min(OFFER_COUNT, len(pool)))
    offers = [{"id": p["id"], "def": p, "catch": None, "revealed": False, "rooms": 0, "cancelled": False}
              for p in chosen]
    offers[run.rng.randrange(len(offers))]["catch"] = run.rng.choice(C.catches)
    return offers


def catch_fires(offer, event, heat):
    catch = offer.get("catch")
    if not catch or offer.get("revealed"):
        return False
    trigger = catch["trigger"]
    if trigger == "immediate":
        return event == "immediate"
    if trigger in ("next_encounter",):
        return event == "on_room_enter" and offer["rooms"] >= 1
    if trigger == "on_fail":
        return event in ("on_fail", "on_crit_fail")
    if trigger == "on_crit_fail":
        return event == "on_crit_fail"
    if trigger == "at_escape":
        return event == "at_escape"
    if trigger == "on_room_enter":
        return event == "on_room_enter"
    if trigger == "on_heat_above":
        return event == "on_room_enter" and heat >= catch.get("threshold", 100)
    if trigger == "delayed":
        return event == "on_room_enter" and offer["rooms"] >= catch.get("after", 1)
    return False


def fire_catches(run, event):
    for offer in run.powerups:
        if not catch_fires(offer, event, run.heat):
            continue
        catch = offer["catch"]
        for e in catch.get("effects", []):
            kind = e.get("type")
            if kind == "money":
                run.add_money(e.get("value", 0))
            elif kind == "heat":
                run.add_heat(e.get("value", 0))
            elif kind == "damage":
                victim = next((m for m in run.party if m.available()), run.party[0])
                victim.damage(e.get("value", 0), run.damage_modifier())
            elif kind == "status":
                victim = next((m for m in run.party if m.available()), run.party[0])
                victim.set_status(e.get("value", "scared"))
            elif kind == "stat_bonus":
                for m in run.party:
                    m.bonus[e["stat"]] = m.bonus.get(e["stat"], 0) + e.get("value", 0)
            elif kind == "cancel_powerup":
                offer["cancelled"] = True
        offer["revealed"] = True
        run.catches_fired += 1


def play(seed, issues, strategy="smart"):
    rng = random.Random(seed)
    run = Run(rng, issues)
    run.events_pool = C.events

    # Recruitment: distinct strongest stats, net-zero jitter.
    pool = list(C.characters)
    rng.shuffle(pool)
    used_best = []
    while len(run.party) < PARTY_SIZE and pool:
        candidates = []
        for _ in range(CANDIDATES):
            index = next((i for i, d in enumerate(pool)
                          if max(d["stats"], key=lambda s: d["stats"][s]) not in used_best), 0)
            if not pool:
                break
            definition = pool.pop(index)
            p = Prisoner(definition)
            if rng.random() < 0.7:
                # Mirrors CharacterFactory._apply_net_zero_jitter: the signature
                # stat is never touched and nothing is raised to within a point
                # of it, so a candidate keeps its archetype.
                signature = max(p.base, key=lambda s: p.base[s])
                signature_value = p.base[signature]
                up = down = None
                for stat in rng.sample(STATS, len(STATS)):
                    if stat == signature:
                        continue
                    if up is None and p.base[stat] < signature_value - 1 and p.base[stat] < 10:
                        up = stat
                    elif down is None and p.base[stat] > 2:
                        down = stat
                if up and down and up != down:
                    p.base[up] += 1
                    p.base[down] -= 1
            candidates.append(p)
        if not candidates:
            break
        pick = max(candidates, key=lambda c: sum(c.base.values())) if strategy == "smart" else rng.choice(candidates)
        used_best.append(max(pick.base, key=lambda s: pick.base[s]))
        run.party.append(pick)

    prison = build_prison(run)
    problem = validate_map(prison)
    if problem:
        issues["bad_map"].append("seed %d: %s" % (seed, problem))
        return run

    node = prison["nodes"][prison["start"]]
    guard = 0
    while guard < 40:
        guard += 1
        if node.get("is_final"):
            break

        options = [prison["nodes"][c] for c in node["connections"]
                   if can_enter(prison["nodes"][c], run.party)]
        if not options:
            issues["stalled"].append("seed %d: no enterable room" % seed)
            return run
        if strategy == "smart":
            # Take risk while quiet, play safe once the prison is awake.
            options.sort(key=lambda n: n["reward"], reverse=(run.heat < 55))
        node = options[0] if strategy == "smart" else rng.choice(options)

        for m in run.party:
            m.tick()
        run.add_heat(node["heat_on_enter"])
        run.add_heat(int(round(HEAT_DRIFT_BASE + node["layer"] * HEAT_DRIFT_PER_LAYER)))
        for offer in run.powerups:
            offer["rooms"] += 1
            for e in run.offer_effects(offer):
                if e.get("type") == "money_per_room":
                    run.add_money(e.get("value", 0))
                elif e.get("type") == "heat_decay":
                    run.add_heat(-e.get("value", 0))
                elif e.get("type") == "heat_per_room":
                    run.add_heat(e.get("value", 0))
        fire_catches(run, "on_room_enter")

        run.last_room_won = True
        event = pick_event(run, node["room_id"])
        if event:
            run.used_events.append(event["id"])
            run.events_seen.append(event["id"])
            usable = [c for c in event["choices"]
                      if c.get("cost_money", 0) <= run.money and eligible(c, run.party)]
            if not usable:
                issues["no_choice"].append("seed %d: %s" % (seed, event["id"]))
                run.add_heat(5)
            else:
                if strategy == "smart":
                    best, best_odds = None, -1
                    for choice in usable:
                        if choice.get("auto"):
                            odds = 62  # a guaranteed modest outcome
                            actor = None
                        else:
                            actors = eligible(choice, run.party)
                            actor = max(actors, key=lambda a: a.stat(choice["stat"]))
                            odds = run.check_preview(actor, choice, node)
                        if odds > best_odds:
                            best, best_odds, best_actor = choice, odds, actor
                    choice, actor = best, best_actor
                else:
                    choice = rng.choice(usable)
                    actors = eligible(choice, run.party)
                    actor = None if choice.get("auto") else rng.choice(actors)

                run.add_money(-choice.get("cost_money", 0))
                contexts = choice.get("tags", [])
                if choice.get("auto"):
                    run.apply_outcome(choice["success"], actor, node["reward"])
                else:
                    tier, _, _ = run.check(actor, choice["stat"], contexts,
                                           choice.get("difficulty", 0) + node["extra_difficulty"])
                    run.apply_trait_reactions(actor, tier, contexts)
                    run.apply_outcome(choice.get(tier, choice["failure"]), actor, node["reward"])
                    run.last_room_won = tier in ("success", "crit_success")
                    if tier in ("failure", "crit_failure"):
                        fire_catches(run, "on_crit_fail" if tier == "crit_failure" else "on_fail")

        if not any(m.available() for m in run.party):
            run.result = "disaster"
            return run
        if run.heat >= MAX_HEAT:
            downed = sum(1 for m in run.party if not m.available())
            run.result = "disaster" if downed >= 3 else "caught"
            return run

        run.rooms_cleared += 1

        if not run.last_room_won:
            continue
        offers = make_offers(run)
        if strategy == "smart":
            taken = max(offers, key=lambda o: {"rare": 3, "uncommon": 2}.get(o["def"]["rarity"], 1))
        else:
            taken = rng.choice(offers)
        for e in taken["def"].get("effects", []):
            kind = e.get("type")
            if kind == "stat_bonus":
                targets = [rng.choice(run.party)] if taken["def"].get("target") == "one" else run.party
                for m in targets:
                    m.bonus[e["stat"]] = m.bonus.get(e["stat"], 0) + e.get("value", 0)
            elif kind == "max_health":
                for m in run.party:
                    m.max_health += e.get("value", 0)
                    m.health = min(m.max_health, m.health + max(0, e.get("value", 0)))
            elif kind == "heal":
                for m in run.party:
                    m.heal(e.get("value", 0))
            elif kind == "revive":
                for m in run.party:
                    if m.status == "unconscious":
                        m.health = max(1, m.max_health // 2)
                        m.set_status("injured")
            elif kind == "money":
                run.add_money(e.get("value", 0))
            elif kind == "heat":
                run.add_heat(e.get("value", 0))
        run.powerups.append(taken)
        fire_catches(run, "immediate")

    else:
        issues["stalled"].append("seed %d: never reached the wall" % seed)
        return run

    # The escape.
    fire_catches(run, "at_escape")
    if strategy == "smart":
        route = max(C.routes, key=lambda r: sum(
            max((m.stat(s) for m in run.party if m.available()), default=0) for s in r["best_stats"]))
    else:
        route = rng.choice(C.routes)

    escape_bonus = sum(e.get("value", 0) for offer in run.powerups
                       for e in run.offer_effects(offer) if e.get("type") == "escape_bonus")
    scaling = route.get("heat_scaling", 0.0)
    passes = 0
    for step in route["steps"]:
        available = [m for m in run.party if m.available()]
        if not available:
            break
        actor = max(available, key=lambda m: m.stat(step["stat"]))
        contexts = step.get("tags", [])
        sit = run.situation(contexts)
        sit["bonuses"].append(-round(run.heat * scaling))
        sit["bonuses"].append(escape_bonus)
        t_bonuses, t_cs, t_cf, t_save = run.trait_mods(actor, contexts)
        chance = (BASE_CHANCE + (actor.stat(step["stat"]) - 5) * PER_POINT
                  - (step.get("difficulty", 0) + ESCAPE_EXTRA) * PER_DIFFICULTY
                  + (round((actor.stat("luck") - 5) * LUCK_WEIGHT) if step["stat"] != "luck" else 0)
                  + sum(t_bonuses) + sum(sit["bonuses"]))
        final = max(MIN_CHANCE, min(MAX_CHANCE, round(chance)))
        roll = rng.randint(1, 100)
        won = roll <= final
        if not won and (sit["save"] + t_save) > 0 and rng.random() * 100 < sit["save"] + t_save:
            won = True
        if won:
            passes += 1
            run.add_heat(-2)
        else:
            actor.damage(2, run.damage_modifier())
            run.add_heat(run.scale_heat(12, actor))

    escaped = passes >= route.get("required_passes", 2) and any(m.available() for m in run.party)
    if escaped:
        run.result = "escaped"
    elif not any(m.available() for m in run.party) or passes == 0:
        run.result = "disaster"
    else:
        run.result = "caught"
    run.route = route["id"]
    return run


def _check_preview(self, actor, choice, node):
    """Best-guess odds for a choice, used by the 'smart' strategy."""
    contexts = choice.get("tags", [])
    difficulty = choice.get("difficulty", 0) + node["extra_difficulty"]
    chance = BASE_CHANCE + (actor.stat(choice["stat"]) - 5) * PER_POINT - difficulty * PER_DIFFICULTY
    if choice["stat"] != "luck":
        chance += round((actor.stat("luck") - 5) * LUCK_WEIGHT)
    t_bonuses, _, _, _ = self.trait_mods(actor, contexts)
    chance += sum(t_bonuses) + sum(self.situation(contexts)["bonuses"])
    return max(MIN_CHANCE, min(MAX_CHANCE, round(chance)))


Run.check_preview = _check_preview


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--runs", type=int, default=4000)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    issues = defaultdict(list)
    for strategy in ("smart", "random"):
        results = Counter()
        rooms, heats, monies, powerups, catches = [], [], [], [], []
        events = Counter()
        for i in range(args.runs):
            run = play(args.seed + i, issues, strategy)
            results[run.result or "UNFINISHED"] += 1
            rooms.append(run.rooms_cleared)
            heats.append(run.peak_heat)
            monies.append(run.money)
            powerups.append(len(run.powerups))
            catches.append(run.catches_fired)
            events.update(run.events_seen)

        total = sum(results.values())
        print("\n=== %s play, %d runs ===" % (strategy.upper(), total))
        for key, count in results.most_common():
            print("  %-12s %5d  %5.1f%%" % (key, count, 100.0 * count / total))
        print("  rooms cleared   mean %.1f   median %d   max %d" % (
            statistics.mean(rooms), statistics.median(rooms), max(rooms)))
        print("  peak Heat       mean %.1f   median %d" % (statistics.mean(heats), statistics.median(heats)))
        print("  money at end    mean %.0f" % statistics.mean(monies))
        print("  power-ups taken mean %.1f" % statistics.mean(powerups))
        print("  catches fired   mean %.2f   (%.0f%% of runs saw at least one)" % (
            statistics.mean(catches), 100.0 * sum(1 for c in catches if c) / total))
        print("  distinct events fired: %d of %d" % (len(events), len(C.events)))
        if args.verbose:
            never = [e["id"] for e in C.events if e["id"] not in events]
            if never:
                print("  events that never fired: %s" % ", ".join(never))

    print("\n=== data integrity ===")
    clean = True
    for key in ("bad_map", "stalled", "no_choice"):
        entries = issues.get(key, [])
        if entries:
            clean = False
            print("  %s: %d  e.g. %s" % (key, len(entries), entries[:3]))
        else:
            print("  %s: none" % key)
    return 0 if clean else 1


if __name__ == "__main__":
    sys.exit(main())
