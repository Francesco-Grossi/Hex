## ProjectileData.gd
## Central definition of projectile kinds and the rules that govern them.
##
## Kind.ARROW  — flies in a straight line, blocked by:
##               • any living unit (other than the shooter's own hex)
##               • Forest overlay
##               • Building overlay
##               • Wall overlay
##               The hex where blocking occurs is the one the projectile
##               reaches before the blocker; damage is dealt to a unit
##               blocker only if it is an enemy of the attacker.
##
## Kind.ARC    — follows a high parabolic arc, passes over everything,
##               always lands on the target hex.  Used by catapults,
##               mages lobbing fireballs, etc.
##
## UnitData entries with "attack_range" > 1 are treated as ranged.
## "projectile_kind" selects which animation plays.
## Melee units (attack_range == 1) do NOT use projectiles.

class_name ProjectileData

enum Kind {
	ARROW,   ## straight, blockable
	ARC,     ## parabolic, unblockable
}

## Per-kind visual defaults (used by Projectile._draw if no color override)
const KIND_COLOR: Dictionary = {
	Kind.ARROW: Color(0.85, 0.78, 0.40),   # warm tan
	Kind.ARC:   Color(0.95, 0.55, 0.15),   # fiery orange
}

## For line-of-sight: which overlay types block an ARROW mid-flight.
## Note: NONE does not block; only solid terrain features do.
const ARROW_BLOCKING_OVERLAYS: Array = [
	# TerrainData.Overlay values:
	1,   # FOREST
	2,   # BUILDING
	3,   # WALL
]

## Convenience: return true if the overlay on a cell blocks arrows.
static func overlay_blocks_arrow(overlay: int) -> bool:
	return overlay in ARROW_BLOCKING_OVERLAYS
