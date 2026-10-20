"""Renders the RinkGM logo PNGs in art/logos from data/world. Run: python3 art/tools/logos/make_lore_logos.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import pixlogo as P

OUT = os.path.join(P.ROOT, "art/logos")
os.makedirs(OUT, exist_ok=True)
c = json.load(open(os.path.join(P.ROOT, "data/world/lore.json")))


def lum(h):
    r, g, b, _ = P.hexc(h)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def order(cols):
    bg = cols[0]
    rest = sorted(cols[1:], key=lambda x: -abs(lum(x) - lum(bg)))
    return [bg] + rest


TEAM_MOTIF = {"kgm": "crown", "bri": "anvil", "scc": "paddle", "ngf": "tree", "mbg": "gull",
              "fhs": "cloud", "gcs": "pick", "rsr": "rocket", "sun": "scorpion", "ost": "loon", "sil": "ghost"}
TEAM_SHAPE = {"kgm": "shield", "bri": "roundrect", "scc": "circle", "ngf": "shield", "mbg": "circle",
              "fhs": "roundrect", "gcs": "shield", "rsr": "circle", "sun": "roundrect", "ost": "circle", "sil": "shield"}
BRANDS = {
    "kodiak": ("bear", "banner", "Kodiak", "est. 1898"),
    "cmc": ("mitten", "roundrect", "CMC", "Canadian Mitten Co"),
    "warlock": ("star", "roundrect", "Warlock", "hockey"),
    "honest": ("plain", "banner", "Honest Hockey Co", "it's fine"),
    "shorewood": ("sticks", "roundrect", "Shorewood", "wooden sticks"),
    "grafton": ("blade", "banner", "Grafton", "blades"),
    "ironside": ("tower", "roundrect", "Ironside", "goalie co"),
    "gripley": ("tape", "roundrect", "Gripley's", "tape and wax"),
    "zambelli": ("zamb", "roundrect", "Zambelli", "model 525"),
    "flatley": ("zamb", "banner", "Flatley", "ice machines"),
    "polarix": ("hexagon", "roundrect", "Polarix", "ice systems"),
    "double_double": ("donut", "roundrect", "Double-Double", "donuts"),
    "moosebrew": ("moose", "banner", "Moosebrew", "lager"),
    "brokenbone": ("bone", "roundrect", "Brokenbone", "mutual insurance"),
    "big_gords": ("truck", "banner", "Big Gord's", "trucks"),
    "maple_tire": ("leaf", "roundrect", "Maple Tire", "and muffler"),
    "rink_rage": ("bolt", "roundrect", "Rink Rage", "energy drink"),
    "frostbank": ("flake", "roundrect", "Frostbank", "since 1921"),
    "puckhead": ("pizza", "roundrect", "Puckhead", "pizza"),
    "northwind": ("gull", "banner", "Northwind", "air"),
    "grizzly_gas": ("paw", "roundrect", "Grizzly", "gas and go"),
    "telenorth": ("arcs", "roundrect", "TeleNorth", "phone and net"),
    "hearthstone": ("house", "roundrect", "Hearthstone", "furnaces"),
}

league = [("GNHL", P.badge({"motif": "sticks", "short": "GNHL", "shape": "shield", "colors": ["0B2545", "F4F1E8", "D9A62E"]}, 6)),
          ("Puckworth Cup", P.badge({"motif": "cup", "short": "CUP", "shape": "circle", "colors": ["2B2D33", "D6D9DC", "D9A62E"]}, 6))]
teams = []
for t in c["teams"]:
    cols = order([x.lstrip("#") for x in t["colors"]])
    teams.append((f'{t["city"]} {t["name"]}', P.badge({"motif": TEAM_MOTIF.get(t["id"], "star"), "short": t["short"], "shape": TEAM_SHAPE.get(t["id"], "circle"), "colors": cols}, 6)))
marks = {}
for group in ("brands", "resurfacers", "sponsors"):
    marks[group] = []
    for b in c[group]:
        motif, shape, name, sub = BRANDS[b["id"]]
        cols = order([x.lstrip("#") for x in b["colors"]])
        im = P.wordmark({"motif": motif, "text": name, "sub": sub, "shape": shape, "colors": cols, "stripe": shape == "banner"}, 6)
        im.save(f"{OUT}/{b['id']}.png")
        marks[group].append((b["name"], im))
for name, im in league + teams:
    im.save(f"{OUT}/{name.lower().replace(' ', '_')}.png")
P.sheet(league + teams, 5, label="GNHL AND ITS CLUBS").save(f"{OUT}/sheet-gnhl.png")
P.sheet(marks["brands"] + marks["resurfacers"], 3, label="GEAR AND RESURFACER BRANDS").save(f"{OUT}/sheet-brands.png")
P.sheet(marks["sponsors"], 3, label="SPONSORS").save(f"{OUT}/sheet-sponsors.png")
print("ok")
