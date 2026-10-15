class_name RunItems
extends RefCounted
## Free supplies stacked in waystations. Crew carry the crates aboard and fit them: side-gun
## weapons at the gun consoles, everything else at the install hub. They only last for the
## current dive.

const MAX_AUTOCANNONS := 3
## Hull integrity restored by one repair kit.
const HULL_KIT := 120.0

## Item id -> name, description and crate colour. Weapons use ids "weapon:<id>" (Game.WEAPONS).
const ITEMS := {
	"hull_kit": {"name": "Hull Repair Kit", "desc": "Restores 120 hull integrity", "color": Color(1.0, 0.5, 0.2)},
	"autocannon": {"name": "Auto Cannon", "desc": "Hull turret that shoots aliens by itself", "color": Color(1.0, 0.85, 0.2)},
	"plating": {"name": "Armor Plating", "desc": "+60 max hull integrity", "color": Color(0.35, 0.8, 1.0)},
	"shield_cell": {"name": "Shield Cell", "desc": "+30 max shield", "color": Color(0.35, 0.8, 1.0)},
	"shield_coil": {"name": "Shield Coil", "desc": "+30% shield recharge", "color": Color(0.35, 0.8, 1.0)},
	"coolant": {"name": "Turret Coolant", "desc": "+15% turret fire rate", "color": Color(0.35, 0.8, 1.0)},
	"calibration": {"name": "Targeting Module", "desc": "+20% turret damage", "color": Color(0.35, 0.8, 1.0)},
	"fuel_tank": {"name": "Auxiliary Tank", "desc": "+25 fuel capacity", "color": Color(0.35, 0.8, 1.0)},
	"injectors": {"name": "Fuel Injectors", "desc": "-15% fuel consumption", "color": Color(0.35, 0.8, 1.0)},
	"thrusters": {"name": "Thruster Overhaul", "desc": "+10% speed and handling", "color": Color(0.35, 0.8, 1.0)},
	"mining_lens": {"name": "Mining Lens", "desc": "+25% mining speed", "color": Color(0.35, 0.8, 1.0)},
	"nanobots": {"name": "Repair Nanobots", "desc": "Engine and weapons slowly repair themselves", "color": Color(0.35, 0.8, 1.0)},
	"dampers": {"name": "Surge Dampers", "desc": "-20% damage spilling into the systems", "color": Color(0.35, 0.8, 1.0)},
	"blaster_mod": {"name": "Blaster Overcharge", "desc": "+25% crew blaster damage", "color": Color(0.5, 1.0, 0.45)},
	"power_tools": {"name": "Power Tools", "desc": "+30% repair speed", "color": Color(0.5, 1.0, 0.45)},
	"crew_armor": {"name": "Crew Armor", "desc": "+20 crew health", "color": Color(0.5, 1.0, 0.45)},
}
## General upgrades a waystation can stock (ship systems, then crew gear).
const UPGRADE_POOL := ["plating", "shield_cell", "shield_coil", "coolant", "calibration", "fuel_tank",
	"injectors", "thrusters", "mining_lens", "nanobots", "dampers", "blaster_mod", "power_tools", "crew_armor"]
const WEAPON_POOL := ["flak", "plasma", "rail"]
const WEAPON_COLOR := Color(1.0, 0.3, 0.25)


static func is_weapon(item: String) -> bool:
	return item.begins_with("weapon:")


static func weapon_of(item: String) -> String:
	return item.substr(7)


static func display_name(item: String) -> String:
	if is_weapon(item):
		return str(Game.WEAPONS.get(weapon_of(item), {}).get("name", "Turret Weapon"))
	return str(ITEMS.get(item, {}).get("name", item))


static func describe(item: String) -> String:
	if is_weapon(item):
		return "Side gun weapon - mount it at a gun console"
	return str(ITEMS.get(item, {}).get("desc", ""))


static func color(item: String) -> Color:
	if is_weapon(item):
		return WEAPON_COLOR
	return ITEMS.get(item, {}).get("color", Color.WHITE)


## Where this item is fitted, for prompts.
static func install_hint(item: String) -> String:
	if is_weapon(item):
		return "mount it at the PORT or STARBOARD gun console"
	return "fit it at the INSTALL HUB in the engine room"
