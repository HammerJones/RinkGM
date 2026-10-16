class_name Names
extends RefCounted
## Name pools for generated players and clubs.

const FIRST := [
	"Mike", "Dave", "Chris", "Matt", "Ryan", "Kevin", "Jason", "Brian", "Tyler", "Josh", "Nick", "Adam",
	"Dan", "Steve", "Mark", "Paul", "Jeff", "Scott", "Eric", "Kyle", "Derek", "Brett", "Cody", "Shane",
	"Luke", "Evan", "Connor", "Liam", "Owen", "Jake", "Sam", "Alex", "Jordan", "Casey", "Riley", "Drew",
	"Pat", "Sean", "Colin", "Brendan", "Travis", "Wade", "Dale", "Gord", "Doug", "Teemu", "Mats", "Ilya",
	"Viktor", "Jori", "Marc-Andre", "Jean", "Felix", "Anton", "Nils", "Erik", "Sasha", "Dmitri", "Petr",
]
const LAST := [
	"Anderson", "Boucher", "Campbell", "Doyle", "Ellis", "Fraser", "Gagnon", "Hughes", "Iverson", "Jensen",
	"Kowalski", "Larsen", "MacDonald", "Novak", "O'Brien", "Peterson", "Quinn", "Roy", "Sullivan", "Tremblay",
	"Underwood", "Vachon", "Walsh", "Young", "Zelinski", "Barrett", "Côté", "Dumont", "Fischer", "Grant",
	"Holmström", "Kerr", "Lindqvist", "Murphy", "Nolan", "Olsen", "Pelletier", "Reid", "Savard", "Tkachuk",
	"Volkov", "Wheeler", "Brodeur", "Carlson", "Dubois", "Horvat", "Kane", "Leclerc", "Morrow", "Parise",
	"Ruutu", "Staal", "Toews", "Barkov", "Hall", "Kessel", "Ladd", "Moss", "Neal", "Orr",
]

## Clubs per tier: beer league teams sponsored by bars, pros named for cities.
const CLUBS := [
	[["Moose Knuckles", "a0522d", "f2d16b"], ["Puck Bunnies", "e85d9e", "f6f6f6"], ["Ice Holes", "2e3a59", "9bd0ff"],
		["Zamboni Drivers", "3c8d4e", "f2f2e9"], ["Hat Trick Tavern", "6b2c91", "f0c33c"], ["Frozen Assets", "1f7a8c", "e8e8e8"],
		["Lumberjacks", "b22222", "1b1b1b"], ["Wobbly Pops", "d98a1c", "2b2b2b"]],
	[["Biscuit Bandits", "c8191e", "ece7dc"], ["Cold Ones", "1f4f9a", "d6a321"], ["Five Hole Fiends", "222222", "ff8c00"],
		["Sin Bin Brewers", "7a3e1d", "f0e0c0"], ["Blue Line Bombers", "174a7c", "ffffff"], ["Garage Leaguers", "4d4d4d", "ffd23f"],
		["Night Owls", "302a4f", "c7b8ff"], ["Slapshot Saloon", "8b0000", "f5deb3"]],
	[["Mudcats", "5b4636", "e6c07b"], ["Rink Rats", "666e7a", "e8452c"], ["Ironmen", "3a3a3a", "c0c0c0"],
		["Thunder", "1b3a6b", "f5c400"], ["Huskies", "2f4f6f", "ffffff"], ["Grizzlies", "5a3412", "e2b46a"],
		["Riverhawks", "0f5257", "f2a541"], ["Wolverines", "143d29", "f0c33c"], ["Copperheads", "a6542b", "1b1b1b"]],
	[["Lakers", "2a5b84", "c9d6df"], ["Coal Kings", "2b2b2b", "e0a526"], ["Frontiersmen", "0c2340", "c8102e"],
		["Bulldogs", "8a1538", "f2f2f2"], ["Ravens", "4b2e83", "e5c75e"], ["Lynx", "0e6b6b", "f2f2f2"],
		["Foundry", "8c3b1a", "1b1b1b"], ["Comets", "ff6f00", "1b1b1b"], ["Harbormasters", "002855", "9ea2a2"]],
	[["Sturgeon", "00205b", "a2aaad"], ["Stingrays", "00718f", "f3c300"], ["Timberwolves", "1a3c34", "c4a35a"],
		["Rail Barons", "0b3d91", "e04e39"], ["Ice Dogs", "1c1c1c", "e31837"], ["Mallards", "1d4f2b", "f2c75c"],
		["Smelters", "8b0000", "a5acaf"], ["Blizzard", "6caddf", "ffffff"], ["Outlaws", "3d2817", "d4a017"]],
	[["Northmen", "0038a8", "c8102e"], ["Firebirds", "f74902", "1b1b1b"], ["Kodiaks", "4f2c1d", "f4a900"],
		["Breakers", "003e7e", "ff6a13"], ["Voyageurs", "00205b", "ffffff"], ["Cardinals", "c8102e", "1b1b1b"],
		["Riptide", "006d75", "ea7200"], ["Elk", "041e42", "8b9196"], ["Furnace", "ce1126", "f2c75c"]],
]


static func first(rng: RandomNumberGenerator) -> String:
	return FIRST[rng.randi() % FIRST.size()]


static func last(rng: RandomNumberGenerator) -> String:
	return LAST[rng.randi() % LAST.size()]


static func clubs(tier: int) -> Array:
	return CLUBS[clampi(tier, 0, CLUBS.size() - 1)]
