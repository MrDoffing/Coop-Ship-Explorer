class_name RunItems
extends RefCounted
## What waystation shops sell during a dive. The crew buys items with the dive's credits, carries
## the crates aboard and fits them: guns at a gun console, everything else at the install hub.
## Everything bought only lasts for the current dive.
##
## Every shop stocks SHOP_SIZE items: a hull repair kit, a gun (one of the guns unlocked at
## homebase) and random upgrades. Auto turrets only turn up while the ship has a free turret slot.

const SHOP_SIZE := 5
## Hull integrity restored by a repair kit: this share of max hull, but at least HULL_KIT.
const HULL_KIT := 120.0
const HULL_KIT_SHARE := 0.3
## Prices rise by this share at every waystation further down.
const PRICE_STEP := 0.25
## How much more likely an auto turret is than another upgrade while a turret slot is free.
const TURRET_WEIGHT := 3.0

const SHIP_COLOR := Color(0.35, 0.8, 1.0)
const SCOUT_COLOR := Color(0.75, 0.55, 1.0)
const CREW_COLOR := Color(0.5, 1.0, 0.45)
const WEAPON_COLOR := Color(1.0, 0.3, 0.25)

## Item id -> name, description, base price and crate colour. Guns use ids "weapon:<id>" (Game.GUNS).
const ITEMS := {
	"hull_kit": {"name": "Hull Repair Kit", "desc": "Restores 30% hull integrity", "price": 70, "color": Color(1.0, 0.5, 0.2)},
	"autocannon": {"name": "Auto Turret", "desc": "Fills an empty turret slot and shoots aliens by itself", "price": 200, "color": Color(1.0, 0.85, 0.2)},
	"plating": {"name": "Armor Plating", "desc": "+15% max hull integrity", "price": 110, "color": SHIP_COLOR},
	"shield_cell": {"name": "Shield Cell", "desc": "+25% max shield", "price": 100, "color": SHIP_COLOR},
	"shield_coil": {"name": "Shield Coil", "desc": "+30% shield recharge, reboots 1 s faster", "price": 90, "color": SHIP_COLOR},
	"coolant": {"name": "Turret Coolant", "desc": "+15% fire rate for every gun and turret", "price": 120, "color": SHIP_COLOR},
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
	"blaster_mod": {"name": "Blaster Overcharge", "desc": "+25% crew blaster damage", "price": 70, "color": CREW_COLOR},
	"power_tools": {"name": "Power Tools", "desc": "+30% repair speed", "price": 70, "color": CREW_COLOR},
	"crew_armor": {"name": "Crew Armor", "desc": "+20 crew health", "price": 60, "color": CREW_COLOR},
}
## General upgrades a shop can stock (ship systems, scouts, then crew gear).
const UPGRADE_POOL := ["plating", "shield_cell", "shield_coil", "coolant", "calibration", "fuel_tank",
	"injectors", "thrusters", "mining_lens", "overcharge", "tractor", "nanobots", "dampers",
	"scout_plating", "scout_guns", "scout_cargo", "scout_thrusters", "blaster_mod", "power_tools", "crew_armor"]
## Base price of each gun in a shop.
const WEAPON_PRICES := {"pulse": 60, "flak": 150, "plasma": 190, "rail": 230}


static func is_weapon(item: String) -> bool:
	return item.begins_with("weapon:")


static func weapon_of(item: String) -> String:
	return item.substr(7)


static func display_name(item: String) -> String:
	if is_weapon(item):
		return str(Game.GUNS.get(weapon_of(item), {}).get("name", "Gun"))
	return str(ITEMS.get(item, {}).get("name", item))


static func describe(item: String) -> String:
	if is_weapon(item):
		return "%s - mount it at a gun console" % str(Game.GUNS.get(weapon_of(item), {}).get("short", "Gun"))
	return str(ITEMS.get(item, {}).get("desc", ""))


static func color(item: String) -> Color:
	if is_weapon(item):
		return WEAPON_COLOR
	return ITEMS.get(item, {}).get("color", Color.WHITE)


## Where this item is fitted, for prompts.
static func install_hint(item: String) -> String:
	if is_weapon(item):
		return "mount it at a GUN console"
	return "fit it at the INSTALL HUB in the engine room"


## Shop price of an item at waystation k (k = 0 is the first one).
static func price(item: String, k: int) -> int:
	var base := 100
	if is_weapon(item):
		base = int(WEAPON_PRICES.get(weapon_of(item), 150))
	else:
		base = int(ITEMS.get(item, {}).get("price", 100))
	return int(round(base * (1.0 + PRICE_STEP * maxi(k, 0)) / 5.0)) * 5


## The SHOP_SIZE items waystation k stocks. `guns` are the unlocked guns, `mounted` the guns on
## the ship right now, `free_slots` how many turret slots are still empty.
static func roll_shop(rng: RandomNumberGenerator, guns: Array, mounted: Array, free_slots: int) -> Array[String]:
	var items: Array[String] = ["hull_kit"]
	# A gun the ship doesn't already carry everywhere, if there is one.
	var options: Array = []
	for g in guns:
		if not (mounted.size() > 0 and mounted.count(g) == mounted.size()):
			options.append(g)
	if options.is_empty():
		options = guns.duplicate() if not guns.is_empty() else ["pulse"]
	items.append("weapon:" + str(options[rng.randi() % options.size()]))
	var pool: Array = UPGRADE_POOL.duplicate()
	var weights: Array[float] = []
	for p in pool:
		weights.append(1.0)
	if free_slots > 0:
		pool.append("autocannon")
		weights.append(TURRET_WEIGHT)
	while items.size() < SHOP_SIZE and not pool.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		var r := rng.randf() * total
		var pick := pool.size() - 1
		for i in pool.size():
			r -= weights[i]
			if r <= 0.0:
				pick = i
				break
		items.append(str(pool[pick]))
		pool.remove_at(pick)
		weights.remove_at(pick)
	return items
