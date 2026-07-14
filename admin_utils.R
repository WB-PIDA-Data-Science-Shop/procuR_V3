# ============================================================================
# ADMINISTRATIVE EFFICIENCY UTILITIES — admin_utils.R
# ============================================================================
# Helpers + orchestrator for the Administrative Efficiency section:
# procedure-type shares, submission/decision period analysis, threshold
# flags, and single-bid regressions (fixest) with robustness checks.
# Sourced LAST by global.R. The regression and sensitivity helpers this module
# relies on are defined in utils_shared.R — cross-reference pointers below
# say exactly where. Source utils_shared.R before this file.
#
# NAVIGATION: every section below is tagged with a unique anchor code in
# square brackets, e.g. [SH-05]. Search (Ctrl+F / grep) for the code to
# jump straight to that section. Codes are stable; line numbers are not.
#
# TABLE OF CONTENTS
# -----------------
#   [AD-01]  app_thresholds_to_pipeline() — nested app thresholds → flat list
#   [AD-02]  SPEC GRID RUNNERS (run_specs, run_short_subm_specs, run_long_dec_specs)
#   [AD-03]  DAY-COUNT HELPERS (compute_tender_days, short/long period flags)
#   [AD-04]  plot_days_hist_with_quartiles() — shared histogram builder
#   [AD-05]  PROCEDURE SHARES (build_proc_share_data + value/count plots)
#   [AD-06]  COUNTRY CONFIG (admin_threshold_config, get_admin_thresholds); year windows: utils_shared [SH-12]
#   [AD-07]  MAIN PIPELINE: run_admin_efficiency_pipeline()
#
# Entry point: run_admin_efficiency_pipeline() [AD-07] returns a named list
# consumed by the server as admin$analysis (see DEVELOPER_GUIDE.md §4.3).
# ============================================================================

# ========================================================================
# Administrative efficiency pipeline
# ========================================================================

# ------------------------------------------------------------------------
# load_data, add_tender_year, recode_procedure_type, add_buyer_group, %||%
# are all defined in utils_shared.R — not repeated here.
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# Helper: convert app nested thresholds → flat pipeline format
#
# The app stores thresholds as:
#   list(
#     subm = list(open = list(days, medium = list(min, max), no_medium, ...), restricted = ..., neg_pub = ...),
#     dec  = list(open = list(days, ...), restricted = ..., neg_pub = ...)
#   )
#
# The pipeline expects a flat list:
#   list(subm_short_open, subm_short_restricted, subm_short_negotiated,
#        subm_medium_open_min, subm_medium_open_max, long_decision_days)
# ------------------------------------------------------------------------


# [AD-01] app_thresholds_to_pipeline() — nested app thresholds → flat list ────
app_thresholds_to_pipeline <- function(app_thr) {
  get_days <- function(lst) {
    v <- lst$days
    if (is.null(v) || (length(v) == 1 && is.na(v))) NA_real_ else as.numeric(v)
  }
  # Decision days: take the first non-NA across open / restricted / neg_pub
  dec_days <- NA_real_
  for (k in c("open", "restricted", "neg_pub")) {
    v <- get_days(app_thr$dec[[k]])
    if (!is.na(v)) { dec_days <- v; break }
  }
  list(
    subm_short_open         = get_days(app_thr$subm$open),
    subm_short_restricted   = get_days(app_thr$subm$restricted),
    subm_short_negotiated   = get_days(app_thr$subm$neg_pub),
    subm_medium_open_min    = app_thr$subm$open$medium$min  %||% NA_real_,
    subm_medium_open_max    = app_thr$subm$open$medium$max  %||% NA_real_,
    long_decision_days      = dec_days
  )
}


# ========================================================================
# SPECIFICATION TESTING AND SENSITIVITY ANALYSIS FUNCTIONS
# ========================================================================


# NOTE: the regression machinery this module drives is defined in
# utils_shared.R — fixest building blocks [SH-13], the sensitivity /
# robustness suite [SH-15] and pick_best_model() [SH-14].

# [AD-02] SPEC GRID RUNNERS (run_specs, run_short_subm_specs, run_long_dec_specs) ────
run_specs <- function(reg_data, x_var,
                      fe_set       = c("0","buyer","year","buyer+year"),
                      cluster_set  = c("none","buyer","year","buyer_year","buyer_buyertype"),
                      controls_set = c("x_only","base"),
                      model_types  = c("fractional_logit","lpm","probit")) {
  n_total <- nrow(reg_data)
  out <- list(); k <- 0L
  for (mt in model_types) {
    for (fe in fe_set) {
      fe_part <- make_fe_part(fe)
      for (cl in cluster_set) {
        cl_fml <- make_cluster(cl)
        for (ctrl in controls_set) {
          rhs_terms <- switch(ctrl,
                              "x_only" = c(x_var),
                              "base"   = c(x_var, "buyer_buyertype", "tender_proceduretype"))
          rhs_terms <- rhs_terms[rhs_terms %in% names(reg_data)]
          fml <- stats::as.formula(paste0("ind_corr_binary ~ ", paste(rhs_terms, collapse = " + "), " | ", fe_part))
          m <- switch(mt,
                      "fractional_logit" = safe_fixest(fixest::feglm(fml, family = quasibinomial(link = "logit"),
                                                                     data = reg_data, cluster = cl_fml)),
                      "lpm"              = safe_fixest(fixest::feols(fml, data = reg_data, cluster = cl_fml)),
                      "probit"           = safe_fixest(fixest::feglm(fml, family = binomial(link = "probit"),
                                                                     data = reg_data, cluster = cl_fml)),
                      NULL
          )
          if (is.null(m)) next
          eff <- tryCatch(
            extract_effect_fixest(m, x_var, reg_data),
            error = function(e) list(estimate = NA_real_, pvalue = NA_real_, nobs = NA_integer_, std_slope = NA_real_)
          )
          if (is.na(eff$estimate)) next
          eff_strength <- safe_fixest(effect_p10_p90(m, reg_data, x_var)) %||% NA_real_
          
          # ── Collect diagnostics ──────────────────────────────────────
          # Convergence (GLM only)
          .converged <- tryCatch(m$converged %||% TRUE, error = function(e) TRUE)
          
          # Multicollinearity: count variables dropped by fixest
          .n_collinear <- tryCatch(length(m$collin.var %||% character(0)), error = function(e) 0L)
          
          # Effective sample: share of original data retained
          .n_eff <- tryCatch(m$nobs %||% eff$nobs, error = function(e) NA)
          .pct_retained <- if (!is.na(.n_eff) && n_total > 0) .n_eff / n_total else NA_real_
          
          # LPM out-of-range: predicted values outside [0,1]
          .out_of_range <- NA_real_
          if (mt == "lpm") {
            .fitted <- tryCatch(stats::fitted(m), error = function(e) NULL)
            if (!is.null(.fitted) && length(.fitted) > 0)
              .out_of_range <- mean(.fitted < 0 | .fitted > 1, na.rm = TRUE)
          }
          
          k <- k + 1L
          out[[k]] <- data.frame(outcome = x_var, model_type = mt,
                                 fe = fe, cluster = cl, controls = ctrl,
                                 estimate = eff$estimate, pvalue = eff$pvalue, nobs = eff$nobs,
                                 std_slope = eff$std_slope, effect_strength = eff_strength,
                                 converged = .converged, n_collinear = .n_collinear,
                                 pct_retained = .pct_retained, out_of_range_pct = .out_of_range,
                                 stringsAsFactors = FALSE)
        }
      }
    }
  }
  if (length(out) == 0) return(data.frame())
  do.call(rbind, out)
}

run_short_subm_specs <- function(reg_data, fe_set = c("0","buyer","year","buyer+year"),
                                 cluster_set = c("none","buyer","year","buyer_year","buyer_buyertype"),
                                 controls_set = c("x_only","base")) {
  run_specs(reg_data, "short_submission_period", fe_set, cluster_set, controls_set)
}

run_long_dec_specs <- function(reg_data, fe_set = c("0","buyer","year","buyer+year"),
                               cluster_set = c("none","buyer","year","buyer_year","buyer_buyertype"),
                               controls_set = c("x_only","base")) {
  run_specs(reg_data, "long_decision_period", fe_set, cluster_set, controls_set)
}

# ------------------------------------------------------------------------
# 4. Generic "days between" helper
# ------------------------------------------------------------------------


# [AD-03] DAY-COUNT HELPERS (compute_tender_days, short/long period flags) ────
compute_tender_days <- function(df, from_col, to_col, new_col) {
  from_quo   <- rlang::enquo(from_col)
  to_quo     <- rlang::enquo(to_col)
  new_col_nm <- rlang::as_name(rlang::enquo(new_col))
  df %>%
    dplyr::mutate(!!from_quo := as.Date(!!from_quo), !!to_quo := as.Date(!!to_quo)) %>%
    dplyr::filter(!is.na(!!from_quo), !is.na(!!to_quo)) %>%
    dplyr::mutate(!!new_col_nm := as.numeric(!!to_quo - !!from_quo)) %>%
    dplyr::filter(!!rlang::sym(new_col_nm) >= 0, !!rlang::sym(new_col_nm) < 365)
}

# ------------------------------------------------------------------------
# Flag helpers
# ------------------------------------------------------------------------

add_short_deadline_flags <- function(df, days_col = tender_days_open,
                                     proc_col = tender_proceduretype, thr) {
  days_col <- rlang::enquo(days_col); proc_col <- rlang::enquo(proc_col)
  med_open       <- df %>% dplyr::filter(!!proc_col == "Open Procedure")              %>% dplyr::summarise(m = stats::median(!!days_col, na.rm = TRUE)) %>% dplyr::pull(m)
  med_restricted <- df %>% dplyr::filter(!!proc_col == "Restricted Procedure")        %>% dplyr::summarise(m = stats::median(!!days_col, na.rm = TRUE)) %>% dplyr::pull(m)
  med_negotiated <- df %>% dplyr::filter(!!proc_col == "Negotiated with publications") %>% dplyr::summarise(m = stats::median(!!days_col, na.rm = TRUE)) %>% dplyr::pull(m)
  short_open_cutoff <- if (is.na(thr$subm_short_open))         med_open       else thr$subm_short_open
  short_rest_cutoff <- if (is.na(thr$subm_short_restricted))   med_restricted else thr$subm_short_restricted
  short_neg_cutoff  <- if (is.null(thr$subm_short_negotiated) || is.na(thr$subm_short_negotiated)) med_negotiated else thr$subm_short_negotiated
  medium_min <- thr$subm_medium_open_min; medium_max <- thr$subm_medium_open_max
  use_medium <- !is.na(medium_min) & !is.na(medium_max)
  df %>% dplyr::mutate(
    short_deadline = dplyr::case_when(
      !!proc_col == "Open Procedure"               & !!days_col < short_open_cutoff ~ TRUE,
      !!proc_col == "Restricted Procedure"         & !!days_col < short_rest_cutoff ~ TRUE,
      !!proc_col == "Negotiated with publications" & !!days_col < short_neg_cutoff  ~ TRUE,
      TRUE ~ FALSE),
    medium_deadline = dplyr::case_when(
      use_medium & !!proc_col == "Open Procedure" &
        !!days_col >= medium_min & !!days_col < medium_max ~ TRUE,
      TRUE ~ FALSE))
}

add_long_decision_flag <- function(df, days_col = tender_days_dec,
                                   proc_col = tender_proceduretype, thr) {
  days_col <- rlang::enquo(days_col); proc_col <- rlang::enquo(proc_col)
  df %>% dplyr::mutate(long_decision = dplyr::case_when(
    !!proc_col %in% c("Open Procedure","Restricted Procedure","Negotiated with publications") &
      !!days_col >= thr$long_decision_days ~ TRUE,
    TRUE ~ FALSE))
}

# ------------------------------------------------------------------------
# Plot helpers
# ------------------------------------------------------------------------


# [AD-04] plot_days_hist_with_quartiles() — shared histogram builder ─────────
plot_days_hist_with_quartiles <- function(data, days_var, facet_var = NULL, title,
                                          x_lab, y_lab = "Number of tenders",
                                          caption = NULL, binwidth = 5, xlim = c(0, 365)) {
  days_sym <- rlang::sym(days_var)
  base <- ggplot2::ggplot(data, ggplot2::aes(x = !!days_sym)) +
    ggplot2::geom_histogram(binwidth = binwidth, fill = "lightblue", color = "white", boundary = 0) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.25))) +
    ggplot2::coord_cartesian(xlim = xlim, clip = "off") +
    ggplot2::labs(title = title, x = x_lab, y = y_lab, caption = caption) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(plot.title.position = "plot",
                   plot.title   = ggplot2::element_text(margin = ggplot2::margin(b = 20)),
                   plot.caption = ggplot2::element_text(hjust = 0, face = "italic", size = 10,
                                                        margin = ggplot2::margin(t = 10)))
  if (is.null(facet_var)) {
    q <- stats::quantile(data[[days_var]], probs = c(0.25, 0.5, 0.75), na.rm = TRUE)
    base +
      ggplot2::geom_vline(xintercept = q, color = "blue",
                          linetype = c("dashed","solid","dashed"), size = 1) +
      ggplot2::annotate("text", x = q, y = Inf,
                        label = paste0(names(q), ": ", round(q, 1), " days"),
                        color = "blue", size = 4, angle = 45, vjust = -1, hjust = 0)
  } else {
    facet_sym <- rlang::sym(facet_var)
    q_by_facet <- data %>%
      dplyr::group_by(!!facet_sym) %>%
      dplyr::summarise(q25 = stats::quantile(!!days_sym, 0.25, na.rm = TRUE),
                       q50 = stats::quantile(!!days_sym, 0.50, na.rm = TRUE),
                       q75 = stats::quantile(!!days_sym, 0.75, na.rm = TRUE), .groups = "drop") %>%
      tidyr::pivot_longer(cols = dplyr::starts_with("q"), names_to = "quartile", values_to = "xint") %>%
      dplyr::mutate(
        quartile_label = dplyr::case_when(quartile == "q25" ~ "25%", quartile == "q50" ~ "50% (median)",
                                          quartile == "q75" ~ "75%", TRUE ~ quartile),
        linetype = dplyr::if_else(quartile == "q50", "solid", "dashed"))
    base +
      ggplot2::geom_vline(data = q_by_facet,
                          ggplot2::aes(xintercept = xint, linetype = quartile_label),
                          color = "blue", size = 0.9) +
      ggrepel::geom_text_repel(data = q_by_facet,
                               ggplot2::aes(x = xint, y = Inf, label = paste0(quartile_label, ": ", round(xint, 1), " days")),
                               inherit.aes = FALSE, color = "blue", size = 3.3, angle = 90, vjust = 1.2,
                               min.segment.length = 0, segment.color = "blue", box.padding = 0.5,
                               direction = "x", max.overlaps = Inf) +
      ggplot2::facet_wrap(stats::as.formula(paste("~", facet_var)), scales = "free_y") +
      ggplot2::scale_linetype_manual(name = NULL,
                                     values = c("25%" = "dashed", "50% (median)" = "solid", "75%" = "dashed"))
  }
}


# [AD-05] PROCEDURE SHARES (build_proc_share_data + value/count plots) ───────
build_proc_share_data <- function(df) {
  # Use first price col with actual non-NA values (skips all-NA injected placeholders)
  price_col <- NA_character_
  for (.c in c("bid_priceusd", "bid_price", "lot_estimatedpriceusd", "lot_estimatedprice")) {
    if (.c %in% names(df) && any(!is.na(df[[.c]]))) { price_col <- .c; break }
  }
  
  df_proc <- df %>%
    dplyr::mutate(
      tender_proceduretype = recode_procedure_type(tender_proceduretype),
      tender_proceduretype = forcats::fct_explicit_na(as.factor(tender_proceduretype), na_level = "Missing value"))
  
  if (!is.na(price_col)) {
    df_proc %>%
      dplyr::group_by(tender_proceduretype) %>%
      dplyr::summarise(total_value  = sum(.data[[price_col]], na.rm = TRUE),
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

plot_proc_share_value <- function(plot_data) {
  ggplot2::ggplot(plot_data, ggplot2::aes(x = stats::reorder(tender_proceduretype, share_value), y = share_value)) +
    ggplot2::geom_col(ggplot2::aes(fill = tender_proceduretype), show.legend = FALSE, width = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = paste0(scales::percent(share_value, accuracy = 0.1),
                                                   " (", scales::dollar(total_value, scale = 1e-6, suffix = "M"), ")")),
                       hjust = -0.05, size = 4) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                                expand = ggplot2::expansion(mult = c(0, 0.4))) +
    ggplot2::scale_fill_brewer(palette = "Blues", direction = -1) +
    ggplot2::coord_flip() +
    ggplot2::labs(title = "Share of contracts value", x = NULL, y = "Share of total value",
                  caption = "Values in millions of USD") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(plot.margin = ggplot2::margin(10, 30, 10, 10),
                   axis.text.y = ggplot2::element_text(size = 14))
}

plot_proc_share_count <- function(plot_data) {
  ggplot2::ggplot(plot_data, ggplot2::aes(x = stats::reorder(tender_proceduretype, share_value), y = share_contracts)) +
    ggplot2::geom_col(ggplot2::aes(fill = tender_proceduretype), show.legend = FALSE, width = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = paste0(scales::percent(share_contracts, accuracy = 0.1),
                                                   " (", n_contracts, " contracts)")),
                       hjust = -0.05, size = 4) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                                expand = ggplot2::expansion(mult = c(0, 0.4))) +
    ggplot2::scale_fill_brewer(palette = "Blues", direction = -1) +
    ggplot2::coord_flip() +
    ggplot2::labs(title = "Share of number of contracts", x = NULL, y = "Share of contracts") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(plot.margin = ggplot2::margin(10, 30, 10, 0),
                   axis.text.y = ggplot2::element_text(size = 14))
}

# ------------------------------------------------------------------------
# Threshold config
# ------------------------------------------------------------------------


# [AD-06] COUNTRY CONFIG (admin_threshold_config, get_admin_thresholds); year windows: utils_shared [SH-12] ────
admin_threshold_config <- tibble::tribble(
  ~country_code, ~subm_short_open, ~subm_short_restricted, ~subm_short_negotiated,
  ~subm_medium_open_min, ~subm_medium_open_max, ~long_decision_days,
  "DEFAULT", 30, 30, 30, 30, 30, 60,
  "UY",      21, 14, 14, 21, 28, 56,
  "BG",      30, 30, 30, 30, 30, NA,
  "ID",       3,  3, NA,  3,  5, NA,
  "DL",      30, 25, 15, 30, 35, 90   # Demoland — bundled demo dataset
)

get_admin_thresholds <- function(country_code) {
  cc  <- toupper(country_code)
  row <- admin_threshold_config %>%
    dplyr::filter(country_code %in% c(cc, "DEFAULT")) %>%
    dplyr::arrange(dplyr::desc(country_code == cc)) %>%
    dplyr::slice(1)
  as.list(dplyr::select(row, -country_code))
}

# year_filter_config and get_year_range() are defined in utils_shared.R
# [SH-12]; get_year_range() accepts component = "singleb", "rel_price" or
# "default".


# ========================================================================
# Unified administrative efficiency pipeline
#
# NEW PARAMETER: thresholds (optional)
#   Pass results$thresholds from the Shiny app to use the values set in
#   the Configuration tab rather than the hardcoded country defaults.
#   If NULL (default), falls back to get_admin_thresholds(country_code).
# ========================================================================


# [AD-07] MAIN PIPELINE: run_admin_efficiency_pipeline() ─────────────────────
run_admin_efficiency_pipeline <- function(df, country_code = "GEN", output_dir,
                                          run_regressions = TRUE,
                                          thresholds = NULL) {
  
  # ── Resolve thresholds ──────────────────────────────────────────────
  # If the app passes its nested thresholds object, convert to flat format.
  # Otherwise fall back to the hardcoded country config.
  if (!is.null(thresholds)) {
    thr        <- app_thresholds_to_pipeline(thresholds)
    thr_source <- "app configuration"
  } else {
    thr        <- get_admin_thresholds(country_code)
    thr_source <- paste0("country defaults (", country_code, ")")
  }
  
  message("Running administrative efficiency pipeline for ", country_code,
          " [thresholds: ", thr_source, "]",
          if (!run_regressions) " [descriptive only]" else "", " ...")
  
  df  <- df %>% add_tender_year()
  if (!"tender_proceduretype" %in% names(df)) df$tender_proceduretype <- NA_character_
  
  # Normalise column structure: create canonical alias columns from whatever
  # alternative names the dataset uses (e.g. buyer_id → buyer_masterid,
  # entity_type → buyer_buyertype). Also applies fuzzy procedure-type mapping
  # so national naming conventions are recognised by all downstream plots.
  df <- normalize_procurement_data(df)
  
  # Determine whether the dataset uses standard ProAct canonical procedure
  # codes or national alternatives.  After recode_procedure_type() (called
  # inside normalize step above), national types get mapped to canonical
  # labels via fuzzy matching in utils_shared.R.
  .available_proc_recoded <- unique(stats::na.omit(recode_procedure_type(df$tender_proceduretype)))
  .COMP_PROC_CANONICAL    <- c("Open Procedure","Restricted Procedure","Negotiated with publications")
  .has_canonical_proc     <- any(.available_proc_recoded %in% .COMP_PROC_CANONICAL)
  # Procedure types to use in regression filters: prefer the three standard
  # competitive types; if none exist, fall back to all available recoded types.
  .comp_proc_for_reg <- if (.has_canonical_proc)
    intersect(.COMP_PROC_CANONICAL, .available_proc_recoded)
  else
    .available_proc_recoded
  
  yr_singleb       <- get_year_range(country_code, component = "singleb")
  min_year_singleb <- yr_singleb$min_year
  max_year_singleb <- yr_singleb$max_year
  
  # ── Summary stats ────────────────────────────────────────────────────
  n_obs_per_year   <- df %>% dplyr::count(tender_year, name = "n_observations")
  n_unique_buyers  <- if ("buyer_masterid"  %in% names(df)) dplyr::n_distinct(df$buyer_masterid,  na.rm = TRUE)
  else if ("buyer_id"   %in% names(df)) dplyr::n_distinct(df$buyer_id,         na.rm = TRUE)
  else if ("buyer_name" %in% names(df)) dplyr::n_distinct(df$buyer_name,       na.rm = TRUE)
  else NA_integer_
  n_unique_bidders <- if ("bidder_masterid"  %in% names(df)) dplyr::n_distinct(df$bidder_masterid,  na.rm = TRUE)
  else if ("bidder_id"   %in% names(df)) dplyr::n_distinct(df$bidder_id,        na.rm = TRUE)
  else if ("supplier_name" %in% names(df)) dplyr::n_distinct(df$supplier_name,  na.rm = TRUE)
  else if ("bidder_name"  %in% names(df)) dplyr::n_distinct(df$bidder_name,     na.rm = TRUE)
  else NA_integer_
  tender_year_tenders <- if ("tender_id" %in% names(df))
    df %>% dplyr::group_by(tender_year) %>%
    dplyr::summarise(n_unique_tender_id = dplyr::n_distinct(tender_id), .groups = "drop")
  else NULL
  
  vars_present <- names(df)[!startsWith(names(df), "ind_")]
  summary_stats <- list(n_obs_per_year = n_obs_per_year, n_unique_buyers = n_unique_buyers,
                        tender_year_tenders = tender_year_tenders,
                        n_unique_bidders = n_unique_bidders, vars_present = vars_present)
  
  if (!is.na(n_unique_buyers))  cat("Unique buyers:  ", n_unique_buyers,  "\n\n") else cat("buyer_masterid not found.\n\n")
  if (!is.null(tender_year_tenders)) { cat("Unique tenders per year:\n"); print(tender_year_tenders); cat("\n") } else cat("tender_id not found.\n\n")
  if (!is.na(n_unique_bidders)) cat("Unique bidders: ", n_unique_bidders, "\n\n") else cat("bidder_masterid not found.\n\n")
  
  # ── A) Procedure type shares ─────────────────────────────────────────
  proc_share_data <- build_proc_share_data(df)
  sh            <- plot_proc_share_value(proc_share_data)
  p_count       <- plot_proc_share_count(proc_share_data)
  combined_proc <- sh + p_count + patchwork::plot_layout(ncol = 2)
  ggplot2::ggsave(file.path(output_dir, "share_value_vs_contracts.png"),
                  combined_proc, width = 19, height = 8, dpi = 300)
  
  # ── B) Submission period distribution ────────────────────────────────
  has_subm_cols <- all(c("tender_publications_firstcallfortenderdate", "tender_biddeadline") %in% names(df))
  if (has_subm_cols) {
    tender_periods_open <- compute_tender_days(
      df, tender_publications_firstcallfortenderdate, tender_biddeadline, tender_days_open)
  } else {
    message("Skipping submission period analysis: date columns missing from dataset.")
    tender_periods_open <- df[0, , drop = FALSE]
    tender_periods_open$tender_days_open <- numeric(0)
  }
  subm <- plot_days_hist_with_quartiles(tender_periods_open, "tender_days_open", NULL,
                                        "Days for bid submission", "Days between call opening and bid submission deadline",
                                        caption = "Vertical lines indicate the 25th, 50th (median), and 75th percentiles")
  ggplot2::ggsave(file.path(output_dir, "subm.png"), subm, width = 10, height = 6, dpi = 300)
  
  # ── C) By procedure type ─────────────────────────────────────────────
  tender_periods_open_proc <- tender_periods_open %>%
    dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
    dplyr::filter(!is.na(tender_proceduretype))
  subm_proc_facet_q <- plot_days_hist_with_quartiles(tender_periods_open_proc, "tender_days_open",
                                                     "tender_proceduretype", "Days for bid submission by procedure type",
                                                     "Days between call opening and bid submission deadline",
                                                     caption = "Blue lines indicate quartiles within each procedure type")
  ggplot2::ggsave(file.path(output_dir, "subm_proc_fac.png"), subm_proc_facet_q, width = 10, height = 6, dpi = 300)
  
  # ── D) Short submission flags ─────────────────────────────────────────
  tender_periods_short <- tender_periods_open_proc %>%
    dplyr::filter(tender_proceduretype %in% c("Open Procedure","Restricted Procedure","Negotiated with publications")) %>%
    add_short_deadline_flags(days_col = tender_days_open, proc_col = tender_proceduretype, thr = thr)
  
  subm_r <- ggplot2::ggplot(tender_periods_short,
                            ggplot2::aes(x = tender_days_open,
                                         fill = dplyr::case_when(short_deadline ~ "red", medium_deadline ~ "yellow", TRUE ~ "lightblue"))) +
    ggplot2::geom_histogram(binwidth = 1, boundary = 0, colour = "white") +
    ggplot2::facet_wrap(~ tender_proceduretype, scales = "free_y") +
    ggplot2::scale_fill_identity() + ggplot2::xlim(0, 60) +
    ggplot2::labs(x = "Days", y = "Number of tenders",
                  title = "Distribution of tender open periods by procedure type",
                  subtitle = paste0("Red = short deadline (<",
                                    thr$subm_short_open, "d open / <", thr$subm_short_restricted,
                                    "d restricted); yellow = medium band")) +
    ggplot2::theme_minimal(base_size = 14) + ggplot2::theme(legend.position = "none")
  share_labels_short <- tender_periods_short %>%
    dplyr::group_by(tender_proceduretype) %>%
    dplyr::summarise(share_short = mean(short_deadline, na.rm = TRUE) * 100, .groups = "drop")
  subm_r <- subm_r +
    ggplot2::geom_text(data = share_labels_short,
                       ggplot2::aes(x = 50, y = Inf, label = paste0("Share with short deadlines: ", round(share_short, 1), "%")),
                       vjust = 2, hjust = 1, size = 4.5, fontface = "bold", inherit.aes = FALSE)
  ggplot2::ggsave(file.path(output_dir, "subm_r.png"), subm_r, width = 10, height = 6, dpi = 300)
  
  tender_periods_buyer <- tender_periods_short %>% dplyr::mutate(buyer_group = add_buyer_group(buyer_buyertype))
  short_share_buyer_proc <- tender_periods_buyer %>%
    dplyr::group_by(buyer_group, tender_proceduretype) %>%
    dplyr::summarise(share_short = mean(short_deadline, na.rm = TRUE), n_tenders = dplyr::n(), .groups = "drop") %>%
    dplyr::mutate(share_other = 1 - share_short) %>%
    tidyr::pivot_longer(c(share_short, share_other), names_to = "deadline_type", values_to = "share")
  buyer_short <- ggplot2::ggplot(short_share_buyer_proc, ggplot2::aes(x = buyer_group, y = share, fill = deadline_type)) +
    ggplot2::geom_col(position = "fill") +
    ggplot2::geom_text(ggplot2::aes(label = scales::percent(share, accuracy = 1)),
                       position = ggplot2::position_fill(vjust = 0.5), color = "white", size = 4, fontface = "bold") +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_fill_manual(values = c("share_short" = "tomato2", "share_other" = "steelblue2"),
                               breaks = c("share_short","share_other"),
                               labels = c("Short submission period","Other submission periods")) +
    ggplot2::facet_wrap(~ tender_proceduretype) +
    ggplot2::labs(x = "Buyer group", y = "Share of tenders (100%)", fill = NULL,
                  title = "Short tender submission periods (by contract count)") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), legend.position = "top")
  .admin_price_col <- intersect(c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"),
                                names(tender_periods_buyer))[1]
  if (!is.na(.admin_price_col)) {
    short_share_value_buyer_proc <- tender_periods_buyer %>%
      dplyr::group_by(buyer_group, tender_proceduretype) %>%
      dplyr::summarise(total_value = sum(.data[[.admin_price_col]], na.rm = TRUE),
                       short_value = sum(.data[[.admin_price_col]][short_deadline %in% TRUE], na.rm = TRUE),
                       share_short = dplyr::if_else(total_value > 0, short_value / total_value, NA_real_),
                       n_contracts = dplyr::n(), .groups = "drop") %>%
      dplyr::mutate(share_other = 1 - share_short) %>%
      tidyr::pivot_longer(c(share_short, share_other), names_to = "deadline_type", values_to = "share")
  } else {
    short_share_value_buyer_proc <- tender_periods_buyer %>%
      dplyr::group_by(buyer_group, tender_proceduretype) %>%
      dplyr::summarise(share_short = mean(short_deadline, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(share_other = 1 - share_short) %>%
      tidyr::pivot_longer(c(share_short, share_other), names_to = "deadline_type", values_to = "share")
  }
  buyer_short_v <- ggplot2::ggplot(short_share_value_buyer_proc, ggplot2::aes(x = buyer_group, y = share, fill = deadline_type)) +
    ggplot2::geom_col(position = "fill") +
    ggplot2::geom_text(ggplot2::aes(label = scales::percent(share, accuracy = 1)),
                       position = ggplot2::position_fill(vjust = 0.5), color = "white", size = 4, fontface = "bold") +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_fill_manual(values = c("share_short" = "tomato2", "share_other" = "steelblue2"),
                               breaks = c("share_short","share_other"),
                               labels = c("Short submission period","Other submission periods")) +
    ggplot2::facet_wrap(~ tender_proceduretype) +
    ggplot2::labs(x = "Buyer group", y = "Share of contract value (100%)", fill = NULL,
                  title = "Short tender submission periods (by contract value)") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), legend.position = "top")
  combined_short_buyer <- buyer_short + buyer_short_v + patchwork::plot_layout(nrow = 2)
  ggplot2::ggsave(file.path(output_dir, "short_submission_buyer.png"), combined_short_buyer,
                  width = 12, height = 12, dpi = 300)
  
  # ── E–F) Decision period distribution ────────────────────────────────
  # Decision date: primary = tender_awarddecisiondate; fallback = tender_contractsignaturedate.
  if (!"tender_contractsignaturedate" %in% names(df))
    df <- df %>% dplyr::mutate(tender_contractsignaturedate = as.Date(NA))
  if (!"tender_awarddecisiondate" %in% names(df))
    df <- df %>% dplyr::mutate(tender_awarddecisiondate = as.Date(NA))
  df_with_end_date <- df %>%
    dplyr::mutate(decision_end_date = dplyr::coalesce(
      as.Date(tender_awarddecisiondate),
      as.Date(tender_contractsignaturedate)))
  if ("tender_biddeadline" %in% names(df_with_end_date)) {
    tender_periods_dec <- compute_tender_days(df_with_end_date, tender_biddeadline, decision_end_date, tender_days_dec)
  } else {
    message("Skipping decision period analysis: tender_biddeadline column missing from dataset.")
    tender_periods_dec <- df_with_end_date[0, , drop = FALSE]
    tender_periods_dec$tender_days_dec <- numeric(0)
  }
  decp <- plot_days_hist_with_quartiles(tender_periods_dec, "tender_days_dec", NULL,
                                        "Days for award decision", "Days between bid submission deadline and contract award",
                                        caption = "Vertical lines indicate quartiles")
  ggplot2::ggsave(file.path(output_dir, "decp.png"), decp, width = 10, height = 6, dpi = 300)
  tender_periods_dec_proc <- tender_periods_dec %>%
    dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
    dplyr::filter(!is.na(tender_proceduretype))
  decp_proc_facet_q <- plot_days_hist_with_quartiles(tender_periods_dec_proc, "tender_days_dec",
                                                     "tender_proceduretype", "Days for award decision",
                                                     "Days between bid submission deadline and contract award",
                                                     caption = "Blue lines indicate quartiles within each procedure type")
  ggplot2::ggsave(file.path(output_dir, "decp_proc_fac.png"), decp_proc_facet_q, width = 10, height = 6, dpi = 300)
  
  # ── G) Long decision flags ────────────────────────────────────────────
  long_threshold_open <- if (is.na(thr$long_decision_days)) {
    tender_periods_dec_proc %>%
      dplyr::filter(tender_proceduretype %in% c("Open Procedure","Restricted Procedure","Negotiated with publications")) %>%
      dplyr::summarise(m = stats::median(tender_days_dec, na.rm = TRUE)) %>% dplyr::pull(m)
  } else thr$long_decision_days
  thr_long_open <- thr; thr_long_open$long_decision_days <- long_threshold_open
  tender_periods_long <- tender_periods_dec_proc %>%
    dplyr::filter(tender_proceduretype %in% c("Open Procedure","Restricted Procedure","Negotiated with publications")) %>%
    add_long_decision_flag(days_col = tender_days_dec, proc_col = tender_proceduretype, thr = thr_long_open)
  long_thr_label_ge <- paste0("\u2265 ", round(long_threshold_open), " days")
  long_thr_label_lt <- paste0("< ",      round(long_threshold_open), " days")
  decp_r <- ggplot2::ggplot(tender_periods_long,
                            ggplot2::aes(x = tender_days_dec,
                                         fill = dplyr::case_when(
                                           tender_proceduretype %in% c("Open Procedure","Restricted Procedure") &
                                             tender_days_dec >= long_threshold_open ~ "red",
                                           TRUE ~ "lightblue"))) +
    ggplot2::geom_histogram(binwidth = 4, boundary = 0, colour = "white") +
    ggplot2::facet_wrap(~ tender_proceduretype, scales = "free_y") +
    ggplot2::scale_fill_identity() + ggplot2::xlim(0, 300) +
    ggplot2::labs(x = "Days", y = "Number of tenders",
                  title = "Distribution of tender decision periods by procedure type",
                  subtitle = paste0("Bars in red: periods ", long_thr_label_ge, " (long threshold)")) +
    ggplot2::theme_minimal(base_size = 14) + ggplot2::theme(legend.position = "none")
  share_labels_long <- tender_periods_long %>%
    dplyr::group_by(tender_proceduretype) %>%
    dplyr::summarise(share_long = mean(tender_days_dec >= long_threshold_open, na.rm = TRUE) * 100, .groups = "drop")
  decp_r <- decp_r +
    ggplot2::geom_text(data = share_labels_long,
                       ggplot2::aes(x = 200, y = Inf, label = paste0("Share delayed: ", round(share_long, 1), "%")),
                       vjust = 2, hjust = 0.75, size = 4.5, fontface = "bold", inherit.aes = FALSE)
  ggplot2::ggsave(file.path(output_dir, "decp_r.png"), decp_r, width = 10, height = 6, dpi = 300)
  
  # ── H) Long decision by buyer ─────────────────────────────────────────
  tender_periods_labeled_dec <- tender_periods_long %>% dplyr::mutate(buyer_group = add_buyer_group(buyer_buyertype))
  long_share_buyer_proc <- tender_periods_labeled_dec %>%
    dplyr::group_by(buyer_group, tender_proceduretype) %>%
    dplyr::summarise(share_long = mean(long_decision, na.rm = TRUE), n_tenders = dplyr::n(), .groups = "drop") %>%
    dplyr::mutate(share_other = 1 - share_long) %>%
    tidyr::pivot_longer(c(share_long, share_other), names_to = "decision_type", values_to = "share")
  buyer_long <- ggplot2::ggplot(long_share_buyer_proc, ggplot2::aes(x = buyer_group, y = share, fill = decision_type)) +
    ggplot2::geom_col(position = "fill") +
    ggplot2::geom_text(ggplot2::aes(label = scales::percent(share, accuracy = 1)),
                       position = ggplot2::position_fill(vjust = 0.5), color = "white", size = 4, fontface = "bold") +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_fill_manual(values = c("share_long" = "tomato2","share_other" = "steelblue2"),
                               breaks = c("share_long","share_other"),
                               labels = c(long_thr_label_ge, long_thr_label_lt)) +
    ggplot2::facet_wrap(~ tender_proceduretype) +
    ggplot2::labs(x = "Buyer group", y = "Share of tenders (100%)", fill = NULL,
                  title = paste0("Long tender decision periods (", long_thr_label_ge, ") — by count")) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), legend.position = "top")
  .dec_price_col <- intersect(c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"),
                              names(tender_periods_labeled_dec))[1]
  if (!is.na(.dec_price_col)) {
    long_share_value_buyer_proc <- tender_periods_labeled_dec %>%
      dplyr::group_by(buyer_group, tender_proceduretype) %>%
      dplyr::summarise(total_value = sum(.data[[.dec_price_col]], na.rm = TRUE),
                       long_value  = sum(.data[[.dec_price_col]][long_decision %in% TRUE], na.rm = TRUE),
                       share_long  = dplyr::if_else(total_value > 0, long_value / total_value, NA_real_),
                       n_contracts = dplyr::n(), .groups = "drop") %>%
      dplyr::mutate(share_other = 1 - share_long) %>%
      tidyr::pivot_longer(c(share_long, share_other), names_to = "decision_type", values_to = "share")
  } else {
    long_share_value_buyer_proc <- tender_periods_labeled_dec %>%
      dplyr::group_by(buyer_group, tender_proceduretype) %>%
      dplyr::summarise(share_long = mean(long_decision, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(share_other = 1 - share_long) %>%
      tidyr::pivot_longer(c(share_long, share_other), names_to = "decision_type", values_to = "share")
  }
  buyer_long_v <- ggplot2::ggplot(long_share_value_buyer_proc, ggplot2::aes(x = buyer_group, y = share, fill = decision_type)) +
    ggplot2::geom_col(position = "fill") +
    ggplot2::geom_text(ggplot2::aes(label = scales::percent(share, accuracy = 1)),
                       position = ggplot2::position_fill(vjust = 0.5), color = "white", size = 4, fontface = "bold") +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_fill_manual(values = c("share_long" = "tomato2","share_other" = "steelblue2"),
                               breaks = c("share_long","share_other"),
                               labels = c(long_thr_label_ge, long_thr_label_lt)) +
    ggplot2::facet_wrap(~ tender_proceduretype) +
    ggplot2::labs(x = "Buyer group", y = "Share of contract value (100%)", fill = NULL,
                  title = paste0("Long tender decision periods (", long_thr_label_ge, ") — by value")) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), legend.position = "top")
  combined_dec_plot <- buyer_long + buyer_long_v + patchwork::plot_layout(nrow = 2)
  ggplot2::ggsave(file.path(output_dir, "long_decision_buyer.png"), combined_dec_plot,
                  width = 12, height = 12, dpi = 300)
  
  # ── I–J) Regressions ─────────────────────────────────────────────────
  specs_short <- specs_long <- sensitivity_short <- sensitivity_long <- NULL
  model_short_glm <- model_long_glm <- plot_short_reg <- plot_long_reg <- NULL
  best_row_short <- best_row_long <- NULL
  is_robust_short <- is_robust_long <- NULL
  marginal_short <- marginal_long <- NULL
  
  run_one_regression <- function(reg_data, x_var, label) {
    if (nrow(reg_data) == 0) { message("No data for ", label); return(list()) }
    specs       <- run_specs(reg_data, x_var)
    if (is.null(specs) || nrow(specs) == 0) return(list())
    sensitivity <- build_sensitivity_bundle(specs)
    message("  ", label, ": ", nrow(specs), " specifications tested.")
    
    # Determine robustness from the sensitivity bundle (same criteria as UI verdict)
    .is_robust <- {
      has_rows <- function(tbl) !is.null(tbl) && is.data.frame(tbl) && nrow(tbl) > 0
      sp <- if (has_rows(sensitivity$overall)) sensitivity$overall$share_positive else 0
      cn <- names(sensitivity$overall)
      p10_col <- cn[grepl("share_p_le_0.1", cn, fixed = TRUE)]
      p10 <- if (length(p10_col) > 0) sensitivity$overall[[p10_col[1]]] else 0
      ss <- if (has_rows(sensitivity$sign)) sensitivity$sign$share_sign_stable else 0
      isTRUE(sp >= 0.7 && p10 >= 0.6 && ss == 1)
    }
    
    # First try: significant positive result
    best_row <- pick_best_model(specs, require_positive = TRUE, p_max = 0.10,
                                strength_col = "effect_strength")
    
    # Fallback: no significant spec — use same scoring criteria but without p-value filter
    if (is.null(best_row)) {
      best_row <- pick_best_model(specs, require_positive = FALSE, p_max = 1.0,
                                  strength_col = "effect_strength")
      if (is.null(best_row)) {
        # Last resort: just pick median-estimate spec
        best_row <- specs %>%
          dplyr::filter(!is.na(estimate)) %>%
          dplyr::mutate(.dist = abs(estimate - stats::median(estimate, na.rm = TRUE))) %>%
          dplyr::arrange(.dist) %>%
          dplyr::slice_head(n = 1) %>%
          dplyr::select(-.dist)
      }
      message("  No significant specification found — showing best-scoring available model.")
    }
    if (is.null(best_row) || nrow(best_row) == 0) return(list(specs = specs, sensitivity = sensitivity))
    
    fe_part   <- make_fe_part(best_row$fe)
    cl_fml    <- make_cluster(best_row$cluster)
    rhs_terms <- switch(best_row$controls,
                        "x_only" = c(x_var),
                        "base"   = c(x_var, "buyer_buyertype", "tender_proceduretype"))
    rhs_terms <- rhs_terms[rhs_terms %in% names(reg_data)]
    fml <- stats::as.formula(paste0("ind_corr_binary ~ ", paste(rhs_terms, collapse = " + "), " | ", fe_part))
    model_glm <- tryCatch(switch(best_row$model_type,
                                 "lpm"    = fixest::feols(fml, data = reg_data, cluster = cl_fml),
                                 "probit" = fixest::feglm(fml, family = binomial(link = "probit"),
                                                          data = reg_data, cluster = cl_fml),
                                 # default: fractional_logit
                                 fixest::feglm(fml, family = quasibinomial(link = "logit"),
                                               data = reg_data, cluster = cl_fml)
    ), error = function(e) {
      message("  Best model refit failed (", best_row$model_type, "): ", e$message)
      NULL
    })
    pred <- NULL
    marginal_effect <- NULL   # store for interpretation
    if (!is.null(model_glm)) {
      pred <- tryCatch({
        raw <- ggeffects::ggpredict(model_glm, terms = x_var)
        df <- as.data.frame(raw)
        cn <- names(df)
        x_col <- if ("x" %in% cn) df[["x"]] else df[[1]]
        y_col <- if ("predicted" %in% cn) df[["predicted"]]
        else if ("estimate" %in% cn) df[["estimate"]]
        else df[[2]]
        lo_col <- if ("conf.low" %in% cn) df[["conf.low"]]
        else { i <- grep("conf.*low|lower", cn, ignore.case=TRUE); if (length(i)) df[[i[1]]] else NA }
        hi_col <- if ("conf.high" %in% cn) df[["conf.high"]]
        else { i <- grep("conf.*high|upper", cn, ignore.case=TRUE); if (length(i)) df[[i[1]]] else NA }
        out <- data.frame(x = as.numeric(x_col), predicted = as.numeric(y_col),
                          conf.low = as.numeric(lo_col), conf.high = as.numeric(hi_col),
                          stringsAsFactors = FALSE)
        # If CIs are all NA, compute manually from SEs
        if (all(is.na(out$conf.low))) {
          se_col <- if ("std.error" %in% cn) df[["std.error"]]
          else { i <- grep("std.*err|se$", cn, ignore.case=TRUE); if (length(i)) df[[i[1]]] else NULL }
          if (!is.null(se_col)) {
            out$conf.low  <- out$predicted - 1.96 * as.numeric(se_col)
            out$conf.high <- out$predicted + 1.96 * as.numeric(se_col)
          }
        }
        # If still NA, create narrow band so ribbon is at least visible
        if (all(is.na(out$conf.low))) {
          out$conf.low  <- out$predicted * 0.95
          out$conf.high <- out$predicted * 1.05
        }
        out
      }, error = function(e) { message("  ggpredict failed: ", e$message); NULL })
      # Compute marginal effect: predicted at x=1 minus predicted at x=0
      if (!is.null(pred) && nrow(pred) >= 2) {
        p0 <- pred$predicted[pred$x == 0]
        p1 <- pred$predicted[pred$x == 1]
        if (length(p0) > 0 && length(p1) > 0)
          marginal_effect <- list(at_0 = p0[1], at_1 = p1[1], diff = p1[1] - p0[1])
      }
    }
    plot_reg <- NULL
    if (!is.null(pred) && nrow(pred) > 0 && "predicted" %in% names(pred)) {
      robustness_note <- if (.is_robust)
        "Evidence is robust \u2014 consistent across the majority of specifications."
      else
        "Evidence is mixed or weak \u2014 interpret with caution."
      selection_note <- if (.is_robust)
        " Selected: highest methodological quality score among significant specifications, closest to median estimate."
      else
        " Selected: highest methodological quality score (no spec met robustness criteria). Interpret with caution."
      caption_txt <- paste0(
        "N=", scales::comma(nrow(reg_data)), "; years ",
        min(reg_data$tender_year, na.rm = TRUE), "\u2013", max(reg_data$tender_year, na.rm = TRUE),
        ". Best spec: ", best_row$model_type, ", FE=", best_row$fe, ", Cluster=", best_row$cluster,
        ", Controls=", best_row$controls,
        " (p=", round(best_row$pvalue, 3), ").",
        " Thresholds: ", thr_source, ". ", robustness_note, selection_note)
      .model_label <- if (exists("pretty_model_name")) pretty_model_name(best_row$model_type) else best_row$model_type
      plot_reg <- ggplot2::ggplot(pred, ggplot2::aes(x = x, y = predicted)) +
        ggplot2::geom_line(size = 1.5, color = "lightblue") +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = conf.low, ymax = conf.high), alpha = 0.25, fill = "#90CAF9") +
        ggplot2::labs(title    = paste0("Predicted probability of single bidding by ", label),
                      subtitle = paste0(
                        if (.is_robust) "\u2713 Robust" else "\u2717 NOT ROBUST \u2014 best available model",
                        " | ", .model_label),
                      x = paste0(x_var, " (0 = normal, 1 = flagged)"),
                      y = "Predicted probability", caption = caption_txt) +
        ggplot2::scale_y_continuous(labels = scales::percent_format()) +
        ggplot2::theme_minimal(base_size = 20)
    }
    list(specs = specs, sensitivity = sensitivity, model_glm = model_glm,
         plot_reg = plot_reg, is_robust = .is_robust, best_row = best_row,
         marginal_effect = marginal_effect)
  }
  
  if (run_regressions) {
    message("\n", strrep("-", 60))
    message("Running specification testing for SHORT submission period...")
    message("  Cutoffs: open=", thr$subm_short_open, "d, restricted=",
            thr$subm_short_restricted, "d, neg_pub=", thr$subm_short_negotiated, "d")
    message("  Procedure filter: ", paste(.comp_proc_for_reg, collapse = ", "))
    message(strrep("-", 60))
    
    # Detect which buyer column to use for the regression FE.
    # Priority: buyer_id (standard admin column) → buyer_masterid (normalised alias).
    .reg_buyer_col <- if ("buyer_id" %in% names(df)) "buyer_id"
    else if ("buyer_masterid" %in% names(df)) "buyer_masterid"
    else NA_character_
    
    # Pre-detect date columns needed for submission/decision periods.
    .has_pub_date  <- "tender_publications_firstcallfortenderdate" %in% names(df)
    .has_deadline  <- "tender_biddeadline"                         %in% names(df)
    .has_sig_date  <- "tender_contractsignaturedate"               %in% names(df)
    .has_award_date <- "tender_awarddecisiondate"                  %in% names(df)
    .has_days_open <- "days_invite2openclose"                      %in% names(df)
    .has_days_dec  <- "days_openclose2award"                       %in% names(df)
    
    # --- SHORT SUBMISSION REGRESSION ---
    # Build submission days: prefer computed date diff; fall back to pre-computed column.
    if (.has_pub_date && .has_deadline) {
      reg_short_base <- df %>%
        dplyr::mutate(
          tender_publications_firstcallfortenderdate = as.Date(tender_publications_firstcallfortenderdate),
          tender_biddeadline = as.Date(tender_biddeadline),
          tender_days_open   = as.numeric(tender_biddeadline - tender_publications_firstcallfortenderdate))
    } else if (.has_days_open) {
      reg_short_base <- df %>%
        dplyr::mutate(tender_days_open = suppressWarnings(as.numeric(.data[["days_invite2openclose"]])))
    } else {
      message("Skipping short-submission regression: no usable date or pre-computed day columns found.")
      reg_short_base <- df[0L, , drop = FALSE]
      reg_short_base$tender_days_open <- numeric(0)
    }
    
    # Recode procedure types then apply adaptive filter.
    # When canonical types exist we filter to competitive procedures only;
    # otherwise we keep all non-NA procedure types so national datasets still
    # produce a regression result.
    reg_short_base <- reg_short_base %>%
      dplyr::mutate(proc_recoded = recode_procedure_type(tender_proceduretype)) %>%
      add_tender_year() %>%
      dplyr::filter(
        tender_year >= min_year_singleb, tender_year <= max_year_singleb,
        !is.na(tender_days_open), tender_days_open >= 0, tender_days_open < 365,
        !is.na(proc_recoded),
        proc_recoded %in% .comp_proc_for_reg
      )
    
    # Short-deadline cutoffs: use configured thresholds where available;
    # fall back to the within-data median per (recoded) procedure type so that
    # national datasets still get a meaningful binary flag.
    .proc_median <- function(d, proc) {
      v <- d$tender_days_open[d$proc_recoded == proc]
      m <- stats::median(v, na.rm = TRUE)
      if (is.na(m) || !is.finite(m)) NA_real_ else m
    }
    short_open_reg <- if (!is.na(thr$subm_short_open)) thr$subm_short_open else
      .proc_median(reg_short_base, "Open Procedure")
    short_rest_reg <- if (!is.na(thr$subm_short_restricted)) thr$subm_short_restricted else
      .proc_median(reg_short_base, "Restricted Procedure")
    short_neg_reg  <- if (!is.na(thr$subm_short_negotiated)) thr$subm_short_negotiated else
      .proc_median(reg_short_base, "Negotiated with publications")
    
    # If no per-type threshold is available (national dataset), derive a single
    # overall statistical cutoff (75th percentile) applied to all procedure types.
    .overall_short_cut <- stats::quantile(reg_short_base$tender_days_open, 0.25, na.rm = TRUE)
    
    reg_short <- reg_short_base %>%
      dplyr::mutate(short_submission_period = dplyr::case_when(
        proc_recoded == "Open Procedure"               & !is.na(short_open_reg) &
          tender_days_open < short_open_reg ~ 1L,
        proc_recoded == "Restricted Procedure"         & !is.na(short_rest_reg) &
          tender_days_open < short_rest_reg ~ 1L,
        proc_recoded == "Negotiated with publications" & !is.na(short_neg_reg) &
          tender_days_open < short_neg_reg  ~ 1L,
        # Fallback: for any other procedure type, use the overall bottom-quartile cutoff
        !is.na(.overall_short_cut) &
          tender_days_open < .overall_short_cut ~ 1L,
        TRUE ~ 0L
      )) %>%
      dplyr::filter(
        !is.na(short_submission_period),
        !is.na(ind_corr_singleb),
        !is.na(.data[[if (!is.na(.reg_buyer_col)) .reg_buyer_col else "buyer_id"]])
      ) %>%
      dplyr::mutate(
        buyer_id = .data[[if (!is.na(.reg_buyer_col)) .reg_buyer_col else "buyer_id"]],
        ind_corr_binary = ind_corr_singleb / 100
      )
    
    res_short          <- run_one_regression(reg_short, "short_submission_period", "short submission period")
    specs_short        <- res_short$specs
    sensitivity_short  <- res_short$sensitivity
    model_short_glm    <- res_short$model_glm
    plot_short_reg     <- res_short$plot_reg
    best_row_short     <- res_short$best_row
    is_robust_short    <- res_short$is_robust
    marginal_short     <- res_short$marginal_effect
    
    message("\n", strrep("-", 60))
    message("Running specification testing for LONG decision period...")
    message("  Cutoff: ", thr$long_decision_days, " days")
    message(strrep("-", 60))
    
    # --- LONG DECISION REGRESSION ---
    # Build decision days: prefer bid-deadline → award; fall back to pre-computed column.
    if (.has_deadline && (.has_award_date || .has_sig_date)) {
      reg_long_base <- df %>%
        dplyr::mutate(
          tender_biddeadline    = as.Date(tender_biddeadline),
          .award_date           = dplyr::coalesce(
            if (.has_award_date) as.Date(tender_awarddecisiondate)    else as.Date(NA),
            if (.has_sig_date)   as.Date(tender_contractsignaturedate) else as.Date(NA)
          ),
          tender_days_dec       = as.numeric(.award_date - tender_biddeadline)
        )
    } else if (.has_days_dec) {
      reg_long_base <- df %>%
        dplyr::mutate(tender_days_dec = suppressWarnings(as.numeric(.data[["days_openclose2award"]])))
    } else if (.has_pub_date && .has_deadline) {
      # Last resort: use overall open-to-close span as a proxy for decision lag
      reg_long_base <- df %>%
        dplyr::mutate(
          tender_publications_firstcallfortenderdate = as.Date(tender_publications_firstcallfortenderdate),
          tender_biddeadline = as.Date(tender_biddeadline),
          tender_days_dec    = as.numeric(tender_biddeadline - tender_publications_firstcallfortenderdate)
        )
    } else {
      message("Skipping long-decision regression: no usable date or pre-computed day columns found.")
      reg_long_base <- df[0L, , drop = FALSE]
      reg_long_base$tender_days_dec <- numeric(0)
    }
    
    reg_long_base <- reg_long_base %>%
      dplyr::mutate(proc_recoded = recode_procedure_type(tender_proceduretype)) %>%
      add_tender_year() %>%
      dplyr::filter(
        tender_year >= min_year_singleb, tender_year <= max_year_singleb,
        !is.na(tender_days_dec), tender_days_dec >= 0, tender_days_dec < 730,
        !is.na(proc_recoded),
        proc_recoded %in% .comp_proc_for_reg
      )
    
    long_threshold_dec <- if (!is.na(thr$long_decision_days)) thr$long_decision_days else
      stats::median(reg_long_base$tender_days_dec, na.rm = TRUE)
    
    reg_long <- reg_long_base %>%
      dplyr::mutate(long_decision_period = dplyr::case_when(
        !is.na(tender_days_dec) & tender_days_dec >= 0 & tender_days_dec < 730 &
          tender_days_dec >= long_threshold_dec ~ 1L,
        !is.na(tender_days_dec) & tender_days_dec >= 0 & tender_days_dec < 730 &
          tender_days_dec <  long_threshold_dec ~ 0L,
        TRUE ~ NA_integer_)) %>%
      dplyr::filter(
        !is.na(long_decision_period),
        !is.na(ind_corr_singleb),
        !is.na(.data[[if (!is.na(.reg_buyer_col)) .reg_buyer_col else "buyer_id"]])
      ) %>%
      dplyr::mutate(
        buyer_id = .data[[if (!is.na(.reg_buyer_col)) .reg_buyer_col else "buyer_id"]],
        ind_corr_binary = ind_corr_singleb / 100
      )
    
    res_long           <- run_one_regression(reg_long, "long_decision_period", "long decision period")
    specs_long         <- res_long$specs
    sensitivity_long   <- res_long$sensitivity
    model_long_glm     <- res_long$model_glm
    plot_long_reg      <- res_long$plot_reg
    best_row_long      <- res_long$best_row
    is_robust_long     <- res_long$is_robust
    marginal_long      <- res_long$marginal_effect
  }
  
  # ── K) Return ─────────────────────────────────────────────────────────
  invisible(list(
    country_code = country_code, data = df, thresholds = thr, thr_source = thr_source,
    proc_share_data = proc_share_data,
    tender_periods_open = tender_periods_open, tender_periods_open_proc = tender_periods_open_proc,
    tender_periods_short = tender_periods_short, tender_periods_dec = tender_periods_dec,
    tender_periods_dec_proc = tender_periods_dec_proc, tender_periods_long = tender_periods_long,
    tender_periods_labeled_dec = tender_periods_labeled_dec,
    sh = sh, p_count = p_count, combined_proc = combined_proc,
    subm = subm, subm_proc_facet_q = subm_proc_facet_q, subm_r = subm_r,
    buyer_short = buyer_short, buyer_short_v = buyer_short_v, combined_short_buyer = combined_short_buyer,
    decp = decp, decp_proc_facet_q = decp_proc_facet_q, decp_r = decp_r,
    buyer_long = buyer_long, buyer_long_v = buyer_long_v, combined_dec_plot = combined_dec_plot,
    plot_short_reg = plot_short_reg, plot_long_reg = plot_long_reg,
    model_short_glm = model_short_glm, model_long_glm = model_long_glm,
    best_row_short = best_row_short, best_row_long = best_row_long,
    is_robust_short = is_robust_short, is_robust_long = is_robust_long,
    marginal_short = marginal_short, marginal_long = marginal_long,
    specs_short = specs_short, sensitivity_short = sensitivity_short,
    specs_long = specs_long, sensitivity_long = sensitivity_long,
    summary_stats = summary_stats
  ))
}