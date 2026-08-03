# Blob Duels

A physics-first 1v1 arena game in Godot 4.7 (Jolt physics, Mobile renderer).
Main scene is `scenes/main.tscn`, driven by `scripts/game.gd`.

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
PNGs, need a display, and are excluded from the suite. `debug_movement_probe.gd`
only prints telemetry and is likewise excluded.

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

## Progression

`scripts/progression_manager.gd` is the `Progression` autoload. Saves are
**debounced**: `_queue_save()` marks state dirty and a `_process` flush writes at
most every 2s, because `record_stat` runs on gameplay hot paths. Call
`save_now()` only for deliberate transactions (purchase, equip, quest claim,
match award). Quest completion never pays out — coins are awarded on claim.

## Arenas

`scripts/environment/` splits each arena into a `*_geometry.gd` module (pure
layout data) and a `*_builder.gd` (node construction), with shared primitives in
`arena_blueprint_geometry.gd`. Keep that split when adding a map. Interactables
(pads, bumpers, trampolines) are one script per behaviour in
`scripts/interactables/`.
