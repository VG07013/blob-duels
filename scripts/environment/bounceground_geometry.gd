class_name BouncegroundGeometry
extends RefCounted

## Pure layout data for Bounceground, the competitive duel court. No nodes
## are built here; bounceground_builder.gd turns these tables into geometry.
##
## World axes: X runs across the court (west -, east +), Z along it. Red spawns
## on the +Z deck and Blue on the -Z deck, so every table is point-symmetric
## through the origin: (x, z) on one half has a twin at (-x, -z). Keep it that
## way when editing - duel_flow_contract checks the mirrored route pairs.
##
## Sizes are plain world units. One blob is BLOB_DIAMETER across, so the court
## is roughly 22 x 30 blobs: room to fling at full charge without the walls
## doing all the work.

const BLOB_RADIUS := 2.8875
const BLOB_DIAMETER := BLOB_RADIUS * 2.0

## Outer footprint (outside faces of the perimeter walls).
const HALF_WIDTH := 64.0
const HALF_LENGTH := 88.0
const FOOTPRINT := Vector2(HALF_WIDTH * 2.0, HALF_LENGTH * 2.0)
const FALL_LIMIT := -30.0
## Decorative lawn around the court, out past where the fog swallows it.
const LAWN_SIZE := 1200.0

## Shell. Solid padded walls to WALL_HEIGHT, glass above them to the roof.
## The walls are the bounce surface the map is named after.
const FLOOR_THICKNESS := 1.0
const WALL_THICKNESS := 3.0
const WALL_HEIGHT := 10.0
const INNER_X := HALF_WIDTH - WALL_THICKNESS
const INNER_Z := HALF_LENGTH - WALL_THICKNESS
const CORNER_POST_RADIUS := 3.2
const GLASS_THICKNESS := 0.4
const ROOF_HEIGHT := 40.0
const ROOF_THICKNESS := 0.4
const ROOF_FRAME_SPACING := 16.0

## Spawn decks: one low team deck against each end wall, with a full-width
## ramp down toward the court.
const SPAWN_DECK_HEIGHT := 2.0
const SPAWN_DECK_WIDTH := 32.0
const SPAWN_DECK_FRONT_Z := 66.0
const SPAWN_RAMP_RUN := 10.0
const SPAWN_MARKER_Z := 74.0
## Top of the blob sits a hair above the deck so it never spawns intersecting.
const SPAWN_MARKER_Y := SPAWN_DECK_HEIGHT + BLOB_RADIUS + 0.16
const SPAWNS := [
	{"name": "RedSpawn", "team": "red", "side": 1.0},
	{"name": "BlueSpawn", "team": "blue", "side": -1.0},
]

## Side decks: raised high ground along the west and east walls, reached by a
## ramp at each end.
const SIDE_DECK_HEIGHT := 7.0
const SIDE_DECK_INNER_X := 38.0
const SIDE_DECK_HALF_Z := 22.0
const SIDE_DECK_WIDTH := INNER_X - SIDE_DECK_INNER_X
const SIDE_DECK_CENTER_X := (SIDE_DECK_INNER_X + INNER_X) * 0.5
const SIDE_RAMP_RUN := 24.0

## Centre mound: a low eight-sided frustum. Gentle enough to roll over, high
## enough to break a flat line of fire across the middle.
const MOUND_SIDES := 8
const MOUND_BASE_RADIUS := 14.0
const MOUND_TOP_RADIUS := 8.5
const MOUND_HEIGHT := 2.2

## Cover walls, all COVER_HEIGHT tall (a little over one blob). Three per half
## plus two centre screens.
const COVER_HEIGHT := 6.5
const COVERS := [
	{"name": "WestScreen", "center": Vector2(-20.0, 0.0), "size": Vector2(3.0, 12.0), "lane": "left", "role": "centre_screen"},
	{"name": "EastScreen", "center": Vector2(20.0, 0.0), "size": Vector2(3.0, 12.0), "lane": "right", "role": "centre_screen"},
	{"name": "RedApproachWall", "center": Vector2(0.0, 40.0), "size": Vector2(18.0, 3.0), "lane": "center", "role": "approach_wall"},
	{"name": "BlueApproachWall", "center": Vector2(0.0, -40.0), "size": Vector2(18.0, 3.0), "lane": "center", "role": "approach_wall"},
	{"name": "RedWestBlock", "center": Vector2(-24.0, 28.0), "size": Vector2(8.0, 8.0), "lane": "left", "role": "flank_block"},
	{"name": "RedEastBlock", "center": Vector2(24.0, 28.0), "size": Vector2(8.0, 8.0), "lane": "right", "role": "flank_block"},
	{"name": "BlueWestBlock", "center": Vector2(-24.0, -28.0), "size": Vector2(8.0, 8.0), "lane": "left", "role": "flank_block"},
	{"name": "BlueEastBlock", "center": Vector2(24.0, -28.0), "size": Vector2(8.0, 8.0), "lane": "right", "role": "flank_block"},
]

## Bounce pads (scenes/interactables/launch_pad.tscn, disc radius ~5.8).
## `direction` is the launch vector before normalising; `height` is the floor
## the pad sits on. Strengths were tuned with a physics probe: a feeder drops
## a resting blob at the mound's edge, a lift lands it on its side deck, and a
## dive lands it beside the centre screens.
const PAD_COLOR_FEED := Color("FFC247")
const PAD_COLOR_DECK := Color("3FD0C9")
const PADS := [
	# Spawn-side feeders throw toward the mound.
	{"name": "RedWestFeeder", "at": Vector2(-26.0, 54.0), "height": 0.0, "direction": Vector3(0.43, 0.5, -0.9), "strength": 85.0, "purpose": "spawn_to_centre", "center": true},
	{"name": "RedEastFeeder", "at": Vector2(26.0, 54.0), "height": 0.0, "direction": Vector3(-0.43, 0.5, -0.9), "strength": 85.0, "purpose": "spawn_to_centre", "center": true},
	{"name": "BlueWestFeeder", "at": Vector2(-26.0, -54.0), "height": 0.0, "direction": Vector3(0.43, 0.5, 0.9), "strength": 85.0, "purpose": "spawn_to_centre", "center": true},
	{"name": "BlueEastFeeder", "at": Vector2(26.0, -54.0), "height": 0.0, "direction": Vector3(-0.43, 0.5, 0.9), "strength": 85.0, "purpose": "spawn_to_centre", "center": true},
	# Court-level pads pop a blob straight up onto the nearest side deck.
	{"name": "WestDeckLift", "at": Vector2(-30.0, 0.0), "height": 0.0, "direction": Vector3(-0.5, 1.0, 0.0), "strength": 85.0, "purpose": "deck_access", "center": false},
	{"name": "EastDeckLift", "at": Vector2(30.0, 0.0), "height": 0.0, "direction": Vector3(0.5, 1.0, 0.0), "strength": 85.0, "purpose": "deck_access", "center": false},
	# Deck pads dive back into the centre fight.
	{"name": "WestDeckDive", "at": Vector2(-SIDE_DECK_CENTER_X, 0.0), "height": SIDE_DECK_HEIGHT, "direction": Vector3(1.0, 0.45, 0.0), "strength": 60.0, "purpose": "deck_to_centre", "center": true},
	{"name": "EastDeckDive", "at": Vector2(SIDE_DECK_CENTER_X, 0.0), "height": SIDE_DECK_HEIGHT, "direction": Vector3(-1.0, 0.45, 0.0), "strength": 60.0, "purpose": "deck_to_centre", "center": true},
]

## Duel flow anchors (roles and lanes read by duel_flow_contract). Heights are
## the floor the anchor stands on.
const FLOW_ANCHORS := [
	{"name": "RedSpawnExit", "at": Vector2(0.0, 60.0), "height": 0.0, "role": "spawn_exit", "lane": "center"},
	{"name": "BlueSpawnExit", "at": Vector2(0.0, -60.0), "height": 0.0, "role": "spawn_exit", "lane": "center"},
	{"name": "MoundContest", "at": Vector2.ZERO, "height": MOUND_HEIGHT, "role": "center_contest", "lane": "center"},
	{"name": "RedWestAttack", "at": Vector2(-33.0, 30.0), "height": 0.0, "role": "attack_route", "lane": "left"},
	{"name": "RedEastAttack", "at": Vector2(33.0, 30.0), "height": 0.0, "role": "attack_route", "lane": "right"},
	{"name": "BlueWestAttack", "at": Vector2(-33.0, -30.0), "height": 0.0, "role": "attack_route", "lane": "left"},
	{"name": "BlueEastAttack", "at": Vector2(33.0, -30.0), "height": 0.0, "role": "attack_route", "lane": "right"},
	{"name": "WestDeckNorth", "at": Vector2(-SIDE_DECK_CENTER_X, 12.0), "height": SIDE_DECK_HEIGHT, "role": "flank_route", "lane": "left"},
	{"name": "WestDeckSouth", "at": Vector2(-SIDE_DECK_CENTER_X, -12.0), "height": SIDE_DECK_HEIGHT, "role": "flank_route", "lane": "left"},
	{"name": "EastDeckNorth", "at": Vector2(SIDE_DECK_CENTER_X, 12.0), "height": SIDE_DECK_HEIGHT, "role": "flank_route", "lane": "right"},
	{"name": "EastDeckSouth", "at": Vector2(SIDE_DECK_CENTER_X, -12.0), "height": SIDE_DECK_HEIGHT, "role": "flank_route", "lane": "right"},
]

## Palette: a bright rubber sports court. Team colours only on the spawn
## decks so sides read at a glance.
const COLOR_COURT := Color("2F7F86")
const COLOR_LINE := Color("F4EBD6")
const COLOR_WALL := Color("27365A")
const COLOR_WALL_TRIM := Color("FFC247")
const COLOR_WALL_BASE := Color("1B2540")
const COLOR_DECK := Color("E9E2CF")
const COLOR_DECK_SIDE := Color("8C94A8")
const COLOR_RAMP := Color("D5D9E0")
const COLOR_CHEVRON := Color("FF7A59")
const COLOR_COVER := Color("F4EBD6")
const COLOR_COVER_CAP := Color("27365A")
const COLOR_MOUND := Color("FF7A59")
const COLOR_MOUND_TOP := Color("F4EBD6")
## Team 0 is the Orange team.
const COLOR_RED := Color("FF7A1A")
const COLOR_BLUE := Color("3C8DDE")
const COLOR_GLASS := Color(0.78, 0.92, 1.0, 0.07)
const COLOR_FRAME := Color("F4EBD6")
const COLOR_LAWN := Color("5C8A4E")


## XZ-plane position plus a height to a world position.
static func world(at: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(at.x, height, at.y)


static func spawn_position(side: float) -> Vector3:
	return Vector3(0.0, SPAWN_MARKER_Y, side * SPAWN_MARKER_Z)


## Camera forward is local -Z, so a yaw of 0 faces -Z: the +Z (red) spawn
## looks straight down the court at the blue deck, and vice versa.
static func spawn_yaw(side: float) -> float:
	return 0.0 if side > 0.0 else PI


## The four side ramps: one at each end of each side deck, rising toward the
## deck (toward z = 0).
static func side_ramps() -> Array[Dictionary]:
	var ramps: Array[Dictionary] = []
	for x_side in [-1.0, 1.0]:
		for z_side in [1.0, -1.0]:
			ramps.append({
				"name": "%s%sRamp" % ["Red" if z_side > 0.0 else "Blue", "West" if x_side < 0.0 else "East"],
				"center": Vector2(x_side * SIDE_DECK_CENTER_X, z_side * (SIDE_DECK_HALF_Z + SIDE_RAMP_RUN * 0.5)),
				"size": Vector2(SIDE_DECK_WIDTH, SIDE_RAMP_RUN),
				# Sign of Z travel from the low end toward the high end.
				"rise_toward": -z_side,
				"height": SIDE_DECK_HEIGHT,
			})
	return ramps


static func spawn_deck_center(side: float) -> Vector2:
	return Vector2(0.0, side * (SPAWN_DECK_FRONT_Z + INNER_Z) * 0.5)


static func spawn_deck_size() -> Vector2:
	return Vector2(SPAWN_DECK_WIDTH, INNER_Z - SPAWN_DECK_FRONT_Z)


static func spawn_ramp(side: float) -> Dictionary:
	return {
		"name": "%sSpawnRamp" % ("Red" if side > 0.0 else "Blue"),
		"center": Vector2(0.0, side * (SPAWN_DECK_FRONT_Z - SPAWN_RAMP_RUN * 0.5)),
		"size": Vector2(SPAWN_DECK_WIDTH, SPAWN_RAMP_RUN),
		"rise_toward": side,
		"height": SPAWN_DECK_HEIGHT,
	}
