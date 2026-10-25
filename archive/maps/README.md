# Archived competitive maps

The five original duel maps were retired from the game on 2026-09-22 when
Bounceground became the single competitive map. They are kept here, with their
history (moved with `git mv`), so any of them can be brought back.

| Map id | Display name | Builder / geometry |
| --- | --- | --- |
| `neon_arcade` | Neon Arcade | `neon_arcade_builder.gd`, `neon_arcade_geometry.gd` |
| `backyard` | Backyard | `backyard_builder.gd`, `backyard_blueprint_geometry.gd` |
| `arena` | Arena | `arena_blueprint_builder.gd`, `arena_blueprint_geometry.gd` |
| `sky_temple` | Aether Citadel | `sky_temple_builder.gd`, `aether_citadel_geometry.gd` |
| `toybox` | Toybox | `toybox_builder.gd`, `toybox_blueprint_geometry.gd` |

All five share `scripts/competitive_arena.gd` as their scene root script
(shell, materials, spawn points, lighting profiles), plus `arena_models.gd`,
`environment_art.gd`, `environment_presentation.gd`, the map-only
interactables in `scripts/interactables/`, and their blueprint contracts and
visual captures in `tests/`.

The folder layout mirrors the project root, and the `.gdignore` file keeps
Godot from importing anything in here, so none of these scripts are compiled
while archived. The per-map music (`assets/audio/music_match_*.wav`) was left in
place and still plays in the match rotation.

## Restoring a map

1. Move the files back to the same paths under the project root, e.g.
   `git mv archive/maps/scripts/competitive_arena.gd scripts/`. Every map needs
   `competitive_arena.gd` and the shared `environment/` helpers above.
2. Re-add the map to `COMPETITIVE_MAP_SCENES` / `MAP_DISPLAY_NAMES` in
   `scripts/game.gd`, `COMPETITIVE_MAPS` in `scripts/hud.gd`, and
   `MAP_MUSIC_THEMES` in `scripts/audio_manager.gd`.
3. Add its scene back to the map lists in the generic map contracts
   (`map_acceptance`, `spawn_safety_integration`, `duel_flow_contract`,
   `lighting_contract`, `material_contract`, ...) and move its blueprint
   contract back into `tests/`.
4. Drop its id from `ARCHIVED_MAP_NAMES` in `scripts/progression_manager.gd`.
