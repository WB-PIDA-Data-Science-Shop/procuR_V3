---
title: Developer guide
nav_order: 5
---

# Developer Guide — Unified Procurement Analysis App

Audience: anyone who needs to **modify** the app or its utility files.
Read `README.md` first for orientation and the anchor navigation system.

Contents:
1. [Architecture at a glance](#1-architecture-at-a-glance)
2. [Load order & function overrides (read before editing!)](#2-load-order--function-overrides)
3. [Reactive state model](#3-reactive-state-model)
4. [End-to-end data flow](#4-end-to-end-data-flow)
5. [Tab ↔ code map](#5-tab--code-map)
6. [How-to recipes](#6-how-to-recipes)
7. [Known quirks & gotchas](#7-known-quirks--gotchas)
8. [Suggested future restructuring](#8-suggested-future-restructuring)

---

## 1. Architecture at a glance

```
                       ┌──────────────────────────────┐
                       │  CSV upload (Setup tab)      │
                       │  [APP-SV03]                  │
                       └──────────────┬───────────────┘
                                      │ fread + de-dup cols + date→char
                                      │ normalize_procurement_data() [SH-08]
                                      │ country auto-detect
              ┌───────────────────────┼───────────────────────────┐
              ▼                       ▼                           ▼
 run_economic_efficiency_  run_admin_efficiency_      run_integrity_pipeline_
 pipeline() [EC-12]        pipeline() [AD-07]         fast_local() [APP-G24]
 (networks skipped)        (regressions optional)     (networks/MCAR/regs deferred)
              │                       │                           │
              ▼                       ▼                           ▼
        econ$analysis           admin$analysis              integ$analysis
        econ$data               admin$data                  integ$data
              │                       │                           │
   per-tab filters [APP-SV06/07]  [APP-SV08/09]              [APP-SV28]
   econ_filter_data [APP-G11]   admin_filter_data [APP-G12] integrity_filter_data [APP-G13]
              │                       │                           │
              ▼                       ▼                           ▼
     econ tabs SV11–SV17      admin tabs SV20–SV24        integ tabs SV29–SV33
              │                       │                           │
              ▼                       ▼                           ▼
   downloads/reports SV18–19   SV25–27                    SV34–37
   (Word via [APP-G22], figures regenerated via [APP-G17/G18/G19])
```

Design in one sentence: **utility files hold pure(ish) analysis functions
and one orchestrator each; `global.R` holds glue, filtering and export
builders; `ui.R` holds layout; `server.R` holds reactive plumbing and
re-renders plots for interactivity; `www/styles.css` holds every visual
design decision.**

Two consequences worth internalising:

* Many charts exist in **two implementations**: a ggplot version in a utils
  file (used in pipeline/Word-report mode) and a plotly `render*` version in
  the server (what the user sees). When changing a chart's logic, check
  whether both need the change — the Word-report builders
  `econ_regenerate_plots()` [APP-G17], `admin_build_word_plots()` [APP-G18]
  and `integ_regenerate_plots()` [APP-G19] were written to mirror the
  renderPlotly logic.
* The pipelines are also runnable **headless** (outside Shiny) for batch work:
  each `run_*_pipeline()` takes a data frame + `country_code` + `output_dir`
  and returns a named list; `save_outputs = TRUE` writes PNGs.

---

## 2. Load order & function overrides

On `shiny::runApp()`, Shiny loads `global.R` → `ui.R` → `server.R`
(native multi-file layout; there is no `app.R`). `global.R` sources, in
this order ([APP-G02]):

```
1. utils_shared.R      ← single home of all shared code
2. econ_out_utils.R    (tryCatch — app still runs without it, with stubs)
3. integrity_utils.R   (tryCatch — stubs on failure)
4. admin_utils.R       (tryCatch — stubs on failure)
5. global.R's own overrides/patches  [APP-G03..G05]
```

CSS is not R code at all anymore: the design system lives in
`www/styles.css`, linked from `ui.R`. Anchor codes were **not** renamed in
the split — `[APP-Gxx]` = global.R, `[APP-UIxx]` = ui.R,
`[APP-SVxx]` = server.R; the master TOC in `global.R` maps them.

### Shared code map

Every function is defined in exactly one file. Anything used by more than
one module lives in `utils_shared.R`; each module carries cross-reference
comments pointing to the anchors below.

| Defined in utils_shared | Used by | Contents |
|---|---|---|
| [SH-13] fixest building blocks | admin + integrity regressions | `make_fe_part`, `make_cluster`, `safe_fixest`, `extract_effect_fixest`, `effect_p10_p90` |
| [SH-15] sensitivity suite | all four regression exercises | `add_strength_column`, `summarise_*`, `classify_specs`, `top_cells`, `build_sensitivity_bundle` |
| [SH-14] `pick_best_model` | admin + integrity | preferred-spec selection (integrity adds its own `pick_most_robust_model`, `model_diagnostics`, vcov trio) |
| [SH-12] `year_filter_config` + `get_year_range` | admin + integrity pipelines | analysis year windows; components `singleb` / `rel_price` / `default`, NA = unbounded. **The `rel_price` rows deliberately mirror the `singleb` rows** — price analyses use the same windows as single-bidding analyses; edit those rows to change that. `safe_pipeline_config()` [APP-G23] wraps config building with a manual fallback. |
| [SH-07] `recode_procedure_type` / `.CANONICAL_RECODE` | everywhere | canonical procedure labels; unrecognised raw values are kept, not collapsed to "Other" |
| [SH-09] `add_buyer_group` | everywhere | buyer-type grouping |
| [SH-06] `load_data` | batch scripts | batch CSV reader — the interactive upload uses its own reader ([APP-SV03]) |

### The two overrides that remain (deliberate)

| Function | Defined in | **Winner at runtime** | Why |
|---|---|---|---|
| `analyze_buyer_supplier_concentration()` | integrity [IN-14], app.R [APP-G03] | **app.R** | Three-tier *paired* buyer/supplier ID resolution; assigned into `.GlobalEnv` so `analyze_competition`'s dynamic lookup finds it. |
| `build_concentration_yearly_plot()` | integrity [IN-14], patched in app.R [APP-G04] | **app.R** | Wraps the integrity version to enforce buyer-ID priority; returns a **native plotly** object. |

Rules going forward:

* **Adding a shared function?** Put it in `utils_shared.R`. Never re-define an
  existing name in a later-sourced file — later definitions silently replace earlier ones.
* **Grep all five files** for a name before creating it.
* Batch use now *requires* sourcing `utils_shared.R` first (§6.6 already does).

## 3. Reactive state model

Defined at [APP-SV01]. Three parallel state bundles, one per section:

```r
econ / admin / integ <- reactiveValues(
  data              = ...,  # full enriched dataset (post-pipeline)
  analysis          = ...,  # pipeline output list (plots + tables + stats)
  filtered_data     = ...,  # committed after "Apply Filters"
  filtered_analysis = ...,  # regenerated analysis on the filtered data
  country_code      = ...,
  value_divisor     = ...,  # 1 or FX rate when local-currency toggle is on
  fig_*             = ...,  # stored plotly figs, always match what's displayed
  ...                       # section-specific extras (thresholds, deferred flags)
)
```

Section-specific extras:

* `admin$thresholds`, `admin$price_thresholds`, `admin$global_proc_filter`,
  `admin$national_proc_keys/labels`, `admin$regression_done`
* `integ$network_done`, `integ$regression_done`, `integ$missing_advanced_done`
  — deferred-computation flags (see §4.4)

**Filters** live in `econ_filters` / `admin_filters` / `integ_filters`:
one slot per tab (`overview`, `market`, `supplier`, … resp. `proc`, `subm`,
`dec`, `reg`, …) plus `active`. Each slot is
`list(year, market, value, buyer_type, procedure_type)`. Filter widgets are
generated per tab with unique input IDs by `filter_bar_ui()` [APP-G16] and the
loops at [APP-SV06/SV09/SV28]; clicking a tab's **Apply Filters** runs the
section's `*_filter_data()` function and commits `filtered_data` (+ regenerated
`filtered_analysis`), which every output in that section reads.

Stored `fig_*` objects exist so downloads and Word reports can export exactly
what is on screen without re-computation races.

---

## 4. End-to-end data flow

### 4.1 Upload & preparation — [APP-SV03]

1. Separator sniffing on the first raw line (`,` vs `;` vs tab), then explicit
   `fread(...)` with `na.strings = c("", "-", "NA")`, `keepLeadingZeros = TRUE`.
2. Duplicate columns dropped; `IDate/Date/POSIX` columns coerced to character
   (so regex year-extraction is version-proof).
3. `normalize_procurement_data()` [SH-08] creates canonical alias columns.
4. Country code: user input, else single-valued 2-letter country column, else
   majority vote, else `"GEN"`.
5. The three pipelines run with progress notifications; heavy parts deferred.
6. `econ$*`, `admin$*`, `integ$*` are populated; UI tabs become live.

### 4.2 Econ pipeline — `run_economic_efficiency_pipeline()` [EC-12]

Enriches: `tender_year`, `cpv_cluster` (2-digit CPV), `single_bid`,
`price_bin_usd`, optional CPV labels. Computes market sizing [EC-07],
supplier entry (per-market or aggregate fallback) [EC-08], relative prices
[EC-10], single-bid suite [EC-11]. Networks [EC-09] are **skipped at upload**
(`network_cpv_clusters = character(0)`) and generated on demand in the
Networks tab [APP-SV15]. Returns the list documented in
`FUNCTION_REFERENCE.md` → EC-12.

### 4.3 Admin pipeline — `run_admin_efficiency_pipeline()` [AD-07]

Thresholds come from the UI (`admin$thresholds` via
`app_thresholds_to_pipeline()` [AD-01]) or country defaults [AD-06].
Computes procedure shares [AD-05], submission/decision day distributions and
short/long flags [AD-03/AD-04], and (optionally / on demand, see
[APP-SV05]) fixest regressions of single-bidding on short-submission /
long-decision flags across an FE×cluster×controls spec grid [AD-02], with the
sensitivity bundle ([SH-15]) surfaced in the Robustness panels [APP-SV24].

### 4.4 Integrity pipeline — `run_integrity_pipeline_fast_local()` [APP-G24]

The app calls this "fast" variant, **not** `run_integrity_pipeline()` [IN-21]
(that one is the full batch runner that saves PNGs). Fast mode runs missing
values, interoperability, competition/concentration and summary stats, and
returns empty placeholders for markets/prices. The heavy pieces are deferred
behind buttons + `integ$*_done` flags:

* MCAR/MAR advanced missingness → [APP-SV29] (`run_missing_advanced_tests` [IN-12])
* Network / flow matrix / concentration → [APP-SV32] (module [IN-15], patched concentration [APP-G03/G04])
* Single-bid & relative-price regressions → [APP-SV33] (modules [IN-14]/[IN-16])

### 4.5 Filtering

Per section: `econ_filter_data()` [APP-G11], `admin_filter_data()` [APP-G12],
`integrity_filter_data()` [APP-G13]. All take
`(df, year_range, market, value_range, buyer_type, procedure_type,
value_divisor, ...)`, apply only non-NULL filters, and re-derive downstream
columns where needed (e.g. keeping `single_bid` numeric and `price_bin`
ordered). Value filtering respects the local-currency divisor.

### 4.6 Exports — the standardized layer [APP-G21]

Every static export funnels through four helpers defined at [APP-G21]:

| Helper | Job |
|---|---|
| `pa_prep_plotly_export(fig, vw, vh)` | Sets an exact export canvas (default 1400×850). If the render block set a width/height on the figure (dynamic-height missingness charts etc.), those dimensions **win outright** — the requested canvas is ignored for that axis, so the exported PNG keeps the chart's designed aspect ratio instead of stretching it. Boosts all fonts to `PA_EXPORT_FONTS` (tick 15 / title 17 / legend 13), forces white background. |
| `pa_save_plot_any(obj, file, w_in, h_in)` | Saves **either** a ggplot (`ggsave`) or a plotly fig (`webshot2`) to PNG. Returns `TRUE`, or `FALSE` with `attr(., "reason")` — never throws, never silently succeeds-by-skipping. |
| `pa_write_manifest(dir, label, rows)` | Writes `MANIFEST.txt` into the ZIP staging dir: one row per *expected* figure with status saved/skipped/failed and an actionable note. |
| `pa_word_add_fig(d, p, ..., height_in, render_scale)` | Word figure insert used by all three report generators (their local `add_fig` delegates here). Handles ggplot *and* plotly; a NULL/failed figure becomes a visible italic note (customisable via `missing_note`) instead of a silent gap. `height_in` overrides the aspect-based height for data-dependent charts (integrity missingness figures use it). `render_scale > 1` renders a ggplot on a proportionally larger canvas so its point-sized text appears smaller at page width — used for the regression spec-grid plots whose text otherwise overflows the page. Images are always placed at the saved file's **true aspect ratio** (reported via `attr("size_px")` from `pa_save_plot_any`), so plotly figures with their own dimensions are never distorted. |
| `pa_build_flow_matrix(unusual_mat, top_n, min_bidders)` | Builds the cross-market supplier flow-matrix heatmap (ggplot) from the unusual-entry matrix; returns `list(plot, height_in)` or NULL. Shared by the integrity Word report and the integrity ZIP. |

Route-specific behaviour:

* **Individual PNG buttons** — `.save_fig_png()` in [APP-SV10] wraps
  `pa_prep_plotly_export()`; handlers in SV18/SV25/SV34 pass their preferred
  size through (the old bug where `dl_econ_plotly` dropped `vw/vh` is fixed).
  The integrity regression figures are ggplots, so their buttons use
  `pa_save_plot_any()` directly (the old handlers pointed at `integ$fig_singleb`
  / `fig_relprice`, reactive slots that were never assigned).
* **Fullscreen expand** — the modebar expand button uses a **CSS overlay**,
  not the browser Fullscreen API (which is silently blocked in the RStudio
  viewer and in iframes without `allowfullscreen`). On expand the chart is
  `Plotly.relayout`-ed to fill the window — necessary because charts with a
  fixed layout height (missingness charts) would otherwise stay small — and
  the original dimensions are restored on exit (button again or Esc).
* **ZIP bundles** (SV19/SV26/SV35) — each handler holds the section's
  **canonical figure manifest** (a list of `obj/name/w/h/note` entries mixing
  regenerated ggplots and stored displayed plotly figs), saves each via
  `pa_save_plot_any()`, and writes MANIFEST.txt. The ZIP is always produced,
  and the UI reports "X of Y figures saved".
* **Word reports** [APP-G22] build their own officer helpers inline; ggplot
  versions of on-screen charts come from [APP-G17/G18/G19], plotly-only
  figures are rendered via webshot2.

---

## 5. Tab ↔ code map

(For what each tab's charts *mean* — variables, formulas, thresholds,
interpretation — see `METHODOLOGY.md`; this table maps tabs to code.)

| Sidebar tab (`tabName`) | UI anchor | Server anchor(s) | Filter slot |
|---|---|---|---|
| Setup (`setup`) | APP-UI03 | APP-SV03, SV04 (thresholds) | — |
| Overview (`overview`) | APP-UI04 | APP-SV11 (value boxes read integ/econ) | econ `overview` |
| Data Overview (`data_overview`) | APP-UI05 | APP-SV11 | econ `filtered_data` |
| Market Sizing (`market_sizing`) | APP-UI06 | APP-SV12 | econ `market` |
| Supplier Dynamics (`supplier_dynamics`) | APP-UI07 | APP-SV13, SV14 | econ `supplier` |
| Networks (`networks`) | APP-UI08 | APP-SV15 | econ `network` |
| Relative Prices (`relative_prices`) | APP-UI09 | APP-SV16 | econ `price` |
| Competition (`competition`) | APP-UI10 | APP-SV17 | econ `competition` |
| Procedure Types (`procedures`) | APP-UI11 | APP-SV20 | admin `proc` |
| Submission Periods (`submission`) | APP-UI12 | APP-SV21 (+SV04 apply-cutoffs) | admin `subm` |
| Decision Periods (`decision`) | APP-UI13 | APP-SV22 (+SV04) | admin `dec` |
| Regression Analysis (`regression`) | APP-UI14 | APP-SV23, SV24, SV05 | admin `reg` |
| Missing Values (`integrity_missing`) | APP-UI15 | APP-SV30, SV29 | integ `missing` |
| Interoperability (`integrity_interop`) | APP-UI16 | APP-SV31 | integ `interop` |
| Risky Profiles (`integrity_risky`) | APP-UI17 | APP-SV32 | integ `risky` |
| Regression/Prices (`integrity_prices`) | APP-UI18 | APP-SV33 | integ `prices` |
| Export & Download (`export`) | APP-UI19 | APP-SV19, SV26, SV27, SV35 | — |

Download handlers: econ SV18, admin SV25, integrity SV34.

---

## 6. How-to recipes

### 6.1 Change how an existing chart looks

1. Find its `output$...` ID in the UI tab (search the tab's `[APP-UIxx]`
   block for `plotlyOutput("...")`).
2. Jump to the matching `output$... <- renderPlotly(...)` in the tab's
   `[APP-SVxx]` block — that is the on-screen version.
3. If the chart also appears in the Word report, mirror the change in the
   ggplot builder: econ → the utils plot function used by [APP-G17]/[EC-12];
   admin → `admin_build_word_plots()` [APP-G18]; integrity → the module in
   `integrity_utils.R` reached via [APP-G19]/[APP-G24].
4. If a stored `fig_*` exists for it in [APP-SV01], make sure the render block
   still assigns it (downloads use it).

### 6.1b Add a figure to the exports (ZIP + Word)

Adding a chart to a tab does **not** automatically export it. Two steps:
(1) add one entry (`obj`, `name`, `w`, `h`, `note`) to the section's manifest
list in its ZIP handler (SV19/SV26/SV35) — `obj` can be a regenerated ggplot
or a stored `fig_*` plotly; the `note` should tell the user how to generate it
if it can be missing; (2) add one `add_fig(doc, ...)` line in the section's
Word generator [APP-G22]. Both paths handle NULL gracefully now.

### 6.2 Add a new chart to an existing tab

1. UI: add a `box(... plotlyOutput("my_id"), downloadButton("dl_my_id", ...))`
   inside the tab's `[APP-UIxx]` block.
2. Server: in the tab's `[APP-SVxx]` block add
   `output$my_id <- renderPlotly({ req(<section>$filtered_data); ... })`,
   pipe the result through `post_process_plotly()` [APP-G20] for consistent
   styling, and store it in the section's `fig_` slot if it should be
   downloadable/exportable.
3. Download: reuse the section's download helper ([APP-SV10]) as the existing
   handlers in SV18/SV25/SV34 do.
4. Word report: add the ggplot version to the relevant regenerator
   ([APP-G17/G18/G19]) and a `body_add_*` block in the section's report
   generator [APP-G22].

### 6.3 Add a filter dimension (e.g. supply type)

1. Extend `filter_bar_ui()` [APP-G16] with the new widget (keep the
   `sectiontab_name` ID convention).
2. Add the field to every slot in the section's `*_filters` reactiveValues
   [APP-SV01].
3. Read it in the section's apply-filters observers ([APP-SV07/SV08/SV28])
   and pass it to the section's `*_filter_data()` ([APP-G11/G12/G13]), where
   you add the actual `dplyr::filter()`.
4. Update `get_filter_caption()` [APP-G14] / `get_filter_description()`
   [SH-04] so captions and reports mention it.

### 6.4 Add a country

1. `admin_utils.R` [AD-06]: add a row to `admin_threshold_config`
   (use `NA` where no legal threshold exists) and, if needed, to
   `year_filter_config` — **and mirror the year rows in `integrity_utils.R`
   [IN-01]**, since both files keep their own copy.
2. `econ_out_utils.R` [EC-06]: add to `NETWORK_YEAR_LIMITS` if the country's
   network years should be clipped.
3. Nothing else — the upload flow auto-detects the code [APP-SV03].

### 6.5 Change admin threshold defaults or add a procedure type

* Defaults: [AD-06] table; live values: threshold UI in Setup +
  `proc_threshold_ui()` [APP-G15]; conversion: [AD-01].
* Canonical procedure labels live in `.CANONICAL_RECODE` [APP-G05] and
  `PROC_TYPE_LABELS` [APP-G08]. Unrecognised labels are preserved and get
  dynamic threshold inputs via [APP-SV04] (`national_proc_keys`).

### 6.6 Run a pipeline outside Shiny (batch / debugging)

```r
source("utils_shared.R"); source("econ_out_utils.R")
source("integrity_utils.R"); source("admin_utils.R")   # keep this order!
df  <- load_data("export.csv")            # integrity's reader wins — that's fine
res <- run_admin_efficiency_pipeline(df, country_code = "UY",
                                     output_dir = "out/", save_outputs = TRUE)
```

---

## 7. Known quirks & gotchas

* **Don't introduce duplicate definitions** — see §2. Shared code belongs
  in `utils_shared.R`; re-defining an existing name in a later-sourced file
  silently shadows the original.
* **`get_year_range()` / year windows** live in [SH-12]. The table's
  `rel_price` rows deliberately mirror the `singleb` rows; to give price
  analyses their own windows, edit those rows knowingly — that changes the
  integrity price analysis.
* **Two chart implementations** (plotly on screen vs ggplot in Word): keep
  them in sync or the report will diverge from the app. Since the [APP-G21]
  layer, plotly-only charts *can* be exported directly (webshot2), so a
  ggplot twin is optional — but ggsave is much faster for ZIP bundles.
* **Exports are manifest-driven**: if a ZIP or Word report is "missing" a
  figure, check MANIFEST.txt / the italic note in the document first — it
  states whether the figure was skipped (deferred analysis not run, columns
  missing) or failed, before you go debugging code.
* **Applying filters resets deferred results** (by design — results must
  match the filters): integrity network/regression/advanced-missingness and
  the admin regressions must be re-run after any "Apply Filters" click before
  they can appear in ZIPs or Word reports. The manifest notes say so.
* **Dynamic-height charts need three heights kept in sync**: the
  `ggplotly(height = ...)` formula in the render block, the CSS spacer
  (`renderUI` injecting `#id { height: ...px !important; }`), and — for Word —
  the `height_in` passed to `add_fig`. The missingness charts' spacers now
  carry a "must match" comment; if you change one formula, change all.
* **Two integrity plot functions have non-obvious return types**:
  `build_concentration_yearly_plot()` (as patched by [APP-G04]) returns a
  **native plotly object** — never pass it to `ggsave()`; and
  `build_network_graph_from_matrix()` **returns** a ggraph/ggplot object
  rather than drawing to the active device — wrapping it in a base `png()`
  device captures nothing. Either mistake makes the figure vanish silently
  from a Word report; always route these through `pa_word_add_fig()` /
  `pa_save_plot_any()`.
* **Word reports are complete by construction**: every chart a section's tabs
  can show has a corresponding `add_fig` line (stored plotly figs are merged
  into the analysis list by the download handlers). Plotly figures are
  rendered via webshot2, so report generation takes noticeably longer when
  many of them are present — that's expected.
* **Regression figures live in `filtered_analysis`, not in `fig_*` slots**:
  integrity → `filtered_analysis$competition$singleb_plot` and
  `filtered_analysis$prices$rel_price_plot` (ggplots); admin →
  `filtered_analysis$plot_short_reg` / `plot_long_reg`. The reactive slots
  `integ$fig_singleb` / `integ$fig_relprice` are unused — don't wire new
  exports to them.
* **`shared_css` is one giant string** [APP-G24] (lines ~1928+ pre-annotation).
  Don't insert code (or quotes) inside it; R will happily parse a broken
  string boundary into chaos.
* **CSV reading**: Shiny uploads are extension-less temp files; the app sniffs
  the separator itself [APP-SV03]. If a file reads with far fewer rows than
  expected, check the first line's separator counts and embedded quotes.
* **`fread` date auto-detection** differs across data.table versions — hence
  the blanket date→character coercion right after reading. Keep it.
* **Networks can segfault** on very large graphs (ggraph stress layout);
  [APP-SV15] guards with row limits — don't remove them.
* **Deferred flags**: `integ$network_done`, `integ$regression_done`,
  `integ$missing_advanced_done`, `admin$regression_done` gate expensive
  observers. Re-running "Apply Filters" resets what needs recomputation;
  if you add a deferred output, follow the same flag pattern.
* **All-NA placeholder columns**: some code injects `bid_priceusd <- NA_real_`
  when absent; `detect_price_col()` [APP-G10] deliberately skips all-NA
  columns — use it rather than `"col" %in% names(df)` for price columns.
* **Unknown CPV clusters** are remapped to `"99"` (Other) right after upload
  so filters and plots agree — do the same for any new CPV-derived feature.
* **`options(shiny.sanitize.errors = FALSE)`** is set for debuggability; flip
  to `TRUE` (or remove) before any public deployment.
* **Encoding/line endings**: files are CRLF, UTF-8 with box-drawing characters
  in comments. Keep editors in UTF-8 to avoid mangling the banners.

---

## 8. Suggested future restructuring

The codebase is organised for safe incremental work: shared code lives once
in `utils_shared.R`, the app follows Shiny's native multi-file layout, and
the anchor system makes every section addressable. If deeper restructuring
is wanted later, the natural next steps are:

1. Consider Shiny modules (`moduleServer`) per section — the per-tab
   input-ID prefix convention (`econ_market_*`, `admin_subm_*`, `integ_*`)
   already mimics module namespacing, so the migration is mostly renaming.
2. Add `testthat` tests around the pure functions (filters, recodes,
   threshold conversion) before any behavioural refactor.
