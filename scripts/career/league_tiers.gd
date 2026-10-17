class_name LeagueTiers
extends RefCounted
## The ladder the user climbs, beginner beer league to minor pro. Each tier
## sets roster strength, season length (12-16 games), playoff format and
## how much practice ice the team gets, and how organised the play is (`ai`,
## read through TierAI). Add tiers by appending.

const TIERS := [
	{
		"name": "Beer League D", "short": "BL-D", "desc": "Beginner beer league. Late-night ice, mismatched socks.",
		"avg": 28.0, "spread": 8.0, "teams": 7, "games": 12, "playoff_teams": 4, "series": [1, 1],
		"practices_per_week": 0, "days_between_games": 7, "tryout_cut": 0.0,
		"ai": {"reaction": 0.55, "decide_min": 0.45, "decide_max": 0.9, "vision": 0.15, "anticipation": 0.1, "discipline": 0.1, "aggression": 0.2, "shot_selection": 0.1, "dash_use": 0.2, "goalie_reaction": 1.6, "goalie_positioning": 0.2},
	},
	{
		"name": "Beer League C", "short": "BL-C", "desc": "Intermediate beer league. People keep score here.",
		"avg": 37.0, "spread": 7.0, "teams": 7, "games": 12, "playoff_teams": 4, "series": [1, 1],
		"practices_per_week": 1, "days_between_games": 7, "tryout_cut": 34.0,
		"ai": {"reaction": 0.45, "decide_min": 0.38, "decide_max": 0.75, "vision": 0.3, "anticipation": 0.25, "discipline": 0.25, "aggression": 0.3, "shot_selection": 0.25, "dash_use": 0.35, "goalie_reaction": 1.4, "goalie_positioning": 0.35},
	},
	{
		"name": "Beer League A", "short": "BL-A", "desc": "Top beer league division. Ex-college players and grudges.",
		"avg": 46.0, "spread": 7.0, "teams": 8, "games": 14, "playoff_teams": 4, "series": [1, 3],
		"practices_per_week": 1, "days_between_games": 7, "tryout_cut": 43.0,
		"ai": {"reaction": 0.36, "decide_min": 0.3, "decide_max": 0.6, "vision": 0.45, "anticipation": 0.4, "discipline": 0.42, "aggression": 0.45, "shot_selection": 0.4, "dash_use": 0.5, "goalie_reaction": 1.25, "goalie_positioning": 0.5},
	},
	{
		"name": "Senior AAA", "short": "SR-AAA", "desc": "Senior amateur. Real systems, real travel, real hits.",
		"avg": 56.0, "spread": 6.0, "teams": 8, "games": 14, "playoff_teams": 4, "series": [3, 3],
		"practices_per_week": 2, "days_between_games": 5, "tryout_cut": 53.0,
		"ai": {"reaction": 0.26, "decide_min": 0.22, "decide_max": 0.45, "vision": 0.62, "anticipation": 0.58, "discipline": 0.62, "aggression": 0.6, "shot_selection": 0.6, "dash_use": 0.65, "goalie_reaction": 1.1, "goalie_positioning": 0.65},
	},
	{
		"name": "Semi-Pro", "short": "SEMI", "desc": "Semi-pro. Paid in gas money and bus rides.",
		"avg": 65.0, "spread": 5.0, "teams": 9, "games": 16, "playoff_teams": 4, "series": [3, 5],
		"practices_per_week": 3, "days_between_games": 4, "tryout_cut": 62.0,
		"ai": {"reaction": 0.18, "decide_min": 0.16, "decide_max": 0.35, "vision": 0.78, "anticipation": 0.74, "discipline": 0.78, "aggression": 0.7, "shot_selection": 0.75, "dash_use": 0.75, "goalie_reaction": 1.0, "goalie_positioning": 0.78},
	},
	{
		"name": "Minor League Pro", "short": "MINOR", "desc": "Minor league pro. One phone call from the show.",
		"avg": 73.0, "spread": 5.0, "teams": 9, "games": 16, "playoff_teams": 4, "series": [5, 5],
		"practices_per_week": 4, "days_between_games": 3, "tryout_cut": 70.0,
		"ai": {"reaction": 0.12, "decide_min": 0.12, "decide_max": 0.28, "vision": 0.9, "anticipation": 0.88, "discipline": 0.9, "aggression": 0.75, "shot_selection": 0.85, "dash_use": 0.85, "goalie_reaction": 0.9, "goalie_positioning": 0.9},
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
