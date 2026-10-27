class_name MatchEvents
extends RefCounted
## The match event hub: everything that happens in a game, in one place.
## The HUD, the venue (scoreboard, goal lamp, crowd), stats and the dev menu
## subscribe here instead of reading game.gd internals. One per match, owned
## by the match node as `game.events`; nothing global holds match state.
##
## Teams are match-side indices (0 = the user's club, 1 = the opponent).
## Players are PlayerProfile or null (exhibition bodies have no profile).

signal faceoff(spot: Vector2)
signal shot(team: int, shooter: PlayerProfile, slap: bool)
signal save(team: int, goalie: PlayerProfile, frozen: bool)
signal goal(team: int, scorer: PlayerProfile, assists: Array)
signal score_changed(score_0: int, score_1: int)
signal hit(team: int, hitter: PlayerProfile, victim: PlayerProfile, impact: float, knocked_down: bool)
signal injury(team: int, player: PlayerProfile, injury: Injury)
signal whistle(reason: String)
signal period_started(period: int, label: String)
signal period_ended(period: int, label: String)
signal line_change(team: int, on_ice: Array)
signal game_over(winner: int, label: String)
