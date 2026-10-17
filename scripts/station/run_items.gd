class_name RunItems
extends RefCounted
## What waystation shops sell and abandoned stations hold during a dive. The crew buys items with
## the dive's credits (salvage is free), carries the crates aboard and fits them: guns at a gun
## console, everything else at the install hub. Hand weapons for the crew ("crew:<id>", see
## CrewWeapons) are not installed: look at the crate and press F to swap weapons. Everything only
## lasts for the current dive.
##
## Every shop stocks SHOP_SIZE items: a hull repair kit, a gun when it is given any (none while
## the gun pods carry their own heavy machine guns) and random upgrades and hand weapons. Auto
## turrets only turn up while the ship has a free turret slot.

const SHOP_SIZE := 5
## Hull integrity restored by a repair kit: this share of max hull, but at least HULL_KIT.
const HULL_KIT := 120.0
const HULL_KIT_SHARE := 0.3
## Prices rise by this share at every waystation further down.
const PRICE_STEP := 0.25
## The shops' buyback counters pay this share of an item's price there.
const SELL_SHARE := 0.25
## How much more likely an auto turret is than another upgrade while a turret slot is free.
const TURRET_WEIGHT := 3.0
## How likely each hand weapon is compared with an upgrade (shops and salvage).
const CREW_WEAPON_WEIGHT := 1.0

const SHIP_COLOR := Color(0.35, 0.8, 1.0)
const SCOUT_COLOR := Color(0.75, 0.55, 1.0)
const CREW_COLOR := Color(0.5, 1.0, 0.45)
const WEAPON_COLOR := Color(1.0, 0.3, 0.25)
const CREW_WEAPON_COLOR := Color(1.0, 0.45, 0.85)

## Item id -> name, description, base price and crate colour. Guns use ids "weapon:<id>" (Game.GUNS).
const ITEMS := {
	"hull_kit": {"name": "Hull Repair Kit", "desc": "Restores 30% hull integrity", "price": 70, "color": Color(1.0, 0.5, 0.2)},
	"autocannon": {"name": "Auto Turret", "desc": "Fills an empty turret slot and shoots aliens by itself", "price": 200, "color": Color(1.0, 0.85, 0.2)},
	"plating": {"name": "Armor Plating", "desc": "+15% max hull integrity", "price": 110, "color": SHIP_COLOR},
	"shield_cell": {"name": "Shield Cell", "desc": "+25% max shield", "price": 100, "color": SHIP_COLOR},
	"shield_coil": {"name": "Shield Coil", "desc": "+30% shield recharge, reboots 1 s faster", "price": 90, "color": SHIP_COLOR},
	"coolant": {"name": "Turret Coolant", "desc": "+15% fire rate and gun cooling for every gun and turret", "price": 120, "color": SHIP_COLOR},
	"calibration": {"name": "Targeting Module", "desc": "+20% damage for every gun and turret", "price": 130, "color": SHIP_COLOR},
	"fuel_tank": {"name": "Auxiliary Tank", "desc": "+30 fuel capacity", "price": 70, "color": SHIP_COLOR},
	"injectors": {"name": "Fuel Injectors", "desc": "-15% fuel consumption", "price": 80, "color": SHIP_COLOR},
	"thrusters": {"name": "Thruster Overhaul", "desc": "+10% speed and handling", "price": 90, "color": SHIP_COLOR},
	"mining_lens": {"name": "Mining Lens", "desc": "+25% mining speed", "price": 90, "color": SHIP_COLOR},
	"overcharge": {"name": "Laser Overcharge", "desc": "+50% mining laser damage to aliens and egg sacs", "price": 100, "color": SHIP_COLOR},
	"tractor": {"name": "Tractor Booster", "desc": "+25% mineral collection range", "price": 60, "color": SHIP_COLOR},
	"nanobots": {"name": "Repair Nanobots", "desc": "Engine and weapons slowly repair themselves", "price": 120, "color": SHIP_COLOR},
	"dampers": {"name": "Surge Dampers", "desc": "-20% damage spilling into the systems", "price": 90, "color": SHIP_COLOR},
	"scout_plating": {"name": "Scout Plating", "desc": "+30 hull for every scout", "price": 80, "color": SCOUT_COLOR},
	"scout_guns": {"name": "Scout Blasters", "desc": "+25% scout weapon damage", "price": 90, "color": SCOUT_COLOR},
	"scout_cargo": {"name": "Scout Cargo Pods", "desc": "+20 scout fuel cargo", "price": 60, "color": SCOUT_COLOR},
	"scout_thrusters": {"name": "Scout Thrusters", "desc": "+12% scout speed", "price": 70, "color": SCOUT_COLOR},
	"blaster_mod": {"name": "Blaster Overcharge", "desc": "+25% damage for every crew hand weapon", "price": 70, "color": CREW_COLOR},
	"power_tools": {"name": "Power Tools", "desc": "+30% repair speed", "price": 70, "color": CREW_COLOR},
	"crew_armor": {"name": "Crew Armor", "desc": "+20 crew health", "price": 60, "color": CREW_COLOR},
}
## General upgrades a shop can stock (ship systems, scouts, then crew gear).
const UPGRADE_POOL := ["plating", "shield_cell", "shield_coil", "coolant", "calibration", "fuel_tank",
	"injectors", "thrusters", "mining_lens", "overcharge", "tractor", "nanobots", "dampers",
	"scout_plating", "scout_guns", "scout_cargo", "scout_thrusters", "blaster_mod", "power_tools", "crew_armor"]
## Base price of each gun in a shop.
const WEAPON_PRICES := {"pulse": 60, "flak": 150, "plasma": 190, "rail": 230}


## A gun for the ship's gun consoles ("weapon:<Game.GUNS id>").
static func is_weapon(item: String) -> bool:
	return item.begins_with("weapon:")


static func weapon_of(item: String) -> String:
	return item.substr(7)


## A hand weapon for the crew ("crew:<CrewWeapons id>").
static func is_crew_weapon(item: String) -> bool:
	return item.begins_with("crew:")


static func crew_weapon_of(item: String) -> String:
	return item.substr(5)


static func crew_weapon_item(id: String) -> String:
	return "crew:" + id


static func display_name(item: String) -> String:
	if is_weapon(item):
		return str(Game.GUNS.get(weapon_of(item), {}).get("name", "Gun"))
	if is_crew_weapon(item):
		return CrewWeapons.display_name(crew_weapon_of(item))
	return str(ITEMS.get(item, {}).get("name", item))


static func describe(item: String) -> String:
	if is_weapon(item):
		return "%s - mount it at a gun console" % str(Game.GUNS.get(weapon_of(item), {}).get("short", "Gun"))
	if is_crew_weapon(item):
		return "Hand weapon: %s" % str(CrewWeapons.def(crew_weapon_of(item))["short"]).to_lower()
	return str(ITEMS.get(item, {}).get("desc", ""))


static func color(item: String) -> Color:
	if is_weapon(item):
		return WEAPON_COLOR
	if is_crew_weapon(item):
		return CREW_WEAPON_COLOR
	return ITEMS.get(item, {}).get("color", Color.WHITE)


## Where this item is fitted, for prompts (`hub_room`: where the ship's install hub is).
static func install_hint(item: String, hub_room := "engine room") -> String:
	if is_weapon(item):
		return "mount it at a GUN console"
	if is_crew_weapon(item):
		return "put it down and press F to equip it"
	return "fit it at the INSTALL HUB in the %s" % hub_room


## Shop price of an item at waystation k (k = 0 is the first one).
static func price(item: String, k: int) -> int:
	var base := 100
	if is_weapon(item):
		base = int(WEAPON_PRICES.get(weapon_of(item), 150))
	elif is_crew_weapon(item):
		base = int(CrewWeapons.def(crew_weapon_of(item))["price"])
	else:
		base = int(ITEMS.get(item, {}).get("price", 100))
	return int(round(base * (1.0 + PRICE_STEP * maxi(k, 0)) / 5.0)) * 5


## What the buyback counter at waystation k pays for an item.
static func sell_price(item: String, k: int) -> int:
	return maxi(1, int(round(price(item, k) * SELL_SHARE)))


## The SHOP_SIZE items waystation k stocks. `guns` are the guns on offer (none: no gun),
## `mounted` the guns on the ship right now, `free_slots` how many turret slots are still empty.
static func roll_shop(rng: RandomNumberGenerator, guns: Array, mounted: Array, free_slots: int) -> Array[String]:
	var items: Array[String] = ["hull_kit"]
	# A gun the ship doesn't already carry everywhere, if there is one.
	var options: Array = []
	for g in guns:
		if not (mounted.size() > 0 and mounted.count(g) == mounted.size()):
			options.append(g)
	if options.is_empty():
		options = guns.duplicate()
	if not options.is_empty():
		items.append("weapon:" + str(options[rng.randi() % options.size()]))
	var pool: Array = UPGRADE_POOL.duplicate()
	var weights: Array[float] = []
	for p in pool:
		weights.append(1.0)
	# Hand weapons blend in with the upgrades.
	for w: String in CrewWeapons.ORDER:
		if w != CrewWeapons.DEFAULT:
			pool.append(crew_weapon_item(w))
			weights.append(CREW_WEAPON_WEIGHT)
	if free_slots > 0:
		pool.append("autocannon")
		weights.append(TURRET_WEIGHT)
	while items.size() < SHOP_SIZE and not pool.is_empty():
		var pick := _pick(rng, weights)
		items.append(str(pool[pick]))
		pool.remove_at(pick)
		weights.remove_at(pick)
	return items


## One crate of salvage from an abandoned station: an upgrade, a hull repair kit, a gun (one of
## `guns`, if any), a hand weapon, or an auto turret while a turret slot is free.
static func roll_salvage(rng: RandomNumberGenerator, guns: Array, free_slots: int) -> String:
	var pool: Array = UPGRADE_POOL.duplicate()
	var weights: Array[float] = []
	for p in pool:
		weights.append(1.0)
	pool.append("hull_kit")
	weights.append(2.5)
	for g in guns:
		pool.append("weapon:" + str(g))
		weights.append(3.0 / maxf(guns.size(), 1.0))
	for w: String in CrewWeapons.ORDER:
		if w != CrewWeapons.DEFAULT:
			pool.append(crew_weapon_item(w))
			weights.append(CREW_WEAPON_WEIGHT * 1.2)
	if free_slots > 0:
		pool.append("autocannon")
		weights.append(TURRET_WEIGHT * 0.6)
	return str(pool[_pick(rng, weights)])


## Index picked from `weights` (relative chances).
static func _pick(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1
