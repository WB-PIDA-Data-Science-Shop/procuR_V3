#!/usr/bin/env python3
# ============================================================================
# generate_demo_data.py — synthetic procurement dataset for the
# Unified Procurement Analysis App (fully fictional, publication-safe)
# ============================================================================
# Produces demo_procurement_data.csv: ~10,800 award records (2015–2024) for
# the fictional country "Demoland" (country code DL, currency DLK,
# 1 USD = 1.80 DLK), matching the 67-column OpenTender-style schema of real
# inputs. All entities, names, places and URLs are invented.
#
# The data contains DELIBERATELY PLANTED patterns so that every feature of
# the analysis tool has something to find (see DEMO_GUIDE.md):
#   P1  Single bidding: elevated & rising in medical (CPV 33), extreme in
#       fuels (09) and non-competitive procedures.
#   P2  Concentration: three "captured" buyers spend ~90% with one favored
#       supplier, every year, across many contracts.
#   P3  Bunching: excess contract mass just below the works threshold
#       (270,000 DLK) and the supplies/services threshold (70,000 DLK),
#       mostly under non-open procedures.
#   P4  Short deadlines: ten "shortcut" regional buyers use 7–15 day
#       submission windows; their tenders get far more single bids
#       (drives the admin short-submission regression).
#   P5  Long decisions: utilities decide slowly (60–260 days) with a mild
#       single-bidding penalty (drives the long-decision regression).
#   P6  Opaque buyers: fifteen buyers with heavy, co-occurring missingness
#       (location fields together; estimated prices), more single bidding
#       and ~12% higher relative prices (drives both integrity regressions).
#   P7  Market entry: construction (45) closes over time (new-supplier share
#       35%→6%); IT services (72) stays open; fuels (09) is a 5-supplier
#       static market.
#   P8  Unusual entries: established suppliers from IT (72), business
#       services (79) and repair (50) win occasional marginal awards in
#       construction (45) and medical (33) — visible flow-matrix routes.
#   P9  Relative prices: centred at 0.93 with a planted spike at exactly
#       1.00 (estimates copied from prices) and overruns concentrated in
#       medical and opaque buyers.
#
# Reproducible: python3 generate_demo_data.py   (fixed seed 42)
# ============================================================================
import csv, io, math, random, uuid, datetime as dt
from collections import defaultdict

random.seed(42)
RATE = 1.80                     # DLK per USD (constant; the app detects it)
YEARS = list(range(2015, 2025))
ROWS_PER_YEAR = {y: 1100 + int((y - 2015) * 80) for y in YEARS}  # 1100→1820

# ── markets ─────────────────────────────────────────────────────────────
# div: (cpv8 list, supply type, share weight, log-mean DLK, log-sd, titles)
MARKETS = {
 "33": (["33600000","33140000","33100000","33690000","33190000"], "SUPPLIES", 0.124, 10.1, 1.0,
        ["Supply of pharmaceutical products — {}",
         "Supply of medical consumables — {}",
         "Delivery of medical equipment for {}"]),
 "45": (["45000000","45233120","45210000","45310000","45232400"], "WORKS", 0.102, 12.0, 1.1,
        ["Road rehabilitation works — section {}",
         "Construction of public building, {}",
         "Renovation works — {} facility"]),
 "09": (["09310000","09134200","09120000"], "SUPPLIES", 0.036, 11.3, 0.8,
        ["Supply of electricity for {}", "Supply of diesel fuel — {}",
         "Supply of natural gas — {}"]),
 "30": (["30213000","30232110","30197644"], "SUPPLIES", 0.058, 9.2, 0.9,
        ["Supply of computers and peripherals for {}",
         "Delivery of office equipment — {}"]),
 "34": (["34110000","34144000","34928400"], "SUPPLIES", 0.044, 11.0, 1.0,
        ["Purchase of vehicles for {}", "Delivery of special-purpose vehicles — {}"]),
 "50": (["50400000","50000000","50110000"], "SERVICES", 0.058, 9.4, 0.9,
        ["Maintenance of medical equipment — {}", "Repair services for {} fleet"]),
 "71": (["71320000","71240000","71520000"], "SERVICES", 0.044, 10.2, 1.0,
        ["Design services for {} project", "Construction supervision — {}"]),
 "72": (["72000000","72260000","72410000"], "SERVICES", 0.066, 10.0, 1.0,
        ["IT system development for {}", "Software maintenance services — {}"]),
 "79": (["79713000","79952000","79340000"], "SERVICES", 0.058, 9.1, 0.9,
        ["Security services for {}", "Organisation of events — {}"]),
 "90": (["90511000","90610000","90910000"], "SERVICES", 0.058, 9.8, 0.9,
        ["Waste collection services — {}", "Street cleaning — {} municipality"]),
 "15": (["15800000","15511000","15810000"], "SUPPLIES", 0.044, 9.0, 0.8,
        ["Supply of food products for {}", "Delivery of bread and dairy — {}"]),
 "60": (["60100000","60130000"], "SERVICES", 0.036, 9.6, 0.9,
        ["Passenger transport services — {}", "Specialised school transport — {}"]),
 "03": (['03000000', '03100000', '03200000', '03300000'], "SUPPLIES", 0.018, 9.0, 0.9,
        ["Supply of agricultural products — {}", "Delivery of agricultural products for {}"]),   # real CPV division: agricultural products
 "18": (['18000000', '18100000', '18200000', '18300000'], "SUPPLIES", 0.015, 8.8, 0.8,
        ["Supply of uniforms and workwear — {}", "Delivery of uniforms and workwear for {}"]),   # real CPV division: uniforms and workwear
 "22": (['22000000', '22100000', '22200000', '22300000'], "SUPPLIES", 0.015, 8.6, 0.8,
        ["Supply of printed materials — {}", "Delivery of printed materials for {}"]),   # real CPV division: printed materials
 "24": (['24000000', '24100000', '24200000', '24300000'], "SUPPLIES", 0.016, 9.2, 0.9,
        ["Supply of chemical products — {}", "Delivery of chemical products for {}"]),   # real CPV division: chemical products
 "31": (['31000000', '31100000', '31200000', '31300000'], "SUPPLIES", 0.02, 9.3, 0.9,
        ["Supply of electrical equipment — {}", "Delivery of electrical equipment for {}"]),   # real CPV division: electrical equipment
 "32": (['32000000', '32200000', '32300000', '32400000'], "SUPPLIES", 0.016, 9.5, 0.9,
        ["Supply of communication equipment — {}", "Delivery of communication equipment for {}"]),   # real CPV division: communication equipment
 "35": (['35000000', '35100000', '35200000', '35300000'], "SUPPLIES", 0.015, 9.4, 0.9,
        ["Supply of security equipment — {}", "Delivery of security equipment for {}"]),   # real CPV division: security equipment
 "38": (['38000000', '38100000', '38200000', '38300000'], "SUPPLIES", 0.018, 9.6, 0.9,
        ["Supply of laboratory equipment — {}", "Delivery of laboratory equipment for {}"]),   # real CPV division: laboratory equipment
 "39": (['39000000', '39100000', '39200000', '39300000'], "SUPPLIES", 0.022, 9.0, 0.9,
        ["Supply of furniture and furnishings — {}", "Delivery of furniture and furnishings for {}"]),   # real CPV division: furniture and furnishings
 "44": (['44000000', '44100000', '44200000', '44300000'], "SUPPLIES", 0.022, 9.8, 1.0,
        ["Supply of construction materials — {}", "Delivery of construction materials for {}"]),   # real CPV division: construction materials
 "48": (['48000000', '48100000', '48200000', '48300000'], "SUPPLIES", 0.022, 9.8, 0.9,
        ["Supply of software packages — {}", "Delivery of software packages for {}"]),   # real CPV division: software packages
 "55": (['55000000', '55100000', '55200000', '55300000'], "SERVICES", 0.016, 9.0, 0.8,
        ["Provision of catering services — {}", "Catering services for {}"]),   # real CPV division: catering services
 "80": (['80000000', '80100000', '80200000', '80300000'], "SERVICES", 0.016, 9.2, 0.9,
        ["Provision of training services — {}", "Training services for {}"]),   # real CPV division: training services
 "85": (['85000000', '85100000', '85200000', '85300000'], "SERVICES", 0.022, 10.0, 0.9,
        ["Provision of health and social services — {}", "Health and social services for {}"]),   # real CPV division: health and social services
}
DIVS   = list(MARKETS)
WEIGHT = [MARKETS[d][2] for d in DIVS]

# ── geography (fictional) ───────────────────────────────────────────────
CITIES = ["Astervale","Nordhaven","Quellin","Bramwick","Southmere","Kestrel",
          "Ivorra","Duskfield","Lornbay","Marrowgate","Veyle","Thornbury",
          "Ellsworth","Greyholm","Ravenscar","Wexbridge","Ophira","Caldermoor",
          "Fenwick","Silverash"]
NUTS  = {c: f"DL{random.randint(1,4)}{random.randint(1,4)}" for c in CITIES}
PCODE = {c: f"{random.randint(10,99)}{random.randint(10,99)}" for c in CITIES}

# ── buyers ──────────────────────────────────────────────────────────────
BTYPES = (["NATIONAL_AUTHORITY"]*15 + ["REGIONAL_AUTHORITY"]*45 +
          ["PUBLIC_BODY"]*30 + ["UTILITIES"]*12 + ["OTHER"]*18)
random.shuffle(BTYPES)
MINISTRIES = ["Health","Transport","Regional Development","Education","Interior",
              "Environment","Agriculture","Energy","Culture","Justice",
              "Finance","Labour","Digital Affairs","Defence","Tourism"]
def buyer_name(i, btype, city):
    if btype == "NATIONAL_AUTHORITY":
        return f"MINISTRY OF {MINISTRIES[i % len(MINISTRIES)].upper()} OF DEMOLAND"
    if btype == "REGIONAL_AUTHORITY":
        return f"MUNICIPALITY OF {city.upper()}"
    if btype == "UTILITIES":
        kind = ["WATER AND SEWERAGE","DISTRICT HEATING","ELECTRICITY DISTRIBUTION","PUBLIC TRANSPORT"][i % 4]
        return f"{city.upper()} {kind} COMPANY"
    if btype == "PUBLIC_BODY":
        kind = ["REGIONAL HOSPITAL","UNIVERSITY","SOCIAL SERVICES AGENCY","ROAD INFRASTRUCTURE AGENCY","REGIONAL HEALTH DIRECTORATE"][i % 5]
        return f"{kind} {city.upper()}"
    return f"{city.upper()} DEVELOPMENT FUND"

BUYERS = []
for i, bt in enumerate(BTYPES):
    city = random.choice(CITIES)
    BUYERS.append(dict(
        mid=f"DL_b{i+1:04d}", bid=f"{random.randint(10**8, 10**9-1)}",
        name=buyer_name(i, bt, city), btype=bt, city=city,
        markets=random.sample(DIVS, k=random.randint(3, 6))))
for b in BUYERS:
    if b["btype"] == "UTILITIES" and "09" not in b["markets"]:
        b["markets"].append("09")

CAPTURED  = [b for b in BUYERS if b["btype"] == "REGIONAL_AUTHORITY"][:3]        # P2
SHORTCUT  = [b for b in BUYERS if b["btype"] == "REGIONAL_AUTHORITY"][5:15]      # P4
OPAQUE    = ([b for b in BUYERS if b["btype"] == "PUBLIC_BODY"][:9] +
             [b for b in BUYERS if b["btype"] == "OTHER"][:6])                   # P6
for b in CAPTURED: b["markets"] = ["45","33","50"]

# ── suppliers ───────────────────────────────────────────────────────────
FLAVOR = {"33":"Medica","45":"Construct","09":"Energo","30":"Tech","34":"Motors",
          "50":"Service","71":"Consult","72":"Soft","79":"Partners","90":"Eco",
          "15":"Foods","60":"Trans",
          "03":"Agro",
          "18":"Textile",
          "22":"Print",
          "24":"Chem",
          "31":"Electro",
          "32":"Telecom",
          "35":"Guard",
          "38":"Lab",
          "39":"Furnish",
          "44":"Materials",
          "48":"Systems",
          "55":"Catering",
          "80":"Academy",
          "85":"Care"}
SFX = ["Ltd","JSC","Group","Plus","Pro","International","& Co"]
FIRST = ["Nova","Alfa","Delta","Vertex","Prime","Blue Ridge","Summit","Atlas",
         "Meridian","Cobalt","Aurora","Pinnacle","Silverline","Northstar","Orion",
         "Cedar","Falcon","Granite","Helix","Ember","Juniper","Krona","Lumen",
         "Mistral","Nimbus","Onyx","Pioneer","Quantum","Rowan","Sable"]
def pick_alt(div, code):
    """A secondary code in a DIFFERENT 3-digit cluster of the same division
    (or None). Used for ~8% of a supplier's awards: creates the sparse
    organic cross-cluster activity real networks have."""
    others = [c for c in MARKETS[div][0] if c[:3] != code[:3]]
    return random.choice(others) if others else None

SUPPLIERS, used = [], set()
sid = 0
for div in DIVS:
    n = {"45": 85, "33": 75, "09": 5, "72": 70,
         "03": 30, "18": 30, "22": 30, "24": 30, "31": 30, "32": 30, "35": 30, "38": 30, "39": 30, "44": 30, "48": 30, "55": 30, "80": 30, "85": 30}.get(div, 45)
    for _ in range(n):
        sid += 1
        while True:
            nm = f"{random.choice(FIRST)} {FLAVOR[div]} {random.choice(SFX)}"
            if nm not in used:
                used.add(nm); break
        city = random.choice(CITIES)
        s = dict(mid=f"DL_s{sid:04d}", sid2=f"{random.randint(10**8,10**9-1)}",
                 name=nm.upper(), home=div, city=city,
                 code=random.choice(MARKETS[div][0]))
        s["alt"] = pick_alt(div, s["code"])
        SUPPLIERS.append(s)
BY_HOME = defaultdict(list)
for s in SUPPLIERS: BY_HOME[s["home"]].append(s)
for b in CAPTURED:                                                            # P2
    b["favored"] = random.choice(BY_HOME[b["markets"][0]])

# P7: per-market yearly active pools with controlled entry
ENTRY = {d: {y: 0.22 for y in YEARS} for d in DIVS}
for i, y in enumerate(YEARS):
    ENTRY["45"][y] = max(0.06, 0.35 - 0.033 * i)      # closing
    ENTRY["72"][y] = 0.35                              # open
    ENTRY["09"][y] = 0.0 if y > 2016 else 0.2          # static oligopoly
def new_supplier(div):
    global sid
    sid += 1
    while True:
        nm = f"{random.choice(FIRST)} {FLAVOR[div]} {random.choice(SFX)} {random.randint(2,99)}"
        if nm not in used:
            used.add(nm); break
    s = dict(mid=f"DL_s{sid:04d}", sid2=f"{random.randint(10**8,10**9-1)}",
             name=nm.upper(), home=div, city=random.choice(CITIES),
             code=random.choice(MARKETS[div][0]))
    s["alt"] = pick_alt(div, s["code"])
    SUPPLIERS.append(s); BY_HOME[div].append(s)
    return s

pool, reserve = {}, {}
for d in DIVS:
    ss = BY_HOME[d][:]; random.shuffle(ss)
    k0 = max(3, int(len(ss) * 0.45))
    pool[d], reserve[d] = ss[:k0], ss[k0:]
ACTIVE = {}                                            # (div, year) -> list
for y in YEARS:
    for d in DIVS:
        newcomers = []
        want_new = int(round(len(pool[d]) * ENTRY[d][y]))
        for _ in range(want_new):
            # draw from the reserve while it lasts, then create fresh
            # suppliers — open markets must never close just because the
            # initial pool ran out
            newcomers.append(reserve[d].pop() if reserve[d] else new_supplier(d))
        if y > YEARS[0] and random.random() < 0.35 and len(pool[d]) > 4:
            pool[d].pop(random.randrange(len(pool[d])))          # churn out
        pool[d].extend(newcomers)
        ACTIVE[(d, y)] = pool[d][:]

# P8: unusual entrants (home -> target routes)
# (home div, shared home specialty, target div, fixed target code, k suppliers)
ROUTES = [("72","72000000","45","45233120",5),
          ("79","79713000","45","45233120",4),
          ("50","50400000","33","33140000",4),
          ("30","30213000","33","33600000",5),   # IT equipment → pharma
          ("90","90511000","45","45310000",4),   # waste services → electrical works
          ("71","71320000","72","72260000",4)]   # design → software services
UNUSUAL = []                                  # (supplier, target, target code, year)
for home, hcode, tgt, tcode, k in ROUTES:
    for s in random.sample(BY_HOME[home], k):
        s["code"] = hcode        # pin: route suppliers share one home cluster
        s["alt"]  = pick_alt(home, hcode)
        for _ in range(random.randint(1, 3)):
            UNUSUAL.append((s, tgt, tcode, random.choice(range(2019, 2024))))

# ── helpers ─────────────────────────────────────────────────────────────
PROCS  = ["OPEN","RESTRICTED","NEGOTIATED_WITH_PUBLICATION",
          "NEGOTIATED_WITHOUT_PUBLICATION","OUTRIGHT_AWARD","COMPETITIVE_DIALOG"]
PWEIGHT= [.52, .12, .10, .14, .10, .02]
NATIONAL = {"OPEN":"OPEN NATIONAL COMPETITION","RESTRICTED":"RESTRICTED NATIONAL COMPETITION",
            "NEGOTIATED_WITH_PUBLICATION":"NEGOTIATION WITH NOTICE",
            "NEGOTIATED_WITHOUT_PUBLICATION":"NEGOTIATION WITHOUT NOTICE",
            "OUTRIGHT_AWARD":"DIRECT CONTRACTING","COMPETITIVE_DIALOG":"COMPETITIVE DIALOGUE"}
THRESH = {"WORKS": 270_000.0, "SUPPLIES": 70_000.0, "SERVICES": 70_000.0}    # P3

def rdate(y):
    return dt.date(y, 1, 1) + dt.timedelta(days=random.randint(0, 364))
def lognorm(mu, sd):
    return math.exp(random.gauss(mu, sd))
def maybe(v, p_missing):
    return "NA" if random.random() < p_missing else v

seen_in_market = defaultdict(set)      # div -> supplier mids seen (for entry flag)
rows = []

def make_award(y, buyer, div, supplier, force_shy=False, force_singleb=None,
               force_code=None):
    cpvs, stype, _, mu, sdv, titles = MARKETS[div]
    opaque   = buyer in OPAQUE
    shortcut = buyer in SHORTCUT
    util     = buyer["btype"] == "UTILITIES"

    # procedure
    proc = random.choices(PROCS, PWEIGHT)[0]
    if force_shy:                                                       # P3
        proc = random.choices(["NEGOTIATED_WITHOUT_PUBLICATION","OUTRIGHT_AWARD",
                               "NEGOTIATED_WITH_PUBLICATION"], [.5,.3,.2])[0]

    # price (DLK)
    if force_shy:
        price = THRESH[stype] * random.uniform(0.82, 0.995)
    else:
        price = lognorm(mu, sdv)
        price = min(price, math.exp(mu + 3.2 * sdv))
    price = round(price, 2)

    # dates & periods
    submp = decp = "NA"
    firstcall = deadline = award = "NA"
    award_d = None
    if proc == "OUTRIGHT_AWARD":
        award_d = rdate(y)
        nocft = 100
    else:
        nocft = 0
        fc = rdate(y)
        if proc == "OPEN":
            sp = int(random.gauss(34, 6))
        elif proc == "RESTRICTED":
            sp = int(random.gauss(30, 5))
        else:
            sp = int(random.gauss(18, 6))
        if shortcut and proc in ("OPEN","RESTRICTED"):
            sp = random.randint(7, 15)                                   # P4
        sp = max(5, min(90, sp))
        dl = fc + dt.timedelta(days=sp)
        if util:                                                     # P5
            dp = max(60, min(320, int(random.gauss(120, 45))))
        else:
            dp = int(random.gauss(45, 20))
            if random.random() < 0.02:
                dp = random.randint(150, 310)        # sparse long tail
            dp = max(3, min(320, dp))
        award_d = dl + dt.timedelta(days=dp)
        firstcall, deadline = fc.isoformat(), dl.isoformat()
        submp, decp = sp, dp
    award = award_d.isoformat() if award_d else "NA"

    # single bidding                                                     P1
    base = {"OPEN":.12,"RESTRICTED":.18,"NEGOTIATED_WITH_PUBLICATION":.35,
            "NEGOTIATED_WITHOUT_PUBLICATION":.70,"OUTRIGHT_AWARD":.95,
            "COMPETITIVE_DIALOG":.15}[proc]
    if div == "33": base += 0.03 + 0.026 * (y - 2015)
    if div == "09": base += 0.25
    if shortcut:    base += 0.28
    if util:        base += 0.08
    if opaque:      base += 0.18
    if force_shy:   base = max(base, 0.55)
    if force_singleb is not None:
        singleb = force_singleb
    else:
        singleb = random.random() < min(base, 0.97)
    nbids = 1 if singleb else 2 + min(8, int(random.expovariate(1/1.6)) )

    # relative price / estimates                                         P9
    est = est_usd = "NA"
    p_have_est = 0.15 if opaque else 0.68
    if random.random() < p_have_est:
        if random.random() < 0.08:
            rel = 1.0
        else:
            rel = random.gauss(0.93, 0.18)
            if div == "33":  rel += 0.07
            if opaque:       rel *= 1.12
            rel = max(0.4, min(1.9, rel))
        est = round(price / rel, 2)
        est_usd = round(est / RATE, 2)

    # missingness (P6: opaque buyers, co-occurring blocks)
    loc_missing = random.random() < (0.80 if opaque else 0.18)
    city  = "NA" if (loc_missing or random.random() < 0.03) else buyer["city"]
    pcode = "NA" if loc_missing else PCODE[buyer["city"]]
    nuts  = "NA" if loc_missing else f'["{NUTS[buyer["city"]]}"]'
    btype = maybe(buyer["btype"], 0.30 if opaque else 0.10)
    natproc = maybe(NATIONAL[proc], 0.60 if opaque else 0.12)
    if opaque and random.random() < 0.25: award = "NA"
    if random.random() < 0.06: deadline = "NA"
    bname  = maybe(buyer["name"], 0.02)
    sname  = maybe(supplier["name"], 0.03)
    title  = maybe(random.choice(titles).format(buyer["city"]), 0.05)
    price_missing = random.random() < 0.03
    supply = maybe(stype, 0.04)

    entry_new = supplier["mid"] not in seen_in_market[div]
    seen_in_market[div].add(supplier["mid"])

    code_eff = force_code or (
        supplier["alt"] if (supplier.get("alt") and random.random() < 0.08)
        else supplier["code"])
    tid = str(uuid.uuid4())
    price_v  = "NA" if price_missing else price
    priceusd = "NA" if price_missing else round(price / RATE, 2)
    dec_ok   = decp != "NA"
    rows.append([
        tid, 1, nbids, "TRUE", "DL",
        award, maybe(award_d + dt.timedelta(days=random.randint(10,40)) if award_d else "NA", 0.88)
            if award_d else "NA",
        deadline, proc, proc, natproc, supply,
        firstcall,
        f"https://tenders.demoland.example/notice/{tid[:8]}",
        "https://tenders.demoland.example/",
        (award_d + dt.timedelta(days=random.randint(20,60))).isoformat()
            if (award_d and random.random() < 0.7) else "NA",
        f"https://tenders.demoland.example/award/{tid[:8]}",
        buyer["mid"], buyer["bid"], city, pcode, "DL", nuts, bname, btype,
        {"NATIONAL_AUTHORITY":"GENERAL_PUBLIC_SERVICES","REGIONAL_AUTHORITY":"GENERAL_PUBLIC_SERVICES",
         "UTILITIES":"UTILITIES","PUBLIC_BODY":"HEALTH","OTHER":"OTHER"}[buyer["btype"]],
        "DL", nuts,
        supplier["mid"], supplier["sid2"], "DL", f'["{NUTS[supplier["city"]]}"]', sname,
        price_v, priceusd, "DLK" if random.random() > 0.05 else "EUR",
        code_eff, "CPV2008", code_eff,
        submp, decp, "TRUE" if stype == "WORKS" else "FALSE",
        title, est_usd, est, "DLK" if est != "NA" else "NA",
        nocft, ("NA" if random.random() < 0.02 else (100 if singleb else 0)),
        "NA",
        (100 if (dec_ok and decp > 90) else (0 if dec_ok else "NA")),
        100 if proc not in ("OPEN","RESTRICTED") else 0,
        (100 if (submp != "NA" and submp < 20) else (0 if submp != "NA" else "NA")),
        "NA",
        round(min(0.99, random.betavariate(2, 6) + (0.55 if buyer in CAPTURED and supplier is buyer.get("favored") else 0)), 3),
        100 if bname == "NA" else 0, 100 if title == "NA" else 0,
        100 if sname == "NA" else 0, 100 if supply == "NA" else 0,
        100 if price_missing else 0, 100 if nuts == "NA" else 0,
        100 if natproc == "NA" else 0, 0,
        100 if award == "NA" else 0,
        round(random.betavariate(2, 8), 3), nbids,
        100 if entry_new else 0,
        maybe(100 if supplier["city"] != buyer["city"] else 0, 0.30),
    ])

# ── main generation loop ────────────────────────────────────────────────
for y in YEARS:
    n = ROWS_PER_YEAR[y]
    # P2: captured buyers first (heavy, favored)
    for b in CAPTURED:
        k = random.randint(28, 45)
        for _ in range(k):
            div = random.choice(b["markets"])
            fav = random.random() < 0.90
            sup = b["favored"] if fav else random.choice(ACTIVE[(div, y)])
            make_award(y, b, div, sup, force_singleb=(random.random() < 0.8) if fav else None)
        n -= k
    # P3: threshold-shy contracts
    shy = int(n * 0.07)
    for _ in range(shy):
        div = random.choices(DIVS, WEIGHT)[0]
        b = random.choice([x for x in BUYERS if div in x["markets"]] or BUYERS)
        make_award(y, b, div, random.choice(ACTIVE[(div, y)]), force_shy=True)
    n -= shy
    # baseline
    for _ in range(n):
        div = random.choices(DIVS, WEIGHT)[0]
        b = random.choice([x for x in BUYERS if div in x["markets"]] or BUYERS)
        make_award(y, b, div, random.choice(ACTIVE[(div, y)]))
# P8: unusual entries — then top up each entrant's HOME awards so the
# target-market share sits below the tool's 5% atypicality threshold
# (an "established supplier making occasional out-of-profile wins")
tgt_wins = defaultdict(int)
for s, tgt, tcode, y in UNUSUAL:
    b = random.choice([x for x in BUYERS if tgt in x["markets"]])
    make_award(y, b, tgt, s, force_code=tcode)
    tgt_wins[s["mid"]] += 1
counts = defaultdict(int)
for r in rows: counts[r[28]] += 1          # col 28 = bidder_masterid
done = set()
for s, tgt, _tc, _y in UNUSUAL:
    if s["mid"] in done: continue
    done.add(s["mid"])
    need = int(math.ceil(tgt_wins[s["mid"]] / 0.045)) + 2 - counts[s["mid"]]
    for _ in range(max(0, need)):
        y2 = random.choice(YEARS)
        b2 = random.choice([x for x in BUYERS if s["home"] in x["markets"]] or BUYERS)
        make_award(y2, b2, s["home"], s)

# ── write CSV (sample style: strings quoted; numbers/booleans/NA bare) ──
HEADER = ["tender_id","lot_number","bid_number","bid_iswinning","tender_country",
 "tender_awarddecisiondate","tender_contractsignaturedate","tender_biddeadline",
 "tender_proceduretype","tender_proceduretype.1","tender_nationalproceduretype",
 "tender_supplytype","tender_publications_firstcallfortenderdate","notice_url",
 "source","tender_publications_firstdcontractawarddate",
 "tender_publications_lastcontractawardurl","buyer_masterid","buyer_id",
 "buyer_city","buyer_postcode","buyer_country","buyer_nuts","buyer_name",
 "buyer_buyertype","buyer_mainactivities","tender_addressofimplementation_country",
 "tender_addressofimplementation_nuts","bidder_masterid","bidder_id",
 "bidder_country","bidder_nuts","bidder_name","bid_price","bid_priceusd",
 "bid_pricecurrency","lot_productcode","lot_localproductcode_type",
 "lot_localproductcode","submp","decp","is_capital","lot_title",
 "lot_estimatedpriceusd","lot_estimatedprice","lot_estimatedpricecurrency",
 "ind_corr_nocft","ind_corr_singleb","ind_corr_taxhaven","ind_corr_dec_period",
 "ind_corr_nonopen_proc_method","ind_corr_subm_period","ind_corr_benfords",
 "ind_winner_share","ind_tr_buyer_name_missing","ind_tr_title_missing",
 "ind_tr_bidder_name_missing","ind_tr_tender_supplytype_missing",
 "ind_tr_bid_price_missing","ind_tr_impl_loc_missing",
 "ind_tr_proc__method_missing","ind_tr_bids_nr_missing","ind_tr_aw_date_missing",
 "ind_comp_bidder_mkt_share","ind_comp_bids_count","ind_comp_bidder_mkt_entry",
 "ind_comp_bidder_non_local"]
assert all(len(r) == len(HEADER) for r in rows), "column count mismatch"

def cell(v):
    if isinstance(v, bool): return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(int(v)) if float(v).is_integer() else f"{v}"
    s = str(v)
    if s in ("NA","TRUE","FALSE"): return s
    return '"' + s.replace('"', '""') + '"'

random.shuffle(rows)
with io.open("demo_procurement_data.csv", "w", encoding="utf-8", newline="") as f:
    f.write(",".join(f'"{h}"' for h in HEADER) + "\n")
    for r in rows:
        f.write(",".join(cell(v) for v in r) + "\n")
print(f"wrote demo_procurement_data.csv: {len(rows)} rows, {len(HEADER)} columns")
