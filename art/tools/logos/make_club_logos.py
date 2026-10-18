"""Renders the RinkGM logo PNGs in art/logos from data/world. Run: python3 art/tools/logos/make_club_logos.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import pixlogo as P
from make_lore_logos import order
OUT = os.path.join(P.ROOT, "art/logos/clubs")
os.makedirs(OUT, exist_ok=True)
t = json.load(open(os.path.join(P.ROOT, "data/world/teams.json")))
M = {"wobbly_pops": "mug", "molars": "tooth", "moose_knuckles": "moose", "ice_holes": "flake", "pallbearers": "ghost",
     "flood_crew": "wave", "frozen_assets": "hexagon", "sin_bin_brewers": "mug", "big_gords": "truck", "plungers": "plunger",
     "millbrook_mallards": "loon", "cold_ones": "mug", "adjusters": "bone", "night_owls": "donut", "retreads": "tire",
     "slapshot_saloon": "mug", "hydro_linemen": "bolt", "rink_rage_bombers": "flame", "splinter_group": "sticks",
     "backcrackers": "bone", "smoke_eaters": "flame", "walleyes": "fish", "rusty_blades": "blade",
     "kessler_millmen": "gear", "millbrook_lumber_kings": "crown", "harlow_falls_huskies": "paw", "port_ainsley_lakers": "wave",
     "duncannon_foundry": "anvil", "tollbridge_coal_kings": "pick", "sainte_odile_castors": "tree", "carvers_gap_ravens": "gull",
     "port_ainsley_sturgeon": "fish", "carrick_rail_barons": "crown", "ellery_smelters": "anvil", "cold_harbour_stingrays": "wave",
     "wexford_ice_dogs": "paw", "wendover_scholars": "star", "fort_kinnear_timberwolves": "tree", "snowden_blizzard": "flake",
     "galloway_outlaws": "star", "duncannon_dukes": "crown", "halverton_northmen": "sticks", "ravensport_breakers": "wave",
     "marchmont_voyageurs": "paddle", "tamarack_kodiaks": "bear", "ashcombe_elk": "moose", "fenwick_firebirds": "flame",
     "st_brendan_friars": "cross", "belle_rive_riptide": "wave", "puckheads": "pizza", "overdues": "house"}
SHAPES = ["roundrect", "circle", "circle", "shield", "shield", "circle"]
sheets = {}
for c in t["clubs"]:
    key = c["id"].split("_", 1)[1]
    cols = order([x.lstrip("#") for x in c["colors"]] + (["1b1b1b"] if len(c["colors"]) < 3 else []))
    im = P.badge({"motif": M.get(key, "star"), "short": c["short"], "shape": SHAPES[c["tier"]], "colors": cols}, 5)
    im.save(f"{OUT}/{c['id']}.png")
    sheets.setdefault(c["tier"], []).append((c["name"] + (" (exp.)" if c.get("expansion") else ""), im))
names = [l["name"].upper() for l in t["leagues"]]
for tier, ims in sorted(sheets.items()):
    P.sheet(ims, 5, label=names[tier]).save(os.path.join(P.ROOT, f"art/logos/sheet-tier{tier}.png"))
print("ok", len(t["clubs"]))
