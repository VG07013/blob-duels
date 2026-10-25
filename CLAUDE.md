# Blob Duels

A physics-first 1v1 arena game in Godot 4.7 (Jolt physics, Mobile renderer).
Main scene is `scenes/main.tscn`, driven by `scripts/game.gd` (`DuelGame`).
game.gd owns the match flow and hands two pieces to helper classes it creates
in `_ready`: `VictoryDirector` (`scripts/victory_director.gd`, the match-end
cinematic) and `PracticeCoordinator` (`scripts/practice_coordinator.gd`, the
practice-only wiring). Both type their back-reference as `DuelGame`, so they
are reached by class name rather than `preload` (a preload would be a parse
cycle); `_victory_sequence_active` on game.gd is a read-only view of the
director's `active` flag.

## Running things

```bash
./scripts/run_tests.sh              # full headless contract suite
./scripts/run_tests.sh shop         # filter by name
./scripts/run_tests.sh --fail-fast  # stop at the first failure
./scripts/run_tests.sh --list       # show what would run (works without Godot)
```

Set `GODOT` if the binary is not on `PATH` or in `/Applications`. CI runs the
same script, so a green local run means a green pipeline.

## Testing conventions

Tests live in `tests/`, one file per contract, named `<area>_contract.gd` for
behaviour and `<area>_integration.gd` for cross-system checks. Each is a
`SceneTree` script that:

- collects failures into an array instead of asserting eagerly, so one run
  reports every violation rather than only the first,
- writes assertion messages describing the **product rule** being protected
  ("Basic abilities must cost 150 Coins"), not the mechanics of the check,
- calls `quit(0)` on success and `quit(1)` after `push_error`-ing each failure.

Scripts ending in `_visual_capture.gd` are not contracts: they render reference
PNGs, need a display, and are excluded from the suite. Scripts ending in
`_probe.gd` (and `debug_movement_probe.gd`) only print telemetry and are
likewise excluded.

Two rendering gotchas for capture/probe scripts, both learned the hard way:
always `await RenderingServer.frame_post_draw` before `get_texture().get_image()`
(process frames advance even when the compositor skips presenting, so a grab
without it can save byte-identical stale frames), and never read
`MultiMesh.get_instance_transform()` in a `--headless` test — the dummy
rendering server does not round-trip transform data.

Tests reach into private state with `game.set("_field", ...)` /
`game.get("_field")`. That coupling is deliberate, but `Object.set()` on an
unknown property is a silent no-op: renaming a private field guts a test's
setup while leaving it green. `scripts/check_test_introspection.py` fails the
build on any `_`-prefixed `set`/`get` or `call` name in `tests/` that no longer
exists under `scripts/`. It runs first in `run_tests.sh` and in CI, before
Godot is even installed.

## Code conventions

- Tabs for indentation, typed GDScript throughout, two blank lines between
  top-level functions.
- Shared helper scripts declare `class_name` **and** are consumed via
  `const NAME := preload("res://...")` in the scripts that use them.
- Tuning numbers belong in `scripts/ability_tuning.gd`, never inline in
  activation handlers.
- Reserve `has_method()` + `call("name", ...)` for genuinely polymorphic targets
  (children of `remote_players` / `projectiles`) and for autoloads that may be
  absent in headless tests (`/root/Progression`). Fixed scene children are typed
  (`BlobPlayer`, `DuelHud`, `PauseMenu`) and called directly, so renames fail at
  compile time.

## Multiplayer model

Direct peer-to-peer ENet over UDP 7359, one client max, no authentication —
trusted-friends alpha only. The host is authoritative:

- Clients send **requests** (`_request_network_shot`, `_request_network_ability`,
  `_report_round_death`); the host validates and replicates the **result**.
- Never trust a client-supplied value. Existing handlers clamp damage and
  impulse, bound position deltas against elapsed time
  (`_sanitize_remote_position`), re-derive velocity host-side, cap name length,
  clamp colours, and cross-check claimed deaths against authoritative health and
  arena bounds. Match that standard in any new RPC.
- Per-peer authority lives in `ServerPeerRegistry` (`scripts/net/`), not in
  fields on `game.gd`. Add new per-peer state to `ServerPeerState` so joins,
  match resets, and disconnects keep handling it in one place.
- `@rpc("any_peer", ...)` handlers must start by checking
  `multiplayer.is_server()` and that the sender is a known peer.

Connectivity and feel, all tuned in `scripts/net/network_tuning.gd`:

- Hosting asks the router for a UDP mapping via UPnP on a worker thread
  (`NetworkSession.upnp_enabled`, injectable factory for tests). On success the
  host sees an Internet code beside the LAN code; the mapping is removed when
  hosting stops. No relay exists, so a refused mapping still means manual port
  forwarding.
- Unreliable ping/pong gives a smoothed RTT (`get_ping_msec()`, HUD readout)
  and the host-clock offset. Remote blobs render from a host-stamped
  `RemoteSnapshotBuffer` at `INTERPOLATION_DELAY_MSEC` behind, extrapolate
  briefly when it runs dry, and snap on teleport-sized jumps.
- `two_client_network_harness` needs a host and a client process; the runner
  starts both for any `*_network_harness` test.

## Abilities

Every ability is one class in `scripts/abilities/` extending `DuelAbility`
(`duel_ability.gd`), created by `AbilityRegistry` and driven by
`AbilityController` (`game._abilities`). game.gd never names an ability: it
forwards activate / tick / expire / interrupt / reset, and the host path
(`_request_network_ability`) forwards to `server_allowed` + `server_activate`
against the peer's `ServerPeerState`. To add an ability: one subclass, one
`AbilityRegistry.create` branch, a catalog row in `progression_manager.gd`,
art/name/cooldown/colour in `ui/ability_hud.gd` and `shop_blob_preview.gd`,
and a sound in `audio_manager.gd`; `host_validated = true` if the host must
apply it for remote peers. Tuning stays in `ability_tuning.gd`.

## Bot duel and match format

`_start_bot_match(difficulty)` runs an offline duel against `BotOpponent`
(`scripts/bot_opponent.gd`, tuning in `bot_tuning.gd`). The bot is registered
as peer `BOT_PEER_ID` (2) with its own `ServerPeerState`, so hits, deaths,
rounds and rewards run through the same host-authoritative code a client
uses; `_is_duel_participant()` is the check to use where a handler used to
ask `multiplayer.get_peers().has()`. The bot body is a `BlobPlayer` configured
local with human input disabled; `BotOpponent` drives it through a
`BlobVirtualInput` (`scripts/blob_virtual_input.gd`, the body's
`virtual_input`): every `Input` read in `player.gd` goes through
`_action_pressed` / `_action_just_pressed` / `get_movement_input`, so the bot
runs the same ramp-up, bounce buffer, fling charge and power slide a player
does - never raw forces. Each physics step it perceives (sight, incoming shots
from `projectiles`, walls and drops ahead), picks a heading (ram, kite, chase,
orbit), layers a dodge, then decides hops, slams, slides, flings and shots;
it emits `shot_requested` and game.gd applies the host fire-rate cap before
spawning the projectile. Difficulty is only data (`bot_tuning.gd` PRESETS);
`bot_behaviour_contract` pins the behaviour, `bot_duel_contract` the presets.
Match format (`set_match_format`, first-to and round seconds) is host-only and
travels with `_receive_match_setup`; rematch (`_on_rematch_requested`) keeps
peers, loadouts and map, resets only the scoreboard, and `hide_victory()`
restores the gameplay HUD the victory cinematic hid. Every round countdown
clears cooldowns (`_reset_ability_state()` locally, `ServerPeerRegistry.reset_for_round()`
on the host).
`bot_duel_contract` and `match_format_contract` guard both.

Match end: `_start_victory_sequence` forwards to `VictoryDirector.start`, which
cuts to the winner on its spawn deck and plays a scripted celebration
(`VICTORY_HOPS`, `pose_at`) driven from game.gd's `_process` via
`VictoryDirector.process`. The squash / spin goes through `VisualRoot.set_celebration_pose`,
never the body. The camera pushes in and orbits only along the cleared line
from `_victory_camera_spot`. `VICTORY_RESULTS_DELAY` later the HUD shows the
results: the title top-centre, the rewards receipt left, the scoreboard
right, laid out and scaled to fit by `_layout_victory`. Letterbox bars, the
winner callout, vignette and confetti live in `ui/victory_fx.gd`. The cursor
stays free for the whole sequence: clicks and pause-resume must not recapture
it while `_victory_sequence_active`. `tests/victory_flow_visual_capture.gd`
renders the real flow (needs a display; `-- --defeat` for the losing side).

## Input and HUD feedback

`scripts/input_bindings.gd` owns default keyboard + gamepad events for every
action, applies saved overrides from the `[bindings]` section of the settings
cfg at startup, and holds the gamepad look / FOV bounds. The pause menu's
Controls tab rebinds through it (`input_bindings_contract`).
`scripts/ui/duel_feedback.gd` is the HUD's feedback layer: pooled damage
numbers, kill feed, low-health vignette, damage-direction arc, round intro.
`DuelHud` delegates to it (`hud_feedback_contract`); repeat hits on one
target within 1s add into a single running damage number. Blobs carry no
floating name tag or health bar (the `Nameplate` node stays hidden). F is
**quick blob**: the Blob slot for `CombatTuning.QUICK_BLOB_SECONDS`, then back
to the Blaster (`hotbar_combat_contract`).
Held items: `HeldItemRig` (`scripts/held_item_rig.gd`, built by game.gd under
`$CameraRig/Camera3D`) shows the Blaster pistol on slot 1 and the two Blob
fists on slot 2, first person only, during a match; both are primitives in
the game's style, drawn with `no_depth_test` so walls never cut them. The
pistol kicks on every local shot, the fists punch. A click in the Blob slot
is `BlobPlayer._throw_punch`: `CombatTuning.PUNCH_*`, a sphere at
`PUNCH_REACH` along the aim, damage + shove through the same paths a body
ram uses (`network_collision_requested` for remote blobs, so the host still
clamps it), alternating hands, `punched` signal for feedback (never
`shoot_requested`). `held_items_contract` guards it.
Fling: a quick ~1s press must launch past rolling speed (front-loaded charge
curve, `fling_regression_contract`); the HUD fling rail is `ui/fling_meter.gd`
above the health pill (ready / charging / cooldown in one widget). Shots have
juggle protection (`receive_collision_impact(..., from_shot = true)`,
`CombatTuning.HIT_CHAIN_*`, `hit_juggle_contract`): only the first shot of a
chain pops a grounded blob up and airborne shots never lift; body slams,
mines and shockwaves keep their full pop.
Power slide: holding `slide` (C / R3) on the ground bursts the blob forward
low and fast (`player.gd` "Power Slide" exports: entry burst, low drag, raised
speed band, committed steering, capped duration). Releasing it (or running
out) on the ground pops a small hop; brake, a fling charge or a slam cut it
with none. Separate from the brake slide. Sounds `slide_start` / the slide
scrape loop / `slide_hop` (`make_power_slide_pack` in `generate_audio.py`).
Guarded in `advanced_movement_contract`.
Music is **lobby-only**: `AudioManager.AUDIBLE_MUSIC_CONTEXTS` holds just
`lobby`, and every gameplay context fades music out
(`audio_lifecycle_integration`).

## Main menu

There is no walkable lobby (the old 3D room lives in `archive/lobby/`). The
pre-game screen is `MainMenu` (`scripts/ui/main_menu.gd`), a full-screen,
one-page Control built in code and owned by `DuelHud` as `main_menu`: match
setup, bot / practice / host / join, the hero blob with name + colour, quests,
loadout and settings are all visible at once — never add page navigation
(`main_menu_contract`). MainMenu owns layout and motion only; `hud.gd` owns
what each control means and keeps the historic signals (`host_requested`,
`practice_requested`, ...) and `set_lobby_mode` / `_return_to_lobby` names.
Pieces: `MenuCard` (`ui/menu_card.gd`, shader glass + hover glow + pop-in
entrance), `MenuWordmark` (letter-drop logo), `MenuBlobStage` (the real player
scene hopping on a pedestal; squash the `VisualRoot`/`FaceRoot` meshes, never
the body — Jolt rejects non-uniform scale), backdrop shader
`assets/materials/menu_backdrop.gdshader`. Every animation honours the
reduced-motion setting. While the menu is up, `game._set_menu_world_parked`
turns off root-viewport 3D and freezes the local blob with input off; any
match start unparks it. Esc in the menu opens Settings over a dimmed menu.

## Shop and quest drawer

Coins, the Shop and the Quest Board open one translucent drawer over the menu
(`ShopOverlay`, bounded to ~70% x 83% of the screen: `lobby_ui_revamp_contract`,
`premium_non_lobby_ui_contract`). `ProgressionDrawer`
(`scripts/ui/progression_drawer.gd`, `hud.drawer`) builds the coin chip, the
menu quest card, the drawer and the toasts, still as children of the HUD layer
so draw order is unchanged; `hud.gd` keeps the entry points the menu, pause
flow and contracts call (`_set_progression_open`, `close_progression`,
`is_progression_open`, `_show_progression_toast`) and the results-screen
rewards receipt. Tests inspect drawer state through `hud.drawer`. Room codes
and the ping readout live in `NetworkStatusHud` (`scripts/ui/network_status.gd`,
`hud.network_status`). Its header (title, Shop / Quests switch, balance,
close) is built once. The body rebuilds per page, and only the affected slot
rebuilds on a category, item or Daily / Weekly change, so the `MenuSegmented`
pills (`ui/menu_segmented.gd`, shared with the menu) glide instead of
snapping. Shop items and quest rows are `MenuCard`s: whole-card tap target
`CardHitTarget`, and `set_highlighted` marks the selected item or a claimable
quest. Motion helpers are in `ui/progression_fx.gd` (entrance pops, springy
buttons, bar fills, count-ups, coin bursts), and `ui/progress_ring.gd` draws
the quest rings. Every effect honours reduced motion through
`ProgressionFx.reduced_motion`. Closing counts as closed immediately
(`is_progression_open`), plays a short exit, then frees the body, including
the model `SubViewport`. Claims and purchases fly coins to or from the header
balance, which counts on landing (`progression_drawer_contract`).
`tests/progression_drawer_visual_capture.gd` renders it (needs a display).
The shop stocks the **full catalog** (12 abilities + 78 cosmetics, 90 items:
`shop_catalog_integrity_contract` pins the count). Every account owns and
wears `STARTER_LOADOUT` (Dash, Classic Blue, Bubble, Bubble Pop, Happy) from
the start; `Progression.stock_full_catalog = false` cuts the shop back to just
those items (`progression_quests_contract` guards both states).

## Progression

`scripts/progression_manager.gd` is the `Progression` autoload. Saves are
**debounced**: `_queue_save()` marks state dirty and a `_process` flush writes at
most every 2s, because `record_stat` runs on gameplay hot paths. Call
`save_now()` only for deliberate transactions (purchase, equip, quest claim,
match award). Quest completion never pays out — coins are awarded on claim.

## Arenas

`scripts/environment/` splits each arena into a `*_geometry.gd` module (pure
layout data) and a `*_builder.gd` (node construction), under a thin scene-root
host script. Keep that split when adding a map. Interactables (pads, bumpers,
trampolines) are one script per behaviour in `scripts/interactables/`.

**Arena** is the default duel map (`DEFAULT_MAP_ID`, first in the HUD picker;
map id `skyline` — `arena` is an archived id that save migration
still retargets, so do not reuse it; `scenes/world/maps/skyline.tscn`, host
`scripts/skyline_arena.gd`) is the one map modelled in Blender instead:
`assets/models/maps/generate_skyline.py` builds and exports `skyline.glb`
(run it with `Blender -b --python <script>`). Style: a big, open, tidy neon
hall — pillared 120-unit walls with cornices and window slits, **one** cyan
accent colour, a solid trussed roof, and platform tops patterned with small,
muted, seeded orange / blue / slate dots, some joined by thin lines
(`build_patterns`) — keep them discreet. `build_finish` adds the blob-scale
detail that makes it read as finished: floor tile seams + border walkway, a
lower-wall dado band (the chamfered corners repeat the full wall treatment so
nothing stops dead at a corner), platform coping / kick plates / side grooves, ramp
curbs, cover caps and spire grooves (all `Deco_`, no collision). Every lower wall bay holds a 16×24
(2:3) poster: solid orange on the red (+z) half, solid blue on the blue half;
images dropped into `assets/models/maps/posters/` take seeded random
eye-level bays, and an `orange_`/`blue_` file prefix keeps one on that
team's half (see its README). The host turns the glb meshes into
collision by name prefix (`Floor_`/`Deck_`/`Block_` normal, `Wall_` bounce,
`Ramp_` grip, `Roof_` ice, `Deco_` visual only; `Roof_` and `Deco_` cast no
shadows so daylight reaches the court; the host also drops the trusses' shadows).
Its lighting mirrors the Blender preview: a near-overhead white sun, a
neutral fill, exposure 1.15, and a shadowless top-down `CeilingFill` light.
The script joins pieces per prefix + material. Edit the layout in the Python script and re-export, never by hand
in the glb. Layout: a 280×280 court, four 18-unit corner towers (40 wide)
with 60-long ramps, two side skybridges, a 64-wide centre plateau with a
70-unit spire, four 32-long cover walls, and end spawn decks.

The other competitive map is **Bounceground**
(`scenes/world/maps/bounceground.tscn`, host `scripts/bounceground_arena.gd`,
`bounceground_geometry.gd` + `bounceground_builder.gd`): a 128×176 enclosed
court with bounce-surface walls, a glass (ice) lid, two team spawn decks, two
ramped side decks, a centre mound, eight cover walls and eight launch pads.
Its tables are point-symmetric through the origin (`duel_flow_contract` checks
the mirrored route pairs), and one StaticBody3D per surface family
(`CourtCollision`/`WallCollision`/`RampCollision`/`GlassCollision`) carries the
physics material. Pad strengths were tuned with a physics probe; re-probe if
you move a pad. The five earlier maps (Neon Arcade, Backyard, Arena, Aether
Citadel, Toybox) live in `archive/maps/` (`.gdignore`d, restore steps in its
README).

The practice/offline map is the blueprint training grounds:
`scenes/world/practice_arena.tscn` + `scripts/practice_arena.gd` (thin host)
with layout in `practice_facility_geometry.gd` and construction in
`practice_facility_builder.gd`. The layout is image-locked to the
"Practice Map – Blueprint" sheet: a 28×15 grid-unit court where
1 GU = 2.888 world units (half a blob diameter), converted with
`world_x = (gx − 14) · GU`, `world_z = (7.5 − gy) · GU` — change coordinates
only by editing the grid tables in the geometry module
(`practice_blueprint_contract` audits stations, height bands, and
interaction directions against those tables). Its structural contract:
`PracticeVisuals`/`PracticeCollision` roots with flat child hierarchies,
groups per the practice contracts, and **zero** interpenetration /
sub-blob-gap budget (`practice_arena_geometry_contract`). Fixed main.tscn
wiring: SpawnManager keeps the 157 bound as the outer safety net, all
ArenaSpawns markers sit on the centre platform facing −Z (single-player
spawn — never add a second spawn area), the eight `DummyStationA..H` nodes
sit on the blueprint stations, and the FallbackSpawn drop at the origin
lands on the platform. Every map (practice included) owns its
`get_lighting_profile()` and must declare `glow_enabled` explicitly —
`lighting_contract` enforces both.

## Practice training layer

The practice map is a training facility, so it carries behaviour the
competitive maps do not. Three pieces, all practice-only:

- `scripts/practice_training.gd` — pure tuning tables for the five dummy
  behaviour modes and the health presets. New training numbers belong here,
  never inline in `dummy_blob.gd`.
- `scripts/practice_session.gd` (`PracticeSession`, a fixed child of
  `main.tscn`) — owns the shared dummy configuration and the run statistics.
  All eight stations are configured through it, because the spec calls for one
  central panel rather than eight physical terminals; never configure a dummy
  directly from `game.gd`.
- `scripts/ui/practice_hud.gd` (`PracticeHud`) — the statistics card and the
  Tab-toggled control panel, deliberately separate from `DuelHud`.

Defaults are product rules, not preferences: dummies are **static** with
**infinite** health, return fire is harmless, and a defeated dummy respawns on
its own station after 1.5s without paying coins. `PracticeCoordinator`
(`scripts/practice_coordinator.gd`) owns that wiring: game.gd calls
`_practice.begin_session()` / `_practice.end_session()` on every practice
entry and exit, so a duel never inherits training state, and
`_start_practice_match` / `_activate_practice_map` on game.gd are forwarders.
`practice_training_contract` guards the modes, presets, and statistics;
`tests/practice_hud_visual_capture.gd` renders the panels (needs a display).
