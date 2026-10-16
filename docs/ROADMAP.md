# RinkGM roadmap

Milestones in order. Each one ends with something Sean can play. The owning
workstream is in brackets; see `ARCHITECTURE.md` for who owns what.

## M0: Foundation (done or in review)

- [x] Playable 3-on-3 voxel demo with Sim / Hybrid / Arcade blend (PR #1)
- [ ] CI that imports the project and plays a headless game on every PR [PM]
- [ ] Demo merged to `main` so every workstream branches from it [Sean]

## M1: One skater, real controls

- [ ] `PlayerAttributes` resource and the skills-to-physics mapping [Mechanics + Physics]
- [ ] Slapshot-style controller scheme with 90° stick arc, lift, tilt, dash, stop [Controls + Physics]
- [ ] Keyboard and mouse version of the same scheme [Controls]
- [ ] Player switching removed; you play one skater and the AI plays the rest [Mechanics]
- [ ] Faster, snappier skating and puck feel, still balanced in autoplay [Physics]
- [ ] Chosen font and UI style applied to the HUD and controls card [UI]

## M2: A full game

- [ ] 5-on-5 plus goalies, 3 forward lines and 2 D pairs, line changes [Mechanics + Physics]
- [ ] 3 periods with adjustable length, intermissions, end-of-game summary [Mechanics + UI]
- [ ] Stick lifts, hits, puck-loss on hard turns, stick-handling speed from skills [Physics]
- [ ] Match event hub feeding stats and the HUD [Mechanics + UI]
- [ ] AI that plays positions and changes lines [Physics + Mechanics]

## M3: A season

- [ ] Beer-league team, 12-16 game schedule, standings, playoffs [Mechanics + UI]
- [ ] Skill growth and decay from games and practice [Mechanics]
- [ ] Injuries tied to hits and toughness, with time out [Mechanics + Physics]
- [ ] Save and load a career [Mechanics]

## M4: Climbing the ladder

- [ ] Tryout invites and higher tiers up to semi-pro/minor league [Mechanics + UI]
- [ ] Opponent and teammate quality scale by tier [Mechanics + Physics]

## Later: Rink sim and open world

- Load the match from a world scene instead of as the main scene.
- Rink management (ice time, staff, upkeep), multiple venues, walking around the rink.
