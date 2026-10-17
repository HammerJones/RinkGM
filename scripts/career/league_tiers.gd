class_name LeagueTiers
extends RefCounted
## The ladder the user climbs, beginner beer league to minor pro. Each tier
## sets roster strength, season length (12-16 games), playoff format and
## how much practice ice the team gets. Add tiers by appending.

const TIERS := [
	{
		"name": "Beer League D", "short": "BL-D", "desc": "Beginner beer league. Late-night ice, mismatched socks.",
		"avg": 28.0, "spread": 8.0, "teams": 7, "games": 12, "playoff_teams": 4, "series": [1, 1],
		"practices_per_week": 0, "days_between_games": 7, "tryout_cut": 0.0,
	},
	{
		"name": "Beer League C", "short": "BL-C", "desc": "Intermediate beer league. People keep score here.",
		"avg": 37.0, "spread": 7.0, "teams": 7, "games": 12, "playoff_teams": 4, "series": [1, 1],
		"practices_per_week": 1, "days_between_games": 7, "tryout_cut": 34.0,
	},
	{
		"name": "Beer League A", "short": "BL-A", "desc": "Top beer league division. Ex-college players and grudges.",
		"avg": 46.0, "spread": 7.0, "teams": 8, "games": 14, "playoff_teams": 4, "series": [1, 3],
		"practices_per_week": 1, "days_between_games": 7, "tryout_cut": 43.0,
	},
	{
		"name": "Senior AAA", "short": "SR-AAA", "desc": "Senior amateur. Real systems, real travel, real hits.",
		"avg": 56.0, "spread": 6.0, "teams": 8, "games": 14, "playoff_teams": 4, "series": [3, 3],
		"practices_per_week": 2, "days_between_games": 5, "tryout_cut": 53.0,
	},
	{
		"name": "Semi-Pro", "short": "SEMI", "desc": "Semi-pro. Paid in gas money and bus rides.",
		"avg": 65.0, "spread": 5.0, "teams": 9, "games": 16, "playoff_teams": 4, "series": [3, 5],
		"practices_per_week": 3, "days_between_games": 4, "tryout_cut": 62.0,
	},
	{
		"name": "Minor League Pro", "short": "MINOR", "desc": "Minor league pro. One phone call from the show.",
		"avg": 73.0, "spread": 5.0, "teams": 9, "games": 16, "playoff_teams": 4, "series": [5, 5],
		"practices_per_week": 4, "days_between_games": 3, "tryout_cut": 70.0,
	},
]


static func count() -> int:
	return TIERS.size()


static func get_tier(i: int) -> Dictionary:
	return TIERS[clampi(i, 0, TIERS.size() - 1)]


## Games to win a playoff series in round `r` (0 = semis).
static func series_wins(tier: int, r: int) -> int:
	var s: Array = get_tier(tier).series
	return (int(s[mini(r, s.size() - 1)]) + 1) / 2
