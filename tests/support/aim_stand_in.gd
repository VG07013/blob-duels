extends Node3D

## Test-only stand-in for the player in dodge and combat mode checks.
##
## It exposes the single property a training dummy reads off its target. The
## real BlobPlayer rewrites aim_direction from its own facing every physics
## frame, so it cannot be pointed anywhere from a test; this can.
##
## Lives under tests/support/ so run_tests.sh, which globs tests/*.gd, never
## mistakes it for a contract.

var aim_direction := Vector3.FORWARD
