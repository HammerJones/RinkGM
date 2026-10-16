class_name SkaterStats
extends Resource
## A skater's ratings on a 1..99 scale. Game mechanics (progression, aging,
## injuries) owns the values; physics only reads them through `n()` and
## PhysicsProfile, which turns them into speeds, forces and error margins.

@export_range(1, 99) var speed := 50           ## top speed and stride power
@export_range(1, 99) var agility := 50         ## turning, edges, stops, balance
@export_range(1, 99) var stick_handling := 50  ## blade speed and puck grip
@export_range(1, 99) var shot_accuracy := 50
@export_range(1, 99) var shot_power := 50
@export_range(1, 99) var shot_release := 50    ## how good a shot is with no wind-up
@export_range(1, 99) var pass_quality := 50    ## pass accuracy and receiving
@export_range(1, 99) var hitting := 50         ## how hard you hit
@export_range(1, 99) var toughness := 50       ## how hard you are to knock down

const NAMES: Array[StringName] = [
	&"speed", &"agility", &"stick_handling", &"shot_accuracy", &"shot_power",
	&"shot_release", &"pass_quality", &"hitting", &"toughness",
]


## The rating as 0..1.
func n(stat: StringName) -> float:
	return clampf((float(get(stat)) - 1.0) / 98.0, 0.0, 1.0)


static func uniform(rating: int) -> SkaterStats:
	var s := SkaterStats.new()
	for k in NAMES:
		s.set(k, rating)
	return s


## Every rating near `rating`, +- `spread`.
static func around(rating: int, spread: int) -> SkaterStats:
	var s := SkaterStats.new()
	for k in NAMES:
		s.set(k, clampi(rating + randi_range(-spread, spread), 1, 99))
	return s


func describe() -> String:
	var parts := []
	for k in NAMES:
		parts.append("%s %d" % [k, get(k)])
	return ", ".join(parts)
