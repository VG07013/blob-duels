class_name NetworkTuning
extends RefCounted

## Central tuning for the peer-to-peer transport layer. Gameplay and rendering
## code read these rather than embedding numbers in the interpolation or
## ping paths, same as AbilityTuning does for abilities.

## How far behind the host clock remote blobs are rendered. Two snapshots at
## the 30 Hz sync rate fit inside this window, so a single lost packet is
## bridged by interpolation instead of a visible hitch.
const INTERPOLATION_DELAY_MSEC := 100

## When the buffer runs dry the last snapshot is advanced along its velocity
## for at most this long, then held. Beyond this the guess is worse than a
## pause.
const MAX_EXTRAPOLATION_MSEC := 150

## A gap between consecutive snapshots implying a speed above this is treated
## as a teleport (respawn, blink) and snapped rather than interpolated. The
## host caps legitimate remote speed at MAX_REMOTE_STATE_SPEED (138 u/s), so
## anything faster cannot be movement.
const TELEPORT_SPEED := 160.0

## A gap this large snaps regardless of the time between snapshots, which
## covers a stale buffer resuming after a long stall.
const TELEPORT_DISTANCE := 12.0

## Ping cadence and smoothing. The RTT readout is an exponential moving
## average so one late packet does not flicker the HUD.
const PING_INTERVAL_SEC := 1.0
const PING_SMOOTHING := 0.25
const PING_SAMPLE_TIMEOUT_MSEC := 3000

## HUD colour thresholds for the ping readout, in milliseconds.
const PING_GOOD_MSEC := 60
const PING_FAIR_MSEC := 120

## UPnP discovery budget. discover() blocks for the full timeout when no
## gateway answers, which is why it always runs off the main thread.
const UPNP_DISCOVER_TIMEOUT_MSEC := 2000
const UPNP_DISCOVER_TTL := 2
const UPNP_MAPPING_DESCRIPTION := "Blob Duels"
