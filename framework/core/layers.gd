class_name Layers
extends RefCounted
## The physics layers, in one place. These are the numbers the game already
## uses (VenueKit.VENUE_LAYER, StickProp.LAYER and PUSH_LAYER, Readable's
## layer); new code reads them from here so a change is one edit.
##
##   layer bit (1-based)   who sits on it
##   1  WORLD              the ice, the rink boards, the match
##   2  VENUE              the building: walls, floors, counters, static props
##   3  PROPS              loose and instanced props (PropField rows, LooseProp, StickProp)
##   4  WALKER             a person walking the building (shoves props)
##   5  READ               readable surfaces (signs, notes, screens)

const WORLD := 1
const VENUE := 2
const PROPS := 3
const WALKER := 4
const READ := 5


static func bit(layer: int) -> int:
	return 1 << (layer - 1)


static func mask(layers: Array) -> int:
	var m := 0
	for l in layers:
		m |= bit(l)
	return m
