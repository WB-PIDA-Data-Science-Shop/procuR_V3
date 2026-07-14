# ============================================================================
# SHARED UTILITIES — utils_shared.R
# ============================================================================
# Helpers used by all three analysis sections, and the single home of every
# function that more than one module needs (regression/sensitivity suite,
# year-window config, recode, …). Sourced FIRST; nothing sourced later
# redefines anything in this file (see DEVELOPER_GUIDE.md §2).
#
# NAVIGATION: every section below is tagged with a unique anchor code in
# square brackets, e.g. [SH-05]. Search (Ctrl+F / grep) for the code to
# jump straight to that section. Codes are stable; line numbers are not.
#
# TABLE OF CONTENTS
# -----------------
#   [SH-01]  OPERATORS: %ni%, %||%
#   [SH-02]  CPV LABEL LOOKUP TABLE (CPV_DESCRIPTIONS)
#   [SH-03]  get_cpv_label() — 2-digit CPV code → human label
#   [SH-04]  get_filter_description() — filters → caption text
#   [SH-05]  VALUE FORMATTING (fmt_value, fmt_value_log)
#   [SH-06]  load_data() — batch-mode CSV reader (single copy)
#   [SH-07]  recode_procedure_type() — canonical (.CANONICAL_RECODE)
#   [SH-08]  normalize_procurement_data() — canonical column aliases
#   [SH-09]  add_buyer_group() — canonical
#   [SH-10]  add_tender_year() — year from first available date column
#   [SH-11]  dir_ensure()
#   [SH-12]  YEAR WINDOW CONFIG (year_filter_config, get_year_range) — canonical
#   [SH-13]  FIXEST BUILDING BLOCKS (make_fe_part, make_cluster, safe_fixest,
#            extract_effect_fixest, effect_p10_p90) — canonical
#   [SH-14]  pick_best_model() — canonical preferred-spec selector
#   [SH-15]  SENSITIVITY / ROBUSTNESS SUITE (add_strength_column, summarise_*,
#            classify_specs, top_cells, build_sensitivity_bundle) — canonical
#
# ============================================================================

# ========================================================================
# SHARED UTILITIES — Unified Procurement Analysis App
# ========================================================================
# Functions used by both the Economic Outcomes and Administrative
# Efficiency sections of the app.
# ========================================================================


# [SH-01] OPERATORS: %ni%, %||% ──────────────────────────────────────────────
`%ni%` <- Negate(`%in%`)
`%||%` <- function(a, b) if (!is.null(a)) a else b

# ========================================================================
# CPV LABEL LOOKUP
# ========================================================================


# [SH-02] CPV LABEL LOOKUP TABLE (CPV_DESCRIPTIONS) ──────────────────────────
CPV_DESCRIPTIONS <- c(
  "03" = "Agricultural products",       "09" = "Petroleum, fuel, electricity",
  "14" = "Mining products",             "15" = "Food, beverages, tobacco",
  "16" = "Agricultural machinery",      "18" = "Clothing, footwear",
  "19" = "Leather, textile products",   "22" = "Printed matter",
  "24" = "Chemical products",           "30" = "Office/computing machinery",
  "31" = "Electrical machinery",        "32" = "Radio, TV, communication",
  "33" = "Medical equipment",           "34" = "Transport equipment",
  "35" = "Security equipment",          "37" = "Musical instruments",
  "38" = "Laboratory equipment",        "39" = "Furniture",
  "41" = "Collected water",             "42" = "Industrial machinery",
  "43" = "Mining/extraction machinery", "44" = "Construction structures",
  "45" = "Construction work",           "48" = "Software packages",
  "50" = "Repair/maintenance",          "51" = "Installation services",
  "55" = "Hotel/restaurant services",   "60" = "Transport services",
  "63" = "Supporting transport",        "64" = "Postal/telecom services",
  "65" = "Utility services",            "66" = "Financial services",
  "70" = "Real estate services",        "71" = "Architectural services",
  "72" = "IT services",                 "73" = "Research services",
  "75" = "Administration services",     "76" = "Services to oil/gas",
  "77" = "Agricultural services",       "79" = "Business services",
  "80" = "Education/training",          "85" = "Health/social services",
  "90" = "Sewage/refuse services",      "92" = "Recreational services",
  "98" = "Other services",              "99" = "Other"
)








# [SH-03] get_cpv_label() — 2-digit CPV code → human label ───────────────────
get_cpv_label <- function(code) {
  desc <- CPV_DESCRIPTIONS[as.character(code)]
  desc <- ifelse(is.na(desc), paste0("CPV ", code), desc)
  paste0(code, " - ", desc)
}

# ========================================================================
# FILTER HELPERS
# ========================================================================


# [SH-04] get_filter_description() — filters → caption text ──────────────────
get_filter_description <- function(filter_list) {
  parts <- c()
  if (!is.null(filter_list$year)           && length(filter_list$year) == 2)
    parts <- c(parts, paste0("Years: ", filter_list$year[1], "-", filter_list$year[2]))
  if (!is.null(filter_list$market)         && length(filter_list$market) > 0 && "All" %ni% filter_list$market)
    parts <- c(parts, paste0("Markets: ", paste(filter_list$market, collapse = ", ")))
  if (!is.null(filter_list$value)          && length(filter_list$value) == 2)
    parts <- c(parts, "Value range applied")
  if (!is.null(filter_list$buyer_type)     && length(filter_list$buyer_type) > 0 && "All" %ni% filter_list$buyer_type)
    parts <- c(parts, paste0("Buyer types: ", paste(filter_list$buyer_type, collapse = ", ")))
  if (!is.null(filter_list$procedure_type) && length(filter_list$procedure_type) > 0 && "All" %ni% filter_list$procedure_type)
    parts <- c(parts, paste0("Procedures: ", paste(filter_list$procedure_type, collapse = ", ")))
  if (length(parts) == 0) return("No filters applied")
  paste(parts, collapse = "; ")
}

# ========================================================================
# VALUE SCALE HELPERS
# ========================================================================


# [SH-05] VALUE FORMATTING (fmt_value, fmt_value_log) ────


fmt_value <- function(v) {
  dplyr::case_when(
    v >= 1e9 ~ paste0(round(v / 1e9, 1), "B"),
    v >= 1e6 ~ paste0(round(v / 1e6, 1), "M"),
    v >= 1e3 ~ paste0(round(v / 1e3, 1), "K"),
    TRUE     ~ as.character(round(v))
  )
}

fmt_value_log <- function(lv) fmt_value(10^lv)

# ========================================================================
# DATA LOADING (shared — identical needs in econ + admin utils)
# ========================================================================


# [SH-06] load_data() — batch-mode CSV reader (single copy; the app upload has its own reader in [APP-SV03]) ────
load_data <- function(input_path) {
  data <- data.table::fread(
    input            = input_path,
    keepLeadingZeros = TRUE,
    encoding         = "UTF-8",
    stringsAsFactors = FALSE,
    showProgress     = TRUE,
    na.strings       = c("", "-", "NA")
  )
  dup_cols <- duplicated(names(data))
  if (any(dup_cols)) data <- data[, !dup_cols, with = FALSE]
  # Coerce IDate/Date columns to character so str_extract works
  # regardless of data.table version (>= 1.14.3 auto-detects dates)
  # Use data.table::set() to avoid df[char_vec] being misread as a join
  date_like_cols <- names(data)[sapply(data, function(x) inherits(x, c("IDate", "Date", "POSIXct", "POSIXlt")))]
  for (col in date_like_cols) data.table::set(data, j = col, value = as.character(data[[col]]))
  data
}

# ========================================================================
# PROCEDURE TYPE RECODING (canonical — used by all three pipelines)
# ========================================================================


# [SH-07] recode_procedure_type() — canonical (.CANONICAL_RECODE) ────
# Canonical procedure-type recode. Keeps unrecognised raw values as-is
# instead of collapsing them into "Other", so country-specific procedure
# labels remain visible in every chart and table.
.CANONICAL_RECODE <- function(x) {
  LUT <- c(
    OPEN="Open Procedure", RESTRICTED="Restricted Procedure",
    NEGOTIATED_WITH_PUBLICATION="Negotiated with publications",
    NEGOTIATED_WITHOUT_PUBLICATION="Negotiated without publications",
    NEGOTIATED="Negotiated (unspecified)",
    COMPETITIVE_DIALOG="Competitive Dialogue",
    INNOVATION_PARTNERSHIP="Innovation Partnership",
    OUTRIGHT_AWARD="Direct Award", OTHER="Other",
    # pass-through already-recoded labels
    "Open Procedure"="Open Procedure",
    "Restricted Procedure"="Restricted Procedure",
    "Negotiated with publications"="Negotiated with publications",
    "Negotiated without publications"="Negotiated without publications",
    "Negotiated (unspecified)"="Negotiated (unspecified)",
    "Negotiated"="Negotiated (unspecified)",
    "Competitive Dialogue"="Competitive Dialogue",
    "Competitive Dialog"="Competitive Dialogue",
    "Innovation Partnership"="Innovation Partnership",
    "Direct Award"="Direct Award",
    "Other"="Other", "Other Procedures"="Other"
  )
  raw <- as.character(x)
  idx <- match(raw, names(LUT))
  out <- LUT[idx]
  # Preserve unrecognised raw values as-is instead of collapsing to "Other"
  out[is.na(idx) & !is.na(x)] <- raw[is.na(idx) & !is.na(x)]
  out[is.na(x)]                <- NA_character_
  unname(out)
}

recode_procedure_type <- function(x) .CANONICAL_RECODE(x)

# ========================================================================
# DATA NORMALISATION — column aliasing for limited / national datasets
# ========================================================================


# [SH-08] normalize_procurement_data() — canonical column aliases ────────────
#' Normalise procurement data to the canonical column structure expected by
#' all three analysis pipelines.
#'
#' This function is ADDITIVE: it never overwrites a column that already
#' exists.  It creates missing standard columns by looking for common
#' alternative names used in national / limited datasets.
#'
#' Columns created when absent:
#'   buyer_masterid  ← buyer_id
#'   buyer_buyertype ← entity_type | buyer_type | contracting_authority_type
#'   bidder_masterid ← bidder_id | bidder_name | supplier_name | winner_name
#'   lot_productcode ← cpv_code | cpv | lot_cpvcode | product_code
#'   bid_priceusd    ← bid_price  (copied as-is; conversion not attempted)
#'
#' @param df   Data frame straight from fread / CSV upload
#' @return     Data frame with additional alias columns (if needed)
normalize_procurement_data <- function(df) {
  
  # buyer_masterid — used for buyer FE and concentration analysis
  if (!"buyer_masterid" %in% names(df) && "buyer_id" %in% names(df))
    df$buyer_masterid <- as.character(df$buyer_id)
  
  # buyer_buyertype — used for buyer group plots and controls
  if (!"buyer_buyertype" %in% names(df)) {
    for (.alt in c("entity_type", "buyer_type", "contracting_authority_type",
                   "buyer_entity_type", "entity_category")) {
      if (.alt %in% names(df)) {
        df$buyer_buyertype <- as.character(df[[.alt]])
        break
      }
    }
  }
  
  # bidder_masterid — used for supplier entry, networks, concentration
  if (!"bidder_masterid" %in% names(df)) {
    for (.alt in c("bidder_id", "bidder_name", "supplier_name",
                   "winner_name", "bidder_normalizedname")) {
      if (.alt %in% names(df)) {
        df$bidder_masterid <- as.character(df[[.alt]])
        break
      }
    }
  }
  
  # lot_productcode — used for CPV/market analysis
  if (!"lot_productcode" %in% names(df)) {
    for (.alt in c("cpv_code", "cpv", "lot_cpvcode", "product_code", "sector_code")) {
      if (.alt %in% names(df)) {
        df$lot_productcode <- as.character(df[[.alt]])
        break
      }
    }
  }
  
  # bid_priceusd — used as the USD price column by most plots; if only a
  # local-currency price column exists, copy it so downstream code has
  # *something* to work with (no exchange-rate conversion is attempted).
  if (!"bid_priceusd" %in% names(df) && "bid_price" %in% names(df))
    df$bid_priceusd <- suppressWarnings(as.numeric(df$bid_price))
  
  df
}

# ========================================================================
# BUYER GROUPING (shared — identical in econ + admin utils)
# ========================================================================


# [SH-09] add_buyer_group() — buyer-type grouping ─────
add_buyer_group <- function(buyer_buyertype) {
  group <- dplyr::case_when(
    grepl("(?i)national", buyer_buyertype) ~ "National Buyer",
    grepl("(?i)regional", buyer_buyertype) ~ "Regional Buyer",
    grepl("(?i)utilities", buyer_buyertype) ~ "Utilities",
    grepl("(?i)European", buyer_buyertype) ~ "EU agency",
    TRUE ~ "Other Public Bodies"
  )
  
  factor(
    group,
    levels = c(
      "National Buyer",
      "Regional Buyer",
      "Utilities",
      "EU agency",
      "Other Public Bodies"
    )
  )
}

# ========================================================================
# TENDER YEAR EXTRACTION (shared — flexible version)
# ========================================================================


# [SH-10] add_tender_year() — year from first available date column ──────────
add_tender_year <- function(df,
                            date_cols = c(
                              "tender_publications_firstcallfortenderdate",
                              "tender_awarddecisiondate",
                              "tender_biddeadline"
                            )) {
  get_year <- function(x) stringr::str_extract(as.character(x), "^\\d{4}")
  cols_present <- intersect(date_cols, names(df))
  if (length(cols_present) == 0) { df$tender_year <- NA_integer_; return(df) }
  year_vec <- purrr::reduce(
    cols_present,
    .init = rep(NA_character_, nrow(df)),
    .f    = function(acc, col) dplyr::coalesce(acc, get_year(df[[col]]))
  )
  df %>% dplyr::mutate(tender_year = as.integer(year_vec))
}

# ========================================================================
# DIRECTORY HELPER (shared)
# ========================================================================


# [SH-11] dir_ensure() ───────────────────────────────────────────────────────
dir_ensure <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

# ========================================================================
# WORD REPORT HELPERS (shared — avoids repeating inside each report fn)
# ========================================================================

# [SH-12] YEAR WINDOW CONFIG (year_filter_config, get_year_range) — canonical ────
# ========================================================================
# Single source of truth for analysis year windows. get_year_range() accepts
# component = "singleb", "rel_price" or "default"; a country/component with
# no row falls back to that country's "default" row, and NA bounds mean
# unbounded. Used by both the admin and integrity pipelines.
# ========================================================================

# Component-specific year windows per country (NA = unbounded).
# The rel_price rows deliberately MIRROR the singleb rows: relative-price
# analyses use the same year windows as single-bidding analyses. To give
# price analyses their own windows, edit the rel_price rows — knowingly:
# that changes which years feed the integrity price analysis.
year_filter_config <- tibble::tribble(
  ~component,  ~country_code, ~min_year, ~max_year,
  "default",   "BG",          NA,        NA,
  "default",   "UY",          NA,        NA,
  "default",   "ID",          NA,        NA,
  "default",   "UG",          NA,        NA,
  "singleb",   "BG",          2011,      2018,
  "singleb",   "UY",          2014,      NA,
  "singleb",   "ID",          2012,      2018,
  "singleb",   "UG",          NA,        NA,
  "rel_price", "BG",          2011,      2018,
  "rel_price", "UY",          2014,      NA,
  "rel_price", "ID",          2012,      2018,
  "rel_price", "UG",          NA,        NA
)

get_year_range <- function(country_code,
                           component = c("singleb", "rel_price", "default")) {
  component <- match.arg(component)
  cc <- toupper(country_code)
  
  # Try component-specific rule
  row_spec <- year_filter_config %>%
    dplyr::filter(component == !!component, country_code == !!cc) %>%
    dplyr::slice_head(n = 1)
  
  # Fall back to default for that country
  if (nrow(row_spec) == 0) {
    row_spec <- year_filter_config %>%
      dplyr::filter(component == "default", country_code == !!cc) %>%
      dplyr::slice_head(n = 1)
  }
  
  # If still nothing, no filtering
  if (nrow(row_spec) == 0) {
    return(list(min_year = -Inf, max_year = Inf))
  }
  
  min_y <- if (is.na(row_spec$min_year)) -Inf else row_spec$min_year
  max_y <- if (is.na(row_spec$max_year)) Inf else row_spec$max_year
  
  list(min_year = min_y, max_year = max_y)
}


# [SH-13] FIXEST BUILDING BLOCKS ──────────────────────────────────────
# ========================================================================
# make_fe_part / make_cluster / safe_fixest / extract_effect_fixest /
# effect_p10_p90: formula fragments for fixed effects and clustering,
# error-safe estimation, tidy extraction of the focal coefficient, and the
# p10→p90 predicted-outcome effect. Used by both the admin and integrity
# regression stacks. (integrity_utils adds its own vcov-robustness helpers:
# extract_effect_fixest_vcov, get_default_vcov_menu, robustness_summary.)
# ========================================================================

make_fe_part <- function(fe) {
  switch(fe,
         "0"          = "0",
         "buyer"      = "buyer_id",
         "year"       = "tender_year",
         "buyer+year" = "buyer_id + tender_year",
         "buyer#year" = "buyer_id^tender_year",
         stop("Unknown FE spec: ", fe)
  )
}

make_cluster <- function(cluster) {
  switch(cluster,
         "none"            = NULL,
         "buyer"           = stats::as.formula("~ buyer_id"),
         "year"            = stats::as.formula("~ tender_year"),
         "buyer_year"      = stats::as.formula("~ buyer_id + tender_year"),
         "buyer_buyertype" = stats::as.formula("~ buyer_id + buyer_buyertype"),
         stop("Unknown cluster spec: ", cluster)
  )
}

safe_fixest <- function(expr) tryCatch(expr, error = function(e) NULL)

extract_effect_fixest <- function(model, x_name, data_used, y_name = NULL) {
  s  <- tryCatch(summary(model), error = function(e) NULL)
  if (is.null(s)) return(list(estimate = NA_real_, pvalue = NA_real_, nobs = NA_integer_, std_slope = NA_real_))
  ct <- s$coeftable
  if (is.null(ct) || !(x_name %in% rownames(ct)))
    return(list(estimate = NA_real_, pvalue = NA_real_, nobs = s$nobs, std_slope = NA_real_))
  est <- as.numeric(ct[x_name, "Estimate"])
  # Safely detect p-value column: feols uses "Pr(>|t|)", feglm uses "Pr(>|z|)"
  p_col <- intersect(c("Pr(>|t|)", "Pr(>|z|)"), colnames(ct))
  pv  <- if (length(p_col) > 0) as.numeric(ct[x_name, p_col[1]]) else NA_real_
  list(estimate = est, pvalue = pv, nobs = s$nobs,
       std_slope = est * stats::sd(data_used[[x_name]], na.rm = TRUE))
}

effect_p10_p90 <- function(model, data_used, x_name) {
  qs   <- stats::quantile(data_used[[x_name]], probs = c(.1, .9), na.rm = TRUE)
  typical <- data_used[1, , drop = FALSE]
  for (nm in names(typical)) {
    if (nm == x_name) next
    v <- data_used[[nm]]
    if (is.numeric(v)) typical[[nm]] <- stats::median(v, na.rm = TRUE)
    else if (is.factor(v) || is.character(v)) {
      tab <- sort(table(v), decreasing = TRUE)
      typical[[nm]] <- names(tab)[1]
      if (is.factor(v)) typical[[nm]] <- factor(typical[[nm]], levels = levels(v))
    }
  }
  d_lo <- typical; d_lo[[x_name]] <- unname(qs[1])
  d_hi <- typical; d_hi[[x_name]] <- unname(qs[2])
  as.numeric(
    suppressWarnings(stats::predict(model, newdata = d_hi, type = "response")) -
      suppressWarnings(stats::predict(model, newdata = d_lo, type = "response"))
  )
}


# [SH-14] pick_best_model() — canonical preferred-spec selector ────────────
# ========================================================================
# Selects the preferred specification from a spec-grid results table using
# sign/significance preferences with diagnostic-based fallbacks.
# (integrity_utils additionally provides pick_most_robust_model() and
# model_diagnostics().)
# ========================================================================

pick_best_model <- function(results_df, require_positive = TRUE, p_max = 0.10,
                            strength_col = c("effect_strength", "std_slope"),
                            preferred_model = "fractional_logit") {
  # Econometric model selection based on regression diagnostics:
  #
  # Hard filters:
  #   - Must have converged
  #   - Must retain >= 20% of observations after FE/singleton removal
  #
  # Diagnostic scoring (penalty-based):
  #   - DV-model appropriateness: is this model type valid for the outcome?
  #   - Heteroskedasticity proxy (LPM): out-of-range predictions [0,1] signal misspecification
  #   - Multicollinearity: variables dropped by fixest due to perfect collinearity
  #   - Effective sample: low retention after FE = over-fitted / too granular
  #   - Controls & clustering: standard econometric practice for panel data
  #
  # Among top-scoring specs: pick closest to median estimate (specification curve; Simonsohn et al. 2020)
  
  strength_col <- match.arg(strength_col)
  df <- results_df
  if (require_positive) df <- df[df$estimate > 0, , drop = FALSE]
  df <- df[!is.na(df$pvalue) & df$pvalue <= p_max, , drop = FALSE]
  df <- df[!is.na(df[[strength_col]]),              , drop = FALSE]
  if (nrow(df) == 0) return(NULL)
  
  # Hard filters
  if ("converged" %in% names(df))
    df <- df[is.na(df$converged) | df$converged == TRUE, , drop = FALSE]
  if ("pct_retained" %in% names(df))
    df <- df[is.na(df$pct_retained) | df$pct_retained >= 0.20, , drop = FALSE]
  if (nrow(df) == 0) return(NULL)
  
  # Diagnostic scoring (start at 10, deduct penalties)
  df$.score <- 10L
  
  # (1) DV-model appropriateness: preferred model gets no penalty, others get -2
  if ("model_type" %in% names(df))
    df$.score <- df$.score - ifelse(df$model_type == preferred_model, 0L, 2L)
  
  # (2) Heteroskedasticity / misspecification (LPM out-of-range predictions)
  if ("out_of_range_pct" %in% names(df))
    df$.score <- df$.score - dplyr::case_when(
      is.na(df$out_of_range_pct)     ~ 0L,   # non-LPM models
      df$out_of_range_pct <= 0.05    ~ 0L,   # acceptable (<5%)
      df$out_of_range_pct <= 0.15    ~ 1L,   # mild heteroskedasticity concern
      TRUE                            ~ 3L    # severe — LPM inappropriate here
    )
  
  # (3) Multicollinearity: penalise models that dropped variables
  if ("n_collinear" %in% names(df))
    df$.score <- df$.score - dplyr::case_when(
      is.na(df$n_collinear) | df$n_collinear == 0 ~ 0L,
      df$n_collinear <= 2                           ~ 1L,
      df$n_collinear <= 5                           ~ 2L,
      TRUE                                          ~ 3L   # severe collinearity
    )
  
  # (4) Effective sample: penalise low retention after FE/singleton removal
  if ("pct_retained" %in% names(df))
    df$.score <- df$.score - dplyr::case_when(
      is.na(df$pct_retained) | df$pct_retained >= 0.70 ~ 0L,
      df$pct_retained >= 0.50                            ~ 1L,
      TRUE                                               ~ 2L
    )
  
  # (5) Controls: no controls = omitted variable bias risk
  df$.score <- df$.score - ifelse(df$controls == "x_only", 2L, 0L)
  
  # (6) Clustering: no clustering = wrong SEs for panel data
  df$.score <- df$.score - ifelse(df$cluster == "none", 1L, 0L)
  
  # Select top-scoring tier (within 1 point of max)
  max_score <- max(df$.score, na.rm = TRUE)
  top_tier  <- df[df$.score >= max_score - 1L, , drop = FALSE]
  
  # Among top tier: pick closest to median estimate
  med_est        <- stats::median(top_tier$estimate, na.rm = TRUE)
  top_tier$.dist <- abs(top_tier$estimate - med_est)
  top_tier       <- top_tier[order(top_tier$.dist), , drop = FALSE]
  
  best <- top_tier[1, , drop = FALSE]
  best$.score <- best$.dist <- NULL
  best[["rank"]] <- 1L
  best
}


# [SH-15] SENSITIVITY / ROBUSTNESS SUITE ──────────────────────────────
# ========================================================================
# add_strength_column, summarise_* (overall / sign / by FE / cluster /
# controls), classify_specs, top_cells, build_sensitivity_bundle: turn a
# specification-grid results table into the robustness summaries shown in
# the app. Used by all four regression exercises.
# ========================================================================

add_strength_column <- function(specs) {
  if (is.null(specs) || nrow(specs) == 0L) return(specs)
  if ("effect_strength" %in% names(specs))  specs$strength <- specs$effect_strength
  else if ("std_slope"  %in% names(specs))  specs$strength <- specs$std_slope
  else                                       specs$strength <- NA_real_
  specs
}

summarise_sensitivity_overall <- function(specs, p_levels = c(0.05, 0.10, 0.20)) {
  if (is.null(specs) || nrow(specs) == 0L) return(tibble::tibble())
  specs <- add_strength_column(specs)
  tibble::tibble(
    n_specs         = nrow(specs),
    share_positive  = mean(specs$estimate > 0, na.rm = TRUE),
    share_negative  = mean(specs$estimate < 0, na.rm = TRUE),
    median_estimate = median(specs$estimate,   na.rm = TRUE),
    median_pvalue   = median(specs$pvalue,     na.rm = TRUE),
    median_strength = median(specs$strength,   na.rm = TRUE),
    !!!setNames(
      lapply(p_levels, function(p) mean(specs$pvalue <= p, na.rm = TRUE)),
      paste0("share_p_le_", p_levels)
    )
  )
}

summarise_sign_instability <- function(specs) {
  if (is.null(specs) || nrow(specs) == 0L) return(tibble::tibble())
  s <- sign(specs$estimate); s <- s[!is.na(s) & s != 0]
  tibble::tibble(
    share_sign_stable = if (length(s) == 0) NA_real_ else as.numeric(length(unique(s)) <= 1),
    n_nonzero = length(s)
  )
}

summarise_by_fe <- function(specs) {
  if (is.null(specs) || nrow(specs) == 0L) return(tibble::tibble())
  add_strength_column(specs) %>%
    dplyr::group_by(fe) %>%
    dplyr::summarise(n_specs = dplyr::n(), share_positive = mean(estimate > 0, na.rm = TRUE),
                     share_p10 = mean(pvalue <= 0.10, na.rm = TRUE), median_p = median(pvalue, na.rm = TRUE),
                     median_strength = median(strength, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(share_p10))
}

summarise_by_cluster <- function(specs) {
  if (is.null(specs) || nrow(specs) == 0L) return(tibble::tibble())
  add_strength_column(specs) %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(n_specs = dplyr::n(), share_positive = mean(estimate > 0, na.rm = TRUE),
                     share_p10 = mean(pvalue <= 0.10, na.rm = TRUE), median_p = median(pvalue, na.rm = TRUE),
                     median_strength = median(strength, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(median_p)
}

summarise_by_controls <- function(specs) {
  if (is.null(specs) || nrow(specs) == 0L) return(tibble::tibble())
  add_strength_column(specs) %>%
    dplyr::group_by(controls) %>%
    dplyr::summarise(n_specs = dplyr::n(), share_positive = mean(estimate > 0, na.rm = TRUE),
                     share_p10 = mean(pvalue <= 0.10, na.rm = TRUE), median_p = median(pvalue, na.rm = TRUE),
                     median_strength = median(strength, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(share_p10))
}

classify_specs <- function(specs, p_cut = 0.10) {
  if (is.null(specs) || nrow(specs) == 0L) return(tibble::tibble())
  specs %>%
    dplyr::mutate(class = dplyr::case_when(
      estimate > 0 & pvalue <= p_cut ~ "Positive & significant",
      estimate > 0                   ~ "Positive but insignificant",
      estimate < 0 & pvalue <= p_cut ~ "Negative & significant",
      estimate < 0                   ~ "Negative but insignificant",
      TRUE                           ~ "Missing/NA")) %>%
    dplyr::count(class) %>% dplyr::mutate(share = n / sum(n))
}

top_cells <- function(specs, p_cut = 0.10, n_top = 10) {
  if (is.null(specs) || nrow(specs) == 0L) return(tibble::tibble())
  specs %>%
    dplyr::mutate(p_ok = pvalue <= p_cut) %>%
    dplyr::group_by(fe, cluster, controls) %>%
    dplyr::summarise(n = dplyr::n(), share_pok = mean(p_ok, na.rm = TRUE),
                     median_p = median(pvalue, na.rm = TRUE), median_est = median(estimate, na.rm = TRUE),
                     .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(share_pok), median_p) %>% dplyr::slice_head(n = n_top)
}

build_sensitivity_bundle <- function(specs) {
  if (is.null(specs) || nrow(specs) == 0L) return(list())
  specs <- add_strength_column(specs)
  list(overall = summarise_sensitivity_overall(specs), sign = summarise_sign_instability(specs),
       by_fe = summarise_by_fe(specs), by_cluster = summarise_by_cluster(specs),
       by_controls = summarise_by_controls(specs), classes = classify_specs(specs),
       top_cells = top_cells(specs))
}
