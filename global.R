# ============================================================================
# UNIFIED PROCUREMENT ANALYSIS APP — global.R (setup, analysis glue, exports)
# ============================================================================
# Shiny dashboard combining three analysis sections over one CSV upload:
#   • Economic Outcomes        (econ_out_utils.R)   — anchors APP-SV11..SV19
#   • Administrative Efficiency (admin_utils.R)     — anchors APP-SV20..SV27
#   • Integrity                (integrity_utils.R)  — anchors APP-SV28..SV35
# FILE LAYOUT (native Shiny multi-file convention):
#   global.R  — this file: options, sourcing, patches, filters, export/report
#               builders  ...................................  [APP-G01..G24]
#   ui.R      — dashboard layout and all tab definitions .....[APP-UI01..UI19]
#   server.R  — all reactive logic ..........................[APP-SV01..SV35]
#   www/styles.css — the entire design system (CSS)
# Anchor codes are unchanged; this TOC remains the master map across files.
# Run with: shiny::runApp() from this folder (Shiny auto-sources global.R,
# then ui.R and server.R). The folder must NOT contain a file named app.R —
# Shiny gives app.R precedence and would ignore these files.
# Full docs: README.md, DEVELOPER_GUIDE.md, FUNCTION_REFERENCE.md.
#
# NAVIGATION: every section below is tagged with a unique anchor code in
# square brackets, e.g. [SH-05]. Search (Ctrl+F / grep) for the code to
# jump straight to that section. Codes are stable; line numbers are not.
#
# TABLE OF CONTENTS
# -----------------
#   [APP-G01]  GLOBAL OPTIONS & LIBRARIES
#   [APP-G02]  SOURCE UTILITY FILES + FALLBACK STUBS  (order: shared → econ → integrity → admin; every name is defined once — only [APP-G03/G04] deliberately override)
#   [APP-G03]  OVERRIDE: analyze_buyer_supplier_concentration — 3-tier paired-ID version (replaces integrity_utils [IN-14])
#   [APP-G04]  PATCH: build_concentration_yearly_plot — enforce buyer-ID priority
#   [APP-G05]  PATCH: build_proc_share_data (canonical recode + price fallback)
#   [APP-G06]  CURRENCY HELPERS (detect_local_currency, make_value_filter_widget)
#   [APP-G07]  CPV LOOKUP GLOBAL (labels come from get_cpv_label [SH-03])
#   [APP-G08]  CONSTANTS — admin section (PROC_TYPE_LABELS, method notes, ...)
#   [APP-G09]  ADMIN HELPERS (compute_outlier_cutoff, classify_supply, proc_to_key)
#   [APP-G10]  COLUMN DETECTION (detect_price_col — skips all-NA placeholder cols)
#   [APP-G11]  ECON FILTER: econ_filter_data()
#   [APP-G12]  ADMIN FILTER: admin_filter_data()
#   [APP-G13]  INTEGRITY FILTER: integrity_filter_data()
#   [APP-G14]  get_filter_caption() — active-filter caption text
#   [APP-G15]  UI HELPER: proc_threshold_ui() — per-procedure threshold inputs
#   [APP-G16]  UI HELPER: filter_bar_ui() — per-section/tab filter widgets
#   [APP-G17]  ECON EXPORT PLOTS: econ_regenerate_plots()
#   [APP-G18]  ADMIN EXPORT PLOTS: admin_build_word_plots() — mirrors renderPlotly logic as ggplots for Word
#   [APP-G19]  INTEGRITY EXPORT PLOTS: integ_regenerate_plots()
#   [APP-G20]  GLOBAL PLOT THEME & PLOTLY POST-PROCESSING (pa_theme, post_process_plotly)
#   [APP-G21]  EXPORT STANDARDIZATION (pa_prep_plotly_export, pa_save_plot_any, pa_write_manifest, pa_word_add_fig)
#   [APP-G22]  WORD REPORT GENERATORS (generate_econ/admin/integrity_word_report)
#   [APP-G23]  safe_pipeline_config() — defensive config builder with a manual fallback
#   [APP-G24]  INTEGRITY PIPELINE RUNNER: run_integrity_pipeline_fast_local() — the version the app actually calls
#   [APP-UI01]  UI ROOT: dashboardPage
#   [APP-UI02]  SIDEBAR MENU — tab registry (tabName ↔ tabItem below)
#   [APP-UI03]  TAB UI: Setup (upload, country code, run button)
#   [APP-UI04]  TAB UI: Overview (econ headline boxes)
#   [APP-UI05]  TAB UI: Data Overview
#   [APP-UI06]  TAB UI: Market Sizing
#   [APP-UI07]  TAB UI: Supplier Dynamics
#   [APP-UI08]  TAB UI: Networks (on-demand)
#   [APP-UI09]  TAB UI: Relative Prices
#   [APP-UI10]  TAB UI: Competition (single-bid)
#   [APP-UI11]  TAB UI: Procedure Types (admin)
#   [APP-UI12]  TAB UI: Submission Periods (admin)
#   [APP-UI13]  TAB UI: Decision Periods (admin)
#   [APP-UI14]  TAB UI: Regression Analysis (admin)
#   [APP-UI15]  TAB UI: Missing Values (integrity)
#   [APP-UI16]  TAB UI: Interoperability (integrity)
#   [APP-UI17]  TAB UI: Risky Profiles (integrity — flow matrix + network graph)
#   [APP-UI18]  TAB UI: Regression / Prices (integrity)
#   [APP-UI19]  TAB UI: Export & Download
#   [APP-SV01]  REACTIVE STATE — econ / admin / integ + per-tab filter stores
#   [APP-SV02]  ADMIN HELPER FUNCTIONS (server scope)
#   [APP-SV03]  DATA UPLOAD & RUN — input$run_analysis: read CSV, normalize, detect country, run all 3 pipelines
#   [APP-SV04]  ADMIN — APPLY THRESHOLDS (global + per-tab subm/dec buttons, national proc-type UI)
#   [APP-SV05]  ADMIN — RE-RUN REGRESSIONS ON DEMAND
#   [APP-SV06]  FILTER UI GENERATION — ECON (per-tab widgets + slider sync)
#   [APP-SV07]  FILTER APPLICATION — ECON (apply/reset per tab)
#   [APP-SV08]  FILTER APPLICATION — ADMIN
#   [APP-SV09]  FILTER UI GENERATION — ADMIN
#   [APP-SV10]  SHARED PLOTLY HELPERS (toolbar config, PNG export, download guard)
#   [APP-SV11]  DATA OVERVIEW OUTPUTS (shared; reads econ$filtered_data)
#   [APP-SV12]  MARKET SIZING OUTPUTS
#   [APP-SV13]  SUPPLIER DYNAMICS OUTPUTS (sliders, bubble / stability / trend)
#   [APP-SV14]  TOP SUPPLIERS PLOT
#   [APP-SV15]  NETWORK OUTPUTS (on-demand generation, size guards)
#   [APP-SV16]  RELATIVE PRICE OUTPUTS (shared rel_price_data reactive)
#   [APP-SV17]  COMPETITION OUTPUTS (single-bid charts)
#   [APP-SV18]  ECON FIGURE DOWNLOAD HANDLERS (fresh render via webshot2)
#   [APP-SV19]  ECON REPORT DOWNLOADS (Word + ZIP)
#   [APP-SV20]  ADMIN PROCEDURE TYPES OUTPUTS (+ bunching analysis)
#   [APP-SV21]  ADMIN SUBMISSION PERIODS OUTPUTS (+ share summary chart)
#   [APP-SV22]  ADMIN DECISION PERIODS OUTPUTS (+ share summary chart)
#   [APP-SV23]  ADMIN REGRESSION OUTPUTS
#   [APP-SV24]  ROBUSTNESS CHECKS — shared spec-plot/table/verdict builders
#   [APP-SV25]  ADMIN FIGURE DOWNLOAD HANDLERS
#   [APP-SV26]  ADMIN REPORT DOWNLOADS (Word + ZIP)
#   [APP-SV27]  EXPORT STATUS BOXES
#   [APP-SV28]  INTEGRITY — FILTER UI GENERATION + APPLICATION
#   [APP-SV29]  INTEGRITY — DEFERRED: ADVANCED MISSINGNESS (MCAR / MAR)
#   [APP-SV30]  INTEGRITY — MISSING VALUES OUTPUTS (+ downloads)
#   [APP-SV31]  INTEGRITY — INTEROPERABILITY OUTPUT
#   [APP-SV32]  INTEGRITY — DEFERRED: NETWORK ANALYSIS (+ concentration plot)
#   [APP-SV33]  INTEGRITY — DEFERRED: REGRESSION ANALYSIS (+ robustness panels)
#   [APP-SV34]  INTEGRITY — FIGURE DOWNLOAD HANDLERS (stored plotly figs)
#   [APP-SV35]  INTEGRITY — EXPORT (Word report + ZIP)
# ============================================================================

# ========================================================================
# UNIFIED PROCUREMENT ANALYSIS APP
# ========================================================================
# Three analysis sections, each backed by its own utility module:
#   - Economic Outcomes          (econ_out_utils.R)  — markets, suppliers,
#                                  prices, competition
#   - Administrative Efficiency  (admin_utils.R)     — procedures, deadlines,
#                                  decision periods, regressions
#   - Integrity                  (integrity_utils.R) — missing data,
#                                  concentration, risky profiles, regressions
#
# A single CSV upload feeds all three pipelines.
# Filters are independent per section (and per tab within a section).
# ========================================================================


# [APP-G01] GLOBAL OPTIONS & LIBRARIES ───────────────────────────────────────
# options(expressions = 10000)  # deliberately NOT set — can cause stack overflow
options(shiny.maxRequestSize = 1000 * 1024^2)
options(shiny.sanitize.errors = FALSE)
options(warn = 1)

library(shiny)
library(shinydashboard)
library(shinyWidgets)
library(DT)
library(ggplot2)
library(dplyr)
library(tidyr)
library(data.table)
library(scales)
library(officer)
library(flextable)
library(rmarkdown)
library(plotly)
library(patchwork)
library(corrr)
library(tidytext)
library(fixest)
library(ggeffects)
library(igraph)
library(ggraph)
library(purrr)
library(ggrepel)
library(giscoR)
library(eurostat)
library(sf)
library(kableExtra)
library(zip)


# [APP-G02] SOURCE UTILITY FILES + FALLBACK STUBS  (order: shared → econ → integrity → admin; every name is defined once — only [APP-G03/G04] deliberately override) ────
# ── Source utility files ─────────────────────────────────────────────────
source("utils_shared.R")

econ_utils_loaded <- tryCatch({ source("econ_out_utils.R"); TRUE },
                              error = function(e) { warning("econ_out_utils.R not found: ", e$message); FALSE })
integrity_utils_loaded <- tryCatch({ source("integrity_utils.R"); TRUE },
                                   error = function(e) { warning("integrity_utils.R not found: ", e$message); FALSE })
admin_utils_loaded <- tryCatch({ source("admin_utils.R"); TRUE },
                               error = function(e) { warning("admin_utils.R not found: ", e$message); FALSE })

if (!econ_utils_loaded) {
  run_economic_efficiency_pipeline <- function(...) stop("utils_econ.R not loaded.")
  build_cpv_lookup <- function(...) NULL
}
if (!admin_utils_loaded) {
  run_admin_efficiency_pipeline <- function(...) stop("utils_admin.R not loaded.")
  get_admin_thresholds <- function(...) list(subm_short_open=30, subm_short_restricted=30,
                                             subm_short_negotiated=30, subm_medium_open_min=NA,
                                             subm_medium_open_max=NA, long_decision_days=60)
}
if (!integrity_utils_loaded) {
  # The app calls run_integrity_pipeline_fast_local() [APP-G24] directly.
  create_pipeline_config        <- function(cc) list(country_code = cc)
  prepare_data                  <- function(df, ...) df
  analyze_missing_values        <- function(...) NULL
  analyze_interoperability      <- function(...) NULL
  analyze_competition           <- function(...) NULL
  analyze_markets               <- function(...) NULL
  analyze_prices                <- function(...) NULL
  safely_run_module             <- function(fn, ...) tryCatch(fn(...), error = function(e) NULL)
}


# [APP-G03] OVERRIDE: analyze_buyer_supplier_concentration — 3-tier paired-ID version (replaces integrity_utils [IN-14]) ────
# ── Override analyze_buyer_supplier_concentration — three-tier paired IDs ──
# assign() into .GlobalEnv explicitly so analyze_competition's dynamic lookup
# always finds this version regardless of the environment this file is evaluated in.
.absc_impl <- function(df, config) {
  # Sequential paired-tier ID resolution:
  #   Tier 1: buyer_masterid + bidder_masterid  (preferred — harmonised IDs)
  #   Tier 2: buyer_id       + bidder_id        (raw administrative IDs)
  #   Tier 3: buyer_name     + bidder_name      (name strings — last resort)
  # A pair is only accepted when BOTH columns are present and non-trivially populated.
  id_pairs <- list(
    c("buyer_masterid", "bidder_masterid"),
    c("buyer_id",       "bidder_id"),
    c("buyer_name",     "bidder_name")
  )
  chosen_pair <- NULL
  for (pair in id_pairs) {
    if (all(pair %in% names(df)) &&
        any(!is.na(df[[pair[1]]]) & nchar(as.character(df[[pair[1]]])) > 0) &&
        any(!is.na(df[[pair[2]]]) & nchar(as.character(df[[pair[2]]])) > 0)) {
      chosen_pair <- pair
      break
    }
  }
  if (is.null(chosen_pair)) {
    message("analyze_buyer_supplier_concentration: no valid buyer/bidder column pair found ",
            "(checked buyer_masterid/bidder_masterid, buyer_id/bidder_id, buyer_name/bidder_name)")
    return(list())
  }
  buyer_col  <- chosen_pair[1]
  bidder_col <- chosen_pair[2]
  message("analyze_buyer_supplier_concentration: using columns '", buyer_col,
          "' (buyer) and '", bidder_col, "' (bidder)")
  
  # Best available price col — skip all-NA placeholders
  price_col <- NA_character_
  for (.c in c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice")) {
    if (.c %in% names(df) && any(!is.na(df[[.c]]))) { price_col <- .c; break }
  }
  
  results <- list()
  tryCatch({
    d <- df %>%
      dplyr::filter(!is.na(.data[[buyer_col]]),
                    nchar(as.character(.data[[buyer_col]])) > 0,
                    !is.na(.data[[bidder_col]]),
                    nchar(as.character(.data[[bidder_col]])) > 0,
                    !is.na(tender_year)) %>%
      dplyr::mutate(
        .buyer  = as.character(.data[[buyer_col]]),
        .bidder = as.character(.data[[bidder_col]]),
        .price  = if (!is.na(price_col)) as.numeric(.data[[price_col]]) else 1
      )
    
    if (nrow(d) == 0) return(list())
    
    conc_data <- d %>%
      dplyr::group_by(tender_year, .buyer, .bidder) %>%
      dplyr::summarise(
        n_contracts = dplyr::n(),
        total_spend = sum(.price, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::group_by(tender_year, .buyer) %>%
      dplyr::mutate(
        buyer_total_spend = sum(total_spend, na.rm = TRUE),
        n_suppliers       = dplyr::n(),
        buyer_conc        = dplyr::if_else(
          buyer_total_spend > 0, total_spend / buyer_total_spend, NA_real_)
      ) %>%
      dplyr::ungroup() %>%
      dplyr::filter(!is.na(buyer_conc))
    
    results$data <- conc_data
    
    # Buyer display name lookup
    nm_lkp <- d %>%
      dplyr::distinct(.buyer, .keep_all = TRUE) %>%
      dplyr::mutate(buyer_name = if ("buyer_name" %in% names(.)) as.character(buyer_name)
                    else .buyer) %>%
      dplyr::select(.buyer, buyer_name)
    
    top_yr <- conc_data %>%
      dplyr::group_by(tender_year, .buyer) %>%
      dplyr::summarise(
        max_conc        = max(buyer_conc, na.rm = TRUE),
        total_contracts = sum(n_contracts, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::filter(is.finite(max_conc)) %>%
      dplyr::left_join(nm_lkp, by = ".buyer") %>%
      dplyr::rename(buyer_masterid = .buyer)
    
    if (nrow(top_yr) == 0) return(results)
    
    yr_apps <- top_yr %>%
      dplyr::group_by(buyer_masterid) %>%
      dplyr::summarise(
        n_years_appeared = dplyr::n(),
        years_list       = paste(sort(unique(tender_year)), collapse = ", "),
        .groups = "drop"
      )
    
    results$yearly_data <- top_yr %>%
      dplyr::left_join(yr_apps, by = "buyer_masterid") %>%
      dplyr::mutate(
        repeated     = n_years_appeared > 1,
        # Three-tier priority: buyer_masterid > buyer_id > buyer_name.
        # buyer_masterid column already holds the best available identifier —
        # the tier was resolved above in chosen_pair selection.
        buyer_short  = substr(as.character(buyer_masterid), 1, 20),
        repeat_label = dplyr::if_else(repeated,
                                      "Appears in multiple years",
                                      "Single year only")
      )
  }, error = function(e)
    message("analyze_buyer_supplier_concentration error: ", e$message))
  
  results
}
# Bind into .GlobalEnv so analyze_competition() always finds it regardless of
# the local environment this file is being evaluated in.
assign("analyze_buyer_supplier_concentration", .absc_impl, envir = .GlobalEnv)


# [APP-G04] PATCH: build_concentration_yearly_plot — enforce buyer-ID priority ────
# ── Patch build_concentration_yearly_plot — enforce buyer ID priority ─────────
# Forces yearly_data buyer_name == buyer_masterid before calling .orig_conc_plot
# so the function's disp_name conditional always resolves to buyer_masterid
# (the best available ID: masterid > buyer_id > buyer_name, already resolved by .absc_impl).
if (exists("build_concentration_yearly_plot")) {
  .orig_conc_plot <- build_concentration_yearly_plot
  build_concentration_yearly_plot <- function(yearly_data, n_buyers = 15,
                                              min_contracts = 1, country = "") {
    if (is.null(yearly_data) || nrow(yearly_data) == 0) return(NULL)
    if (!"buyer_name" %in% names(yearly_data))
      yearly_data$buyer_name <- NA_character_
    yearly_data <- yearly_data %>%
      dplyr::mutate(
        # Three-tier buyer identifier priority: buyer_masterid > buyer_id > buyer_name.
        # buyer_masterid column already holds the best available ID (.absc_impl resolves
        # the tier before assigning). By setting buyer_name = buyer_masterid here we
        # force .orig_conc_plot's own disp_name conditional (which falls back to
        # buyer_masterid when buyer_name equals buyer_masterid) to always display
        # the primary ID — regardless of which version of integrity_utils.R is loaded.
        buyer_name = as.character(buyer_masterid)
      )
    tryCatch(.orig_conc_plot(yearly_data, n_buyers, min_contracts, country),
             error = function(e) NULL)
  }
}


# [APP-G05] PATCH: build_proc_share_data (canonical recode + price fallback) ────
# .CANONICAL_RECODE and the recode_procedure_type() delegate are defined in
# utils_shared.R [SH-07]. The build_proc_share_data patch below lives here
# (not in utils_shared) because it must wrap the admin_utils version AFTER
# that file has been sourced.

# Patch build_proc_share_data to use .CANONICAL_RECODE AND a fallback price col.
# Uses a fallback chain of price columns rather than a single hardcoded one.
if (exists("build_proc_share_data")) {
  build_proc_share_data <- function(df) {
    # Use first price col with actual non-NA data (skips injected all-NA placeholders)
    .price_candidates <- c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice")
    .pc <- NA_character_
    for (.c in .price_candidates) {
      if (.c %in% names(df) && any(!is.na(df[[.c]]))) { .pc <- .c; break }
    }
    df_proc <- df %>%
      dplyr::mutate(
        tender_proceduretype = .CANONICAL_RECODE(tender_proceduretype),
        tender_proceduretype = forcats::fct_explicit_na(
          as.factor(tender_proceduretype), na_level = "Missing value"))
    if (!is.na(.pc)) {
      df_proc %>%
        dplyr::group_by(tender_proceduretype) %>%
        dplyr::summarise(total_value  = sum(.data[[.pc]], na.rm = TRUE),
                         n_contracts  = dplyr::n(), .groups = "drop") %>%
        dplyr::mutate(share_value     = total_value / sum(total_value),
                      share_contracts = n_contracts / sum(n_contracts))
    } else {
      df_proc %>%
        dplyr::group_by(tender_proceduretype) %>%
        dplyr::summarise(total_value  = NA_real_,
                         n_contracts  = dplyr::n(), .groups = "drop") %>%
        dplyr::mutate(share_value     = NA_real_,
                      share_contracts = n_contracts / sum(n_contracts))
    }
  }
}


# [APP-G06] CURRENCY HELPERS (detect_local_currency, make_value_filter_widget) ────
# ── Currency helpers ──────────────────────────────────────────────────────
# The local currency is detected dynamically from the data (never hardcoded).
# .BGN_PER_USD kept for backward compatibility with any remaining references.
.BGN_PER_USD <- 1.85

#' Detect the local currency label and conversion rate from a data frame.
#' Returns list(label, rate) where rate = local / USD (i.e. multiply USD by rate).
#' Uses bid_pricecurrency for the label.  Rate is computed as median(bid_price / bid_priceusd)
#' when both columns are present and non-zero; defaults to 1 otherwise.
detect_local_currency <- function(df) {
  # Currency label from bid_pricecurrency
  label <- "Local Currency"
  if ("bid_pricecurrency" %in% names(df)) {
    vals <- df[["bid_pricecurrency"]]
    vals <- vals[!is.na(vals) & nchar(as.character(vals)) == 3]
    if (length(vals) > 0) {
      top <- names(sort(table(vals), decreasing = TRUE))[1]
      if (!is.null(top) && nchar(top) == 3) label <- toupper(top)
    }
  }
  # Exchange rate: median(local / usd) — only meaningful when bid_price is local
  rate <- 1
  if (label != "USD" &&
      all(c("bid_price", "bid_priceusd") %in% names(df))) {
    bp  <- as.numeric(df[["bid_price"]])
    bpu <- as.numeric(df[["bid_priceusd"]])
    ok  <- !is.na(bp) & !is.na(bpu) & bpu > 0 & bp > 0
    if (sum(ok) >= 10) {
      r <- stats::median(bp[ok] / bpu[ok], na.rm = TRUE)
      if (is.finite(r) && r > 0) rate <- r
    }
  }
  list(label = label, rate = rate)
}

# Shared value filter widget builder — used by econ, admin, integrity.
# Returns a tagList with a National Currency / USD radio and a 0-to-max slider.
# currency_input_id : shiny input ID for the radio  (e.g. "econ_value_currency")
# slider_input_id   : shiny input ID for the slider (e.g. "econ_value_range")
# prices            : numeric vector of raw USD values from the data
# local_currency    : list(label, rate) from detect_local_currency(); defaults to USD no-op
make_value_filter_widget <- function(prices, currency_input_id, slider_input_id,
                                     current_currency = "USD",
                                     local_currency   = list(label = "USD", rate = 1)) {
  prices <- prices[!is.na(prices) & is.finite(prices) & prices > 0]
  if (length(prices) == 0) return(NULL)
  
  loc_label <- local_currency$label %||% "USD"
  loc_rate  <- local_currency$rate  %||% 1
  # If local currency IS USD (or unknown), don't show the radio at all
  show_radio <- !is.null(loc_label) && loc_label != "USD"
  
  rate    <- if (current_currency == loc_label) loc_rate else 1
  p_cur   <- prices * rate
  max_p   <- quantile(p_cur, 0.99, na.rm = TRUE)
  cur_sym <- if (current_currency == loc_label) loc_label else "USD"
  
  # Slider in M for coarse dragging
  max_m <- ceiling(max_p / 1e6)
  max_k <- ceiling(max_p / 1e3)
  
  choices_vec <- if (show_radio) c("USD", loc_label) else "USD"
  
  tagList(
    if (show_radio)
      radioButtons(currency_input_id, NULL,
                   choices = choices_vec, selected = current_currency, inline = TRUE),
    # Coarse slider (millions)
    tags$div(style = "margin-bottom:4px;",
             tags$small(style = "color:#64748B;",
                        paste0("Drag to set rough range (", cur_sym, ", millions):")),
             sliderInput(paste0(slider_input_id, "_coarse"),
                         NULL,
                         min = 0, max = max(1, max_m), value = c(0, max(1, max_m)),
                         step = max(1, round(max_m / 50)),
                         ticks = FALSE, sep = ",",
                         pre = if (cur_sym == "USD") "$" else "",
                         post = "M")
    ),
    # Precise numeric inputs (thousands)
    tags$div(style = "margin-top:4px;",
             tags$small(style = "color:#64748B;",
                        paste0("Or enter exact values (", cur_sym, ", thousands):")),
             fluidRow(
               column(6,
                      numericInput(paste0(slider_input_id, "_min_k"),
                                   "From (K):", value = 0, min = 0, max = max_k, step = 1)),
               column(6,
                      numericInput(paste0(slider_input_id, "_max_k"),
                                   "To (K):",   value = max_k, min = 0, max = max_k, step = 1))
             )
    )
  )
}



# [APP-G07] CPV LOOKUP GLOBAL (labels come from get_cpv_label [SH-03]) ───────
# ── CPV code labels ───────────────────────────────────────────────────────
# CPV descriptions are hardcoded in CPV_DESCRIPTIONS (utils_shared.R).
# No external cpv_codes.csv file is needed. cpv_lookup_global stays NULL;
# get_cpv_label() is used directly everywhere market labels are required.
cpv_lookup_global <- NULL




# [APP-G08] CONSTANTS — admin section (PROC_TYPE_LABELS, method notes, ...) ────
# ========================================================================
# CONSTANTS (Admin section)
# ========================================================================

PROC_TYPE_LABELS <- c(
  "Open Procedure",
  "Restricted Procedure",
  "Negotiated with publications",
  "Negotiated without publications",
  "Negotiated (unspecified)",
  "Competitive Dialogue",
  "Innovation Partnership",
  "Direct Award",
  "Other"
)

CUTOFF_CHOICES <- c(
  "Tukey fence (Q3 + 1.5×IQR)" = "iqr",
  "75th percentile (Q3)"       = "p75",
  "80th percentile"            = "p80",
  "85th percentile"            = "p85",
  "90th percentile"            = "p90",
  "95th percentile"            = "p95",
  "99th percentile"            = "p99",
  "Mean"                       = "mean",
  "Median"                     = "median"
)

ALL_PROC_TYPES <- list(
  list(id = "open",        label = "Open Procedure",                  default = 30,  medium = TRUE,  med_min = 30, med_max = 60),
  list(id = "restricted",  label = "Restricted Procedure",            default = 30,  medium = TRUE,  med_min = NA, med_max = NA),
  list(id = "neg_pub",     label = "Negotiated with publications",    default = 30,  medium = TRUE,  med_min = NA, med_max = NA),
  list(id = "neg_nopub",   label = "Negotiated without publications", default = NA,  medium = FALSE, med_min = NA, med_max = NA),
  list(id = "neg_unspec",  label = "Negotiated (unspecified)",        default = NA,  medium = FALSE, med_min = NA, med_max = NA),
  list(id = "competitive", label = "Competitive Dialogue",            default = NA,  medium = FALSE, med_min = NA, med_max = NA),
  list(id = "innov",       label = "Innovation Partnership",          default = NA,  medium = FALSE, med_min = NA, med_max = NA),
  list(id = "direct",      label = "Direct Award",                   default = NA,  medium = FALSE, med_min = NA, med_max = NA),
  list(id = "other",       label = "Other",                          default = NA,  medium = FALSE, med_min = NA, med_max = NA)
)

ALL_DEC_PROC_TYPES <- list(
  list(id = "dec_open",        label = "Open Procedure",                  default = 60),
  list(id = "dec_restricted",  label = "Restricted Procedure",            default = 60),
  list(id = "dec_neg_pub",     label = "Negotiated with publications",    default = 60),
  list(id = "dec_neg_nopub",   label = "Negotiated without publications", default = NA),
  list(id = "dec_neg_unspec",  label = "Negotiated (unspecified)",        default = NA),
  list(id = "dec_competitive", label = "Competitive Dialogue",            default = NA),
  list(id = "dec_innov",       label = "Innovation Partnership",          default = NA),
  list(id = "dec_direct",      label = "Direct Award",                   default = NA),
  list(id = "dec_other",       label = "Other",                          default = NA)
)

TUKEY_EXPLANATION <- div(
  class = "alert alert-info",
  style = "font-size:12px; padding:8px 12px; margin-top:6px;",
  icon("info-circle"),
  tags$strong(" What is the Tukey fence?"),
  " The Tukey fence (also called the 1.5×IQR rule) flags values as outliers when they fall above",
  tags$strong(" Q3 + 1.5 × IQR"), ", where Q3 is the 75th percentile and IQR = Q3 − Q1.",
  " It is a robust, data-driven method that adapts to the spread of each dataset",
  " without assuming a normal distribution."
)


# [APP-G09] ADMIN HELPERS (compute_outlier_cutoff, classify_supply, proc_to_key) ────
# ========================================================================
# ADMIN HELPER FUNCTIONS
# ========================================================================

compute_outlier_cutoff <- function(x, method = "iqr") {
  x <- x[!is.na(x) & is.finite(x)]
  if (length(x) < 10) return(NA_real_)
  switch(method,
         iqr    = { q <- quantile(x, c(0.25, 0.75)); q[2] + 1.5 * (q[2] - q[1]) },
         p75 = quantile(x, 0.75), p80 = quantile(x, 0.80), p85 = quantile(x, 0.85),
         p90 = quantile(x, 0.90), p95 = quantile(x, 0.95), p99 = quantile(x, 0.99),
         mean = mean(x), median = median(x),
         quantile(x, 0.75))
}

has_any_price_threshold <- function(pt) {
  !is.null(pt) && any(sapply(pt, function(proc)
    any(sapply(proc, function(v) !is.null(v) && !is.na(v) && is.finite(v) && v > 0))))
}

classify_supply <- function(df) {
  if (!"tender_supplytype" %in% names(df)) return(rep("Goods", nrow(df)))
  dplyr::case_when(
    grepl("WORK",        toupper(as.character(df$tender_supplytype))) ~ "Works",
    grepl("SERV",        toupper(as.character(df$tender_supplytype))) ~ "Services",
    grepl("GOODS|SUPPL", toupper(as.character(df$tender_supplytype))) ~ "Goods",
    TRUE ~ "Goods"
  )
}

.PROC_LABEL_TO_KEY <- c(
  "Open Procedure"                  = "open",
  "Restricted Procedure"            = "restricted",
  "Negotiated with publications"    = "neg_pub",
  "Negotiated without publications" = "neg_nopub",
  "Negotiated (unspecified)"        = "neg_unspec",
  "Competitive Dialogue"            = "competitive",
  "Innovation Partnership"          = "innov",
  "Direct Award"                    = "direct"
)
proc_to_key <- function(proc_label) {
  key <- .PROC_LABEL_TO_KEY[as.character(proc_label)]
  key[is.na(key)] <- "other"
  unname(key)
}


# [APP-G10] COLUMN DETECTION (detect_price_col — skips all-NA placeholder cols) ────
# ── Column detection helpers ─────────────────────────────────────────────
.PRICE_COLS_PRIORITY  <- c("bid_priceusd","lot_estimatedpriceusd","tender_finalprice","lot_estimatedprice","bid_price")
.PRICE_COLS_ADMIN     <- c("bid_priceusd","bid_price")
.PRICE_COLS_SUPP      <- c("bid_priceusd","lot_estimatedpriceusd","lot_estimatedprice","bid_price")

detect_price_col <- function(df, candidates = .PRICE_COLS_PRIORITY) {
  # Return the first candidate column that (a) exists AND (b) has at least one non-NA value.
  # This prevents injected all-NA placeholders (bid_priceusd <- NA_real_) from blocking
  # real price columns further down the priority list.
  for (col in candidates) {
    if (col %in% names(df) && any(!is.na(df[[col]]))) return(col)
  }
  NA_character_
}



# [APP-G11] ECON FILTER: econ_filter_data() ──────────────────────────────────
# ========================================================================
# ECON FILTER DATA
# ========================================================================

econ_filter_data <- function(df, year_range = NULL, market = NULL, value_range = NULL,
                             buyer_type = NULL, procedure_type = NULL, value_divisor = 1,
                             buyer_mapping = NULL, procedure_mapping = NULL) {
  filtered <- df
  
  if (!is.null(year_range) && "tender_year" %in% names(df))
    filtered <- filtered %>% filter(tender_year >= year_range[1] & tender_year <= year_range[2])
  
  if (!is.null(market) && length(market) > 0 && "cpv_cluster" %in% names(df))
    filtered <- filtered %>% filter(cpv_cluster %in% market)
  
  if (!is.null(value_range) && !is.null(value_divisor)) {
    price_col_f <- detect_price_col(df, c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"))
    if (!is.na(price_col_f)) {
      actual_min <- value_range[1] * value_divisor
      actual_max <- value_range[2] * value_divisor
      filtered <- filtered %>%
        filter(!is.na(.data[[price_col_f]])) %>%
        filter(.data[[price_col_f]] >= actual_min & .data[[price_col_f]] <= actual_max)
    }
  }
  
  if (!is.null(buyer_type) && length(buyer_type) > 0 &&
      "buyer_buyertype" %in% names(df)) {
    if (!is.null(buyer_mapping)) {
      raw_values <- buyer_mapping[buyer_mapping$group %in% buyer_type, "raw"]
      filtered <- filtered %>% filter(buyer_buyertype %in% raw_values)
    } else {
      filtered <- filtered %>% filter(buyer_buyertype %in% buyer_type)
    }
  }
  
  if (!is.null(procedure_type) && length(procedure_type) > 0 &&
      "tender_proceduretype" %in% names(df)) {
    if (!is.null(procedure_mapping)) {
      raw_values <- procedure_mapping[procedure_mapping$cleaned %in% procedure_type, "raw"]
      filtered <- filtered %>% filter(tender_proceduretype %in% raw_values)
    } else {
      filtered <- filtered %>% filter(tender_proceduretype %in% procedure_type)
    }
  }
  # Ensure single_bid stays numeric after any join/filter operations
  if ("single_bid" %in% names(filtered))
    filtered$single_bid <- as.numeric(as.character(filtered$single_bid))
  # Ensure price_bin stays ordered factor
  if ("price_bin" %in% names(filtered) && !is.ordered(filtered$price_bin))
    filtered$price_bin <- factor(filtered$price_bin, ordered = TRUE)
  return(filtered)
}


# [APP-G12] ADMIN FILTER: admin_filter_data() ────────────────────────────────
# ========================================================================
# ADMIN FILTER DATA
# ========================================================================

admin_filter_data <- function(df, year_range = NULL, market = NULL, value_range = NULL,
                              buyer_type = NULL, procedure_type = NULL, value_divisor = 1,
                              procedure_mapping = NULL) {
  filtered_df <- df
  
  if (!is.null(year_range)) {
    year_col <- if ("tender_year" %in% names(df)) "tender_year"
    else if ("year" %in% names(df)) "year"
    else if ("cal_year" %in% names(df)) "cal_year" else NULL
    if (!is.null(year_col))
      filtered_df <- filtered_df %>%
        filter(.data[[year_col]] >= year_range[1] & .data[[year_col]] <= year_range[2])
  }
  
  if (!is.null(market) && length(market) > 0 && "lot_productcode" %in% names(df))
    filtered_df <- filtered_df %>%
      mutate(cpv_2dig = substr(lot_productcode, 1, 2)) %>%
      filter(cpv_2dig %in% market) %>%
      select(-cpv_2dig)
  
  if (!is.null(value_range) && !is.null(value_divisor)) {
    price_col <- detect_price_col(df, c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"))
    if (!is.na(price_col)) {
      actual_min <- value_range[1] * value_divisor
      actual_max <- value_range[2] * value_divisor
      filtered_df <- filtered_df %>%
        filter(!is.na(.data[[price_col]])) %>%
        filter(.data[[price_col]] >= actual_min & .data[[price_col]] <= actual_max)
    }
  }
  
  if (!is.null(buyer_type) && length(buyer_type) > 0 &&
      "buyer_buyertype" %in% names(df))
    filtered_df <- filtered_df %>%
      mutate(buyer_group = add_buyer_group(buyer_buyertype)) %>%
      filter(as.character(buyer_group) %in% buyer_type) %>%
      select(-buyer_group)
  
  if (!is.null(procedure_type) && length(procedure_type) > 0 &&
      "tender_proceduretype" %in% names(df)) {
    if (!is.null(procedure_mapping)) {
      raw_values <- procedure_mapping[procedure_mapping$cleaned %in% procedure_type, "raw"]
      filtered_df <- filtered_df %>% filter(tender_proceduretype %in% raw_values)
    } else {
      # fallback: match on recoded column directly
      filtered_df <- filtered_df %>%
        filter(recode_procedure_type(tender_proceduretype) %in% procedure_type)
    }
  }
  
  return(filtered_df)
}


# [APP-G13] INTEGRITY FILTER: integrity_filter_data() ────────────────────────
# ========================================================================
# INTEGRITY FILTER DATA
# ========================================================================

integrity_filter_data <- function(df, year_range = NULL, market = NULL, value_range = NULL,
                                  buyer_type = NULL, procedure_type = NULL, value_divisor = 1) {
  filtered_df <- df
  if (!is.null(year_range)) {
    year_col <- if ("tender_year" %in% names(df)) "tender_year"
    else if ("year" %in% names(df)) "year"
    else if ("cal_year" %in% names(df)) "cal_year" else NULL
    if (!is.null(year_col))
      filtered_df <- filtered_df %>%
        dplyr::filter(.data[[year_col]] >= year_range[1] & .data[[year_col]] <= year_range[2])
  }
  if (!is.null(market) && length(market) > 0 && "lot_productcode" %in% names(df))
    filtered_df <- filtered_df %>%
      dplyr::mutate(cpv_2dig = substr(lot_productcode, 1, 2)) %>%
      dplyr::filter(cpv_2dig %in% market) %>%
      dplyr::select(-cpv_2dig)
  if (!is.null(value_range) && !is.null(value_divisor)) {
    price_col <- detect_price_col(df, c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"))
    if (!is.na(price_col)) {
      filtered_df <- filtered_df %>%
        dplyr::filter(!is.na(.data[[price_col]])) %>%
        dplyr::filter(.data[[price_col]] >= value_range[1] * value_divisor &
                        .data[[price_col]] <= value_range[2] * value_divisor)
    }
  }
  if (!is.null(buyer_type) && length(buyer_type) > 0 &&
      "buyer_buyertype" %in% names(df))
    filtered_df <- filtered_df %>%
      dplyr::mutate(buyer_group = add_buyer_group(buyer_buyertype)) %>%
      dplyr::filter(as.character(buyer_group) %in% buyer_type) %>%
      dplyr::select(-buyer_group)
  if (!is.null(procedure_type) && length(procedure_type) > 0 &&
      "tender_proceduretype" %in% names(df))
    filtered_df <- filtered_df %>%
      dplyr::filter(recode_procedure_type(tender_proceduretype) %in% procedure_type)
  return(filtered_df)
}


# [APP-G14] get_filter_caption() — active-filter caption text ────────────────
get_filter_caption <- function(filters_list) {
  if (is.null(filters_list)) return("")
  desc <- get_filter_description(filters_list)
  if (desc == "No filters applied") return("")
  paste("Filters Applied:", desc)
}


# [APP-G15] UI HELPER: proc_threshold_ui() — per-procedure threshold inputs ────
# ========================================================================
# UI HELPER: PROC THRESHOLD BLOCK
# ========================================================================

proc_threshold_ui <- function(proc_id, proc_label, default_days,
                              show_medium = FALSE, med_min = NA, med_max = NA,
                              is_decision = FALSE,
                              show_short = FALSE, default_short = NA) {
  field_id_no_thr   <- paste0("no_thr_",         proc_id)
  field_id_days     <- paste0("thr_days_",        proc_id)
  field_id_outlier  <- paste0("outlier_method_",  proc_id)
  field_id_med_min  <- paste0("thr_med_min_",     proc_id)
  field_id_med_max  <- paste0("thr_med_max_",     proc_id)
  field_id_no_med   <- paste0("no_medium_",       proc_id)
  field_id_short    <- paste0("dec_short_days_",  gsub("^dec_", "", proc_id))
  
  tagList(
    h5(style = "margin-top:10px; font-weight:bold; color:#2c3e50;", proc_label),
    checkboxInput(field_id_no_thr, "No legal threshold (derive statistically)", value = is.na(default_days)),
    conditionalPanel(
      condition = paste0("!input.", field_id_no_thr),
      numericInput(field_id_days,
                   if (is_decision) "Too-long threshold (days)" else "Short threshold (days)",
                   value = if (is.na(default_days)) 30 else default_days, min = 1, step = 1)
    ),
    conditionalPanel(
      condition = paste0("input.", field_id_no_thr),
      selectInput(field_id_outlier, "Derive cutoff using:", choices = CUTOFF_CHOICES, selected = "iqr")
    ),
    if (show_short && is_decision) tagList(
      hr(style = "margin: 4px 0;"),
      numericInput(field_id_short, "Too-short threshold (days, optional):",
                   value = if (is.na(default_short)) NA else default_short, min = 0, step = 1)
    ),
    if (show_medium) tagList(
      hr(style = "margin: 6px 0;"),
      checkboxInput(field_id_no_med, "No medium band", value = TRUE),
      conditionalPanel(
        condition = paste0("!input.", field_id_no_med),
        fluidRow(
          column(6, numericInput(field_id_med_min, "Medium band min (days)",
                                 value = if (is.na(med_min)) 30 else med_min, min = 1, step = 1)),
          column(6, numericInput(field_id_med_max, "Medium band max (days)",
                                 value = if (is.na(med_max)) 60 else med_max, min = 1, step = 1))
        )
      )
    )
  )
}


# [APP-G16] UI HELPER: filter_bar_ui() — per-section/tab filter widgets ──────
# ========================================================================
# UI HELPER: FILTER BAR (namespaced with prefix)
# ========================================================================

# filter_bar_ui: section = "econ" or "admin", tab = short tab name e.g. "market", "proc"
# Generates IDs that match server registrations:
#   econ_year_filter_market, econ_apply_filters_market, etc.
filter_bar_ui <- function(section, tab) {
  p <- paste0(section, "_")    # prefix: "econ_" or "admin_"
  tagList(
    fluidRow(
      column(2, uiOutput(paste0(p, "year_filter_",           tab))),
      column(2, uiOutput(paste0(p, "market_filter_",         tab))),
      column(2, uiOutput(paste0(p, "value_filter_",          tab))),
      column(3, uiOutput(paste0(p, "buyer_type_filter_",     tab))),
      column(3, uiOutput(paste0(p, "procedure_type_filter_", tab)))
    ),
    fluidRow(
      column(12,
             actionButton(paste0(p, "apply_filters_", tab), "Apply Filters",
                          icon = icon("filter"), class = "btn-primary"),
             actionButton(paste0(p, "reset_filters_",  tab), "Reset Filters",
                          icon = icon("undo"),   class = "btn-warning"),
             textOutput(paste0(p, "filter_status_", tab), inline = TRUE)
      )
    )
  )
}


# [APP-G17] ECON EXPORT PLOTS: econ_regenerate_plots() ───────────────────────
# ========================================================================
# ECON: REGENERATE PLOTS FOR EXPORT
# ========================================================================

econ_regenerate_plots <- function(filtered_data) {
  plots <- list()
  tryCatch({
    price_var <- detect_price_col(filtered_data)
    market_summary <- summarise_market_size(filtered_data, value_col = price_var)
    plots$market_size_n  <- plot_market_contract_counts(market_summary)
    plots$market_size_v  <- plot_market_total_value(market_summary)
    plots$market_size_av <- plot_market_bubble(market_summary)
    # Supplier entry: three-tier ID resolution (masterid → id → name) + CPV-aware branching
    sup_id_regen <- intersect(c("bidder_masterid", "bidder_id", "bidder_name"), names(filtered_data))[1]
    if (!is.na(sup_id_regen) && "tender_year" %in% names(filtered_data)) {
      has_cpv_regen <- "cpv_cluster" %in% names(filtered_data) &&
        any(!is.na(filtered_data$cpv_cluster))
      if (has_cpv_regen) {
        # Market-faceted path (heatmap per CPV market)
        supplier_stats <- tryCatch(
          compute_supplier_entry(filtered_data, supplier_id_col = sup_id_regen),
          error = function(e) NULL)
        plots$supplier_stats     <- supplier_stats
        plots$suppliers_entrance <- if (!is.null(supplier_stats))
          tryCatch(plot_supplier_shares_heatmap(supplier_stats), error = function(e) NULL)
        else NULL
        plots$unique_supp        <- tryCatch(
          plot_unique_suppliers_heatmap(filtered_data, supplier_id_col = sup_id_regen),
          error = function(e) NULL)
      } else {
        # Aggregate path for datasets without CPV market categories
        agg_stats_regen <- tryCatch(
          compute_supplier_entry_aggregate(filtered_data, supplier_id_col = sup_id_regen),
          error = function(e) NULL)
        plots$supplier_entry_agg <- if (!is.null(agg_stats_regen))
          tryCatch(plot_supplier_entry_aggregate(agg_stats_regen, supplier_id_col = sup_id_regen),
                   error = function(e) NULL)
        else NULL
      }
    }
    if (all(c("bid_price","lot_estimatedprice") %in% names(filtered_data))) {
      rp <- filtered_data %>% add_relative_price()
      # rel_tot: use custom density logic so percentages are correct (not old util)
      plots$rel_tot <- tryCatch({
        rp_col <- "relative_price"
        if (rp_col %in% names(rp)) {
          v <- rp[[rp_col]]; v <- v[!is.na(v)&is.finite(v)&v>0]; n_total <- length(v)
          if (n_total > 5) {
            n_under <- sum(v<0.999); n_at <- sum(v>=0.999&v<=1.001); n_over <- sum(v>1.001)
            pu <- round(n_under/n_total*100,1); pa2 <- round(n_at/n_total*100,1)
            po <- round(n_over/n_total*100,1) + (100-(round(n_under/n_total*100,1)+round(n_at/n_total*100,1)+round(n_over/n_total*100,1)))
            med_rp <- median(v); xr <- quantile(v,c(0.005,0.995))
            dens <- density(v,from=max(0,xr[1]),to=xr[2],n=512)
            df_d <- data.frame(x=dens$x,y=dens$y)
            stxt <- paste0("Under budget: ",pu,"% | At budget: ",pa2,"% | Over budget: ",po,"%  (n=",scales::comma(n_total),")")
            plotly::plot_ly() %>%
              plotly::add_trace(data=df_d%>%dplyr::filter(x<=1),x=~x,y=~y,type="scatter",mode="none",fill="tozeroy",fillcolor="rgba(0,105,180,0.25)",name="Under budget",hoverinfo="skip") %>%
              plotly::add_trace(data=df_d%>%dplyr::filter(x>=1),x=~x,y=~y,type="scatter",mode="none",fill="tozeroy",fillcolor="rgba(180,0,0,0.20)",name="Over budget",hoverinfo="skip") %>%
              plotly::add_trace(data=df_d,x=~x,y=~y,type="scatter",mode="lines",line=list(color="#334155",width=2),name="Density",hoverinfo="text",text=stxt) %>%
              plotly::layout(xaxis=list(title="Relative price"),yaxis=list(title="Density"),
                             shapes=list(list(type="line",x0=1,x1=1,y0=0,y1=1,yref="paper",line=list(color="#888",width=1.5,dash="dash")),
                                         list(type="line",x0=med_rp,x1=med_rp,y0=0,y1=1,yref="paper",line=list(color="#D97706",width=1.5,dash="dot"))),
                             annotations=list(
                               list(x=(xr[1]+1)/2,y=0.5,yref="paper",xanchor="center",text=paste0("<b>",pu,"%</b><br>under budget"),showarrow=FALSE,font=list(size=11,color="#0069B4")),
                               list(x=1.02,y=0.5,yref="paper",xanchor="left",text=paste0("<b>",pa2,"%</b><br>at budget"),showarrow=FALSE,font=list(size=11,color="#475569")),
                               list(x=(1+xr[2])/2,y=0.5,yref="paper",xanchor="center",text=paste0("<b>",po,"%</b><br>over budget"),showarrow=FALSE,font=list(size=11,color="#B40000"))),
                             paper_bgcolor="#ffffff",plot_bgcolor="#ffffff",
                             legend=list(orientation="h",y=-0.15),margin=list(l=60,r=20,t=20,b=60))
          }
        }
      }, error=function(e) NULL)
      if ("tender_year" %in% names(rp)) plots$rel_year <- plot_relative_price_by_year(rp)
      if ("cpv_cluster" %in% names(rp) || "cpv_category" %in% names(rp)) {
        # Apply same get_cpv_label relabelling as the screen render
        if ("cpv_cluster" %in% names(rp))
          rp <- rp %>% dplyr::mutate(cpv_category = get_cpv_label(cpv_cluster))
        top_m <- top_markets_by_relative_price(rp, n=10)
        plots$rel_10 <- tryCatch(plot_top_markets_relative_price(rp, top_m), error=function(e) NULL)
      }
      if ("buyer_name" %in% names(rp)) {
        top_b <- top_buyers_by_relative_price(rp, min_contracts=10, n=20)
        if (nrow(top_b) > 0) plots$rel_buy <- plot_top_buyers_relative_price(top_b, label_max_chars=30)
      }
    }
    plots$single_bid_overall          <- tryCatch(plot_single_bid_overall(filtered_data),          error = function(e) NULL)
    plots$single_bid_by_procedure     <- tryCatch(plot_single_bid_by_procedure(filtered_data),     error = function(e) NULL)
    plots$single_bid_by_price         <- tryCatch(plot_single_bid_by_price(filtered_data),         error = function(e) NULL)
    plots$single_bid_by_buyer_group   <- tryCatch(plot_single_bid_by_buyer_group(filtered_data),   error = function(e) NULL)
    plots$single_bid_by_market        <- tryCatch(plot_single_bid_by_market(filtered_data),        error = function(e) NULL)
    plots$top_buyers_single_bid       <- tryCatch(plot_top_buyers_single_bid(filtered_data,
                                                                             buyer_id_col = "buyer_masterid",
                                                                             top_n = 20, min_tenders = 30),                error = function(e) NULL)
  }, error = function(e) message("Plot regen error: ", e$message))
  return(plots)
}


# [APP-G18] ADMIN EXPORT PLOTS: admin_build_word_plots() — mirrors renderPlotly logic as ggplots for Word ────
admin_build_word_plots <- function(filtered_data, thresholds, global_proc_filter, subm_cutoffs, dec_cutoffs, price_thresholds = list()) {
  # Build ggplot objects using the SAME logic as the renderPlotly blocks.
  # Arguments mirror the server-scope reactives so the caller can pass live values.
  plots <- list()
  
  tryCatch({
    # ── Helpers ────────────────────────────────────────────────────────
    apply_proc_filter <- function(df) {
      if (is.null(global_proc_filter) || length(global_proc_filter) == 0) return(df)
      pr <- recode_procedure_type(df$tender_proceduretype)
      df[!is.na(pr) & pr %in% global_proc_filter, , drop = FALSE]
    }
    
    # ── Procedure shares ───────────────────────────────────────────────
    plot_data <- tryCatch(build_proc_share_data(filtered_data), error = function(e) NULL)
    if (!is.null(plot_data)) {
      plots$sh <- tryCatch(
        ggplot2::ggplot(plot_data,
                        ggplot2::aes(x = stats::reorder(tender_proceduretype, share_value), y = share_value)) +
          ggplot2::geom_col(fill = "#3c8dbc", width = 0.6) +
          ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                                      expand = ggplot2::expansion(mult = c(0, 0.4))) +
          ggplot2::coord_flip() +
          ggplot2::labs( x = NULL, y = "Share of total value") +
          pa_theme(),
        error = function(e) NULL)
      plots$p_count <- tryCatch(
        ggplot2::ggplot(plot_data,
                        ggplot2::aes(x = stats::reorder(tender_proceduretype, share_value), y = share_contracts)) +
          ggplot2::geom_col(fill = "#3c8dbc", width = 0.6) +
          ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                                      expand = ggplot2::expansion(mult = c(0, 0.4))) +
          ggplot2::coord_flip() +
          ggplot2::labs( x = NULL, y = "Share of contracts") +
          pa_theme(),
        error = function(e) NULL)
    }
    
    # ── Submission period distribution ─────────────────────────────────
    tp_open <- tryCatch(
      compute_tender_days(filtered_data,
                          tender_publications_firstcallfortenderdate,
                          tender_biddeadline, tender_days_open),
      error = function(e) NULL)
    if (!is.null(tp_open)) {
      days_open <- tp_open$tender_days_open[!is.na(tp_open$tender_days_open) &
                                              tp_open$tender_days_open >= 0 &
                                              tp_open$tender_days_open <= 365]
      if (length(days_open) > 1) {
        q_open  <- quantile(days_open, probs = c(0.25, 0.5, 0.75), na.rm = TRUE)
        mu_open <- mean(days_open, na.rm = TRUE)
        plots$subm <- tryCatch(
          ggplot2::ggplot(data.frame(days = days_open), ggplot2::aes(x = days)) +
            ggplot2::geom_histogram(binwidth = 5, fill = PA_NORMAL, colour = "white") +
            ggplot2::geom_vline(xintercept = q_open,
                                colour = c(PA_Q_Q1,PA_Q_MEDIAN,PA_Q_Q1),
                                linetype = c("dashed","solid","dashed"), linewidth = 1) +
            ggplot2::geom_vline(xintercept = mu_open, colour = PA_Q_MEAN,
                                linetype = "dotted", linewidth = 1) +
            ggplot2::coord_cartesian(xlim = c(0, 365)) +
            ggplot2::labs(
              x = "Days from call opening to bid deadline",
              y = "Number of contracts") +
            pa_theme(),
          error = function(e) NULL)
      }
      
      # ── Submission by procedure type ─────────────────────────────────
      tp_open_proc <- apply_proc_filter(tp_open) %>%
        dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
        dplyr::filter(!is.na(tender_proceduretype)) %>%
        dplyr::filter(tender_days_open >= 0, tender_days_open <= 365)
      
      if (nrow(tp_open_proc) > 0) {
        ql <- tp_open_proc %>%
          dplyr::group_by(tender_proceduretype) %>%
          dplyr::filter(dplyr::n() >= 5) %>%
          dplyr::summarise(Q1 = quantile(tender_days_open, 0.25, na.rm = TRUE),
                           Median = quantile(tender_days_open, 0.50, na.rm = TRUE),
                           Q3 = quantile(tender_days_open, 0.75, na.rm = TRUE),
                           Mean = mean(tender_days_open, na.rm = TRUE), .groups = "drop") %>%
          tidyr::pivot_longer(c(Q1, Median, Q3, Mean), names_to = "stat", values_to = "xintercept")
        plots$subm_proc_facet_q <- tryCatch(
          ggplot2::ggplot(tp_open_proc, ggplot2::aes(x = tender_days_open)) +
            ggplot2::geom_histogram(binwidth = 5, fill = PA_NORMAL, colour = "white", linewidth = 0.3) +
            ggplot2::geom_vline(data = ql,
                                ggplot2::aes(xintercept = xintercept, colour = stat, linetype = stat),
                                linewidth = 0.9) +
            ggplot2::scale_colour_manual(values = c(Q1=PA_Q_Q1,Median=PA_Q_MEDIAN,Q3=PA_Q_Q1,Mean=PA_Q_MEAN),
                                         breaks = c("Q1","Median","Q3","Mean")) +
            ggplot2::scale_linetype_manual(values = c(Q1="dashed",Median="solid",Q3="dashed",Mean="dotted"),
                                           breaks = c("Q1","Median","Q3","Mean")) +
            ggplot2::facet_wrap(~ tender_proceduretype, scales = "free_y", ncol = 3) +
            ggplot2::coord_cartesian(xlim = c(0, 365)) +
            ggplot2::labs(
              x = "Days from call opening to bid deadline",
              y = "Contracts", colour = NULL, linetype = NULL) +
            pa_theme() +
            ggplot2::theme(legend.position = "top",
                           strip.text = ggplot2::element_text(face = "bold", size = 10),
                           panel.spacing=ggplot2::unit(0.4,"cm")),
          error = function(e) NULL)
        
        # ── Short submission deadlines ──────────────────────────────────
        if (!is.null(subm_cutoffs) && nrow(subm_cutoffs) > 0) {
          tp_flagged <- tp_open_proc %>%
            dplyr::left_join(subm_cutoffs, by = "tender_proceduretype") %>%
            dplyr::mutate(
              status = dplyr::case_when(
                tender_days_open < short_cut ~ "Short",
                !no_medium & !is.na(med_min) & !is.na(med_max) &
                  tender_days_open >= med_min & tender_days_open <= med_max ~ "Medium",
                TRUE ~ "Normal"),
              status = factor(status, levels = c("Short","Medium","Normal")))
          share_df <- tp_flagged %>%
            dplyr::group_by(tender_proceduretype, short_cut) %>%
            dplyr::summarise(share_short = mean(status == "Short", na.rm = TRUE), .groups = "drop") %>%
            dplyr::mutate(thr_str = dplyr::if_else(is.na(short_cut), "no threshold",
                                                   paste0("<", round(short_cut), " days")),
                          label = paste0(tender_proceduretype, "\nThreshold: ", thr_str,
                                         " | ", scales::percent(share_short, accuracy = 0.1), " short"))
          binned <- tp_flagged %>%
            dplyr::filter(tender_days_open >= 0, tender_days_open <= 60) %>%
            dplyr::mutate(day_bin = floor(tender_days_open)) %>%
            dplyr::count(tender_proceduretype, day_bin, status) %>%
            dplyr::left_join(share_df %>% dplyr::select(tender_proceduretype, label, short_cut),
                             by = "tender_proceduretype") %>%
            dplyr::mutate(label = factor(label))
          if (nrow(binned) > 0) {
            vline_df <- share_df %>% dplyr::select(label, short_cut) %>% dplyr::distinct() %>%
              dplyr::filter(!is.na(short_cut)) %>%
              dplyr::mutate(label = factor(label, levels = levels(binned$label)))
            plots$subm_r <- tryCatch(
              ggplot2::ggplot(binned, ggplot2::aes(x = day_bin, y = n, fill = status)) +
                ggplot2::geom_col(position = "stack", width = 1) +
                ggplot2::geom_vline(data = vline_df, ggplot2::aes(xintercept = short_cut),
                                    colour = PA_ROSE, linetype = "dashed", linewidth = 0.8) +
                ggplot2::scale_fill_manual(values = c(Short=PA_SHORT, Medium=PA_MEDIUM, Long=PA_LONG, Normal=PA_NORMAL)) +
                ggplot2::facet_wrap(~ label, scales = "free_y") +
                ggplot2::coord_cartesian(xlim = c(0, 60)) +
                ggplot2::labs(
                  x = "Days", y = "Contracts", fill = NULL) +
                pa_theme() +
                ggplot2::theme(legend.position = "top",
                               strip.text = ggplot2::element_text(size = 10, face = "bold"),
                               panel.spacing=ggplot2::unit(0.4,"cm")),
              error = function(e) NULL)
          }
          
          # ── Short by buyer group ──────────────────────────────────────
          tp_buyer <- tp_open_proc %>%
            dplyr::left_join(subm_cutoffs %>% dplyr::select(tender_proceduretype, short_cut),
                             by = "tender_proceduretype") %>%
            dplyr::mutate(short_deadline = tender_days_open < short_cut,
                          buyer_group    = add_buyer_group(buyer_buyertype))
          if (nrow(tp_buyer) > 0) {
            by_count <- tp_buyer %>%
              dplyr::group_by(buyer_group, tender_proceduretype) %>%
              dplyr::summarise(share_short = mean(short_deadline, na.rm = TRUE),
                               n_total = dplyr::n(), .groups = "drop") %>%
              dplyr::mutate(share_other = 1 - share_short, metric = "Count") %>%
              tidyr::pivot_longer(c(share_short, share_other),
                                  names_to = "type", values_to = "share") %>%
              dplyr::mutate(label = factor(dplyr::if_else(type == "share_short","Short","Normal"),
                                           levels = c("Normal","Short")))
            plots$buyer_short <- tryCatch(
              ggplot2::ggplot(by_count, ggplot2::aes(x = buyer_group, y = share, fill = label)) +
                ggplot2::geom_col(position = "stack", width = 0.7) +
                ggplot2::scale_fill_manual(values = c(Short=PA_SHORT, Normal=PA_NORMAL)) +
                ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                                            expand = ggplot2::expansion(mult = c(0, 0.02))) +
                ggplot2::facet_wrap(~ tender_proceduretype) +
                ggplot2::labs(
                  x = NULL, y = "Share", fill = NULL) +
                pa_theme() +
                ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1),
                               legend.position = "top",
                               strip.text = ggplot2::element_text(face = "bold", size = 10),
                               panel.spacing=ggplot2::unit(0.4,"cm")),
              error = function(e) NULL)
          }
        }
      }
    }
    
    # ── Decision period distribution ────────────────────────────────────
    # Decision date: primary = tender_awarddecisiondate; fallback = tender_contractsignaturedate
    df_dec <- filtered_data
    if (!"tender_contractsignaturedate" %in% names(df_dec))
      df_dec <- df_dec %>% dplyr::mutate(tender_contractsignaturedate = as.Date(NA))
    if (!"tender_awarddecisiondate" %in% names(df_dec))
      df_dec <- df_dec %>% dplyr::mutate(tender_awarddecisiondate = as.Date(NA))
    tp_dec <- tryCatch(
      df_dec %>%
        dplyr::mutate(decision_end_date = dplyr::coalesce(
          as.Date(tender_awarddecisiondate), as.Date(tender_contractsignaturedate))) %>%
        compute_tender_days(tender_biddeadline, decision_end_date, tender_days_dec),
      error = function(e) NULL)
    
    if (!is.null(tp_dec)) {
      days_dec <- tp_dec$tender_days_dec[!is.na(tp_dec$tender_days_dec) &
                                           tp_dec$tender_days_dec >= 0 &
                                           tp_dec$tender_days_dec <= 730]
      if (length(days_dec) > 1) {
        q_dec  <- quantile(days_dec, probs = c(0.25, 0.5, 0.75), na.rm = TRUE)
        mu_dec <- mean(days_dec, na.rm = TRUE)
        plots$decp <- tryCatch(
          ggplot2::ggplot(data.frame(days = days_dec), ggplot2::aes(x = days)) +
            ggplot2::geom_histogram(binwidth = 10, fill = PA_NORMAL, colour = "white") +
            ggplot2::geom_vline(xintercept = q_dec,
                                colour = c(PA_Q_Q1,PA_Q_MEDIAN,PA_Q_Q1),
                                linetype = c("dashed","solid","dashed"), linewidth = 1) +
            ggplot2::geom_vline(xintercept = mu_dec, colour = PA_Q_MEAN,
                                linetype = "dotted", linewidth = 1) +
            ggplot2::coord_cartesian(xlim = c(0, 730)) +
            ggplot2::labs(
              x = "Days from bid deadline to contract award",
              y = "Number of contracts") +
            pa_theme(),
          error = function(e) NULL)
      }
      
      # ── Decision by procedure type ──────────────────────────────────
      tp_dec_proc <- apply_proc_filter(tp_dec) %>%
        dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
        dplyr::filter(!is.na(tender_proceduretype)) %>%
        dplyr::filter(tender_days_dec >= 0, tender_days_dec <= 730)
      
      if (nrow(tp_dec_proc) > 0) {
        ql_dec <- tp_dec_proc %>%
          dplyr::group_by(tender_proceduretype) %>%
          dplyr::filter(dplyr::n() >= 5) %>%
          dplyr::summarise(Q1 = quantile(tender_days_dec, 0.25, na.rm = TRUE),
                           Median = quantile(tender_days_dec, 0.50, na.rm = TRUE),
                           Q3 = quantile(tender_days_dec, 0.75, na.rm = TRUE),
                           Mean = mean(tender_days_dec, na.rm = TRUE), .groups = "drop") %>%
          tidyr::pivot_longer(c(Q1, Median, Q3, Mean), names_to = "stat", values_to = "xintercept")
        plots$decp_proc_facet_q <- tryCatch(
          ggplot2::ggplot(tp_dec_proc, ggplot2::aes(x = tender_days_dec)) +
            ggplot2::geom_histogram(binwidth = 10, fill = PA_NORMAL, colour = "white", linewidth = 0.3) +
            ggplot2::geom_vline(data = ql_dec,
                                ggplot2::aes(xintercept = xintercept, colour = stat, linetype = stat),
                                linewidth = 0.9) +
            ggplot2::scale_colour_manual(values = c(Q1=PA_Q_Q1,Median=PA_Q_MEDIAN,Q3=PA_Q_Q1,Mean=PA_Q_MEAN),
                                         breaks = c("Q1","Median","Q3","Mean")) +
            ggplot2::scale_linetype_manual(values = c(Q1="dashed",Median="solid",Q3="dashed",Mean="dotted"),
                                           breaks = c("Q1","Median","Q3","Mean")) +
            ggplot2::facet_wrap(~ tender_proceduretype, scales = "free_y", ncol = 3) +
            ggplot2::coord_cartesian(xlim = c(0, 730)) +
            ggplot2::labs(
              x = "Days from bid deadline to contract award",
              y = "Contracts", colour = NULL, linetype = NULL) +
            pa_theme() +
            ggplot2::theme(legend.position = "top",
                           strip.text = ggplot2::element_text(face = "bold", size = 10),
                           panel.spacing=ggplot2::unit(0.4,"cm")),
          error = function(e) NULL)
        
        # ── Long decision flags ─────────────────────────────────────────
        if (!is.null(dec_cutoffs) && nrow(dec_cutoffs) > 0) {
          tp_long <- tp_dec_proc %>%
            dplyr::left_join(dec_cutoffs, by = "tender_proceduretype") %>%
            dplyr::mutate(long_decision = tender_days_dec >= long_cut)
          share_df_dec <- tp_long %>%
            dplyr::group_by(tender_proceduretype, long_cut) %>%
            dplyr::summarise(share_long = mean(long_decision, na.rm = TRUE), .groups = "drop") %>%
            dplyr::mutate(label = paste0(tender_proceduretype,
                                         "\nThreshold: \u2265", round(long_cut), " days | ",
                                         scales::percent(share_long, accuracy = 0.1), " long"))
          binned_dec <- tp_long %>%
            dplyr::filter(tender_days_dec >= 0, tender_days_dec <= 300) %>%
            dplyr::mutate(day_bin = floor(tender_days_dec / 4) * 4,
                          status  = factor(dplyr::if_else(long_decision, "Long", "Normal"),
                                           levels = c("Long","Normal"))) %>%
            dplyr::count(tender_proceduretype, day_bin, status) %>%
            dplyr::left_join(share_df_dec %>% dplyr::select(tender_proceduretype, label, long_cut),
                             by = "tender_proceduretype") %>%
            dplyr::mutate(label = factor(label))
          if (nrow(binned_dec) > 0) {
            vline_dec <- share_df_dec %>% dplyr::select(label, long_cut) %>% dplyr::distinct() %>%
              dplyr::mutate(label = factor(label, levels = levels(binned_dec$label)))
            plots$decp_r <- tryCatch(
              ggplot2::ggplot(binned_dec, ggplot2::aes(x = day_bin, y = n, fill = status)) +
                ggplot2::geom_col(position = "stack", width = 4) +
                ggplot2::geom_vline(data = vline_dec, ggplot2::aes(xintercept = long_cut),
                                    colour = PA_ROSE, linetype = "dashed", linewidth = 0.8) +
                ggplot2::scale_fill_manual(values = c(Long=PA_LONG, Normal=PA_NORMAL)) +
                ggplot2::facet_wrap(~ label, scales = "free_y") +
                ggplot2::coord_cartesian(xlim = c(0, 300)) +
                ggplot2::labs(
                  x = "Days", y = "Contracts", fill = NULL) +
                pa_theme() +
                ggplot2::theme(legend.position = "top",
                               strip.text = ggplot2::element_text(size = 10, face = "bold"),
                               panel.spacing=ggplot2::unit(0.4,"cm")),
              error = function(e) NULL)
          }
          
          # ── Long by buyer group ─────────────────────────────────────
          tp_buyer_long <- tp_long %>%
            dplyr::mutate(buyer_group = add_buyer_group(buyer_buyertype))
          if (nrow(tp_buyer_long) > 0) {
            by_count_long <- tp_buyer_long %>%
              dplyr::group_by(buyer_group, tender_proceduretype) %>%
              dplyr::summarise(share_long = mean(long_decision, na.rm = TRUE),
                               n_total = dplyr::n(), .groups = "drop") %>%
              dplyr::mutate(share_other = 1 - share_long, metric = "Count") %>%
              tidyr::pivot_longer(c(share_long, share_other),
                                  names_to = "type", values_to = "share") %>%
              dplyr::mutate(label = factor(dplyr::if_else(type == "share_long","Long","Normal"),
                                           levels = c("Normal","Long")))
            plots$buyer_long <- tryCatch(
              ggplot2::ggplot(by_count_long, ggplot2::aes(x = buyer_group, y = share, fill = label)) +
                ggplot2::geom_col(position = "stack", width = 0.7) +
                ggplot2::scale_fill_manual(values = c(Long=PA_LONG, Normal=PA_NORMAL)) +
                ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                                            expand = ggplot2::expansion(mult = c(0, 0.02))) +
                ggplot2::facet_wrap(~ tender_proceduretype) +
                ggplot2::labs(
                  x = NULL, y = "Share", fill = NULL) +
                pa_theme() +
                ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1),
                               legend.position = "top",
                               strip.text = ggplot2::element_text(face = "bold", size = 10),
                               panel.spacing=ggplot2::unit(0.4,"cm")),
              error = function(e) NULL)
          }
        }
      }
    }
    
    # ── Bunching (contract value distribution near thresholds) ───────────
    if (has_any_price_threshold(price_thresholds) && "bid_price" %in% names(filtered_data)) {
      message("[bunching] price_thresholds has ", length(price_thresholds), " proc groups; bid_price present")
      tryCatch({
        proc_label_map <- c(open="Open Procedure", restricted="Restricted Procedure",
                            neg_pub="Negotiated with publications", neg_nopub="Negotiated without publications",
                            neg="Negotiated Procedure", competitive="Competitive Dialogue",
                            innov="Innovation Partnership", direct="Direct Award", other="Other")
        supply_map <- c(goods="Goods", works="Works", services="Services")
        all_thr <- list()
        for (pk in names(price_thresholds)) for (sk in names(price_thresholds[[pk]])) {
          v <- price_thresholds[[pk]][[sk]]
          if (!is.null(v) && !is.na(v) && is.finite(v) && v > 0 &&
              pk %in% names(proc_label_map) && sk %in% names(supply_map)) {
            key <- paste0(sk, "_", round(v))
            if (is.null(all_thr[[key]]))
              all_thr[[key]] <- list(supply_label = supply_map[[sk]], threshold = v,
                                     log_thr = log10(v), proc_labels = proc_label_map[[pk]])
            else
              all_thr[[key]]$proc_labels <- paste0(all_thr[[key]]$proc_labels, ", ", proc_label_map[[pk]])
          }
        }
        if (length(all_thr) > 0) {
          df_b <- filtered_data %>%
            dplyr::mutate(supply_grp = classify_supply(.)) %>%
            dplyr::filter(!is.na(bid_price), bid_price > 1) %>%
            dplyr::mutate(log_val = log10(bid_price))
          bin_size <- 0.05; show_win <- 3.0
          panels <- unname(all_thr)
          panel_plots <- lapply(panels, function(pn) {
            d_win <- df_b %>% dplyr::filter(supply_grp == pn$supply_label,
                                            log_val >= pn$log_thr - show_win,
                                            log_val <= pn$log_thr + show_win)
            if (nrow(d_win) < 15) return(NULL)
            breaks <- seq(pn$log_thr - show_win, pn$log_thr + show_win + bin_size, by = bin_size)
            h      <- graphics::hist(d_win$log_val, breaks = breaks, plot = FALSE)
            df_h   <- data.frame(x = h$breaks[-length(h$breaks)] + bin_size/2, y = h$counts)
            excl   <- abs(df_h$x - pn$log_thr) <= (10 * bin_size)
            fit_df <- df_h[!excl, ]
            df_h$expected <- NA_real_
            if (nrow(fit_df) >= 8) {
              fit <- tryCatch(lm(y ~ poly(x, 4), data = fit_df), error = function(e) NULL)
              if (!is.null(fit)) df_h$expected <- pmax(predict(fit, newdata = df_h), 0)
            }
            df_h$below_win <- df_h$x < pn$log_thr & df_h$x >= (pn$log_thr - 10 * bin_size)
            df_h$is_bunch  <- df_h$below_win & !is.na(df_h$expected) & df_h$expected > 0 &
              df_h$y > df_h$expected * 1.5
            df_h$fill <- dplyr::case_when(df_h$is_bunch ~ "Bunching", df_h$below_win ~ "Near threshold", TRUE ~ "Normal")
            df_h$fill <- factor(df_h$fill, levels = c("Normal", "Near threshold", "Bunching"))
            tick_at  <- seq(ceiling((pn$log_thr - show_win) / 0.5) * 0.5,
                            floor((pn$log_thr + show_win) / 0.5) * 0.5, by = 0.5)
            tick_at  <- sort(unique(c(tick_at, pn$log_thr)))
            tick_lbl <- sapply(tick_at, function(v)
              if (abs(v - pn$log_thr) < 0.001) paste0(fmt_value(10^v), " ★") else fmt_value(10^v))
            p <- ggplot2::ggplot(df_h, ggplot2::aes(x = x, y = y, fill = fill)) +
              ggplot2::geom_col(width = bin_size * 0.9) +
              ggplot2::scale_fill_manual(values = c(Normal = "#5dade2",
                                                    "Near threshold" = "#f0b27a",
                                                    Bunching = "#e74c3c")) +
              ggplot2::geom_vline(xintercept = pn$log_thr, colour = "#922b21",
                                  linewidth = 1.2, linetype = "solid") +
              ggplot2::scale_x_continuous(breaks = tick_at, labels = tick_lbl) +
              ggplot2::labs(title = paste0(pn$supply_label, " — Threshold: ", fmt_value(pn$threshold)),
                            x = "Contract value (log scale)", y = "Contracts", fill = NULL) +
              pa_theme() +
              ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1, size = 8),
                             legend.position = "bottom", legend.text = ggplot2::element_text(size = 8))
            if (!all(is.na(df_h$expected))) {
              df_line <- df_h[!is.na(df_h$expected), ]
              p <- p + ggplot2::geom_line(ggplot2::aes(x = x, y = expected), colour = "#1c2833",
                                          linewidth = 0.9, linetype = "dashed", inherit.aes = FALSE,
                                          data = df_line)
            }
            p
          })
          panel_plots <- Filter(Negate(is.null), panel_plots)
          if (length(panel_plots) > 0) {
            message("[bunching] assigning ", length(panel_plots), " panel plot(s) to plots$bunching")
            plots$bunching <- panel_plots
          }
        }
      }, error = function(e) {
        message("[bunching] ggplot build ERROR: ", e$message)
      })
    }
    
    # Regressions — too slow to rerun; taken from stored filtered_analysis
    plots$plot_short_reg <- NULL
    plots$plot_long_reg  <- NULL
    
  }, error = function(e) message("admin_build_word_plots error: ", e$message))
  return(plots)
}



# [APP-G19] INTEGRITY EXPORT PLOTS: integ_regenerate_plots() ─────────────────
integ_regenerate_plots <- function(filtered_data, country_code) {
  tryCatch(
    run_integrity_pipeline_fast_local(filtered_data, country_code),
    error = function(e) { message("Integ plot regen error: ", e$message); list() }
  )
}



# [APP-G20] GLOBAL PLOT THEME & PLOTLY POST-PROCESSING (pa_theme, post_process_plotly) ────
# ========================================================================
# UI
# ========================================================================

# ========================================================================
# WORD REPORT GENERATION FUNCTIONS
# ========================================================================
# Three separate functions: econ, admin, integrity — all same signature.

# ══════════════════════════════════════════════════════════════════════
# PROCUREMENT ANALYTICS — GLOBAL PLOT THEME & PALETTE
# ══════════════════════════════════════════════════════════════════════
PA_NAVY   <- "#0F1F3D"; PA_NAVY2  <- "#1A3160"
PA_TEAL   <- "#00897B"; PA_AMBER  <- "#D97706"
PA_ROSE   <- "#DC2626"; PA_SLATE  <- "#475569"
PA_SLATE2 <- "#94A3B8"; PA_GREY   <- "#E2E8F0"
PA_NORMAL <- "#5B8DB8"   # neutral bars
PA_SEVERE <- PA_ROSE     # severe / bunching
# Period-band semantic colours — used consistently across all submission/decision charts
PA_SHORT  <- "#C62828"   # deep red   — too short / flagged (mirrors PA_LONG)
PA_MEDIUM <- "#F59E0B"   # amber      — medium band (acceptable but watch)
PA_LONG   <- "#C62828"   # deep red   — too long / flagged
PA_FLAG   <- PA_LONG     # legacy alias — use PA_SHORT/PA_MEDIUM/PA_LONG for period bands
PA_Q_Q1     <- PA_NAVY2  # Q1/Q3 quantile lines
PA_Q_MEDIAN <- PA_ROSE   # median line
PA_Q_MEAN   <- PA_TEAL   # mean line

pa_theme <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) %+replace%
    ggplot2::theme(
      text             = ggplot2::element_text(colour = PA_SLATE),
      plot.title       = ggplot2::element_blank(),
      plot.subtitle    = ggplot2::element_blank(),
      plot.caption     = ggplot2::element_text(size = base_size - 1, colour = PA_SLATE2,
                                               hjust = 0, margin = ggplot2::margin(t = 6)),
      axis.title       = ggplot2::element_text(size = base_size, colour = PA_SLATE),
      axis.text        = ggplot2::element_text(size = base_size, colour = PA_SLATE),
      axis.line        = ggplot2::element_line(colour = PA_GREY, linewidth = 0.4),
      axis.ticks       = ggplot2::element_line(colour = PA_GREY, linewidth = 0.3),
      panel.grid.major = ggplot2::element_line(colour = "#F1F5F9", linewidth = 0.4),
      panel.grid.minor = ggplot2::element_blank(),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.background  = ggplot2::element_rect(fill = "white", colour = NA),
      strip.text       = ggplot2::element_text(size = base_size, face = "bold",
                                               colour = PA_NAVY),
      strip.background = ggplot2::element_rect(fill = "#F8FAFC", colour = PA_GREY,
                                               linewidth = 0.4),
      legend.text      = ggplot2::element_text(size = base_size, colour = PA_SLATE),
      legend.title     = ggplot2::element_text(size = base_size, face = "bold",
                                               colour = PA_NAVY),
      legend.key.size  = ggplot2::unit(0.85, "lines"),
      legend.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin      = ggplot2::margin(6, 10, 6, 6)
    )
}

# ---------------------------------------------------------------------------
# Post-process a ggplotly object: override every baked-in font size so that
# integrity (and other) plots look correct regardless of when they were built.
# ---------------------------------------------------------------------------
post_process_plotly <- function(p,
                                tick_size   = 13,
                                title_size  = 15,
                                legend_size = 12) {
  # Screen-legible defaults for every chart routed through this function;
  # per-chart overrides still win. Adjust these three numbers to change
  # chart text sizes app-wide.
  # Apply font sizing to axes and legend
  p <- plotly::layout(p,
                      font   = list(size = tick_size),
                      xaxis  = list(tickfont  = list(size = tick_size),
                                    titlefont = list(size = title_size)),
                      yaxis  = list(tickfont  = list(size = tick_size),
                                    titlefont = list(size = title_size)),
                      legend = list(font = list(size = legend_size))
  )
  # Walk all axes (xaxis2, yaxis3 …) present in facets/subplots
  pb <- plotly::plotly_build(p)
  for (nm in names(pb$x$layout)) {
    if (grepl("^[xy]axis", nm)) {
      pb$x$layout[[nm]]$tickfont  <- list(size = tick_size)
      pb$x$layout[[nm]]$titlefont <- list(size = title_size)
    }
  }
  # Size the plot title; keep a small top margin for it
  if (!is.null(pb$x$layout$title$text) && nchar(pb$x$layout$title$text) > 0) {
    pb$x$layout$title$font <- list(size = title_size, color = "#222222")
    pb$x$layout$margin$t   <- max(pb$x$layout$margin$t %||% 30, 40)
  } else {
    # No title — minimise top margin so plot sits flush
    pb$x$layout$margin$t <- 20
  }
  pb
}




# [APP-G21] EXPORT STANDARDIZATION — one sizing/font/save path for ALL exports ────
# ========================================================================
# EXPORT STANDARDIZATION HELPERS
# ========================================================================
# All static exports — individual PNG downloads, ZIP bundles and Word
# reports — funnel through one layer, so sizes and fonts are consistent and
# a missing figure is always reported rather than silently skipped:
#   pa_prep_plotly_export()  — exact pixel size + print-ready fonts
#   pa_save_plot_any()       — saves ggplot OR plotly to PNG; returns TRUE/FALSE
#                              with attr("reason") explaining any failure
#   pa_write_manifest()      — writes MANIFEST.txt inside every figures ZIP
#   pa_word_add_fig()        — Word figure helper: never silently skips; a
#                              missing figure becomes a visible italic note
# ========================================================================

# Print-ready font sizes applied to every static export (PNG / ZIP / Word)
PA_EXPORT_FONTS <- list(tick = 15, title = 17, legend = 13)

# Prepare a plotly figure for static export:
#  - honours any width/height the render block already set (dynamic-height
#    heatmaps keep their aspect instead of being squashed into 1200x700)
#  - otherwise applies the standard export canvas (vw x vh)
#  - boosts all fonts to PA_EXPORT_FONTS so text stays readable in the PNG
pa_prep_plotly_export <- function(fig, vw = 1400, vh = 850) {
  lw <- suppressWarnings(as.numeric(tryCatch(fig$x$layout$width,  error = function(e) NULL) %||% NA))
  lh <- suppressWarnings(as.numeric(tryCatch(fig$x$layout$height, error = function(e) NULL) %||% NA))
  # Dimensions set by the render block define the chart's intended shape
  # (dynamic-height missingness charts etc.) — honour them exactly rather
  # than stretching to the requested canvas, which distorted the ratio.
  if (is.finite(lw)) vw <- ceiling(lw)
  if (is.finite(lh)) vh <- ceiling(lh)
  fig <- plotly::layout(fig, width = vw, height = vh,
                        paper_bgcolor = "#ffffff", plot_bgcolor = "#ffffff")
  fig <- tryCatch(
    post_process_plotly(fig,
                        tick_size   = PA_EXPORT_FONTS$tick,
                        title_size  = PA_EXPORT_FONTS$title,
                        legend_size = PA_EXPORT_FONTS$legend),
    error = function(e) fig)
  fig <- plotly::config(fig, displayModeBar = FALSE, responsive = FALSE)
  attr(fig, "pa_export_size") <- c(vw, vh)
  fig
}

# Save a ggplot OR plotly object to PNG. Returns TRUE on success, FALSE with
# attr(., "reason") on failure. NULL input fails with reason "not generated".
pa_save_plot_any <- function(obj, file, width_in = 10, height_in = 7, dpi = 300,
                             webshot_delay = 1.5, gg_scale = 1) {
  # gg_scale > 1 renders a ggplot on a proportionally larger canvas, so its
  # (absolute, point-sized) text appears smaller when the image is placed at
  # page width — the fix for plots whose text overflows in Word reports.
  # On success the returned TRUE carries attr "size_px" = c(w, h) of the
  # saved image, so callers can place it at its true aspect ratio.
  fail <- function(reason) { r <- FALSE; attr(r, "reason") <- reason; r }
  if (is.null(obj)) return(fail("not generated"))
  if (inherits(obj, "ggplot")) {
    return(tryCatch({
      ggplot2::ggsave(file, plot = obj, width = width_in, height = height_in,
                      dpi = dpi, bg = "white", scale = gg_scale)
      r <- TRUE
      attr(r, "size_px") <- c(width_in, height_in) * dpi * gg_scale
      r
    }, error = function(e) fail(conditionMessage(e))))
  }
  if (inherits(obj, c("plotly", "htmlwidget"))) {
    return(tryCatch({
      fig <- pa_prep_plotly_export(obj, vw = round(width_in * 140),
                                        vh = round(height_in * 140))
      sz  <- attr(fig, "pa_export_size")
      tmp <- tempfile(fileext = ".html")
      htmlwidgets::saveWidget(fig, tmp, selfcontained = TRUE)
      webshot2::webshot(tmp, file = file, vwidth = sz[1] + 20, vheight = sz[2] + 20,
                        delay = webshot_delay, zoom = 2)
      unlink(tmp)
      if (file.exists(file) && file.size(file) > 1000) {
        r <- TRUE
        attr(r, "size_px") <- sz * 2   # webshot zoom = 2
        r
      } else fail("webshot2 produced an empty file")
    }, error = function(e) fail(conditionMessage(e))))
  }
  fail(paste0("unsupported plot class: ", paste(class(obj), collapse = "/")))
}

# Write MANIFEST.txt into a ZIP staging directory.
# rows: data.frame(figure, status = "saved"/"skipped"/"failed", note)
pa_write_manifest <- function(dir, section_label, rows) {
  lines <- c(
    paste0(section_label, " — figure export manifest"),
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M")),
    strrep("-", 78),
    sprintf("%-40s %-8s %s", "FIGURE", "STATUS", "NOTE"),
    strrep("-", 78),
    sprintf("%-40s %-8s %s", rows$figure, rows$status, rows$note),
    strrep("-", 78),
    paste0(sum(rows$status == "saved"), " of ", nrow(rows), " expected figures saved."),
    "",
    "'skipped' = the figure was not generated in this session; the NOTE says",
    "what to do (open the tab / click its Run button) or why it cannot exist",
    "for this dataset. Generate it, then download the ZIP again."
  )
  writeLines(lines, file.path(dir, "MANIFEST.txt"))
  invisible(NULL)
}

# Build the cross-market supplier flow-matrix heatmap from the unusual-entry
# matrix. Returns list(plot = <ggplot>, height_in = <inches>) or NULL.
# Shared by the integrity Word report and the integrity figures ZIP.
pa_build_flow_matrix <- function(unusual_mat, top_n = 20, min_bidders = 4) {
  if (is.null(unusual_mat) || nrow(unusual_mat) == 0) return(NULL)
  tryCatch({
    edges <- unusual_mat %>%
      dplyr::rename(from = home_cpv_cluster, to = target_cpv_cluster) %>%
      dplyr::filter(n_bidders >= min_bidders, from != to)
    top_clusters <- edges %>%
      tidyr::pivot_longer(c(from, to), values_to = "cluster") %>%
      dplyr::count(cluster, wt = n_bidders, sort = TRUE) %>%
      dplyr::slice_head(n = top_n) %>% dplyr::pull(cluster)
    df_mat <- edges %>%
      dplyr::filter(from %in% top_clusters, to %in% top_clusters) %>%
      dplyr::mutate(from = factor(from, levels = rev(top_clusters)),
                    to   = factor(to,   levels = top_clusters))
    if (nrow(df_mat) == 0) return(NULL)
    n_cl    <- length(top_clusters)
    txt_sz  <- max(3.2, min(5.5, 56 / max(n_cl, 1)))
    axis_sz <- max(7,   min(11,  110 / max(n_cl, 1)))
    p_mat <- ggplot2::ggplot(df_mat, ggplot2::aes(x = to, y = from, fill = n_bidders)) +
      ggplot2::geom_tile(colour = "white", linewidth = 0.5) +
      ggplot2::geom_text(ggplot2::aes(label = n_bidders), size = txt_sz, fontface = "bold") +
      ggplot2::scale_fill_gradientn(
        colours = c("#f0f7ff", "#93c6e0", "#2471a3", "#1a5276"),
        na.value = "grey95", name = "Suppliers crossing") +
      ggplot2::scale_x_discrete(position = "top") +
      ggplot2::labs(x = "\u2193 Target market", y = "Home market \u2192") +
      pa_theme() +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(angle = 40, hjust = 0,
                                            size = axis_sz, face = "bold"),
        axis.text.y = ggplot2::element_text(size = axis_sz, face = "bold"),
        panel.grid  = ggplot2::element_blank(),
        legend.position = "right",
        plot.title  = ggplot2::element_text(size = 11, face = "bold"))
    list(plot = p_mat, height_in = min(6.5, max(3.5, n_cl * 0.28 + 1.2)))
  }, error = function(e) { message("flow matrix build error: ", e$message); NULL })
}

# Word figure helper used by all three report generators: adds the label and
# EITHER the figure (ggplot or plotly via pa_save_plot_any) OR a visible
# italic note explaining that it is missing — never a silent skip.
pa_word_add_fig <- function(d, p, cw = 6.5, aspect = 0.60, label = NULL, max_h = 5.5,
                            height_in = NULL, render_scale = 1,
                            missing_note = paste0(
                              "Figure not available — not generated for this ",
                              "dataset / filter selection (see MANIFEST.txt in ",
                              "the figures ZIP for details).")) {
  if (!is.null(label)) d <- officer::body_add_par(d, label, style = "heading 2")
  # height_in (if given) sets the exact figure height — used for charts whose
  # natural height depends on the data (e.g. missingness bar/heatmap charts)
  h <- if (!is.null(height_in) && is.finite(height_in)) min(height_in, 8.5)
       else min(max_h, cw * aspect)
  note <- function(dd, txt) officer::body_add_fpar(dd, officer::fpar(officer::ftext(
    txt, officer::fp_text(italic = TRUE, color = "#8A8A8A", font.size = 9))))
  if (is.null(p)) return(note(d, missing_note))
  tmp <- tempfile(fileext = ".png")
  ok  <- pa_save_plot_any(p, tmp, width_in = cw, height_in = h, dpi = 180,
                          gg_scale = render_scale)
  if (isTRUE(ok)) {
    # Place at the saved image's true aspect ratio so nothing gets distorted
    # (plotly figures may export at their own dimensions)
    szpx <- attr(ok, "size_px")
    if (!is.null(szpx) && length(szpx) == 2 && all(is.finite(szpx)) && szpx[1] > 0)
      h <- min(8.8, cw * szpx[2] / szpx[1])
    d <- officer::body_add_img(d, src = tmp, width = cw, height = h)
    d <- officer::body_add_par(d, "", style = "Normal")
  } else {
    d <- note(d, paste0("Figure could not be rendered: ",
                        attr(ok, "reason") %||% "unknown error"))
  }
  d
}
# [APP-G22] WORD REPORT GENERATORS (generate_econ/admin/integrity_word_report) ────
# Called as generate_econ_word_report(), generate_admin_word_report(),
# generate_integrity_word_report() to avoid naming collision.
# ========================================================================

generate_econ_word_report <- function(filtered_data, filtered_analysis, country_code,
                                      output_file, filters_text = "") {
  tryCatch({
    doc <- officer::read_docx()
    cw  <- 6.5  # usable page width in inches
    
    h1_  <- function(d, t) officer::body_add_par(d, t, style = "heading 1")
    h2_  <- function(d, t) officer::body_add_par(d, t, style = "heading 2")
    par_ <- function(d, t) officer::body_add_par(d, t, style = "Normal")
    br_  <- function(d)    officer::body_add_par(d, "",  style = "Normal")
    pg_  <- function(d)    officer::body_add_break(d)
    
    # Delegates to pa_word_add_fig() [APP-G21]: handles ggplot AND plotly,
    # and inserts a visible note when a figure is missing (no silent skips).
    add_fig <- function(d, p, aspect = 0.60, label = NULL, max_h = 5.5, height_in = NULL, ...)
      pa_word_add_fig(d, p, cw = cw, aspect = aspect, label = label, max_h = max_h,
                      height_in = height_in, ...)
    
    n_c <- format(nrow(filtered_data), big.mark = ",")
    n_b <- if ("buyer_masterid"  %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_masterid,  na.rm = TRUE), big.mark = ",")
    else if ("buyer_id"   %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_id,        na.rm = TRUE), big.mark = ",")
    else if ("buyer_name" %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_name,      na.rm = TRUE), big.mark = ",")
    else "N/A"
    n_s <- if ("bidder_masterid"  %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$bidder_masterid,  na.rm = TRUE), big.mark = ",")
    else if ("bidder_id"   %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$bidder_id,        na.rm = TRUE), big.mark = ",")
    else if ("supplier_name" %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$supplier_name, na.rm = TRUE), big.mark = ",")
    else if ("bidder_name"  %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$bidder_name,    na.rm = TRUE), big.mark = ",")
    else "N/A"
    yr  <- if ("tender_year" %in% names(filtered_data)) {
      paste(min(filtered_data$tender_year, na.rm = TRUE), "–", max(filtered_data$tender_year, na.rm = TRUE))
    } else "N/A"
    
    doc <- h1_(doc, "Economic Outcomes Analysis Report")
    doc <- par_(doc, paste("Country:", country_code))
    doc <- par_(doc, paste("Date:", format(Sys.Date(), "%B %d, %Y")))
    if (nchar(filters_text) > 0) { doc <- h2_(doc, "Applied Filters"); doc <- par_(doc, filters_text) }
    doc <- pg_(doc)
    
    doc <- h1_(doc, "Executive Summary")
    doc <- par_(doc, paste0("Economic outcomes analysis for ", country_code,
                            ": ", n_c, " contracts, ", n_b, " buyers, ",
                            n_s, " suppliers, years ", yr, "."))
    ov <- data.frame(Metric = c("Total Contracts","Unique Buyers","Unique Suppliers","Years Covered"),
                     Value  = c(n_c, n_b, n_s, yr), stringsAsFactors = FALSE)
    ft <- flextable::flextable(ov) %>% flextable::theme_booktabs() %>% flextable::autofit()
    doc <- flextable::body_add_flextable(doc, ft)
    doc <- pg_(doc)
    
    # ── 0. Contracts Over Time ─────────────────────────────────────────
    ov_note <- "Not available — open the Data Overview tab once, then regenerate this report."
    doc <- h1_(doc, "Contracts Over Time")
    doc <- add_fig(doc, filtered_analysis$fig_contracts_year, aspect = 0.50,
                   label = "Contracts per Year", missing_note = ov_note)
    doc <- add_fig(doc, filtered_analysis$fig_value_by_year,  aspect = 0.50,
                   label = "Contract Value by Year", missing_note = ov_note)
    doc <- pg_(doc)
    
    # ── 1. Market Size ─────────────────────────────────────────────────
    doc <- h1_(doc, "1. Market Size")
    doc <- add_fig(doc, filtered_analysis$market_size_n,  aspect = 0.55, label = "Number of Contracts per Market")
    doc <- add_fig(doc, filtered_analysis$market_size_v,  aspect = 0.55, label = "Total Contract Value per Market")
    doc <- add_fig(doc, filtered_analysis$market_size_av, aspect = 0.55, label = "Average Contract Value per Market")
    doc <- pg_(doc)
    
    # ── 1b. Supplier Dynamics ──────────────────────────────────────────
    doc <- h1_(doc, "1b. Supplier Dynamics")
    if (!is.null(filtered_analysis$suppliers_entrance) ||
        !is.null(filtered_analysis$unique_supp)) {
      doc <- add_fig(doc, filtered_analysis$suppliers_entrance, aspect = 0.80,
                     label = "New vs Repeat Suppliers by Market", max_h = 7)
      doc <- add_fig(doc, filtered_analysis$unique_supp,        aspect = 0.80,
                     label = "Unique Suppliers by Market",        max_h = 7)
    } else {
      # Aggregate fallback used for datasets without CPV market categories
      doc <- add_fig(doc, filtered_analysis$supplier_entry_agg, aspect = 0.55,
                     label = "New vs Repeat Suppliers (Aggregate)")
    }
    sd_note <- "Not available — open the Supplier Dynamics tab once, then regenerate this report."
    doc <- add_fig(doc, filtered_analysis$fig_supp_bubble,    aspect = 0.70, label = "Supplier Entry Bubble Grid",    max_h = 6.5, missing_note = sd_note)
    doc <- add_fig(doc, filtered_analysis$fig_supp_stability, aspect = 0.70, label = "Market Stability Scatter",      max_h = 6.5, missing_note = sd_note)
    doc <- add_fig(doc, filtered_analysis$fig_supp_trend,     aspect = 0.70, label = "New vs Repeat Suppliers Trend", max_h = 6.5, missing_note = sd_note)
    doc <- add_fig(doc, filtered_analysis$fig_top_suppliers,  aspect = 0.70, label = "Top Suppliers",                 max_h = 6.5, missing_note = sd_note)
    doc <- pg_(doc)
    
    # ── 2. Relative Prices ─────────────────────────────────────────────
    doc <- h1_(doc, "2. Relative Prices")
    doc <- add_fig(doc, filtered_analysis$rel_tot,  aspect = 0.55, label = "Relative Price — Overall")
    doc <- add_fig(doc, filtered_analysis$rel_year, aspect = 0.55, label = "Relative Price — Over Time")
    doc <- add_fig(doc, filtered_analysis$rel_10,   aspect = 0.55, label = "Relative Price — Top 10 Markets")
    doc <- add_fig(doc, filtered_analysis$rel_buy,  aspect = 0.55, label = "Relative Price — By Buyer")
    doc <- pg_(doc)
    
    # ── 2b. Buyer–Supplier Networks ────────────────────────────────────
    doc <- h1_(doc, "2b. Buyer–Supplier Networks")
    nets <- filtered_analysis$network_plots
    if (!is.null(nets) && length(nets) > 0) {
      for (nm in names(nets)) {
        if (!is.null(nets[[nm]]))
          doc <- add_fig(doc, nets[[nm]], height_in = 6.0, render_scale = 1.2, label = nm)
      }
    } else {
      doc <- par_(doc, "Not available — generate the networks in the Networks tab (re-run after changing filters), then regenerate this report.")
    }
    doc <- pg_(doc)
    
    # ── 3. Single Bidding ──────────────────────────────────────────────
    doc <- h1_(doc, "3. Single Bidding")
    doc <- add_fig(doc, filtered_analysis$single_bid_overall,          aspect = 0.55, label = "Single Bidding — Overall Rate")
    doc <- add_fig(doc, filtered_analysis$single_bid_by_procedure,     aspect = 0.55, label = "Single Bidding — By Procedure Type")
    doc <- add_fig(doc, filtered_analysis$single_bid_by_price,          aspect = 0.55, label = "Single Bidding — By Price Category")
    doc <- add_fig(doc, filtered_analysis$single_bid_by_buyer_group,   aspect = 0.55, label = "Single Bidding — By Buyer Group")
    doc <- add_fig(doc, filtered_analysis$single_bid_by_market,        aspect = 0.65, label = "Single Bidding — By Market",        max_h = 6)
    doc <- add_fig(doc, filtered_analysis$top_buyers_single_bid,       aspect = 0.65, label = "Top Buyers by Single Bidding Rate", max_h = 6)
    
    doc <- par_(doc, paste0("Report generated on ", format(Sys.Date(), "%B %d, %Y"), "."))
    print(doc, target = output_file)
    TRUE
  }, error = function(e) { message("Econ Word error: ", e$message); FALSE })
}

generate_admin_word_report <- function(filtered_data, filtered_analysis, country_code,
                                       output_file, filters_text = "") {
  tryCatch({
    doc <- officer::read_docx()
    pg_w <- 8.5; pg_h <- 11; margin <- 1
    cw   <- pg_w - 2 * margin  # usable width = 6.5 in
    
    h1_  <- function(d, t) officer::body_add_par(d, t, style = "heading 1")
    h2_  <- function(d, t) officer::body_add_par(d, t, style = "heading 2")
    par_ <- function(d, t) officer::body_add_par(d, t, style = "Normal")
    br_  <- function(d)    officer::body_add_par(d, "",  style = "Normal")
    pg_  <- function(d)    officer::body_add_break(d)
    
    # Delegates to pa_word_add_fig() [APP-G21]: handles ggplot AND plotly,
    # and inserts a visible note when a figure is missing (no silent skips).
    add_fig <- function(d, p, aspect = 0.55, label = NULL, max_h = 5.5, height_in = NULL, ...)
      pa_word_add_fig(d, p, cw = cw, aspect = aspect, label = label, max_h = max_h,
                      height_in = height_in, ...)
    
    n_c <- format(nrow(filtered_data), big.mark = ",")
    n_b <- if ("buyer_masterid"  %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_masterid,  na.rm = TRUE), big.mark = ",")
    else if ("buyer_id"   %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_id,        na.rm = TRUE), big.mark = ",")
    else if ("buyer_name" %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_name,      na.rm = TRUE), big.mark = ",")
    else "N/A"
    yr  <- if ("tender_year" %in% names(filtered_data))
      paste(min(filtered_data$tender_year, na.rm = TRUE), "–",
            max(filtered_data$tender_year, na.rm = TRUE))
    else "N/A"
    
    doc <- h1_(doc, "Administrative Efficiency Analysis Report")
    doc <- par_(doc, paste("Country:", country_code))
    doc <- par_(doc, paste("Date:", format(Sys.Date(), "%B %d, %Y")))
    if (nchar(filters_text) > 0) {
      doc <- h2_(doc, "Applied Filters"); doc <- par_(doc, filters_text)
    }
    doc <- pg_(doc)
    
    doc <- h1_(doc, "Executive Summary")
    doc <- par_(doc, paste0(
      "Administrative efficiency analysis for ", country_code, ". Dataset: ",
      n_c, " contracts, ", n_b, " unique buyers, years ", yr, ". ",
      "Analysis covers procedure type distribution, submission deadline compliance, ",
      "contract value bunching near thresholds, decision period lengths, and regression results."))
    
    ov  <- data.frame(Metric = c("Total Contracts", "Unique Buyers", "Years Covered"),
                      Value  = c(n_c, n_b, yr), stringsAsFactors = FALSE)
    ft  <- flextable::flextable(ov) %>% flextable::theme_booktabs() %>% flextable::autofit()
    doc <- flextable::body_add_flextable(doc, ft)
    doc <- pg_(doc)
    
    # ── Procedure Types ──────────────────────────────────────────────
    doc <- h1_(doc, "1. Procedure Types")
    doc <- par_(doc, "Distribution of procurement contracts by procedure type.")
    doc <- add_fig(doc, filtered_analysis$sh,      aspect = 0.50, label = "Share of Contract Value by Procedure Type")
    doc <- add_fig(doc, filtered_analysis$p_count, aspect = 0.50, label = "Share of Contract Count by Procedure Type")
    doc <- add_fig(doc, filtered_analysis$fig_proc_value_dist, aspect = 0.60,
                   label = "Contract Value Distribution by Procedure Type", max_h = 5.5,
                   missing_note = "Not available — open the Procedure Types tab once, then regenerate this report.")
    
    # ── Submission Periods ────────────────────────────────────────────
    doc <- pg_(doc)
    doc <- h1_(doc, "2. Submission Periods")
    doc <- par_(doc, paste0(
      "Days between call for tenders publication and bid deadline. ",
      "Short deadlines may reduce competition."))
    doc <- add_fig(doc, filtered_analysis$subm,              aspect = 0.55, label = "Overall Submission Period Distribution")
    doc <- add_fig(doc, filtered_analysis$subm_proc_facet_q, aspect = 0.70, label = "Submission Periods by Procedure Type",  max_h = 6)
    doc <- add_fig(doc, filtered_analysis$subm_r,            aspect = 0.70, label = "Short vs Normal Submission Deadlines",   max_h = 6)
    doc <- add_fig(doc, filtered_analysis$buyer_short,       aspect = 0.70, label = "Short Deadlines by Buyer Group",         max_h = 6)
    doc <- add_fig(doc, filtered_analysis$fig_subm_share, aspect = 0.55,
                   label = "Submission Period Share Summary",
                   missing_note = "Not available — open the Submission Periods tab once, then regenerate this report.")
    
    # ── Contract Value Bunching ───────────────────────────────────────
    bunching     <- filtered_analysis$bunching
    bunching_fig <- filtered_analysis$bunching_fig_fallback
    has_bunching <- (!is.null(bunching) && length(bunching) > 0) ||
      !is.null(bunching_fig)
    if (has_bunching) {
      doc <- pg_(doc)
      doc <- h1_(doc, "3. Contract Value Bunching Near Thresholds")
      doc <- par_(doc, paste0(
        "Histogram of contract values near procedure-type value thresholds. ",
        "Red bars indicate possible bunching (observed counts exceed counterfactual by ≥50%). ",
        "The dashed line shows the counterfactual expected distribution."))
      if (!is.null(bunching) && length(bunching) > 0) {
        # Preferred: ggplot panels (one per supply-type threshold)
        for (i in seq_along(bunching)) {
          doc <- add_fig(doc, bunching[[i]], aspect = 0.55,
                         label = if (i == 1) "Bunching Analysis" else NULL)
        }
      } else if (!is.null(bunching_fig)) {
        # Fallback: render the stored plotly figure via webshot2
        tryCatch({
          tmp_html <- tempfile(fileext = ".html")
          tmp_png  <- tempfile(fileext = ".png")
          htmlwidgets::saveWidget(bunching_fig, tmp_html, selfcontained = TRUE)
          webshot2::webshot(tmp_html, tmp_png, vwidth = 1400, vheight = 900, delay = 2, zoom = 2)
          if (file.exists(tmp_png) && file.size(tmp_png) > 1000) {
            doc <- h2_(doc, "Bunching Analysis")
            doc <- officer::body_add_img(doc, src = tmp_png, width = cw, height = cw * 0.6)
            doc <- br_(doc)
          }
          unlink(c(tmp_html, tmp_png))
        }, error = function(e) message("Bunching webshot fallback error: ", e$message))
      }
    }
    
    # ── Decision Periods ──────────────────────────────────────────────
    doc <- pg_(doc)
    doc <- h1_(doc, "4. Decision Periods")
    doc <- par_(doc, paste0(
      "Days from bid deadline to contract award. ",
      "Long decision periods may indicate administrative bottlenecks."))
    doc <- add_fig(doc, filtered_analysis$decp,               aspect = 0.55, label = "Overall Decision Period Distribution")
    doc <- add_fig(doc, filtered_analysis$decp_proc_facet_q,  aspect = 0.70, label = "Decision Periods by Procedure Type",   max_h = 6)
    doc <- add_fig(doc, filtered_analysis$decp_r,             aspect = 0.70, label = "Long vs Normal Decision Periods",       max_h = 6)
    doc <- add_fig(doc, filtered_analysis$buyer_long,         aspect = 0.70, label = "Long Decision Periods by Buyer Group",  max_h = 6)
    doc <- add_fig(doc, filtered_analysis$fig_dec_share, aspect = 0.55,
                   label = "Decision Period Share Summary",
                   missing_note = "Not available — open the Decision Periods tab once, then regenerate this report.")
    
    # ── Regression Analysis — section always present; a plot that has not
    # been generated appears as an explanatory note instead of vanishing ──
    doc <- pg_(doc)
    doc <- h1_(doc, "5. Regression Analysis")
    doc <- par_(doc, "Multivariate regression estimates for submission and decision period determinants.")
    doc <- add_fig(doc, filtered_analysis$plot_short_reg, aspect = 0.75, label = "Short Submission Regression Results", max_h = 6.5,
                   render_scale = 1.25,
                   missing_note = "Not available — run the regressions in the Regression Analysis tab (re-run after changing filters), then regenerate this report.")
    doc <- add_fig(doc, filtered_analysis$plot_long_reg,  aspect = 0.75, label = "Long Decision Regression Results",    max_h = 6.5,
                   render_scale = 1.25,
                   missing_note = "Not available — run the regressions in the Regression Analysis tab (re-run after changing filters), then regenerate this report.")
    
    doc <- par_(doc, paste0("Report generated on ", format(Sys.Date(), "%B %d, %Y"), "."))
    print(doc, target = output_file)
    TRUE
  }, error = function(e) { message("Admin Word error: ", e$message); FALSE })
}


generate_integrity_word_report <- function(filtered_data, filtered_analysis, country_code,
                                           output_file, filters_text = "") {
  tryCatch({
    doc <- officer::read_docx()
    pg_w <- 8.5; margin <- 1
    cw   <- pg_w - 2 * margin  # 6.5 in
    
    h1_  <- function(d, t) officer::body_add_par(d, t, style = "heading 1")
    h2_  <- function(d, t) officer::body_add_par(d, t, style = "heading 2")
    par_ <- function(d, t) officer::body_add_par(d, t, style = "Normal")
    br_  <- function(d)    officer::body_add_par(d, "",  style = "Normal")
    pg_  <- function(d)    officer::body_add_break(d)
    
    # Delegates to pa_word_add_fig() [APP-G21]: handles ggplot AND plotly,
    # and inserts a visible note when a figure is missing (no silent skips).
    add_fig <- function(d, p, aspect = 0.60, label = NULL, max_h = 5.5, height_in = NULL, ...)
      pa_word_add_fig(d, p, cw = cw, aspect = aspect, label = label, max_h = max_h,
                      height_in = height_in, ...)
    
    n_c  <- format(nrow(filtered_data), big.mark = ",")
    n_b  <- if ("buyer_masterid"  %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_masterid,  na.rm = TRUE), big.mark = ",")
    else if ("buyer_id"   %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_id,        na.rm = TRUE), big.mark = ",")
    else if ("buyer_name" %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$buyer_name,      na.rm = TRUE), big.mark = ",")
    else "N/A"
    n_s  <- if ("bidder_masterid"  %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$bidder_masterid,  na.rm = TRUE), big.mark = ",")
    else if ("bidder_id"   %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$bidder_id,        na.rm = TRUE), big.mark = ",")
    else if ("supplier_name" %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$supplier_name, na.rm = TRUE), big.mark = ",")
    else if ("bidder_name"  %in% names(filtered_data)) format(dplyr::n_distinct(filtered_data$bidder_name,    na.rm = TRUE), big.mark = ",")
    else "N/A"
    yrs  <- if ("tender_year" %in% names(filtered_data)) {
      y <- sort(unique(filtered_data$tender_year[!is.na(filtered_data$tender_year)]))
      if (length(y) > 1) paste0(min(y), "–", max(y)) else as.character(y[1])
    } else "N/A"
    
    doc <- h1_(doc, "Procurement Integrity Analysis Report")
    doc <- par_(doc, paste("Country:", country_code))
    doc <- par_(doc, paste("Date:", format(Sys.Date(), "%B %d, %Y")))
    if (nchar(filters_text) > 0) { doc <- h2_(doc, "Applied Filters"); doc <- par_(doc, filters_text) }
    doc <- pg_(doc)
    
    # ── 1. Executive Summary ──────────────────────────────────────────
    doc <- h1_(doc, "1. Executive Summary")
    doc <- par_(doc, paste0(
      "Procurement integrity assessment for ", country_code, ". Covers ", n_c,
      " contracts, ", n_b, " buyers, ", n_s, " suppliers over years ", yrs, "."))
    overall_miss <- filtered_analysis$missing$overall_long
    high_miss <- if (!is.null(overall_miss)) sum(overall_miss$missing_share >= 0.20, na.rm = TRUE) else NA
    mod_miss  <- if (!is.null(overall_miss)) sum(overall_miss$missing_share >= 0.05 & overall_miss$missing_share < 0.20, na.rm = TRUE) else NA
    if (!is.na(high_miss))
      doc <- par_(doc, paste0("• Data Quality: ", high_miss, " variable(s) >20% missing; ", mod_miss, " in 5–20% range."))
    conc_data <- filtered_analysis$competition$concentration_yearly_data
    if (!is.null(conc_data) && nrow(conc_data) > 0) {
      max_conc <- max(conc_data$max_conc, na.rm = TRUE)
      doc <- par_(doc, paste0("• Concentration: highest buyer-year concentration ", scales::percent(max_conc, accuracy = 1), "."))
    }
    unusual_mat <- filtered_analysis$markets$unusual_matrix
    if (!is.null(unusual_mat) && nrow(unusual_mat) > 0)
      doc <- par_(doc, paste0("• Unusual Market Entries: ", nrow(unusual_mat), " cross-market routes detected."))
    doc <- pg_(doc)
    
    # ── 2. Data Overview ──────────────────────────────────────────────
    doc <- h1_(doc, "2. Data Overview")
    ov  <- data.frame(Indicator = c("Total contracts","Unique buyers","Unique suppliers","Years covered"),
                      Value     = c(n_c, n_b, n_s, yrs), stringsAsFactors = FALSE)
    ft_ov <- flextable::flextable(ov) %>% flextable::theme_booktabs() %>% flextable::autofit()
    doc   <- flextable::body_add_flextable(doc, ft_ov); doc <- br_(doc)
    
    if (!is.null(overall_miss) && nrow(overall_miss) > 0) {
      doc <- h2_(doc, "Variable Completeness")
      miss_tbl <- overall_miss %>%
        dplyr::arrange(dplyr::desc(missing_share)) %>%
        dplyr::mutate(Variable = variable,
                      `Missing Share` = scales::percent(missing_share, accuracy = 0.1),
                      Severity = dplyr::case_when(missing_share >= 0.20 ~ "High (>20%)",
                                                  missing_share >= 0.05 ~ "Moderate", TRUE ~ "Low (<5%)")) %>%
        dplyr::select(Variable, `Missing Share`, Severity)
      ft_miss <- flextable::flextable(as.data.frame(miss_tbl)) %>% flextable::theme_booktabs() %>% flextable::autofit()
      doc <- flextable::body_add_flextable(doc, ft_miss)
    }
    doc <- pg_(doc)
    
    # ── 3. Missing Values Analysis ────────────────────────────────────
    doc <- h1_(doc, "3. Missing Values Analysis")
    # Heights follow the number of variables shown (mirrors the app's dynamic
    # sizing) so tall charts are not squeezed into a fixed aspect ratio.
    n_ov <- nrow(filtered_analysis$missing$overall_long %||% data.frame())
    doc <- add_fig(doc, filtered_analysis$missing$overall_plot,
                   height_in = max(3.5, min(8.5, n_ov * 0.17 + 0.8)),
                   label = "Overall Missing Values")
    n_gv <- min(20, length(filtered_analysis$missing$by_buyer_var_order %||% character(0)))
    doc <- add_fig(doc, filtered_analysis$missing$by_buyer_plot,
                   height_in = max(3.5, min(8, n_gv * 0.30 + 1)),
                   label = "Missing Values by Buyer Type")
    n_pv <- min(20, length(filtered_analysis$missing$by_procedure_var_order %||% character(0)))
    doc <- add_fig(doc, filtered_analysis$missing$by_procedure_plot,
                   height_in = max(3.5, min(8, n_pv * 0.30 + 1)),
                   label = "Missing Values by Procedure Type")
    n_yv <- min(20, length(filtered_analysis$missing$by_year_var_order %||% character(0)))
    doc <- add_fig(doc, filtered_analysis$missing$by_year_plot,
                   height_in = max(3.5, min(8, n_yv * 0.30 + 1)),
                   label = "Missing Values Over Time")
    adv_note <- "Not available — run the Advanced Missingness Tests in the Missing Values tab (re-run after changing filters), then regenerate this report."
    doc <- add_fig(doc, filtered_analysis$missing$cooccurrence_plot, aspect = 0.65,
                   label = "Co-occurrence of Missing Values", max_h = 5.5, missing_note = adv_note)
    doc <- add_fig(doc, filtered_analysis$missing$mar_plot, aspect = 0.65,
                   label = "MAR Pattern Analysis", max_h = 5.5, missing_note = adv_note)
    doc <- pg_(doc)
    
    # ── 4. Interoperability ───────────────────────────────────────────
    doc <- h1_(doc, "4. Interoperability")
    org_miss <- filtered_analysis$interoperability$org_missing
    if (!is.null(org_miss) && nrow(org_miss) > 0) {
      tbl <- org_miss %>%
        dplyr::mutate(`Missing Share` = scales::percent(missing_share, accuracy = 0.1)) %>%
        dplyr::select(`Organization Type` = organization_type, `ID Type` = id_type, `Missing Share`)
      ft_org <- flextable::flextable(as.data.frame(tbl)) %>% flextable::theme_booktabs() %>% flextable::autofit()
      doc <- flextable::body_add_flextable(doc, ft_org)
    } else {
      doc <- par_(doc, "Interoperability data not available.")
    }
    doc <- pg_(doc)
    
    # ── 5. Market Competition & Unusual Entry Analysis ────────────────
    doc <- h1_(doc, "5. Market Competition & Unusual Market Entry Analysis")
    
    net_note <- "Not available — run the Network Analysis in the Risky Profiles tab (re-run after changing filters), then regenerate this report."
    doc <- add_fig(doc, filtered_analysis$markets$supplier_unusual_plot, aspect = 0.60,
                   label = "Unusual Supplier Entries", max_h = 5, missing_note = net_note)
    doc <- add_fig(doc, filtered_analysis$markets$market_unusual_plot,   aspect = 0.60,
                   label = "Most-Affected Markets",    max_h = 5, missing_note = net_note)
    
    # Flow matrix + network graph (both derived from the unusual-entry matrix)
    if (!is.null(unusual_mat) && nrow(unusual_mat) > 0) {
      fm <- pa_build_flow_matrix(unusual_mat)
      if (!is.null(fm)) {
        doc <- add_fig(doc, fm$plot, label = "Supplier Flow Matrix (cross-market bidding)",
                       height_in = fm$height_in)
      } else {
        doc <- add_fig(doc, NULL, label = "Supplier Flow Matrix (cross-market bidding)",
                       missing_note = "Not available — no qualifying cross-market supplier flows (minimum 4 shared bidders).")
      }
      # build_network_graph_from_matrix() RETURNS a ggraph (ggplot) object
      # rather than drawing to the active device — it must be saved via
      # add_fig()/ggsave. (A base png() device wrapped around the call would
      # capture nothing and produce an invalid file.)
      p_net <- tryCatch({
        set.seed(42)
        build_network_graph_from_matrix(
          unusual_matrix = unusual_mat, min_bidders = 4, top_n = 20,
          cl_filter = NULL, country = country_code %||% "")
      }, error = function(e) NULL)
      doc <- add_fig(doc, p_net, label = "Supplier Network Graph",
                     height_in = 5.5, render_scale = 1.3,
                     missing_note = "Not available — no qualifying cross-market supplier flows (minimum 4 shared bidders).")
    } else {
      doc <- h2_(doc, "Supplier Flow Matrix & Network Graph")
      doc <- par_(doc, net_note)
    }
    doc <- pg_(doc)
    
    # ── 6. Supplier Concentration Over Time ──────────────────────────
    # NOTE: build_concentration_yearly_plot() [APP-G04] returns a NATIVE
    # PLOTLY object — it must be rendered via add_fig()/pa_save_plot_any()
    # (webshot2), never passed to ggsave().
    doc <- h1_(doc, "6. Top Buyers by Supplier Concentration Over Time")
    conc_data <- filtered_analysis$competition$concentration_yearly_data
    if (!is.null(conc_data) && nrow(conc_data) > 0) {
      p_conc <- tryCatch(build_concentration_yearly_plot(
        yearly_data = conc_data, n_buyers = 10, min_contracts = 1,
        country = country_code %||% ""), error = function(e) NULL)
      n_years <- dplyr::n_distinct(conc_data$tender_year)
      n_cols  <- min(max(n_years, 1), 3)
      n_rows  <- ceiling(n_years / n_cols)
      doc <- add_fig(doc, p_conc, height_in = min(7, max(3.5, n_rows * 2.8)),
                     missing_note = "Not available — the concentration plot could not be built for the current filters.")
    } else {
      doc <- par_(doc, "Not available — no buyer-year concentration data for the current filters.")
    }
    doc <- pg_(doc)
    
    # ── 7. Effect on Prices and Competition (Regressions) ────────────
    doc <- h1_(doc, "7. Effect on Prices and Competition")
    doc <- par_(doc, "Regression results showing the effect of missing data and market structure on competition and prices.")
    reg_note <- "Not available — run the regressions in the integrity Regression tab (re-run after changing filters), then regenerate this report."
    # singleb_plot may live in $prices or $competition (observer stores both)
    singleb_plot  <- filtered_analysis$prices$singleb_plot %||%
      filtered_analysis$competition$singleb_plot
    relprice_plot <- filtered_analysis$prices$rel_price_plot
    # render_scale = 1.5 renders the plots on a 1.5x canvas so their (large,
    # spec-grid) text fits the page instead of overflowing it
    doc <- add_fig(doc, singleb_plot,  aspect = 0.70, label = "Single-Bidding vs. Missing Data Share",
                   max_h = 6, render_scale = 1.5, missing_note = reg_note)
    doc <- add_fig(doc, relprice_plot, aspect = 0.70, label = "Relative Prices vs. Missing Data Share",
                   max_h = 6, render_scale = 1.5, missing_note = reg_note)
    doc <- pg_(doc)
    
    # ── 8. Conclusions ────────────────────────────────────────────────
    doc <- h1_(doc, "8. Conclusions")
    doc <- par_(doc, paste0(
      "Report generated on ", format(Sys.Date(), "%B %d, %Y"),
      ". All findings are statistical indicators and should be interpreted with domain knowledge."))
    
    print(doc, target = output_file)
    TRUE
  }, error = function(e) {
    message("Integrity Word report FAILED: ", e$message)
    message("  Call stack: ", paste(capture.output(traceback()), collapse=" | "))
    FALSE
  })
}




# [APP-G23] safe_pipeline_config() — defensive config builder with a manual fallback ────
# Builds the integrity pipeline configuration. If create_pipeline_config()
# errors for any reason, the config is rebuilt manually with conservative
# year windows so the pipeline can always run.
safe_pipeline_config <- function(country_code) {
  # First attempt: call create_pipeline_config normally
  cfg <- tryCatch(create_pipeline_config(country_code), error = function(e) e)
  if (!inherits(cfg, "error")) return(cfg)
  
  # Fallback: create_pipeline_config() failed (e.g. an incompatible
  # get_year_range() in a modified utils file). Rebuild the config manually,
  # requesting only the universally supported "singleb"/"default" components.
  message("create_pipeline_config failed (", cfg$message, "); rebuilding config safely")
  yr_default  <- tryCatch(get_year_range(country_code, "default"),  error = function(e) list(min_year=-Inf, max_year=Inf))
  yr_singleb  <- tryCatch(get_year_range(country_code, "singleb"),  error = function(e) list(min_year=-Inf, max_year=Inf))
  yr_relprice <- tryCatch(get_year_range(country_code, "rel_price"),error = function(e) yr_singleb)
  list(
    country    = toupper(country_code),
    thresholds = list(
      min_buyer_contracts=100, min_suppliers_for_buyer_conc=3,
      min_buyer_years=3, cpv_digits=3, min_bidders_for_edge=4,
      top_n_buyers=30, top_n_suppliers=30, top_n_markets=30,
      top_n_vars=10, marginal_share_threshold=0.05,
      max_wins_atypical=3, min_history_threshold=4,
      max_relative_price=5, min_relative_price=0
    ),
    years          = yr_default,
    years_singleb  = yr_singleb,
    years_relprice = yr_relprice,
    models = list(
      p_max=0.10,
      fe_set=c("buyer","year","buyer+year","buyer#year"),
      cluster_set=c("none","buyer","year","buyer_year","buyer_buyertype"),
      controls_set=c("x_only","base","base_extra"),
      model_types_relprice=c("ols_level","ols_log","gamma_log")
    ),
    plots = list(width=10, height=6, width_large=12, height_large=12, dpi=300, base_size=14)
  )
}


# [APP-G24] INTEGRITY PIPELINE RUNNER: run_integrity_pipeline_fast_local() — the version the app actually calls ────
# ========================================================================
# INTEGRITY PIPELINE RUNNER (global scope — called by run_analysis + apply_integ_filters)
# ========================================================================
run_integrity_pipeline_fast_local <- function(df, country_code, output_dir = tempdir()) {
  # Build config — guard against older integrity_utils that lack "rel_price" in get_year_range
  config <- safe_pipeline_config(country_code)
  tryCatch(ensure_output_directory(output_dir), error = function(e) NULL)
  df <- tryCatch(prepare_data(df), error = function(e) { message("prepare_data failed: ", e$message); df })
  list(
    config           = config,
    data             = df,
    data_quality     = tryCatch(check_data_quality(df, config),            error = function(e) NULL),
    summary_stats    = tryCatch(log_summary_stats(df, config, output_dir),  error = function(e) NULL),
    missing          = safely_run_module(analyze_missing_values,   df, config, output_dir, save_plots = FALSE),
    interoperability = safely_run_module(analyze_interoperability, df, config, output_dir),
    competition      = safely_run_module(analyze_competition,      df, config, output_dir, save_plots = FALSE),
    markets          = list(network_plot = NULL, flow_matrix_plot = NULL,
                            supplier_unusual_plot = NULL, market_unusual_plot = NULL),
    prices           = list(singleb_plot = NULL, rel_price_plot = NULL,
                            singleb_sensitivity = NULL, relprice_sensitivity = NULL)
  )
}
