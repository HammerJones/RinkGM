# People: everyone in the rink is somebody

Sean, 2026-10-18: "I want everyone in the game to be a real character with
personality and dialogue options. Every person in the rink should be a real
NPC that moves and interacts with the world. Including everyone in the
stands. Part of the personality should be what events they're interested in
watching/participating in."

This doc is the system and the data contract. The people themselves live in
`docs/world/CAST.md` (who they are) and `data/world/` (what the game reads).

## 1. The rules

1. **Nobody is a prop.** Every body in the building, from the Zambelli driver
   to the grandmother in row J, is a `Person` with a name, a home, a
   personality, things they care about and something to say.
2. **Two kinds of people, one shape.** The *cast* (about 60 named characters,
   hand written in `data/world/cast.json`) and the *townsfolk* (a few hundred
   per town, generated from a seed so the same people come back every week,
   `scripts/world/people/townsfolk.gd`). Both are the same `Person` record, so
   any townsperson can be promoted to a quest giver.
3. **People come for what they like.** Attendance is not a fill percentage.
   Each person has an interest in watching and in taking part in every kind
   of event, and comes when the event is on, they're free, the ice is good
   enough for them and the rink hasn't burned them lately.
4. **People do things.** In the building they walk through real doors, queue
   at the canteen, lean on the glass, go to the washroom, buy laces at Bev's,
   get cold, get bored, cheer, complain and leave. Seated fans are the same
   agents, sitting down.
5. **People remember.** Satisfaction per person feeds the rink's reputation
   and the contracts in `RinkSim`. Treat customers badly and *specific
   people* stop coming, and say why. This is the "chaos you earned" from
   `PATHS.md`: a calm rink by default.

## 2. Event kinds

Every booking and special event has an `event` kind. `RinkContracts.ORGS`
carries it; special events in `data/world/events.json` do too.

| Kind | What it is | Who plays | Who watches |
| --- | --- | --- | --- |
| `beer_league` | Valley Beer League games, late nights | adults 25-60 | partners, friends, a few diehards |
| `minor_hockey` | Millbrook Minor Hockey practices and games | kids 5-17 | parents, grandparents, siblings |
| `high_school` | Millbrook High Mallards | teens | classmates, parents, the band |
| `senior_hockey` | Lumber Kings, Senior AAA | adults | the town; the big crowd |
| `pro_practice` | Duncannon Dukes practice ice | pros | rink rats, autograph hunters |
| `tournament` | weekend tournaments | kids | families from five towns |
| `figure_practice` | Figure club morning ice | skaters 6-20, coaches | parents with coffee |
| `figure_show` | competitions, test days, the spring ice show | skaters | families, the arts crowd |
| `public_skate` | open skate, all ages | anyone | parents on the bench, dates |
| `learn_to_skate` | kids' and adults' lessons | beginners | nervous parents |
| `stick_and_puck` | open shinny with sticks | anyone with gear | nobody, mostly |
| `broomball` | Harlow Falls Broomball Club | adults in sneakers | friends |
| `special` | Christmas skate, Doris Day, carnival, memorial game | varies | varies |

Each kind also says what the event needs from the ice (`use` in
`RinkContracts`: hockey, figure, public) and how big a crowd it can draw.

## 3. Person record

The same keys for cast and townsfolk. Townsfolk fill fewer of them.

```json
{
  "id": "bev_kowalchuk",
  "name": "Beverly Kowalchuk",
  "known_as": "Bev",
  "age": 58,
  "pronouns": "she/her",
  "town": "millbrook",
  "home": "Above the pro shop",
  "job": "Owner, Bev's Edge & Tape",
  "role": "staff",
  "archetype": "shopkeeper",
  "look": {"build": "stocky", "height": 0.96, "skin": 2, "hair": "grey_bun", "hair_color": "8a8a8a",
           "outfit": "shop_apron", "colors": ["2f5e8a", "d9d4c7"], "accessory": "reading_glasses"},
  "traits": {"warmth": 0.6, "chatter": 0.4, "patience": 0.3, "pride": 0.8, "nerve": 0.7, "humour": 0.9},
  "likes": ["sharp edges", "people who say thank you", "the 1981 Kings"],
  "dislikes": ["composite sticks", "being rushed"],
  "voice": "Dry, short sentences, calls everyone 'champ'. Never raises her voice.",
  "interests": {"beer_league": {"watch": 0.2, "play": 0.0}, "figure_show": {"watch": 0.7, "play": 0.0}},
  "schedule": [{"days": [1, 2, 3, 4, 5, 6], "from": 9.0, "to": 18.0, "place": "pro_shop", "doing": "work"}],
  "rel": {"earl_bratt": 40, "old_pete_vachon": 85},
  "dialogue": "bev_kowalchuk",
  "quests": ["bev_whetstone"],
  "bio": "Two or three sentences."
}
```

| Key | Meaning |
| --- | --- |
| `role` | `staff` (works at the rink), `regular` (comes most weeks), `customer`, `visitor` (rare), `family` |
| `archetype` | one of the archetypes in section 5; cast members use one too, for their barks and their needs |
| `look` | what the voxel body wears (`scripts/art/people.gd`); `height` scales an adult body, kids use `age` |
| `traits` | 0..1 each. `warmth`: friendly. `chatter`: talks. `patience`: queues, waits for wet ice. `pride`: takes slights hard. `nerve`: calm under chaos. `humour`: jokes |
| `interests` | per event kind, `watch` and `play` 0..1. Missing kinds are 0 |
| `schedule` | where they are when they are not at an event. Hours of the day, weekdays 0 = Sunday. `place` is a venue place (section 7) or `away` |
| `rel` | how they feel about other people, -100..100. `owner` is the player |
| `dialogue` | id of a tree in `data/world/dialogue/<id>.json` |
| `job` | one line: "Nurse, Valley Regional Hospital", "In school", "Retired" |
| `work` | the job's hours: `{title, employer, days, from, to, flex, boss, id}`. `flex` 0..1 is how easily they swap a shift. Named people without it get one from their schedule's `work` block |
| `commute` | how they get to the rink: `car`, `foot`, `ride` (a parent drives) |
| `kin` | `{person id: relation}`: `partner`, `child`, `parent`, `sibling`, `grandparent`, `grandchild` |
| `friends` | person ids they come to watch or sit with |
| `backstory` | a few sentences; named people use `bio`, townsfolk get a generated one |

Townsfolk jobs come from `data/world/jobs.json` (templates by archetype
and town, with hour options, a boss and a commute); the job's hours
replace the archetype's stand-in work block, so rink time fits around
work. Backstories are built from `data/world/backstory.json` (who they
are, their work, their family, what the rink is to them), warm and a
little wry; lines whose tokens can't be filled are skipped.

## 4. Attendance

For each booked session or special event, every person in the region gets a
chance to come. Pure logic in `scripts/world/people/attendance.gd`.

```
want = interest[event][watch or play]
     * fit       (kids' events need a kid in the family; play needs the age/skill)
     * free      (their schedule says they're free; work, school, bedtime)
     * ice_draw  (rink reputation for this use, against their patience)
     * mood      (their own satisfaction with the rink, 0..1, starts 0.7)
     * pull      (the event's draw: a final pulls more than a practice)
come if rng < want
```

Families come together: a minor hockey player brings a parent, and maybe a
sibling and a grandparent. A participant who comes brings their gear and
goes to a dressing room; a spectator heads for the stands.

**Everyone has a reason.** Each entry is `{person, as, reason, arrive,
group}`; `reason` is `{why, for, for_name, group, until, negotiated,
place, doing}`. `why` is one of `player`, `parent`, `sibling`,
`grandparent`, `partner`, `child`, `grandchild`, `friend`, `date`,
`scout`, `next_student` (the figure coach's next lesson, early), `zamboni`
(a kid who came for the machine), `autograph`, `fan`, `drop_in`, `work`.
`for` is the person they came for. A group arrives together (players 15
to 40 minutes early, their family with them) and leaves when its player
leaves; parents wait in the lobby while kids change. A parent whose job
covers the event may swap a shift for one that matters (`negotiated`, a
line from `jobs.json` "negotiate"); the higher the stakes and the boss's
`flex`, the likelier. People talk about all this through `@why_here`,
`@work`, `@with` and `@about`, with lines from `data/world/dialogue/_life.json`.

## 5. Archetypes

Townsfolk are generated from archetypes. Each sets trait ranges, interests,
schedule, look and barks. The list (all in `data/world/archetypes.json`):

`hockey_parent`, `figure_parent`, `rink_rat` (kid who lives at the rink),
`beer_leaguer`, `retiree_regular`, `date_night` (couples at public skate),
`figure_skater`, `minor_player`, `teen`, `learn_to_skate_adult`,
`stick_and_puck_regular`, `broomballer`, `superfan` (Lumber Kings),
`autograph_hunter`, `coffee_coach` (the parent who coaches from the stands),
`grandparent`, `scout`, `shift_worker` (mill or plant, comes at odd hours),
`shopkeeper`, `canteen_worker`, `volunteer` (timekeepers, 50/50 sellers),
`official` (refs and linespeople), `coach`, `rink_staff`.

## 6. Dialogue

Trees in `data/world/dialogue/<id>.json`. One tree per cast member; townsfolk
share archetype trees (`data/world/dialogue/archetype_<id>.json`) filled with
their own name, interests and mood.

```json
{
  "id": "bev_kowalchuk",
  "barks": {
    "idle": ["Edges don't sharpen themselves, champ."],
    "bad_ice": ["Ice looks like a gravel pit today."],
    "goal": ["About time."]
  },
  "start": [
    {"if": [{"not_flag": "met_bev"}], "node": "first"},
    {"if": [{"quest": ["bev_whetstone", "active"]}], "node": "whetstone_check"},
    {"node": "hub"}
  ],
  "nodes": {
    "first": {
      "say": "You're the new owner. Doris hasn't killed you yet, so that's something.",
      "do": [{"set": "met_bev"}],
      "options": [
        {"text": "Nice to meet you. I'm {owner}.", "do": [{"rel": ["bev_kowalchuk", 5]}], "to": "hub"},
        {"text": "Who's Doris?", "to": "doris"}
      ]
    }
  }
}
```

`say` can be a string or a list (one picked at random). Tokens: `{owner}`,
`{rink}`, `{town}`, `{weekday}`, `{time}`, `{event}` (what's on now),
`{ice_word}` (how the ice is: "glass", "fine", "chewed up", "slush"),
`{name}` and `{known_as}` (the speaker).

**Conditions** (`if`, all must hold): `flag`, `not_flag`, `rel_gte`
`[id, n]`, `rel_lt`, `quest` `[id, "inactive"|"active"|"done"|"failed"]`,
`step` `[quest, step]`, `ice_gte` (reputation), `rooms_gte` (facility
score), `money_gte`, `day_gte`, `weekday` `[0..6]`, `hour_between`
`[from, to]`, `event_now` (kind), `contract` (org id), `path` (player,
coach or gm), `trait_gte` `[trait, x]` (the speaker's), `mood_lt` `x`,
`chance` `x`.

**Effects** (`do`, in order): `set` flag, `clear` flag, `rel` `[id, delta]`,
`mood` delta (the speaker's satisfaction with the rink), `quest_start`,
`quest_step` `[quest, step]`, `quest_done`, `quest_fail`, `money` delta (booked as "people"), `pay_dues` true
(the owner's Beer League dues through RinkSim.pay_dues),
`item` `[id, count]` (inventory), `rep` delta (ice reputation), `note`
(a line in the day log), `end` true.

An option with `if` that fails is hidden. A node with no options ends the
conversation after its line.

## 7. Places

People move between named places. The venue provides them (Rink
environment); `scripts/world/people/place_map.gd` builds a walk graph from
the venue's rooms and doors and adds named spots.

`entrance`, `lobby`, `canteen` (queue), `pro_shop`, `washroom`, `vending`, `hall`, `stands`
(seats), `glass` (standing at the boards), `bench`, `penalty_box`,
`dressing_room`, `ice`, `office`, `zamboni_bay`, `plant_room`, `skate_rental`,
`community_room`, `parking`, `away` (not in the building).

## 8. Side quests

`data/world/quests.json`. Hand-written quests from the cast, plus favour
templates any townsperson can give (`"giver": "archetype:hockey_parent"`).

```json
{
  "id": "bev_whetstone",
  "title": "The Whetstone",
  "giver": "bev_kowalchuk",
  "kind": "side",
  "summary": "Bev's grandfather's whetstone is somewhere in the plant room.",
  "start": [{"rel_gte": ["bev_kowalchuk", 20]}, {"day_gte": 7}],
  "steps": [
    {"id": "find", "text": "Look for the whetstone in the plant room.", "goal": {"type": "visit", "place": "plant_room"}},
    {"id": "return", "text": "Bring it back to Bev.", "goal": {"type": "talk", "to": "bev_kowalchuk"}}
  ],
  "reward": [{"rel": ["bev_kowalchuk", 15]}, {"item": ["free_sharpening", 5]}],
  "fail": {"after_days": 0}
}
```

**Goal types**: `talk` `{to}`, `visit` `{place}`, `event_held` `{event,
name, count, min_rating}` (`name` picks one special event), `job_done` `{job, count}` (a `RinkSim.job` id),
`rating_gte` `{use, value}` (ice rating at a session), `rep_gte` `{value}`,
`rooms_gte` `{value}`, `item` `{id, count}`, `contract` `{org}`, `flag`
`{flag}`, `attend` `{person, event}` (that person came to that event).

A quest tree can hold an `at_<person id>` node: when a step sends the owner
to talk to someone other than the giver, that person opens with it.

`kind`: `side` (a story), `favour` (a small ask, repeatable, from templates),
`chain` (several quests that unlock in order, `"after": "quest_id"`).

## 9. Life in the building

`RinkLife.attach_live(people)` puts a live `RinkPeople` on the sim: each
session of today and tomorrow is booked about 50 minutes ahead
(`Attendance.who_comes`), its phase (`before`, `on`, `after`) follows the
clock, staff come for their shifts and drop-ins (rink rats, coffee
retirees) every half hour. On the venue walk `WalkPeople` does this in
place of the seated crowd (`--no-people` keeps the old crowd; hockey
matches still use `VenueCrowd`).

In the building people fidget (sip, phone, stretch, lean), watch their
person, cheer and clap, gasp at falls, wander to the halls, the canteen,
the washrooms and the vending machines, and trade two-line small talk
over their heads (`_life.json` "small_talk"). They come and go through
the parking lot or the street, by car or on foot.

**Signals for sound** (`RinkPeople`): `barked(person, text, at)`,
`chatter(level 0..1)`, `cheered(at, strength)`, `reacted(what, at,
strength)` (`gasp`, `clap`, `zamboni`), `person_arrived(person, how)`
(`car`, `foot`), `person_left(person)`, `agent_arrived(agent)`.

**For other systems** (on-ice events, drills): `claim(agent, owner)`,
`release(agent)`, `is_claimed`, `move_to(agent, pos, speed)`, `place(agent, pos, yaw)`,
`set_pose(agent, pose)`, `on_ice(session)` (who is skating), `agent_of(person_id)`,
`present(pred)`, `nearest(pos)`, `session_phase` (session key to phase), `send_home(agent)`,
`send_group_home(group)`, `fell(person_id)`, `goal(scorer)`. A claimed
agent's brain stops deciding until it's released.

**Sharing the ice**: set `RinkPeople.ice_controller` to the system drawing
the ice (OnIceSession). While it's set, players walk to the dressing room
(or the skate rental) and hand off there, `ice_controller.take(person)`
when it has that method, and aren't drawn; spectators keep watching and
face the ice. Clearing it gives the players back. The venue walk creates
`OnIceSession.for_sim(sim, venue, {came})` when a session goes on (if the
events code is in the build) and frees it after.

**Performance**: brains think in slices (near every 0.25 s, far every
1.2 s), paths are searched in batches on worker threads, only moving or
changed agents rewrite their MultiMesh slots, far agents every third
frame, and small parts (items, heads) drop out with distance. 400 people
update in about 4 ms a frame (headless).

**Local AI lines** (optional, off by default): `WorldSettings`
(`user://world_settings.cfg`, section `people`) holds `ai_dialogue`,
`ai_endpoint` (an Ollama-compatible `/api/generate`), `ai_model`,
`ai_timeout`. F2 in the talk panel toggles it. `AiDialogue` asks for one
extra line, async with a timeout; any failure is silent and the offline
line stands. No keys, no accounts; tests set `AiDialogue.blocked`.

**Gus's handoff** (`data/world/tutorial.json`, `TutorialGuide`): on the
first morning Gus, flying to Florida that afternoon, offers to show the
owner round. Yes runs the steps (plant round, ice check, the office,
Doris, the first flood, the first public skate); no turns the tutorial
off and the choice is saved (career flags, or the settings file on a
free walk). Other systems add steps with `add_step(step, after_id)` and
report progress with `notify(kind, data)` (`job`, `screen`, `talk`,
`signal`).

## 10. Code

| File | What |
| --- | --- |
| `scripts/world/people/person.gd` | `Person`: the record, mood, memory, needs |
| `scripts/world/people/cast.gd` | `Cast`: loads cast, archetypes and townsfolk; the region's population |
| `scripts/world/people/townsfolk.gd` | `Townsfolk`: seeded generation from archetypes |
| `scripts/world/people/attendance.gd` | `Attendance`: who comes to a session |
| `scripts/world/people/story_world.gd` | `StoryWorld`: flags, items, the condition and effect vocabulary, text tokens |
| `scripts/world/people/conversation.gd` | `Conversation`: runs a tree against the StoryWorld; built-in tree for townsfolk |
| `scripts/world/people/rink_life.gd` | `RinkLife`: ties people to `RinkSim` sessions, jobs and days |
| `scripts/world/people/talk_panel.gd` | `TalkPanel`: the conversation box |
| `scripts/world/people/people_walk.gd` | walk-around playtest with people (`scenes/world/people_walk.tscn`) |
| `scripts/world/people/quest_log.gd` | `QuestLog`: quest state, goal tracking |
| `scripts/world/people/npc_brain.gd` | `NpcBrain`: needs and activities in the building (pure logic) |
| `scripts/world/people/place_map.gd` | `PlaceMap`: the walk graph from the venue |
| `scripts/world/people/rink_people.gd` | `RinkPeople`: the node that runs and draws everyone in the building |
| `scripts/world/people/walk_people.gd` | `WalkPeople`: people, talk and the tutorial on a venue walk |
| `scripts/world/people/tutorial_guide.gd` | `TutorialGuide`: Gus's first-day walkthrough |
| `scripts/world/people/ai_dialogue.gd` | `AiDialogue`: the optional local AI line |
| `scripts/world/people/world_settings.gd` | `WorldSettings`: player settings for the world (AI lines, tutorial) |
| `scripts/art/people.gd` | voxel bodies for every role and age |

Tests: `tools/tests/test_people.gd`, `tools/tests/test_npc_life.gd`.
