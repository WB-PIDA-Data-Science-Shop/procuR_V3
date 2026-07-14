---
title: Function reference
nav_order: 6
---

# Function Reference

One entry per function/object, grouped by file and anchor code.
"⚠ overridden" = this definition is replaced at runtime by a later-sourced
file (see `DEVELOPER_GUIDE.md` §2 for the full table). Signatures show the
important arguments only; defaults live in the code.

---

## utils_shared.R  `[SH-xx]`

| Anchor | Function / object | Purpose |
|---|---|---|
| SH-01 | `%ni%`, `%||%` | "not in" operator; NULL-coalescing operator. |
| SH-02 | `CPV_DESCRIPTIONS` | Named vector: 2-digit CPV code → English market label. Extend here to add market labels app-wide. |
| SH-03 | `get_cpv_label(code)` | CPV code(s) → label; unknown codes become `"CPV <code>"`. |
| SH-04 | `get_filter_description(filter_list)` | Human-readable summary of active filters (used in reports). |
| SH-05 | `fmt_value(v)` / `fmt_value_log(lv)` | Value formatting (log10 variant for log sliders). |
| SH-06 | `load_data(input_path)` | Batch-mode CSV reader — single copy (the app upload has its own reader in [APP-SV03]). Drops duplicated columns and coerces date columns to character. |
| SH-07 | `.CANONICAL_RECODE(x)`; `recode_procedure_type(x)` | Canonical procedure-type recode; keeps unrecognised raw values as-is so country-specific labels stay visible. |
| SH-08 | `normalize_procurement_data(df)` | Creates canonical alias columns (`buyer_masterid`, `buyer_buyertype`, `bidder_masterid`, `lot_productcode`, `bid_priceusd`) from national/limited exports. No FX conversion. |
| SH-09 | `add_buyer_group(buyer_buyertype)` | Regex-based grouping into National/Regional/Utilities/EU/Other factor. |
| SH-10 | `add_tender_year(df, date_cols)` | `tender_year` = first 4-digit year found across the date columns (coalesced in priority order). |
| SH-11 | `dir_ensure(path)` | `dir.create` if missing; returns path invisibly. |
| SH-12 | `year_filter_config`; `get_year_range(country_code, component)` | **Analysis year windows** (components: `singleb`, `rel_price`, `default`; NA = unbounded). The `rel_price` rows mirror the `singleb` rows by design — price analyses use the same windows as single-bidding analyses. |
| SH-13 | `make_fe_part`, `make_cluster`, `safe_fixest`, `extract_effect_fixest`, `effect_p10_p90` | **Fixest building blocks**: FE/cluster formula fragments, error-safe estimation, focal-coefficient extraction, and the p10→p90 predicted-outcome effect. Used by both regression stacks. |
| SH-14 | `pick_best_model(results_df, ...)` | **Preferred-spec selector**: picks the displayed model from a spec-grid results table using sign/significance preferences with diagnostic fallbacks. |
| SH-15 | `add_strength_column`, `summarise_sensitivity_overall`, `summarise_sign_instability`, `summarise_by_fe/cluster/controls`, `classify_specs`, `top_cells`, `build_sensitivity_bundle` | **Sensitivity/robustness suite**: turns a spec-grid results table into the robustness summaries and verdicts shown in the app. |

---

## econ_out_utils.R  `[EC-xx]`

| Anchor | Function | Purpose |
|---|---|---|
| EC-01 | *(setup block)* | Loads packages; registers `text` as an optional ggplot aesthetic so `ggplotly()` hover tooltips don't warn. |
| EC-02 | `save_plot(plot, out_dir, filename, width, height, dpi)` | ggsave wrapper with error tolerance; used when the pipeline runs in save mode. |
| EC-03 | `make_cpv_cluster_legend(market_summary)` | Cluster→category legend table for reports. `add_cpv_cluster(df, cpv_col, digits)` adds `cpv_cluster` (first n digits of CPV). |
| EC-04 | `add_single_bid_flag(df)` | `single_bid` 0/1 from `ind_corr_singleb` (or derived). `add_price_bins_usd(df)` adds ordered `price_bin` factor from the best USD price column. `wrap_strip(x, width)` wraps facet labels. |
| EC-05 | `build_cpv_lookup(cpv_table, code_col, label_col)` | Builds 2-digit (and finer) CPV lookup tables from a reference CSV. `attach_cpv_labels(df, ...)` joins `cpv_category` labels onto the data. |
| EC-06 | `year_breaks_rule(years, max_labels)` | Sensible integer year axis breaks. `NETWORK_YEAR_LIMITS` + `get_network_year_limits(country_code)` clip network years per country. |
| EC-07 | `summarise_market_size(df, value_col)` | Per-CPV-cluster: contract counts, total value, typical size. Plots: `plot_market_contract_counts()`, `plot_market_total_value()`, `plot_market_bubble()` (count × value bubble grid). |
| EC-08 | `compute_supplier_entry(df, ...)` | Per market×year: new vs repeat supplier shares (3-tier supplier ID). Plots: `plot_supplier_shares_heatmap()`, `plot_unique_suppliers_heatmap()`. Aggregate fallback when CPV absent: `compute_supplier_entry_aggregate()` + `plot_supplier_entry_aggregate()` (stacked bars). |
| EC-09 | `plot_buyer_supplier_networks(df, cpv_clusters, top_buyers, ncol, ...)` | Bipartite buyer–supplier network snapshots by year for chosen CPV clusters (tidygraph/ggraph). Heavy — called on demand from [APP-SV15]. |
| EC-10 | `add_relative_price(df)` | `rel_price = bid_priceusd / lot_estimatedpriceusd` with sanity trimming. Plots/tables: `plot_relative_price_density()`, `plot_relative_price_by_year()`, `top_markets_by_relative_price(df, n)` + `plot_top_markets_relative_price()`, `top_buyers_by_relative_price()` + `plot_top_buyers_relative_price()`. Internal themes `.rel_theme`, `.rp_fill`. |
| EC-11 | `.comp_lollipop(dat, ...)` | Generic single-bid lollipop builder (with `.comp_theme`, `.sb_col`). Wrappers: `plot_single_bid_overall()`, `_by_procedure()`, `_by_price()`, `_by_buyer_group()`, `top_markets_by_single_bid()` + `plot_single_bid_by_market()`, `plot_single_bid_market_procedure_price_top()`, `plot_top_buyers_single_bid()`. All compute mean single-bid % per grouping vs overall. |
| EC-12 | `run_economic_efficiency_pipeline(df, country_code, output_dir, cpv_lookup, cpv_digits, save_outputs, network_cpv_clusters, ...)` | **Orchestrator.** Normalises + enriches data, then runs EC-07…EC-11 (networks only for requested clusters). Returns list: `country_code, summary_stats, df` (enriched), market sizing (`market_summary, market_size_n/v/av`), supplier dynamics (`supplier_stats, suppliers_entrance, unique_supp, supplier_entry_agg`), `network_plots`, relative prices (`relative_price_data, rel_tot/year/10/buy, top_markets/top_buyers_relative_price`), competition (`single_bid_*`, `top_buyers_single_bid`), `cpv_cluster_legend`. Consumed as `econ$analysis`. |

---

## admin_utils.R  `[AD-xx]`

| Anchor | Function | Purpose |
|---|---|---|
| AD-01 | `app_thresholds_to_pipeline(app_thr)` | Converts the app's nested threshold list (`subm/dec × procedure × days/medium band`) to the flat list the pipeline expects (`subm_short_open`, …, `long_decision_days`). |
| AD-02 | `run_specs(reg_data, x_var, fe_set, cluster_set, controls_set, ...)` | Runs the full FE × cluster × controls grid of `feglm`/`feols` models of single-bidding on `x_var`; returns tidy specs table. Thin wrappers: `run_short_subm_specs()`, `run_long_dec_specs()`. |
| AD-03 | `compute_tender_days(df, from_col, to_col, new_col)` | Day difference between two date columns. `add_short_deadline_flags(df, days_col, thresholds, proc_col)` flags short submission periods per procedure (incl. optional medium band for open procedures). `add_long_decision_flag(df, days_col, threshold)` flags long decision periods. |
| AD-04 | `plot_days_hist_with_quartiles(data, days_var, facet_var, title, ...)` | Histogram of period lengths with quartile lines; optional faceting by procedure. Backbone of the submission/decision distribution charts. |
| AD-05 | `build_proc_share_data(df)` | Yearly procedure-type shares by value and count. `plot_proc_share_value()` / `plot_proc_share_count()` render stacked shares. |
| AD-06 | `admin_threshold_config`; `get_admin_thresholds(country_code)` | Country default thresholds (rows: DEFAULT, UY, BG, ID). Year windows: utils_shared [SH-12]. |
| AD-07 | `run_admin_efficiency_pipeline(df, country_code, output_dir, thresholds, run_regressions, ...)` | **Orchestrator.** Recodes procedures, computes day counts + flags, builds all admin plots, optionally runs the regression grids for short-submission and long-decision effects. Returns list incl.: `data, thresholds, thr_source, proc_share_data, tender_periods_*` (data), plots (`sh, p_count, combined_proc, subm*, buyer_short*, decp*, buyer_long*`), regression artefacts (`plot_short/long_reg, model_*_glm, best_row_*, is_robust_*, marginal_*, specs_*, sensitivity_*`), `summary_stats`. Consumed as `admin$analysis`. |

---

## integrity_utils.R  `[IN-xx]`  (anchor codes mirror the file's PART numbers)

| Anchor | Function | Purpose |
|---|---|---|
| IN-01 | `create_pipeline_config(country_code)` | Central config list (country, year windows per component, plot params). Year windows are defined in utils_shared [SH-12]; `safe_pipeline_config()` [APP-G23] wraps config building with a manual fallback. |
| IN-02 | `label_lookup`; `label_with_lookup(vec, lookup)` | Variable-name → display-label mapping for missing-value charts. |
| IN-03 | `PLOT_SIZES`, `standard_plot_theme(base_size)`, `white_bg()` | Shared integrity plot theme. |
| IN-04 | `validate_required_columns(df, cols, action_name)`; `check_data_quality(df, config)` | Column validation with clear messages; row/col/NA diagnostics. (`load_data`: utils_shared [SH-06].) |
| IN-05 | `standardize_missing_values(df)` ("", "-", "NA" → NA); `add_derived_variables(df)` (year, periods `submp`/`decp`, capital flag, …); `prepare_data(df)` — the standard prep chain run before every integrity analysis. (`add_buyer_group`: utils_shared [SH-09].) |
| IN-06 | `summarise_missing_shares(df, cols)`; `pivot_missing_long(df)`; `compute_org_missing(df)`; `compute_missing_correlations(df)` | Missing-share computations overall / long format / per organisation / correlations between missingness indicators. |
| IN-07 | `create_plot_saver(output_dir, config)`; `plot_missing_bar(...)`; `plot_missing_heatmap(...)` | Missingness bar chart (with labels) and generic x×y heatmap; closure-based PNG saver for batch mode. |
| IN-08 | `plot_missing_cooccurrence()` / `compute_cooccurrence_data()` / `plot_cooccurrence_from_data()` | Jaccard co-occurrence of missingness between fields. `run_little_mcar_test(df, max_cols)` — Little's MCAR chi-square. `run_mar_predictability(df, label_lookup, min_miss)` + `plot_mar_predictability()` — how well other fields predict each field's missingness (MAR evidence). |
| IN-09 | `extract_effect_fixest_vcov`, `get_default_vcov_menu`, `robustness_summary` | vcov-menu robustness helpers (specific to this module). Core spec helpers: utils_shared [SH-13]. |
| IN-10 | `pick_most_robust_model(results_df, ...)`; `model_diagnostics(specs_df, ...)` | Robust-spec selection and diagnostics (specific to this module). `pick_best_model`: utils_shared [SH-14]. |
| IN-11 | `pretty_model_name/controls_label/fe_label()`, `controls_note()`, `fe_counts_note()`, `make_groupvar_heatmap()`, `make_year_heatmap()` | Display labels/notes for regression panels; missingness heatmap builders by group / by year. |
| IN-12 | `analyze_missing_values(df, config, output_dir, save_plots)` | **Module.** Overall/by-buyer/by-procedure/by-year missingness + plots (dynamic heights). `run_missing_advanced_tests(df, config, output_dir)` — deferred MCAR/MAR battery. |
| IN-13 | `analyze_interoperability(df, config, output_dir)` | **Module.** Presence of linking identifiers/URLs across records. |
| IN-14 | `build_cpv_df()`; `build_concentration_yearly_plot()` (⚠ patched by [APP-G04]); `analyze_buyer_supplier_concentration()` (⚠ replaced by [APP-G03]); `run_singleb_specs(buyer_analysis_fe, config)`; `analyze_singleb_data(df, config)`; `analyze_competition(df, config, output_dir, run_regressions, save_plots)` | **Module.** Buyer/supplier concentration (HHI-style, yearly) and single-bid regression grid. |
| IN-15 | `detect_unusual_entries(cpv_data, config)`; `build_unusual_matrix()`; `build_network_graph_from_matrix(unusual_matrix, min_bidders, ...)`; `analyze_markets(df, config, output_dir)` | **Module.** Suppliers appearing in atypical markets → flow matrix + network graph ("Risky Profiles" tab). |
| IN-16 | `prepare_price_data(df, config)`; `run_relprice_specs(rel_price_data, config)`; `analyze_prices(df, config, output_dir)` | **Module.** Relative-price data prep + regression grid + plots. |
| IN-17 | `analyze_regional(df, config, output_dir)` | **Module.** NUTS/regional breakdowns (batch pipeline only; needs giscoR/eurostat/sf). |
| IN-18 | `log_summary_stats(df, config, output_dir)` | Summary statistics block (counts per year, entities, variables present). |
| IN-19 | `safely_run_module(module_fn, df, config, output_dir, ...)` | tryCatch wrapper so one failing module never kills the pipeline. |
| IN-20 | `ensure_output_directory(output_dir)` | Alias for `dir_ensure()`. |
| IN-21 | `run_integrity_pipeline(df, country_code, output_dir)` | **Full batch orchestrator** (all modules incl. markets/prices/regional, saves plots). The Shiny app instead uses `run_integrity_pipeline_fast_local()` [APP-G24], which defers the heavy modules. |

---

## global.R  `[APP-Gxx]`

| Anchor | Function / object | Purpose |
|---|---|---|
| G01 | *(options + libraries)* | `shiny.maxRequestSize = 1 GB`, unsanitised errors, warn=1; all packages. |
| G02 | *(source block)* | Sources the four utils files in the binding order (§2 of the guide) and defines no-op stubs so the app degrades gracefully if a file is missing. |
| G03 | `.absc_impl(df, config)` → assigned as `analyze_buyer_supplier_concentration` | Replacement concentration analysis using sequential **paired** ID tiers (masterid pair → id pair → name pair; a tier is used only if both sides are populated). Assigned into `.GlobalEnv` so `analyze_competition`'s dynamic lookup finds it. |
| G04 | *(patch)* `build_concentration_yearly_plot` | Wraps the integrity version to enforce buyer-ID priority. |
| G05 | `build_proc_share_data` (startup patch) | Wraps the admin version to use `.CANONICAL_RECODE` and a fallback price column. The recode itself is defined in utils_shared [SH-07]. |
| G06 | `detect_local_currency(df)`; `make_value_filter_widget(prices, ...)` | Currency label + median local/USD exchange rate from `bid_pricecurrency`/prices; builds the coarse-M-slider + precise-K-inputs value filter widget (radio hidden when local currency is USD/unknown). |
| G07 | `cpv_lookup_global` | Placeholder (NULL); labels come from `get_cpv_label()` [SH-03]. |
| G08 | `PROC_TYPE_LABELS` (+ method-note strings) | Canonical procedure labels used by admin filters/thresholds. |
| G09 | `compute_outlier_cutoff(x, method)`; `has_any_price_threshold(pt)`; `classify_supply(df)`; `proc_to_key(proc_label)` | IQR/percentile outlier cutoffs; price-threshold presence check; supply-type classification; procedure label → input-ID-safe key. |
| G10 | `detect_price_col(df, candidates)` | First price column that exists **and** has non-NA values (skips injected all-NA placeholders). |
| G11–G13 | `econ_filter_data()` / `admin_filter_data()` / `integrity_filter_data()` | Section filter engines: apply year/market/value/buyer-type/procedure filters (only non-NULL ones), honour `value_divisor`, and repair derived columns (numeric `single_bid`, ordered `price_bin`). Admin variant also takes `procedure_mapping`. |
| G14 | `get_filter_caption(filters_list)` | Caption string of active filters shown under charts. |
| G15 | `proc_threshold_ui(proc_id, proc_label, default_days, show_medium, ...)` | One procedure's threshold input block (short days + optional medium band). |
| G16 | `filter_bar_ui(section, tab)` | Collapsible filter box for a section/tab pair; generates IDs matching the server loops (`{section}_{tab}_{field}` convention). |
| G17 | `econ_regenerate_plots(filtered_data)` | Rebuilds the econ ggplot set from filtered data for Word/ZIP export. |
| G18 | `admin_build_word_plots(filtered_data, thresholds, global_proc_filter, subm_cutoffs, dec_cutoffs, price_thresholds)` | Rebuilds admin ggplots mirroring the renderPlotly logic (same cutoffs/filters the user sees). |
| G19 | `integ_regenerate_plots(filtered_data, country_code)` | Re-runs the fast integrity pipeline on filtered data for export. |
| G20 | `pa_theme(base_size)`; `post_process_plotly(p, ...)` | Global ggplot theme; plotly post-processor (font sizing across all axes/subplots, title sizing, margins). Pipe every rendered plotly through it. |
| G21 | `PA_EXPORT_FONTS`; `pa_prep_plotly_export(fig, vw, vh)`; `pa_save_plot_any(obj, file, width_in, height_in, gg_scale)` (returns TRUE with `attr("size_px")`); `pa_write_manifest(dir, label, rows)`; `pa_build_flow_matrix(unusual_mat)`; `pa_word_add_fig(d, p, cw, aspect, label, max_h, height_in, render_scale, missing_note)` | **Export standardization layer.** Print-ready font sizes; plotly export prep (exact canvas, honours render-set dimensions); universal ggplot/plotly PNG saver returning TRUE/FALSE + `attr("reason")`; MANIFEST.txt writer for ZIP bundles; Word figure inserter that shows a visible note instead of silently skipping missing figures. Used by all download/ZIP/Word paths. |
| G22 | `generate_econ_word_report()` / `generate_admin_word_report()` / `generate_integrity_word_report()` | Word report builders (same signature) with inline officer/flextable helpers; figures inserted via `pa_word_add_fig` [G21] — every expected figure appears as an image or an explanatory note. Coverage matches the tabs: econ adds contracts/value-by-year, the four plotly supplier charts and the networks section; admin adds value distribution + submission/decision share summaries; integrity renders the flow matrix via `pa_build_flow_matrix`, the network graph as the ggraph object it is, the concentration plotly via webshot2, and the regression figures with `render_scale = 1.5` so their text fits the page. The download handlers merge the stored plotly figs into the analysis list before calling the generators. |
| G23 | `safe_pipeline_config(country_code)` | Builds the integrity config via `create_pipeline_config()`, with a manual fallback construction if that fails for any reason. |
| G24 | `run_integrity_pipeline_fast_local(df, country_code, output_dir)` | The integrity runner the app actually calls: prepare → missing → interoperability → competition (no plot saving); markets/prices returned as empty placeholders filled by the deferred observers ([APP-SV32/35]). |

*(The visual design system is not R code: it lives in `www/styles.css`,
inlined by ui.R at startup.)*

## ui.R  `[APP-UIxx]`

`ui <- dashboardPage(...)` [UI01]; sidebar menu [UI02] registers each
`menuItem(tabName = ...)`; body `tabItem`s [UI03–UI19] hold the per-tab
layout: filter bar (`filter_bar_ui`), boxes with `plotlyOutput`/`DTOutput`,
per-figure download buttons, and (Setup) upload + country + threshold panels.
See the tab map in `DEVELOPER_GUIDE.md` §5.

## server.R  `[APP-SVxx]`

| Anchor | Contents |
|---|---|
| SV01 | Reactive state: `econ`, `admin`, `integ`, per-tab filter stores, mapping reactiveVals, `integ_filtered_data()` accessor. |
| SV02 | Server-scope admin helpers. |
| SV03 | `observeEvent(input$run_analysis)`: robust CSV read (separator sniffing, dup-col drop, date→character), `normalize_procurement_data`, country auto-detect, run econ pipeline (networks skipped), admin pipeline, fast integrity pipeline; populate reactive state; CPV `"99"` normalisation. |
| SV04 | Apply Thresholds (global + tab-local submission/decision buttons), live sync of `admin$global_proc_filter`, dynamic threshold inputs for national (unrecognised) procedure types. |
| SV05 | Admin "Run regressions" button → spec grids on demand (`admin$regression_done`). |
| SV06/SV09/SV28 | Filter widget generation loops (econ / admin / integrity) — per-tab unique input IDs + coarse-slider↔precise-input sync. |
| SV07/SV08 (+ SV28) | Apply/Reset observers per tab: read widgets → `*_filter_data()` → commit `filtered_data` (+ regenerate `filtered_analysis`). |
| SV10 | Shared plotly helpers: `.pa_fullscreen_btn` (CSS-overlay **expand button** on every chart — works in RStudio viewer/iframes where the Fullscreen API is blocked; relayouts the chart to fill the window and restores on exit/Esc), `pa_config()` toolbar config (expand, autoscale, hi-res camera PNG, white bg), `.save_fig_png()` standardized PNG export (wraps [G21] prep — fig-set dimensions win, print fonts), not-rendered-yet warning guard, `dl_plotly_fig()` handler factory. |
| SV11 | Data Overview outputs (value boxes, variable table, contracts/value by year). |
| SV12 | Market sizing: counts, value, bubble; download-ready figs stored. |
| SV13/SV14 | Supplier dynamics: min-size sliders, entry bubble grid, stability scatter (native plotly), new-vs-repeat trends (+ aggregate fallback), top-suppliers lollipop. |
| SV15 | Networks: status box, CPV picker from live data, on-demand generation with row-limit guards (segfault protection). |
| SV16 | Relative prices: shared `rel_price_data()` reactive feeding four plots. |
| SV17 | Competition: single-bid chart suite. |
| SV18/SV19 | Econ figure downloads (fresh render) and Word/ZIP report downloads. The ZIP handler holds the econ **figure manifest** (regenerated ggplots + stored plotly figs + networks) and writes MANIFEST.txt via [G21]. |
| SV20–SV22 | Admin outputs: procedure types (+ bunching analysis around thresholds); submission periods (+ share summary); decision periods (+ share summary). Cutoff reactives are shared between the distribution and buyer-level charts. |
| SV23/SV24 | Admin regression outputs; shared robustness builders (spec coefficient plot, spec detail table, verdict card) reused by both admin and integrity panels. |
| SV25/SV26/SV27 | Admin figure downloads; admin report downloads (ZIP holds the admin figure manifest incl. bunching, value-distribution and share-summary charts + MANIFEST.txt); export status boxes. |
| SV29–SV33 | Integrity outputs: deferred MCAR/MAR; missing-value charts + exact-display downloads; interoperability; deferred network/flow-matrix/concentration; deferred regressions + robustness panels. |
| SV34/SV35 | Integrity figure downloads (stored plotly figs; the two regression figures are ggplots read from `filtered_analysis$competition$singleb_plot` / `filtered_analysis$prices$rel_price_plot`); integrity Word/ZIP export (ZIP holds the integrity figure manifest with per-figure notes on which deferred analysis to run + MANIFEST.txt). |
