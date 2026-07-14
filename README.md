# Unified Procurement Analysis App

A Shiny dashboard for analysing public-procurement data from a single CSV upload,
covering three analytical perspectives:

| Section | What it answers | Utility file |
|---|---|---|
| **Economic Outcomes** | Market sizes, supplier entry/churn, buyer–supplier networks, relative prices, single-bid competition | `econ_out_utils.R` |
| **Administrative Efficiency** | Procedure-type shares, submission & decision period lengths, threshold "bunching", regressions linking short/long periods to single bidding | `admin_utils.R` |
| **Integrity** | Missing-data quality (incl. MCAR/MAR tests), interoperability, buyer/supplier concentration, risky market profiles, single-bid & relative-price regressions | `integrity_utils.R` |

Each section has its own filter state, its own tabs, and its own Word/ZIP export.

---

## Live demo & documentation

* **Live app:** <https://datanalytics-int.worldbank.org/procur_v3/> — click **Run Demo** on the Setup page.
* **Documentation site:** `https://<USER>.github.io/<REPO>/` once GitHub Pages
  is enabled (Settings → Pages → branch `main`, folder `/docs`).

## Repository layout

```
global.R  ui.R  server.R          # the Shiny app (multi-file layout)
utils_shared.R  econ_out_utils.R  # analysis modules
admin_utils.R   integrity_utils.R
www/styles.css                    # design system
demo-data/                        # bundled synthetic dataset + guide + generator
docs/                             # GitHub Pages site (this documentation)
deploy_shinyapps.R  PUBLISHING.md # one-command deploy + publishing checklist
```

## 1. Quick start

```r
# From the app folder:
shiny::runApp()          # or open the folder as an RStudio project and Run App
```

The app uses Shiny's native multi-file layout: `global.R` (setup + analysis
glue) → `ui.R` (layout) → `server.R` (reactive logic), with all styling in
`www/styles.css`. Two deployment rules: **(1) the folder must not contain a file named
`app.R`** — Shiny gives such a file precedence and would ignore the app's
actual code; **(2) keep the folder structure intact**, i.e. `styles.css`
belongs in the `www/` subfolder. (The CSS is inlined at startup via `includeCSS`, and the app also
finds it in the root as a fallback — but if the file is missing entirely the
app renders with the default unstyled theme and logs a warning.)

Then in the browser:

1. **Setup tab** → upload a CSV (up to 1 GB; `,`, `;` or tab separated — the
   separator is auto-detected).
2. Optionally type a 2-letter country code (leave blank to auto-detect from
   `tender_country` / `buyer_country` columns; falls back to `"GEN"`).
3. Click **Run Analysis**. All three pipelines run; heavy pieces
   (networks, MCAR/MAR tests, integrity regressions) are deferred until you
   open their tabs and click their buttons.

### Required packages

Declared at the top of `global.R` (`[APP-G01]`):
`shiny, shinydashboard, shinyWidgets, DT, ggplot2, dplyr, tidyr, data.table,
scales, officer, flextable, rmarkdown, plotly, patchwork, corrr, tidytext,
fixest, ggeffects, igraph, ggraph, purrr, ggrepel, giscoR, eurostat, sf,
kableExtra, zip` — plus (loaded by `econ_out_utils.R`) `stringr, forcats,
tidygraph`, and `webshot2` for PNG downloads of plotly figures, `tibble`,
`naniar/misty` style dependencies used inside the MCAR test if present.

Install anything missing with `install.packages()`.

---

## 2. Demo dataset

A fully synthetic demonstration dataset ships with the tool:
`demo_procurement_data.csv` (15,674 award records, ~2,700 suppliers, 26 CPV
markets, 2015–2024, for the
fictional country "Demoland", currency DLK) together with `DEMO_GUIDE.md`
— a walkthrough of what every tab should find — and
`generate_demo_data.py`, the seeded generator that produced it. All
entities, places and identifiers are invented, so the dataset is safe to
publish alongside the tool. Click **“Load bundled demo dataset”** on the Setup
tab — country, currency and every threshold configure themselves — and
follow the guide tab by tab. The findings it lists are planted
by construction: they demonstrate detection capability, not real-world
evidence.

## 3. File inventory

| File | Lines* | Role |
|---|---|---|
| `global.R` | ~2.2k | Setup and analysis glue: options, sourcing, patches, filter engines, export/report builders. Anchors `[APP-G01..G24]`; holds the **master TOC** for all APP anchors. |
| `ui.R` | ~1.7k | Dashboard layout and every tab definition. Anchors `[APP-UI01..UI19]`. Must end with the bare `ui` object. |
| `server.R` | ~7.1k | All reactive logic. Anchors `[APP-SV01..SV35]`. Must end with the bare `server` function. |
| `www/styles.css` | — | The entire design system (fonts, palette, sidebar, plot backgrounds). **Design changes happen here, without touching R.** |
| `utils_shared.R` | ~0.7k | Helpers used by all sections and **the single home of every function shared across modules** (regression/sensitivity suite, year-window config, recode, …). Sourced **first**. |
| `econ_out_utils.R` | ~2k | Economic-efficiency helpers + `run_economic_efficiency_pipeline()`. Sourced **second**. |
| `integrity_utils.R` | ~3.9k | Integrity helpers + analysis modules + `run_integrity_pipeline()`. Sourced **third**. |
| `admin_utils.R` | ~1.1k | Admin-efficiency helpers + `run_admin_efficiency_pipeline()`. Sourced **fourth (last)**. |

\* Approximate, after annotation.

> ℹ️ **One definition per name.** Every function is defined in exactly one
> file; anything used by more than one module lives in `utils_shared.R`.
> The only exceptions are two deliberate overrides applied at startup
> (`[APP-G03]`/`[APP-G04]` in `global.R`); see `DEVELOPER_GUIDE.md` §2.
> Cross-reference comments in each module point to where shared functions
> are defined.

---

## 4. Navigating the code (anchor system)

Every file starts with a **table of contents**, and every section carries a
unique, grep-able anchor code in square brackets:

```
[SH-xx]   utils_shared.R
[EC-xx]   econ_out_utils.R
[AD-xx]   admin_utils.R
[IN-xx]   integrity_utils.R      (mirrors the file's existing "PART n" numbering)
[APP-Gxx] app.R — global scope (patches, filters, report builders)
[APP-UIxx] app.R — UI tab definitions
[APP-SVxx] app.R — server logic blocks
```

To find anything: open the file's TOC (top of file), pick the code, and search
for it, e.g. `grep -n "\[APP-SV21\]" app.R` jumps to the admin Submission
Periods server block. Anchors are stable identifiers — documentation refers to
them instead of line numbers.

Sections whose runtime definition is replaced elsewhere are flagged inline
with `!! OVERRIDDEN` and a pointer to the winning anchor.

---

## 5. Input data requirements

The app is built for OpenTender/PROACT-style exports but degrades gracefully.
On upload, `normalize_procurement_data()` (`[SH-08]`) creates canonical columns
from common aliases, so national exports with different naming still work.

### Canonical columns and accepted aliases

| Canonical column | Used for | Accepted aliases (first match wins) |
|---|---|---|
| `buyer_masterid` | buyer FE, concentration, counts | `buyer_id` |
| `buyer_buyertype` | buyer-group plots, controls | `entity_type`, `buyer_type`, `contracting_authority_type`, `buyer_entity_type`, `entity_category` |
| `bidder_masterid` | supplier entry, networks, concentration | `bidder_id`, `bidder_name`, `supplier_name`, `winner_name`, `bidder_normalizedname` |
| `lot_productcode` | CPV/market analysis | `cpv_code`, `cpv`, `lot_cpvcode`, `product_code`, `sector_code` |
| `bid_priceusd` | value analysis (no FX conversion is attempted) | `bid_price` |

### Other columns the app looks for

* **Dates** (year extraction, `[SH-10]`): `tender_publications_firstcallfortenderdate`,
  `tender_awarddecisiondate`, `tender_biddeadline` (first available wins);
  `tender_contractsignaturedate` as a decision-date fallback.
* **Competition**: `ind_corr_singleb` (0/100 single-bid indicator). If it is
  absent the competition/single-bid charts are unavailable (`[EC-04]`).
* **Prices**: priority order `bid_priceusd → lot_estimatedpriceusd →
  tender_finalprice → lot_estimatedprice → bid_price` (`[APP-G10]`, `[EC-12]`);
  `lot_estimatedpriceusd` also enables relative-price analysis
  (`contract / estimate`, `[EC-10]`).
* **Procedure types**: `tender_proceduretype`, recoded to canonical labels by
  `.CANONICAL_RECODE` (`[APP-G05]`); unrecognised national labels are kept
  as-is and get their own threshold inputs in the admin section (`[APP-SV04]`).
* **Currency**: `bid_pricecurrency` drives the local-currency toggle
  (`[APP-G06]`).
* Missing values: `""`, `"-"`, `"NA"` are read as `NA` on upload (`[APP-SV03]`).

Nothing is strictly mandatory — modules that lack their inputs skip themselves
with a message — but the more of the above are present, the more tabs light up.

---

## 6. Country-specific configuration

Three places hold country defaults (all keyed by 2-letter code, uppercase):

| What | Where | Anchor |
|---|---|---|
| Admin thresholds (short submission days per procedure, medium band, long decision days) | `admin_threshold_config` in `admin_utils.R`; rows for `DEFAULT`, `UY`, `BG`, `ID` | `[AD-06]` |
| Year windows per analysis component (`singleb`, `default`; integrity also knows `rel_price`) | `year_filter_config` + `get_year_range()` in both `admin_utils.R` and `integrity_utils.R` | `[AD-06]`, `[IN-01]` |
| Network year limits (econ networks) | `NETWORK_YEAR_LIMITS` in `econ_out_utils.R` | `[EC-06]` |

Unknown countries fall back to `DEFAULT` / unbounded years / code `"GEN"`.
Users can override admin thresholds live in the UI (Setup/threshold panels);
those UI values flow through `app_thresholds_to_pipeline()` (`[AD-01]`).

To add a country: see the recipe in `DEVELOPER_GUIDE.md` §6.4.

---

## 7. Outputs

All static exports (individual PNGs, ZIP bundles, Word figures) go through one
standardized layer (`[APP-G21]`): a common canvas size, print-ready font
sizes, and a single saver that handles both ggplot and plotly figures.

* **Interactive**: every chart is plotly with a camera button (high-res
  white-background PNG) and an **expand button** that enlarges the chart to
  fill the whole window for detailed viewing — press it again or hit Esc to
  exit (`[APP-SV10]`; works in the browser and the RStudio viewer alike).
  Drag on any chart to box-zoom; the autoscale button resets.
* **Per-figure downloads**: buttons under most charts export the currently
  displayed figure at a standard readable size via `webshot2`
  (`[APP-SV18]`, `[APP-SV25]`, `[APP-SV34]`). Charts that set their own height
  (dynamic heatmaps) keep their shape.
* **ZIP bundles**: all figures of a section as PNGs (`[APP-SV19]`,
  `[APP-SV26]`, `[APP-SV35]`). Every ZIP now contains a **MANIFEST.txt**
  listing each expected figure with status *saved / skipped / failed* and,
  for skipped ones, exactly what to do (e.g. "Run the regressions in the
  Regression tab first") or why the dataset can't produce it.
* **Word reports**: one per section (`[APP-G22]`), always from the *currently
  filtered* data. A figure that could not be generated appears as a visible
  italic note in its place — figures are never silently dropped.

---

## 8. Documentation map

| File | Read it when… |
|---|---|
| `README.md` (this file) | you are new, or preparing data for the app |
| `METHODOLOGY.md` | you need to understand or explain **what a chart shows**: data, formulas, filters, thresholds, and how to interpret every plot (technical, code-referenced) |
| `METHODOLOGY_POLICY_NOTE.md` | you are briefing a **non-technical / policy audience**: the same analytical framework in plain, academic prose, with interpretation principles and a glossary |
| `DEVELOPER_GUIDE.md` | you need to change behaviour: architecture, data flow, override table, how-to recipes, known gotchas |
| `FUNCTION_REFERENCE.md` | you need to know what a specific function does, its inputs and outputs |
| In-code TOCs + anchors | you are navigating inside a file |
