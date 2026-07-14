---
title: Methodology
nav_order: 3
---

# Methodology — Unified Procurement Analysis App

This document explains **every chart in the app**: what data feeds it, how it
is computed, which filters and settings affect it, and how to read it. It is
written against the code itself — each entry cites the anchor code
(`[EC-07]`, `[APP-SV12]`, …) where the computation lives, so you can verify or
modify any step (see `README.md` §4 for the anchor navigation system).
A plain-language companion for non-technical and policy audiences is
available as `METHODOLOGY_POLICY_NOTE.md`.

Contents:
1. [Data preparation (applies to everything)](#1-data-preparation)
2. [Filters (applies per section)](#2-filters)
3. [Rendering, exports and reproducibility](#3-rendering-exports-and-reproducibility)
4. [Economic Outcomes plots](#4-economic-outcomes)
5. [Administrative Efficiency plots](#5-administrative-efficiency)
6. [Integrity plots](#6-integrity)
7. [Regression & robustness methodology (shared)](#7-regression--robustness-methodology)
8. [General interpretation caveats](#8-general-interpretation-caveats)

---

## 1. Data preparation

All analyses run on a single uploaded CSV, prepared once at upload
(`[APP-SV03]`) and then enriched per section by the pipelines.

**Reading.** The field separator (`,`, `;`, tab) is sniffed from the first
line; the file is read with `data.table::fread` with `na.strings = c("", "-",
"NA")` (so blank cells, dashes and literal "NA" all become missing) and
`keepLeadingZeros = TRUE` (IDs are never mangled). Duplicated column names
are dropped; any auto-detected date columns are coerced back to character so
year extraction behaves identically across data.table versions.

**Column normalisation** (`normalize_procurement_data()` `[SH-08]`). Canonical
columns are created from common aliases so national exports work unchanged:
`buyer_masterid` (← `buyer_id`), `buyer_buyertype` (← `entity_type`,
`buyer_type`, `contracting_authority_type`, …), `bidder_masterid`
(← `bidder_id`, `bidder_name`, `supplier_name`, `winner_name`, …),
`lot_productcode` (← `cpv_code`, `cpv`, `product_code`, …), `bid_priceusd`
(← `bid_price`; **no currency conversion is performed** — see §8).

**Derived variables used across plots:**

| Variable | Definition | Where |
|---|---|---|
| `tender_year` | First 4-digit year found in, priority order: `tender_publications_firstcallfortenderdate` → `tender_awarddecisiondate` → `tender_biddeadline` | `[SH-10]` |
| `tender_proceduretype` (recoded) | Raw procedure strings mapped by `.CANONICAL_RECODE` to canonical labels (Open Procedure, Restricted Procedure, Negotiated with/without publications, Competitive Dialogue, Direct Award, …). Unrecognised national labels are **kept as-is**, not collapsed into "Other". | `[SH-07]` |
| `cpv_cluster` ("market") | First **2 digits** of the CPV product code. Codes not in the reference list are remapped to `"99"` (Other). Human labels come from `CPV_DESCRIPTIONS` / `get_cpv_label()`. Throughout this document, "market" = 2-digit CPV division. | `[EC-03]`, `[SH-02]` |
| `single_bid` | `ind_corr_singleb / 100` → a 0/1 (or 0–1) indicator that the tender received exactly one bid. If `ind_corr_singleb` is absent, competition plots are unavailable (the flag is *not* reconstructed from `bid_number`). | `[EC-04]` |
| `price_bin` | `bid_priceusd` (fallback `bid_price` → `lot_estimatedpriceusd` → `lot_estimatedprice`) cut at 0, 5k, 10k, 50k, 100k, 500k, 1M (left-closed) → "< 5k" … "> 1M". | `[EC-04]` |
| `buyer_group` | Regex on `buyer_buyertype`: National Buyer / Regional Buyer / Utilities / EU agency / Other Public Bodies (case-insensitive). | `[SH-09]` |
| Price column (generic) | Wherever "value" is plotted, the first *non-empty* column in the priority chain `bid_priceusd → lot_estimatedpriceusd → tender_finalprice → lot_estimatedprice → bid_price` is used (`detect_price_col` `[APP-G10]` skips all-NA placeholders). |

**Country code.** User input on the Setup tab, else auto-detected from a
2-letter country column (unique value, else majority vote), else `"GEN"`.
It selects default thresholds (`[AD-06]`) and year windows (`[SH-12]`).

---

## 2. Filters

Each of the three sections (Economic / Admin / Integrity) has **its own
filter state**, and within a section **each tab has its own filter bar**
(`filter_bar_ui` `[APP-G16]`). Filters do nothing until the tab's **Apply
Filters** button is clicked; they then commit a new `filtered_data` for the
whole section, which every plot in that section reads.

Filter fields (all optional; only non-empty ones are applied — `[APP-G11/12/13]`):

| Field | Effect |
|---|---|
| **Year range** | `tender_year` between the slider bounds. |
| **Market** | keep selected `cpv_cluster` value(s). |
| **Contract value** | price (per the priority chain above) within the range. If the *local-currency* toggle is active, bounds are interpreted in local currency and divided by the detected median local/USD rate (`value_divisor`, `[APP-G06]`) before filtering. |
| **Buyer type** | keep selected `buyer_buyertype` values. |
| **Procedure type** | keep selected canonical procedure labels (admin also honours its global procedure filter from Setup). |

Two important consequences:

1. **Every chart caption lists the active filters** (`get_filter_caption`
   `[APP-G14]`), and Word reports/ZIPs are always built from the *currently
   filtered* data — what you export is what you saw.
2. **Applying filters resets deferred results** (integrity networks,
   integrity/admin regressions, MCAR/MAR): they must be re-run so results
   match the filters.

---

## 3. Rendering, exports and reproducibility

On screen every chart is interactive plotly (drag = box-zoom, autoscale
resets, expand button = full-window view). Static exports (PNG buttons, ZIP,
Word) all go through one standardized layer (`[APP-G21]`): fixed canvas or
the chart's own dynamic dimensions, print-ready fonts, and — in Word — the
saved image's true aspect ratio. Several charts exist in two implementations
(interactive plotly in the server; ggplot twin for Word/ZIP via
`[APP-G17/G18/G19]`); the computations described below are identical in both.
The only stochastic element anywhere is graph layout: network layouts are
seeded (`set.seed(42)`), so all outputs are fully reproducible for a given
dataset + filters + thresholds.

---

## 4. Economic Outcomes

### 4.1 Data Overview — *Contracts per Year* and *Contract Value by Year* `[APP-SV11]`
(The app has a single, shared Data Overview tab; its charts reflect the
Economic section's filters.)
- **Variables:** `tender_year`; the detected price column for the value chart.
- **Computation:** simple counts / sums of the filtered data per year. The
  value chart is displayed in millions (or the local-currency equivalent when
  the toggle is on).
- **Interpretation:** coverage diagnostics first, trends second. A cliff at
  the edges usually reflects data collection (publication lags, source
  changes), not procurement activity. Check these before reading any yearly
  trend elsewhere.

### 4.2 Market Sizing `[EC-07]`, `[APP-SV12]`
All three charts aggregate the filtered data per **market** (2-digit CPV):
`n_contracts = n()`, `total_value = sum(price)`, `avg_value = mean(price)`
(`summarise_market_size`).

- ***Number of Contracts by Market*** — horizontal bars of `n_contracts`,
  sorted. Reads as "where the procurement volume is".
- ***Total Contract Value by Market*** — same layout with `total_value`.
  Volume ≠ value: a market can dominate one and not the other.
- ***Market bubble chart*** — x = contract count, y = total value, bubble
  size = average contract size. Top-right = big markets; high-y/low-x =
  few, large contracts (infrastructure-type markets); high-x/low-y = many
  small purchases.
- **Caveats:** value charts silently use whichever price column exists; if
  only estimated prices are present, "value" means *estimated* value. Missing
  prices are excluded from sums/means but not from counts.

### 4.3 Supplier Dynamics

**Core definition — "new" supplier** (`compute_supplier_entry` `[EC-08]`):
within each market, a supplier's `first_year` is the earliest `tender_year`
in which their `bidder_masterid` appears *in that market* (within the
filtered data). A supplier is **new** in market *m*, year *t* iff
*t = first_year(m, supplier)*. Per market × year the app computes
`n_suppliers` (distinct IDs), `n_new_suppliers`, `share_new = new/total`.

- ***Supplier Entry Bubble Grid*** `[APP-SV13]` — x = year, y = market,
  bubble size = `n_suppliers`, fill = `share_new`; bubbles at or above the
  "high-entry" slider threshold are flagged. Sliders restrict to markets
  above a minimum average contract count / value (computed per market as the
  mean over years). **Reading it:** persistent large bubbles with moderate
  new-share = healthy contested markets; shrinking bubbles with near-zero
  new-share = closing markets (possible entrenchment); all-dark first column
  is mechanical (see caveat).
- ***Unique Suppliers heatmap / New-vs-Repeat heatmap*** (Word/ZIP twins,
  `[EC-08]`) — the same statistics as tile heatmaps per market × year.
- ***Market Stability Scatter*** `[APP-SV13]` — one point per market:
  x = mean `n_suppliers` across years, y = mean `share_new`,
  point size = average yearly contract count,
  and **volatility = SD of `share_new` across years** encoded in the hover/
  colour. Bottom-left (few suppliers, no entry) = concentrated & static —
  the corner worth investigating; top-right = contested and refreshing.
- ***New vs Repeat Suppliers Trend*** — stacked area of `share_new` vs
  `share_repeat` over years (aggregate across all markets when CPV is
  absent: `compute_supplier_entry_aggregate`, same definitions without the
  market dimension).
- ***Top Suppliers*** `[APP-SV14]` — suppliers grouped by ID; ranked by
  `total_value` when a price column exists, else by `n_contracts` (top-N
  slider); hover includes each supplier's dominant market (its modal
  `cpv_cluster`).
- **Caveats:** (1) **Left-censoring** — in the first observed year *every*
  supplier is "new" by construction; ignore the first year of the range when
  reading entry rates. Filtering years re-bases `first_year`, so entry shares
  are relative to the filtered window, not all history. (2) Supplier identity
  is only as good as the ID column; name-based IDs inflate "new" suppliers
  through spelling variants.

### 4.4 Buyer–Supplier Networks `[EC-09]`, `[APP-SV15]`
- **Variables:** buyer ID, supplier ID, `cpv_cluster`, `tender_year`.
- **Computation:** for the selected market(s), a bipartite graph per year:
  nodes = top buyers (by contract count) and their suppliers, edges =
  buyer–supplier contract pairs (edge weight = number of contracts). Layout
  is force-directed (ggraph), seeded. Generated **on demand** (Networks tab)
  with row-limit guards; country-specific year clipping may apply
  (`NETWORK_YEAR_LIMITS` `[EC-06]`).
- **Interpretation:** hub suppliers connected to many buyers are normal for
  broad markets; a buyer connected to exactly one supplier year after year in
  a market with many alternative suppliers is the interesting pattern.
  Layout distances are aesthetic, not metric — read the *connections*, not
  positions.

### 4.5 Relative Prices `[EC-10]`, `[APP-SV16]`
- **Core variable:** `relative_price = bid_price / lot_estimatedprice`
  (same currency numerator/denominator). Ratios ≤ 0 or **> 5 are set to NA**
  (`cap = 5`) — an outlier trim that removes data-entry errors.
  Requires both columns; tabs are empty otherwise.
- ***Distribution of Relative Prices*** — density of `relative_price` with a
  reference line at 1.0. Mass left of 1 = contracts below estimate
  ("savings"); a **spike exactly at 1.0** usually means estimates are set
  equal to (or copied from) contract prices — an estimation-practice signal,
  not a market outcome. Mass right of 1 = overruns relative to estimate.
- ***Relative Prices by Year*** — yearly distributions (median + spread).
  Watch for drift of the median away from ~1 and for changing spread.
- ***Top Markets by Relative Price*** — markets ranked by
  `pct_over = mean(relative_price > 1)` — the **share of contracts priced
  above estimate** (not the mean ratio), top-N shown. Robust to outliers by
  construction.
- ***Top Buyers by Relative Price*** — the same share computed per buyer
  (minimum-contract filter applies).
- **Caveats:** everything here measures prices *relative to the buyer's own
  estimate*. Systematically low/high estimates shift the whole picture
  without any market change; the ratio says nothing about absolute value for
  money.

### 4.6 Competition (single bidding) `[EC-11]`, `[APP-SV17]`
All charts show the **mean of `single_bid`** (share of tenders with exactly
one bidder) per grouping, as lollipops against the overall filtered-data
average (colour = above/below overall; label shows the group's n).

| Chart | Grouping variable |
|---|---|
| *Single Bidding Overall* | none (one value + yearly context) |
| *…by Procedure Type* | canonical `tender_proceduretype` |
| *…by Price Category* | `price_bin` (see §1) |
| *…by Buyer Group* | `buyer_group` |
| *…by Market* | `cpv_cluster` (top markets by rate, `top_markets_by_single_bid`) |
| *Top Buyers by Single Bidding* | buyer ID (minimum-contract filter) |

- **Interpretation:** single bidding is the workhorse *red-flag* competition
  indicator: structurally high rates in open procedures, in specific markets,
  or at specific buyers warrant attention. But it is an **outcome**, not
  proof of wrongdoing — thin markets, remote regions and specialised goods
  legitimately produce single bids. The by-price chart separates "small
  purchases nobody bids on" from "large contracts with one bidder" — the
  latter matters more. Groups with tiny n (shown in labels) are noise.

---

## 5. Administrative Efficiency

### 5.1 Procedure Types `[AD-05]`, `[APP-SV20]`
- ***Share of Contract Value / Count by Procedure Type*** — per year, each
  procedure's share of total value (`build_proc_share_data`, using the price
  fallback chain) and of contract count; stacked 100% bars.
  **Interpretation:** competitive procedures (Open/Restricted) should
  dominate; a growing share of Negotiated-without-publication or Direct
  Award — especially by *value* while the *count* share stays flat (a few
  large non-competitive contracts) — is the classic pattern to investigate.
- ***Contract Value Distribution by Procedure Type*** — distribution of
  (log) contract values per procedure; shows which procedures are used at
  which value ranges, and pre-reads the bunching analysis.

### 5.2 Contract Value Bunching `[APP-SV20]` (bunching panel)
Detects **strategic pricing just below procedure thresholds** (e.g. splitting
or shading contract values to stay under the open-procedure limit).

- **Inputs:** `bid_price` (> 1), the per-procedure × supply-type **price
  thresholds** entered in Setup, `classify_supply()` for Goods/Works/Services.
- **Computation (per threshold panel):**
  1. Work in `log10(bid_price)`; histogram with **0.05-log bins** within
     ±`show` window around the threshold.
  2. Define an **exclusion window** of `n_search_bins` × 0.05 log-units
     around the threshold (user slider, default 10 bins ⇒ ±0.5).
  3. Fit a **degree-4 polynomial** to bin counts *outside* the exclusion
     window (≥ 8 bins required) — this is the **counterfactual** (dotted
     line): what the value distribution would look like absent threshold
     effects.
  4. Bins **below the threshold, inside the window**, whose observed count
     exceeds the counterfactual by more than the **sensitivity** slider
     (default +50%) are flagged red as *bunching*; other below-threshold
     bins are amber.
- **Interpretation:** red bars = excess mass just under the threshold. The
  wider the exclusion window, the more conservative the counterfactual.
  Bunching is *consistent with* threshold manipulation but also with honest
  budgeting to known limits — corroborate with procedure choice and single
  bidding for the same contracts. Sparse panels (<15 contracts) are skipped.

### 5.3 Submission Periods `[AD-03/AD-04]`, `[APP-SV21]`
- **Core variable:** `tender_days_open` = days between
  `tender_publications_firstcallfortenderdate` and `tender_biddeadline`
  (`compute_tender_days`; negative and ≥365-day values dropped as errors).
- **Short-deadline flag** (`add_short_deadline_flags`): per procedure,
  `days < cutoff`. Cutoffs come from the Setup / tab threshold inputs; where
  a threshold is left NA (no legal minimum) the **within-data median for
  that procedure** is used instead — the flag then means "below typical",
  not "below legal". An optional **medium band** exists for Open procedures
  (`[min, max)` = "reduced but lawful" deadlines).
- ***Overall Submission Period Distribution*** — histogram of days with
  quartile lines (`plot_days_hist_with_quartiles`). Read the quartiles, and
  look for spikes exactly at legal minimums (calendar compliance vs genuine
  planning).
- ***Submission Periods by Procedure Type*** — same histogram faceted per
  procedure (quartiles per facet).
- ***Short vs Normal Submission Deadlines*** — distribution split by the
  flag; shows how much mass sits below the cutoff.
- ***Short Deadlines by Buyer Group*** — share of short-deadline tenders per
  `buyer_group`: which buyer types systematically compress deadlines.
- ***Submission Period Share Summary*** — per procedure, stacked shares of
  **Short / Medium / Normal** tenders (statuses from the current cutoffs;
  recomputed live when you press the tab's *Apply cutoffs*).
- **Interpretation:** short submission windows mechanically restrict who can
  bid — they are the main *administrative* lever behind single bidding
  (tested formally in §7). Flags are threshold-relative: with median
  fallbacks, ~50% short is *by construction* and only the comparison across
  procedures/buyers/years is meaningful.

### 5.4 Decision Periods `[APP-SV22]`
Mirror of §5.3 with `tender_days_dec` = days from `tender_biddeadline` to
`tender_awarddecisiondate` (fallback `tender_contractsignaturedate`), and a
single **long-decision** flag: `days ≥ long_decision_days` (applies to
Open/Restricted/Negotiated-with-publication). Long decision periods signal
process inefficiency and create space for post-bid negotiation; the same
four chart types plus the share summary apply.

### 5.5 Admin Regressions — see §7 (outcome: single bidding; treatments:
`short_submission_period`, `long_decision_period`).

---

## 6. Integrity

### 6.1 Missing Values `[IN-06/IN-07/IN-12]`, `[APP-SV30]`
The tracked variable set is fixed (`label_lookup` `[IN-02]`): tender ID,
year, lot number, number of bids, winning bid, country, award-decision /
contract-signature / bid-deadline / first-call dates, procedure type,
national procedure type, supply type, notice/award URLs, source, buyer and
bidder IDs/names, etc. For every tracked variable *v*:
`missing_share(v) = mean(is.na(v))` over the filtered rows.

- ***Overall Missing Values*** — bar per variable, sorted; height is
  data-driven (one row per variable). Severity convention used throughout:
  **<5% low, 5–20% moderate, >20% high**.
- ***Missing Values by Buyer Type*** — heatmap variable × `buyer_group`
  (top-N variables slider). Uneven missingness across buyer types = uneven
  reporting discipline, and a warning that buyer-type comparisons elsewhere
  are built on unequal data.
- ***Missing Values by Procedure Type*** / ***Over Time*** — same heatmap
  logic against procedure / year. A sudden yearly change usually marks a
  source or form change.
- ***Co-occurrence of Missing Values*** (deferred; `[IN-08]`) — for variable
  pairs, **Jaccard = P(both NA) / P(either NA)**. High Jaccard = the fields
  go missing *together* (same form section / same source pipeline), i.e.
  structural rather than random gaps.
- ***Little's MCAR test*** (deferred) — chi-square test of "Missing
  Completely At Random" over up to 20 numeric columns. A significant p-value
  **rejects** MCAR: missingness is patterned. With large n it is almost
  always significant — treat it as confirmation, not discovery.
- ***MAR Predictability*** (deferred; `run_mar_predictability`) — for each
  variable with ≥1% missingness, a model predicts *whether the value is
  missing* from observed covariates (year, buyer type, …). The chart shows
  predictive power per variable: high values = "Missing At Random given
  observables" — missingness is systematic along known dimensions.
  **Interpretation of the trio:** bars tell *how much* is missing;
  co-occurrence and MAR tell *how structured* it is. Structured missingness
  is the integrity-relevant kind — it means specific record types
  (procedures, buyers, periods) are systematically less transparent, and it
  motivates the §7 regressions that use missingness as the explanatory
  variable.

### 6.2 Interoperability `[IN-13]`, `[APP-SV31]`
A table (not a chart): for buyers and suppliers, the missing share of
*Source ID*, *Generated (master) ID*, *Name*, and *Address/postcode*
(`compute_org_missing`). This measures whether records can be **linked** —
across years, datasets, and registries. High master-ID missingness directly
degrades every supplier-entry, network and concentration figure (see their
caveats).

### 6.3 Buyer–Supplier Concentration `[APP-G03/G04]`, `[APP-SV32]`
- **ID resolution:** the first *pair* of buyer+supplier ID columns that are
  both non-trivially populated, tried in order master IDs → raw IDs → names.
- **Computation:** per `year × buyer × supplier`:
  `total_spend = Σ price` (contract count if no price column). Then per
  `year × buyer`: `buyer_conc(supplier) = supplier_spend / buyer_total_spend`
  and **`max_conc` = the largest single-supplier share of that buyer's
  spending that year**.
- ***Top Buyers by Supplier Concentration Over Time*** — per year, the
  buyers with the highest `max_conc` (Top-N and *minimum contracts per
  buyer-year* sliders — the latter removes buyers whose 100% concentration
  is just "they bought twice"). Buyers appearing in multiple years are
  marked (*repeated*).
- **Interpretation:** `max_conc` near 1 = one supplier captures (nearly) all
  of a buyer's spend. Persistently repeated buyers at high concentration
  *with many contracts* are the priority pattern — single-year, few-contract
  cases are usually mechanical. Concentration is a dependency measure, not
  proof of favoritism: sole legitimate suppliers exist (utilities,
  monopolies, framework contracts).

### 6.4 Risky Profiles — unusual market entries `[IN-15]`, `[APP-SV32]`
- **Definition of an atypical entry** (`detect_unusual_entries`; thresholds
  from the pipeline config): for each supplier × market,
  `share_awards = awards in that market / supplier's total awards`. The
  entry is **atypical** iff the supplier has *enough history*
  (`total awards ≥ 4`), the market is *marginal* for them
  (`share_awards < 5%`), and they won *at most 3* awards there.
  Intuition: an established supplier winning one-off contracts far outside
  its home business.
- ***Unusual Supplier Entries*** — suppliers ranked by number of atypical
  market entries.
- ***Most-Affected Markets*** — markets ranked by how many atypical entrants
  they received.
- ***Supplier Flow Matrix*** — heatmap of **home market → target market**
  supplier flows, restricted to routes shared by **≥ 4 suppliers** and the
  top-20 most connected markets; cell value = number of suppliers crossing
  that route ("home" = the supplier's largest-share market).
- ***Supplier Network Graph*** — the same routes as a directed graph
  (node = market, edge width = number of crossing suppliers; min-bidders /
  top-clusters / market-filter controls in the tab; seeded layout).
- **Interpretation:** systematic *routes* matter more than single suppliers:
  many suppliers from unrelated market A repeatedly winning marginal awards
  in market B suggests bid-rotation, fronting, or misclassified CPV codes.
  Always check the CPV explanation first — bad product coding produces
  identical patterns. Conglomerates and traders legitimately span markets.

### 6.5 Integrity Regressions `[IN-14/IN-16]`, `[APP-SV33]` — see §7. Two
models: **single bidding vs missing data** (buyer×year panel; outcome =
buyer's yearly single-bid rate; treatment = buyer's yearly
`cumulative_missing_share` = mean missing-share across tracked variables for
that buyer-year), and **relative prices vs missing data** (contract level;
outcome = `relative_price` as in §4.5, trimmed to (0, 5]; treatment =
`total_missing_share` = row-level share of key fields missing).

---

## 7. Regression & robustness methodology

All four regression exercises (admin: short submission → single bidding,
long decision → single bidding; integrity: missingness → single bidding,
missingness → relative prices) follow the same **specification-grid**
philosophy: rather than one hand-picked model, *every combination* of model
type × fixed effects × clustering × controls is estimated, a **preferred
specification** is displayed, and the full grid feeds the robustness panel.

**The grids** (`run_specs` `[AD-02]`, `run_singleb_specs` `[IN-14]`,
`run_relprice_specs` `[IN-16]`; shared helpers `[SH-13..18]`):

| Element | Admin (tender level) | Integrity single-bid (buyer×year) | Integrity rel. price (contract level) |
|---|---|---|---|
| Outcome | `ind_corr_binary` = `ind_corr_singleb`/100 | `cumulative_singleb_rate` (0–1) | `relative_price`; `log(relative_price)` for log models |
| Treatment (x) | `short_submission_period` / `long_decision_period` flag (§5.3/5.4) | `cumulative_missing_share` | `total_missing_share` |
| Model types | fractional logit (quasibinomial), LPM (OLS), probit | fractional logit family | OLS level, OLS log, Gamma-log GLM |
| Fixed effects | none / buyer / year / buyer+year (integrity also buyer#year) | same | same |
| Clustered SEs | none / buyer / year / buyer×year / buyer type | same | same |
| Controls | x-only, or + buyer type + procedure type | x-only, or + log1p(contracts), log1p(avg value) (+ extra) | x-only, or + log contract value + buyer type + procedure type |

Estimation is via `fixest`; failing specs are skipped (`safe_fixest`).
For each successful spec the focal coefficient, SE, p-value, CI and n are
extracted (`extract_effect_fixest`), plus an **effect-strength** measure:
the predicted change in the outcome when the treatment moves from its 10th
to its 90th percentile, all other variables held at typical values
(`effect_p10_p90`) — this is what "moving from low to high exposure" does in
outcome units. Diagnostics per spec include convergence, collinearity drops,
retained-sample share, and (LPM) out-of-range predictions.

**Preferred specification** (`pick_best_model` `[SH-14]`): the displayed
"main result" is chosen from the grid by sign/significance preferences with
fallbacks — it is the *best defensible* model, not an average.

**Main regression plots** (*Short Submission / Long Decision Regression
Results*; *Single-Bidding vs Missing Data Share*; *Relative Prices vs
Missing Data Share*): coefficient of the preferred spec with its CI and the
marginal-effect visualisation; the FE/cluster/control notes under the plot
state exactly which spec is shown.

**Robustness panels** (`build_sensitivity_bundle` `[SH-15]`, UI `[APP-SV24]`):
- *Specification chart* — every grid estimate as a dot with CI, coloured by
  significance; you should see where the preferred spec sits in the cloud.
- *Breakdowns* — significance shares by FE choice, clustering, controls: if
  the effect only "works" under one FE structure, that is a warning.
- *Verdict card* — automatic classification from the grid:
  **✓ Strong and robust**: ≥70% of specs share the (positive) sign, ≥60%
  significant at p<0.10, and the sign never flips;
  **⚠ Moderate**: ≥60% share the sign and ≥30% significant;
  **✗ Weak or mixed** otherwise (the best available model is still shown).

**How to interpret all of these:** the estimates are **associational**, not
causal — there is no exogenous variation in deadlines or missingness. Fixed
effects absorb stable buyer/year differences, but time-varying confounders
(contract complexity, urgency, market conditions) remain. A "strong and
robust" verdict means the *correlation* is stable across reasonable
modelling choices — which is exactly the right evidentiary standard for a
red-flag screening tool, and exactly short of proof.

---

## 8. General interpretation caveats

1. **Red flags, not verdicts.** Every indicator here (single bidding,
   concentration, bunching, missingness, unusual entries) has innocent
   explanations. The methodology is designed for *screening and
   prioritisation*; conclusions require case-level review.
2. **Filters define the universe.** All statistics — including "new"
   suppliers, overall averages and regression samples — are computed on the
   filtered data. Captions state the active filters; exports match the
   screen.
3. **Currency.** `bid_priceusd` is an alias copy when only local prices
   exist — no FX conversion is performed. The local-currency toggle only
   rescales *filter bounds and axis labels* (median observed rate); it does
   not convert the data. Never compare absolute values across countries from
   this app alone.
4. **ID quality bounds everything entity-based.** Supplier entry, networks,
   concentration and top-N charts inherit the quality of
   `buyer_masterid`/`bidder_masterid` (check §6.2 first). Name-based
   fallbacks fragment entities and bias entry *up*, concentration *down*.
5. **Left/right censoring.** First-year entry rates are 100% by
   construction; last-year counts may be incomplete (publication lag). Read
   yearly trends away from the edges.
6. **Thresholds are configurable and country-specific.** Short/long flags,
   bunching thresholds, and year windows come from Setup / `[AD-06]` /
   `[SH-12]`; with median fallbacks, flags are relative, not legal,
   categories. Reports record the thresholds in force.
7. **Estimated vs final prices.** Wherever the price fallback chain lands on
   estimated prices, "value" means estimated value; relative-price analyses
   explicitly require both and trim ratios to (0, 5].
8. **Missing data is itself an outcome here.** The integrity section treats
   missingness as a transparency indicator — but remember that heavy
   missingness also *mechanically weakens* the other sections' statistics
   for the affected records.
