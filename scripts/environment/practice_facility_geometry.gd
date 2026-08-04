class_name PracticeFacilityGeometry
extends RefCounted

## Pure layout data for the holo training facility - no nodes, no engine calls.
##
## Everything is authored in world units at 1:1 scale. Fixed external
## constraints this layout must respect (all set in scenes/main.tscn):
##   - SpawnManager bound: half-extent 157, fall limit -80
##   - spawn markers at (+/-115, 5, 0) and (0, 5, +/-115), FallbackSpawn (0, 6, 0)
##   - dummies: Rose (-60, -35), Gold (60, 35), Lime (-130, -40),
##     Violet (130, 50), Orange (0, -105)
##   - blob diameter 5.776

const BLOB_DIAMETER := 5.776

## Shell -----------------------------------------------------------------------
const GROUND_SIZE := Vector3(320.0, 2.0, 320.0)
const GROUND_CENTER := Vector3(0.0, -1.0, 0.0)
## Inner faces at +/-158: the blob's centre is physically capped at ~155, inside
## the 157 out-of-bounds line - the same wall/bound relationship the old map had.
const WALL_INNER := 158.0
const WALL_SIZE := Vector3(320.0, 66.0, 2.0)
const WALL_CENTER_Y := 33.0
const ROOF_SIZE := Vector3(330.0, 2.0, 330.0)
const ROOF_UNDERSIDE_Y := 66.0
const PYLON_SIZE := Vector3(4.0, 66.0, 4.0)
const PYLON_POSITIONS: Array[Vector3] = [
	Vector3(-150, 33, -150), Vector3(150, 33, -150),
	Vector3(-150, 33, 150), Vector3(150, 33, 150),
	Vector3(-150, 33, 0), Vector3(150, 33, 0),
	Vector3(0, 33, -150), Vector3(0, 33, 150),
]

## Colour language --------------------------------------------------------------
const COLOR_STRUCTURE := Color(0.10, 0.85, 1.0)   # cyan - grid, walls, trim
const COLOR_TARGET := Color(1.0, 0.25, 0.85)       # magenta - things to hit
const COLOR_MOVEMENT := Color(1.0, 0.72, 0.15)     # amber - pads, ramps, routes
const COLOR_SAFE := Color(0.30, 1.0, 0.55)         # green - spawns, safe ground
const COLOR_DECK := Color(0.05, 0.07, 0.11)        # dark structure body

## Centre hub (FallbackSpawn lands at the origin - keep r < 8 free of collision
## above the floor) --------------------------------------------------------------
const HUB_FLOOR_RINGS := [
	{"radius": 6.0, "color": COLOR_TARGET},
	{"radius": 9.0, "color": COLOR_STRUCTURE},
]
const HUB_CORE_RING_RADII: Array[float] = [3.0, 4.2, 5.4]
const HUB_CORE_BASE_Y := 11.0
const SPAWN_DISC_POSITIONS: Array[Vector3] = [
	Vector3(-115, 0.06, 0), Vector3(115, 0.06, 0),
	Vector3(0, 0.06, -115), Vector3(0, 0.06, 115),
]

## Zone 1 - FLING RANGE (west lane; Rose is the mid target, Lime the long one) --
const RANGE_LANE_Z := -40.0
const RANGE_TEE := Vector3(-18, 0.06, -40)
const RANGE_RAIL_Z := [-54.5, -25.5]
const RANGE_RAIL_SIZE := Vector3(134.0, 0.1, 0.4)
const RANGE_RAIL_CENTER_X := -85.0
## Tick marks every 20 m of fling distance from the tee at x = -18.
const RANGE_TICK_XS: Array[float] = [-38.0, -58.0, -78.0, -98.0, -118.0, -138.0]
const RANGE_TICK_SIZE := Vector3(0.5, 0.08, 26.0)
## Upright rings to fling through - taller and further as charge grows.
const RANGE_RINGS := [
	{"center": Vector3(-78, 5, -40), "radius": 4.0},
	{"center": Vector3(-108, 7, -40), "radius": 3.0},
	{"center": Vector3(-142, 9, -40), "radius": 2.5},
]
## Extra rings woven into the other zones: one threaded between the tower decks
## (fling through it mid-chain), one at the gallery mouth.
const EXTRA_RINGS := [
	{"center": Vector3(14, 21, -117), "radius": 3.5},
	{"center": Vector3(82, 6, 50), "radius": 3.0},
]
## TAP / FULL SEND arcs, from measured landings (practice_calibration_probe):
## a tap from the tee rests ~48 units down-range; a full send crosses the whole
## lane and splats on the west wall, so its arc marks the splat line.
const RANGE_TAP_ARC_X := -66.0
const RANGE_FULL_ARC_X := -152.0
const RANGE_DECK := {"center": Vector3(-60, 7, -70), "size": Vector3(28, 2, 12)}

## Zone 2 - RICOCHET GALLERY (east; Violet sits in a pocket you can only bank
## into) --------------------------------------------------------------------------
const GALLERY_BANK_WALLS := [
	{"center": Vector3(94, 4, 24), "yaw_degrees": 35.0},
	{"center": Vector3(120, 4, 18), "yaw_degrees": -40.0},
	{"center": Vector3(94, 4, 76), "yaw_degrees": -35.0},
	{"center": Vector3(120, 4, 82), "yaw_degrees": 40.0},
	{"center": Vector3(146, 4, 50), "yaw_degrees": 90.0},
]
const GALLERY_BANK_SIZE := Vector3(10.0, 8.0, 1.5)
const GALLERY_CHEVRON_POSITIONS: Array[Vector3] = [
	Vector3(86, 0.07, 34), Vector3(97, 0.07, 42), Vector3(108, 0.07, 47),
	Vector3(86, 0.07, 66), Vector3(97, 0.07, 58), Vector3(108, 0.07, 53),
]
const GALLERY_DECK := {"center": Vector3(110, 7, 115), "size": Vector3(28, 2, 14)}

## Zone 3 - BOUNCE TOWERS (north; Orange stands among the towers as the aerial
## target) ------------------------------------------------------------------------
const TOWER_DECKS := [
	{"prefix": "TowerADeck", "center": Vector3(-30, 9, -108), "size": Vector3(16, 2, 16)},
	{"prefix": "TowerBDeck", "center": Vector3(0, 17, -126), "size": Vector3(12, 2, 12)},
	{"prefix": "TowerCDeck", "center": Vector3(28, 25, -108), "size": Vector3(10, 2, 10)},
]
## impulse tuned during calibration so each arc lands centre-deck.
## Impulses measured in-engine (practice_calibration_probe): 70 rises +12.9,
## 60 rises +9.5, 55 ~ +8 - each clears its deck by about a blob radius.
const BOUNCE_PADS := [
	{"position": Vector3(-30, 0.7, -86), "impulse": 70.0},
	{"position": Vector3(-30, 10.7, -108), "impulse": 60.0},
	{"position": Vector3(0, 18.7, -126), "impulse": 60.0},
	{"position": Vector3(-150, 0.7, -40), "impulse": 55.0},
	{"position": Vector3(60, 0.7, 12), "impulse": 55.0},
]

## Zone 4 - SPAR RING (south-east; Gold anchors a close-quarters circle) ---------
const SPAR_RING_CENTER := Vector3(60, 0.06, 35)
const SPAR_RING_RADIUS := 10.0
const SPAR_RINGS := [
	{"center": Vector3(60, 5, 55), "radius": 3.5},
	{"center": Vector3(78, 6, 35), "radius": 3.0},
]
const SPAR_DECK := {"center": Vector3(60, 7, 92), "size": Vector3(24, 2, 12)}

## Ramps: 8 closed wedges, run 18 wide 6, rising to their deck top with no lip.
## Pairing (prefix -> landing prefix) is asserted by map_geometry_contract.
const RAMPS := [
	{"prefix": "RangeRamp_E", "deck": "RangeDeck", "foot": Vector3(-41, 0, -70), "toward": Vector3(-1, 0, 0)},
	{"prefix": "RangeRamp_W", "deck": "RangeDeck", "foot": Vector3(-79, 0, -70), "toward": Vector3(1, 0, 0)},
	{"prefix": "GalleryRamp_E", "deck": "GalleryDeck", "foot": Vector3(129, 0, 115), "toward": Vector3(-1, 0, 0)},
	{"prefix": "GalleryRamp_W", "deck": "GalleryDeck", "foot": Vector3(91, 0, 115), "toward": Vector3(1, 0, 0)},
	{"prefix": "SparRamp_E", "deck": "SparDeck", "foot": Vector3(77, 0, 92), "toward": Vector3(-1, 0, 0)},
	{"prefix": "SparRamp_W", "deck": "SparDeck", "foot": Vector3(43, 0, 92), "toward": Vector3(1, 0, 0)},
	{"prefix": "TowerRamp_W", "deck": "TowerADeck", "foot": Vector3(-43, 0, -108), "toward": Vector3(1, 0, 0)},
	{"prefix": "TowerRamp_S", "deck": "TowerADeck", "foot": Vector3(-30, 0, -95), "toward": Vector3(0, 0, -1)},
]
const RAMP_RUN := 18.0
const RAMP_WIDTH := 6.0
const RAMP_THICKNESS := 1.0

## Signage ------------------------------------------------------------------------
const ZONE_SIGNS := [
	{"text": "FLING RANGE", "position": Vector3(-60, 14, -58), "yaw_degrees": 0.0, "color": COLOR_MOVEMENT},
	{"text": "RICOCHET GALLERY", "position": Vector3(110, 14, 100), "yaw_degrees": 180.0, "color": COLOR_TARGET},
	{"text": "BOUNCE TOWERS", "position": Vector3(0, 30, -130), "yaw_degrees": 0.0, "color": COLOR_MOVEMENT},
	{"text": "SPAR RING", "position": Vector3(60, 12, 78), "yaw_degrees": 180.0, "color": COLOR_TARGET},
]
## Fixed dummy positions (from main.tscn) - used to place spotlight discs.
const DUMMY_POSITIONS: Array[Vector3] = [
	Vector3(-60, 0, -35), Vector3(60, 0, 35), Vector3(-130, 0, -40),
	Vector3(130, 0, 50), Vector3(0, 0, -105),
]


## Deck top height for a ramp entry, resolved from the deck tables.
static func deck_top_y(deck_prefix: String) -> float:
	match deck_prefix:
		"RangeDeck":
			return RANGE_DECK["center"].y + RANGE_DECK["size"].y * 0.5
		"GalleryDeck":
			return GALLERY_DECK["center"].y + GALLERY_DECK["size"].y * 0.5
		"SparDeck":
			return SPAR_DECK["center"].y + SPAR_DECK["size"].y * 0.5
		"TowerADeck":
			var tower := TOWER_DECKS[0] as Dictionary
			return (tower["center"] as Vector3).y + (tower["size"] as Vector3).y * 0.5
	return 0.0
