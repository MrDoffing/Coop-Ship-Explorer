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
| Pilot seat | Cockpit (front, behind the glazed nose) | Throttle, turning, climb/dive, in first person at the cockpit's dashboard (see **The cockpit** below). The autopilot follows the tunnel while the throttle stays set, so a solo player can leave the seat. |
| Gun pods | Gunnery deck windows | Glass gun pods outside the hull, each with a twin heavy machine gun on either side. The console takes you into the pod (see **Gun pods** below). Side pods swing past straight ahead, so they can fire in front of the nose too. |
| Mining laser | Next to the cockpit door | A beam that breaks crystal deposits into chunks, which the tractor field pulls back to the tip of the laser. |
| Scout bay | Starboard side room | You climb into a scout and launch it: a small fighter you fly in first person (see **Scouts** below). It fits through the narrow side tunnels where fuel crystals grow and carries fuel back when it docks. Its cannons and missiles can hit critters on the hull, which the gun pods can't reach. |
| Repair panels | Engine room (rear), weapons room (port side) | Use the toolkit on these to repair the engine and weapon systems. |
| Emergency blast button | Cockpit: the big red button on a pedestal right of the pilot seat, under a flip cover | See **Emergency blast** below. The pilot presses **B** (or looks at it and clicks); anyone else can reach over and press **E**. |
| Install hub | Engine room, port wall | Fit upgrades, repair kits and auto turrets bought in a waystation shop. Its screen lists what was fitted this dive. |
| Cargo ramp | Stern, behind the engine room | Opens by itself when the ship lands at a waystation or an abandoned station and closes for liftoff. |

### Motherships

| Ship | Unlock | Gun pods | Mining lasers | Scouts | Turret slots | Notes |
|---|---|---|---|---|---|---|
| Prospector | standard | 2 (port, starboard, on towers out from the hull) | 1 (under the chin) | 1 (belly) | 1 (up to 4) | The all-rounder: hull 400, shield 120. |
| Vanguard Carrier | 250 RP | 1 (bow, front edge of the flight deck; it turns all the way round) | 1 (under the chin) | 2 combat scouts on the flight deck | 1 (up to 4) | Combat scouts have +60% hull, +50% damage and +15% speed. |
| Excavator Prime | 300 RP | 1 (front corner) | 2 (on mining arms) | 1 (roof) | 2 (up to 4) | Its lasers mine 45% faster and do 60% more damage to aliens. |
| Dreadnought | 400 RP | 3 (port, starboard, front corner; armoured, +25% damage) | 1 (on the tip of the ram) | 1 (belly) | 2 (up to 5) | Big and slow: hull 640, shield 160. |

Turret slots hold **auto turrets**: small automatic guns that shoot any free-flying alien above
their part of the hull. Every slot launches empty; buy turrets in waystation shops to fill them.

### Gun pods
Taking a gun console puts you in its gun pod, in first person: a glass ball held together by bolted
steel strips, with your seat, a control panel in front and a twin heavy machine gun on each side
(two barrels over and under, so four in all). Everything you need is in the pod, not on the HUD:
- **The sight:** a reflector sight in front of the window. Its glowing ring is always in the middle
  of your view, and the four barrels' fire converges on whatever is under it. Hold **RMB** to lean
  in to the sight.
- **Aiming:** the pod is heavy. It swings after the mouse at most about 140° a second, and its
  traversing motors whine low while it turns (louder and higher the faster it swings).
- **All the way round:** the Vanguard's bow gun turns all the way round, so it can shoot behind the
  ship too. While the ship itself is in its line of fire (the flight deck, the island) the guns hold
  their fire, like a bomber turret's interrupter, and the belt screen says HULL IN LINE.
- **The screens** on top of the control panel: rounds left in the belt (with a belt gauge), barrel
  heat (green, amber, red), the weapon systems' health, and lamps for ready, belt change, heat and
  weapon systems. A stencil on the panel says which keys do what.
- **The belt:** 240 rounds, about 15 a second. When it runs dry a new belt is loaded by itself,
  which takes 4 s (the screen shows LOADING).
- **Heat:** every round heats the guns and the heat bleeds off by itself. Holding the trigger from
  cold takes about 8 s to reach full heat. The barrels glow as they get hot and smoke more the
  hotter they are: wisps from about 30% heat, thick smoke at full heat, and every burst puffs smoke
  out of the muzzles (more when hot). The guns sound hotter too: their bark rises in pitch as the
  barrels heat up, smoothly, to a quarter higher at full heat. Every round
  fired at full heat damages the **weapon systems** (0.5% each, with sparks in the pod and a warning
  buzzer). The engineers repair them at the repair panels as usual; at 0% every gun and mining
  laser goes offline until they are repaired to 50%. Fire in bursts.
- **The rocket launcher:** a pod can carry the **Multiple Rocket Launcher** instead of its machine
  guns: a tall launcher box on each side of the pod, eight rockets in each (sixteen in all). Hold
  **LMB** and they leave one at a time, the boxes taking turns (about eight a second): they scatter
  wide, fly a little crooked at first, speed up, and home in on an alien that comes within about
  18 m ahead of them. Each hits for 38, and its blast hurts what is round it (55% of that, out to
  4.5 m). An empty tube is reloaded one rocket at a time, one every 0.8 s, so a full reload takes
  about 13 s; the screens show the rockets left and the loader. Guns for the pods come in crates
  from the waystation shops: carry one to a gun console and press **E** there to mount it (the gun
  taken off comes out in a crate at your feet, to mount again some time).
- Everyone else sees you sitting in the pod, and the pod turning and firing.

### The cockpit
Every ship's nose is a glazed greenhouse of grimy glass panes in bolted steel frames, and the pilot
sits right behind it, in first person: the glass wraps round the seat, so you see the tunnel ahead,
to the sides, up and down past the dashboard. The mining laser hangs under the chin, ahead of the
glass (on the Excavator the lasers are on the mining arms either side; on the Dreadnought it sits on
the tip of the ram). Everything the pilot needs is in the cockpit, not on the HUD (the ship panel
and the pilot read-out are hidden while you sit there, and a station's marker only shows while the
station is in view through the glass):
- **The dashboard:** left of the terminal, a luminous **fuel** gauge and **speedometer** side by
  side, with figures round their scales and the value in a window under the needle; right of it,
  on a bolted plate of their own, vertical bar gauges for **hull** and **shield** side by side, with
  their figures under them (say 320/400). A small red light over the fuel gauge and over each bar
  flashes when it runs critically low (fuel under 20%, hull under 30%, shield under 25% or down).
  Over the terminal, three lamps: AUTOPILOT (a lit switch), INTRUDER and SURGE.
- **The terminal:** a green-text screen in the middle of the dashboard with the thrust, speed,
  depth, the systems, the emergency blast and the hostility, and what's next: the next station and
  how far, IN RANGE - [L] LAND, docking, waiting for crew to come aboard, SURGING - FULL THRUST.
- **Side panels** on cabinets either side of the seat. Left, the **engine**: a drawing of the engine
  whose fan turns and exhaust burns with the thrust (its casing flashing red when it is badly
  damaged, all of it red when it is offline), its state, integrity, thrust and revolutions. Right,
  the **weapons**: the weapon systems' state, and for each gun pod its belt (the rounds left, or the
  new belt loading) and its barrels' heat.
- **Camera feeds** from five cameras on the hull, on green monitors (they flicker along like old
  closed-circuit television). The **rear** camera, high on the stern looking back for anything
  following, hangs over the dashboard like a rear-view mirror. The **port** and **starboard**
  cameras, at the front corners of the hull looking back along its flanks, stand on arms off the
  dashboard's ends like a car's side mirrors. The **spine** and **belly** cameras, on brackets
  above the roof and below the belly, look back and a little away from the hull (it fills about a
  third of their picture); their screens are set into the dashboard. They show the rock the hull is
  about to scrape and the critters clawing at it. The feeds looking back are mirrored, like
  mirrors, so what is on your left is on the left of the screen.
- **The controls:** the **thrust lever** on the left console (W/S), the **gear stick** on the right
  console, which leans as you turn (A/D) and climb or dive (Space/Ctrl), and on a pedestal right of
  the stick the **big red button** for when things go bad (B), under a flip cover.
- **Looking around:** the mouse turns your head (as far as you can turn it in the seat); hold
  **RMB** to lean in towards what you look at, to read a screen or peer out through the glass.
  Look at the AUTOPILOT switch or the big red button and its key shows over it; click (**LMB**) to
  press it.
- **Scraping:** the hull grinding along rock throws sparks and screeches (the cameras catch it).
  It does no damage, but hitting rock hard still does.
- Nobody can climb over the dashboard into the nose: an invisible barrier closes off the front of
  the room.
- Everyone else sees the levers and dials move and the button's cover flip up; the camera feeds
  run while you are in or near the cockpit.

### Scouts
A scout is a small fighter with a cockpit for one. Take its console in the scout bay and you climb
in and launch, in first person: the seat is built into a tight cockpit under a bubble canopy of
greasy glass (smears, wipe marks and drips that catch the light) in bolted steel straps, wide and
high so you see all round, with panels close at hand on your left and right and the gunsight in
front. A lamp on your side of the glass glints softly in it (smeared dull where the grease is),
and a lamp beyond it glares through the smears round it, like a dirty windscreen at night; the
gun pods' and the cockpit's glass and your helmet's visor do the same. Everything you need is in
the cockpit, not on the HUD:
- **Flying:** the mouse steers (the scout banks into turns), WASD moves, Space/Ctrl go up and down.
  **Shift** fires the **booster**: it drives the scout straight ahead at 2.4 times its top speed,
  and the view widens and shakes as it picks up speed. It heats the scout, though.
- **The cannons:** two, one each side under the belly, firing in turn (**LMB**) at whatever is under
  the gunsight's glowing ring. The magazine holds 80 rounds and reloads by itself once it runs dry
  (2.5 s; the RELOAD lamp flashes).
- **Heat:** every round and every second of boosting heats the scout, and the heat bleeds off by
  itself. Firing alone from cold reaches full heat in about 8 s, boosting alone in about 8 s too,
  both at once in under 3 s. At full heat the cannons and the booster cut out (OVERHEAT) until the
  heat is back down to 45%, about 4.5 s later.
- **Missiles:** four, two under each wing (the outer ones go first, the sides taking turns). Hold
  **RMB** on an alien ahead of you: a crosshair on the canopy glass closes in on it, with its
  distance (SEEK), until it locks on about a second later (LOCK, and a steady tone). Each **LMB**
  click then fires one missile, which homes in on it (or on another alien nearby if that one dies
  first) and bursts in a big blast: 150 damage to what it hits, and splash damage to everything
  within 9 m (less further out). Without a lock, or with none left, a click only buzzes. All four
  are reloaded when the scout docks.
- **The panels:** on the left, thrust (the speed, with the booster's zone beyond the top speed), hull
  integrity and the fuel cargo. On the right, the cannons' magazine (the rounds left on a green
  screen, and a bar), the missiles (a drawing of the scout with its four missiles under the wings,
  green while loaded, red once fired) and a homing needle pointing the way to the scout's dock, with the
  distance. In front, under the gunsight, the heat gauge, four lamps (HULL, HEAT, RELOAD, LOCK) and
  the keys stencilled below them.
- **Damage:** as the hull takes heavy damage the canopy cracks. Each crack starts at the edge of the
  glass, beside a steel strap or along the sill, and splinters out over it; the first appears at
  85% hull and more follow further down, each growing longer (with a creak) as the hull drops.
  Below 30% the hull is critical: an alarm sounds, the HULL lamp flashes and
  red lights pulse in the cockpit. Hitting rock at speed hurts, but one crash takes at most 45% of
  the hull.
- **Docking:** fly back to the mothership's scout dock (the needle shows the way, and a marker on the
  glass shows the dock once it is ahead) and press **E** within 15 m. The fuel cargo goes into the
  ship's tank and the scout is rearmed and cooled down. Holding **E** recalls the scout from anywhere
  (its cargo is lost).
- Everyone else sees you in the cockpit, the missiles leaving their pylons and the cannons' muzzle
  flashes. Out in the scout nothing aboard the mothership can reach you: boarders leave you alone.

### Interiors
Each ship has a layout of its own, so a new ship feels fresh. Every one starts at the cockpit
behind the glazed nose and ends at the cargo door.
- **Prospector:** a narrow cockpit, the gunnery deck with the guns at its side windows, a hall with
  the weapon systems room (port) and the scout bay (starboard), and the engine room with the
  install hub.
- **Vanguard Carrier:** a bridge with three seats (bow gun, mining laser, and the pilot's ahead of
  them at the glazed nose under the flight deck's overhang) and a
  narrow spine corridor with four rooms off it: Flight Ops A and B (one scout console each, with a
  window), the weapon systems room and the quartermaster's store with the install hub. Twin
  reactors in the engine room, with the engine panels on the side walls.
- **Excavator Prime:** a mining control room (the pilot ahead of the two laser consoles, looking
  out between the mining arms), then an
  open ore hall round a crusher with the weapon systems panels built into its sides. The gun
  console is at the starboard window, the scout lift console behind it, and the install hub on
  the port wall.
- **Dreadnought:** taller and wider. A bridge far forward (helm, with the mining laser and forward
  gun consoles at its side windows), the combat information centre with the port and starboard
  batteries and a plotting table, twin corridors round the armoury core (weapon systems) with the
  magazine (install hub) and the scout bay either side, and twin reactors.

### Sounds from outside
Shut in, you hear the world outside muffled. Aboard the mothership (walking about or at any of its
stations, the pilot seat included) everything outside the hull comes through it dull and quieter:
the gun pods firing, aliens, explosions, the bulkhead doors. From a gun pod or a scout's cockpit
it comes through the glass, a little less muffled. What is in there with you sounds clear: the
ship's insides aboard, your own guns and engine in the pod or the scout.

### Ship systems (from the spec)
- **Shield** absorbs damage. When it breaks, it reboots after a few seconds and then recharges.
- **Hull** takes damage once the shield is down. The crew can't repair it in flight, only with
  hull repair kits from a waystation shop. At 0 the ship is destroyed and the crew returns to
  homebase.
- Hull damage also spills into the **engine** and **weapons** systems, and firing a gun pod at
  full heat damages the weapon systems too. Either one goes offline at 0% and comes back online
  once it is repaired to 50%. The crew can also repair before that.
- **Fuel** burns while flying (faster at high throttle). With an empty tank the ship flies at low
  power, the shield cannot recharge and the ship takes extra damage. The scouts use no fuel.

The ship panel (top left) shows each value as a percentage inside its bar and as an absolute value
beside it (in the pilot seat it is hidden: the cockpit's dials and lamps show the same; out in a
scout it is hidden too, and so is your health). Walking about, your health is on your helmet's
VITALS display instead (see **The suit**).

### Aliens
- **Spitters** keep their distance and spit acid at the ship (or a scout).
- **Critters** latch onto the hull and scratch it. Only the scouts can shoot them off.
- **Infiltrators** latch onto a roof hatch. Once the shield is down they cut in and become
  **boarders**, which attack the crew and sabotage machinery. Kill them with your hand weapons.
- **Nests** sit on cavern walls, surrounded by egg sacs that hatch aliens forever. They hatch
  faster when the ship gets close or a sac is hit (about twice as fast, at most one hatchling every
  1.6 s and five alive at once). Destroy every sac to kill the nest; it drops rare minerals. A sac
  has 55 health near the surface (its health grows with depth half as fast as the aliens').
- Living in **abandoned stations** (see below): the **stalker**, **barnacles** on the ceilings,
  packs of **crawlers** round their nests, and **acid spiders**.

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
| **Surging** (the meter is full) | the alarm goes off and the aliens keep coming, in ones and twos: the first 10 s after the alarm (time to react and open the throttle), then every 9 s or so, closing in to about every 2 s over the next 40 s. It lasts until the ship docks at a waystation, so head for the next one at full thrust. |

Ambushes come more often and in bigger packs deeper down and with a bigger crew.

**Ambush warning:** the ship's motion tracker picks up every ambush 6 s before it arrives. Its
ping sounds all over the ship, faster and higher as the pack closes in, and a warning at the top of
the screen says whether it comes from ahead or astern and counts down to it.
While the hostility surges, the SURGE lamp blinks, the terminal says so, the meter flashes red and
the ship's red alarm lights pulse.

Difficulty rises with depth. Minerals get rarer and more valuable deeper down (Ferrite 2 CR,
Cobaltite 4, Aurium 6 and Voidstone 9 per chunk), but even diligent mining buys only part of
a shop's stock: choose what matters. The tunnel is about 56 m across (radius 28 ± 7 m), wider
in caverns and narrower where it straightens out for a waystation.

### Emergency blast
A shockwave from the shield emitters, set off by the big red button in the cockpit: the pilot
presses **B** or looks at the button and clicks (its cover flips up and the button goes down), or
anyone else standing behind the pilot seat on the right reaches it with **E**.
- **Damage:** everything within 42 m takes damage that falls off with distance. Point blank is
  lethal to almost anything; spitters die out to about 30 m. That includes critters and
  infiltrators latched onto the hull, and nearby egg sacs.
- **Cost:** 6% of max hull and 12 fuel. It also drains the shield completely, which then has to
  reboot.
- **Cooldown:** 15 s, shown as the BLAST bar on the HUD and on the cockpit's terminal; the button
  glows while the blast is ready.
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
  every station further down). One is always a **hull repair kit** (restores 30% hull), one a
  **gun for the gun pods** (one the ship doesn't carry on every pod yet: at first that is the
  Multiple Rocket Launcher), and three are random upgrades and **hand weapons**: armour plating,
  shield cells and coils, turret coolant (faster fire and cooling), targeting modules, fuel tanks
  and injectors, thrusters, mining lens,
  laser overcharge, tractor booster, repair nanobots, surge dampers, scout plating, blasters, cargo
  pods and thrusters, the gunsmith kit, power tools, crew armour, the nine hand weapons, and
  **auto turrets** (more likely while the ship has an empty turret slot).
- **Buying and carrying:** look at an item and press **E** to buy it, then **E** again to pick up
  the crate. You can't use tools while carrying. Press **G** to put it down. Walk it up the ramp
  and fit it:
  - **Hand weapons** aren't installed: look at the crate and press **F** to swap (see below).
  - **Guns for the gun pods** are mounted at a gun console (see **Gun pods**).
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
- **Inside:** a military mining outpost of olive-drab and bronze plate, generated from the cave's
  seed: five to eight rooms joined by corridors that bend round them and branch off each other
  (T-junctions, and now and then a loop), ringed every few metres by heavy octagonal frames, with
  pipes along them, caged amber lamps and grated floors. Rooms are plain, have an alcove, or are
  L-shaped, with ribbed walls, furniture along them and furniture or machinery in the middle. A
  sign over each doorway (on the corridor side) names the room:
  - **Science labs:** specimen tanks of glowing, bubbling fluid with something floating in them (a
	foetal alien, a crewman half turned into one, a crawler; some tanks drained, some smashed and
	empty), lab tables and benches with microscopes, flasks and terminals.
  - **Storage, crew quarters, mess halls, med bays and workshops:** shelves and crates stacked on
	pallets; beds with side tables and lockers; long tables with benches and a serving counter;
	surgery tables; machine tools and workbenches.
  - **The control hub** (in about three outposts out of five): a desk with the station's computer,
	a big map of the station on a board behind it and, up over the board, four monitors showing
	live feeds from cameras high in the corners of other rooms. See below.
  - **Armory:** gun racks, ammunition and weapon benches; most of its salvage is hand weapons.
  - **The generator room** (in about two outposts out of three): see below.
  - **Secure storage**, the vault: the dead end furthest in, behind a keypad lock, with the best
	salvage.
- **Salvage:** rooms hold **salvage crates** by their walls (free: upgrades, hull repair kits,
  hand weapons and auto turrets); a room behind a sealed door holds more.
- **Credit boxes:** heavy steel strongboxes with brass corners, a thin amber light under the lid
  and what they are worth on an amber readout (more deeper down, more in sealed rooms and the
  vault). Pick one up (**E**), carry it aboard the ship and put it down (**G**, or **E** at the
  install hub): its credits go into the dive's credits for the shops.
- **The generator:** an outpost with a generator starts dark: only red emergency lamps glow, and
  a door or two (NO POWER on them, a dark lamp over them) won't open. Pull the generator's starter
  cord (**E** at the handle on its side) until the engine catches, two or three pulls. It shakes
  and chugs, its flywheel spins, the working lamps come back on in a wave from the generator room,
  the emergency lamps go out, and the doors that needed power grind open, letting out whatever
  was shut in (often the stalker). The noise draws the stalker too.
- **Keypad locks:** the vault (and sometimes one more dead end) is locked. Look at the lock's
  panel beside the door and press **E**: your view closes in on it and its service hatch swings
  open. Four lamps across its top are lit in a row of colours; behind the hatch six cords run
  tangled from six digits on the left to six coloured terminals on the right. Follow each lit
  colour's cord back to its digit and key the four digits in, in the lamps' order (look at a key
  and click **LMB**, or type them; C clears, < deletes; **E** or walking off leaves, and a hit
  pulls you out). The right code opens the door. A wrong one costs a try (the three lamps beside
  the display); after the third the door **locks down**: a steel shutter slams down in front of
  it, the corridor flashes red, an alarm sounds (drawing the stalker) and that door never opens
  again.
- **The control hub** (a rough first version) runs every door in the station. In an outpost with
  one, every doorway has a working door with an id (D10 to D59) on a plate over it, and a dead end
  or two are locked from the hub (CONTROL LOCK on the door): a horde of boarders is shut in behind
  each, besides whatever else lives there. The hub needs power: with a generator, it stays dark
  (NO POWER on its map) until the generator runs. Then:
  - **The map** on the board shows the rooms with their names, the corridors and every door with
	its id, green while it is open, red while it is locked (dark red: locked down); a room shut in
	behind locked doors is red and says LOCKED. It is turned so that up on the map is the way you
	face looking at it, and a marker says YOU ARE HERE.
  - **The computer:** look at it and press **E** to sit down at it: your view closes in on its
	green screen, and what you type goes on it. **Enter** sends the line, **Backspace** deletes,
	**Esc** gets up (a hit does too). The commands: `HELP`; `DOORS` (every door, its state and its
	room); `LOCK D23` and `UNLOCK D23` (any door but the station's front door, not one locked down
	for good, and a door won't come down on someone or something standing in its doorway). Find a
	locked room's door on the map and unlock it; whatever was shut in there hears it open. Locking
	doors behind you shuts aliens out (they can't get through a shut door). The answers show on
	the screen for everyone, and several crew can use it at once.
  - **The monitors** run while you are in the hub (one feed a frame, in turn).
- **Sentry turrets:** a station holds one or two, and one more for every room locked from the
  control hub (three at most): steel boxes much like the salvage crates (their glowing bands
  orange), with a big yellow double chevron on the lid pointing the way they face (the barrel's tip
  shows in a hatch at that end). Pick one up (**E**) and carry it like any crate; set it down in a
  station (aboard the ship it won't open) and press **F**: the lid's halves swing open and a heavy
  machine gun rises on its post.
  It guards 45° either side of its front, swings to the nearest alien it can see within 24 m there
  and fires at it, fast and hard (16 a round, about 12 rounds a second; much better than any hand
  weapon), until its 300 rounds run out; the rounds left show on a display at its back. Aliens it
  hurts turn on it; the others may run past it after the crew. **F** folds an intact one up again
  (it keeps its rounds) to carry it on. Once it has taken enough damage it is wrecked for good:
  bent over, sparking and smoking a little.
- **Aliens**, tougher deeper down (the first room is always clear):
  - **The stalker** (in most outposts): taller than a man, glossy black, all limbs, with a long
	swept-back head and a bladed tail, and it takes a lot of shooting. It roams the station. When
	it spots someone it rushes them, claws them two to four times and runs off to hide out of
	sight, then comes back for more. Badly hurt, it flees to its lair and heals there before it
	hunts again.
  - **Barnacles** grow flat on the ceilings of corridors and rooms, crusted over with the
	ceiling's own grime so they are hard to see; now and then a drop falls from one. Their tongues
	stay in until you walk within about 2 m of the spot under one: then it lashes out, reels you in
	under it, lifts you off your feet and holds you there while it chews on you, until it is shot
	dead (you can still look up and shoot; your crewmates and the bots can too). It can't reach
	through a wall.
  - **Crawlers**, like face-huggers, live in packs round their nest, a spongy growth of hollow
	tubes full of holes on a wall, the ceiling or the floor, and crawl over the walls and ceiling
	of their room. Step into their room and they leap at you off the walls, rake you and land on
	the floor, then scuttle back up for another go. They aren't fast and don't follow you out of
	their room, unless you shoot one: then the whole pack hunts the crew out to about 18 m from
	the nest for a while. The nest slowly breeds new crawlers (one every 30 s while nobody is
	near); shoot it to stop that.
  - **Acid spiders** walk on four long legs (each foot steps on its own as the body moves), up
	walls and across ceilings as easily as floors. Aggressive: they spot you from further off and
	never stand still for long, scurrying from spot to spot round you, and stop only to rear up
	and spit a glob of acid (it arcs).
  They notice crew within sight, or close enough to hear by the open ways (not through a wall or
  a shut door), and chase them through the station along its corridors and open doors, but never
  into the ship. They go for whoever is closest, crew bots as well as players, turn on whoever
  shoots them, and a pack spreads out over the crew instead of all going for one. Lost track of
  you, they make their way back to where they were by the corridors too.
- **Liftoff:** the pilot presses **L** once everyone is back aboard. Crates and aliens left
  behind stay in the station (and its doors and generator as they were), in case you come back
  before the next waystation.

### Hand weapons
Everyone starts a dive with the **Pistol**. The others come in crates, from waystation shops or
abandoned stations. Look at a crate holding one and press **F**: you take that weapon and your old
one goes into the crate. You can also carry these crates around with **E** like any other. The
Gunsmith Kit from a shop boosts every hand weapon.

You handle them in first person, and there are no hands: the weapon does all the moving.
- **Relaxed:** walking about, or a moment after your last shot, you hold the weapon low across your
  body. A click brings it up and fires (that takes about a tenth of a second).
- **From the hip (LMB):** quick, but the shots scatter widely.
- **Aimed (hold RMB):** the weapon comes up to your eye and you look down its own sight; the view
  zooms in a little and you walk at about half speed. The first shot goes where the sight is, but
  keep firing and the shots spread wider (they settle again within half a second or so). Each
  weapon has a sight of its own: iron sights with glowing dots on the Pistol (and on each of the
  Dual Pistols, which come up just under your line of sight, closer together), a notch and a glowing
  bead on the Revolver, a peep and a hooded post on the Submachine Gun, a reflex sight with a
  glowing ring on the Pulse Rifle, a round holographic sight with a cyan ring on the Photon Rifle, a short
  scope on the Marksman Rifle (you look through its eyepiece at a red chevron, zoomed 1.8 times,
  and still see the world round the scope), a bead and a ghost ring on the Shotgun, a WW2-style
  ring sight on the Multiple Grenade Launcher and an open ring on the Storm Lance.
- **Kick:** every shot kicks the weapon back and the view up (most of that comes back by itself),
  with a muzzle flash. Sprinting lowers the weapon; firing or aiming stops a sprint. There is no
  crosshair: the weapons have their sights.
- **The trigger:** most weapons fire for as long as you hold LMB. The Revolver is semi-automatic:
  one shot a click, as fast as you click.
- **The display** is built into the top of every weapon at the back, turned to you under a little
  hood (like the guns in Halo): its rounds left (or its heat on a bar), in green. You read it from
  the hip, and it sits just under the sight when you aim. You hear it too: the last few rounds of
  a magazine each tick hollow and the last one rings as it leaves, and an energy weapon's report
  rises as it heats up.

There are two kinds:
- **Magazine weapons** (Pistol, Dual Pistols, Revolver, Submachine Gun, Pulse Rifle, Marksman
  Rifle, Shotgun, Multiple Grenade Launcher): most throw a spent casing out of the ejection port with every shot,
  which bounces, rolls and lies on the floor for a few seconds before it is gone (the Shotgun's
  shells come out as its pump racks after each shot). Once the magazine is empty the trigger only
  clicks, hollow (the Pistol's slide locks back): press **R** to reload (you can also top it up
  early). The old magazine drops to the floor (it is gone a few seconds later), the new one slides
  in and clicks home, and the slide or bolt is racked. The Revolver keeps its cases in the cylinder:
  to reload, it tips up, the cylinder swings out on its crane, the spent moon clip (six cases on a
  steel star) drops out of the back, a full one goes in and the cylinder snaps shut. The grenade
  launcher's cylinder swings out the same way, throwing out its six big cases. Switching to the
  toolkit, taking a station, picking up a crate or bringing out the scanner cuts a reload short. A
  weapon you take out of a crate comes loaded. Crew bots reload by themselves.
- **Energy weapons** (Photon Rifle, Storm Lance): no magazine, but every shot heats them up
  (their coils, fins and chambers glow hotter) and the heat bleeds off by itself. At full heat the
  weapon overheats: it vents steam and stays locked (the trigger only fizzles) until it has cooled.
  **R** vents it early.
- **The Dual Pistols** (Dual Berettas, in a way): a slim stainless pistol in each hand, either side
  of the view. Hold LMB and they fire in turn, right, left, right..., each with its own slide,
  flash and casing; each gun's display shows its own rounds (15 each), and a reload swaps both
  magazines at once. Quick, but wild from the hip.
- **The Revolver:** fire it slowly and every shot goes where the sights are; fan it and each shot
  scatters wider and kicks harder than the last (by the fifth quick shot the scatter is about six
  times as wide and the kick three times as hard): a wild-west shootout. It settles again within
  half a second.
- **The Submachine Gun** sprays a 64-round drum at 15 rounds a second, with a wide scatter and a
  strong climb. Aiming tightens it but never makes it accurate, and its rounds hit only half as
  hard beyond about 25 m. The Shotgun's pellets lose most of their punch beyond 20 m too.
- **The Marksman Rifle** fires heavy rounds at a steady pace; each goes through the first alien it
  hits into the one behind it.
- **The Multiple Grenade Launcher** is fully automatic: hold LMB and it fires its six 40 mm grenades
  one after the other, in an arc (its sight is set for about 10 m). A grenade clunks and bounces off the walls and floors, rolls, and goes off when its fuse
  runs out 1.6 s after the shot, or at once when it strikes an alien; a red lamp blinks on its tail
  so you can follow it in the dark. The blast hurts every alien within 6.5 m it can reach (not
  through a wall), never the crew, and shakes your view if you are close.
- **The Photon Rifle** fires glowing bolts, like a blaster: each flies to where the shot lands
  (about 95 m/s), lighting the corridor as it goes, and strikes there.
- **The Storm Lance** charges while you hold LMB (its prongs crackle and its hum rises) and
  lets the bolt go when you release it. The bolt goes where you aim it: it does not seek aliens
  out, it strikes the one in its way (or one it passes within a hand's breadth of) and jumps on
  to the closest alien within 7 m of that one, up to four
  more times, each jump keeping 72% of the damage. A fuller charge hits harder and heats more; let
  go too early and it only fizzles. Holding a full charge slowly heats it up. The bolt is white-hot
  and flickers, every alien it strikes flares, it cracks like thunder where it first hits, and
  letting it go shakes your view.

| Weapon | Kind | Damage | Rate | Magazine / heat | Notes |
|---|---|---|---|---|---|
| Pistol | magazine | 22 | 4.5 shots/s | 12, 1.5 s reload | The sidearm everyone starts with. |
| Dual Pistols | magazine | 18 | 8.3 shots/s, the guns in turn | 2 x 15, 2.2 s reload | A gun in each hand. Wild from the hip. |
| Revolver | magazine | 40 | as fast as you click | 6, 2.3 s reload (moon clip) | Semi-automatic. Quick shots scatter and kick harder and harder. |
| Submachine Gun | magazine | 7.5, down to 45% from 10 to 28 m | 15 rounds/s | 64-round drum, 2.6 s reload | Wide scatter and a strong climb, even aimed. |
| Pulse Rifle | magazine | 15 | 11 rounds/s | 40, 2.0 s reload | Rapid fire with a strong climb, an ammo counter on top. |
| Photon Rifle | energy | 11.5 | 10 rounds/s | 2.4% a shot (42 shots from cold), 1.8 s vent | The Pulse Rifle's energy twin: glowing bolts, glowing fins. |
| Marksman Rifle | magazine | 52 | 2.7 shots/s | 10, 2.3 s reload | Short scope. Each round goes through the first alien into the next. |
| Shotgun | magazine | 10 pellets x 15, down to 40% from 6 to 20 m | every 0.7 s | 8, 2.2 s reload | Slow, heavy pump action, pistol grip. Shreds anything up close. |
| Multiple Grenade Launcher | magazine | 80 blast, half at its 6.5 m edge | 2.8 grenades/s | 6, 3.0 s reload | Fully automatic. Grenades bounce about until they go off. |
| Storm Lance | energy | 30 to 85 by charge, then 72% a jump | 0.9 s to charge | 16 to 40% a bolt, 1.8 s vent | Goes where it is aimed, then jumps from alien to alien. |

The ship's guns are the gun pods' heavy machine guns (see **Gun pods**): 7 damage a round, about
15 rounds a second from the four barrels, tracer rounds that converge on the sight. The older ship
guns (Pulse Cannon, Flak Cannon, Plasma Mortar, Rail Lance) are shelved for now: shops, salvage
and the shipyard no longer offer them.

### The suit
Walking about, you see the world from inside your helmet: its edge frames the view all round, thin
at the sides and the top, the sides bowed out a little and the bottom a shallow V, deeper at the
bottom where the instruments are. A steel shell with a rubber seal round the opening, panel seams
and rivets, the visor's hinges at the top corners, ribbed hoses round the lower corners, and set
into the chin, each on a flat plate pressed into the shell, the instruments (walking, they replace
the HUD's health bar), with a breathing vent and two status lamps between them:
- **VITALS** (bottom left): your health, as a figure, a bar and a heartbeat trace that races as your
  health drops (and for a while after a hit), and runs flat once you are knocked out. The red CRIT
  lamp beside it flashes while your health is critical.
- **SUIT** (bottom right): whether your visor is sealed, and out of the ship a needle pointing back
  to the ship's cargo door with the distance, and whether your flashlight is on. The SEAL lamp
  beside it shines green while the visor is sealed (red once it is cracked) and flashes amber while
  it moves.
- **The visor** (grimy glass, like the mothership's windows) swings down and seals by itself as you
  walk out of the ship (with a hiss and a moment of fog on the glass) and opens again back aboard.
  Light only gets into your helmet through the visor: a crewmate's lamp behind you leaves no glint
  on it and doesn't light the inside of your helmet, while a lamp ahead (say, a crewmate's
  flashlight pointed at you) glares through the grime round it.
  Once your health is down to half it cracks from its edges, more and further as your health keeps
  dropping (below 30% the suit beeps too); the cracks seal over once you have recovered past 62%.
- **The scanner:** hold **Q** to swing the echolocation scanner on your suit up in front of you
  (your weapon goes down, so you can't fire meanwhile). It pings like a boat's radar: a beam sweeps
  round its round green screen every 2 s (the top is the way you face) and paints the walls the
  ping bounces off as it passes: a clean outline of the rooms and corridors round you, out to 32 m.
  The ping goes through walls: it maps every wall within range, not only those in plain view. For
  now the picture is as clear as it gets (an experiment): every echo is where the wall is, with no
  false dots, no noise and no fading out with distance, and it stays at full strength until the
  beam paints it afresh. Aliens show as orange blobs and your crewmates as blue rings, where they
  are right now, each flaring as the beam passes. It only works outside the ship, in the stations:
  aboard, the hull drowns the echoes and it shows nothing but static.
- Everyone else sees you holding your weapon low, raised or up at your eye, and your scanner in
  front of your chest.

### Homebase
Research points (**RP**) are earned at the end of every dive: 1 RP per 10 m of depth, 10 RP per
waystation landed at and 2 RP per nest destroyed. The shipyard spends them:
- **Ships:** unlock the Vanguard Carrier, Excavator Prime and Dreadnought, and choose which ship
  to fly. The selected ship stands on the pad.
- **Upgrades** (per ship): Hull Plating (+15% hull), Shield Capacitors (+15% shield), Engine
  Tuning (+8% speed and handling) and Turret Slots (+1 auto turret slot, up to the ship's
  hardpoints; slots launch empty).
- **Armory:** hidden while the ship guns are shelved (every gun pod carries a heavy machine gun).
  Guns unlocked before stay in the save.

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
- **Outpost test:** a dive that starts with the ship landed at the first abandoned station, its
  ramp down and its aliens in their rooms, and a crate of every hand weapon (but the Pistol you
  carry) along the pier, where you stand: look at a crate and press **F** to swap, and try each one
  on the aliens. A test dive leaves the save alone (no research points, no record). It is also on
  the title screen (**TEST: OUTPOST + EVERY WEAPON**, debug builds only), and
  `godot --path . -- --test=outpost` goes straight into it.
- Cheats change the real save, so the first one keeps a copy of the profile from before
  (`savegame_precheat.json`). **Restore my save** brings it back.

### Crew bots
With fewer than 4 players, the host can fill empty crew slots with bots: **+ Bot / - Bot** in the
homebase crew panel. The choice is remembered for future sessions.
- **Repairs come first.** A bot drops its gun when the engine or weapon systems fall below 70% (or
  go offline) and repairs them to full. Bots split up when both systems need work.
- **Otherwise it mans a free gun pod.** It leads its shots at aliens and shoots egg sacs when no
  aliens are in range, in bursts: it stops at 85% heat and waits for the guns to cool, so it never
  damages the weapon systems.
- **Bots mine when it is quiet.** With no aliens near the ship for 6 seconds, a bot takes each
  free mining laser and breaks crystals in reach (never fuel crystals, and not next to a nest).
  When aliens show up it moves to a free gun. If every gun is taken, it turns the laser on the
  aliens instead.
- **Bots give way to humans.** Use a station a bot is manning and the bot steps aside. A player
  joining the session takes a bot's slot.
- **Bots defend themselves.** A bot that sees a boarder within 10 m gets up and fights it with its
  pistol, then goes back to its job. That includes a boarder attacking a crewmate next to it. Bots
  react and shoot a little slower and less accurately than players, reload when their pistol
  runs dry and top it up between fights. They don't hunt boarders
  elsewhere in the ship or fly scouts, and if knocked out they respawn like players.
- **Bots follow the host through abandoned stations.** When the ship has landed at one and the
  host walks out, the bots leave their jobs and tag along. They don't pick up crates, but they
  shoot any alien within 16 m, and go back to work once the host is aboard again.

## Controls

| Context | Keys |
|---|---|
| Walking | WASD move, mouse look, Space jump, Shift sprint, E use station, 1/2/wheel hand weapon/toolkit, LMB fire (from the hip) or repair, RMB aim down the sight, R reload (or vent), hold Q scanner |
| Shop and crates | E buy (look at a shop item), E pick up (look at a crate), E install (at the install hub or a gun console), G drop, F swap hand weapons with a crate |
| Abandoned stations | E pull the generator's starter; at a keypad lock: E open its panel, then LMB (on a key) or 0-9 key a digit, Backspace/Delete delete/clear, E (or walking) leave; at the control hub's computer: E sit down, type a command, Enter send, Backspace delete, Esc get up; sentry turrets: F open (set down in a station) or fold up, E pick up (folded) |
| Any station | E leave, Esc menu, Tab crew status |
| Pilot | W/S throttle, A/D turn, Space/Ctrl climb/dive, T autopilot, X full stop, B emergency blast, L land at / lift off from a waystation or abandoned station, mouse looks around the cockpit, RMB lean in, LMB press the AUTOPILOT switch or the red button you look at |
| Gun pods | Mouse aim (the pod swings after it), LMB fire (machine guns, or rockets one after another), RMB lean in to the sight; E at a gun console while carrying a gun's crate mounts it |
| Mining lasers | Mouse aim, LMB fire, RMB zoom |
| Scout | Mouse steer, WASD move, Space/Ctrl up/down, Shift boost (straight ahead), LMB cannons, hold RMB on an alien to lock on and LMB to fire a missile (one a click), E dock when close, hold E to recall the scout (its cargo is lost) |
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
  input to the host, so on high-latency connections steering responds a little late (except a
  scout's turning: its pilot's own client turns it at once, so the view never lags the mouse).

Progress is saved to `%APPDATA%\Godot\app_userdata\CoopShipExplorer\savegame.json`. To start
over, use Settings › Reset campaign progress.

## Project layout

```
autoload/      game.gd (profile, research points, ships, guns, ship stats, settings, input), net.gd (sessions), sfx.gd (synth audio, muffling through the hull and glass)
scenes/main.tscn
scripts/
  main.gd              level switching (replicated via MultiplayerSpawner), menus
  levels/              homebase.gd (shipyard), mission.gd (cave streaming, population, director, mission end)
  cave/                cave_gen.gd (signed-distance-field cave + surface nets, waystation halls, abandoned station hangars), cave_chunk.gd (threaded build, rock shader)
  station/             station_builder.gd (hall, bulkheads, pad, pier, shop), waystation.gd (bulkhead doors), supply_crate.gd, run_items.gd (shop catalogue, salvage),
					   abandoned stations: outpost_layout.gd (the plan: rooms, corridors, doors, door ids, themes, furniture), derelict_builder.gd (building them, waypoints),
					   outpost_props.gd (their furniture and machinery), derelict.gd (lamps, doors, generator, the control hub's feeds, map and computer), hack_panel.gd (keypad locks),
					   hub_console.gd (the control hub's computer), hub_map.gd (the station map on its board), sentry.gd (portable sentry turrets)
  ship/                ship_types.gd (the motherships' stats and layouts), ship_interiors.gd (each ship's rooms, consoles, panels, walking graph), mothership.gd (incl. gun pod simulation, docking, gates, shop, auto turrets, hostility), ship_builder.gd (hulls, glazed noses + interiors), cockpit.gd (the pilot's cockpit: dashboard, camera feeds, levers), turret.gd (mining lasers), gun_pod.gd (the manned gun pods: heavy machine guns or the rocket launcher), scout.gd (the scouts: flight, cannons, heat, booster, missiles), scout_cockpit.gd (the scout's canopy, cockpit and instruments), ship_marks.gd (decals on the hulls: markings, grime and wear, battle damage)
  crew/                crew_member.gd (first-person avatar, stations, hand weapon, toolkit), crew_weapons.gd (hand weapons: stats, models, effects), weapon_rig.gd (the weapon in the first-person view), helmet.gd (the helmet, its instruments and visor), scanner.gd (the echolocation scanner), crew_bot.gd (bot AI)
  enemies/             alien.gd (spitter/critter/infiltrator), nest.gd, boarder.gd (aliens on foot: the boarder, and the base of the abandoned stations' aliens),
					   stalker.gd, barnacle.gd, climber.gd (crawling over walls and ceilings), crawler.gd, hive.gd (crawlers' nests), spider.gd
  minerals/            deposit.gd, mineral_chunk.gd
  fx/                  fx.gd (particles, flashes, tracers), projectiles.gd (incl. the scouts' missiles and the gun pods' rockets), debris.gd (spent casings and dropped magazines), grenades.gd (the grenade launcher's grenades), marks.gd (decals, and the ones that fade)
  ui/                  hud.gd, main_menu.gd, pause_menu.gd, settings_panel.gd, cheat_menu.gd (homebase cheats)
  common/              models.gd (procedural meshes, mesh batching, loading the Blender-made assets), net_util.gd, ui_theme.gd
  dev/autotest.gd      automated test runs (see below)
assets/models/         Blender-made models (.gltf with baked textures): the Prospector's hull and fittings, the gun pod and its rocket launcher boxes, every hand weapon, the outposts' generator and furniture
assets/decals/         decal textures (markings, grime, battle damage, laser burns); assets/textures/: the tiling hull plating and the
					   abandoned stations' wall panels, tread plate and grating (tools/blender/outpost.py)
tools/blender/         the Python scripts that make them (see "Blender-made models" and "Decals" below)
```

### Blender-made models

Most of the game is still built from primitives in GDScript, but some assets are made in
Blender by scripts in `tools/blender/`: the Prospector's fittings and hull shape (`prospector.py`),
the gun pod (`gun_pod.py`), the Pulse Rifle (`rifle.py`), the other hand weapons (`weapons.py`, one
`weapon_<id>` asset each: `blender -b -P tools/blender/weapons.py -- pistol` rebuilds one, no name
all nine; the sights' dots and beads, the sight glass and reticles, the marksman rifle's scope and
the displays are still made in code), and the outposts' generator and furniture
(`outpost_generator.py`, `outpost_props.py`), and the gun pods' rocket launcher boxes (`mrls.py`). Small things get their wear baked in;
the Prospector's hull is not baked (a baked texture the size of a ship costs far too much memory):
it takes the tiling hull plating every mothership uses, and its grime and wear are decals (below). Each script models the asset in the
game's own coordinates, gives every part a procedural material (paint, plating seams, chipped
edges, grime, scratches; `lib.kind()`), bakes those into one texture atlas (albedo, occlusion /
roughness / metallic, normals, emission) and exports `assets/models/<name>/<name>.gltf` with its textures. Rebuild
one with Blender 4.2 (a GPU makes the bake take minutes rather than much longer), then let Godot
reimport (open the editor, or `godot --headless --path . --import`):

```
"C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" -b -P tools/blender/gun_pod.py
```

Preview renders and the baked textures land in `tools/blender/previews/`. In the game,
`Models.asset_mesh()` shows one of an asset's objects and can tint or swap a named material
(the pod's "Paint" takes the ship's colour, its "Hot" barrels glow, the rifle's "Accent" stripe is
the owner's colour). The Prospector's hull is lofted through the same sections as in
`ShipTypes`, so if those change, copy them into `prospector.py`. The glazing, screens, lamps,
labels, lights and everything that moves are still made in code.

The scripts write each texture's Godot import settings themselves (`lib.write_import()`):
VRAM-compressed with mipmaps for model textures and the plating (the editor's own 3D detection
never sees textures that are only loaded from code), lossless for decals.

### Decals

Godot's `Decal` paints a texture onto whatever surfaces are inside its box. `scripts/fx/marks.gd`
(`Marks`) makes them from the textures in `assets/decals/`, which `tools/blender/decals.py` draws
(noise for grime and damage, fonts and flat shapes for the stencils) together with the tiling hull
plating in `assets/textures/` (`Models.hull_plating()`); it runs in about 20 seconds:

```
"C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" -b -P tools/blender/decals.py
```

- **Markings, grime and wear on every mothership** (`ShipMarks.build()`, from `ShipBuilder`): the
  name stencilled on both sides, the registration on the bow and the roof, the guild's emblem,
  NO STEP, CREW HATCH, CARGO RAMP, TRACTOR FIELD, SCOUT BAY, KEEP CLEAR and FUEL, walkways between
  the hatches, lifting points, hazard signs and stripes; dirt on the roof, streaks down the sides,
  dust and mud on the belly, chipped paint round hatches, doors and edges, soot from the thrusters
  and round the gun pods. Placed from the hull's sections and seeded by the ship type, so every
  player sees the same ship. Per-ship positions: `ShipMarks.NAMES` and `HATCH_TEXT`.
- **Battle damage** (`ShipMarks.damage()`, from `Mothership._fx_hit` / `_fx_scrape` on every
  peer): acid splashes from spit (glowing while fresh), claw marks from critters, dents from hard
  knocks and long scrapes from grinding along rock, on the hull where the hit landed. Each fades
  out over the last part of its life (`ShipMarks.DAMAGE`: 2 to 3 minutes); hits on one spot freshen
  the mark there; at most `DAMAGE_CAP` per ship.
- **Laser burns on the rock** (`Mothership._burn_rock()`): where a mining laser's beam ends on rock,
  a molten burn that stays hot under the beam, stretches along a sweep into one scorch, cools
  (`BURN_COOL`) and fades (`BURN_LIFE`); at most `ROCK_MARKS`.

Decals paint only surfaces on their render layers: the hull and everything fixed to it carry
`Game.VIS_HULL`, the cave rock `Game.VIS_ROCK`, so crew, aliens, turrets and interiors stay clean.

Balance numbers to tweak:
- Motherships (stats, stations, turret slots, hardpoints): `ShipTypes.TYPES`. Their interiors
  (console spots, repair panels, install hub, walking graph, spawn points): `ShipInteriors.LAYOUTS`,
  and the rooms themselves: `ShipBuilder._rooms_<ship>()`. Base stats, homebase
  ship upgrades, gun unlocks and research point rewards: `Game.ship_stats()`, `Game.SHIP_UPGRADES`,
  `Game.GUNS` and the `RP_*` constants in `game.gd`.
- The cockpit: the constants at the top of `Cockpit` (`scripts/ship/cockpit.gd`): where the pilot
  sits and how far they can turn their head, the camera feeds' resolution, field of view and the
  range they render within, the thrust lever's and gear stick's travel, the speed dial's scale, when
  the red lights flash (`FUEL_LOW`, `HULL_LOW`, `SHIELD_LOW`) and the dashboard's layout. Each ship's glazed nose (`"nose"` and `"sill"`), where its cameras are
  (`"cams"`) and its chin-mounted laser are in `ShipTypes.TYPES`; the cockpit room is the
  interior's `"cockpit"` (`ShipInteriors`). How fast scraping along rock counts:
  `Mothership.SCRAPE_SPEED`. The feeds render one per frame, in turn, and leave out the ship's
  interior, which is drawn on its own render layer (`Game.VIS_INTERIOR`), all but the cockpit and
  the cargo ramp.
- Gun pods: the constants at the top of `GunPod` (`scripts/ship/gun_pod.gd`): the heavy machine
  gun's rate of fire, damage, round speed and spread, the belt and how long a new one takes, heat
  per round, cooling and the damage of firing hot, how fast the pod turns, the heat its barrels
  start to smoke at, how loud its motors whine (`SERVO_DB`) and how high its bark rises in pitch at
  full heat (`HOT_PITCH`). The rocket launcher: `MRLS_*` in `GunPod` (tubes, the time between
  rockets, damage, launch speed, scatter, the loader's time a rocket) and `ROCKET_*` in
  `projectiles.gd` (top speed, the crooked start, homing cone and reach, fuse, blast); what the pod
  guns are and cost: `GunPod.WEAPONS`.
  Where each ship's pods sit and how far they swing: the gun stations in `ShipTypes.TYPES` (the
  `gunpod_check` autotest checks the barrels clear the hull); a pod with yaw limits of -180..180
  turns all the way round and holds its fire while the ship is in its line of fire
  (`Mothership.fire_masked`, `MASK_RANGE`). Auto turrets and scout guns: `AUTO_SPREAD` and `SCOUT_SPREAD`
  in `mothership.gd`.
- Scouts: the constants at the top of `Scout` (`scripts/ship/scout.gd`): the cannons' rate of fire,
  round speed, magazine and reload, the heat per round and per second of boosting, cooling and when
  the guns come back after overheating, the booster's speed, the missiles' lock (time, cone, range)
  and damage, how much one crash can take and when the hull counts as critical; their hull, damage,
  cargo and speed are `scout_*` in `Game.ship_stats()` (times the ship type's `scout_*`). How the
  missiles fly: `MISSILE_*` in `projectiles.gd`. The cockpit: `ScoutCockpit` (the eye and the field
  of view at top speed and at full boost, the canopy's shape, the panels' places, where each crack
  starts on the glass and which way it runs (`CRACKS`), at how much hull it appears (`CRACK_AT`)
  and how much more damage it takes to grow to full length (`CRACK_GROW`); the grease is drawn in
  `GLASS_SHADER`). Each ship's scout docks: `"dock"` in `ShipTypes.TYPES`
  (the `fighter` autotest checks the scouts clear the belly above and the ground or deck below).
- Muffled sounds: `HULL_CUTOFF`, `HULL_DB`, `GLASS_CUTOFF` and `GLASS_DB` in `sfx.gd`, and how
  close a sound must be to a gun pod or a scout to count as inside it (`POD_REACH`, `SCOUT_REACH`).
  Sound players out in the world are handed to `Sfx.track()` so their muffling follows the listener.
- Hostility: `HOSTILITY_TIME` in `mothership.gd` (how long it takes to fill), and the ambushes per
  stage (`AMBUSH_INTERVAL`, `AMBUSH_PACK` in `mission.gd`), the motion tracker's warning
  (`AMBUSH_WARNING`) and the surge (`SURGE_FIRST`, `SURGE_GAP_START`, `SURGE_GAP_END`,
  `SURGE_RAMP`).
- Emergency blast: the `BLAST_*` constants at the top of `mothership.gd` (radius, damage, hull and
  fuel cost, cooldown).
- Crew bots: the constants at the top of `crew_bot.gd` (repair threshold, gun range, aim speed,
  reaction time, self-defence range, fire rate and accuracy, and when it counts as safe to mine). Bots count as half a crew member for difficulty (`MissionLevel.difficulty()`).
- Waystations: spacing and the straightened approach (`STATION_*` in `CaveGen`), the hall, gates
  and shop layout (`StationBuilder`), docking range, speeds, bulkhead speed and what a docked ship
  gets per second (`LAND_RANGE`, `DOCK_*`, `GATE_RATE` in `mothership.gd`), the safe zone
  (`StationBuilder.SAFE_MIN` / `SAFE_MAX`), the shop's stock and prices (`RunItems`) and what each
  item does (`Mothership._apply_item()`), and the auto turrets (`AUTO_*` in `mothership.gd`).
- Abandoned stations: how often and where they appear (`DERELICT_*` in `CaveGen`) and the hangar
  (`DerelictBuilder`). The plan (`OutpostLayout`): the grid (`CELL`, `GX`, `GZ`), how many rooms
  and their heights, doorways, what a corridor costs to lay (`STEP`, `TURN`, `BESIDE`: how much
  they prefer running straight and keeping apart), loops (`LOOP_CHANCE`, `LOOP_MAX`), how often
  there is a generator, a control hub (and a second room locked from it), an armory or a second
  keypad lock (`*_CHANCE`, `MAX_LOCKS`), the door ids (`DOOR_IDS`), the keypad's colours, cords,
  digits and tries (`HACK_*`), and what stands along
  each kind of room's walls (`WALL_PROPS`, `WALL_FREE`) and in its middle (`_central()`); the
  furniture itself is in `OutpostProps`. The look (`DerelictBuilder`): the corridors' octagonal
  frames (`CHAMFER_*`, `FRAME_*`), how many lamps (`LAMP_EVERY`) and their colours; the surfaces
  are drawn by `tools/blender/outpost.py` (`blender -b -P tools/blender/outpost.py`, a few
  seconds). What it costs to draw: the station's surfaces (and its furniture models) are merged and
  committed in cubes `CHUNK` metres on a side, so what is out of view or out of a flashlight's reach
  is culled; its walls, floors, ceilings and doors are on `Game.VIS_SHELL`, the only shadow casters
  for crewmates' flashlights; and one occluder of its wall and ceiling boxes lets the renderer skip
  whatever they hide (`_occluder()`; project setting `rendering/occlusion_culling`). Nothing may be
  built in front of a keypad (`HackPanel.clear_box()`, `Models.Batch.keep_clear()`). The station's life (`Derelict`): how fast a sealed door opens and a shutter drops
  (`DOOR_RATE`, `SHUTTER_TIME`), the power's wave of lamps (`POWER_WAVE`), the lockdown's alarm
  (`ALARM_TIME`), the generator's flywheel and shake, the control hub's camera feeds (`FEED_*`);
  the hub's computer (`HubConsole`: its screen, text block, close look) and map (`HubMap`: size,
  colours); what its commands do (`Mothership._hub_command()`). Sentry turrets: the constants at
  the top of `Sentry` (arc, reach, rate of fire, damage, rounds, health, unfolding), how many a
  station holds (`Mothership.SENTRY_MAX`) and how hard aliens it hurts go for it
  (`Boarder.SENTRY_PROVOKED`, `SENTRY_PROVOKE_TIME`). Landing range
  and how close aliens may be for a landing, salvage, credit boxes and the stalker
  (`DERELICT_LAND_RANGE`, `DERELICT_CLEAR_RANGE`, `SALVAGE_CHANCE`, `CREDITS_CHANCE`,
  `STALKER_CHANCE`, `_credit_box()` and `_derelict_contents()` in `mothership.gd`, which also
  places the barnacles, nests, spiders and the hordes behind the hub's locked doors: `HORDE`), how many pulls the generator takes (`_gen_need`), what
  salvage can be (`RunItems.roll_salvage()`). The aliens: `Boarder.KIND_STATS` (health, speed,
  damage, reach, size), how close they hear and how far they keep off the walls (`HEAR_RANGE`,
  `WALL_GAP`), and each one's constants: `Stalker` (speeds, sight, claws a visit, hiding, fleeing
  and healing), `Barnacle` (reach, the lash and the reel, how high it holds you, its drip),
  `Climber` (how they climb), `Crawler` (patch, hunting radius, leaps), `Hive` (breeding),
  `Spider` (spitting distances, scurries, its legs and their steps).
- The shops' buyback counters: `RunItems.SELL_SHARE`.
- Hand weapons: `CrewWeapons.DEFS` (damage and how it falls off with distance, fire rate and
  whether the weapon is semi-automatic, the scatter from the hip and aimed and how it builds up, the
  zoom while aiming, the kick and how much harder quick shots kick, piercing, the grenades' speed,
  lift, fuse and blast radius, magazine and reload time, or heat per shot, cooling and vent time,
  shop price, the muzzle flash, the Photon Rifle's bolts), each weapon's muzzle (`MUZZLES`), how
  far apart the Dual Pistols are (`DUAL_SPREAD`, `DUAL_HELD_SPREAD`, `DUAL_CRATE_SPREAD`; their poses
  in view: `DUAL_*` in `WeaponRig`), the
  Storm Lance's charge, aim and chain (`CHARGE_TIME`, `BOLT_SLACK`, `CHAIN_RANGE`, `CHAIN_JUMPS`,
  `CHAIN_FALLOFF`...) and how long an overheated
  weapon vents (`OVERHEAT_VENT`). How they are handled: the constants at the top of `CrewMember`
  (how fast a weapon comes up and how long until it is held relaxed again, aiming time and speed,
  extra scatter on the move, how much of the kick comes back). Their poses in view: `WeaponRig`.
  Casings, magazines and moon clips on the floor: `Debris` (bounce, how many are kept, how long
  they stay and shrink away: `CASING_LIFE`, `MAG_LIFE`, `FADE`). Grenades in flight: `Grenades`
  (bounce, rolling, how late a copy may go off on its own, the blast's look and how far away it
  shakes the view). Where each weapon's display sits: `"display_at"` in its builder in
  `CrewWeapons`; the cylinders' crane swing and turn: `CRANE_OPEN`, `TURN_TIME` in `WeaponRig`.
- Dirty glass (the gun pods', the cockpits', the scouts' canopies and the visor):
  `GunPod.GLASS_LIGHT` (`GLINT_MAX` and `GLINT_ROUGH`: how bright and how sharp a lamp's reflection
  in the glass may get; `GLARE` and the two scattering lobes in its light(): how much a lamp beyond
  the glass glares through the grease, and how far round it). Fill lights that hang in front of the
  glass with no lamp there leave it out (`Game.VIS_GLASS`); a lamp grazing the glass glares less
  (`GRAZE`), so a curved pane lit from the side shows no hard edge. The helmet's inside is lit only through
  its opening: `Helmet.LIT_SHADER` (`BOUNCE`: light that gets in and bounces round inside).
- The suit: `Helmet` (the opening's shape: `OPEN_SIDE`, `SIDE_BOW`, `OPEN_TOP`, `OPEN_BOTTOM`,
  `V_RISE`; the shell's profile `RINGS` and its seams; where the instruments and the vent sit and
  their plates; the visor; when it cracks: `CRACK_START`, `CRACK_AT`, `HEAL_MARGIN`, `CRITICAL`,
  and where the cracks run: `CRACKS`) and `Scanner` (range, sweep time, rays per sweep, how many
  walls a ray goes on through: `WALL_LAYERS`, how high it pings: `PING_HEIGHT`, how long a fresh
  echo and a blip's flare glow, when two echoes join into a line: `JOIN_*`, the inks).
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
- Spotlights: every spotlight (the ships' and scouts' headlights, the floodlights on the ships, in
  the stations and at the homebase, the crew's flashlights and the gate beacons) shines through a
  light cookie, so it falls like a real lamp's light instead of an even disc: a broad beam with
  faint reflector rings, an even wash crossed by the shadows of the lamp's guard bars, a torch's
  hot spot, dark band and halo, a beacon's streaks. The patterns are in `Models.light_cookie()`. A
  cookie only shows on a light that casts shadows, so all of these do.
- Spawn pacing: `MissionLevel._director()` and `_populate()`, plus the `Nest` constants (hatch
  intervals, live caps, `HATCH_GAP`, `HIT_AGITATION`).
- Cave shape: the radius, path and side tunnels in `CaveGen`.

## Automated tests

`scripts/dev/autotest.gd` drives the game and saves screenshots to `user://autotest/`. It uses a
separate save file, so it never touches real progress.

```
godot --path . -- --autotest=smoke     # full solo mission loop (add --headless for speed)
godot --path . -- --autotest=assets    # close-ups of the Blender-made models (windowed)
godot --path . -- --autotest=decals    # every ship's markings and grime, battle damage, laser burns (windowed; decals_check: headless)
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
godot --path . -- --autotest=weapons   # hand weapon damage (the semi-automatic ones clicked; marksman rounds piercing, grenade blasts), swapping at a crate
godot --path . -- --autotest=cheats    # the homebase cheat menu, buying everything, restoring the save
godot --path . -- --autotest=interiors # every ship's interior: inside the hull, walking graph and spots clear, views (interiors_check: no shots)
godot --path . -- --autotest=interior_bots  # crew bots repairing and manning the guns in every ship's interior
godot --path . -- --autotest=backlog   # guns and spread, plasma blast, laser-tip mining, hostility, shop door, buyback, flashlight, skitters (backlog_check: no shots)
godot --path . -- --autotest=backlog2  # engine hum, reloading, buyback facing, gate beacons, landing with aliens about, outpost aliens (crawlers, a stalker, a spider) vs bots (backlog2_check: no shots)
godot --path . -- --autotest=gunpod    # gun pods: barrels clear of every hull, the gunner's view, firing, heat and overheating, belt change, sight, bot gunner (gunpod_check: no shots)
godot --path . -- --autotest=cockpit   # the cockpit: glazed noses and camera mounts, lasers clear of the glass, how much of the spine and belly views the hull fills, the pilot's view, lever, stick, gauges, readouts, red lights, lamps, side displays, terminal, camera feeds, red button, looking at and clicking the switches, the barrier, ambush warning, surge, scraping, gun pod smoke, motors and bark by heat, every ship's cockpit and the Vanguard's interrupter (cockpit_check: no shots)
godot --path . -- --autotest=fighter   # the scouts: clear of every ship's docks, the view from the eye (panels in view, inside the canopy), the cockpit view, cannons, magazine, overheating, booster, locking on and missiles, cracks and the critical alarm, the homing needle and the dock's marker, docking, muffled sounds aboard, in a pod and in the scout, the Vanguard's combat scouts (fighter_check: no shots)
godot --path . -- --autotest=host_scout  # with --autotest=join_scout: a client flies the scout (it turns at once there), fires the cannons, boosts, locks on and fires a missile at the host's spitter, docks
godot --path . -- --autotest=soldier   # on foot: the helmet's instruments, the weapon's poses, every sight lined up, scatter and bloom, casings and magazines, reloading, overheating and venting, the lightning chain and its shake, the revolver held, fanned and fired slowly and its moon-clip reload, the Dual Pistols firing in turn, the submachine gun's rate, scatter and climb, the marksman round through two aliens, the shotgun's rate and damage, grenades bouncing, going off on the fuse or on an alien and the cases thrown out, the scanner aboard and in a station, the visor sealing outside and cracking, and that nothing hides the helmet's screens or any gun's display (soldier_check: no shots)
godot --path . -- --autotest=glass    # lamps and dirty glass: a lamp behind the head leaves nothing on the visor, one ahead glares through its grime; the gun pod, cockpit and scout canopy (windowed)
godot --path . -- --autotest=outpost  # the outpost test: landed at an abandoned station, a crate of every hand weapon on the pier, swapping each one, the save left alone (outpost_check: no shots)
godot --path . -- --autotest=outpost_plans    # 80 outposts' plans checked (every room reachable, sealed rooms behind the right door, furniture clear), how long one takes, plans drawn to plan_<n>.png (headless)
godot --path . -- --autotest=outpost_tour     # every room, a corridor, the control hub's desk and a keypad with the power off and on, a lockdown, how long building one takes (windowed)
godot --path . -- --autotest=outposts         # the generator's starter, a keypad lock (wrong code, a key clicked, the right code, walking through) and a lockdown, a barnacle (hidden tongue, its reach, not through a wall), the stalker's visit and its healing, crawlers in and out of their patch, an acid spider (and how often its legs reach), a credit box deposited, aliens behind a shut door, 40 s of aliens chasing about checked against the walls (outposts_check: no shots)
godot --path . -- --autotest=outpost_walls    # 2 minutes of a busy outpost (aliens of every kind chasing the player all over it, going home, a noise): every step of every alien checked against the walls and shut doors (headless)
godot --path . -- --autotest=host_outpost     # multiplayer outpost, host side (run join_outpost in a second instance): reports the client's generator pulls, codes and the barnacle holding them
godot --path . -- --autotest=join_outpost     # multiplayer outpost, client side: the generator's starter, a wrong and the right code at a keypad, held by a barnacle, a spider's legs, as the client sees them
godot --path . -- --autotest=outpost_gallery  # the outposts' aliens up close in a studio on the pad (windowed)
godot --path . -- --autotest=props_gallery    # every kind of outpost furniture up close (lockers, filing cabinets, tanks and drums in four variants), pg_<kind>.png (windowed)
godot --path . -- --autotest=keypads          # 55 keypad locks in 40 outposts: nothing the station builds stands in front of one (keypads_check: headless, no shots)
godot --path . -- --autotest=outpost_perf     # what an outpost costs to draw with three crew bots along: fps, GPU time, draw calls at the pier, a corridor and every room, and with the flashlights off, the station hidden, the aliens stopped (windowed; outpost_perf_solo: no bots)
godot --path . -- --autotest=visor_side       # a lamp close beside the helmet, 45 to 90 degrees off the view: the visor's glare fades smoothly (windowed)
godot --path . -- --autotest=hub              # the control hub: door ids, the horde behind its locked door, dark without power, sitting at the computer and typing (HELP, DOORS, bad lines), a door refused with a crate in its doorway, locked and unlocked, the dead end opened, Esc; pictures of the desk, map, screen and a door's plate (hub_check: no shots)
godot --path . -- --autotest=sentries         # sentry turrets: won't open aboard, opened in a room, what it shoots and leaves alone, aliens turning on it, its rounds, folded and picked up, wrecked (sentries_check: no shots)
godot --path . -- --autotest=scanner_perf     # what the echolocation scanner costs to draw: frame rate with it down and up, draw time, a ray's time (windowed)
godot --path . -- --autotest=generator_views  # the outposts' generator alone from each side, its control box and the starter pulled out (windowed)
godot --path . -- --autotest=rockets          # the rocket launcher: mounted from a crate (the machine gun comes off in one), a salvo at tough spitters (scatter, curve, homing), the loader, the screens, a bot firing salvos (rockets_check: no shots)
godot --path . -- --autotest=dual             # the Dual Pistols in the first-person view: poses, firing in turn, both displays, reloading (windowed)
godot --path . -- --autotest=host_soldier  # with --autotest=join_soldier: a client fires the pistol (from the hip and aimed) and reloads, lets a lightning bolt go down a line of the host's boarders and holds the scanner up; the host reports the hits, the client's poses and the casings and magazine out of its gun
```

## Known limitations

- The ships and levels are built in code, so the editor shows only the empty `Main` scene. Run the
  game to see the content.
- Vehicles are simulated on the server without client-side prediction (a scout's pilot turns it at
  once on their own client, but its position still follows the server). That is fine on a LAN, but
  piloting from a distant client feels slightly delayed.
- The scouts pass through the mothership's hull instead of colliding with it.
- Aliens don't collide with the bulkhead doors (the station's turrets shoot down anything that
  comes close).
- Audio is simple synthesised effects with no music.
