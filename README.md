# Coop Ship Explorer

A 1–4 player co-op game for Godot 4.6, built from `Game_Spec.md.txt`. The crew runs a mining
mothership through procedurally generated asteroid caves. They mine minerals, spend them in
waystation shops to upgrade the ship during the dive, search abandoned stations for salvage, and
keep the ship alive against aliens until it is destroyed. The deeper they get, the more research
points they bring home to unlock new ships, guns and ship upgrades.

Everything (cave, ships, aliens, UI, sounds) is generated from code, so there are no asset files.

## Running

Open the folder in Godot 4.6 and press **F5**, or run:

```
Godot_v4.6.1-stable_win64.exe --path "<this folder>"
```

## How to play

1. **Title screen**: set a callsign, then choose **Play Solo**, **Host Game** or **Join Game**
   (enter the host's IP address, optionally followed by `:port`).
2. **Homebase**: spend the crew's research points in the shipyard: unlock motherships and choose
   which one to fly, upgrade it, and unlock guns (see **Homebase** below). The host can add
   **crew bots** to empty crew slots (see below), then presses **LAUNCH MISSION**.
3. **Mission**: walk around inside the mothership and use its stations. Mining earns **credits**,
   which only exist during the dive: spend them in the shop of each **waystation** you land at. The
   mission ends when the mothership is destroyed (or the host aborts from the Esc menu). The crew
   earns research points for how far it got; unspent credits are lost.

### Stations and jobs

Every mothership has its own walkable interior (see **Interiors** below); which consoles it has
depends on the ship (see **Motherships**). The rooms are signposted.

| Station | Where (Prospector) | What it does |
|---|---|---|
| Pilot seat | Cockpit (front) | Throttle, turning, climb/dive. The autopilot follows the tunnel while the throttle stays set, so a solo player can leave the seat. |
| Guns | Gunnery deck windows, or next to the cockpit door | Manned turrets. Side guns swing past straight ahead, so they can fire in front of the nose too. Every gun launches with a Pulse Cannon; shops sell Flak Cannons, Plasma Mortars and Rail Lances once unlocked. |
| Mining laser | Next to the cockpit door | A beam that breaks crystal deposits into chunks, which the tractor field pulls back to the tip of the laser. |
| Scout bay | Starboard side room | Launches a scout pod. It fits through the narrow side tunnels where fuel crystals grow and carries fuel back when it docks. Its guns can hit critters on the hull, which the turrets can't reach. |
| Repair panels | Engine room (rear), weapons room (port side) | Use the toolkit on these to repair the engine and weapon systems. |
| Emergency blast button | Cockpit, right of the pilot seat | See **Emergency blast** below. The pilot can also press **B**. |
| Install hub | Engine room, port wall | Fit upgrades, repair kits and auto turrets bought in a waystation shop. Its screen lists what was fitted this dive. |
| Cargo ramp | Stern, behind the engine room | Opens by itself when the ship lands at a waystation or an abandoned station and closes for liftoff. |

### Motherships

| Ship | Unlock | Guns | Mining lasers | Scouts | Turret slots | Notes |
|---|---|---|---|---|---|---|
| Prospector | standard | 2 (port, starboard) | 1 (nose) | 1 (belly) | 1 (up to 4) | The all-rounder: hull 400, shield 120. |
| Vanguard Carrier | 250 RP | 1 (bow, front edge of the flight deck) | 1 (under the bow) | 2 combat scouts on the flight deck | 1 (up to 4) | Combat scouts have +60% hull, +50% damage and +15% speed. |
| Excavator Prime | 300 RP | 1 (front corner) | 2 (on mining arms) | 1 (roof) | 2 (up to 4) | Its lasers mine 45% faster and do 60% more damage to aliens. |
| Dreadnought | 400 RP | 3 (port, starboard, front corner; heavy, +25% damage) | 1 (nose) | 1 (belly) | 2 (up to 5) | Big and slow: hull 640, shield 160. |

Turret slots hold **auto turrets**: small automatic guns that shoot any free-flying alien above
their part of the hull. Every slot launches empty; buy turrets in waystation shops to fill them.

### Interiors
Each ship has a layout of its own, so a new ship feels fresh. Every one ends at the cargo door.
- **Prospector:** a narrow cockpit, the gunnery deck with the guns at its side windows, a hall with
  the weapon systems room (port) and the scout bay (starboard), and the engine room with the
  install hub.
- **Vanguard Carrier:** a bridge with three seats side by side (bow gun, pilot, mining laser) and a
  narrow spine corridor with four rooms off it: Flight Ops A and B (one scout console each, with a
  window), the weapon systems room and the quartermaster's store with the install hub. Twin
  reactors in the engine room, with the engine panels on the side walls.
- **Excavator Prime:** a mining control room (the pilot between the two laser consoles), then an
  open ore hall round a crusher with the weapon systems panels built into its sides. The gun
  console is at the starboard window, the scout lift console behind it, and the install hub on
  the port wall.
- **Dreadnought:** taller and wider. A bridge far forward (helm, with the mining laser and forward
  gun consoles at its side windows), the combat information centre with the port and starboard
  batteries and a plotting table, twin corridors round the armoury core (weapon systems) with the
  magazine (install hub) and the scout bay either side, and twin reactors.

### Ship systems (from the spec)
- **Shield** absorbs damage. When it breaks, it reboots after a few seconds and then recharges.
- **Hull** takes damage once the shield is down. The crew can't repair it in flight, only with
  hull repair kits from a waystation shop. At 0 the ship is destroyed and the crew returns to
  homebase.
- Hull damage also spills into the **engine** and **weapons** systems. Either one goes offline at
  0% and comes back online once it is repaired to 50%. The crew can also repair before that.
- **Fuel** burns while flying (faster at high throttle). With an empty tank the ship flies at low
  power, the shield cannot recharge and the ship takes extra damage. The scouts use no fuel.

The ship panel (top left) shows each value as a percentage inside its bar and as an absolute value
beside it.

### Aliens
- **Spitters** keep their distance and spit acid at the ship (or a scout).
- **Critters** latch onto the hull and scratch it. Only the scouts can shoot them off.
- **Infiltrators** latch onto a roof hatch. Once the shield is down they cut in and become
  **boarders**, which attack the crew and sabotage machinery. Kill them with blasters.
- **Nests** sit on cavern walls, surrounded by egg sacs that hatch aliens forever. They hatch
  faster when the ship gets close or a sac is hit (about twice as fast, at most one hatchling every
  1.6 s and five alive at once). Destroy every sac to kill the nest; it drops rare minerals. A sac
  has 55 health near the surface (its health grows with depth half as fast as the aliens').
- Living in **abandoned stations** (see below): **boarders**, packs of small, fast **skitters**
  that crawl over the walls and ceilings and drop down to claw at you, and **needlers** that keep
  their distance and fire needles.

### Hostility
The meter under the credits shows how hard the aliens are hunting the ship. It fills up while the
ship flies (each of its four stages takes about 80 s, so about 5 minutes from empty to full), holds
while the ship is down at an abandoned station, and resets at every waystation, so dawdling and
sniping from afar has a price.

| Stage | Ambushes |
|---|---|
| Docile | none |
| Mild | a small pack every 40 s or so |
| Moderate | bigger packs about every 30 s |
| High | large packs about every 15 s |

Ambushes come more often and in bigger packs deeper down and with a bigger crew.

Difficulty rises with depth. Minerals get rarer and more valuable deeper down (Ferrite 2 CR,
Cobaltite 4, Aurium 6 and Voidstone 9 per chunk), but even diligent mining buys only part of
a shop's stock: choose what matters. The tunnel is about 56 m across (radius 28 ± 7 m), wider
in caverns and narrower where it straightens out for a waystation.

### Emergency blast
A shockwave from the shield emitters, triggered by the big red button in the cockpit or by the
pilot pressing **B**.
- **Damage:** everything within 42 m takes damage that falls off with distance. Point blank is
  lethal to almost anything; spitters die out to about 30 m. That includes critters and
  infiltrators latched onto the hull, and nearby egg sacs.
- **Cost:** 6% of max hull and 12 fuel. It also drains the shield completely, which then has to
  reboot.
- **Cooldown:** 15 s, shown as the BLAST bar on the HUD.
- **When it is refused:** with less than 12 fuel, or when the hull is too weak to survive the cost.

### Waystations
Every 650 m or so (the first one at about 320 m), the tunnel runs through a waystation: a hall
built into the tunnel around a landing pad, sealed by a bulkhead at each end. Near a station the
tunnel straightens out, narrows and smooths so the ship lines up with the gates. An orange marker
shows the next one.
- **Entering:** the entrance bulkhead stands open. The exit bulkhead stays sealed until you land,
  so you have to stop here: if the ship flies into the hall without landing, the flight computer
  stops it short of the sealed exit. Yellow warning beacons over the corners of each gate turn
  while its doors open or close.
- **Landing:** within about 110 m of the entrance gate (or anywhere inside the hall) the pilot
  presses **L**. The ship flies through the gate over the shop and settles on the pad, nose towards
  the exit. Scouts that are out are recalled first. As soon as the ship is down the **entrance
  seals behind it**: the previous stretch of tunnel is closed for good. The cargo ramp opens onto
  a pier leading into the shop.
- **Safe haven:** while docking and docked the ship takes no damage, refuels, and its shield
  recharges (even from broken). The station's turrets shoot down any alien in the hall or its
  approach tunnels, including critters on the hull. No ambushes are sent while docked, and landing
  resets the **hostility**.
- **Shop:** five items on pedestals, paid for with the credits mined this dive (prices rise at
  every station further down). One is always a **hull repair kit** (restores 30% hull), one is
  always a **gun** (one of the guns unlocked at homebase; while only the Pulse Cannon is unlocked,
  that is a spare Pulse Cannon), and three are random upgrades and **hand weapons**: armour
  plating, shield cells and coils, turret coolant, targeting modules, fuel tanks and injectors,
  thrusters, mining lens, laser overcharge, tractor booster, repair nanobots, surge dampers, scout
  plating, blasters, cargo pods and thrusters, blaster overcharge, power tools, crew armour, the
  four hand weapons, and **auto turrets** (more likely while the ship has an empty turret slot).
- **Buying and carrying:** look at an item and press **E** to buy it, then **E** again to pick up
  the crate. You can't use tools while carrying. Press **G** to put it down. Walk it up the ramp
  and fit it:
  - **Guns** go to a gun console, where they replace that gun's weapon.
  - **Hand weapons** aren't installed: look at the crate and press **F** to swap (see below).
  - **Everything else** (repair kits, auto turrets, upgrades) goes to the ship's **install hub**.
- **Selling:** the **buyback** counter just inside the shop door, facing the middle of the shop,
  buys any crate you carry to it (bought here, earlier or salvaged) for 25% of its price at this
  shop.
- **Liftoff:** the pilot presses **L** again. The ship waits until every conscious crew member is
  back aboard, and asks for a second **L** if bought items are still in the shop. The ramp closes,
  the **exit bulkhead opens**, the ship rises and flies out through the exit gate and hands the
  helm back with the autopilot on. Once the ship (and any scout) is through, the exit **seals
  behind it**: there is no way back.
- Everything bought lasts for the **current dive only**.

### Abandoned stations
In about 60% of the stretches between two waystations (never within 120 m of one), a hangar is
cut into the tunnel wall: an abandoned mining outpost. A grey ◇ marker shows it when it is near.
Landing there is **optional** and there are no bulkheads: fly past if you like.
- **Landing:** within about 90 m of the hangar mouth the pilot presses **L**, but not while an
  alien is within 60 m of the ship (critters and infiltrators latched onto the hull don't count;
  the pilot's screen and the marker say when aliens are too close). The ship flies in side-on,
  turns round over the pad and settles nose out; the cargo ramp comes down onto a pier that leads
  to the station's door. Scouts are recalled first.
- **The cave's aliens leave it alone:** from the moment the ship starts landing until it is back
  out in the tunnel, they don't attack it. Aliens latched onto the hull let go, and those that
  were after the ship roam the tunnel by the hangar, so expect company when you leave.
- **No safe haven:** nothing refuels the ship or recharges its shield. No ambushes are sent while
  the ship is down, and the hostility holds.
- **Flashlights:** the crew's flashlights come on by themselves out in the station and go off again
  back aboard.
- **Inside:** four to seven rooms joined by corridors, generated from the cave's seed: storage,
  crew quarters, labs... and a vault (the room furthest from the door). Rooms hold **salvage
  crates** (free: upgrades, hull repair kits, guns, hand weapons and auto turrets; the vault always
  has two) and **aliens** (boarders, skitter packs, needlers; the first room is clear and the vault
  is always guarded). They notice crew who come close or within sight, call their pack mates and
  chase you through the station, but never into the ship. They go for whoever is closest, crew
  bots as well as players, turn on whoever shoots them, and a pack spreads out over the crew
  instead of all going for one. They get tougher deeper down.
- **Liftoff:** the pilot presses **L** once everyone is back aboard. Crates and aliens left
  behind stay in the station, in case you come back before the next waystation.

### Hand weapons
Everyone starts a dive with the **Blaster**. The others come in crates, from waystation shops or
abandoned stations. Look at a crate holding one and press **F**: you take that weapon and your old
one goes into the crate. You can also carry these crates around with **E** like any other.
Blaster Overcharge from a shop boosts every hand weapon. Every gun scatters its shots a little:
hardly at all for the long-range weapons, widely for the close-range ones.

Every weapon fires from a **magazine** (the HUD shows the shots left). Once it is empty the trigger
only clicks: press **R** to reload (you can also top it up early). Switching to the toolkit, taking
a station or picking up a crate cuts a reload short. A weapon you take out of a crate comes loaded.
Crew bots reload by themselves.

| Weapon | Damage | Magazine | Notes |
|---|---|---|---|
| Blaster | 20 per shot, 4 shots/s | 15, 1.2 s reload | The reliable sidearm. |
| Pulse Rifle | 11 per bolt, 11 bolts/s | 45, 1.8 s reload | Rapid fire with some spread. |
| Scattergun | 10 pellets x 9, every 0.3 s | 8, 1.9 s reload | Shreds anything up close, weak at range. |
| Rail Carbine | 90, every 1.0 s | 5, 2.0 s reload | Pin-point. The slug passes through up to five aliens in a line. |
| Plasma Launcher | 60 splash (6 m), every 0.95 s | 6, 2.2 s reload | A slow orb that bursts on impact; good against skitter packs. |

The ship's guns: the **Pulse Cannon** (rapid bolts, slight spread), the **Flak Cannon** (bursts of
eight pellets about four times a second in a wide cone: devastating close to the ship, useless far
off), the **Plasma Mortar** (slow orbs that burst in a 16 m blast) and the **Rail Lance** (a
pin-point piercing slug).

### Homebase
Research points (**RP**) are earned at the end of every dive: 1 RP per 10 m of depth, 10 RP per
waystation landed at and 2 RP per nest destroyed. The shipyard spends them:
- **Ships:** unlock the Vanguard Carrier, Excavator Prime and Dreadnought, and choose which ship
  to fly. The selected ship stands on the pad.
- **Upgrades** (per ship): Hull Plating (+15% hull), Shield Capacitors (+15% shield), Engine
  Tuning (+8% speed and handling) and Turret Slots (+1 auto turret slot, up to the ship's
  hardpoints; slots launch empty).
- **Armory:** unlock the Flak Cannon (60 RP), Plasma Mortar (100 RP) and Rail Lance (140 RP).
  Unlocked guns turn up in waystation shops during dives.

Saves from before the shipyard changed are converted automatically: lifetime credits become
research points (1 RP per 45 credits), guns you had bought stay unlocked, and the old save is kept
as `savegame_v1_backup.json` next to the new one.

### Cheat menu (for testing)
When the game runs from the editor or the Godot executable (a debug build), the host has a
**CHEATS** button in the bottom-left corner of the homebase. It is not there in release exports.
- **Research points:** +100, +1,000 or +10,000 RP, to buy anything in the shipyard the normal way.
- **Unlock all ships / guns**, and **max the upgrades** of the selected ship or every owned ship.
- **Dive credits:** every dive starts with 1,000, 10,000 or 99,999 credits for the waystation shops
  (until you quit the game).
- **Fresh profile** (click twice) starts the campaign over.
- Cheats change the real save, so the first one keeps a copy of the profile from before
  (`savegame_precheat.json`). **Restore my save** brings it back.

### Crew bots
With fewer than 4 players, the host can fill empty crew slots with bots: **+ Bot / - Bot** in the
homebase crew panel. The choice is remembered for future sessions.
- **Repairs come first.** A bot drops its gun when the engine or weapon systems fall below 70% (or
  go offline) and repairs them to full. Bots split up when both systems need work.
- **Otherwise it mans a free gun.** It leads its shots at aliens and shoots egg sacs when no
  aliens are in range.
- **Bots mine when it is quiet.** With no aliens near the ship for 6 seconds, a bot takes each
  free mining laser and breaks crystals in reach (never fuel crystals, and not next to a nest).
  When aliens show up it moves to a free gun. If every gun is taken, it turns the laser on the
  aliens instead.
- **Bots give way to humans.** Use a station a bot is manning and the bot steps aside. A player
  joining the session takes a bot's slot.
- **Bots defend themselves.** A bot that sees a boarder within 10 m gets up and fights it with its
  blaster, then goes back to its job. That includes a boarder attacking a crewmate next to it. Bots
  react and shoot a little slower and less accurately than players, reload when their blaster
  runs dry and top it up between fights. They don't hunt boarders
  elsewhere in the ship or fly scouts, and if knocked out they respawn like players.
- **Bots follow the host through abandoned stations.** When the ship has landed at one and the
  host walks out, the bots leave their jobs and tag along. They don't pick up crates, but they
  shoot any alien within 16 m, and go back to work once the host is aboard again.

## Controls

| Context | Keys |
|---|---|
| Walking | WASD move, mouse look, Space jump, Shift sprint, E use station, 1/2/Q/wheel hand weapon/toolkit, LMB shoot or repair, R reload |
| Shop and crates | E buy (look at a shop item), E pick up (look at a crate), E install (at the install hub or a gun console), G drop, F swap hand weapons with a crate |
| Any station | E leave, Esc menu, Tab crew status |
| Pilot | W/S throttle, A/D turn, Space/Ctrl climb/dive, T autopilot, X full stop, B emergency blast, L land at / lift off from a waystation or abandoned station, mouse orbits the camera |
| Guns / mining lasers | Mouse aim, LMB fire, RMB zoom |
| Scout | Mouse steer, WASD move, Space/Ctrl up/down, Shift boost, LMB fire, E dock when close, hold E to recall the scout (its cargo is lost) |
| Anywhere | F11 fullscreen |

Key bindings are registered in code (`autoload/game.gd`, `_setup_input`). Actions already defined in
Project Settings › Input Map take precedence, so you can rebind them there.

## Multiplayer

- The host uses ENet on port **24565** (UDP), which can be changed on the title screen. Players on
  the same network join with the host's local IP. Internet play needs that port forwarded on the
  host's router, and Windows will ask to allow Godot through the firewall the first time.
- Up to 4 players. Friends can join while the crew is at homebase or in the middle of a mission.
- The host owns the save file and the research points. The server simulates the ship, aliens and
  the scouts. Each player's own avatar runs locally, so walking stays responsive. Stations send
  input to the host, so on high-latency connections steering responds a little late.

Progress is saved to `%APPDATA%\Godot\app_userdata\CoopShipExplorer\savegame.json`. To start
over, use Settings › Reset campaign progress.

## Project layout

```
autoload/      game.gd (profile, research points, ships, guns, ship stats, settings, input), net.gd (sessions), sfx.gd (synth audio)
scenes/main.tscn
scripts/
  main.gd              level switching (replicated via MultiplayerSpawner), menus
  levels/              homebase.gd (shipyard), mission.gd (cave streaming, population, director, mission end)
  cave/                cave_gen.gd (signed-distance-field cave + surface nets, waystation halls, abandoned station hangars), cave_chunk.gd (threaded build, rock shader)
  station/             station_builder.gd (hall, bulkheads, pad, pier, shop), waystation.gd (bulkhead doors), supply_crate.gd, run_items.gd (shop catalogue, salvage),
					   derelict_builder.gd (abandoned stations: room layout, building, waypoints), derelict.gd (their flickering lights)
  ship/                ship_types.gd (the motherships' stats and layouts), ship_interiors.gd (each ship's rooms, consoles, panels, walking graph), mothership.gd (incl. docking, gates, shop, auto turrets, hostility), ship_builder.gd (hulls + interiors), turret.gd, scout.gd
  crew/                crew_member.gd (first-person avatar, stations, hand weapon, toolkit), crew_weapons.gd (hand weapons), crew_bot.gd (bot AI)
  enemies/             alien.gd (spitter/critter/infiltrator), boarder.gd (aliens on foot: boarder, skitter, needler), nest.gd
  minerals/            deposit.gd, mineral_chunk.gd
  fx/                  fx.gd (particles, flashes, tracers), projectiles.gd
  ui/                  hud.gd, main_menu.gd, pause_menu.gd, settings_panel.gd, cheat_menu.gd (homebase cheats)
  common/              models.gd (procedural meshes, mesh batching), net_util.gd, ui_theme.gd
  dev/autotest.gd      automated test runs (see below)
```

Balance numbers to tweak:
- Motherships (stats, stations, turret slots, hardpoints): `ShipTypes.TYPES`. Their interiors
  (console spots, repair panels, install hub, walking graph, spawn points): `ShipInteriors.LAYOUTS`,
  and the rooms themselves: `ShipBuilder._rooms_<ship>()`. Base stats, homebase
  ship upgrades, gun unlocks and research point rewards: `Game.ship_stats()`, `Game.SHIP_UPGRADES`,
  `Game.GUNS` and the `RP_*` constants in `game.gd`.
- Turret weapons (fire rate, damage, pellets, spread): `Mothership.WEAPON_DEFS`, plus `AUTO_SPREAD` and
  `SCOUT_SPREAD`; the Plasma Mortar's blast radius: `Projectiles.KINDS["plasma"]["splash"]`.
- Hostility: `HOSTILITY_TIME` in `mothership.gd` (how long it takes to fill), and the ambushes per
  stage (`AMBUSH_INTERVAL`, `AMBUSH_PACK` in `mission.gd`).
- Emergency blast: the `BLAST_*` constants at the top of `mothership.gd` (radius, damage, hull and
  fuel cost, cooldown).
- Crew bots: the constants at the top of `crew_bot.gd` (repair threshold, gun range, aim speed,
  reaction time, self-defence range, fire rate and accuracy, and when it counts as safe to mine). Bots count as half a crew member for difficulty (`MissionLevel.difficulty()`).
- Waystations: spacing and the straightened approach (`STATION_*` in `CaveGen`), the hall, gates
  and shop layout (`StationBuilder`), docking range, speeds, bulkhead speed and what a docked ship
  gets per second (`LAND_RANGE`, `DOCK_*`, `GATE_RATE` in `mothership.gd`), the safe zone
  (`StationBuilder.SAFE_MIN` / `SAFE_MAX`), the shop's stock and prices (`RunItems`) and what each
  item does (`Mothership._apply_item()`), and the auto turrets (`AUTO_*` in `mothership.gd`).
- Abandoned stations: how often and where they appear (`DERELICT_*` in `CaveGen`), the hangar and
  the rooms (`DerelictBuilder`: room count and sizes, grid, furniture), landing range and how much
  salvage and how many aliens the rooms hold, and how close aliens may be for a landing
  (`DERELICT_LAND_RANGE`, `DERELICT_CLEAR_RANGE`, `SALVAGE_CHANCE`,
  `HOSTILE_CHANCE` and `_roll_pack()` in `mothership.gd`), what salvage can be
  (`RunItems.roll_salvage()`), and the aliens there (`Boarder.KIND_STATS` and the constants at the
  top of `boarder.gd`, including how the skitters climb).
- The shops' buyback counters: `RunItems.SELL_SHARE`.
- Hand weapons: `CrewWeapons.DEFS` (damage, fire rate, spread, piercing, splash, shop price,
  magazine size and reload time).
- Egg sacs: `Nest.SAC_HP`.
- Alien stats: `Alien.KIND_STATS`.
- Mining and minerals: mining speed and reach (`mining_power`, `mining_range`, `tractor_range` in
  `Game.ship_stats()`; lasers deal `Mothership.LASER_ALIEN_SHARE` of it to aliens), mineral values
  and toughness (`Deposit.TYPES`) and deposits per stretch of tunnel (`MissionLevel._populate()`).
- Tunnel width: `TUNNEL_RADIUS` and `TUNNEL_RADIUS_VAR` in `CaveGen`.
- Engine hum: `ENGINE_HUM_*` in `mothership.gd` (the level inside the engine room at idle and
  full throttle, and how fast it fades outside it), and each interior's `engine_room` box in
  `ShipInteriors`.
- Waystation warning beacons: `BEACON_*` and `BEAM_LEN` in `StationBuilder`, how fast they turn
  and how long they keep turning after a door stops in `Waystation`.
- Spawn pacing: `MissionLevel._director()` and `_populate()`, plus the `Nest` constants (hatch
  intervals, live caps, `HATCH_GAP`, `HIT_AGITATION`).
- Cave shape: the radius, path and side tunnels in `CaveGen`.

## Automated tests

`scripts/dev/autotest.gd` drives the game and saves screenshots to `user://autotest/`. It uses a
separate save file, so it never touches real progress.

```
godot --path . -- --autotest=smoke     # full solo mission loop (add --headless for speed)
godot --path . -- --autotest=combat    # every weapon, boarders, hull critters, nests, repairs, load
godot --path . -- --autotest=scout     # scout fuel run through a side tunnel and back
godot --path . -- --autotest=death     # ship destroyed -> research points -> shipyard purchases
godot --path . -- --autotest=soak      # long accelerated dive
godot --path . -- --autotest=bots      # crew bots: guns, repairs, giving way to humans, fighting boarders
godot --path . -- --autotest=botfight  # detailed log of two bots against a wave of tough boarders
godot --path . -- --autotest=blast     # emergency blast falloff, costs, cooldown, cockpit button
godot --path . -- --autotest=fxcheck   # blaster impact effects land where the shot hits
godot --path . -- --autotest=shadows   # headlight shadow views for checking artifacts
godot --path . -- --autotest=host      # host with a full bot crew; run --autotest=join in a second instance
godot --path . -- --autotest=host_late # client joins mid-mission
godot --path . -- --autotest=station   # waystation: sealed exit, landing, bulkheads, shop, carrying, liftoff, no way back
godot --path . -- --autotest=notes     # bots on the mining laser, guns covering the bow, auto turrets, laser overcharge, nest pace
godot --path . -- --autotest=host_station  # with --autotest=join_station: a client buys a crate and carries it aboard
godot --path . -- --autotest=ships     # every mothership: views, guns, lasers, scouts
godot --path . -- --autotest=models    # every mothership and scout in a lit studio
godot --path . -- --autotest=meta      # old save conversion, unlocking and upgrading ships and guns
godot --path . -- --autotest=hud       # ship panel read-outs
godot --path . -- --autotest=sound     # mining laser hum levels, and the engine hum around the ship before and after
godot --path . -- --autotest=tunnels   # tunnel width, waystations sealing the tunnel, abandoned station placement (several seeds)
godot --path . -- --autotest=derelict  # abandoned station: landing, rooms, salvage, hostiles, bots following, F swap, liftoff
godot --path . -- --autotest=weapons   # hand weapon damage (rail piercing, plasma splash), swapping at a crate
godot --path . -- --autotest=cheats    # the homebase cheat menu, buying everything, restoring the save
godot --path . -- --autotest=interiors # every ship's interior: inside the hull, walking graph and spots clear, views (interiors_check: no shots)
godot --path . -- --autotest=interior_bots  # crew bots repairing and manning the guns in every ship's interior
godot --path . -- --autotest=backlog   # guns and spread, plasma blast, laser-tip mining, hostility, shop door, buyback, flashlight, skitters (backlog_check: no shots)
godot --path . -- --autotest=backlog2  # engine hum, reloading, buyback facing, gate beacons, landing with aliens about, outpost aliens vs bots (backlog2_check: no shots)
```

## Known limitations

- The ships and levels are built in code, so the editor shows only the empty `Main` scene. Run the
  game to see the content.
- Vehicles are simulated on the server without client-side prediction. That is fine on a LAN, but
  piloting from a distant client feels slightly delayed.
- The scouts pass through the mothership's hull instead of colliding with it.
- Aliens don't collide with the bulkhead doors (the station's turrets shoot down anything that
  comes close).
- Audio is simple synthesised effects with no music.
