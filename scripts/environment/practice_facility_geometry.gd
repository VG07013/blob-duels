class_name PracticeFacilityGeometry
extends RefCounted

## Pure layout data for the practice training grounds - no nodes, no engine
## calls. Rebuilt 1:1 from the "Practice Map - Blueprint" sheet.
##
## Blueprint convention: a 28 x 15 grid-unit (GU) top-down sheet, origin at the
## bottom-left corner, +GridX to the right, +GridY toward the top. 1 GU is half
## a blob diameter. The sheet's top edge faces world -Z:
##   world_x = (grid_x - 14.0) * GU
##   world_z = (7.5 - grid_y) * GU
## Fixed external constraints (scenes/main.tscn): SpawnManager bound 157 /
## fall limit -80 stay as the outer safety net, the FallbackSpawn drops at the
## origin onto the centre platform, and the eight training dummies sit on the
## stations tabled below.

const BLOB_DIAMETER := 5.776
const GU := 2.888

## Sheet footprint --------------------------------------------------------------
const GRID_WIDTH := 28.0
const GRID_LENGTH := 15.0
const FLOOR_SIZE := Vector3(GRID_WIDTH * GU, 0.35 * GU, GRID_LENGTH * GU)
## Surrounding lawn apron so the outdoor facility does not float in the sky;
## sized to the SpawnManager safety bound, top flush with the turf underside
## so the two ground plates touch without interpenetrating.
const APRON_SIZE := Vector3(320.0, 1.0, 320.0)
const APRON_TOP_Y := -0.35 * GU

## Colour palette (spec: controlled, no rainbow, no neon) ------------------------
const COLOR_TURF := Color("527542")
const COLOR_TURF_DARK := Color("425F36")
const COLOR_GRID_LINE := Color("5E8050")
const COLOR_WALL := Color("252A2E")
const COLOR_WALL_TRIM := Color("41484F")
const COLOR_BLOCK := Color("8B9095")
const COLOR_LIGHT_PANEL := Color("C9CDD0")
const COLOR_ORANGE := Color("F17C24")
const COLOR_BLUE := Color("327CC5")
const COLOR_RED := Color("D8493F")
const COLOR_WHITE := Color("D9DDE0")
const COLOR_BASE_TRIM := Color("1B1F22")

## Perimeter walls (solid band, 0..3 GU) -----------------------------------------
const WALL_THICKNESS := 0.5 * GU
const WALL_HEIGHT := 3.0 * GU
const WALL_INNER_X := 13.5 * GU
const WALL_INNER_Z := 7.0 * GU
const CORNER_ROUND_RADIUS := 0.75 * GU

## Transparent upper enclosure (3..5 GU) and canopy roof at 5 GU ------------------
const ENCLOSURE_THICKNESS := 0.15 * GU
const ENCLOSURE_BASE_Y := WALL_HEIGHT
const ENCLOSURE_TOP_Y := 5.0 * GU
const ROOF_UNDERSIDE_Y := 5.0 * GU
const ROOF_SIZE := Vector3(GRID_WIDTH * GU, 0.15 * GU, GRID_LENGTH * GU)

## Centre spawn platform (octagonal frustum, flat top, ramped skirt) --------------
const PLATFORM_TOP_Y := 0.6 * GU
const PLATFORM_TOP_HALF_X := 2.25 * GU
const PLATFORM_TOP_HALF_Z := 2.0 * GU
const PLATFORM_CORNER_CUT := 3.5
## 0.7 GU skirt keeps the base inside the 3 GU shooting circle.
const PLATFORM_SKIRT := 0.7 * GU

## Dummy stations (blueprint grid coords; raised stations get a pedestal) --------
## Station letters follow the spec sheet: A-C upper row, D-E middle, F-H lower.
const PEDESTAL_HEIGHT := 0.4 * GU
const PEDESTAL_RADIUS := 0.8 * GU
const STATION_RING_RADIUS := 1.25 * GU
const DUMMY_STATIONS := [
	{"letter": "A", "grid": Vector2(5.0, 13.0), "raised": false},
	{"letter": "B", "grid": Vector2(14.0, 12.5), "raised": true},
	{"letter": "C", "grid": Vector2(23.0, 13.0), "raised": false},
	{"letter": "D", "grid": Vector2(5.0, 9.5), "raised": false},
	{"letter": "E", "grid": Vector2(23.0, 9.5), "raised": false},
	{"letter": "F", "grid": Vector2(5.0, 3.5), "raised": false},
	{"letter": "G", "grid": Vector2(14.0, 2.3), "raised": true},
	{"letter": "H", "grid": Vector2(23.0, 3.5), "raised": false},
]

## Low cover blocks (3 x 1.8 x 1.2 GU, box collision) -----------------------------
const COVER_SIZE := Vector3(3.0 * GU, 1.2 * GU, 1.8 * GU)
const COVER_GRID_POSITIONS: Array[Vector2] = [
	Vector2(10.0, 10.0), Vector2(18.0, 10.0),
	Vector2(10.0, 5.0), Vector2(18.0, 5.0),
]

## Broad side ramps (4 GU run rising to 1.6 GU at the wall end, curved profile) ---
## "sign" is the world-X direction of travel up the ramp; the high edge sits
## 1 GU clear of the wall, matching the sheet.
const SIDE_RAMP_WIDTH := 3.0 * GU
const SIDE_RAMP_RUN := 4.0 * GU
const SIDE_RAMP_HEIGHT := 1.6 * GU
const SIDE_RAMP_SEGMENTS := 4
const SIDE_RAMPS := [
	{"prefix": "SideRampWest", "grid_center": Vector2(3.5, 7.5), "sign": -1.0},
	{"prefix": "SideRampEast", "grid_center": Vector2(24.5, 7.5), "sign": 1.0},
]

## Wedge ramps (3 x 2.5 GU rising to 1.2 GU), each aimed at its corner dummy lane.
const WEDGE_WIDTH := 3.0 * GU
const WEDGE_RUN := 2.5 * GU
const WEDGE_HEIGHT := 1.2 * GU
const WEDGES := [
	{"prefix": "WedgeUpperLeft", "grid": Vector2(8.0, 11.0), "aim_letter": "A"},
	{"prefix": "WedgeUpperRight", "grid": Vector2(20.0, 11.0), "aim_letter": "C"},
	{"prefix": "WedgeLowerLeft", "grid": Vector2(8.0, 4.0), "aim_letter": "F"},
	{"prefix": "WedgeLowerRight", "grid": Vector2(20.0, 4.0), "aim_letter": "H"},
]

## Training hop pads (0.9 GU discs, light bounce only) ----------------------------
const HOP_PAD_RADIUS := 0.45 * GU
const HOP_PAD_HEIGHT := 0.18 * GU
## Small controlled hops - about half a blob of rise with the current
## controller (bounce-pad impulse 55 measured ~+8 during BUG-028 calibration).
const HOP_PAD_IMPULSE := 24.0
const HOP_PAD_GRID_POSITIONS: Array[Vector2] = [
	Vector2(9.0, 12.4), Vector2(10.5, 12.4), Vector2(12.0, 12.4),
	Vector2(16.0, 12.4), Vector2(17.5, 12.4), Vector2(19.0, 12.4),
	Vector2(9.0, 2.0), Vector2(10.5, 2.0), Vector2(12.0, 2.0),
	Vector2(16.0, 2.0), Vector2(17.5, 2.0), Vector2(19.0, 2.0),
]

## Wall bounce panels (5 x 2 GU, centre 1.5 GU up, 0.15 GU proud of the wall) -----
const PANEL_WIDTH := 5.0 * GU
const PANEL_HEIGHT := 2.0 * GU
const PANEL_CENTER_Y := 1.5 * GU
const PANEL_PROTRUSION := 0.15 * GU
const PANEL_SPEED_MULTIPLIER := 1.10
const PANEL_MINIMUM_SPEED := 6.0
## Face anchor = the wall's inner face; the panel protrudes inward from it.
const REBOUND_PANELS := [
	{"name": "ReboundPanelNorth", "face": Vector3(0.0, 1.5 * GU, -7.0 * GU), "inward": Vector3(0, 0, 1)},
	{"name": "ReboundPanelSouth", "face": Vector3(0.0, 1.5 * GU, 7.0 * GU), "inward": Vector3(0, 0, -1)},
	{"name": "ReboundPanelWest", "face": Vector3(-13.5 * GU, 1.5 * GU, 0.0), "inward": Vector3(1, 0, 0)},
	{"name": "ReboundPanelEast", "face": Vector3(13.5 * GU, 1.5 * GU, 0.0), "inward": Vector3(-1, 0, 0)},
]

## Floor markings (all visual only) -----------------------------------------------
const GRID_LINE_WIDTH := 0.06
const CROSSHAIR_LINE_WIDTH := 0.08 * GU
const CROSSHAIR_X_SPAN := Vector2(7.0, 21.0)
const CROSSHAIR_Y_SPAN := Vector2(2.0, 13.0)
const SHOOTING_CIRCLE_RADIUS := 3.0 * GU


## Blueprint grid -> world conversion. Height is passed straight through.
static func world(grid: Vector2, height: float = 0.0) -> Vector3:
	return Vector3((grid.x - 14.0) * GU, height, (7.5 - grid.y) * GU)


static func station_by_letter(letter: String) -> Dictionary:
	for station_value in DUMMY_STATIONS:
		var station := station_value as Dictionary
		if str(station["letter"]) == letter:
			return station
	return {}


## Y of the surface a dummy on this station rests on.
static func station_floor_y(station: Dictionary) -> float:
	return PEDESTAL_HEIGHT if bool(station["raised"]) else 0.0
