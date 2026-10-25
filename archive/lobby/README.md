# Archived 3D lobby

The walkable lobby room (a round wood-and-concrete hall with a join pad) was
retired on 2026-09-24 when the full-screen main menu
(`scripts/ui/main_menu.gd`) replaced it. It is kept here, with its history
(moved with `git mv`), in case a walkable social space comes back.

- `scenes/world/lobby_room.tscn` — scene root (`Room` static body, `JoinPad` area)
- `scripts/lobby_room.gd` — `LobbyRoom`: materials, furnished bays, trophy, lighting

To restore it: move both files back, re-add the `Lobby` instance to
`scenes/main.tscn` at `Vector3(0, 0, 620)`, bring back `SpawnManager`'s
`lobby_center` / `lobby_radius` + `is_outside_lobby`, and reconnect the join
pad in `game.gd`. The `lobby_*` furniture entries in
`environment_asset_library.gd` are still in place.
