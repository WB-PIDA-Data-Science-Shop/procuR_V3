---
title: Demo dataset guide
nav_order: 2
---

# Demo Dataset — Demoland Public Procurement (Synthetic)

`demo_procurement_data.csv` is a **fully synthetic** dataset built to
demonstrate every feature of the Procurement Analysis Dashboard. It can be
published alongside the tool: no real entities, transactions, places or
identifiers appear anywhere in it.

* **15,674 award records and ~2,700 suppliers, 2015–2024**, fictional country **Demoland**
  (country code `DL`), currency **DLK** (1 USD = 1.80 DLK).
* **26 markets** using authentic CPV-2008 division codes and names
  (construction, pharmaceuticals, software, laboratory equipment,
  catering, training, …), so market charts and CPV clustering look and
  behave like real OpenTender data.
* Same 67-column OpenTender-style schema as real inputs — upload it
  unchanged on the Setup tab.
* ~7.7 MB as CSV (≈1.7 MB zipped); regenerate bit-for-bit with
  `python3 generate_demo_data.py` (fixed seed 42).

> **Disclosure.** The interesting findings below are *planted by
> construction* — the generator injects them deliberately so each analysis
> tab has something to show. This dataset demonstrates what the tool can
> detect; it is not evidence about any real procurement system.

## Loading — fully automatic

Click **"Load bundled demo dataset (Demoland)"** on the Setup tab (or upload
`demo_procurement_data.csv` manually — same result). Country (`DL`) and
currency (`DLK`) are detected from the data, and every threshold pre-fills
itself: procurement-value thresholds **Works 270,000 / Supplies & Services
70,000 DLK** (bunching analysis), legal minimum submission **30 days (Open)
/ 25 (Restricted)**, and the long-decision threshold **90 days**. Nothing to
type — just click through the tabs.

## What each tab should find

**Data Overview** — volume grows from ~800 (2015) to ~1,350 (2024) awards;
value is dominated by construction and medical supplies.

**Economic Outcomes**
* *Market Sizing*: construction (CPV 45) leads by value with few, large
  contracts; medical supplies (33) leads by count.
* *Supplier Dynamics*: construction visibly **closes over time** (the
  new-supplier share falls to ~10% by 2024) while IT services (72) keeps
  refreshing (~30–45% new); fuels (09) is a static five-supplier market —
  look for it in the bottom-left of the stability scatter.
* *Relative Prices*: distribution centred ≈0.97 with a visible **spike at
  exactly 1.00** (estimates copied from prices, ~8% of contracts); medical
  shows the highest share of contracts above estimate.
* *Competition*: overall single bidding ≈47%; highest in fuels (09) and
  medical (33, **rising over time**), and in non-open procedures.

**Administrative Efficiency**
* *Procedure Types*: non-competitive procedures take a substantial value
  share.
* *Bunching*: clear excess mass **just below 270,000 DLK** for works (and
  below 70,000 for supplies/services), mostly under negotiated/direct
  procedures — red bars in the bunching panel.
* *Submission Periods*: a group of ten regional "shortcut" buyers uses
  7–15-day windows; their open tenders reach ~40% single bidding vs ~27%
  for normal windows.
* *Decision Periods*: decision times span 3–310 days with ~90% under 100;
  utilities decide in ~120 days median vs ~45 elsewhere, so they dominate
  the long-decision (≥60-day) shares in the buyer-group chart.
* *Regressions*: short submission periods → **positive, robust** effect on
  single bidding; long decision periods → positive, more moderate effect.

**Integrity**
* *Missing Values*: location fields (city/postcode/NUTS) go missing
  **together** (co-occurrence ≈0.9); estimated prices are missing for ~37%
  of records, concentrated in 15 "opaque" buyers; MAR analysis shows
  missingness is predictable from buyer type.
* *Interoperability*: master IDs are complete (linkage is reliable),
  location fields are the weak point.
* *Concentration*: three buyers (~430–460 contracts each) direct ~75–85% of
  their annual spend to a single favored supplier, **repeatedly across
  years** — they top the concentration chart.
* *Risky Profiles*: after running the network analysis, the flow matrix and
  network show six supplier routes between market clusters: IT services
  (720→452, five suppliers) and security/business services (797→452, four)
  into construction works; equipment repair into medical supplies (504→331,
  four); IT equipment into pharmaceuticals (302→336, five); waste services
  into electrical works (905→453, four); and design services into software
  (713→722, four). Suppliers keep a fixed CPV specialty (with occasional
  secondary-cluster activity), matching the tool's 3-digit clustering —
  lowering the "min suppliers per route" slider reveals additional sparse
  organic crossings.
* *Regressions*: buyers with more missing data have **more single bidding**
  (+8pp raw) and their contracts settle **~6pp higher relative to
  estimates** — both effects survive the robustness grid.

**Exports** — generate the Word report and figures ZIP for each section;
every chart above appears in them (run the network analysis and regressions
first so the deferred figures are included).

## Files

| File | Purpose |
|---|---|
| `demo_procurement_data.csv` | the dataset (upload this) |
| `generate_demo_data.py` | seeded generator — full recipe for every planted pattern, for transparency and regeneration |
| `DEMO_GUIDE.md` | this walkthrough |
