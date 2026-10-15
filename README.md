# Coop Ship Explorer

A 1–4 player co-op game for Godot 4.6, built from `Game_Spec.md.txt`. The crew runs a mining
mothership through procedurally generated asteroid caves. They mine minerals and keep the ship
alive against aliens until it is destroyed. Then they spend the haul on upgrades and dive deeper.

Everything (cave, ship, aliens, UI, sounds) is generated from code, so there are no asset files.

## Running

Open the folder in Godot 4.6 and press **F5**, or run:

```
Godot_v4.6.1-stable_win64.exe --path "<this folder>"
```

## How to play

1. **Title screen**: set a callsign, then choose **Play Solo**, **Host Game** or **Join Game**
   (enter the host's IP address, optionally followed by `:port`).
2. **Homebase**: spend the crew's shared credits in the shipyard on mothership, weapon, scout and
   crew upgrades, and buy or mount turret weapons. The host can add **crew bots** to empty crew
   slots (see below), then presses **LAUNCH MISSION**.
3. **Mission**: walk around inside the mothership and use its stations. Land at **waystations**
   along the way to refuel, patch the hull and pick up free upgrades for the current dive. The
   mission ends when the mothership is destroyed (or the host aborts from the Esc menu). You are
   paid for the minerals you collected, plus a depth bonus and a bonus for each nest destroyed.

### Stations and jobs

| Station | Where | What it does |
|---|---|---|
| Pilot seat | Cockpit (front) | Throttle, turning, climb/dive. The autopilot follows the tunnel while the throttle stays set, so a solo player can leave the seat. |
| Port / Starboard gun | Gunnery deck windows | Turrets on each side of the hull. They swing past straight ahead, so both can fire in front of the nose. Weapons: Pulse Cannon, Flak, Plasma Mortar, Rail Lance. |
| Mining laser | Next to the cockpit door | A nose-mounted beam. It breaks crystal deposits into chunks, which the tractor field pulls in. |
| Scout bay | Starboard side room | Launches the scout pod. It fits through the narrow side tunnels where fuel crystals grow and carries fuel back when it docks. Its guns can hit critters on the hull, which the turrets can't reach. |
| Repair panels | Engine room (rear), weapons room (port side) | Use the toolkit on these to repair the engine and weapon systems. |
| Emergency blast button | Cockpit, right of the pilot seat | See **Emergency blast** below. The pilot can also press **B**. |
| Install hub | Engine room, port wall | Fit upgrades and hull repair kits carried aboard from a waystation. Its screen lists what was fitted this dive. |
| Cargo ramp | Stern, behind the engine room | Opens by itself when the ship lands at a waystation and closes for liftoff. |

### Ship systems (from the spec)
- **Shield** absorbs damage. When it breaks, it reboots after a few seconds and then recharges.
- **Hull** takes damage once the shield is down. The crew can't repair it in flight, only with
  repair kits from a waystation. At 0 the ship is destroyed and the crew returns to homebase.
- Hull damage also spills into the **engine** and **weapons** systems. Either one goes offline at
  0% and comes back online once it is repaired to 50%. The crew can also repair before that.
- **Fuel** burns while flying (faster at high throttle). With an empty tank the ship flies at low
  power, the shield cannot recharge and the ship takes extra damage. The scout itself uses no fuel.

### Aliens
- **Spitters** keep their distance and spit acid at the ship (or the scout).
- **Critters** latch onto the hull and scratch it. Only the scout can shoot them off.
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
Every 440 m or so (the first one at about 290 m), a hangar is cut into the cave wall. An orange
marker shows the nearest one, and its beacons blink at the hangar mouth.
- **Landing:** within about 110 m of the hangar entrance the pilot presses **L**. The ship flies in
  side-on, turns round over the pad and settles on its landing legs, nose pointing out. The cargo
  ramp then opens onto a pier leading into the station.
- **Safe haven:** while docking and docked the ship takes no damage, refuels, and its shield
  recharges (even from broken). The station's turrets shoot down any alien that comes within about
  65 m, including critters on the hull. No ambushes are sent while docked.
- **Supplies:** crates are spread around the supply room: one or two **hull repair kits** (+120
  hull), a **side gun weapon** (Flak, Plasma Mortar or Rail Lance), an **auto cannon** if a
  hardpoint is still free, and two general upgrades for the ship or crew (armour plating, shield
  cells, turret coolant, targeting module, fuel tanks, thrusters, repair nanobots, blaster
  overcharge, power tools, crew armour and more).
- **Carrying:** look at a crate and press **E** to pick it up. You can't use tools while carrying.
  Press **G** to put it down. Walk it up the ramp and fit it:
  - **Weapons** go to the PORT or STARBOARD gun console. They replace that turret's weapon.
  - **Everything else** (repair kits, auto cannons, upgrades) goes to the **install hub** in the
    engine room.
- **Auto cannons** from waystations mount on up to 3 hardpoints (two on the roof, one under the
  nose). They track and shoot free-flying aliens on their own while the weapon systems are online.
  Auto cannons bought at homebase sit on separate hardpoints on the hull edges (see below).
- **Liftoff:** the pilot presses **L** again. The ship waits until every conscious crew member is
  back aboard. The ramp closes, the ship backs out and hands the helm back with the autopilot on.
  Crates left outside stay at the station.
- Everything from a waystation lasts for the **current dive only**. Homebase upgrades are unaffected.

### Homebase extras
- **Auto Cannons** (Weapons tab, expensive, up to 4): small automatic turrets on the hull's top
  edges, front corners first. They are weak (a fraction of a side gun's damage) but shoot any
  free-flying alien above their edge of the ship, every dive.
- **Laser Overcharge** (Weapons tab, up to 4): +50% mining laser damage to aliens and egg sacs per
  level. Mining speed on crystals is unaffected (that is Mining Laser Focus).

### Crew bots
With fewer than 4 players, the host can fill empty crew slots with bots: **+ Bot / - Bot** in the
homebase crew panel. The choice is remembered for future sessions.
- **Repairs come first.** A bot drops its gun when the engine or weapon systems fall below 70% (or
  go offline) and repairs them to full. Bots split up when both systems need work.
- **Otherwise it mans a free side gun.** It leads its shots at aliens and shoots egg sacs when no
  aliens are in range.
- **One bot mines when it is quiet.** With no aliens near the ship for 6 seconds, a bot takes the
  mining laser and breaks crystals in reach (never fuel crystals, and not next to a nest). When
  aliens show up it moves to a free side gun. If both guns are taken, it turns the laser on the
  aliens instead.
- **Bots give way to humans.** Use a gun a bot is manning and the bot steps aside. A player joining
  the session takes a bot's slot.
- **Bots defend themselves.** A bot that sees a boarder within 10 m gets up and fights it with its
  blaster, then goes back to its job. That includes a boarder attacking a crewmate next to it. Bots
  react and shoot a little slower and less accurately than players. They don't hunt boarders
  elsewhere in the ship, and if knocked out they respawn like players.

## Controls

| Context | Keys |
|---|---|
| Walking | WASD move, mouse look, Space jump, Shift sprint, E use station, 1/2/Q/wheel blaster/toolkit, LMB shoot or repair |
| Supply crates | E pick up (look at a crate), E install (at the install hub or a gun console), G drop |
| Any station | E leave, Esc menu, Tab crew status |
| Pilot | W/S throttle, A/D turn, Space/Ctrl climb/dive, T autopilot, X full stop, B emergency blast, L land at / lift off from a waystation, mouse orbits the camera |
| Guns / mining laser | Mouse aim, LMB fire, RMB zoom |
| Scout | Mouse steer, WASD move, Space/Ctrl up/down, Shift boost, LMB fire, E dock when close, hold E to recall the scout (its cargo is lost) |
| Anywhere | F11 fullscreen |

Key bindings are registered in code (`autoload/game.gd`, `_setup_input`). Actions already defined in
Project Settings › Input Map take precedence, so you can rebind them there.

## Multiplayer

- The host uses ENet on port **24565** (UDP), which can be changed on the title screen. Players on
  the same network join with the host's local IP. Internet play needs that port forwarded on the
  host's router, and Windows will ask to allow Godot through the firewall the first time.
- Up to 4 players. Friends can join while the crew is at homebase or in the middle of a mission.
- The host owns the save file and the shared credits. The server simulates the ship, aliens and
  the scout. Each player's own avatar runs locally, so walking stays responsive. Stations send
  input to the host, so on high-latency connections steering responds a little late.

Progress is saved to `%APPDATA%\Godot\app_userdata\CoopShipExplorer\savegame.json`. To start
over, use Settings › Reset campaign progress.

## Project layout

```
autoload/      game.gd (profile, upgrades, ship stats, settings, input), net.gd (sessions), sfx.gd (synth audio)
scenes/main.tscn
scripts/
  main.gd              level switching (replicated via MultiplayerSpawner), menus
  levels/              homebase.gd (shop), mission.gd (cave streaming, population, director, mission end)
  cave/                cave_gen.gd (signed-distance-field cave + surface nets), cave_chunk.gd (threaded build, rock shader)
  station/             station_builder.gd (waystation pad, pier, supply room), supply_crate.gd, run_items.gd (supply catalogue)
  ship/                mothership.gd (incl. docking, supplies, auto cannons), ship_builder.gd (hull + interior layout), turret.gd, scout.gd
  crew/                crew_member.gd (first-person avatar, stations, blaster, toolkit), crew_bot.gd (bot AI)
  enemies/             alien.gd (spitter/critter/infiltrator), boarder.gd, nest.gd
  minerals/            deposit.gd, mineral_chunk.gd
  fx/                  fx.gd (particles, flashes, tracers), projectiles.gd
  ui/                  hud.gd, main_menu.gd, pause_menu.gd, settings_panel.gd
  common/              models.gd (procedural meshes), net_util.gd, ui_theme.gd
  dev/autotest.gd      automated test runs (see below)
```

Balance numbers to tweak:
- Ship stats and upgrade effects: `Game.ship_stats()` and `Game.UPGRADES`.
- Turret weapons: `Mothership.WEAPON_DEFS`.
- Emergency blast: the `BLAST_*` constants at the top of `mothership.gd` (radius, damage, hull and
  fuel cost, cooldown).
- Crew bots: the constants at the top of `crew_bot.gd` (repair threshold, gun range, aim speed,
  reaction time, self-defence range, fire rate and accuracy, and when it counts as safe to mine). Bots count as half a crew member for difficulty (`MissionLevel.difficulty()`).
- Waystations: spacing and placement (`STATION_*` in `CaveGen`), docking range, speeds and what a
  docked ship gets per second (`LAND_RANGE`, `DOCK_*` in `mothership.gd`), the safe-zone radius
  (`StationBuilder.SAFE_RADIUS`), what each crate does (`RunItems` and `Mothership._apply_item()`),
  what a station stocks (`Mothership._station_offer()`) and the auto cannons (`AUTO_*` in
  `mothership.gd`).
- Alien stats: `Alien.KIND_STATS`.
- Mineral types: `Deposit.TYPES`.
- Spawn pacing: `MissionLevel._director()` and `_populate()`, plus the `Nest` constants (hatch
  intervals, live caps, `HATCH_GAP`, `HIT_AGITATION`).
- Side gun reach towards the bow: `ShipBuilder.GUN_FORWARD_REACH`.
- Bought auto cannons and Laser Overcharge: `Game.UPGRADES` and `Game.ship_stats()`; their mounts
  are the first `ShipBuilder.EDGE_CANNONS` entries of `ShipBuilder.AUTOCANNON_MOUNTS`.
- Cave shape: the radius, path and side tunnels in `CaveGen`.

## Automated tests

`scripts/dev/autotest.gd` drives the game and saves screenshots to `user://autotest/`. It uses a
separate save file, so it never touches real progress.

```
godot --path . -- --autotest=smoke     # full solo mission loop (add --headless for speed)
godot --path . -- --autotest=combat    # every weapon, boarders, hull critters, nests, repairs, load
godot --path . -- --autotest=scout     # scout fuel run through a side tunnel and back
godot --path . -- --autotest=death     # ship destroyed -> payout -> shop purchase
godot --path . -- --autotest=soak      # long accelerated dive
godot --path . -- --autotest=bots      # crew bots: guns, repairs, giving way to humans, fighting boarders
godot --path . -- --autotest=botfight  # detailed log of two bots against a wave of tough boarders
godot --path . -- --autotest=blast     # emergency blast falloff, costs, cooldown, cockpit button
godot --path . -- --autotest=fxcheck   # blaster impact effects land where the shot hits
godot --path . -- --autotest=shadows   # headlight shadow views for checking artifacts
godot --path . -- --autotest=host      # host with a full bot crew; run --autotest=join in a second instance
godot --path . -- --autotest=host_late # client joins mid-mission
godot --path . -- --autotest=station   # waystation: land, ramp, carry and fit supplies, defences, liftoff, auto cannon
godot --path . -- --autotest=notes     # bots on the mining laser, guns covering the bow, bought auto cannons, laser overcharge, nest pace
godot --path . -- --autotest=host_station  # with --autotest=join_station: a client carries a crate aboard
```

## Known limitations

- The ship and levels are built in code, so the editor shows only the empty `Main` scene. Run the
  game to see the content.
- Vehicles are simulated on the server without client-side prediction. That is fine on a LAN, but
  piloting from a distant client feels slightly delayed.
- The scout passes through the mothership's hull instead of colliding with it.
- Audio is simple synthesised effects with no music.
