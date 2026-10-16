# Coop Ship Explorer

A 1–4 player co-op game for Godot 4.6, built from `Game_Spec.md.txt`. The crew runs a mining
mothership through procedurally generated asteroid caves. They mine minerals, spend them in
waystation shops to upgrade the ship during the dive, and keep it alive against aliens until it is
destroyed. The deeper they get, the more research points they bring home to unlock new ships,
guns and ship upgrades.

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

Every mothership has the same walkable interior; which consoles it has depends on the ship (see
**Motherships**).

| Station | Where | What it does |
|---|---|---|
| Pilot seat | Cockpit (front) | Throttle, turning, climb/dive. The autopilot follows the tunnel while the throttle stays set, so a solo player can leave the seat. |
| Guns | Gunnery deck windows, or next to the cockpit door | Manned turrets. Side guns swing past straight ahead, so they can fire in front of the nose too. Every gun launches with a Pulse Cannon; shops sell Scatter Cannons, Plasma Mortars and Rail Lances once unlocked. |
| Mining laser | Next to the cockpit door | A beam that breaks crystal deposits into chunks, which the tractor field pulls in. |
| Scout bay | Starboard side room | Launches a scout pod. It fits through the narrow side tunnels where fuel crystals grow and carries fuel back when it docks. Its guns can hit critters on the hull, which the turrets can't reach. |
| Repair panels | Engine room (rear), weapons room (port side) | Use the toolkit on these to repair the engine and weapon systems. |
| Emergency blast button | Cockpit, right of the pilot seat | See **Emergency blast** below. The pilot can also press **B**. |
| Install hub | Engine room, port wall | Fit upgrades, repair kits and auto turrets bought in a waystation shop. Its screen lists what was fitted this dive. |
| Cargo ramp | Stern, behind the engine room | Opens by itself when the ship lands at a waystation and closes for liftoff. |

### Motherships

| Ship | Unlock | Guns | Mining lasers | Scouts | Turret slots | Notes |
|---|---|---|---|---|---|---|
| Prospector | standard | 2 (port, starboard) | 1 (nose) | 1 (belly) | 1 (up to 4) | The all-rounder: hull 400, shield 120. |
| Vanguard Carrier | 250 RP | 1 (bow, front edge of the flight deck) | 1 (under the bow) | 2 combat scouts on the flight deck | 1 (up to 4) | Combat scouts have +60% hull, +50% damage and +15% speed. |
| Excavator Prime | 300 RP | 1 (front corner) | 2 (on mining arms) | 1 (roof) | 2 (up to 4) | Its lasers mine 45% faster and do 60% more damage to aliens. |
| Dreadnought | 400 RP | 3 (port, starboard, front corner; heavy, +25% damage) | 1 (nose) | 1 (belly) | 2 (up to 5) | Big and slow: hull 640, shield 160. |

Turret slots hold **auto turrets**: small automatic guns that shoot any free-flying alien above
their part of the hull. Every slot launches empty; buy turrets in waystation shops to fill them.

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
  1.6 s and five alive at once). Destroy every sac to kill the nest; it drops rare minerals.

Difficulty rises with depth. Minerals get rarer and more valuable deeper down (Ferrite →
Cobaltite → Aurium → Voidstone).

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
Every 440 m or so (the first one at about 290 m), the tunnel runs through a waystation: a hall
built into the tunnel around a landing pad, sealed by a bulkhead at each end. Near a station the
tunnel straightens out, narrows and smooths so the ship lines up with the gates. An orange marker
shows the next one.
- **Entering:** the entrance bulkhead stands open. The exit bulkhead stays sealed until you land,
  so you have to stop here: if the ship flies into the hall without landing, the flight computer
  stops it short of the sealed exit.
- **Landing:** within about 110 m of the entrance gate (or anywhere inside the hall) the pilot
  presses **L**. The ship flies through the gate over the shop and settles on the pad, nose towards
  the exit. Scouts that are out are recalled first. As soon as the ship is down the **entrance
  seals behind it**: the previous stretch of tunnel is closed for good. The cargo ramp opens onto
  a pier leading into the shop.
- **Safe haven:** while docking and docked the ship takes no damage, refuels, and its shield
  recharges (even from broken). The station's turrets shoot down any alien in the hall or its
  approach tunnels, including critters on the hull. No ambushes are sent while docked.
- **Shop:** five items on pedestals, paid for with the credits mined this dive (prices rise at
  every station further down). One is always a **hull repair kit** (restores 30% hull), one is
  always a **gun** (one of the guns unlocked at homebase; while only the Pulse Cannon is unlocked,
  that is a spare Pulse Cannon), and three are random upgrades: armour plating, shield cells and
  coils, turret coolant, targeting modules, fuel tanks and injectors, thrusters, mining lens, laser
  overcharge, tractor booster, repair nanobots, surge dampers, scout plating, blasters, cargo pods
  and thrusters, blaster overcharge, power tools, crew armour, and **auto turrets** (more likely
  while the ship has an empty turret slot).
- **Buying and carrying:** look at an item and press **E** to buy it, then **E** again to pick up
  the crate. You can't use tools while carrying. Press **G** to put it down. Walk it up the ramp
  and fit it:
  - **Guns** go to a gun console, where they replace that gun's weapon.
  - **Everything else** (repair kits, auto turrets, upgrades) goes to the **install hub** in the
    engine room.
- **Liftoff:** the pilot presses **L** again. The ship waits until every conscious crew member is
  back aboard, and asks for a second **L** if bought items are still in the shop. The ramp closes,
  the **exit bulkhead opens**, the ship rises and flies out through the exit gate and hands the
  helm back with the autopilot on. Once the ship (and any scout) is through, the exit **seals
  behind it**: there is no way back.
- Everything bought lasts for the **current dive only**.

### Homebase
Research points (**RP**) are earned at the end of every dive: 1 RP per 10 m of depth, 10 RP per
waystation landed at and 2 RP per nest destroyed. The shipyard spends them:
- **Ships:** unlock the Vanguard Carrier, Excavator Prime and Dreadnought, and choose which ship
  to fly. The selected ship stands on the pad.
- **Upgrades** (per ship): Hull Plating (+15% hull), Shield Capacitors (+15% shield), Engine
  Tuning (+8% speed and handling) and Turret Slots (+1 auto turret slot, up to the ship's
  hardpoints; slots launch empty).
- **Armory:** unlock the Scatter Cannon (60 RP), Plasma Mortar (100 RP) and Rail Lance (140 RP).
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
  react and shoot a little slower and less accurately than players. They don't hunt boarders
  elsewhere in the ship or fly scouts, and if knocked out they respawn like players.

## Controls

| Context | Keys |
|---|---|
| Walking | WASD move, mouse look, Space jump, Shift sprint, E use station, 1/2/Q/wheel blaster/toolkit, LMB shoot or repair |
| Shop and crates | E buy (look at a shop item), E pick up (look at a crate), E install (at the install hub or a gun console), G drop |
| Any station | E leave, Esc menu, Tab crew status |
| Pilot | W/S throttle, A/D turn, Space/Ctrl climb/dive, T autopilot, X full stop, B emergency blast, L land at / lift off from a waystation, mouse orbits the camera |
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
  cave/                cave_gen.gd (signed-distance-field cave + surface nets, waystation halls), cave_chunk.gd (threaded build, rock shader)
  station/             station_builder.gd (hall, bulkheads, pad, pier, shop), waystation.gd (bulkhead doors), supply_crate.gd, run_items.gd (shop catalogue)
  ship/                ship_types.gd (the motherships' stats and layouts), mothership.gd (incl. docking, gates, shop, auto turrets), ship_builder.gd (hulls + interior), turret.gd, scout.gd
  crew/                crew_member.gd (first-person avatar, stations, blaster, toolkit), crew_bot.gd (bot AI)
  enemies/             alien.gd (spitter/critter/infiltrator), boarder.gd, nest.gd
  minerals/            deposit.gd, mineral_chunk.gd
  fx/                  fx.gd (particles, flashes, tracers), projectiles.gd
  ui/                  hud.gd, main_menu.gd, pause_menu.gd, settings_panel.gd, cheat_menu.gd (homebase cheats)
  common/              models.gd (procedural meshes, mesh batching), net_util.gd, ui_theme.gd
  dev/autotest.gd      automated test runs (see below)
```

Balance numbers to tweak:
- Motherships (stats, stations, turret slots, hardpoints): `ShipTypes.TYPES`. Base stats, homebase
  ship upgrades, gun unlocks and research point rewards: `Game.ship_stats()`, `Game.SHIP_UPGRADES`,
  `Game.GUNS` and the `RP_*` constants in `game.gd`.
- Turret weapons: `Mothership.WEAPON_DEFS`.
- Emergency blast: the `BLAST_*` constants at the top of `mothership.gd` (radius, damage, hull and
  fuel cost, cooldown).
- Crew bots: the constants at the top of `crew_bot.gd` (repair threshold, gun range, aim speed,
  reaction time, self-defence range, fire rate and accuracy, and when it counts as safe to mine). Bots count as half a crew member for difficulty (`MissionLevel.difficulty()`).
- Waystations: spacing and the straightened approach (`STATION_*` in `CaveGen`), the hall, gates
  and shop layout (`StationBuilder`), docking range, speeds, bulkhead speed and what a docked ship
  gets per second (`LAND_RANGE`, `DOCK_*`, `GATE_RATE` in `mothership.gd`), the safe zone
  (`StationBuilder.SAFE_MIN` / `SAFE_MAX`), the shop's stock and prices (`RunItems`) and what each
  item does (`Mothership._apply_item()`), and the auto turrets (`AUTO_*` in `mothership.gd`).
- Alien stats: `Alien.KIND_STATS`.
- Mineral types: `Deposit.TYPES`.
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
godot --path . -- --autotest=sound     # mining laser hum levels compared with the old one
godot --path . -- --autotest=cheats    # the homebase cheat menu, buying everything, restoring the save
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
