class_name TrainingYardGeometry
extends RefCounted

## Pure layout data for the Training Yard, the third competitive map: a
## drill hall laid out like a firing range. No nodes are built here;
## training_yard_builder.gd turns these tables into geometry.
##
## World axes match Bounceground: X across the hall (west -, east +), Z along
## it. Red spawns on the +Z deck and Blue on the -Z deck, and every table is
## point-symmetric through the origin ((x, z) has a twin at (-x, -z)) because
## duel_flow_contract checks the mirrored route pairs.
##
## The hall is 120 x 160 units (about 21 x 28 blobs): a central raised
## "ring" platform to fight over, a target pillar either side of it, four
## low blocks and two approach walls that cut the lanes like range dividers,
## a gallery along each long wall reached by a ramp at each end, and launch
## pads that feed everything toward the ring.

const BLOB_RADIUS := 2.8875
const BLOB_DIAMETER := BLOB_RADIUS * 2.0

## Outer footprint (outside faces of the perimeter walls).
const HALF_WIDTH := 60.0
const HALF_LENGTH := 80.0
const FOOTPRINT := Vector2(HALF_WIDTH * 2.0, HALF_LENGTH * 2.0)
const FALL_LIMIT := -30.0
const APRON_SIZE := 1200.0

## Shell: solid walls to WALL_HEIGHT (the bounce surface), glass to the roof.
const FLOOR_THICKNESS := 1.0
const WALL_THICKNESS := 3.0
const WALL_HEIGHT := 9.0
const INNER_X := HALF_WIDTH - WALL_THICKNESS
const INNER_Z := HALF_LENGTH - WALL_THICKNESS
const CORNER_POST_RADIUS := 3.0
const GLASS_THICKNESS := 0.4
const ROOF_HEIGHT := 36.0
const ROOF_THICKNESS := 0.4
const ROOF_FRAME_SPACING := 15.0

## Spawn decks against each end wall with a full-width ramp down to the lanes.
const SPAWN_DECK_HEIGHT := 2.0
const SPAWN_DECK_WIDTH := 32.0
const SPAWN_DECK_FRONT_Z := 60.0
const SPAWN_RAMP_RUN := 10.0
const SPAWN_MARKER_Z := 70.0
const SPAWN_MARKER_Y := SPAWN_DECK_HEIGHT + BLOB_RADIUS + 0.16
const SPAWNS := [
	{"name": "RedSpawn", "team": "red", "side": 1.0},
	{"name": "BlueSpawn", "team": "blue", "side": -1.0},
]

## Galleries: raised walkways along the west and east walls, a ramp at each end.
const GALLERY_HEIGHT := 6.0
const GALLERY_INNER_X := 46.0
const GALLERY_HALF_Z := 20.0
const GALLERY_WIDTH := INNER_X - GALLERY_INNER_X
const GALLERY_CENTER_X := (GALLERY_INNER_X + INNER_X) * 0.5
const GALLERY_RAMP_RUN := 20.0

## The ring: an eight-sided raised platform in the middle of the hall, high
## enough to be the high ground and gentle enough to roll onto.
const RING_SIDES := 8
const RING_BASE_RADIUS := 16.0
const RING_TOP_RADIUS := 11.0
const RING_HEIGHT := 3.0

## Cover: two target pillars flanking the ring, and per half an approach wall
## plus two blocks. All COVER_HEIGHT tall (a little over one blob).
const COVER_HEIGHT := 6.2
const COVERS := [
	{"name": "WestPillar", "center": Vector2(-22.0, 0.0), "size": Vector2(3.0, 12.0), "lane": "left", "role": "centre_screen"},
	{"name": "EastPillar", "center": Vector2(22.0, 0.0), "size": Vector2(3.0, 12.0), "lane": "right", "role": "centre_screen"},
	{"name": "RedApproachWall", "center": Vector2(0.0, 36.0), "size": Vector2(18.0, 3.0), "lane": "center", "role": "approach_wall"},
	{"name": "BlueApproachWall", "center": Vector2(0.0, -36.0), "size": Vector2(18.0, 3.0), "lane": "center", "role": "approach_wall"},
	{"name": "RedWestBlock", "center": Vector2(-22.0, 26.0), "size": Vector2(8.0, 8.0), "lane": "left", "role": "flank_block"},
	{"name": "RedEastBlock", "center": Vector2(22.0, 26.0), "size": Vector2(8.0, 8.0), "lane": "right", "role": "flank_block"},
	{"name": "BlueWestBlock", "center": Vector2(-22.0, -26.0), "size": Vector2(8.0, 8.0), "lane": "left", "role": "flank_block"},
	{"name": "BlueEastBlock", "center": Vector2(22.0, -26.0), "size": Vector2(8.0, 8.0), "lane": "right", "role": "flank_block"},
]

## Launch pads (scenes/interactables/launch_pad.tscn). Feeders throw a blob
## from the lanes onto the ring, lifts pop it up to its gallery, dives bring
## it back down into the fight.
const PAD_COLOR_FEED := Color("05D1FF")
const PAD_COLOR_DECK := Color("FF8A3D")
const PADS := [
	{"name": "RedWestFeeder", "at": Vector2(-24.0, 48.0), "height": 0.0, "direction": Vector3(0.45, 0.5, -0.9), "strength": 84.0, "purpose": "spawn_to_centre", "center": true},
	{"name": "RedEastFeeder", "at": Vector2(24.0, 48.0), "height": 0.0, "direction": Vector3(-0.45, 0.5, -0.9), "strength": 84.0, "purpose": "spawn_to_centre", "center": true},
	{"name": "BlueWestFeeder", "at": Vector2(-24.0, -48.0), "height": 0.0, "direction": Vector3(0.45, 0.5, 0.9), "strength": 84.0, "purpose": "spawn_to_centre", "center": true},
	{"name": "BlueEastFeeder", "at": Vector2(24.0, -48.0), "height": 0.0, "direction": Vector3(-0.45, 0.5, 0.9), "strength": 84.0, "purpose": "spawn_to_centre", "center": true},
	{"name": "WestGalleryLift", "at": Vector2(-34.0, 0.0), "height": 0.0, "direction": Vector3(-0.5, 1.0, 0.0), "strength": 80.0, "purpose": "gallery_access", "center": false},
	{"name": "EastGalleryLift", "at": Vector2(34.0, 0.0), "height": 0.0, "direction": Vector3(0.5, 1.0, 0.0), "strength": 80.0, "purpose": "gallery_access", "center": false},
	{"name": "WestGalleryDive", "at": Vector2(-GALLERY_CENTER_X, 0.0), "height": GALLERY_HEIGHT, "direction": Vector3(1.0, 0.45, 0.0), "strength": 60.0, "purpose": "gallery_to_centre", "center": true},
	{"name": "EastGalleryDive", "at": Vector2(GALLERY_CENTER_X, 0.0), "height": GALLERY_HEIGHT, "direction": Vector3(-1.0, 0.45, 0.0), "strength": 60.0, "purpose": "gallery_to_centre", "center": true},
]

## Duel flow anchors (roles and lanes read by duel_flow_contract). Heights are
## the floor the anchor stands on.
const FLOW_ANCHORS := [
	{"name": "RedSpawnExit", "at": Vector2(0.0, 54.0), "height": 0.0, "role": "spawn_exit", "lane": "center"},
	{"name": "BlueSpawnExit", "at": Vector2(0.0, -54.0), "height": 0.0, "role": "spawn_exit", "lane": "center"},
	{"name": "RingContest", "at": Vector2.ZERO, "height": RING_HEIGHT, "role": "center_contest", "lane": "center"},
	{"name": "RedWestAttack", "at": Vector2(-32.0, 28.0), "height": 0.0, "role": "attack_route", "lane": "left"},
	{"name": "RedEastAttack", "at": Vector2(32.0, 28.0), "height": 0.0, "role": "attack_route", "lane": "right"},
	{"name": "BlueWestAttack", "at": Vector2(-32.0, -28.0), "height": 0.0, "role": "attack_route", "lane": "left"},
	{"name": "BlueEastAttack", "at": Vector2(32.0, -28.0), "height": 0.0, "role": "attack_route", "lane": "right"},
	{"name": "WestGalleryNorth", "at": Vector2(-GALLERY_CENTER_X, 11.0), "height": GALLERY_HEIGHT, "role": "flank_route", "lane": "left"},
	{"name": "WestGallerySouth", "at": Vector2(-GALLERY_CENTER_X, -11.0), "height": GALLERY_HEIGHT, "role": "flank_route", "lane": "left"},
	{"name": "EastGalleryNorth", "at": Vector2(GALLERY_CENTER_X, 11.0), "height": GALLERY_HEIGHT, "role": "flank_route", "lane": "right"},
	{"name": "EastGallerySouth", "at": Vector2(GALLERY_CENTER_X, -11.0), "height": GALLERY_HEIGHT, "role": "flank_route", "lane": "right"},
]

## Palette: a drill hall in charcoal and slate with one cyan accent (the same
## accent as the Arena), team colours only on the spawn decks.
const COLOR_FLOOR := Color("23272E")
const COLOR_LINE := Color("05D1FF")
const COLOR_LINE_DIM := Color("8FA3B8")
const COLOR_WALL := Color("2B3340")
const COLOR_WALL_TRIM := Color("05D1FF")
const COLOR_WALL_BASE := Color("151A21")
const COLOR_DECK := Color("DCE3EA")
const COLOR_DECK_SIDE := Color("5B6675")
const COLOR_RAMP := Color("C7CFD8")
const COLOR_CHEVRON := Color("05D1FF")
const COLOR_COVER := Color("E8ECF1")
const COLOR_COVER_CAP := Color("05D1FF")
const COLOR_RING := Color("3A4452")
const COLOR_RING_TOP := Color("DCE3EA")
## Team 0 is the Orange team.
const COLOR_RED := Color("FF7A1A")
const COLOR_BLUE := Color("3C8DDE")
const COLOR_GLASS := Color(0.75, 0.9, 1.0, 0.07)
const COLOR_FRAME := Color("C7CFD8")
const COLOR_APRON := Color("1C2026")


## XZ-plane position plus a height to a world position.
static func world(at: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(at.x, height, at.y)


static func spawn_position(side: float) -> Vector3:
	return Vector3(0.0, SPAWN_MARKER_Y, side * SPAWN_MARKER_Z)


## Camera forward is local -Z, so a yaw of 0 faces -Z: the +Z (red) spawn
## looks straight down the hall at the blue deck, and vice versa.
static func spawn_yaw(side: float) -> float:
	return 0.0 if side > 0.0 else PI


## The four gallery ramps: one at each end of each gallery, rising toward
## the gallery (toward z = 0).
static func gallery_ramps() -> Array[Dictionary]:
	var ramps: Array[Dictionary] = []
	for x_side in [-1.0, 1.0]:
		for z_side in [1.0, -1.0]:
			ramps.append({
				"name": "%s%sRamp" % ["Red" if z_side > 0.0 else "Blue", "West" if x_side < 0.0 else "East"],
				"center": Vector2(x_side * GALLERY_CENTER_X, z_side * (GALLERY_HALF_Z + GALLERY_RAMP_RUN * 0.5)),
				"size": Vector2(GALLERY_WIDTH, GALLERY_RAMP_RUN),
				"rise_toward": -z_side,
				"height": GALLERY_HEIGHT,
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
