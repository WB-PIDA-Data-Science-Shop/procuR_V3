# ============================================================================
# UNIFIED PROCUREMENT ANALYSIS APP — server.R (all reactive logic)
# ============================================================================
# Anchors [APP-SV01..SV35]; the master table of contents lives in global.R.
# This file must evaluate to the server function — the bare `server` on the
# last line is what Shiny picks up. (With the global.R/ui.R/server.R layout,
# shiny::runApp() assembles the app itself — no shinyApp() call exists
# anywhere in the code.)
# ============================================================================


# ==============================================================================
# SERVER
# ==============================================================================

server <- function(input, output, session) {
  
  
  # [APP-SV01] REACTIVE STATE — econ / admin / integ + per-tab filter stores ────
  # ============================================================
  # REACTIVE VALUES
  # ============================================================
  
  econ <- reactiveValues(
    data              = NULL,
    analysis          = NULL,
    filtered_data     = NULL,
    filtered_analysis = NULL,
    country_code      = NULL,
    cpv_lookup        = NULL,
    value_divisor     = 1,
    slider_trigger    = 0,
    # stored plotly figs — always match what's currently displayed
    fig_supp_bubble        = NULL,
    fig_supp_stability     = NULL,
    fig_supp_trend         = NULL,
    fig_top_suppliers      = NULL,
    fig_rel_buy            = NULL,
    fig_rel_size           = NULL,
    value_max_k            = NULL,
    fig_contracts_year_econ= NULL,
    fig_value_by_year      = NULL
  )
  
  admin <- reactiveValues(
    data              = NULL,
    analysis          = NULL,
    filtered_data     = NULL,
    filtered_analysis = NULL,
    country_code      = NULL,
    value_divisor     = 1,
    thresholds        = NULL,
    price_thresholds  = list(),
    global_proc_filter = PROC_TYPE_LABELS,
    bunching_fig              = NULL,
    fig_contracts_year        = NULL,
    fig_proc_share_value      = NULL,
    fig_proc_share_count      = NULL,
    fig_proc_value_dist       = NULL,
    fig_subm_dist             = NULL,
    fig_subm_proc             = NULL,
    fig_subm_short            = NULL,
    fig_buyer_short           = NULL,
    fig_dec_dist              = NULL,
    fig_dec_proc              = NULL,
    fig_dec_long              = NULL,
    fig_buyer_long            = NULL,
    fig_subm_share            = NULL,
    fig_dec_share             = NULL,
    gg_proc_share_value       = NULL,
    gg_proc_share_count       = NULL,
    gg_subm_dist              = NULL,
    gg_subm_proc              = NULL,
    gg_subm_short             = NULL,
    gg_buyer_short            = NULL,
    gg_dec_dist               = NULL,
    gg_dec_proc               = NULL,
    gg_dec_long               = NULL,
    gg_buyer_long             = NULL,
    value_max_k               = NULL,
    national_proc_keys        = character(0),   # keys for unrecognised proc types in dataset
    national_proc_labels      = list(),          # key -> raw label map
    regression_done           = FALSE
  )
  
  econ_filters <- reactiveValues(
    active      = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    overview    = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    market      = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    supplier    = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    network     = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    price       = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    competition = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL)
  )
  
  admin_filters <- reactiveValues(
    active   = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    overview = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    proc     = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    subm     = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    dec      = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    reg      = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL)
  )
  
  # Buyer/procedure type mappings (for econ section)
  econ_buyer_mapping       <- reactiveVal(NULL)
  econ_procedure_mapping   <- reactiveVal(NULL)
  admin_procedure_mapping  <- reactiveVal(NULL)
  
  # ── Integrity reactive state ──────────────────────────────────────────
  integ <- reactiveValues(
    data              = NULL,
    analysis          = NULL,
    filtered_data     = NULL,
    filtered_analysis = NULL,
    country_code      = NULL,
    value_divisor     = 1,
    network_done      = FALSE,
    regression_done   = FALSE,
    missing_advanced_done = FALSE,
    # stored plotly figs — always match what's currently displayed
    fig_contracts_year = NULL,
    fig_miss_overall   = NULL,
    fig_miss_buyer     = NULL,
    fig_miss_proc      = NULL,
    fig_miss_time      = NULL,
    fig_miss_cooc      = NULL,
    fig_miss_mar       = NULL,
    fig_supp_unusual   = NULL,
    fig_mkt_unusual    = NULL,
    fig_concentration  = NULL,
    fig_singleb        = NULL,
    fig_relprice       = NULL,
    value_max_k        = NULL
  )
  
  integ_filters <- reactiveValues(
    active   = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    data     = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    missing  = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    interop  = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    risky    = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL),
    prices   = list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL)
  )
  
  # integ_filtered_data: convenience accessor that returns the committed
  # filtered state (updated after Apply Filters is clicked).
  # Using integ$filtered_data directly keeps the overview value-boxes
  # in sync with the rest of the integrity analysis, and avoids reading
  # the now tab-specific filter input IDs from a context that has no tab.
  integ_filtered_data <- reactive({
    req(integ$filtered_data)
    integ$filtered_data
  })
  
  
  # [APP-SV02] ADMIN HELPER FUNCTIONS (server scope) ─────────────────────────
  # ============================================================
  # ADMIN HELPER FUNCTIONS
  # ============================================================
  
  get_thr_val <- function(proc_id, is_decision = FALSE) {
    no_thr_id <- paste0("no_thr_", proc_id)
    days_id   <- paste0("thr_days_", proc_id)
    if (isTRUE(input[[no_thr_id]])) NA_real_
    else { v <- input[[days_id]]; if (is.null(v) || is.na(v)) NA_real_ else as.numeric(v) }
  }
  
  get_outlier_method <- function(proc_id) {
    if (isTRUE(input[[paste0("no_thr_", proc_id)]])) input[[paste0("outlier_method_", proc_id)]] else NULL
  }
  
  get_medium_band <- function(proc_id) {
    no_med_val <- input[[paste0("no_medium_",   proc_id)]]
    min_val    <- input[[paste0("thr_med_min_", proc_id)]]
    max_val    <- input[[paste0("thr_med_max_", proc_id)]]
    if (is.null(no_med_val) && is.null(min_val))
      return(list(min = NA_real_, max = NA_real_))
    if (isTRUE(no_med_val)) {
      list(min = NA_real_, max = NA_real_)
    } else {
      list(
        min = if (!is.null(min_val)) as.numeric(min_val) else NA_real_,
        max = if (!is.null(max_val)) as.numeric(max_val) else NA_real_
      )
    }
  }
  
  apply_global_proc_filter <- function(df) {
    gf <- admin$global_proc_filter
    if (is.null(gf) || length(gf) == 0 || "tender_proceduretype" %ni% names(df)) return(df)
    proc_recoded <- recode_procedure_type(df$tender_proceduretype)
    df[!is.na(proc_recoded) & proc_recoded %in% gf, , drop = FALSE]
  }
  
  build_thresholds_list <- function(thr_loaded) {
    mk_subm <- function(days, med_min = NA_real_, med_max = NA_real_, no_med = NULL) {
      # no_med defaults to TRUE (no medium band) unless both min and max are
      # non-NA AND caller explicitly passes no_med=FALSE.
      if (is.null(no_med)) no_med <- is.na(med_min) || is.na(med_max)
      list(days = days, outlier_method = "iqr",
           medium = list(min = med_min, max = med_max), no_medium = no_med)
    }
    mk_dec <- function(days, short_days = NA_real_, med_min = NA_real_, med_max = NA_real_) {
      no_med <- is.na(med_min) || is.na(med_max)
      list(days = days, outlier_method = "iqr", short_days = short_days,
           medium = list(min = med_min, max = med_max), no_medium = no_med)
    }
    list(
      subm = list(
        open        = mk_subm(thr_loaded$subm_short_open,       thr_loaded$subm_medium_open_min, thr_loaded$subm_medium_open_max),
        restricted  = mk_subm(thr_loaded$subm_short_restricted, NA_real_, NA_real_),
        neg_pub     = mk_subm(thr_loaded$subm_short_negotiated, NA_real_, NA_real_),
        neg_nopub   = mk_subm(NA_real_),
        neg_unspec  = mk_subm(NA_real_),
        competitive = mk_subm(NA_real_),
        innov       = mk_subm(NA_real_),
        direct      = mk_subm(NA_real_),
        other       = mk_subm(NA_real_)
      ),
      dec = list(
        open        = mk_dec(thr_loaded$long_decision_days),
        restricted  = mk_dec(thr_loaded$long_decision_days),
        neg_pub     = mk_dec(thr_loaded$long_decision_days),
        neg_nopub   = mk_dec(NA_real_),
        neg_unspec  = mk_dec(NA_real_),
        competitive = mk_dec(NA_real_),
        innov       = mk_dec(NA_real_),
        direct      = mk_dec(NA_real_),
        other       = mk_dec(NA_real_)
      )
    )
  }
  
  pre_populate_config <- function(session, thr_loaded) {
    set_subm <- function(pid, days_val) {
      if (!is.na(days_val)) {
        updateCheckboxInput(session, paste0("no_thr_", pid),   value = FALSE)
        updateNumericInput(session,  paste0("thr_days_", pid), value = days_val)
      } else updateCheckboxInput(session, paste0("no_thr_", pid), value = TRUE)
    }
    set_subm("open",       thr_loaded$subm_short_open)
    set_subm("restricted", thr_loaded$subm_short_restricted)
    set_subm("neg_pub",    if (!is.null(thr_loaded$subm_short_negotiated)) thr_loaded$subm_short_negotiated else NA)
    if (!is.na(thr_loaded$subm_medium_open_min))
      updateNumericInput(session, "thr_med_min_open", value = thr_loaded$subm_medium_open_min)
    if (!is.na(thr_loaded$subm_medium_open_max))
      updateNumericInput(session, "thr_med_max_open", value = thr_loaded$subm_medium_open_max)
    # Decision thresholds — explicitly set the "No legal threshold" checkbox for
    # EVERY decision procedure type so the UI always matches admin$thresholds.
    # When long_decision_days is NA (e.g. BG) the checkbox must be TRUE so the
    # flagged-shares plot uses statistical derivation immediately without the
    # user having to click Apply.
    dec_pids <- c("dec_open","dec_restricted","dec_neg_pub",
                  "dec_neg_nopub","dec_neg_unspec","dec_competitive",
                  "dec_innov","dec_direct","dec_other")
    if (!is.na(thr_loaded$long_decision_days)) {
      for (pid in dec_pids) {
        updateCheckboxInput(session, paste0("no_thr_", pid),   value = FALSE)
        updateNumericInput(session,  paste0("thr_days_", pid), value = thr_loaded$long_decision_days)
      }
    } else {
      # NA threshold — tell UI to derive statistically so plots render immediately
      for (pid in dec_pids)
        updateCheckboxInput(session, paste0("no_thr_", pid), value = TRUE)
    }
    # Country-specific price thresholds
    # BG (Bulgaria): EU procurement thresholds in BGN
    #   Goods/Services: 300,000 BGN  |  Works: 10,000,000 BGN
    if (!is.null(thr_loaded$country_code) && toupper(thr_loaded$country_code) == "BG") {
      price_procs <- c("open","rest","neg_pub","neg_nopub","competitive","innov","direct","other")
      for (proc in price_procs) {
        updateNumericInput(session, paste0("price_", proc, "_goods"),    value = 300000)
        updateNumericInput(session, paste0("price_", proc, "_works"),    value = 10000000)
        updateNumericInput(session, paste0("price_", proc, "_services"), value = 300000)
      }
      showNotification(
        "ℹ️ BG price thresholds pre-filled: 300,000 BGN (Goods/Services), 10,000,000 BGN (Works).",
        type = "message", duration = 5
      )
    }
    # DL (Demoland — the bundled demo dataset): thresholds from DEMO_GUIDE.md
    if (!is.null(thr_loaded$country_code) && toupper(thr_loaded$country_code) == "DL") {
      price_procs <- c("open","rest","neg_pub","neg_nopub","competitive","innov","direct","other")
      for (proc in price_procs) {
        updateNumericInput(session, paste0("price_", proc, "_goods"),    value = 70000)
        updateNumericInput(session, paste0("price_", proc, "_works"),    value = 270000)
        updateNumericInput(session, paste0("price_", proc, "_services"), value = 70000)
      }
      showNotification(
        "ℹ️ Demoland demo thresholds pre-filled: 70,000 DLK (Goods/Services), 270,000 DLK (Works).",
        type = "message", duration = 6
      )
    }
  }
  
  
  # [APP-SV03] DATA UPLOAD & RUN — input$run_analysis: read CSV, normalize, detect country, run all 3 pipelines ────
  # ============================================================
  # SINGLE DATA UPLOAD — runs all three pipelines (econ, admin, integrity)
  # ============================================================
  
  # One pipeline, two entry points: the user's uploaded file, or the demo
  # dataset bundled with the app (demo-data/demo_procurement_data.csv).
  .data_request <- reactiveVal(NULL)
  observeEvent(input$run_analysis, {
    req(input$datafile)
    .data_request(list(path = input$datafile$datapath,
                       size = input$datafile$size))
  })
  output$demo_load_ui <- renderUI({
    if (!file.exists("demo-data/demo_procurement_data.csv")) return(NULL)
    tagList(
      actionButton("load_demo",
                   tags$span(icon("play-circle", class = "fa-lg"), " Run Demo"),
                   class = "btn-wb-success btn-lg",
                   style = "width:100%; padding:15px; font-size:18px;"),
      div(style = "text-align:center; margin:12px 0; color:#8a8a8a; font-weight:bold; letter-spacing:1px;",
          "— OR —")
    )
  })
  observeEvent(input$load_demo, {
    demo_path <- "demo-data/demo_procurement_data.csv"
    if (!file.exists(demo_path)) {
      showNotification("Demo dataset not found (expected demo-data/demo_procurement_data.csv next to the app files).",
                       type = "error", duration = 8)
      return()
    }
    .data_request(list(path = demo_path, size = file.info(demo_path)$size))
  })
  observeEvent(.data_request(), {
    req(.data_request())
    .src_path <- .data_request()$path
    .src_size <- .data_request()$size
    
    withProgress(message = "Loading data...", value = 0, {
      incProgress(0.05, detail = "Reading file...")
      
      tryCatch({
        # ---- Robust CSV reading ------------------------------------------------
        # Shiny saves uploads as extension-less temp files. Without explicit sep,
        # fread auto-detection can behave differently across data.table versions
        # and server locales, causing partial reads (wrong sep -> far fewer rows).
        # Strategy: detect sep from the first raw line, then read explicitly.
        # Check actual size of the temp file vs what Shiny reported
        reported_size <- .src_size
        actual_size   <- file.info(.src_path)$size
        raw_lines <- readLines(.src_path, n = 5, warn = FALSE,
                               encoding = "UTF-8")
        first_line <- raw_lines[1]
        sep_detected <- ","
        if (lengths(regmatches(first_line, gregexpr(";", first_line))) >
            lengths(regmatches(first_line, gregexpr(",", first_line))))
          sep_detected <- ";"
        else if (lengths(regmatches(first_line, gregexpr("\t", first_line))) >
                 lengths(regmatches(first_line, gregexpr(",", first_line))))
          sep_detected <- "\t"
        
        df <- fread(
          .src_path,
          sep              = sep_detected,
          header           = TRUE,
          keepLeadingZeros = TRUE,
          encoding         = "UTF-8",
          stringsAsFactors = FALSE,
          showProgress     = FALSE,
          na.strings       = c("", "-", "NA"),
          data.table       = TRUE
        )
        dup_cols <- duplicated(names(df))
        if (any(dup_cols)) df <- df[, !dup_cols, with = FALSE]
        df <- as.data.frame(df)
        # Coerce any IDate/Date columns to character so str_extract works
        # regardless of data.table version (>= 1.14.3 auto-detects dates)
        date_like_cols <- names(df)[sapply(df, function(x) inherits(x, c("IDate", "Date", "POSIXct", "POSIXlt")))]
        if (length(date_like_cols) > 0)
          df[date_like_cols] <- lapply(df[date_like_cols], as.character)
        
        # Normalise column structure early so all three pipelines benefit from
        # canonical column aliases even if the CSV uses national / limited names.
        # This maps e.g. buyer_id → buyer_masterid, entity_type → buyer_buyertype,
        # bidder_name → bidder_masterid, and bid_price → bid_priceusd (no FX conversion).
        df <- normalize_procurement_data(df)
        
        # --- Resolve country code ---
        # Auto-detect if user left blank, typed placeholder, or typed generic code
        user_cc  <- toupper(trimws(input$country_code %||% ""))
        use_auto <- nchar(user_cc) == 0 || user_cc %in% c("XX", "GEN", "NA")
        
        if (!use_auto) {
          country_code <- user_cc
        } else {
          auto_code <- NULL
          # Scan columns that often carry a single-valued country identifier
          for (col in c("tender_country", "buyer_country", "country_code", "country",
                        "tender_countryofpublication", "buyer_mainactivities")) {
            if (col %in% names(df)) {
              vals <- unique(df[[col]][!is.na(df[[col]])])
              vals <- vals[nchar(as.character(vals)) == 2]   # keep only 2-letter codes
              if (length(vals) == 1) {
                auto_code <- toupper(as.character(vals[1]))
                cat("Auto-detected country code from column '", col, "':", auto_code, "\n")
                showNotification(paste0("Auto-detected country: ", auto_code,
                                        " (from column '", col, "')"),
                                 type = "message", duration = 4)
                break
              }
            }
          }
          # Try majority-vote across multi-value columns as fallback
          if (is.null(auto_code)) {
            for (col in c("tender_country", "buyer_country", "country_code", "country")) {
              if (col %in% names(df)) {
                vals <- df[[col]][!is.na(df[[col]])]
                vals <- vals[nchar(as.character(vals)) == 2]
                if (length(vals) > 0) {
                  top <- names(sort(table(vals), decreasing = TRUE))[1]
                  if (!is.null(top) && nchar(top) == 2) {
                    auto_code <- toupper(top)
                    cat("Country code via majority vote from '", col, "':", auto_code, "\n")
                    showNotification(paste0("Country inferred: ", auto_code,
                                            " (majority in '", col, "')"),
                                     type = "message", duration = 4)
                    break
                  }
                }
              }
            }
          }
          country_code <- if (!is.null(auto_code) && nchar(auto_code) == 2) auto_code else "GEN"
        }
        
        # --- Econ pipeline (networks skipped here, generated on-demand in Networks tab) ---
        incProgress(0.15, detail = "Running economic outcomes analysis...")
        
        econ_results <- run_economic_efficiency_pipeline(
          df                   = df,
          country_code         = country_code,
          output_dir           = tempdir(),
          save_outputs         = FALSE,
          cpv_lookup           = cpv_lookup_global,
          network_cpv_clusters = character(0)   # always skip at load time
        )
        
        df_econ <- df
        if (!"tender_year" %in% names(df_econ)) df_econ <- add_tender_year(df_econ)
        if (!"cpv_cluster" %in% names(df_econ) && "lot_productcode" %in% names(df_econ))
          df_econ <- df_econ %>% mutate(cpv_cluster = substr(as.character(lot_productcode), 1, 2))
        if (!"tender_proceduretype" %in% names(df_econ)) df_econ$tender_proceduretype <- NA_character_
        if (!"buyer_buyertype" %in% names(df_econ)) df_econ$buyer_buyertype <- NA_character_
        
        # Normalise cpv_cluster on econ_results$df: any 2-digit code not in CPV_DESCRIPTIONS
        # is remapped to "99" so unknown markets collapse into one "99 - Other" bucket.
        # IMPORTANT: this must happen BEFORE econ$analysis and econ$data are assigned so
        # that apply_econ_filters / reset_econ_filters always read normalised codes and the
        # market filter dropdown never shows raw un-labelled codes like "CPV 22".
        if (!is.null(econ_results$df) && "cpv_cluster" %in% names(econ_results$df)) {
          known_codes <- names(CPV_DESCRIPTIONS)
          econ_results$df$cpv_cluster <- ifelse(
            econ_results$df$cpv_cluster %in% known_codes,
            econ_results$df$cpv_cluster,
            "99"
          )
          econ_results$df$cpv_category <- get_cpv_label(econ_results$df$cpv_cluster)
        }
        # Apply the same normalisation to supplier_stats so the supplier dynamics
        # picker and heatmaps use exactly the same market names as the market size plots.
        if (!is.null(econ_results$supplier_stats) &&
            "cpv_cluster" %in% names(econ_results$supplier_stats)) {
          known_codes <- names(CPV_DESCRIPTIONS)
          econ_results$supplier_stats$cpv_cluster <- ifelse(
            econ_results$supplier_stats$cpv_cluster %in% known_codes,
            econ_results$supplier_stats$cpv_cluster,
            "99"
          )
          # Re-aggregate: if unknowns were split across multiple original codes, merge them
          econ_results$supplier_stats <- econ_results$supplier_stats %>%
            dplyr::group_by(cpv_cluster, tender_year) %>%
            dplyr::summarise(
              n_suppliers        = sum(n_suppliers,        na.rm = TRUE),
              n_new_suppliers    = sum(n_new_suppliers,    na.rm = TRUE),
              n_repeat_suppliers = sum(n_repeat_suppliers, na.rm = TRUE),
              .groups = "drop"
            ) %>%
            dplyr::mutate(
              share_new    = n_new_suppliers    / pmax(n_suppliers, 1),
              share_repeat = n_repeat_suppliers / pmax(n_suppliers, 1)
            )
        }
        # Normalise df_econ (econ$data) the same way so the value filter widget and
        # any other consumer of econ$data also sees consistent CPV codes.
        if ("cpv_cluster" %in% names(df_econ)) {
          known_codes  <- names(CPV_DESCRIPTIONS)
          df_econ$cpv_cluster  <- ifelse(df_econ$cpv_cluster %in% known_codes, df_econ$cpv_cluster, "99")
          df_econ$cpv_category <- get_cpv_label(df_econ$cpv_cluster)
        }
        
        # Assign AFTER all normalisation is complete — R copy-on-modify means assigning
        # earlier would give econ$analysis$df the pre-normalisation codes.
        econ$data              <- df_econ
        econ$analysis          <- econ_results
        econ$filtered_data     <- econ_results$df
        econ$filtered_analysis <- econ_results
        econ$country_code      <- country_code
        econ$cpv_lookup        <- cpv_lookup_global
        
        incProgress(0.5, detail = "Running administrative efficiency analysis...")
        
        # --- Admin pipeline ---
        # The admin pipeline calls ggsave() unconditionally.
        # Override it with a no-op so it does not open a graphics device
        # (which can crash R in headless/Shiny environments).
        local_ggsave <- ggplot2::ggsave
        suppressMessages(
          assignInNamespace("ggsave", function(...) invisible(NULL), ns = "ggplot2")
        )
        on.exit(
          suppressMessages(
            assignInNamespace("ggsave", local_ggsave, ns = "ggplot2")
          ),
          add = TRUE
        )
        
        df_admin <- as.data.frame(df) %>% add_tender_year()
        if (!"tender_proceduretype" %in% names(df_admin)) df_admin$tender_proceduretype <- NA_character_
        if (!"buyer_buyertype" %in% names(df_admin)) df_admin$buyer_buyertype <- NA_character_
        
        admin_results <- run_admin_efficiency_pipeline(
          df              = df_admin,
          country_code    = country_code,
          output_dir      = tempdir(),
          run_regressions = FALSE,  # always skipped on load; run on demand from the Regression tab
          thresholds      = NULL
        )
        
        admin$data              <- df_admin
        admin$analysis          <- admin_results
        admin$filtered_data     <- df_admin
        admin$filtered_analysis <- admin_results
        admin$country_code      <- country_code
        
        # Initialize value_divisor so contract value filter works on first Apply
        # even before the currency widget has rendered and set it.
        local({
          pc <- intersect(c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"),
                          names(df_admin))[1]
          if (!is.na(pc)) {
            prices <- df_admin[[pc]]; prices <- prices[!is.na(prices) & prices > 0]
            if (length(prices) > 0) {
              loc <- detect_local_currency(df_admin)
              admin$local_currency <- loc
              admin$value_divisor  <- 1e3   # default: no currency conversion, values in K
              admin$value_max_k    <- ceiling(quantile(prices, 0.99, na.rm=TRUE) / 1e3)
            }
          }
        })
        
        thr_loaded         <- get_admin_thresholds(country_code)
        thr_loaded$country_code <- country_code   # pass through for country-specific pre-fills
        admin$thresholds   <- build_thresholds_list(thr_loaded)
        
        # Build country-specific price thresholds directly (not waiting for user to click Apply).
        # If no prefill exists for this country, price_thresholds stays empty and bunching
        # simply won't render — no error, just the "configure thresholds" prompt.
        country_price_thresholds <- local({
          cc <- toupper(country_code %||% "")
          if (cc == "BG") {
            bg_row <- function() list(goods=300000, works=10000000, services=300000)
            list(open=bg_row(), restricted=bg_row(), neg_pub=bg_row(),
                 neg_nopub=bg_row(), neg_unspec=bg_row(), competitive=bg_row(),
                 innov=bg_row(), direct=bg_row(), other=bg_row())
          } else {
            list()   # no prefill — bunching stays inactive, no error
          }
        })
        admin$price_thresholds <- country_price_thresholds
        
        pre_populate_config(session, thr_loaded)
        
        # After data loads, update the static procedure-filter checkbox groups
        # to include any national/unrecognised procedure types not in PROC_TYPE_LABELS.
        # recode_procedure_type() now preserves unknown values as-is, so we collect
        # all distinct labels (canonical + national) present in the loaded data.
        if ("tender_proceduretype" %in% names(df_admin)) {
          all_proc_labels <- sort(unique(stats::na.omit(
            recode_procedure_type(df_admin$tender_proceduretype)
          )))
          # Prepend canonical ordering; national types will appear at the end
          ordered_labels <- c(
            intersect(PROC_TYPE_LABELS, all_proc_labels),   # canonical first
            setdiff(all_proc_labels, PROC_TYPE_LABELS)      # national types last
          )
          if (length(ordered_labels) > 0) {
            updateCheckboxGroupInput(session, "global_proc_filter",
                                     choices  = ordered_labels,
                                     selected = ordered_labels)
            updateCheckboxGroupInput(session, "subm_proc_filter",
                                     choices  = ordered_labels,
                                     selected = ordered_labels)
            updateCheckboxGroupInput(session, "dec_proc_filter",
                                     choices  = ordered_labels,
                                     selected = ordered_labels)
            updateCheckboxGroupInput(session, "proc_value_dist_procs",
                                     choices  = ordered_labels,
                                     selected = intersect(
                                       c("Open Procedure","Restricted Procedure","Negotiated with publications"),
                                       ordered_labels
                                     ))
            # Store dynamic proc labels so select_all observers can use them
            admin$proc_type_labels  <- ordered_labels
            # Also update the reactive value immediately so apply_global_proc_filter
            # works right away with national proc types (before user clicks Apply Thresholds)
            admin$global_proc_filter <- ordered_labels
            
            # Detect national/unrecognised proc types — those whose proc_to_key() returns "other"
            # but which are NOT literally "Other". Build safe input IDs for threshold UI.
            nat_procs <- setdiff(all_proc_labels, PROC_TYPE_LABELS)
            if (length(nat_procs) > 0) {
              safe_key <- function(x) gsub("[^A-Za-z0-9]", "_", x)
              nat_keys <- sapply(nat_procs, safe_key)
              # Remove duplicates (in case two raw values produce the same safe key)
              nat_keys <- nat_keys[!duplicated(nat_keys)]
              nat_labels <- setNames(as.list(nat_procs[!duplicated(nat_keys)]), nat_keys)
              admin$national_proc_keys   <- nat_keys
              admin$national_proc_labels <- nat_labels
              # Pre-populate thresholds with statistical fallback for national types
              thr_cur <- admin$thresholds %||% list(subm=list(), dec=list())
              for (k in nat_keys) {
                if (is.null(thr_cur$subm[[k]]))
                  thr_cur$subm[[k]] <- list(days=NA_real_, outlier_method="iqr",
                                            medium=list(min=NA_real_,max=NA_real_), no_medium=TRUE)
                if (is.null(thr_cur$dec[[k]]))
                  thr_cur$dec[[k]] <- list(days=NA_real_, outlier_method="iqr",
                                           short_days=NA_real_,
                                           medium=list(min=NA_real_,max=NA_real_), no_medium=TRUE)
              }
              admin$thresholds <- thr_cur
            } else {
              admin$national_proc_keys   <- character(0)
              admin$national_proc_labels <- list()
            }
          }
        }
        
        incProgress(0.95, detail = "Finalizing...")
        
        output$analysis_status <- renderText({
          tryCatch({
            paste0(
              "\u2713 Analysis complete!\n",
              "Country: ", country_code, "\n",
              "Rows: ", formatC(nrow(df), format = "d", big.mark = ","), "\n",
              "Columns: ", ncol(df), "\n",
              "All column names:\n", paste(sort(names(df)), collapse=", ")
            )
          }, error = function(e) paste0("Status render error: ", e$message))
        })
        
        # --- Integrity pipeline ---
        incProgress(0.90, detail = "Running procurement integrity analysis...")
        tryCatch({
          integ_df <- as.data.frame(df)
          integ_results <- run_integrity_pipeline_fast_local(
            df           = integ_df,
            country_code = country_code,
            output_dir   = tempdir()
          )
          integ$data              <- integ_results$data
          integ$analysis          <- integ_results
          integ$filtered_data     <- integ_results$data
          integ$filtered_analysis <- integ_results
          integ$country_code      <- country_code
          integ$network_done      <- FALSE
          integ$regression_done   <- FALSE
          integ$missing_advanced_done <- FALSE
        }, error = function(e_integ) {
          warning("Integrity pipeline error: ", e_integ$message)
          showNotification(paste("Integrity pipeline warning:", e_integ$message),
                           type = "warning", duration = 8)
        })
        
        showNotification(
          "\u2713 Economic + Administrative + Integrity analyses complete! Navigate tabs to explore results.",
          type = "message", duration = 6
        )
        
      }, error = function(e) {
        output$analysis_status <- renderText(paste("Error:", e$message))
        showNotification(paste("Error:", e$message), type = "error", duration = NULL)
      })
    })
  })
  
  
  # [APP-SV04] ADMIN — APPLY THRESHOLDS (global + per-tab subm/dec buttons, national proc-type UI) ────
  # ============================================================
  # ADMIN — APPLY THRESHOLDS
  # ============================================================
  
  observeEvent(input$apply_thresholds, {
    req(admin$data)
    subm_keys <- c("open","restricted","neg_pub","neg_nopub","neg_unspec","competitive","innov","direct","other")
    thr_new   <- list(subm = list(), dec = list())
    
    for (k in subm_keys) {
      med         <- get_medium_band(k)
      no_med_val  <- input[[paste0("no_medium_", k)]]
      no_med_flag <- if (is.null(no_med_val)) TRUE else isTRUE(no_med_val)
      thr_new$subm[[k]] <- list(days = get_thr_val(k), outlier_method = get_outlier_method(k),
                                medium = med, no_medium = no_med_flag)
    }
    for (k in subm_keys) {
      dk <- paste0("dec_", k)
      thr_new$dec[[k]] <- list(days = get_thr_val(dk, is_decision = TRUE), outlier_method = get_outlier_method(dk))
    }
    admin$thresholds <- thr_new
    
    read_price_row <- function(prefix) {
      list(
        goods    = as.numeric(input[[paste0("price_", prefix, "_goods")]]),
        works    = as.numeric(input[[paste0("price_", prefix, "_works")]]),
        services = as.numeric(input[[paste0("price_", prefix, "_services")]])
      )
    }
    admin$price_thresholds <- list(
      open        = read_price_row("open"),
      restricted  = read_price_row("rest"),
      neg_pub     = read_price_row("neg_pub"),
      neg_nopub   = read_price_row("neg_nopub"),
      neg_unspec  = read_price_row("neg_nopub"),  # shares threshold with neg_nopub by default
      competitive = read_price_row("competitive"),
      innov       = read_price_row("innov"),
      direct      = read_price_row("direct"),
      other       = read_price_row("other")
    )
    
    gf <- input$global_proc_filter
    admin$global_proc_filter <- if (is.null(gf) || length(gf) == 0) PROC_TYPE_LABELS else gf
    
    showNotification("\u2713 Thresholds applied — all admin plots updated.", type = "message", duration = 4)
  })
  
  observeEvent(input$select_all_procs,   {
    lbl <- admin$proc_type_labels %||% PROC_TYPE_LABELS
    updateCheckboxGroupInput(session, "global_proc_filter", selected = lbl)
  })
  observeEvent(input$deselect_all_procs, { updateCheckboxGroupInput(session, "global_proc_filter", selected = character(0)) })
  
  # Keep admin$global_proc_filter live-synced to checkbox — not just on Apply Thresholds
  observeEvent(input$global_proc_filter, {
    gf <- input$global_proc_filter
    admin$global_proc_filter <- if (is.null(gf) || length(gf) == 0)
      admin$proc_type_labels %||% PROC_TYPE_LABELS
    else gf
  }, ignoreNULL = FALSE)
  
  # ── Per-tab procedure filter select-all/deselect-all ──────────────────
  observeEvent(input$subm_proc_select_all,   {
    lbl <- admin$proc_type_labels %||% PROC_TYPE_LABELS
    updateCheckboxGroupInput(session, "subm_proc_filter", selected = lbl)
  })
  observeEvent(input$subm_proc_deselect_all, { updateCheckboxGroupInput(session, "subm_proc_filter", selected = character(0)) })
  observeEvent(input$dec_proc_select_all,    {
    lbl <- admin$proc_type_labels %||% PROC_TYPE_LABELS
    updateCheckboxGroupInput(session, "dec_proc_filter",  selected = lbl)
  })
  observeEvent(input$dec_proc_deselect_all,  { updateCheckboxGroupInput(session, "dec_proc_filter",  selected = character(0)) })
  
  # ── Apply submission thresholds (tab-local button) ─────────────────────
  observeEvent(input$apply_thresholds_subm, {
    req(admin$data)
    subm_keys <- c("open","restricted","neg_pub","neg_nopub","neg_unspec","competitive","innov","direct","other")
    thr_cur   <- if (is.null(admin$thresholds)) list(subm = list(), dec = list()) else admin$thresholds
    for (k in subm_keys) {
      med         <- get_medium_band(k)
      no_med_val  <- input[[paste0("no_medium_", k)]]
      no_med_flag <- if (is.null(no_med_val)) TRUE else isTRUE(no_med_val)
      thr_cur$subm[[k]] <- list(days = get_thr_val(k), outlier_method = get_outlier_method(k),
                                medium = med, no_medium = no_med_flag)
    }
    # Also read thresholds for any national proc types shown in the dynamic section
    for (nat_key in (admin$national_proc_keys %||% character(0))) {
      raw_days  <- suppressWarnings(as.numeric(input[[paste0("nat_subm_days_",   nat_key)]]))
      no_thr    <- isTRUE(input[[paste0("nat_subm_no_thr_",  nat_key)]])
      no_med    <- isTRUE(input[[paste0("nat_subm_no_med_",  nat_key)]])
      raw_m_min <- suppressWarnings(as.numeric(input[[paste0("nat_subm_med_min_", nat_key)]]))
      raw_m_max <- suppressWarnings(as.numeric(input[[paste0("nat_subm_med_max_", nat_key)]]))
      thr_cur$subm[[nat_key]] <- list(
        days           = if (no_thr || is.na(raw_days)) NA_real_ else raw_days,
        outlier_method = input[[paste0("nat_subm_method_", nat_key)]] %||% "iqr",
        medium         = list(min = if (no_med || is.na(raw_m_min)) NA_real_ else raw_m_min,
                              max = if (no_med || is.na(raw_m_max)) NA_real_ else raw_m_max),
        no_medium      = no_med
      )
    }
    admin$thresholds <- thr_cur
    showNotification("\u2713 Submission thresholds applied.", type = "message", duration = 3)
  })
  
  # ── Apply decision thresholds (tab-local button) ───────────────────────
  observeEvent(input$apply_thresholds_dec, {
    req(admin$data)
    subm_keys <- c("open","restricted","neg_pub","neg_nopub","neg_unspec","competitive","innov","direct","other")
    thr_cur   <- if (is.null(admin$thresholds)) list(subm = list(), dec = list()) else admin$thresholds
    for (k in subm_keys) {
      dk         <- paste0("dec_", k)
      med_dec    <- get_medium_band(dk)
      no_med_val <- input[[paste0("no_medium_", dk)]]
      no_med_flg <- if (is.null(no_med_val)) TRUE else isTRUE(no_med_val)
      # Short cutoff for decision (optional — how short is "too quick"?)
      raw_short  <- suppressWarnings(as.numeric(input[[paste0("dec_short_days_", k)]]))
      thr_cur$dec[[k]] <- list(
        days           = get_thr_val(dk, is_decision = TRUE),
        outlier_method = get_outlier_method(dk),
        short_days     = if (is.na(raw_short)) NA_real_ else raw_short,
        medium         = med_dec,
        no_medium      = no_med_flg
      )
    }
    # National proc types
    for (nat_key in (admin$national_proc_keys %||% character(0))) {
      raw_days  <- suppressWarnings(as.numeric(input[[paste0("nat_dec_days_",    nat_key)]]))
      no_thr    <- isTRUE(input[[paste0("nat_dec_no_thr_",   nat_key)]])
      raw_short <- suppressWarnings(as.numeric(input[[paste0("nat_dec_short_",   nat_key)]]))
      no_med    <- isTRUE(input[[paste0("nat_dec_no_med_",   nat_key)]])
      raw_m_min <- suppressWarnings(as.numeric(input[[paste0("nat_dec_med_min_", nat_key)]]))
      raw_m_max <- suppressWarnings(as.numeric(input[[paste0("nat_dec_med_max_", nat_key)]]))
      thr_cur$dec[[nat_key]] <- list(
        days           = if (no_thr || is.na(raw_days)) NA_real_ else raw_days,
        outlier_method = input[[paste0("nat_dec_method_", nat_key)]] %||% "iqr",
        short_days     = if (is.na(raw_short)) NA_real_ else raw_short,
        medium         = list(min = if (no_med || is.na(raw_m_min)) NA_real_ else raw_m_min,
                              max = if (no_med || is.na(raw_m_max)) NA_real_ else raw_m_max),
        no_medium      = no_med
      )
    }
    admin$thresholds <- thr_cur
    showNotification("\u2713 Decision thresholds applied.", type = "message", duration = 3)
  })
  
  # ── Dynamic national proc type threshold UI ──────────────────────────────
  # Renders numeric input boxes for procedure types in the dataset that don't
  # match any canonical category (e.g. country-specific raw codes).
  output$national_subm_thresholds_ui <- renderUI({
    nat_keys <- admin$national_proc_keys %||% character(0)
    if (length(nat_keys) == 0) return(NULL)
    tagList(
      hr(),
      tags$p(style="color:#7d6608; font-weight:bold; margin-bottom:6px;",
             icon("info-circle"), " National/non-standard procedure types detected in your data:"),
      fluidRow(
        lapply(nat_keys, function(k) {
          label <- admin$national_proc_labels[[k]] %||% k
          no_thr_id  <- paste0("nat_subm_no_thr_", k)
          days_id    <- paste0("nat_subm_days_",   k)
          method_id  <- paste0("nat_subm_method_", k)
          no_med_id  <- paste0("nat_subm_no_med_", k)
          med_min_id <- paste0("nat_subm_med_min_", k)
          med_max_id <- paste0("nat_subm_med_max_", k)
          column(3, div(class="proc-section",
                        tags$strong(style="font-size:12px;", label),
                        checkboxInput(no_thr_id, "No legal threshold (derive statistically)", value = TRUE),
                        conditionalPanel(
                          condition = paste0("!input['", no_thr_id, "']"),
                          numericInput(days_id, "Short threshold (days):", value = NA, min = 0, step = 1)
                        ),
                        conditionalPanel(
                          condition = paste0("input['", no_thr_id, "']"),
                          selectInput(method_id, "Statistical method:", choices = CUTOFF_CHOICES, selected = "iqr")
                        ),
                        hr(style = "margin: 4px 0;"),
                        checkboxInput(no_med_id, "No medium band", value = TRUE),
                        conditionalPanel(
                          condition = paste0("!input['", no_med_id, "']"),
                          fluidRow(
                            column(6, numericInput(med_min_id, "Med. min (days):", value = NA, min = 0, step = 1)),
                            column(6, numericInput(med_max_id, "Med. max (days):", value = NA, min = 0, step = 1))
                          )
                        )
          ))
        })
      )
    )
  })
  
  output$national_dec_thresholds_ui <- renderUI({
    nat_keys <- admin$national_proc_keys %||% character(0)
    if (length(nat_keys) == 0) return(NULL)
    tagList(
      hr(),
      tags$p(style="color:#7d6608; font-weight:bold; margin-bottom:6px;",
             icon("info-circle"), " National/non-standard procedure types detected in your data:"),
      fluidRow(
        lapply(nat_keys, function(k) {
          label      <- admin$national_proc_labels[[k]] %||% k
          no_thr_id  <- paste0("nat_dec_no_thr_",   k)
          days_id    <- paste0("nat_dec_days_",      k)
          method_id  <- paste0("nat_dec_method_",    k)
          short_id   <- paste0("nat_dec_short_",     k)
          no_med_id  <- paste0("nat_dec_no_med_",    k)
          med_min_id <- paste0("nat_dec_med_min_",   k)
          med_max_id <- paste0("nat_dec_med_max_",   k)
          column(3, div(class="proc-section",
                        tags$strong(style="font-size:12px;", label),
                        checkboxInput(no_thr_id, "No legal threshold (derive statistically)", value = TRUE),
                        conditionalPanel(
                          condition = paste0("!input['", no_thr_id, "']"),
                          numericInput(days_id, "Too-long threshold (days):", value = NA, min = 0, step = 1)
                        ),
                        conditionalPanel(
                          condition = paste0("input['", no_thr_id, "']"),
                          selectInput(method_id, "Statistical method:", choices = CUTOFF_CHOICES, selected = "iqr")
                        ),
                        conditionalPanel(
                          condition = paste0("!input['", no_thr_id, "']"),
                          numericInput(short_id, "Too-short threshold (days, optional):", value = NA, min = 0, step = 1)
                        ),
                        hr(style = "margin: 4px 0;"),
                        checkboxInput(no_med_id, "No medium band", value = TRUE),
                        conditionalPanel(
                          condition = paste0("!input['", no_med_id, "']"),
                          fluidRow(
                            column(6, numericInput(med_min_id, "Med. min (days):", value = NA, min = 0, step = 1)),
                            column(6, numericInput(med_max_id, "Med. max (days):", value = NA, min = 0, step = 1))
                          )
                        )
          ))
        })
      )
    )
  })
  
  output$threshold_status_subm <- renderText({ if (is.null(admin$thresholds)) "" else "Thresholds active \u2713" })
  output$threshold_status_dec  <- renderText({ if (is.null(admin$thresholds)) "" else "Thresholds active \u2713" })
  output$threshold_status  <- renderText({ if (is.null(admin$thresholds)) "" else "Thresholds active \u2713" })
  
  
  # [APP-SV05] ADMIN — RE-RUN REGRESSIONS ON DEMAND ──────────────────────────
  # ============================================================
  # ADMIN — RE-RUN REGRESSIONS ON DEMAND
  # ============================================================
  
  output$regression_status_box <- renderUI({
    if (!is.null(admin$filtered_analysis$plot_short_reg) || !is.null(admin$filtered_analysis$plot_long_reg))
      div(class = "reg-status-ok", icon("check-circle"), " Regression results available and up to date.")
    else
      div(class = "reg-status-wait", icon("clock"), " No results yet. Set your filters, then click Run.")
  })
  
  observeEvent(input$run_regressions_now, {
    req(admin$filtered_data, admin$country_code)
    withProgress(message = "Running regression analysis...", value = 0, {
      incProgress(0.1, detail = "Preparing data...")
      tryCatch({
        reg_results <- run_admin_efficiency_pipeline(
          df              = admin$filtered_data,
          country_code    = admin$country_code,
          output_dir      = tempdir(),
          run_regressions = TRUE,
          thresholds      = admin$thresholds
        )
        for (nm in c("plot_short_reg","plot_long_reg","sensitivity_short","sensitivity_long",
                     "specs_short","specs_long","model_short_glm","model_long_glm",
                     "best_row_short","best_row_long","is_robust_short","is_robust_long",
                     "marginal_short","marginal_long"))
          admin$filtered_analysis[[nm]] <- reg_results[[nm]]
        admin$regression_done <- TRUE
        incProgress(1, detail = "Done.")
        showNotification("Regression analysis complete!", type = "message", duration = 5)
      }, error = function(e) showNotification(paste("Error:", e$message), type = "error", duration = 10))
    })
  })
  
  
  # [APP-SV06] FILTER UI GENERATION — ECON (per-tab widgets + slider sync) ────
  # ============================================================
  # FILTER UI GENERATION — ECON SECTION
  # ============================================================
  
  # VALUE FILTER SYNC: coarse M slider → precise K inputs
  # Defined here so it is available to all three section filter loops below.
  make_slider_sync <- function(coarse_id, min_k_id, max_k_id, rate_fn) {
    observeEvent(input[[coarse_id]], {
      v <- input[[coarse_id]]; req(!is.null(v))
      rate <- rate_fn()
      updateNumericInput(session, min_k_id, value = floor(v[1] * 1e3))
      updateNumericInput(session, max_k_id, value = ceiling(v[2] * 1e3))
    }, ignoreInit = TRUE)
  }
  
  econ_tabs <- c("overview","market","supplier","network","price","competition")
  
  # ── Per-tab filter widget builders — each tab gets its own unique input IDs
  #    to avoid Shiny's "duplicate input ID" warning that occurs when the same
  #    pickerInput/sliderInput ID is inserted into multiple uiOutput containers
  #    that all live in the DOM simultaneously.
  #    Naming convention: econ_yr_{tab}, econ_mkt_{tab}, econ_val_{tab},
  #                       econ_btype_{tab}, econ_ptype_{tab}
  # ──────────────────────────────────────────────────────────────────────────
  .econ_year_widget <- function(t) {
    req(econ$filtered_data)
    years <- econ$filtered_data$tender_year; years <- years[!is.na(years)]
    if ("tender_year" %in% names(econ$filtered_data) && length(years) > 0)
      sliderInput(paste0("econ_yr_", t), "Year Range:",
                  min=min(years), max=max(years), value=c(min(years),max(years)), step=1, sep="")
  }
  .econ_market_widget <- function(t) {
    # Read choices from FULL unfiltered data so the widget does not re-render
    # (and lose its selection) every time a different filter is applied.
    src <- if (!is.null(econ$data)) econ$data else econ$filtered_data
    req(!is.null(src))
    if (!"cpv_cluster" %in% names(src)) return(NULL)
    cpv_codes <- sort(unique(src$cpv_cluster))
    cpv_codes <- cpv_codes[!is.na(cpv_codes) & cpv_codes != ""]
    if (length(cpv_codes) == 0) return(NULL)
    cpv_choices <- setNames(cpv_codes, sapply(cpv_codes, get_cpv_label))
    # Restore active selection so switching tabs does not wipe the picker
    cur_sel <- econ_filters$active$market %||% character(0)
    pickerInput(paste0("econ_mkt_", t), "Market (CPV):",
                choices  = cpv_choices,
                selected = cur_sel,
                multiple = TRUE,
                options  = list(`actions-box` = TRUE, `live-search` = TRUE,
                                `none-selected-text` = "All markets"))
  }
  .econ_value_widget <- function(t) {
    src <- if (!is.null(econ$data)) econ$data else econ$filtered_data
    req(!is.null(src))
    price_col <- detect_price_col(src, c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"))
    if (is.na(price_col)) return(NULL)
    prices <- src[[price_col]]; prices <- prices[!is.na(prices) & prices > 0]
    if (length(prices) == 0) return(NULL)
    # Detect the local currency from the data (never hardcoded)
    loc_cur  <- detect_local_currency(src)
    cur      <- input[[paste0("econ_val_cur_", t)]] %||% "USD"
    rate     <- if (cur == loc_cur$label && cur != "USD") loc_cur$rate else 1
    div      <- 1e3
    econ$value_divisor   <- div / rate
    econ$value_max_k     <- ceiling(max(prices) * rate / div)
    econ$local_currency  <- loc_cur
    make_value_filter_widget(prices, paste0("econ_val_cur_", t), paste0("econ_val_rng_", t),
                             cur, local_currency = loc_cur)
  }
  .econ_buyer_widget <- function(t) {
    src <- if (!is.null(econ$data)) econ$data else econ$filtered_data
    req(!is.null(src))
    if (!"buyer_buyertype" %in% names(src)) return(NULL)
    raw_types <- unique(src$buyer_buyertype); raw_types <- raw_types[!is.na(raw_types)]
    if (length(raw_types) == 0) return(NULL)
    df_map <- data.frame(raw=raw_types, group=as.character(add_buyer_group(raw_types)), stringsAsFactors=FALSE)
    econ_buyer_mapping(df_map)
    cur_sel <- econ_filters$active$buyer_type %||% character(0)
    pickerInput(paste0("econ_btype_", t), "Buyer Type:",
                choices  = sort(unique(df_map$group)),
                selected = cur_sel,
                multiple = TRUE,
                options  = list(`actions-box` = TRUE,
                                `none-selected-text` = "All buyer types"))
  }
  .econ_proc_widget <- function(t) {
    src <- if (!is.null(econ$data)) econ$data else econ$filtered_data
    req(!is.null(src))
    if (!"tender_proceduretype" %in% names(src)) return(NULL)
    raw_types <- unique(src$tender_proceduretype); raw_types <- raw_types[!is.na(raw_types)]
    if (length(raw_types) == 0) return(NULL)
    df_map <- data.frame(raw=raw_types, cleaned=recode_procedure_type(raw_types), stringsAsFactors=FALSE)
    econ_procedure_mapping(df_map)
    cur_sel <- econ_filters$active$procedure_type %||% character(0)
    pickerInput(paste0("econ_ptype_", t), "Procedure Type:",
                choices  = sort(unique(df_map$cleaned)),
                selected = cur_sel,
                multiple = TRUE,
                options  = list(`actions-box` = TRUE, `live-search` = TRUE,
                                `none-selected-text` = "All procedure types"))
  }
  
  for (tab in econ_tabs) {
    local({
      t <- tab
      output[[paste0("econ_year_filter_",           t)]] <- renderUI(.econ_year_widget(t))
      output[[paste0("econ_market_filter_",         t)]] <- renderUI(.econ_market_widget(t))
      output[[paste0("econ_value_filter_",          t)]] <- renderUI(.econ_value_widget(t))
      output[[paste0("econ_buyer_type_filter_",     t)]] <- renderUI(.econ_buyer_widget(t))
      output[[paste0("econ_procedure_type_filter_", t)]] <- renderUI(.econ_proc_widget(t))
      output[[paste0("econ_filter_status_",         t)]] <- renderText({
        econ$slider_trigger
        paste("  📋", get_filter_description(econ_filters$active))
      })
      # Per-tab coarse↔fine slider sync for the value filter
      make_slider_sync(
        paste0("econ_val_rng_", t, "_coarse"),
        paste0("econ_val_rng_", t, "_min_k"),
        paste0("econ_val_rng_", t, "_max_k"),
        local({ tt <- t; function() {
          loc <- econ$local_currency %||% list(label = "USD", rate = 1)
          cur <- input[[paste0("econ_val_cur_", tt)]] %||% "USD"
          if (cur == loc$label && cur != "USD") loc$rate else 1
        }})
      )
    })
  }
  
  
  # [APP-SV07] FILTER APPLICATION — ECON (apply/reset per tab) ───────────────
  # ============================================================
  # FILTER APPLICATION — ECON
  # ============================================================
  
  apply_econ_filters <- function(tab_name) {
    req(econ$data, econ$analysis)
    tryCatch({
      current_filters <- list(
        year           = input[[paste0("econ_yr_",    tab_name)]],
        market         = input[[paste0("econ_mkt_",   tab_name)]],
        value = {
          mn_k <- input[[paste0("econ_val_rng_", tab_name, "_min_k")]]
          mx_k <- input[[paste0("econ_val_rng_", tab_name, "_max_k")]]
          mn <- if (is.null(mn_k) || is.na(mn_k)) 0 else mn_k
          mx <- if (is.null(mx_k) || is.na(mx_k)) (econ$value_max_k %||% 1e9) else mx_k
          c(mn, mx)
        },
        buyer_type     = input[[paste0("econ_btype_", tab_name)]],
        procedure_type = input[[paste0("econ_ptype_", tab_name)]]
      )
      econ_filters$active        <- current_filters
      econ_filters[[tab_name]]   <- current_filters
      
      filtered <- econ_filter_data(
        df             = econ$analysis$df,
        year_range     = current_filters$year,
        market         = current_filters$market,
        value_range    = current_filters$value,
        buyer_type     = current_filters$buyer_type,
        procedure_type = current_filters$procedure_type,
        value_divisor  = econ$value_divisor,
        buyer_mapping  = econ_buyer_mapping(),
        procedure_mapping = econ_procedure_mapping()
      )
      econ$filtered_data      <- filtered
      econ$slider_trigger     <- econ$slider_trigger + 1
      
      # Recompute market sizing plots from filtered data (fast, no networks/regressions)
      tryCatch({
        price_var <- detect_price_col(filtered)
        ms <- summarise_market_size(filtered, value_col = price_var)
        econ$filtered_analysis$market_size_n  <- plot_market_contract_counts(ms)
        econ$filtered_analysis$market_size_v  <- plot_market_total_value(ms)
        econ$filtered_analysis$market_size_av <- plot_market_bubble(ms)
        # Supplier entry: three-tier ID + CPV-aware re-compute after filter
        sup_id_filter <- intersect(c("bidder_masterid", "bidder_id", "bidder_name"), names(filtered))[1]
        if (!is.na(sup_id_filter) && "tender_year" %in% names(filtered)) {
          has_cpv_filter <- "cpv_cluster" %in% names(filtered) && any(!is.na(filtered$cpv_cluster))
          if (has_cpv_filter) {
            ss <- tryCatch(
              compute_supplier_entry(filtered, supplier_id_col = sup_id_filter),
              error = function(e) NULL)
            if (!is.null(ss) && "cpv_cluster" %in% names(ss)) {
              known_codes    <- names(CPV_DESCRIPTIONS)
              ss$cpv_cluster <- ifelse(ss$cpv_cluster %in% known_codes, ss$cpv_cluster, "99")
              ss <- ss %>%
                dplyr::group_by(cpv_cluster, tender_year) %>%
                dplyr::summarise(
                  n_suppliers        = sum(n_suppliers,        na.rm = TRUE),
                  n_new_suppliers    = sum(n_new_suppliers,    na.rm = TRUE),
                  n_repeat_suppliers = sum(n_repeat_suppliers, na.rm = TRUE),
                  .groups = "drop"
                ) %>%
                dplyr::mutate(
                  share_new    = n_new_suppliers    / pmax(n_suppliers, 1),
                  share_repeat = n_repeat_suppliers / pmax(n_suppliers, 1)
                )
            }
            econ$filtered_analysis$supplier_stats <- ss
          } else {
            # No CPV — recompute the aggregate chart
            agg_filter <- tryCatch(
              compute_supplier_entry_aggregate(filtered, supplier_id_col = sup_id_filter),
              error = function(e) NULL)
            econ$filtered_analysis$supplier_entry_agg <- if (!is.null(agg_filter))
              tryCatch(plot_supplier_entry_aggregate(agg_filter, supplier_id_col = sup_id_filter),
                       error = function(e) NULL)
            else NULL
          }
        }
      }, error = function(e) message("Market sizing update: ", e$message))
      
      showNotification(paste("Econ filters applied:", scales::comma(nrow(filtered)), "contracts"),
                       type = "message", duration = 2)
    }, error = function(e) {
      showNotification(paste("Filter error:", e$message), type = "error", duration = 8)
    })
  }
  
  reset_econ_filters <- function(tab_name) {
    empty <- list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL)
    econ_filters$active      <- empty
    econ_filters[[tab_name]] <- empty
    econ$filtered_data       <- econ$analysis$df
    econ$filtered_analysis   <- econ$analysis   # restore full pre-computed plots
    econ$slider_trigger      <- econ$slider_trigger + 1
    showNotification("Econ filters reset", type = "message", duration = 2)
  }
  
  
  
  for (tn in econ_tabs) {
    local({
      t <- tn
      observeEvent(input[[paste0("econ_apply_filters_", t)]],  { apply_econ_filters(t) })
      observeEvent(input[[paste0("econ_reset_filters_",  t)]], { reset_econ_filters(t) })
    })
  }
  
  
  # [APP-SV08] FILTER APPLICATION — ADMIN ────────────────────────────────────
  # ============================================================
  # FILTER APPLICATION — ADMIN
  # ============================================================
  
  apply_admin_filters <- function(tab_name) {
    req(admin$data)
    tryCatch({
      current_filters <- list(
        year           = input[[paste0("admin_yr_",    tab_name)]],
        market         = input[[paste0("admin_mkt_",   tab_name)]],
        value = {
          mn_k <- input[[paste0("admin_val_rng_", tab_name, "_min_k")]]
          mx_k <- input[[paste0("admin_val_rng_", tab_name, "_max_k")]]
          mn <- if (is.null(mn_k) || is.na(mn_k)) 0 else mn_k
          mx <- if (is.null(mx_k) || is.na(mx_k)) (admin$value_max_k %||% 1e9) else mx_k
          c(mn, mx)
        },
        buyer_type     = input[[paste0("admin_btype_", tab_name)]],
        procedure_type = input[[paste0("admin_ptype_", tab_name)]]
      )
      admin_filters$active      <- current_filters
      admin_filters[[tab_name]] <- current_filters
      
      filtered <- admin_filter_data(
        df                 = admin$data,
        year_range         = current_filters$year,
        market             = current_filters$market,
        value_range        = current_filters$value,
        buyer_type         = current_filters$buyer_type,
        procedure_type     = current_filters$procedure_type,
        value_divisor      = admin$value_divisor,
        procedure_mapping  = admin_procedure_mapping()
      )
      if (!"tender_year" %in% names(filtered)) filtered <- add_tender_year(filtered)
      if (!"tender_proceduretype" %in% names(filtered)) filtered$tender_proceduretype <- NA_character_
      if (!"buyer_buyertype" %in% names(filtered)) filtered$buyer_buyertype <- NA_character_
      admin$filtered_data <- filtered
      
      showNotification(paste("Admin filters applied:", formatC(nrow(filtered), format = "d", big.mark = ",")),
                       type = "message", duration = 3)
    }, error = function(e) {
      showNotification(paste("Filter error:", e$message), type = "error", duration = 8)
    })
  }
  
  reset_admin_filters <- function(tab_name) {
    empty <- list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL)
    admin_filters$active      <- empty
    admin_filters[[tab_name]] <- empty
    admin$filtered_data       <- admin$data
    admin$filtered_analysis   <- admin$analysis
    admin$regression_done     <- FALSE
    showNotification("Admin filters reset", type = "message", duration = 2)
  }
  
  
  # [APP-SV09] FILTER UI GENERATION — ADMIN ──────────────────────────────────
  # ============================================================
  # FILTER UI GENERATION — ADMIN SECTION
  # ============================================================
  
  admin_tabs <- c("overview","proc","subm","dec","reg")
  
  for (tab in admin_tabs) {
    local({
      t <- tab
      
      output[[paste0("admin_year_filter_", t)]] <- renderUI({
        req(admin$data)
        year_col <- if ("tender_year" %in% names(admin$data)) "tender_year"
        else if ("year" %in% names(admin$data)) "year"
        else if ("cal_year" %in% names(admin$data)) "cal_year" else NULL
        if (!is.null(year_col)) {
          years <- admin$data[[year_col]]; years <- years[!is.na(years)]
          if (length(years) > 0)
            sliderInput(paste0("admin_yr_", t), "Year Range:",
                        min = min(years), max = max(years),
                        value = c(min(years), max(years)), step = 1, sep = "")
        }
      })
      
      output[[paste0("admin_market_filter_", t)]] <- renderUI({
        # Read from full unfiltered data so the widget is not invalidated on
        # every filter application and does not lose its current selection.
        src <- if (!is.null(econ$data)) econ$data else econ$filtered_data
        req(!is.null(src))
        if ("cpv_cluster" %in% names(src)) {
          cpv_codes <- sort(unique(src$cpv_cluster))
          cpv_codes <- cpv_codes[!is.na(cpv_codes) & cpv_codes != ""]
          if (length(cpv_codes) > 0) {
            cpv_choices <- setNames(cpv_codes, sapply(cpv_codes, get_cpv_label))
            cur_sel <- admin_filters$active$market %||% character(0)
            pickerInput(paste0("admin_mkt_", t), "Market (CPV):",
                        choices  = cpv_choices,
                        selected = cur_sel,
                        multiple = TRUE,
                        options  = list(`actions-box` = TRUE, `live-search` = TRUE,
                                        `none-selected-text` = "All markets"))
          }
        }
      })
      
      output[[paste0("admin_value_filter_", t)]] <- renderUI({
        req(admin$data)
        price_col <- detect_price_col(admin$data, c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"))
        if (!is.na(price_col)) {
          prices <- admin$data[[price_col]]; prices <- prices[!is.na(prices) & prices > 0]
          if (length(prices) > 0) {
            # Detect the local currency from the data
            loc_cur <- detect_local_currency(admin$data)
            cur     <- input[[paste0("admin_val_cur_", t)]] %||% "USD"
            rate    <- if (cur == loc_cur$label && cur != "USD") loc_cur$rate else 1
            div     <- 1e3
            admin$value_divisor  <- div / rate
            admin$value_max_k    <- ceiling(max(prices) * rate / div)
            admin$local_currency <- loc_cur
            make_value_filter_widget(prices, paste0("admin_val_cur_", t), paste0("admin_val_rng_", t),
                                     cur, local_currency = loc_cur)
          }
        }
      })
      
      output[[paste0("admin_buyer_type_filter_", t)]] <- renderUI({
        req(admin$data)
        if ("buyer_buyertype" %in% names(admin$data)) {
          buyer_groups <- admin$data %>%
            mutate(buyer_group = add_buyer_group(buyer_buyertype)) %>%
            pull(buyer_group) %>% as.character() %>% unique() %>% sort()
          buyer_groups <- buyer_groups[!is.na(buyer_groups)]
          if (length(buyer_groups) > 0) {
            cur_sel <- admin_filters$active$buyer_type %||% character(0)
            pickerInput(paste0("admin_btype_", t), "Buyer Type:",
                        choices  = buyer_groups,
                        selected = cur_sel,
                        multiple = TRUE,
                        options  = list(`actions-box` = TRUE,
                                        `none-selected-text` = "All buyer types"))
          }
        }
      })
      
      output[[paste0("admin_procedure_type_filter_", t)]] <- renderUI({
        req(admin$data)
        if ("tender_proceduretype" %in% names(admin$data)) {
          raw_types <- unique(admin$data$tender_proceduretype)
          raw_types <- raw_types[!is.na(raw_types)]
          if (length(raw_types) > 0) {
            df_map <- data.frame(raw     = raw_types,
                                 cleaned = recode_procedure_type(raw_types),
                                 stringsAsFactors = FALSE)
            admin_procedure_mapping(df_map)
            types <- sort(unique(df_map$cleaned[!is.na(df_map$cleaned)]))
            cur_sel <- admin_filters$active$procedure_type %||% character(0)
            pickerInput(paste0("admin_ptype_", t), "Procedure Type:",
                        choices  = types,
                        selected = cur_sel,
                        multiple = TRUE,
                        options  = list(`actions-box` = TRUE, `live-search` = TRUE,
                                        `none-selected-text` = "All procedure types"))
          }
        }
      })
      
      output[[paste0("admin_filter_status_", t)]] <- renderText({
        paste("  \U0001f4cb", get_filter_description(admin_filters$active))
      })
      
      # Per-tab coarse↔fine slider sync for the value filter
      make_slider_sync(
        paste0("admin_val_rng_", t, "_coarse"),
        paste0("admin_val_rng_", t, "_min_k"),
        paste0("admin_val_rng_", t, "_max_k"),
        local({ tt <- t; function() {
          loc <- admin$local_currency %||% list(label = "USD", rate = 1)
          cur <- input[[paste0("admin_val_cur_", tt)]] %||% "USD"
          if (cur == loc$label && cur != "USD") loc$rate else 1
        }})
      )
    })
  }
  
  for (tn in admin_tabs) {
    local({
      t <- tn
      observeEvent(input[[paste0("admin_apply_filters_", t)]],  { apply_admin_filters(t) })
      observeEvent(input[[paste0("admin_reset_filters_",  t)]], { reset_admin_filters(t) })
    })
  }
  
  # Per-tab slider sync is wired inside each section's filter loop above.
  # (econ_tabs, admin_tabs, integ_tabs each call make_slider_sync per tab)
  
  
  # [APP-SV10] SHARED PLOTLY HELPERS (toolbar config, PNG export, download guard) ────
  # SHARED PLOTLY HELPERS
  # ============================================================
  
  # Adds autoscale button + high-res PNG export to every chart.
  # Forces pure white backgrounds so the camera-button PNG is clean (no blue tint).
  # Custom modebar button: expand any chart into a full-window overlay for
  # detailed viewing. Uses a CSS overlay rather than the browser Fullscreen
  # API — the API is blocked in the RStudio viewer and in iframes without
  # the allowfullscreen attribute. The chart is explicitly relayout-ed to fill the
  # window, including charts with a fixed layout height (missingness charts),
  # and restored on exit. Click the button again or press Esc to exit.
  .pa_fullscreen_btn <- list(
    name  = "pa_fullscreen",
    title = "Expand chart — click again or press Esc to exit",
    icon  = list(
      width  = 1792, height = 1792,
      path   = "M883 1056q0 13-10 23l-332 332 144 144q19 19 19 45t-19 45-45 19h-448q-26 0-45-19t-19-45v-448q0-26 19-45t45-19 45 19l144 144 332-332q10-10 23-10t23 10l114 114q10 10 10 23zm781-864v448q0 26-19 45t-45 19-45-19l-144-144-332 332q-10 10-23 10t-23-10l-114-114q-10-10-10-23t10-23l332-332-144-144q-19-19-19-45t19-45 45-19h448q26 0 45 19t19 45z",
      transform = "matrix(1 0 0 -1 0 1792)"
    ),
    click = htmlwidgets::JS("
      function(gd) {
        var el = gd.closest('.js-plotly-plot') || gd;
        function rs() { setTimeout(function() { if (window.Plotly) Plotly.Plots.resize(gd); }, 80); }
        if (!el._paExpanded) {
          el._paExpanded  = true;
          el._paPrevStyle = el.getAttribute('style') || '';
          el._paLay = { w: (gd.layout && gd.layout.width)  || null,
                        h: (gd.layout && gd.layout.height) || null };
          var ph = document.createElement('div');
          ph.style.height = el.offsetHeight + 'px';
          el.parentNode.insertBefore(ph, el);
          el._paPh = ph;
          el.style.position = 'fixed';
          el.style.top = '0'; el.style.left = '0';
          el.style.width = '100vw'; el.style.height = '100vh';
          el.style.zIndex = '10000';
          el.style.backgroundColor = '#ffffff';
          el.style.padding = '24px';
          el.style.boxSizing = 'border-box';
          el.style.overflow = 'auto';
          el._paCollapse = function() {
            if (!el._paExpanded) return;
            el._paExpanded = false;
            el.setAttribute('style', el._paPrevStyle);
            if (el._paPh && el._paPh.parentNode) el._paPh.parentNode.removeChild(el._paPh);
            document.removeEventListener('keydown', el._paEsc);
            Plotly.relayout(gd, { width: el._paLay.w, height: el._paLay.h, autosize: true });
            rs();
          };
          el._paEsc = function(ev) { if (ev.key === 'Escape') el._paCollapse(); };
          document.addEventListener('keydown', el._paEsc);
          Plotly.relayout(gd, { width: window.innerWidth - 60, height: window.innerHeight - 60 });
          rs();
        } else {
          el._paCollapse();
        }
      }")
  )
  
  pa_config <- function(fig) {
    fig %>%
      plotly::layout(
        paper_bgcolor = "#ffffff",
        plot_bgcolor  = "#ffffff"
      ) %>%
      plotly::config(
        displayModeBar       = TRUE,
        modeBarButtonsToAdd  = list(.pa_fullscreen_btn, "autoScale2d"),
        toImageButtonOptions = list(format          = "png",
                                    scale           = 2,
                                    filename        = "chart_export",
                                    # Force white background in camera-button export.
                                    # Without this Plotly inherits the page background
                                    # colour (AdminLTE blue-grey) into the PNG.
                                    setBackground   = "#ffffff"),
        responsive           = TRUE
      )
  }
  
  # Export a plotly figure to PNG at a standard, readable size.
  # Delegates sizing/fonts to pa_prep_plotly_export() [APP-G21]: honours any
  # width/height the render block set (dynamic-height heatmaps keep their
  # shape), applies print-ready fonts, and captures at the exact canvas size.
  .save_fig_png <- function(fig, file, vw = 1400, vh = 850) {
    fig_dl <- pa_prep_plotly_export(fig, vw = vw, vh = vh)
    sz     <- attr(fig_dl, "pa_export_size")
    ok <- tryCatch({
      tmp <- tempfile(fileext = ".html")
      htmlwidgets::saveWidget(fig_dl, tmp, selfcontained = TRUE)
      webshot2::webshot(tmp, file = file, vwidth = sz[1] + 20, vheight = sz[2] + 20,
                        delay = 2, zoom = 2)
      unlink(tmp)
      file.exists(file) && file.size(file) > 1000
    }, error = function(e) { message("webshot2 error: ", e$message); FALSE })
    if (isTRUE(ok)) return(invisible(NULL))
    
    showNotification(
      "Download failed. Check the R console for the error. Make sure webshot2 is installed: install.packages('webshot2')",
      type = "error", duration = 15
    )
    req(FALSE)
  }
  
  # Helper: show a warning toast and cancel download when chart not yet rendered
  .require_fig <- function(fig, plot_label = "this chart") {
    if (is.null(fig)) {
      showNotification(
        paste0("Please view ", plot_label, " first, then download."),
        type = "warning", duration = 5
      )
      req(FALSE)
    }
    fig
  }
  
  # Download helper used by all admin plotly figures
  dl_plotly_fig <- function(fig_expr, fname, vw = 1200, vh = 700) {
    downloadHandler(
      filename = function() {
        cc <- tryCatch(admin$country_code %||% "export", error = function(e) "export")
        paste0(fname, "_", cc, "_", format(Sys.Date(), "%Y%m%d"), ".png")
      },
      content = function(file) {
        fig <- tryCatch(fig_expr(), error = function(e) NULL)
        .require_fig(fig, fname)
        .save_fig_png(fig, file, vw, vh)
      }
    )
  }
  
  
  # [APP-SV11] DATA OVERVIEW OUTPUTS (shared; reads econ$filtered_data) ──────
  # ============================================================
  # DATA OVERVIEW OUTPUTS (shared, uses econ filtered_data)
  # ============================================================
  
  output$n_contracts <- renderValueBox({
    req(econ$filtered_data)
    valueBox(formatC(nrow(econ$filtered_data), format="d", big.mark=","),
             "Contracts", icon=icon("file-contract"), color="navy")
  })
  output$n_buyers <- renderValueBox({
    req(econ$filtered_data); df <- econ$filtered_data
    n <- if ("buyer_masterid" %in% names(df)) dplyr::n_distinct(df$buyer_masterid, na.rm=TRUE)
    else if ("buyer_id"  %in% names(df)) dplyr::n_distinct(df$buyer_id,       na.rm=TRUE)
    else if ("buyer_name"%in% names(df)) dplyr::n_distinct(df$buyer_name,     na.rm=TRUE)
    else "N/A"
    valueBox(if (is.numeric(n)) formatC(n, format="d", big.mark=",") else n,
             "Buyers", icon=icon("building"), color="teal")
  })
  output$n_suppliers <- renderValueBox({
    req(econ$filtered_data); df <- econ$filtered_data
    n <- if ("bidder_masterid"  %in% names(df)) dplyr::n_distinct(df$bidder_masterid, na.rm=TRUE)
    else if ("bidder_id"   %in% names(df)) dplyr::n_distinct(df$bidder_id,       na.rm=TRUE)
    else if ("supplier_name"%in% names(df)) dplyr::n_distinct(df$supplier_name,  na.rm=TRUE)
    else if ("bidder_name" %in% names(df)) dplyr::n_distinct(df$bidder_name,     na.rm=TRUE)
    else "N/A"
    valueBox(if (is.numeric(n)) formatC(n, format="d", big.mark=",") else n,
             "Suppliers", icon=icon("truck"), color="olive")
  })
  output$n_years <- renderValueBox({
    req(econ$filtered_data); df <- econ$filtered_data
    years <- if ("tender_year" %in% names(df)) unique(df$tender_year[!is.na(df$tender_year)]) else NA
    yr    <- if (length(years) > 0) paste(min(years), "-", max(years)) else "N/A"
    valueBox(yr, "Period", icon=icon("calendar"), color="navy")
  })
  
  output$contracts_year_plot <- renderPlotly({
    req(econ$filtered_data)
    df <- econ$filtered_data
    if (!"tender_year" %in% names(df)) return(NULL)
    year_counts <- df %>% group_by(tender_year) %>% summarise(n = n(), .groups="drop")
    year_counts <- year_counts %>%
      mutate(label = formatC(n, format="d", big.mark=","))
    p <- ggplot(year_counts, aes(x=tender_year, y=n,
                                 text=paste0("Year: ", tender_year, "<br>Contracts: ", label))) +
      geom_col(fill=PA_NORMAL) +
      labs(x="Year", y="Number of Contracts") +
      pa_theme() + scale_y_continuous(labels=scales::comma)
    # Integer year breaks must be set on the ggplot scale: ggplotly bakes
    # ggplot's breaks into an explicit tickvals array, which overrides any
    # later layout(dtick=...) — the source of 2022.5-style ticks.
    p <- p + scale_x_continuous(breaks = function(x) seq(ceiling(x[1]), floor(x[2]), by = 1))
    ggplotly(p, tooltip="text") %>%
      layout(hoverlabel=list(bgcolor="white", font=list(size=13)),
             hovermode="x unified") %>%
      pa_config() -> .stored_fig
    econ$fig_contracts_year_econ <- .stored_fig
    .stored_fig
  })
  
  output$value_by_year_plot <- renderPlotly({
    req(econ$filtered_data)
    df <- econ$filtered_data
    price_var <- NULL
    for (col in c("bid_priceusd","lot_estimatedpriceusd","tender_finalprice","lot_estimatedprice","bid_price"))
      if (col %in% names(df)) { price_var <- col; break }
    if (!"tender_year" %in% names(df) || is.null(price_var)) return(NULL)
    
    n_all <- df %>%
      group_by(tender_year) %>%
      summarise(n_contracts = n(), .groups = "drop")
    
    year_values <- df %>%
      filter(!is.na(.data[[price_var]]), .data[[price_var]] > 0) %>%
      group_by(tender_year) %>%
      summarise(total_value = sum(.data[[price_var]], na.rm = TRUE), .groups = "drop") %>%
      left_join(n_all, by = "tender_year")
    
    loc_lbl <- (econ$local_currency %||% list(label="NC"))$label
    max_val <- max(year_values$total_value, na.rm=TRUE)
    if (max_val > 1e9) { sdiv <- 1e9; ylbl <- paste0("Total Value (Billions ", loc_lbl, ")"); sn <- "B"
    } else if (max_val > 1e6) { sdiv <- 1e6; ylbl <- paste0("Total Value (Millions ", loc_lbl, ")"); sn <- "M"
    } else if (max_val > 1e3) { sdiv <- 1e3; ylbl <- paste0("Total Value (Thousands ", loc_lbl, ")"); sn <- "K"
    } else { sdiv <- 1; ylbl <- paste0("Total Value (", loc_lbl, ")"); sn <- "" }
    year_values <- year_values %>% mutate(tv_disp = total_value / sdiv)
    p <- ggplot(year_values, aes(x=tender_year, y=tv_disp,
                                 text=paste0("Year: ", tender_year,
                                             "<br>Contracts: ", format(n_contracts, big.mark=","),
                                             "<br>Total value: ", round(tv_disp, 2), sn, " ", loc_lbl))) +
      geom_col(fill="#00a65a") +
      labs(x="Year", y=ylbl) +
      pa_theme() + scale_y_continuous(labels=scales::comma)
    p <- p + scale_x_continuous(breaks = function(x) seq(ceiling(x[1]), floor(x[2]), by = 1))  # integer years (see note in contracts_year_plot)
    ggplotly(p, tooltip="text") %>%
      layout(hoverlabel=list(bgcolor="white"), hovermode="x unified") %>%
      pa_config() -> .stored_fig
    econ$fig_value_by_year <- .stored_fig
    .stored_fig
  })
  
  # ── Helper: build a top-N lollipop chart for buyers or suppliers ──────────
  .overview_entity_plot <- function(df, id_col, name_col, price_col, top_n, metric, entity_label) {
    use_col <- if (!is.null(name_col) && name_col %in% names(df)) name_col
    else if (!is.null(id_col) && id_col %in% names(df)) id_col
    else NULL
    if (is.null(use_col)) return(plotly::plot_ly() %>%
                                   add_annotations(text=paste("No", entity_label, "identifier column found"),
                                                   x=0.5, y=0.5, xref="paper", yref="paper",
                                                   showarrow=FALSE, font=list(size=13, color="#888")))
    has_price <- !is.null(price_col) && price_col %in% names(df)
    ss <- df %>%
      dplyr::filter(!is.na(.data[[use_col]]), as.character(.data[[use_col]]) != "") %>%
      dplyr::group_by(entity = .data[[use_col]]) %>%
      dplyr::summarise(
        n_contracts = dplyr::n(),
        total_value = if (has_price) sum(.data[[price_col]], na.rm=TRUE) else NA_real_,
        .groups = "drop"
      )
    sort_col <- if (metric == "total_value" && has_price && !all(is.na(ss$total_value))) "total_value"
    else "n_contracts"
    ss <- ss %>%
      dplyr::arrange(dplyr::desc(.data[[sort_col]])) %>%
      dplyr::slice_head(n = top_n) %>%
      dplyr::arrange(.data[[sort_col]]) %>%
      dplyr::mutate(
        label = {s <- as.character(entity); ifelse(nchar(s)>40, paste0(substr(s,1,38),"\u2026"), s)},
        x_val = .data[[sort_col]]
      )
    loc_lbl <- (econ$local_currency %||% list(label="NC"))$label
    # Initialise scaling vars — overridden below if sort_col == "total_value"
    tv_s   <- 1
    tv_sfx <- ""
    if (sort_col == "total_value") {
      max_tv <- max(ss$total_value, na.rm=TRUE)
      if (max_tv>=1e9){tv_s<-1e9;tv_sfx<-"B"}else if(max_tv>=1e6){tv_s<-1e6;tv_sfx<-"M"}else if(max_tv>=1e3){tv_s<-1e3;tv_sfx<-"K"}else{tv_s<-1;tv_sfx<-""}
      ss <- ss %>% dplyr::mutate(x_val = total_value / tv_s)
      x_lab <- paste0("Total value (", tv_sfx, " ", loc_lbl, ")")
    } else { x_lab <- "Number of contracts" }
    
    ss$tip <- paste0("<b>", ss$label, "</b><br>",
                     "Contracts: <b>", scales::comma(ss$n_contracts), "</b>",
                     if (has_price && !all(is.na(ss$total_value)))
                       paste0("<br>Total value: <b>", round(ss$total_value/
                                                              ifelse(sort_col=="total_value", tv_s %||% 1, 1), 1),
                              if(sort_col=="total_value") tv_sfx else "", " ", loc_lbl, "</b>")
                     else "")
    cat_order <- ss$label
    col_vals  <- ss$x_val
    col_range <- range(col_vals, na.rm=TRUE)
    col_norm  <- if(diff(col_range)>0)(col_vals-col_range[1])/diff(col_range) else rep(0.5, nrow(ss))
    hex_cols  <- scales::col_numeric(c("#93C5FD","#1E3A8A"), domain=c(0,1))(col_norm)
    dyn_h     <- max(300, min(800, top_n * 30 + 60))
    plot_ly(height=dyn_h) %>%
      add_segments(data=ss, x=0, xend=~x_val, y=~label, yend=~label,
                   line=list(color="#CBD5E1", width=1.5), hoverinfo="skip", showlegend=FALSE) %>%
      add_markers(data=ss, x=~x_val, y=~label, marker=list(size=11, color=hex_cols,
                                                           line=list(color="white",width=1.5)), text=~tip, hoverinfo="text", showlegend=FALSE) %>%
      layout(xaxis=list(title=x_lab, zeroline=FALSE, gridcolor="#F1F5F9", tickfont=list(size=13)),
             yaxis=list(title="", tickfont=list(size=13), categoryorder="array", categoryarray=cat_order),
             hoverlabel=list(bgcolor="white", font=list(size=11)), hovermode="closest",
             margin=list(l=10,r=30,t=20,b=50), paper_bgcolor="#ffffff", plot_bgcolor="#ffffff") %>%
      pa_config()
  }
  
  output$overview_top_buyers_plot_ui <- renderUI({
    top_n <- as.integer(input$overview_top_buyer_n %||% 15)
    plotlyOutput("overview_top_buyers_plot", height = paste0(max(350, top_n * 30 + 80), "px"))
  })
  
  output$overview_top_buyers_plot <- renderPlotly({
    req(econ$filtered_data)
    df      <- econ$filtered_data
    top_n   <- as.integer(input$overview_top_buyer_n       %||% 15)
    metric  <- input$overview_buyer_metric %||% "n_contracts"
    id_col  <- intersect(c("buyer_masterid","buyer_id"), names(df))[1]
    nm_col  <- intersect(c("buyer_name","buyer_normalized_name","buyer_normalizedname"), names(df))[1]
    pc      <- detect_price_col(df, .PRICE_COLS_SUPP)
    fig <- .overview_entity_plot(df, id_col %||% NA_character_, nm_col %||% NA_character_, pc, top_n, metric, "buyer")
    econ$fig_ov_top_buyers <- fig
    fig
  })
  
  output$overview_top_suppliers_plot_ui <- renderUI({
    top_n <- as.integer(input$overview_top_supplier_n %||% 15)
    plotlyOutput("overview_top_suppliers_plot", height = paste0(max(350, top_n * 30 + 80), "px"))
  })
  
  output$overview_top_suppliers_plot <- renderPlotly({
    req(econ$filtered_data)
    df      <- econ$filtered_data
    top_n   <- as.integer(input$overview_top_supplier_n    %||% 15)
    metric  <- input$overview_supplier_metric %||% "n_contracts"
    id_col  <- intersect(c("bidder_masterid","bidder_id"), names(df))[1]
    nm_col  <- intersect(c("bidder_name","bidder_normalized_name","winner_name","bidder_normalizedname"), names(df))[1]
    pc      <- detect_price_col(df, .PRICE_COLS_SUPP)
    fig <- .overview_entity_plot(df, id_col %||% NA_character_, nm_col %||% NA_character_, pc, top_n, metric, "supplier")
    econ$fig_ov_top_suppliers <- fig
    fig
  })
  
  
  
  # [APP-SV12] MARKET SIZING OUTPUTS ─────────────────────────────────────────
  # ============================================================
  # MARKET SIZING OUTPUTS
  # ============================================================
  
  output$market_size_n_plot <- renderPlotly({
    req(econ$filtered_data)
    ms <- tryCatch({
      df <- econ$filtered_data
      if (!"cpv_cluster" %in% names(df)) return(NULL)
      df %>%
        filter(!is.na(cpv_cluster)) %>%
        mutate(cpv_label = get_cpv_label(cpv_cluster)) %>%
        group_by(cpv_label) %>%
        summarise(n_contracts = n(), .groups = "drop") %>%
        arrange(desc(n_contracts)) %>% slice_head(n = 30) %>%
        mutate(
          label_short = ifelse(nchar(cpv_label) > 35,
                               paste0(substr(cpv_label, 1, 33), "…"), cpv_label),
          tooltip = paste0("<b>", cpv_label, "</b><br>Contracts: ",
                           formatC(n_contracts, format="d", big.mark=",")),
          label_short = factor(label_short, levels = label_short[order(n_contracts)])
        )
    }, error = function(e) NULL)
    if (is.null(ms) || nrow(ms) == 0) {
      req(econ$filtered_analysis$market_size_n)
      return(ggplotly(econ$filtered_analysis$market_size_n, tooltip=c("x","y")) %>%
               layout(font=list(size=11), hoverlabel=list(bgcolor="white",font=list(size=11))))
    }
    p <- ggplot(ms, aes(x = label_short, y = n_contracts, text = tooltip)) +
      geom_col(fill = PA_NORMAL) +
      coord_flip() +
      scale_y_continuous(labels = scales::comma) +
      labs(x = NULL, y = "Number of contracts") +
      pa_theme()
    ggplotly(p, tooltip = "text") %>%
      layout(hoverlabel = list(bgcolor = "white", font = list(size = 13)),
             hovermode = "closest", margin = list(l = 10)) %>%
      pa_config()
  })
  
  output$market_size_v_plot <- renderPlotly({
    req(econ$filtered_data)
    .loc_v <- (econ$local_currency %||% list(label="NC"))$label
    .pfx_v <- if (.loc_v == "USD") "$" else ""
    ms <- tryCatch({
      df <- econ$filtered_data
      price_var <- detect_price_col(df)
      if (is.null(price_var) || !"cpv_cluster" %in% names(df)) return(NULL)
      df %>%
        filter(!is.na(cpv_cluster), !is.na(.data[[price_var]]),
               .data[[price_var]] > 0) %>%
        mutate(cpv_label = get_cpv_label(cpv_cluster)) %>%
        group_by(cpv_label) %>%
        summarise(total_value = sum(.data[[price_var]], na.rm = TRUE), .groups = "drop") %>%
        arrange(desc(total_value)) %>% slice_head(n = 30) %>%
        mutate(
          label_short = ifelse(nchar(cpv_label) > 35,
                               paste0(substr(cpv_label, 1, 33), "\u2026"), cpv_label),
          tooltip     = paste0("<b>", cpv_label, "</b><br>Total value: ",
                               .pfx_v,
                               scales::number(total_value, accuracy = 1,
                                              scale_cut = scales::cut_short_scale()),
                               if (.pfx_v == "") paste0(" ", .loc_v) else ""),
          label_short = factor(label_short, levels = label_short[order(total_value)])
        )
    }, error = function(e) NULL)
    if (is.null(ms) || nrow(ms) == 0) {
      req(econ$filtered_analysis$market_size_v)
      return(ggplotly(econ$filtered_analysis$market_size_v, tooltip=c("x","y")) %>%
               layout(font=list(size=11), hoverlabel=list(bgcolor="white",font=list(size=11))))
    }
    p <- ggplot(ms, aes(x = label_short, y = total_value, text = tooltip)) +
      geom_col(fill = PA_TEAL) +
      coord_flip() +
      scale_y_continuous(labels = scales::label_number(scale_cut = scales::cut_short_scale(),
                                                       accuracy = 0.1)) +
      labs(x = NULL, y = paste0("Total contract value (", .loc_v, ")")) +
      pa_theme()
    ggplotly(p, tooltip = "text") %>%
      layout(hoverlabel = list(bgcolor = "white", font = list(size = 13)),
             hovermode = "closest", margin = list(l = 10)) %>%
      pa_config()
  })
  
  output$market_size_av_plot <- renderPlotly({
    req(econ$filtered_data)
    ms <- tryCatch({
      df  <- econ$filtered_data
      price_var <- detect_price_col(df)
      if (is.null(price_var)) stop("no price column")
      df %>%
        filter(!is.na(cpv_cluster)) %>%
        mutate(cpv_label = get_cpv_label(cpv_cluster)) %>%
        group_by(cpv_cluster, cpv_label) %>%
        summarise(
          n_contracts  = n(),
          total_value  = sum(.data[[price_var]], na.rm=TRUE),
          avg_value    = mean(.data[[price_var]], na.rm=TRUE),
          .groups="drop"
        ) %>%
        filter(n_contracts > 0, avg_value > 0, total_value > 0)
    }, error = function(e) NULL)
    
    if (is.null(ms) || nrow(ms) == 0) return(
      plotly::plot_ly(type = "scatter", mode = "markers") %>%
        plotly::add_annotations(text="No price data available for bubble plot",
                                x=0.5, y=0.5, xref="paper", yref="paper", showarrow=FALSE,
                                font=list(size=11, color="#888"))
    )
    
    .loc_av <- (econ$local_currency %||% list(label="NC"))$label
    .pfx_av <- if (.loc_av == "USD") "$" else ""
    
    # Attach derived columns to ms so plotly can reference them via ~
    ms <- ms %>%
      mutate(
        bubble_size  = scales::rescale(sqrt(total_value), to = c(8, 50)),
        log_avg      = log10(avg_value + 1),
        hover_text   = paste0(
          "<b>", cpv_label, "</b><br>",
          "Contracts: <b>", scales::comma(n_contracts), "</b><br>",
          "Avg contract value: <b>",
          .pfx_av, scales::number(avg_value, scale_cut=scales::cut_short_scale(), accuracy=0.1),
          if (.pfx_av == "") paste0(" ", .loc_av) else "",
          "</b><br>",
          "Total market value: <b>",
          .pfx_av, scales::number(total_value, scale_cut=scales::cut_short_scale(), accuracy=0.1),
          if (.pfx_av == "") paste0(" ", .loc_av) else "",
          "</b>"
        )
      )
    
    # Build clean decade tick labels for both log axes
    make_log_ticks <- function(vals, prefix = "") {
      lo <- floor(log10(min(vals, na.rm=TRUE)))
      hi <- ceiling(log10(max(vals, na.rm=TRUE)))
      pows <- seq(lo, hi)
      tv   <- 10^pows
      fmt  <- function(v) {
        dplyr::case_when(
          v >= 1e9  ~ paste0(prefix, scales::comma(v/1e9), "B"),
          v >= 1e6  ~ paste0(prefix, scales::comma(v/1e6), "M"),
          v >= 1e3  ~ paste0(prefix, scales::comma(v/1e3), "K"),
          TRUE      ~ paste0(prefix, scales::comma(v))
        )
      }
      list(tickvals = tv, ticktext = fmt(tv))
    }
    xt <- make_log_ticks(ms$n_contracts)
    yt <- make_log_ticks(ms$avg_value, prefix = .pfx_av)
    
    plot_ly(ms,
            x         = ~n_contracts,
            y         = ~avg_value,
            text      = ~hover_text,
            hoverinfo = "text",
            type      = "scatter",
            mode      = "markers",
            marker    = list(
              size      = ~bubble_size,
              sizemode  = "diameter",
              color     = ~log_avg,
              colorscale = list(c(0,"#c6dbef"), c(0.5,"#4292c6"), c(1,"#08306b")),
              showscale = TRUE,
              colorbar  = list(title = paste0("Avg value<br>(log₁₀ ", .loc_av, ")"), tickformat = ".1f"),
              opacity   = 0.85,
              line      = list(color = "white", width = 1)
            )
    ) %>%
      layout(
        xaxis  = list(
          title     = "Number of contracts (log scale)",
          type      = "log",
          tickvals  = xt$tickvals,
          ticktext  = xt$ticktext,
          tickangle = -35,
          zeroline  = FALSE,
          gridcolor = "#eeeeee"
        ),
        yaxis  = list(
          title     = "Average contract value (log scale)",
          type      = "log",
          tickvals  = yt$tickvals,
          ticktext  = yt$ticktext,
          zeroline  = FALSE,
          gridcolor = "#eeeeee"
        ),
        margin     = list(l=90, r=60, t=60, b=90),
        hoverlabel = list(bgcolor="white", font=list(size=12)),
        hovermode  = "closest",
        showlegend = FALSE
      ) %>%
      pa_config()
  })
  
  
  # [APP-SV13] SUPPLIER DYNAMICS OUTPUTS (sliders, bubble / stability / trend) ────
  # ============================================================
  # SUPPLIER DYNAMICS — DYNAMIC SLIDERS
  # ============================================================
  
  output$market_contracts_range_slider <- renderUI({
    req(econ$filtered_data)
    trigger <- econ$slider_trigger
    df <- econ$filtered_data
    mkt <- df %>% filter(!is.na(cpv_cluster), !is.na(tender_year)) %>%
      group_by(cpv_cluster, tender_year) %>% summarise(n=n(), .groups="drop") %>%
      group_by(cpv_cluster) %>% summarise(avg=mean(n), .groups="drop")
    max_c <- max(mkt$avg, na.rm=TRUE); med_c <- median(mkt$avg, na.rm=TRUE)
    if (is.na(max_c) || max_c < 10) { max_c <- 1000; med_c <- 500 }
    max_val <- ceiling(max_c / 100) * 100
    tagList(
      sliderInput("econ_market_contracts_range", "Average contracts per market-year:",
                  min=0, max=max_val, value=c(0, max_val), step=max(10, round(max_val/100)), width="100%"),
      tags$div(style="margin-top:-15px;margin-bottom:10px;font-size:11px;color:#666;",
               HTML(paste0("\U0001f4ca Median: <span style='color:#d32f2f;font-weight:bold;'>",
                           round(med_c), "</span> contracts")))
    )
  })
  
  output$market_value_range_slider <- renderUI({
    req(econ$filtered_data)
    trigger <- econ$slider_trigger
    df <- econ$filtered_data
    price_col <- detect_price_col(df, .PRICE_COLS_SUPP)
    if (is.null(price_col)) return(p("Value data not available"))
    mkt <- df %>% filter(!is.na(cpv_cluster), !is.na(tender_year), !is.na(.data[[price_col]])) %>%
      group_by(cpv_cluster, tender_year) %>%
      summarise(tv=sum(.data[[price_col]], na.rm=TRUE)/1e6, .groups="drop") %>%
      group_by(cpv_cluster) %>% summarise(avg=mean(tv), .groups="drop")
    max_v <- max(mkt$avg, na.rm=TRUE); med_v <- median(mkt$avg, na.rm=TRUE)
    if (is.na(max_v) || max_v < 1) { max_v <- 1000; med_v <- 500 }
    max_val <- ceiling(max_v / 100) * 100
    tagList(
      sliderInput("econ_market_value_range", "Avg contract value per market-year (millions):",
                  min=0, max=max_val, value=c(0, max_val), step=max(10, round(max_val/100)), width="100%"),
      tags$div(style="margin-top:-15px;margin-bottom:10px;font-size:11px;color:#666;",
               HTML(paste0("\U0001f4ca Median: <span style='color:#d32f2f;font-weight:bold;'>$",
                           round(med_v,1), "M</span>")))
    )
  })
  
  output$market_filter_status <- renderText({
    cr <- input$econ_market_contracts_range; vr <- input$econ_market_value_range
    parts <- c()
    if (!is.null(cr) && cr[1] > 0) parts <- c(parts, paste0("Avg contracts: ", cr[1], "-", cr[2]))
    if (!is.null(vr) && vr[1] > 0) parts <- c(parts, paste0("Value: $", vr[1], "M-$", vr[2], "M"))
    if (length(parts) > 0) paste("Active filters:", paste(parts, collapse=" | "))
    else "No market size filters active (showing all markets)"
  })
  
  observeEvent(input$reset_market_filters, {
    if (!is.null(input$econ_market_contracts_range))
      updateSliderInput(session, "econ_market_contracts_range", value=c(0, input$econ_market_contracts_range[2]))
    if (!is.null(input$econ_market_value_range))
      updateSliderInput(session, "econ_market_value_range", value=c(0, input$econ_market_value_range[2]))
    showNotification("Market size filters reset", type="message", duration=2)
  })
  
  # Apply button: plots already react live to sliders; this just gives visual confirmation
  observeEvent(input$apply_market_filters, {
    n <- if (!is.null(input$econ_market_contracts_range) || !is.null(input$econ_market_value_range))
      "Market size filters applied — plots updated" else "No market size filters active"
    showNotification(n, type="message", duration=2)
  })
  
  # ── Helper: get filtered market CPVs from size sliders ──────────────
  get_market_filtered_cpvs <- function(df) {
    cr <- input$econ_market_contracts_range; vr <- input$econ_market_value_range
    if (is.null(cr) && is.null(vr)) return(NULL)
    price_col <- detect_price_col(df, .PRICE_COLS_SUPP)
    # Single-pass per-market aggregation
    base <- df %>%
      dplyr::filter(!is.na(cpv_cluster), !is.na(tender_year)) %>%
      dplyr::group_by(cpv_cluster, tender_year)
    if (!is.null(price_col)) {
      base <- base %>%
        dplyr::summarise(n=dplyr::n(),
                         tv=sum(.data[[price_col]], na.rm=TRUE)/1e6, .groups="drop") %>%
        dplyr::group_by(cpv_cluster) %>%
        dplyr::summarise(avg_contracts=mean(n), avg_value=mean(tv), .groups="drop")
    } else {
      base <- base %>%
        dplyr::summarise(n=dplyr::n(), .groups="drop") %>%
        dplyr::group_by(cpv_cluster) %>%
        dplyr::summarise(avg_contracts=mean(n), avg_value=0, .groups="drop")
    }
    if (!is.null(cr)) base <- base %>% dplyr::filter(avg_contracts >= cr[1], avg_contracts <= cr[2])
    if (!is.null(vr)) base <- base %>% dplyr::filter(avg_value    >= vr[1], avg_value    <= vr[2])
    base$cpv_cluster
  }
  
  # ── Plot 1: Bubble grid — size = unique suppliers, colour = % new entry ─
  output$supplier_bubble_plot_ui <- renderUI({
    df <- econ$filtered_data
    n_mkts <- if (!is.null(df) && "cpv_cluster" %in% names(df))
      dplyr::n_distinct(df$cpv_cluster, na.rm=TRUE) else 20
    # reasonable: ~24px per market row, capped at 750, min 420
    h <- max(420, min(750, n_mkts * 24 + 100))
    plotlyOutput("supplier_bubble_plot", height=paste0(h,"px"))
  })
  
  output$supplier_bubble_plot <- renderPlotly({
    req(econ$filtered_analysis$supplier_stats, econ$filtered_data)
    thr_new  <- input$econ_new_threshold %||% 50
    show_lab <- isTRUE(input$supp_show_labels)
    show_cnt <- isTRUE(input$supp_show_counts)
    
    ss   <- econ$filtered_analysis$supplier_stats
    keep <- get_market_filtered_cpvs(econ$filtered_data)
    if (!is.null(keep)) ss <- ss %>% filter(cpv_cluster %in% keep)
    if (nrow(ss) == 0) return(plotly::plot_ly(type = "scatter", mode = "markers") %>%
                                plotly::add_annotations(text="No data after market filters", x=0.5, y=0.5,
                                                        xref="paper", yref="paper", showarrow=FALSE, font=list(size=14, color="#888")))
    
    ss <- ss %>%
      mutate(
        cpv_label   = get_cpv_label(cpv_cluster),
        pct_new_lab = scales::percent(share_new, accuracy=1),
        flag_new    = share_new * 100 >= thr_new,
        tooltip_text = paste0(
          "<b>", cpv_label, "</b>  (", tender_year, ")<br>",
          "Unique suppliers: <b>", n_suppliers, "</b><br>",
          "% New this year: <b>", pct_new_lab, "</b>",
          ifelse(flag_new, " ❗ above threshold", ""), "<br>",
          "Repeat suppliers: ", scales::percent(share_repeat, accuracy=1)
        )
      )
    
    y_var <- if (show_lab) "cpv_label" else "cpv_cluster"
    
    p <- ggplot(ss, aes(
      x    = factor(tender_year),
      y    = reorder(.data[[y_var]], cpv_cluster),
      size = n_suppliers,
      fill = share_new,
      text = tooltip_text
    )) +
      geom_point(shape=21, colour="white", stroke=0.3, alpha=0.9) +
      scale_fill_gradient2(
        low="#1565c0", mid="#fffde7", high="#c62828",
        midpoint = thr_new / 100,
        limits   = c(0, 1),
        labels   = scales::percent,
        name     = "% New
suppliers"
      ) +
      scale_size_continuous(range=c(3, 20), name="Unique
suppliers", labels=scales::comma) +
      labs(x="Year", y="CPV Market",
           title="Supplier landscape: depth (size) × entry rate (colour)") +
      pa_theme() +
      theme(
        axis.text.y   = element_text(size=if(show_lab) 10 else 11),
        axis.text.x   = element_text(angle=45, hjust=1),
        panel.grid.major = element_line(colour="#f0f0f0"),
        panel.grid.minor = element_blank(),
        legend.position  = "right"
      )
    
    if (show_cnt)
      p <- p + geom_text(aes(label=n_suppliers), size=2.5, colour="#333", fontface="bold")
    
    n_mkts <- dplyr::n_distinct(ss$cpv_cluster)
    dyn_h  <- max(420, min(750, n_mkts * 24 + 100))
    econ$fig_supp_bubble <- ggplotly(p, tooltip="text", height=dyn_h) %>%
      layout(font=list(size=11), hoverlabel=list(bgcolor="white", font=list(size=11)),
             hovermode="closest", legend=list(orientation="v"),
             yaxis=list(tickfont=list(size=13))) %>%
      pa_config()
    econ$fig_supp_bubble
  })
  # ── Plot 2: Market stability scatter — native plotly (no ggrepel/ggplotly issues) ─
  output$supplier_stability_plot <- renderPlotly({
    req(econ$filtered_analysis$supplier_stats, econ$filtered_data)
    ss   <- econ$filtered_analysis$supplier_stats
    keep <- get_market_filtered_cpvs(econ$filtered_data)
    if (!is.null(keep)) ss <- ss %>% filter(cpv_cluster %in% keep)
    if (nrow(ss) == 0) return(plotly::plot_ly(type = "scatter", mode = "markers") %>%
                                plotly::add_annotations(text="No data after market filters", x=0.5, y=0.5,
                                                        xref="paper", yref="paper", showarrow=FALSE, font=list(size=14, color="#888")))
    
    df <- econ$filtered_data
    mkt_size <- df %>%
      filter(!is.na(cpv_cluster), !is.na(tender_year)) %>%
      group_by(cpv_cluster, tender_year) %>% summarise(n_contracts=n(), .groups="drop") %>%
      group_by(cpv_cluster) %>% summarise(avg_contracts=mean(n_contracts), .groups="drop")
    
    # Volatility = year-on-year standard deviation of % new suppliers.
    # A market where % new jumps between 10% and 80% across years has high SD = volatile.
    # A market stuck at ~30% every year has low SD = predictable/stable.
    s <- ss %>%
      group_by(cpv_cluster) %>%
      summarise(
        avg_pct_new = mean(share_new, na.rm=TRUE),
        avg_n_supp  = mean(n_suppliers, na.rm=TRUE),
        volatility  = sd(share_new, na.rm=TRUE),   # SD of % new across years
        n_years     = n(),
        .groups="drop"
      ) %>%
      left_join(mkt_size, by="cpv_cluster") %>%
      mutate(
        cpv_label    = get_cpv_label(cpv_cluster),
        avg_contracts = replace_na(avg_contracts, 1),
        volatility    = replace_na(volatility, 0),
        # colour on entry rate
        col_val = avg_pct_new,
        tooltip = paste0(
          "<b>", cpv_label, "</b><br>",
          "Avg unique suppliers/yr: <b>", round(avg_n_supp, 1), "</b><br>",
          "Avg % new suppliers: <b>", scales::percent(avg_pct_new, accuracy=1), "</b><br>",
          "Entry rate volatility (SD): ", scales::percent(volatility, accuracy=1),
          "<br><i>SD of % new across years &mdash; higher = more year-to-year swings</i><br>",
          "Avg contracts/yr: ", round(avg_contracts), "<br>",
          "Years observed: ", n_years
        )
      )
    
    med_x <- median(s$avg_pct_new, na.rm=TRUE)
    med_y <- median(s$avg_n_supp,  na.rm=TRUE)
    
    # Colour scale: blue (stable/low entry) → red (high churn)
    cols <- scales::col_numeric(
      palette = c("#1565c0","#fffde7","#c62828"),
      domain  = c(0, 1)
    )(s$col_val)
    
    # Bubble size scaled to avg_contracts
    sz <- scales::rescale(sqrt(s$avg_contracts), to=c(8, 40))
    
    fig <- plot_ly(s,
                   x         = ~avg_pct_new,
                   y         = ~avg_n_supp,
                   text      = ~tooltip,
                   hoverinfo = "text",
                   type      = "scatter",
                   mode      = "markers",
                   marker    = list(
                     size    = sz,
                     color   = cols,
                     opacity = 0.85,
                     line    = list(color="white", width=1.5)
                   )
    ) %>%
      # Median reference lines as shapes (survive without ggplot conversion loss)
      layout(font=list(size=11),
             xaxis  = list(title="Average % new suppliers per year (entry rate)",
                           tickformat=".0%",
                           range=c(-0.02, 1.08),   # pad left+right so edge bubbles aren't clipped
                           zeroline=FALSE),
             yaxis  = list(title="Average unique suppliers per year (market depth)",
                           zeroline=FALSE),
             # generous margins: extra bottom for "median entry" label, extra right for edge bubbles
             margin = list(l=90, r=60, t=44, b=110),
             shapes = list(
               list(type="line", x0=med_x, x1=med_x, y0=0, y1=1, yref="paper",
                    line=list(color="#bbb", width=1, dash="dot")),
               list(type="line", x0=0, x1=1, xref="paper", y0=med_y, y1=med_y,
                    line=list(color="#bbb", width=1, dash="dot"))
             ),
             annotations = list(
               # "median depth": just below the horizontal line at the very left edge
               list(x=0, y=med_y, xref="paper", yref="y",
                    xanchor="left", yanchor="top",
                    text="  median depth", showarrow=FALSE,
                    font=list(size=9, color="#aaa")),
               # "median entry": placed in the bottom margin BELOW the x-axis (negative paper y),
               # centred on the vertical line — never overlaps plot content
               list(x=med_x, y=-0.05, xref="x", yref="paper",
                    xanchor="center", yanchor="top",
                    text="median entry", showarrow=FALSE,
                    font=list(size=9, color="#aaa"))
             ),
             hoverlabel = list(bgcolor="white", font=list(size=12)),
             hovermode  = "closest",
             showlegend = FALSE
      )
    econ$fig_supp_stability <- fig %>%
      plotly::add_annotations(
        text      = "Market Stability Overview (avg across years)",
        x         = 0.5, y = 1.04, xref = "paper", yref = "paper",
        xanchor   = "center", yanchor = "bottom", showarrow = FALSE,
        font      = list(size = 11, color = "#444444")
      ) %>%
      pa_config()
    econ$fig_supp_stability
  })
  
  # ── Plot 3: New vs repeat trend — native plotly stacked area per market ─
  output$supp_trend_market_picker_ui <- renderUI({
    req(econ$filtered_data)
    
    # Build supplier_stats with fallback: if none in analysis, compute from filtered data
    ss <- econ$filtered_analysis$supplier_stats
    df <- econ$filtered_data
    
    # Always offer an "All Markets" aggregate option
    # Detect supplier ID col — strict three-tier priority: masterid → id → name
    sup_id_col <- intersect(c("bidder_masterid", "bidder_id", "bidder_name"), names(df))[1]
    
    # "All Markets" synthetic row: aggregate across all CPVs (or use when no CPV present)
    has_cpv <- !is.null(ss) && nrow(ss) > 0 && "cpv_cluster" %in% names(ss)
    
    if (has_cpv) {
      cpvs <- sort(unique(ss$cpv_cluster))
      cpv_choices <- setNames(cpvs, sapply(cpvs, get_cpv_label))
      all_choice  <- c("__ALL__" = "\u2605 All Markets (entire dataset)")
      choices     <- c(all_choice, cpv_choices)
      default_sel <- c("__ALL__", head(cpvs, min(3, length(cpvs))))
    } else {
      choices     <- c("__ALL__" = "\u2605 All Markets (entire dataset)")
      default_sel <- "__ALL__"
    }
    
    pickerInput("supp_trend_markets", "Select markets to show:",
                choices  = choices,
                selected = default_sel,
                multiple = TRUE,
                options  = list(`actions-box`=TRUE, `live-search`=TRUE,
                                `selected-text-format`="count > 4",
                                `count-selected-text`="{0} markets"))
  })
  
  output$supplier_trend_plot_ui <- renderUI({
    req(econ$filtered_data)
    
    # When no CPV market data is available, show the aggregate stacked chart directly
    ss      <- econ$filtered_analysis$supplier_stats
    has_cpv <- !is.null(ss) && nrow(ss) > 0 && "cpv_cluster" %in% names(ss)
    
    if (!has_cpv) {
      # Show the aggregate (no-CPV) plotly output, sized for a single panel
      return(plotlyOutput("supplier_trend_agg_plot", height = "420px"))
    }
    
    if (is.null(input$supp_trend_markets) || length(input$supp_trend_markets) == 0)
      return(div(class="deferred-box", icon("hand-pointer"),
                 " Select at least one market above to display the chart."))
    # Count real markets (excluding __ALL__)
    real_mkts <- setdiff(input$supp_trend_markets, "__ALL__")
    has_all   <- "__ALL__" %in% input$supp_trend_markets
    n_panels  <- length(real_mkts) + if (has_all) 1L else 0L
    nrows     <- ceiling(n_panels / 2L)
    h         <- max(400L, nrows * 340L)
    plotlyOutput("supplier_trend_plot", height=paste0(h, "px"))
  })
  
  # ── Aggregate "New vs Repeat" for countries without CPV market categories ──
  # Uses the same native plotly stacked-area style as the per-market panels:
  # orange (rgba 217,119,6) = Repeat, teal (rgba 0,137,123) = New.
  # Count / Share toggle is respected identically.
  output$supplier_trend_agg_plot <- renderPlotly({
    req(econ$filtered_data)
    metric    <- input$supp_trend_metric %||% "count"
    use_share <- identical(metric, "share")
    
    # Compute stats live from filtered_data so filter changes are reflected.
    # Three-tier ID priority: masterid -> id -> name.
    df_live    <- econ$filtered_data %||% econ$data
    sup_id_agg <- intersect(c("bidder_masterid", "bidder_id", "bidder_name"), names(df_live))[1]
    
    if (is.na(sup_id_agg) || !"tender_year" %in% names(df_live))
      return(plotly::plot_ly() %>%
               plotly::add_annotations(
                 text = "No supplier data found (need bidder_masterid, bidder_id, or bidder_name, plus tender_year)",
                 x=0.5, y=0.5, xref="paper", yref="paper",
                 showarrow=FALSE, font=list(size=12, color="#888")))
    
    agg_stats <- tryCatch(
      compute_supplier_entry_aggregate(df_live, supplier_id_col = sup_id_agg),
      error = function(e) NULL)
    
    if (is.null(agg_stats) || nrow(agg_stats) == 0)
      return(plotly::plot_ly() %>%
               plotly::add_annotations(
                 text = paste0("No supplier entry data (column used: '", sup_id_agg, "')"),
                 x=0.5, y=0.5, xref="paper", yref="paper",
                 showarrow=FALSE, font=list(size=12, color="#888")))
    
    ytitle  <- if (use_share) "Share of suppliers (%)" else "Number of suppliers"
    ysuffix <- if (use_share) "%" else ""
    
    d <- agg_stats %>%
      dplyr::mutate(
        cum1 = if (use_share) round(share_repeat * 100, 1) else n_repeat_suppliers,
        cum2 = if (use_share) round((share_repeat + share_new) * 100, 1)
        else n_repeat_suppliers + n_new_suppliers,
        # One tooltip line PER TRACE: in unified hover mode every line gets
        # its own trace-coloured swatch, so combined multi-line tooltips on a
        # single trace show mismatched colours next to the other lines.
        tip_rep = if (use_share)
          paste0("Repeat: <b>", round(share_repeat * 100, 1), "%</b>")
        else
          paste0("Repeat: <b>", scales::comma(n_repeat_suppliers), "</b>"),
        tip_new = if (use_share)
          paste0("New: <b>", round(share_new * 100, 1), "%</b>  \u00b7  Total: ",
                 scales::comma(n_suppliers), " suppliers")
        else
          paste0("New: <b>", scales::comma(n_new_suppliers), "</b>  \u00b7  Total: ",
                 scales::comma(n_suppliers), " suppliers")
      )
    
    id_label <- dplyr::case_when(
      sup_id_agg == "bidder_masterid" ~ "Master ID",
      sup_id_agg == "bidder_id"       ~ "Supplier ID",
      TRUE                            ~ "Supplier Name"
    )
    
    # NOTE: the base plot_ly() call must carry NO data — a data-bearing base
    # creates an invisible ghost trace ("trace 0") that pollutes the legend
    # and the unified hover box. Each add_trace() carries the data instead.
    plot_ly() %>%
      layout(
        hovermode = "x unified",
        xaxis  = list(title = "Year", dtick = 1, tickformat = "d", tickangle = -45,
                      tickfont = list(size = 13), titlefont = list(size = 14)),
        yaxis  = list(title = ytitle, ticksuffix = ysuffix,
                      tickfont = list(size = 13), titlefont = list(size = 14)),
        legend = list(orientation = "h", y = 1.08, x = 0.5, xanchor = "center"),
        annotations = list(list(
          text      = paste0("All markets combined — identity: ", id_label),
          x = 0.5, y = -0.18, xref = "paper", yref = "paper",
          xanchor = "center", showarrow = FALSE,
          font = list(size = 10, color = "#888888")
        )),
        margin = list(l = 60, r = 20, t = 40, b = 70)
      ) %>%
      add_trace(data = d, x = ~tender_year,
                y = ~cum1, name = "Repeat", legendgroup = "Repeat", showlegend = TRUE,
                type = "scatter", mode = "none", fill = "tozeroy",
                fillcolor = "rgba(217,119,6,0.75)",
                hoverinfo = "text", hovertext = ~tip_rep) %>%
      add_trace(data = d, x = ~tender_year,
                y = ~cum2, name = "New", legendgroup = "New", showlegend = TRUE,
                type = "scatter", mode = "none", fill = "tonexty",
                fillcolor = "rgba(0,137,123,0.75)",
                hoverinfo = "text", hovertext = ~tip_new)
  })
  
  output$supplier_trend_plot <- renderPlotly({
    req(econ$filtered_data, input$supp_trend_markets)
    metric    <- input$supp_trend_metric %||% "count"
    use_share <- identical(metric, "share")
    
    # Use the raw uploaded data (all original columns intact).
    # econ$data is set from df_econ (raw upload + add_tender_year) at load time.
    # Fall back to filtered_data if raw not yet available.
    df_raw  <- if (!is.null(econ$data) && nrow(econ$data) > 0) econ$data
    else econ$filtered_data
    ss_raw  <- econ$filtered_analysis$supplier_stats
    
    sel      <- input$supp_trend_markets
    has_all  <- "__ALL__" %in% sel
    cpv_sel  <- setdiff(sel, "__ALL__")
    
    # Detect supplier ID col from filtered_data first (used for ALL panel),
    # then fall back to df_raw. Three-tier priority: masterid → id → name.
    sup_id_col <- intersect(
      c("bidder_masterid", "bidder_id", "bidder_name"),
      unique(c(names(econ$filtered_data), names(df_raw)))
    )[1]
    
    make_entry_stats <- function(data, label) {
      if (is.na(sup_id_col))                       return(NULL)
      if (!sup_id_col %in% names(data))            return(NULL)
      if (!"tender_year" %in% names(data))         return(NULL)
      
      sup_yr <- data %>%
        dplyr::filter(
          !is.na(.data[[sup_id_col]]),
          nchar(as.character(.data[[sup_id_col]])) > 0,
          !is.na(tender_year)
        ) %>%
        dplyr::distinct(.data[[sup_id_col]], tender_year) %>%
        dplyr::rename(supplier_id = 1)
      
      if (nrow(sup_yr) == 0) return(NULL)
      
      first_yr <- sup_yr %>%
        dplyr::group_by(supplier_id) %>%
        dplyr::summarise(first_year = min(tender_year, na.rm = TRUE), .groups = "drop")
      
      out <- sup_yr %>%
        dplyr::left_join(first_yr, by = "supplier_id") %>%
        dplyr::mutate(is_new = tender_year == first_year) %>%
        dplyr::group_by(tender_year) %>%
        dplyr::summarise(
          n_suppliers        = dplyr::n(),
          n_new_suppliers    = sum(is_new,  na.rm = TRUE),
          n_repeat_suppliers = sum(!is_new, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::mutate(
          cpv_cluster = label, cpv_label = label, n_other = 0L,
          pct_repeat  = round(n_repeat_suppliers / pmax(n_suppliers, 1) * 100, 1),
          pct_new     = round(n_new_suppliers     / pmax(n_suppliers, 1) * 100, 1),
          pct_other   = 0
        ) %>%
        dplyr::arrange(tender_year)
      
      if (nrow(out) == 0) return(NULL)
      out
    }
    
    panels <- list()
    ALL_LABEL <- "\u2605 All Markets"
    
    if (has_all) {
      # Use econ$filtered_data — same source as supplier_trend_agg_plot (the
      # aggregate-only renderer that is known to work). econ$data is the raw
      # pre-pipeline frame and may differ in column structure.
      df_for_all <- econ$filtered_data %||% econ$data
      agg <- if (!is.null(df_for_all) && nrow(df_for_all) > 0 &&
                 sup_id_col %in% names(df_for_all) &&
                 "tender_year" %in% names(df_for_all)) {
        tryCatch({
          agg_raw <- compute_supplier_entry_aggregate(df_for_all, supplier_id_col = sup_id_col)
          if (is.null(agg_raw) || nrow(agg_raw) == 0) NULL
          else agg_raw %>%
            dplyr::mutate(
              cpv_cluster = ALL_LABEL, cpv_label = ALL_LABEL, n_other = 0L,
              pct_repeat  = round(share_repeat * 100, 1),
              pct_new     = round(share_new    * 100, 1),
              pct_other   = 0
            ) %>%
            dplyr::arrange(tender_year)
        }, error = function(e) {
          message("ALL panel error: ", e$message)
          NULL
        })
      } else NULL
      if (!is.null(agg) && nrow(agg) > 0) panels[[ALL_LABEL]] <- agg
    }
    
    if (length(cpv_sel) > 0 && !is.null(ss_raw) && nrow(ss_raw) > 0) {
      cpv_data <- ss_raw %>%
        dplyr::filter(cpv_cluster %in% cpv_sel) %>%
        dplyr::mutate(
          cpv_label  = get_cpv_label(cpv_cluster),
          n_other    = pmax(0L, n_suppliers - n_new_suppliers - n_repeat_suppliers),
          pct_repeat = round(n_repeat_suppliers / pmax(n_suppliers, 1) * 100, 1),
          pct_new    = round(n_new_suppliers     / pmax(n_suppliers, 1) * 100, 1),
          pct_other  = round(n_other             / pmax(n_suppliers, 1) * 100, 1)
        ) %>%
        dplyr::arrange(cpv_label, tender_year)
      for (cpv in sort(unique(cpv_data$cpv_label)))
        panels[[cpv]] <- cpv_data %>% dplyr::filter(cpv_label == cpv)
    }
    
    if (length(panels) == 0)
      return(plotly::plot_ly() %>%
               plotly::add_annotations(
                 text = if (is.na(sup_id_col))
                   "No supplier identifier found (need bidder_masterid, bidder_id, or bidder_name)"
                 else paste0("No data for selected markets (using '", sup_id_col,
                             "' as supplier ID — check it has non-empty values)"),
                 x=0.5, y=0.5, xref="paper", yref="paper",
                 showarrow=FALSE, font=list(size=12, color="#888")))
    
    ytitle  <- if (use_share) "Share of suppliers (%)" else "Number of suppliers"
    ysuffix <- if (use_share) "%" else ""
    markets <- names(panels)
    n_mkts  <- length(markets)
    ncols   <- min(2L, n_mkts)
    nrows   <- ceiling(n_mkts / ncols)
    
    plot_list <- lapply(seq_along(markets), function(i) {
      mkt      <- markets[[i]]
      d        <- panels[[mkt]] %>%
        dplyr::mutate(
          cum1 = if (use_share) pct_repeat           else n_repeat_suppliers,
          cum2 = if (use_share) pct_repeat + pct_new else n_repeat_suppliers + n_new_suppliers,
          # Per-trace tooltip lines — see the aggregate plot note (unified
          # hover assigns one swatch per trace, so each line must belong to
          # the trace whose colour it describes).
          tip_rep = if (use_share) paste0("Repeat: <b>", pct_repeat, "%</b>")
          else paste0("Repeat: <b>", n_repeat_suppliers, "</b>"),
          tip_new = if (use_share)
            paste0("New: <b>", pct_new, "%</b>  \u00b7  Total: ",
                   n_suppliers, " suppliers")
          else
            paste0("New: <b>", n_new_suppliers, "</b>  \u00b7  Total: ",
                   n_suppliers, " suppliers")
        )
      show_leg <- (i == 1L)
      if (nrow(d) == 0) return(NULL)
      # Empty base (no data) — see the aggregate plot note: a data-bearing
      # base adds one ghost "trace N" per panel to legend and hover.
      plot_ly() %>%
        layout(xaxis = list(title="Year", dtick=1, tickformat="d", tickangle=-45,
                            tickfont=list(size=13), titlefont=list(size=14)),
               yaxis = list(title=ytitle, ticksuffix=ysuffix,
                            tickfont=list(size=13), titlefont=list(size=14))) %>%
        add_trace(data=d, x=~tender_year,
                  y=~cum1, name="Repeat", legendgroup="Repeat", showlegend=show_leg,
                  type="scatter", mode="none", fill="tozeroy",
                  fillcolor="rgba(217,119,6,0.75)",
                  hoverinfo="text", hovertext=~tip_rep) %>%
        add_trace(data=d, x=~tender_year,
                  y=~cum2, name="New", legendgroup="New", showlegend=show_leg,
                  type="scatter", mode="none", fill="tonexty",
                  fillcolor="rgba(0,137,123,0.75)",
                  hoverinfo="text", hovertext=~tip_new)
    })
    
    plot_list <- Filter(Negate(is.null), plot_list)
    if (length(plot_list) == 0)
      return(plotly::plot_ly() %>%
               plotly::add_annotations(text="No data to display", x=0.5, y=0.5,
                                       xref="paper", yref="paper", showarrow=FALSE,
                                       font=list(size=13, color="#888")))
    
    col_centres <- if (ncols == 2) c(0.22, 0.78) else 0.5
    row_height  <- 1 / nrows
    panel_anns  <- lapply(seq_along(markets), function(i) {
      col_idx <- ((i - 1L) %% ncols) + 1L
      row_idx <- ceiling(i / ncols)
      y_top   <- 1 - (row_idx - 1L) * row_height
      list(text=markets[[i]], x=col_centres[[col_idx]], y=y_top - 0.03,
           xref="paper", yref="paper", xanchor="center", yanchor="bottom",
           showarrow=FALSE, font=list(size=12, color="#222"))
    })
    
    fig_out <- subplot(plot_list, nrows=nrows, shareX=FALSE, shareY=FALSE,
                       titleX=FALSE, titleY=FALSE, heights=rep(row_height, nrows),
                       margin=c(0.06, 0.06, 0.14, 0.06))
    fig_out <- plotly::layout(fig_out,
                              annotations=panel_anns,
                              hoverlabel=list(bgcolor="white", font=list(size=13)),
                              hovermode="x unified", font=list(size=12),
                              margin=list(l=70, r=20, t=30, b=70),
                              paper_bgcolor="#ffffff", plot_bgcolor="#ffffff",
                              legend=list(orientation="h", y=-0.06, x=0.5, xanchor="center",
                                          font=list(size=12)))
    econ$fig_supp_trend <- fig_out
    fig_out
  })
  
  
  # [APP-SV14] TOP SUPPLIERS PLOT ────────────────────────────────────────────
  # ============================================================
  # TOP SUPPLIERS PLOT
  # ============================================================
  
  output$top_suppliers_plot_ui <- renderUI({
    req(econ$filtered_data)
    df <- econ$filtered_data
    # Show plot as long as ANY supplier identifier is present
    has_supp <- any(c("bidder_masterid","bidder_id","bidder_name",
                      "bidder_normalized_name","winner_name","bidder_normalizedname") %in% names(df))
    if (!has_supp) return(div(class="alert alert-warning",
                              icon("exclamation-triangle"),
                              " No supplier identifier column found (expected bidder_masterid, bidder_id, or bidder_name)."))
    top_n <- as.integer(input$top_supp_n %||% 20)
    h     <- paste0(max(350, min(900, top_n * 32 + 80)), "px")
    plotlyOutput("top_suppliers_plot", height = h)
  })
  
  output$top_suppliers_plot <- renderPlotly({
    req(econ$filtered_data)
    df <- econ$filtered_data
    
    # Detect supplier ID and name columns
    supp_id_col <- if ("bidder_masterid"       %in% names(df)) "bidder_masterid"
    else if ("bidder_id"          %in% names(df)) "bidder_id"
    else NULL
    supp_nm_col <- if ("bidder_name"            %in% names(df)) "bidder_name"
    else if ("bidder_normalized_name" %in% names(df)) "bidder_normalized_name"
    else if ("winner_name"        %in% names(df)) "winner_name"
    else if ("bidder_normalizedname" %in% names(df)) "bidder_normalizedname"
    else NULL
    if (is.null(supp_id_col) && is.null(supp_nm_col))
      return(.empty_plotly("No supplier ID or name column found in the data."))
    # Use name if available, fall back to ID
    supp_col <- if (!is.null(supp_nm_col)) supp_nm_col else supp_id_col
    
    # Detect buyer name column
    buy_nm_col <- if ("buyer_name"             %in% names(df)) "buyer_name"
    else if ("buyer_normalized_name"  %in% names(df)) "buyer_normalized_name"
    else if ("buyer_normalizedname"   %in% names(df)) "buyer_normalizedname"
    else if ("contracting_authority"  %in% names(df)) "contracting_authority"
    else if ("buyer_masterid"         %in% names(df)) "buyer_masterid"
    else NULL
    
    top_n     <- as.integer(input$top_supp_n  %||% 20)
    metric    <- input$top_supp_metric %||% "n_contracts"
    price_col <- detect_price_col(df, .PRICE_COLS_SUPP)
    
    # Per-supplier summary
    df_filt <- df %>% dplyr::filter(!is.na(.data[[supp_col]]),
                                    as.character(.data[[supp_col]]) != "")
    ss <- df_filt %>%
      dplyr::group_by(supplier = .data[[supp_col]]) %>%
      dplyr::summarise(
        n_contracts = dplyr::n(),
        total_value = if (!is.null(price_col))
          sum(.data[[price_col]], na.rm = TRUE) else NA_real_,
        n_markets   = if ("cpv_cluster" %in% names(df))
          dplyr::n_distinct(cpv_cluster, na.rm = TRUE) else NA_integer_,
        n_years     = if ("tender_year" %in% names(df))
          dplyr::n_distinct(tender_year, na.rm = TRUE) else NA_integer_,
        .groups = "drop"
      )
    
    # Find top buyer per supplier (by number of contracts together)
    if (!is.null(buy_nm_col)) {
      top_buyer <- df_filt %>%
        dplyr::filter(!is.na(.data[[buy_nm_col]]),
                      as.character(.data[[buy_nm_col]]) != "") %>%
        dplyr::group_by(supplier = .data[[supp_col]],
                        buyer    = .data[[buy_nm_col]]) %>%
        dplyr::summarise(n = dplyr::n(), .groups = "drop") %>%
        dplyr::group_by(supplier) %>%
        dplyr::slice_max(n, n = 1, with_ties = FALSE) %>%
        dplyr::ungroup() %>%
        dplyr::mutate(
          buyer_short = {
            b <- as.character(buyer)
            ifelse(nchar(b) > 40, paste0(substr(b, 1, 38), "…"), b)
          }
        ) %>%
        dplyr::select(supplier, top_buyer = buyer_short, top_buyer_n = n)
      ss <- dplyr::left_join(ss, top_buyer, by = "supplier")
    } else {
      ss$top_buyer   <- NA_character_
      ss$top_buyer_n <- NA_integer_
    }
    
    # Sort and trim
    sort_col <- if (metric == "total_value" && all(is.na(ss$total_value))) "n_contracts"
    else if (metric == "n_markets" && all(is.na(ss$n_markets))) "n_contracts"
    else metric
    
    ss <- ss %>%
      dplyr::arrange(dplyr::desc(.data[[sort_col]])) %>%
      dplyr::slice_head(n = top_n) %>%
      dplyr::arrange(.data[[sort_col]]) %>%   # ascending: highest ends up at top via categoryarray
      dplyr::mutate(
        label = {
          s <- as.character(supplier)
          ifelse(nchar(s) > 45, paste0(substr(s, 1, 43), "…"), s)
        },
        color_val = if (!all(is.na(total_value))) total_value else n_contracts
      )
    # Category order for plot_ly — must be set explicitly (unlike ggplot factors)
    cat_order <- ss$label   # ascending order → highest at top after axis reversal
    
    has_value   <- !all(is.na(ss$total_value))
    has_markets <- !all(is.na(ss$n_markets))
    has_years   <- !all(is.na(ss$n_years))
    has_buyer   <- !all(is.na(ss$top_buyer))
    
    # Join supplier ID from original data if it differs from display name
    has_id <- !is.null(supp_id_col) && supp_id_col != supp_col
    if (has_id) {
      id_lkp <- df %>%
        dplyr::filter(!is.na(.data[[supp_col]]), !is.na(.data[[supp_id_col]])) %>%
        dplyr::distinct(supplier = .data[[supp_col]],
                        supp_id_val = as.character(.data[[supp_id_col]]))
      ss <- dplyr::left_join(ss, id_lkp, by = "supplier")
    } else {
      ss$supp_id_val <- NA_character_
    }
    
    # Auto-scale total_value for display (B / M / K depending on magnitude)
    if (has_value) {
      max_tv <- max(ss$total_value, na.rm = TRUE)
      if      (max_tv >= 1e9) { tv_scale <- 1e9; tv_suffix <- "B" }
      else if (max_tv >= 1e6) { tv_scale <- 1e6; tv_suffix <- "M" }
      else if (max_tv >= 1e3) { tv_scale <- 1e3; tv_suffix <- "K" }
      else                    { tv_scale <- 1;   tv_suffix <- ""  }
    } else {
      tv_scale <- 1; tv_suffix <- ""
    }
    
    loc_lbl_s  <- (econ$local_currency %||% list(label="NC"))$label
    cur_pfx_s  <- if (loc_lbl_s == "USD") "$" else ""
    
    fmt_value <- function(v) paste0(cur_pfx_s,
                                    scales::number(v, scale=1/tv_scale, suffix=tv_suffix, accuracy=0.1),
                                    if (cur_pfx_s == "") paste0(" ", loc_lbl_s) else "")
    
    # Build tooltip — all outside mutate to avoid .data pronoun issues
    ss$tooltip <- paste0(
      "<b>", ss$label, "</b><br>",
      if (has_id)      paste0("ID: ", ss$supp_id_val, "<br>") else "",
      "Contracts won: <b>", scales::comma(ss$n_contracts), "</b><br>",
      if (has_value)   paste0("Total value: <b>", fmt_value(ss$total_value), "</b><br>") else "",
      if (has_markets) paste0("Markets served: <b>", ss$n_markets, "</b><br>") else "",
      if (has_years)   paste0("Active years: <b>", ss$n_years, "</b><br>") else "",
      if (has_buyer)   paste0("Top buyer: <b>", ss$top_buyer, "</b> (", scales::comma(ss$top_buyer_n), " contracts)") else ""
    )
    
    x_val <- ss[[sort_col]]
    x_lab <- switch(sort_col,
                    n_contracts = "Number of contracts won",
                    total_value = paste0("Total contract value (", tv_suffix, " ", loc_lbl_s, ")"),
                    n_markets   = "Number of markets served")
    
    # Colour scale
    col_vals  <- ss$color_val
    col_range <- range(col_vals, na.rm = TRUE)
    col_norm  <- if (diff(col_range) > 0) (col_vals - col_range[1]) / diff(col_range) else rep(0.5, nrow(ss))
    hex_cols  <- scales::col_numeric(c("#93C5FD", "#1E3A8A"), domain = c(0, 1))(col_norm)
    
    # x-axis tick format — use auto-scaled values
    x_tickformat <- if (sort_col == "total_value") "$,.1f" else ","
    x_ticksuffix <- if (sort_col == "total_value") tv_suffix else ""
    x_tickscale  <- if (sort_col == "total_value") (1 / tv_scale) else 1
    
    dyn_h <- max(350, min(900, top_n * 32 + 80))
    
    # Native plot_ly — no ggplotly conversion overhead → instant metric switch
    plot_ly(height = dyn_h) %>%
      # Stems
      add_segments(
        data = ss,
        x = 0, xend = ~x_val * x_tickscale,
        y = ~label, yend = ~label,
        line = list(color = "#CBD5E1", width = 1.5),
        hoverinfo = "skip", showlegend = FALSE
      ) %>%
      # Dots
      add_markers(
        data = ss,
        x = ~x_val * x_tickscale, y = ~label,
        marker = list(
          size   = 11,
          color  = hex_cols,
          line   = list(color = "white", width = 1.5)
        ),
        text      = ~tooltip,
        hoverinfo = "text",
        showlegend = FALSE
      ) %>%
      layout(
        xaxis = list(
          title      = x_lab,
          tickformat = x_tickformat,
          ticksuffix = x_ticksuffix,
          zeroline   = FALSE,
          gridcolor  = "#F1F5F9",
          tickfont   = list(size = 11)
        ),
        yaxis = list(
          title         = "",
          tickfont      = list(size = 11),
          categoryorder = "array",
          categoryarray = cat_order       # ascending data + array order = highest at top
        ),
        hoverlabel  = list(bgcolor = "white", font = list(size = 11)),
        hovermode   = "closest",
        margin      = list(l = 10, r = 30, t = 30, b = 50),
        paper_bgcolor = "#ffffff",
        plot_bgcolor  = "#ffffff"
      ) %>%
      pa_config() -> fig
    econ$fig_top_suppliers <- fig
    fig
  })
  
  
  # [APP-SV15] NETWORK OUTPUTS (on-demand generation, size guards) ───────────
  # ============================================================
  # NETWORK OUTPUTS
  # ============================================================
  
  # Network status box
  # CPV market picker — populated from live data after upload
  output$network_cpv_picker_ui <- renderUI({
    if (is.null(econ$filtered_data)) {
      return(div(class="alert alert-info", style="padding:8px;",
                 icon("info-circle"), " Load data first to see available CPV markets."))
    }
    df <- econ$filtered_data
    if (!"cpv_cluster" %in% names(df) && "lot_productcode" %in% names(df))
      df <- df %>% dplyr::mutate(cpv_cluster = substr(as.character(lot_productcode), 1, 2))
    
    if (!"cpv_cluster" %in% names(df)) {
      return(div(class="alert alert-warning", "No CPV cluster column found in data."))
    }
    
    cpv_codes <- sort(unique(df$cpv_cluster[!is.na(df$cpv_cluster)]))
    # Build labelled choices: "45 - Construction work" => value "45"
    cpv_labels <- sapply(cpv_codes, get_cpv_label)
    choices <- setNames(cpv_codes, cpv_labels)
    
    # Count contracts per market for the subtitle
    counts <- table(df$cpv_cluster)
    
    pickerInput(
      "network_cpv_selected",
      label = tags$div(icon("project-diagram"), tags$strong(" Select CPV Markets for Networks")),
      choices = choices,
      selected = NULL,
      multiple = TRUE,
      options = list(
        `actions-box`        = TRUE,
        `live-search`        = TRUE,
        `live-search-placeholder` = "Search markets...",
        `selected-text-format` = "count > 3",
        `count-selected-text`  = "{0} markets selected",
        `none-selected-text`   = "-- Select one or more markets --",
        size = 10
      )
    )
  })
  
  output$network_status_box <- renderUI({
    plots <- econ$filtered_analysis$network_plots
    if (is.null(plots)) {
      div(class="alert alert-info", style="margin-bottom:0;",
          icon("info-circle"), " No networks generated yet.",
          " Enter CPV codes above and click Generate.")
    } else if (length(plots) == 0) {
      div(class="alert alert-warning", style="margin-bottom:0;",
          icon("exclamation-triangle"), " Networks generated but no matching data found.",
          " Try different CPV codes.")
    } else {
      div(class="alert alert-success", style="margin-bottom:0;",
          icon("check-circle"), tags$strong(paste0(" ", length(plots), " network(s) ready.")),
          " Scroll down to view. Click Generate to regenerate with new settings.")
    }
  })
  
  # On-demand network generation
  # Calls plot_buyer_supplier_networks() directly - never re-runs the full pipeline.
  # The stress layout in ggraph can segfault on large graphs; we guard with row limits
  # and process one CPV at a time so a single failure does not kill everything.
  observeEvent(input$run_networks_now, {
    req(econ$filtered_data)
    cpv_list <- input$network_cpv_selected
    if (is.null(cpv_list) || length(cpv_list) == 0) {
      showNotification("Select at least one CPV market from the list before generating networks.",
                       type = "warning", duration = 5)
      return()
    }
    top_n    <- as.integer(input$network_top_buyers %||% 15)
    
    df_net <- econ$filtered_data
    
    # Determine correct buyer column
    buyer_col <- if ("buyer_masterid" %in% names(df_net)) "buyer_masterid" else
      if ("buyer_id"       %in% names(df_net)) "buyer_id"       else NULL
    if (is.null(buyer_col)) {
      showNotification("Cannot generate networks: no buyer ID column (buyer_masterid / buyer_id).",
                       type = "error", duration = 8)
      return()
    }
    
    # Ensure cpv_cluster column exists
    if (!"cpv_cluster" %in% names(df_net) && "lot_productcode" %in% names(df_net))
      df_net <- df_net %>% dplyr::mutate(cpv_cluster = substr(as.character(lot_productcode), 1, 2))
    
    # Hard cap on total rows to prevent ggraph stress layout from segfaulting
    MAX_TOTAL <- 150000L
    if (nrow(df_net) > MAX_TOTAL) {
      showNotification(
        paste0("Sampling ", formatC(MAX_TOTAL, format="d", big.mark=","),
               " rows from ", formatC(nrow(df_net), format="d", big.mark=","),
               " for network generation (memory safety)."),
        type = "warning", duration = 6)
      df_net <- df_net[sample.int(nrow(df_net), MAX_TOTAL), ]
    }
    
    withProgress(message = "Generating networks...", value = 0, {
      net_plots <- list()
      
      for (i in seq_along(cpv_list)) {
        cpv <- cpv_list[[i]]
        incProgress(i / length(cpv_list),
                    detail = paste0("CPV ", cpv, "  (", i, "/", length(cpv_list), ")"))
        
        # Skip if not enough data for this CPV
        n_rows <- sum(!is.na(df_net$cpv_cluster) & df_net$cpv_cluster == cpv)
        if (n_rows < 5) {
          message("Skipping CPV ", cpv, ": only ", n_rows, " rows in filtered data")
          next
        }
        
        # Per-CPV row cap - large markets crash the stress layout
        df_cpv <- df_net[!is.na(df_net$cpv_cluster) & df_net$cpv_cluster == cpv, ]
        MAX_CPV <- 30000L
        if (nrow(df_cpv) > MAX_CPV) {
          message("CPV ", cpv, ": sampling ", MAX_CPV, " from ", nrow(df_cpv), " rows")
          df_cpv <- df_cpv[sample.int(nrow(df_cpv), MAX_CPV), ]
        }
        
        p <- tryCatch(
          suppressWarnings(
            plot_buyer_supplier_networks(
              df_cpv,
              cpv_focus    = cpv,
              n_top_buyers = top_n,
              ncol         = 2,
              buyer_id_col = buyer_col,
              country_code = econ$country_code %||% "GEN"
            )
          ),
          error = function(e) {
            message("Network CPV ", cpv, " error: ", e$message)
            NULL
          }
        )
        
        if (!is.null(p)) {
          net_plots[[paste0("CPV ", cpv)]] <- p
        }
      }
      
      econ$filtered_analysis$network_plots <- net_plots
      n_ok <- length(net_plots)
      
      if (n_ok > 0) {
        showNotification(
          paste0("✓ ", n_ok, " network(s) ready: ", paste(names(net_plots), collapse=", ")),
          type = "message", duration = 4)
      } else {
        showNotification(
          paste0("No networks generated. Verify CPV codes [",
                 paste(cpv_list, collapse=", "), "] exist in the cpv_cluster column."),
          type = "warning", duration = 8)
      }
    })
  })
  
  output$network_plots_ui <- renderUI({
    plots <- econ$filtered_analysis$network_plots
    if (is.null(plots) || length(plots) == 0) {
      return(div(class="alert alert-info", style="margin:20px;",
                 icon("info-circle"),
                 " Use the panel above to select CPV markets and generate network diagrams."))
    }
    plot_boxes <- lapply(seq_along(plots), function(i) {
      pname <- paste0("econ_network_plot_", i)
      dname <- paste0("dl_network_", i)
      p     <- plots[[i]]
      output[[pname]] <- renderPlot({ p }, height = 800)
      # Register download handler here so it's always in sync with the displayed plot
      output[[dname]] <- downloadHandler(
        filename = function() paste0("network_cpv", i, "_", econ$country_code %||% "export",
                                     "_", format(Sys.Date(), "%Y%m%d"), ".png"),
        content  = function(file) {
          req(!is.null(p))
          ggplot2::ggsave(file, p, width = 14, height = 11, dpi = 300, bg = "white")
        }
      )
      box(title = names(plots)[i], width = 12, solidHeader = TRUE, status = "primary",
          plotOutput(pname, height = "800px"),
          downloadButton(dname, "Download Figure",
                         class = "download-btn btn-sm"))
    })
    do.call(tagList, plot_boxes)
  })
  
  
  # [APP-SV16] RELATIVE PRICE OUTPUTS (shared rel_price_data reactive) ───────
  # ============================================================
  # RELATIVE PRICE OUTPUTS
  # ============================================================
  
  # Computed once per filtered_data change; all four rel plots share it
  rel_price_data <- reactive({
    req(econ$filtered_data)
    tryCatch(add_relative_price(econ$filtered_data), error = function(e) NULL)
  })
  
  .empty_plotly <- function(msg, color = "#888")
    plotly::plot_ly(type = "scatter", mode = "markers") %>% plotly::add_annotations(
      text = msg, x = 0.5, y = 0.5, xref = "paper", yref = "paper",
      showarrow = FALSE, font = list(size = 13, color = color))
  
  output$rel_tot_plot <- renderPlotly({
    df_rel <- rel_price_data(); req(!is.null(df_rel))
    tryCatch({
      # Identify relative_price column (bid / estimate)
      rp_col <- if ("relative_price" %in% names(df_rel)) "relative_price" else NULL
      if (is.null(rp_col))
        return(ggplotly(plot_relative_price_density(df_rel), tooltip="text") %>%
                 layout(font=list(size=11), hoverlabel=list(bgcolor="white")) %>% pa_config())
      
      rp <- df_rel[[rp_col]]
      rp <- rp[!is.na(rp) & is.finite(rp) & rp > 0]
      n_total <- length(rp)
      req(n_total > 0)
      
      # Strict 3-way partition — every contract counted exactly once
      n_under <- sum(rp <  0.999)
      n_at    <- sum(rp >= 0.999 & rp <= 1.001)
      n_over  <- sum(rp >  1.001)
      # sanity: n_under + n_at + n_over == n_total by construction
      pct_under <- round(n_under / n_total * 100, 1)
      pct_at    <- round(n_at    / n_total * 100, 1)
      pct_over  <- round(n_over  / n_total * 100, 1)
      # Adjust rounding so they always sum to exactly 100
      diff <- 100 - (pct_under + pct_at + pct_over)
      pct_over <- pct_over + diff   # absorb rounding remainder into largest group
      
      med_rp  <- median(rp)
      x_range <- quantile(rp, c(0.005, 0.995))
      
      # Density for the plot
      dens <- density(rp, from=max(0, x_range[1]), to=x_range[2], n=512)
      df_dens <- data.frame(x=dens$x, y=dens$y)
      
      summary_txt <- paste0(
        "<b>Under budget</b> (< 1.0): <b>", pct_under, "%</b> (", formatC(n_under, big.mark=",", format="d"), " contracts)<br>",
        "<b>At budget</b> (≈1.0): <b>", pct_at, "%</b> (", formatC(n_at, big.mark=",", format="d"), ")<br>",
        "<b>Over budget</b> (> 1.0): <b>", pct_over, "%</b> (", formatC(n_over, big.mark=",", format="d"), ")<br>",
        "Total: ", formatC(n_total, big.mark=",", format="d"), " contracts | Median: ", round(med_rp, 3)
      )
      
      plot_ly() %>%
        # Under-budget fill (blue)
        add_trace(data=df_dens %>% filter(x <= 1),
                  x=~x, y=~y, type="scatter", mode="none",
                  fill="tozeroy", fillcolor="rgba(0,105,180,0.25)",
                  name="Under budget", hoverinfo="skip") %>%
        # Over-budget fill (red)
        add_trace(data=df_dens %>% filter(x >= 1),
                  x=~x, y=~y, type="scatter", mode="none",
                  fill="tozeroy", fillcolor="rgba(180,0,0,0.20)",
                  name="Over budget", hoverinfo="skip") %>%
        # Full density line
        add_trace(data=df_dens, x=~x, y=~y,
                  type="scatter", mode="lines",
                  line=list(color="#334155", width=2),
                  name="Density",
                  hoverinfo="text",
                  text=summary_txt) %>%
        layout(
          font       = list(size=11),
          hoverlabel = list(bgcolor="white", font=list(size=11)),
          hovermode  = "x unified",
          xaxis = list(title="Relative price (contract ÷ estimate)",
                       zeroline=FALSE, tickfont=list(size=13)),
          yaxis = list(title="Density", tickfont=list(size=13), zeroline=FALSE),
          shapes = list(
            # Budget line at 1.0
            list(type="line", x0=1, x1=1, y0=0, y1=1, yref="paper",
                 line=list(color="#888", width=1.5, dash="dash")),
            # Median line
            list(type="line", x0=med_rp, x1=med_rp, y0=0, y1=1, yref="paper",
                 line=list(color="#D97706", width=1.5, dash="dot"))
          ),
          annotations = list(
            list(x=med_rp, y=0.88, yref="paper", xanchor="left", yanchor="top",
                 text=paste0(" median (", round(med_rp,3), ")"), showarrow=FALSE,
                 font=list(size=10, color="#D97706")),
            list(x=(x_range[1]+1)/2, y=0.5, yref="paper", xanchor="center",
                 text=paste0("<b>", pct_under, "%</b><br>under budget"),
                 showarrow=FALSE, font=list(size=11, color="#0069B4")),
            list(x=1.02, y=0.5, yref="paper", xanchor="left", yanchor="center",
                 text=paste0("<b>", pct_at, "%</b><br>at budget"),
                 showarrow=FALSE, font=list(size=11, color="#475569")),
            list(x=(1+x_range[2])/2, y=0.5, yref="paper", xanchor="center",
                 text=paste0("<b>", pct_over, "%</b><br>over budget"),
                 showarrow=FALSE, font=list(size=11, color="#B40000"))
          ),
          legend = list(orientation="h", y=-0.15, font=list(size=10)),
          margin = list(l=60, r=20, t=20, b=60),
          paper_bgcolor="#ffffff", plot_bgcolor="#ffffff"
        ) %>%
        pa_config()
    }, error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$rel_year_plot <- renderPlotly({
    df_rel <- rel_price_data(); req(!is.null(df_rel))
    tryCatch(
      ggplotly(plot_relative_price_by_year(df_rel), tooltip = "text") %>%
        layout(font=list(size=11), hoverlabel = list(bgcolor = "white"), hovermode = "closest",
               legend = list(orientation = "h", y = -0.12, font=list(size=10))) %>%
        pa_config(),
      error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  # markets plot: dynamic height based on number of CPV categories
  output$rel_10_plot_ui <- renderUI({
    df_rel <- rel_price_data()
    n_mkts <- if (!is.null(df_rel) && "cpv_category" %in% names(df_rel))
      dplyr::n_distinct(df_rel$cpv_category, na.rm = TRUE) else 10
    h <- paste0(max(380, min(750, n_mkts * 30 + 100)), "px")
    plotlyOutput("rel_10_plot", height = h)
  })
  
  output$rel_10_plot <- renderPlotly({
    df_rel <- rel_price_data(); req(!is.null(df_rel))
    tryCatch({
      # Replace cpv_category with the full "XX — Name" label used in the filters
      # so the y-axis matches what the user sees in the Market dropdown.
      if ("cpv_cluster" %in% names(df_rel))
        df_rel <- df_rel %>%
          dplyr::mutate(cpv_category = get_cpv_label(cpv_cluster))
      top_mkts <- top_markets_by_relative_price(df_rel)
      ggplotly(plot_top_markets_relative_price(df_rel, top_mkts),
               tooltip = "text") %>%
        layout(font=list(size=11), hoverlabel = list(bgcolor = "white"), hovermode = "closest",
               margin = list(l=220, r=20, t=70, b=40),
               legend = list(orientation = "h", y = 1.06, x = 0.5, xanchor = "center", yanchor = "bottom",
                             font = list(size = 11))) %>%
        pa_config()
    }, error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$rel_buy_plot_ui <- renderUI({
    top_n <- as.integer(input$rel_buy_top_n %||% 20)
    h     <- paste0(max(300, min(500, top_n * 18 + 80)), "px")
    plotlyOutput("rel_buy_plot", height = h)
  })
  
  output$rel_buy_plot <- renderPlotly({
    df_rel <- rel_price_data(); req(!is.null(df_rel))
    top_n         <- as.integer(input$rel_buy_top_n        %||% 20)
    min_contracts <- as.integer(input$rel_buy_min_contracts %||% 10)
    tryCatch({
      top_buy <- top_buyers_by_relative_price(df_rel, min_contracts = min_contracts, n = top_n)
      if (nrow(top_buy) == 0)
        return(.empty_plotly(paste0("No buyers found with \u2265 ", min_contracts, " contracts")))
      # Pass detected local currency label so hover doesn't show hardcoded $
      loc_lbl <- (econ$local_currency %||% list(label="NC"))$label
      p_buy <- ggplotly(plot_top_buyers_relative_price(top_buy, label_max_chars = 30,
                                                       currency_label = loc_lbl),
                        tooltip = "text") %>%
        layout(font=list(size=11), hoverlabel = list(bgcolor = "white"), hovermode = "closest",
               legend = list(orientation = "v", x = 1.02, y = 0.5, font = list(size = 10)))
      # Hide any vline/dashed-line traces from the legend
      dash_traces <- which(sapply(p_buy$x$data, function(t)
        !is.null(t$line) && isTRUE(t$line$dash %in% c("dash","dashdot","dot"))))
      if (length(dash_traces) > 0) p_buy <- plotly::style(p_buy, showlegend = FALSE, traces = dash_traces)
      econ$fig_rel_buy <- p_buy %>% pa_config(); econ$fig_rel_buy
    }, error = function(e) .empty_plotly(paste("Error:", e$message), "red"))
  })
  
  
  # [APP-SV17] COMPETITION OUTPUTS (single-bid charts) ───────────────────────
  # ============================================================
  # COMPETITION OUTPUTS
  # ============================================================
  
  .comp_plotly <- function(p) {
    ggplotly(p, tooltip = "text") %>%
      layout(hoverlabel = list(bgcolor = "white"), hovermode = "closest",
             autosize = TRUE)
  }
  
  output$single_bid_overall_plot <- renderPlotly({
    req(econ$filtered_data)
    df      <- econ$filtered_data
    metric  <- input$sb_overall_metric %||% "rate"
    tryCatch({
      if (identical(metric, "distribution")) {
        # Distribution mode: share of ALL single-bid contracts that fall in each year
        d <- df %>%
          dplyr::filter(!is.na(single_bid), !is.na(tender_year)) %>%
          dplyr::group_by(tender_year) %>%
          dplyr::summarise(
            n_contracts  = dplyr::n(),
            n_single_bid = sum(single_bid, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          dplyr::mutate(
            total_sb     = sum(n_single_bid),
            share_sb     = n_single_bid / pmax(total_sb, 1),
            n_years      = dplyr::n(),
            equal_share  = 1 / n_years,
            # pre-compute colour as a plain character vector — plotly requires this,
            # formula notation (~) inside marker$color is NOT evaluated
            bar_col      = ifelse(share_sb >= (1 / n_years), PA_LONG, PA_NORMAL),
            hover_txt    = paste0(
              "Year: <b>", tender_year, "</b><br>",
              "Share of all single bids: <b>", scales::percent(share_sb, accuracy = 0.1), "</b><br>",
              "Single-bid contracts: ", scales::comma(round(n_single_bid)), "<br>",
              "Total contracts: ", scales::comma(n_contracts), "<br>",
              "Average per year: ", scales::percent(1 / n_years, accuracy = 0.1)
            )
          )
        eq_share <- 1 / nrow(d)   # scalar for the reference shape
        # Label the dashed line via y-axis tick or a subtitle annotation
        eq_pct_label <- scales::percent(eq_share, accuracy = 0.1)
        plotly::plot_ly(d, x = ~tender_year) %>%
          plotly::add_bars(
            y            = ~share_sb,
            marker       = list(color = d$bar_col,
                                line  = list(color = "white", width = 0.4)),
            text         = ~hover_txt,
            hoverinfo    = "text",
            textposition = "none",            # suppress on-bar labels; hover only
            showlegend   = FALSE
          ) %>%
          plotly::layout(
            xaxis  = list(title = NULL, dtick = 1, tickformat = "d",
                          tickfont = list(size = 12)),
            yaxis  = list(title = "Share of all single-bid contracts",
                          tickformat = ".1%", tickfont = list(size = 12)),
            bargap = 0.3,
            # extra right margin so the dashed-line label fits inside the panel
            margin = list(l = 60, r = 100, t = 30, b = 40),
            shapes = list(list(
              type = "line", x0 = 0, x1 = 1, xref = "paper",
              y0 = eq_share, y1 = eq_share, yref = "y",
              line = list(color = "#777777", width = 1.2, dash = "dash")
            )),
            annotations = list(list(
              # Place label just inside the right edge of the plot area
              x = 0.98, xref = "paper",
              y = eq_share, yref = "y",
              text = paste0("avg (", eq_pct_label, ")"),
              xanchor = "right", yanchor = "bottom", showarrow = FALSE,
              font = list(size = 10, color = "#666666"),
              bgcolor = "rgba(255,255,255,0.7)", borderpad = 2
            ))
          ) %>% pa_config()
      } else {
        .comp_plotly(plot_single_bid_overall(df)) %>% pa_config()
      }
    }, error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$single_bid_procedure_plot <- renderPlotly({
    req(econ$filtered_data)
    tryCatch(.comp_plotly(plot_single_bid_by_procedure(econ$filtered_data)),
             error = function(e) .empty_plotly(paste("Not available:", e$message))) %>%
      pa_config()
  })
  
  output$single_bid_price_plot <- renderPlotly({
    req(econ$filtered_data)
    df     <- econ$filtered_data
    metric <- input$sb_price_metric %||% "rate"
    tryCatch({
      if (identical(metric, "distribution")) {
        # Distribution mode: share of ALL single-bid contracts in each value band
        if (!"price_bin" %in% names(df))
          return(.empty_plotly("No contract value data available for this view."))
        d <- df %>%
          dplyr::filter(!is.na(single_bid), !is.na(price_bin)) %>%
          dplyr::group_by(price_bin) %>%
          dplyr::summarise(
            n_contracts  = dplyr::n(),
            n_single_bid = sum(single_bid, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          dplyr::mutate(
            total_sb  = sum(n_single_bid),
            share_sb  = n_single_bid / pmax(total_sb, 1),
            # pre-compute colour as plain character vector — required by plotly marker$color
            bar_col   = ifelse(share_sb == max(share_sb, na.rm = TRUE), PA_LONG, PA_NORMAL),
            hover_txt = paste0(
              "Band: <b>", price_bin, "</b><br>",
              "Share of all single bids: <b>", scales::percent(share_sb, accuracy = 0.1), "</b><br>",
              "Single-bid contracts: ", scales::comma(round(n_single_bid)), "<br>",
              "Total contracts: ", scales::comma(n_contracts)
            )
          )
        if (nrow(d) == 0)
          return(.empty_plotly("No data in value bands."))
        eq_share <- 1 / nrow(d)
        eq_pct_label <- scales::percent(eq_share, accuracy = 0.1)
        plotly::plot_ly(d, x = ~price_bin) %>%
          plotly::add_bars(
            y            = ~share_sb,
            marker       = list(color = d$bar_col,
                                line  = list(color = "white", width = 0.4)),
            text         = ~hover_txt,
            hoverinfo    = "text",
            textposition = "none",            # suppress on-bar labels; hover only
            showlegend   = FALSE
          ) %>%
          plotly::layout(
            xaxis  = list(title = "Contract value band", tickangle = -35,
                          tickfont = list(size = 12)),
            yaxis  = list(title = "Share of all single-bid contracts",
                          tickformat = ".1%", tickfont = list(size = 12)),
            bargap = 0.25,
            margin = list(l = 60, r = 100, t = 30, b = 80),
            shapes = list(list(
              type = "line", x0 = 0, x1 = 1, xref = "paper",
              y0 = eq_share, y1 = eq_share, yref = "y",
              line = list(color = "#777777", width = 1.2, dash = "dash")
            )),
            annotations = list(list(
              x = 0.98, xref = "paper",
              y = eq_share, yref = "y",
              text = paste0("avg (", eq_pct_label, ")"),
              xanchor = "right", yanchor = "bottom", showarrow = FALSE,
              font = list(size = 10, color = "#666666"),
              bgcolor = "rgba(255,255,255,0.7)", borderpad = 2
            ))
          ) %>% pa_config()
      } else {
        .comp_plotly(plot_single_bid_by_price(df)) %>% pa_config()
      }
    }, error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$single_bid_buyer_group_plot <- renderPlotly({
    req(econ$filtered_data)
    tryCatch(.comp_plotly(plot_single_bid_by_buyer_group(econ$filtered_data)),
             error = function(e) .empty_plotly(paste("Not available:", e$message))) %>%
      pa_config()
  })
  
  output$single_bid_market_plot_ui <- renderUI({
    df <- econ$filtered_data
    n_mkts <- if (!is.null(df)) {
      lbl <- if ("cpv_category" %in% names(df) && !all(is.na(df$cpv_category)))
        "cpv_category" else "cpv_cluster"
      dplyr::n_distinct(df[[lbl]], na.rm = TRUE)
    } else 10
    plotlyOutput("single_bid_market_plot", height = paste0(max(300, min(700, n_mkts * 24 + 100)), "px"))
  })
  
  output$single_bid_market_plot <- renderPlotly({
    req(econ$filtered_data)
    tryCatch(
      ggplotly(plot_single_bid_by_market(econ$filtered_data), tooltip = "text") %>%
        layout(hoverlabel = list(bgcolor = "white"), hovermode = "closest",
               font = list(size = 11),
               margin = list(l = 10, r = 20, t = 20, b = 40),
               autosize = TRUE) %>%
        pa_config(),
      error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$top_buyers_single_bid_plot_ui <- renderUI({
    top_n <- as.integer(input$sb_buy_top_n %||% 20)
    plotlyOutput("top_buyers_single_bid_plot", height = paste0(max(400, top_n * 28), "px"))
  })
  
  output$top_buyers_single_bid_plot <- renderPlotly({
    req(econ$filtered_data)
    top_n       <- as.integer(input$sb_buy_top_n       %||% 20)
    min_tenders <- as.integer(input$sb_buy_min_tenders %||% 30)
    # Auto-detect the buyer ID column (masterid → id → name)
    buyer_col <- intersect(c("buyer_masterid", "buyer_id", "buyer_name"),
                           names(econ$filtered_data))[1]
    if (is.na(buyer_col)) buyer_col <- NULL
    tryCatch(
      .comp_plotly(plot_top_buyers_single_bid(econ$filtered_data,
                                              buyer_id_col = buyer_col,
                                              top_n        = top_n,
                                              min_tenders  = min_tenders)) %>%
        pa_config(),
      error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  
  # [APP-SV18] ECON FIGURE DOWNLOAD HANDLERS (fresh render via webshot2) ─────
  # ============================================================
  # ECON FIGURE DOWNLOAD HANDLERS
  # All downloads now render fresh from current filtered data
  # (same as what's displayed) via webshot2.
  # ============================================================
  
  # Helper: render a fresh plotly from filtered econ data and save via webshot2
  dl_econ_plotly <- function(make_fig, fname, vw = 1200, vh = 700) {
    downloadHandler(
      filename = function() paste0(fname, "_", econ$country_code %||% "export",
                                   "_", format(Sys.Date(), "%Y%m%d"), ".png"),
      content  = function(file) {
        fig <- tryCatch(make_fig(), error = function(e) NULL)
        .require_fig(fig, fname)
        .save_fig_png(fig, file, vw, vh)
      }
    )
  }
  
  # Overview charts — use stored figs (always match what's displayed)
  output$dl_contracts_year_econ <- downloadHandler(
    filename = function() paste0("contracts_per_year_", econ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      fig <- tryCatch(econ$fig_contracts_year_econ, error = function(e) NULL)
      .require_fig(fig, "Contracts per Year")
      .save_fig_png(fig, file)
    }
  )
  output$dl_value_by_year <- downloadHandler(
    filename = function() paste0("contract_value_by_year_", econ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      fig <- tryCatch(econ$fig_value_by_year, error = function(e) NULL)
      .require_fig(fig, "Contract Value by Year")
      .save_fig_png(fig, file)
    }
  )
  
  # Market sizing — re-computed live from filtered data
  output$dl_overview_top_buyers    <- dl_econ_plotly(function() econ$fig_ov_top_buyers,
                                                     "top_buyers",    1200, 700)
  output$dl_overview_top_suppliers <- dl_econ_plotly(function() econ$fig_ov_top_suppliers,
                                                     "top_suppliers", 1200, 700)
  output$dl_market_size_n <- dl_econ_plotly(function() {
    df <- econ$filtered_data; req(!is.null(df))
    if (!"cpv_cluster" %in% names(df)) req(FALSE)
    df %>% dplyr::filter(!is.na(cpv_cluster)) %>%
      dplyr::mutate(cpv_label = get_cpv_label(cpv_cluster)) %>%
      dplyr::group_by(cpv_label) %>%
      dplyr::summarise(n_contracts = dplyr::n(), .groups = "drop") %>%
      dplyr::arrange(dplyr::desc(n_contracts)) %>% dplyr::slice_head(n = 30) %>%
      dplyr::mutate(
        label_short = ifelse(nchar(cpv_label) > 35, paste0(substr(cpv_label,1,33),"\u2026"), cpv_label),
        label_short = factor(label_short, levels = label_short[order(n_contracts)])
      ) %>%
      { ggplotly(
        ggplot2::ggplot(., ggplot2::aes(x=label_short, y=n_contracts,
                                        text=paste0("<b>",cpv_label,"</b><br>Contracts: ",
                                                    formatC(n_contracts,format="d",big.mark=",")))) +
          ggplot2::geom_col(fill=PA_NORMAL) + ggplot2::coord_flip() +
          ggplot2::scale_y_continuous(labels=scales::comma) +
          ggplot2::labs(x=NULL, y="Number of contracts") + pa_theme(),
        tooltip="text")
      } %>% pa_config()
  }, "market_size_n", 1200, 800)
  
  output$dl_market_size_v <- dl_econ_plotly(function() {
    df <- econ$filtered_data; req(!is.null(df))
    price_var <- detect_price_col(df); req(!is.null(price_var))
    .loc_dl <- (econ$local_currency %||% list(label="NC"))$label
    df %>% dplyr::filter(!is.na(cpv_cluster), !is.na(.data[[price_var]]), .data[[price_var]]>0) %>%
      dplyr::mutate(cpv_label = get_cpv_label(cpv_cluster)) %>%
      dplyr::group_by(cpv_label) %>%
      dplyr::summarise(total_value=sum(.data[[price_var]],na.rm=TRUE), .groups="drop") %>%
      dplyr::arrange(dplyr::desc(total_value)) %>% dplyr::slice_head(n=30) %>%
      dplyr::mutate(
        label_short = ifelse(nchar(cpv_label)>35, paste0(substr(cpv_label,1,33),"\u2026"), cpv_label),
        label_short = factor(label_short, levels=label_short[order(total_value)])
      ) %>%
      { ggplotly(
        ggplot2::ggplot(., ggplot2::aes(x=label_short, y=total_value,
                                        text=paste0("<b>",cpv_label,"</b>"))) +
          ggplot2::geom_col(fill=PA_TEAL) + ggplot2::coord_flip() +
          ggplot2::scale_y_continuous(labels=scales::label_number(scale_cut=scales::cut_short_scale(),
                                                                  accuracy=0.1)) +
          ggplot2::labs(x=NULL, y=paste0("Total contract value (", .loc_dl, ")")) + pa_theme(),
        tooltip="text")
      } %>% pa_config()
  }, "market_size_v", 1200, 800)
  
  output$dl_market_size_av <- dl_econ_plotly(function() {
    req(!is.null(econ$filtered_data))
    df <- econ$filtered_data
    price_var <- detect_price_col(df); req(!is.null(price_var))
    .loc_av2 <- (econ$local_currency %||% list(label="NC"))$label
    .pfx_av2 <- if (.loc_av2 == "USD") "$" else ""
    ms <- df %>%
      dplyr::filter(!is.na(cpv_cluster)) %>%
      dplyr::mutate(cpv_label = get_cpv_label(cpv_cluster)) %>%
      dplyr::group_by(cpv_cluster, cpv_label) %>%
      dplyr::summarise(n_contracts=dplyr::n(),
                       total_value=sum(.data[[price_var]],na.rm=TRUE),
                       avg_value=mean(.data[[price_var]],na.rm=TRUE), .groups="drop") %>%
      dplyr::filter(n_contracts>0, avg_value>0, total_value>0) %>%
      dplyr::mutate(
        bubble_size = scales::rescale(sqrt(total_value), to=c(8,50)),
        log_avg     = log10(avg_value+1),
        hover_text  = paste0("<b>",cpv_label,"</b><br>",
                             "Contracts: <b>",scales::comma(n_contracts),"</b><br>",
                             "Avg contract value: <b>",
                             .pfx_av2,scales::number(avg_value,scale_cut=scales::cut_short_scale(),accuracy=0.1),
                             if(.pfx_av2=="") paste0(" ",.loc_av2) else "","</b><br>",
                             "Total market value: <b>",
                             .pfx_av2,scales::number(total_value,scale_cut=scales::cut_short_scale(),accuracy=0.1),
                             if(.pfx_av2=="") paste0(" ",.loc_av2) else "","</b>")
      )
    req(nrow(ms) > 0)
    make_log_ticks <- function(vals, prefix="") {
      pows <- seq(floor(log10(min(vals,na.rm=TRUE))), ceiling(log10(max(vals,na.rm=TRUE))))
      tv <- 10^pows
      fmt <- function(v) dplyr::case_when(
        v>=1e9~paste0(prefix,scales::comma(v/1e9),"B"), v>=1e6~paste0(prefix,scales::comma(v/1e6),"M"),
        v>=1e3~paste0(prefix,scales::comma(v/1e3),"K"), TRUE~paste0(prefix,scales::comma(v)))
      list(tickvals=tv, ticktext=fmt(tv))
    }
    xt <- make_log_ticks(ms$n_contracts); yt <- make_log_ticks(ms$avg_value, prefix="$")
    plotly::plot_ly(ms, x=~n_contracts, y=~avg_value, text=~hover_text, hoverinfo="text",
                    type="scatter", mode="markers",
                    marker=list(size=~bubble_size, sizemode="diameter",
                                color=~log_avg,
                                colorscale=list(c(0,"#c6dbef"),c(0.5,"#4292c6"),c(1,"#08306b")),
                                showscale=TRUE,
                                colorbar=list(title="Avg value<br>(log₁₀ USD)", tickformat=".1f"),
                                opacity=0.85, line=list(color="white",width=1))) %>%
      plotly::layout(
        xaxis=list(title="Number of contracts (log scale)",type="log",
                   tickvals=xt$tickvals, ticktext=xt$ticktext, tickangle=-35, zeroline=FALSE, gridcolor="#eeeeee"),
        yaxis=list(title="Average contract value (log scale)",type="log",
                   tickvals=yt$tickvals, ticktext=yt$ticktext, zeroline=FALSE, gridcolor="#eeeeee"),
        margin=list(l=90,r=60,t=60,b=90),
        hoverlabel=list(bgcolor="white",font=list(size=12)), hovermode="closest", showlegend=FALSE) %>%
      pa_config()
  }, "market_size_av", 1200, 700)
  
  # Relative price plots — re-built from live rel_price_data()
  rel_price_dl_fig <- function(plot_fn, ...) {
    df_rel <- tryCatch(rel_price_data(), error=function(e) NULL)
    req(!is.null(df_rel))
    ggplotly(plot_fn(df_rel, ...), tooltip="text") %>%
      plotly::layout(hoverlabel=list(bgcolor="white")) %>% pa_config()
  }
  output$dl_rel_tot <- dl_econ_plotly(function() {
    # Reproduce the custom density plot that's shown on screen (not the util function)
    df_rel <- tryCatch(rel_price_data(), error=function(e) NULL); req(!is.null(df_rel))
    rp_col <- if ("relative_price" %in% names(df_rel)) "relative_price" else NULL
    req(!is.null(rp_col))
    rp      <- df_rel[[rp_col]]; rp <- rp[!is.na(rp) & is.finite(rp) & rp > 0]
    n_total <- length(rp); req(n_total > 0)
    n_under <- sum(rp <  0.999); n_at <- sum(rp >= 0.999 & rp <= 1.001); n_over <- sum(rp > 1.001)
    pct_under <- round(n_under/n_total*100,1); pct_at <- round(n_at/n_total*100,1)
    pct_over  <- round(n_over/n_total*100,1) + (100-(round(n_under/n_total*100,1)+round(n_at/n_total*100,1)+round(n_over/n_total*100,1)))
    med_rp  <- median(rp); x_range <- quantile(rp, c(0.005, 0.995))
    dens    <- density(rp, from=max(0,x_range[1]), to=x_range[2], n=512)
    df_dens <- data.frame(x=dens$x, y=dens$y)
    summary_txt <- paste0(
      "<b>Under budget</b> (< 1.0): <b>",pct_under,"%</b> (",formatC(n_under,big.mark=",",format="d")," contracts)<br>",
      "<b>At budget</b> (≈1.0): <b>",pct_at,"%</b> (",formatC(n_at,big.mark=",",format="d"),")<br>",
      "<b>Over budget</b> (> 1.0): <b>",pct_over,"%</b> (",formatC(n_over,big.mark=",",format="d"),")<br>",
      "Total: ",formatC(n_total,big.mark=",",format="d")," contracts | Median: ",round(med_rp,3))
    plot_ly() %>%
      add_trace(data=df_dens%>%filter(x<=1),x=~x,y=~y,type="scatter",mode="none",fill="tozeroy",fillcolor="rgba(0,105,180,0.25)",name="Under budget",hoverinfo="skip") %>%
      add_trace(data=df_dens%>%filter(x>=1),x=~x,y=~y,type="scatter",mode="none",fill="tozeroy",fillcolor="rgba(180,0,0,0.20)",name="Over budget",hoverinfo="skip") %>%
      add_trace(data=df_dens,x=~x,y=~y,type="scatter",mode="lines",line=list(color="#334155",width=2),name="Density",hoverinfo="text",text=summary_txt) %>%
      plotly::layout(
        font=list(size=11), hoverlabel=list(bgcolor="white",font=list(size=11)), hovermode="x unified",
        xaxis=list(title="Relative price (contract ÷ estimate)",zeroline=FALSE,tickfont=list(size=13)),
        yaxis=list(title="Density",tickfont=list(size=13),zeroline=FALSE),
        shapes=list(
          list(type="line",x0=1,x1=1,y0=0,y1=1,yref="paper",line=list(color="#888",width=1.5,dash="dash")),
          list(type="line",x0=med_rp,x1=med_rp,y0=0,y1=1,yref="paper",line=list(color="#D97706",width=1.5,dash="dot"))),
        annotations=list(
          list(x=med_rp,y=0.88,yref="paper",xanchor="left",yanchor="top",text=paste0(" median (",round(med_rp,3),")"),showarrow=FALSE,font=list(size=10,color="#D97706")),
          list(x=(x_range[1]+1)/2,y=0.5,yref="paper",xanchor="center",text=paste0("<b>",pct_under,"%</b><br>under budget"),showarrow=FALSE,font=list(size=11,color="#0069B4")),
          list(x=1.02,y=0.5,yref="paper",xanchor="left",yanchor="center",text=paste0("<b>",pct_at,"%</b><br>at budget"),showarrow=FALSE,font=list(size=11,color="#475569")),
          list(x=(1+x_range[2])/2,y=0.5,yref="paper",xanchor="center",text=paste0("<b>",pct_over,"%</b><br>over budget"),showarrow=FALSE,font=list(size=11,color="#B40000"))),
        legend=list(orientation="h",y=-0.15,font=list(size=10)),
        margin=list(l=60,r=20,t=20,b=60), paper_bgcolor="#ffffff", plot_bgcolor="#ffffff") %>%
      pa_config()
  }, "rel_tot", 1200, 700)
  output$dl_rel_year <- dl_econ_plotly(function() rel_price_dl_fig(plot_relative_price_by_year),  "rel_year", 1200, 700)
  output$dl_rel_10   <- dl_econ_plotly(function() {
    df_rel <- tryCatch(rel_price_data(), error=function(e) NULL); req(!is.null(df_rel))
    if ("cpv_cluster" %in% names(df_rel))
      df_rel <- df_rel %>% dplyr::mutate(cpv_category = get_cpv_label(cpv_cluster))
    top_mkts <- top_markets_by_relative_price(df_rel)
    ggplotly(plot_top_markets_relative_price(df_rel, top_mkts), tooltip="text") %>%
      plotly::layout(hoverlabel=list(bgcolor="white"), margin=list(l=220,r=20,t=70,b=40)) %>%
      pa_config()
  }, "rel_10", 1200, 800)
  output$dl_rel_buy  <- dl_econ_plotly(function() {
    df_rel <- tryCatch(rel_price_data(), error=function(e) NULL); req(!is.null(df_rel))
    top_n         <- as.integer(input$rel_buy_top_n %||% 20)
    min_contracts <- as.integer(input$rel_buy_min_contracts %||% 10)
    top_buy <- top_buyers_by_relative_price(df_rel, min_contracts=min_contracts, n=top_n)
    req(nrow(top_buy) > 0)
    ggplotly(plot_top_buyers_relative_price(top_buy, label_max_chars=30), tooltip="text") %>%
      plotly::layout(hoverlabel=list(bgcolor="white")) %>% pa_config()
  }, "rel_buy", 1200, 800)
  
  output$rel_size_plot <- renderPlotly({
    df_rel <- rel_price_data(); req(!is.null(df_rel))
    tryCatch({
      rp_col    <- if ("relative_price" %in% names(df_rel)) "relative_price" else NULL
      price_col <- detect_price_col(df_rel, .PRICE_COLS_SUPP)
      req(!is.null(rp_col), !is.null(price_col))
      
      d <- df_rel %>%
        dplyr::filter(!is.na(.data[[rp_col]]), is.finite(.data[[rp_col]]),
                      .data[[rp_col]] > 0, .data[[rp_col]] < 10,
                      !is.na(.data[[price_col]]), .data[[price_col]] > 0) %>%
        dplyr::mutate(rp = .data[[rp_col]], val = .data[[price_col]])
      req(nrow(d) >= 20)
      
      # Band assignment — prefer existing price_bin, else fixed USD breaks
      if ("price_bin" %in% names(d) && dplyr::n_distinct(d$price_bin, na.rm = TRUE) > 1) {
        d <- d %>% dplyr::filter(!is.na(price_bin))
        d$band_lbl <- as.character(d$price_bin)
        band_order <- levels(d$price_bin) %||% sort(unique(d$band_lbl))
      } else {
        breaks_usd <- c(0, 5e3, 1e4, 5e4, 1e5, 5e5, 1e6, Inf)
        labels_usd <- c("< $5K", "$5K–$10K", "$10K–$50K",
                        "$50K–$100K", "$100K–$500K", "$500K–$1M", "> $1M")
        d$band_lbl <- labels_usd[
          findInterval(d$val, breaks_usd, rightmost.closed = TRUE)
        ]
        band_order <- labels_usd
      }
      d$band_lbl <- factor(d$band_lbl, levels = intersect(band_order, unique(d$band_lbl)))
      req(!all(is.na(d$band_lbl)))
      
      # Per-band summary
      summ <- d %>%
        dplyr::group_by(band_lbl) %>%
        dplyr::summarise(
          n        = dplyr::n(),
          pct_over = round(mean(rp > 1.001) * 100, 1),
          med_rp   = median(rp),
          q25      = quantile(rp, 0.25),
          q75      = quantile(rp, 0.75),
          p10      = quantile(rp, 0.10),
          p90      = quantile(rp, 0.90),
          .groups  = "drop"
        ) %>%
        dplyr::mutate(
          over     = med_rp > 1.001,
          bar_col  = dplyr::case_when(
            med_rp > 1.10  ~ "#DC2626",   # clearly over budget — red
            med_rp > 1.001 ~ "#D97706",   # slightly over — amber
            TRUE           ~ "#00897B"    # at or under — teal
          ),
          tip = paste0(
            "<b>", band_lbl, "</b><br>",
            "Contracts: <b>", scales::comma(n), "</b><br>",
            "Median relative price: <b>", round(med_rp, 3), "</b><br>",
            "% over budget: <b>", pct_over, "%</b><br>",
            "IQR: [", round(q25, 3), " – ", round(q75, 3), "]<br>",
            "P10–P90: [", round(p10, 3), " – ", round(p90, 3), "]"
          )
        )
      
      nb <- nrow(summ)
      bar_w <- 0.55   # fractional width for the IQR box
      
      fig <- plot_ly(hoverinfo = "text")
      
      # P10–P90 thin whisker
      fig <- fig %>%
        add_segments(
          data  = summ,
          x     = ~as.integer(band_lbl),        xend = ~as.integer(band_lbl),
          y     = ~p10,                          yend = ~p90,
          line  = list(color = "#CBD5E1", width = 2),
          hoverinfo = "skip", showlegend = FALSE
        )
      
      # IQR filled bar (geom_col aesthetic)
      for (i in seq_len(nb)) {
        r <- summ[i, ]
        fig <- fig %>%
          add_trace(
            type   = "scatter", mode = "none",
            x      = c(i - bar_w/2, i - bar_w/2, i + bar_w/2, i + bar_w/2, i - bar_w/2),
            y      = c(r$q25, r$q75, r$q75, r$q25, r$q25),
            fill   = "toself",
            fillcolor = r$bar_col,
            line   = list(color = "white", width = 0.5),
            opacity    = 0.82,
            text       = r$tip, hoverinfo = "text",
            showlegend = FALSE
          )
      }
      
      # Invisible full-column hover catchers. The IQR boxes are fill-only
      # (mode = "none") polygon traces, and plotly does not reliably trigger
      # hover on fill areas — hence "hover shows nothing". A transparent bar
      # spanning each column carries the tooltip instead.
      y_top <- max(c(summ$p90, 1.05), na.rm = TRUE) * 1.12
      fig <- fig %>%
        add_bars(
          data = summ, x = ~as.integer(band_lbl), y = y_top,
          width = 0.9, marker = list(color = "rgba(0,0,0,0)"),
          # hovertext (NOT text): for bar traces `text` is PRINTED on the
          # bars by default; hovertext only ever appears in the tooltip.
          hovertext = ~tip, hoverinfo = "text", textposition = "none",
          showlegend = FALSE
        )
      
      # Median tick line across the bar
      fig <- fig %>%
        add_segments(
          data  = summ,
          x     = ~as.integer(band_lbl) - bar_w/2,
          xend  = ~as.integer(band_lbl) + bar_w/2,
          y     = ~med_rp, yend = ~med_rp,
          line  = list(color = "white", width = 2.5),
          hoverinfo = "skip", showlegend = FALSE
        )
      
      # % over-budget label above each bar — use loop to avoid ~ column ref in font colour
      for (i in seq_len(nb)) {
        r <- summ[i, ]
        fig <- fig %>%
          add_annotations(
            x         = as.integer(r$band_lbl),
            y         = r$p90,
            text      = paste0(r$pct_over, "%"),
            showarrow = FALSE,
            yanchor   = "bottom",
            font      = list(size = 10, color = r$bar_col),
            yshift    = 4
          )
      }
      
      # Budget line at 1.0
      fig <- fig %>%
        plotly::layout(
          shapes = list(list(
            type  = "line", x0 = 0.4, x1 = nb + 0.6, xref = "x",
            y0    = 1, y1 = 1,
            line  = list(color = "#64748B", width = 1.5, dash = "dash")
          )),
          xaxis = list(
            title       = "Contract value band",
            tickvals    = seq_len(nb),
            ticktext    = as.character(summ$band_lbl),
            tickangle   = -30,
            tickfont    = list(size = 11),
            zeroline    = FALSE,
            showgrid    = FALSE,
            range       = c(0.4, nb + 0.6)
          ),
          yaxis = list(
            title    = "Relative price  (contract ÷ estimate)",
            tickfont = list(size = 13),
            zeroline = FALSE,
            gridcolor = "#F1F5F9"
          ),
          hoverlabel    = list(bgcolor = "white", font = list(size = 13)),
          hovermode     = "closest",
          margin        = list(l = 65, r = 20, t = 30, b = 90),
          paper_bgcolor = "#ffffff",
          plot_bgcolor  = "#ffffff"
        ) %>%
        pa_config()
      
      econ$fig_rel_size <- fig
      fig
    }, error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$dl_rel_size <- dl_econ_plotly(function() {
    df_rel <- tryCatch(rel_price_data(), error=function(e) NULL); req(!is.null(df_rel))
    tryCatch(econ$fig_rel_size, error=function(e) NULL) %||%
      .empty_plotly("View the chart first, then download.")
  }, "rel_size", 1200, 600)
  
  # Single-bid plots — re-built from live econ$filtered_data
  output$dl_single_bid_overall <- dl_econ_plotly(function() {
    req(econ$filtered_data)
    .comp_plotly(plot_single_bid_overall(econ$filtered_data)) %>% pa_config()
  }, "single_bid_overall", 900, 600)
  output$dl_single_bid_procedure <- dl_econ_plotly(function() {
    req(econ$filtered_data)
    .comp_plotly(plot_single_bid_by_procedure(econ$filtered_data)) %>% pa_config()
  }, "single_bid_procedure", 900, 600)
  output$dl_single_bid_price <- dl_econ_plotly(function() {
    req(econ$filtered_data)
    .comp_plotly(plot_single_bid_by_price(econ$filtered_data)) %>% pa_config()
  }, "single_bid_price", 900, 600)
  output$dl_single_bid_buyer_group <- dl_econ_plotly(function() {
    req(econ$filtered_data)
    .comp_plotly(plot_single_bid_by_buyer_group(econ$filtered_data)) %>% pa_config()
  }, "single_bid_buyer_group", 900, 600)
  output$dl_single_bid_market <- dl_econ_plotly(function() {
    req(econ$filtered_data)
    ggplotly(plot_single_bid_by_market(econ$filtered_data), tooltip="text") %>%
      plotly::layout(hoverlabel=list(bgcolor="white"), autosize=TRUE) %>% pa_config()
  }, "single_bid_market", 900, 700)
  output$dl_top_buyers_single_bid <- dl_econ_plotly(function() {
    req(econ$filtered_data)
    top_n       <- as.integer(input$sb_buy_top_n %||% 20)
    min_tenders <- as.integer(input$sb_buy_min_tenders %||% 30)
    buyer_col   <- intersect(c("buyer_masterid","buyer_id","buyer_name"),
                             names(econ$filtered_data))[1]
    if (is.na(buyer_col)) buyer_col <- NULL
    .comp_plotly(plot_top_buyers_single_bid(econ$filtered_data,
                                            buyer_id_col=buyer_col,
                                            top_n=top_n, min_tenders=min_tenders)) %>% pa_config()
  }, "top_buyers_single_bid", 900, 700)
  
  # Downloads the SUPPLIER ENTRY RATE BUBBLE CHART — same as displayed
  output$dl_top_suppliers <- downloadHandler(
    filename = function() paste0("top_suppliers_", econ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      fig <- tryCatch(econ$fig_top_suppliers, error = function(e) NULL)
      .require_fig(fig, "Top Suppliers")
      .save_fig_png(fig, file, 1200, 800)
    }
  )
  output$dl_supp_trend <- downloadHandler(
    filename = function() paste0("supplier_trend_", econ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      fig <- tryCatch(econ$fig_supp_trend, error = function(e) NULL)
      .require_fig(fig, "New vs Repeat Suppliers Trend")
      .save_fig_png(fig, file, 1400, 700)
    }
  )
  output$dl_suppliers_entrance <- downloadHandler(
    filename = function() paste0("supplier_entry_bubble_", econ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      fig <- tryCatch(econ$fig_supp_bubble, error = function(e) NULL)
      .require_fig(fig, "Supplier Entry Rate Bubble Chart")
      .save_fig_png(fig, file)
    }
  )
  
  # Downloads the MARKET STABILITY SCATTER — same as displayed
  output$dl_unique_supp <- downloadHandler(
    filename = function() paste0("market_stability_scatter_", econ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      fig <- tryCatch(econ$fig_supp_stability, error = function(e) NULL)
      .require_fig(fig, "Market Stability Scatter")
      .save_fig_png(fig, file)
    }
  )
  
  
  # [APP-SV19] ECON REPORT DOWNLOADS (Word + ZIP) ────────────────────────────
  # ============================================================
  # ECON REPORT DOWNLOADS
  # ============================================================
  
  econ_get_export_data <- function() {
    econ_filter_data(
      df             = econ$analysis$df,
      year_range     = econ_filters$active$year,
      market         = econ_filters$active$market,
      value_range    = econ_filters$active$value,
      buyer_type     = econ_filters$active$buyer_type,
      procedure_type = econ_filters$active$procedure_type,
      value_divisor  = econ$value_divisor,
      buyer_mapping  = econ_buyer_mapping(),
      procedure_mapping = econ_procedure_mapping()
    )
  }
  
  admin_get_export_data <- function() {
    admin_filter_data(
      df                = admin$data,
      year_range        = admin_filters$active$year,
      market            = admin_filters$active$market,
      value_range       = admin_filters$active$value,
      buyer_type        = admin_filters$active$buyer_type,
      procedure_type    = admin_filters$active$procedure_type,
      value_divisor     = admin$value_divisor,
      procedure_mapping = admin_procedure_mapping()
    )
  }
  
  integ_get_export_data <- function() {
    integrity_filter_data(
      df             = integ$data,
      year_range     = integ_filters$active$year,
      market         = integ_filters$active$market,
      value_range    = integ_filters$active$value,
      buyer_type     = integ_filters$active$buyer_type,
      procedure_type = integ_filters$active$procedure_type,
      value_divisor  = integ$value_divisor
    )
  }
  
  
  output$dl_econ_word <- downloadHandler(
    filename = function() paste0("econ_outcomes_", econ$country_code, "_", Sys.Date(), ".docx"),
    content  = function(file) {
      req(econ$data, econ$analysis, econ$country_code)
      withProgress(message="Generating economic outcomes Word report...", value=0, {
        incProgress(0.2, detail="Filtering data...")
        exp_data <- econ_get_export_data()
        incProgress(0.4, detail="Regenerating plots...")
        regen    <- econ_regenerate_plots(exp_data)
        # Merge the stored displayed figs (native-plotly-only charts) so the
        # report can include them; NULLs become explanatory notes in the doc
        regen$fig_contracts_year <- econ$fig_contracts_year_econ
        regen$fig_value_by_year  <- econ$fig_value_by_year
        regen$fig_supp_bubble    <- econ$fig_supp_bubble
        regen$fig_supp_stability <- econ$fig_supp_stability
        regen$fig_supp_trend     <- econ$fig_supp_trend
        regen$fig_top_suppliers  <- econ$fig_top_suppliers
        regen$network_plots      <- econ$filtered_analysis$network_plots
        incProgress(0.6, detail="Creating report (plotly figures are rendered via webshot2 — this can take a minute)...")
        filter_desc  <- get_filter_description(econ_filters$active)
        filters_text <- if (filter_desc == "No filters applied") "" else paste0("Applied Filters: ", filter_desc)
        ok <- generate_econ_word_report(
          filtered_data     = exp_data,
          filtered_analysis = regen,
          country_code      = econ$country_code,
          output_file       = file,
          filters_text      = filters_text
        )
        output$export_status <- renderText(if (ok) "Economic Word report generated!" else "Error generating Word report.")
      })
    }
  )
  
  output$dl_econ_zip <- downloadHandler(
    filename = function() paste0("econ_figures_", econ$country_code, "_", format(Sys.Date(), "%Y%m%d"), ".zip"),
    content  = function(file) {
      req(econ$data, econ$analysis, econ$country_code)
      withProgress(message="Creating economic figures ZIP...", value=0, {
        incProgress(0.1, detail="Filtering data...")
        exp_data  <- econ_get_export_data()
        incProgress(0.2, detail="Regenerating plots...")
        regen     <- econ_regenerate_plots(exp_data)
        temp_dir  <- tempfile(); dir.create(temp_dir)
        cc        <- econ$country_code
        # Canonical manifest: EVERY figure the econ section can produce.
        # obj may be a ggplot, a plotly fig (stored displayed version), or NULL
        # (recorded in MANIFEST.txt as skipped, with a note on how to get it).
        no_cpv  <- "Needs CPV market data (lot_productcode column)."
        no_rel  <- "Needs both bid_price and lot_estimatedprice columns."
        no_sb   <- "Needs a single-bid indicator (ind_corr_singleb or bid_number)."
        view_sd <- "Open the Supplier Dynamics tab once, then re-download."
        view_do <- "Open the Data Overview tab once, then re-download."
        entries <- list(
          list(obj = econ$fig_contracts_year_econ,      name = "contracts_per_year",      w = 10, h = 6,  note = view_do),
          list(obj = econ$fig_value_by_year,            name = "contract_value_by_year",  w = 10, h = 6,  note = view_do),
          list(obj = regen$market_size_n,               name = "market_size_n",           w = 10, h = 7,  note = no_cpv),
          list(obj = regen$market_size_v,               name = "market_size_v",           w = 10, h = 7,  note = no_cpv),
          list(obj = regen$market_size_av,              name = "market_size_av",          w = 10, h = 7,  note = no_cpv),
          list(obj = econ$fig_supp_bubble,              name = "supplier_entry_bubble",   w = 11, h = 8,  note = view_sd),
          list(obj = econ$fig_supp_stability,           name = "market_stability_scatter",w = 11, h = 8,  note = view_sd),
          list(obj = econ$fig_supp_trend,               name = "new_vs_repeat_trend",     w = 11, h = 8,  note = view_sd),
          list(obj = econ$fig_top_suppliers,            name = "top_suppliers",           w = 10, h = 8,  note = view_sd),
          list(obj = regen$suppliers_entrance,          name = "suppliers_entrance",      w = 12, h = 10, note = paste(no_cpv, "Also needs supplier IDs.")),
          list(obj = regen$unique_supp,                 name = "unique_supp",             w = 12, h = 10, note = paste(no_cpv, "Also needs supplier IDs.")),
          list(obj = regen$supplier_entry_agg,          name = "supplier_entry_aggregate",w = 10, h = 7,  note = "Only produced for datasets WITHOUT CPV market data."),
          list(obj = regen$rel_tot,                     name = "rel_tot",                 w = 10, h = 7,  note = no_rel),
          list(obj = regen$rel_year,                    name = "rel_year",                w = 10, h = 7,  note = no_rel),
          list(obj = regen$rel_10,                      name = "rel_10",                  w = 10, h = 7,  note = paste(no_rel, no_cpv)),
          list(obj = regen$rel_buy,                     name = "rel_buy",                 w = 10, h = 7,  note = paste(no_rel, "Also needs buyer_name.")),
          list(obj = regen$single_bid_overall,          name = "single_bid_overall",      w = 10, h = 6,  note = no_sb),
          list(obj = regen$single_bid_by_procedure,     name = "single_bid_procedure",    w = 10, h = 7,  note = no_sb),
          list(obj = regen$single_bid_by_price,         name = "single_bid_price",        w = 10, h = 7,  note = no_sb),
          list(obj = regen$single_bid_by_buyer_group,   name = "single_bid_buyer_grp",    w = 10, h = 7,  note = no_sb),
          list(obj = regen$single_bid_by_market,        name = "single_bid_market",       w = 10, h = 9,  note = paste(no_sb, no_cpv)),
          list(obj = regen$top_buyers_single_bid,       name = "top_buyers_single_bid",   w = 10, h = 7,  note = no_sb)
        )
        statuses <- data.frame(figure = character(0), status = character(0),
                               note = character(0), stringsAsFactors = FALSE)
        saved <- 0
        for (i in seq_along(entries)) {
          e <- entries[[i]]
          incProgress(0.2 + i / length(entries) * 0.7, detail = paste0("Saving ", e$name))
          ok <- pa_save_plot_any(e$obj, file.path(temp_dir, paste0(e$name, "_", cc, ".png")),
                                 width_in = e$w, height_in = e$h)
          st <- if (isTRUE(ok)) "saved" else if (identical(attr(ok, "reason"), "not generated")) "skipped" else "failed"
          nt <- if (isTRUE(ok)) "" else if (st == "skipped") e$note else (attr(ok, "reason") %||% "unknown error")
          statuses <- rbind(statuses, data.frame(figure = e$name, status = st, note = nt,
                                                 stringsAsFactors = FALSE))
          if (isTRUE(ok)) saved <- saved + 1
        }
        # Networks — generated on demand in the Networks tab
        net_plots <- econ$filtered_analysis$network_plots
        if (!is.null(net_plots) && length(net_plots) > 0) {
          for (j in seq_along(net_plots)) {
            nm <- names(net_plots)[j] %||% paste0("network_", j)
            ok <- pa_save_plot_any(net_plots[[j]],
                                   file.path(temp_dir, paste0(nm, "_", cc, ".png")),
                                   width_in = 12, height_in = 12)
            statuses <- rbind(statuses, data.frame(
              figure = nm, status = if (isTRUE(ok)) "saved" else "failed",
              note   = if (isTRUE(ok)) "" else (attr(ok, "reason") %||% "unknown error"),
              stringsAsFactors = FALSE))
            if (isTRUE(ok)) saved <- saved + 1
          }
        } else {
          statuses <- rbind(statuses, data.frame(
            figure = "networks_*", status = "skipped",
            note = "Generate networks in the Networks tab first, then re-download.",
            stringsAsFactors = FALSE))
        }
        pa_write_manifest(temp_dir, "Economic Outcomes", statuses)
        zip::zip(zipfile = file, files = list.files(temp_dir, full.names = TRUE), mode = "cherry-pick")
        output$export_status <- renderText(paste0(
          saved, " of ", nrow(statuses),
          " economic figures saved to ZIP — see MANIFEST.txt inside the ZIP."))
        if (saved < nrow(statuses))
          showNotification(paste0(saved, " of ", nrow(statuses),
                                  " figures saved. MANIFEST.txt inside the ZIP explains how to generate the rest."),
                           type = "warning", duration = 8)
        unlink(temp_dir, recursive=TRUE)
      })
    }
  )
  
  
  # [APP-SV20] ADMIN PROCEDURE TYPES OUTPUTS (+ bunching analysis) ───────────
  # ============================================================
  # ADMIN PROCEDURE TYPES OUTPUTS
  # ============================================================
  
  # Cached — called once, used by both value and count plots
  admin_proc_share <- reactive({
    req(admin$filtered_data)
    tryCatch(build_proc_share_data(admin$filtered_data), error = function(e) NULL)
  })
  
  output$procedure_share_value_plot <- renderPlotly({
    plot_data <- admin_proc_share(); req(!is.null(plot_data))
    tryCatch({
      has_value <- !all(is.na(plot_data$share_value))
      loc_lbl   <- (admin$local_currency %||% list(label="NC"))$label
      cur_pfx   <- if (loc_lbl == "USD") "$" else ""
      
      if (has_value) {
        # Auto-scale total_value for tooltip
        max_tv <- max(plot_data$total_value, na.rm=TRUE)
        if (max_tv >= 1e9) { tv_s <- 1e9; tv_sfx <- "B" } else
          if (max_tv >= 1e6) { tv_s <- 1e6; tv_sfx <- "M" } else
            if (max_tv >= 1e3) { tv_s <- 1e3; tv_sfx <- "K" } else { tv_s <- 1; tv_sfx <- "" }
        
        p <- ggplot2::ggplot(plot_data,
                             ggplot2::aes(x=stats::reorder(tender_proceduretype, share_value),
                                          y=share_value,
                                          text=paste0(tender_proceduretype,"<br>",
                                                      scales::percent(share_value, accuracy=0.1)," (",
                                                      cur_pfx, round(total_value/tv_s, 1), tv_sfx,
                                                      " ", loc_lbl, ")"))) +
          ggplot2::geom_col(fill="#3c8dbc", width=0.6) +
          ggplot2::scale_y_continuous(labels=scales::percent_format(accuracy=1),
                                      expand=ggplot2::expansion(mult=c(0,0.4))) +
          ggplot2::coord_flip() +
          ggplot2::labs(x=NULL, y="Share of total value") +
          pa_theme()
      } else {
        # No price column — show count-based chart with a note
        p <- ggplot2::ggplot(plot_data,
                             ggplot2::aes(x=stats::reorder(tender_proceduretype, share_contracts),
                                          y=share_contracts,
                                          text=paste0(tender_proceduretype,"<br>",
                                                      scales::percent(share_contracts, accuracy=0.1),
                                                      " (",n_contracts," contracts)"))) +
          ggplot2::geom_col(fill="#95a5a6", width=0.6) +
          ggplot2::scale_y_continuous(labels=scales::percent_format(accuracy=1),
                                      expand=ggplot2::expansion(mult=c(0,0.4))) +
          ggplot2::coord_flip() +
          ggplot2::labs(x=NULL, y="Share of contracts (no price data available)") +
          pa_theme()
      }
      admin$gg_proc_share_value <- p
      p_out <- ggplotly(p, tooltip="text") %>% layout(font=list(size=11), showlegend=FALSE)
      admin$fig_proc_share_value <- p_out %>% pa_config(); admin$fig_proc_share_value
    }, error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$procedure_share_count_plot <- renderPlotly({
    plot_data <- admin_proc_share(); req(!is.null(plot_data))
    tryCatch({
      p <- ggplot2::ggplot(plot_data,
                           ggplot2::aes(x=stats::reorder(tender_proceduretype, share_value), y=share_contracts,
                                        text=paste0(tender_proceduretype,"<br>",
                                                    scales::percent(share_contracts,accuracy=0.1)," (",n_contracts," contracts)"))) +
        ggplot2::geom_col(fill="#3c8dbc", width=0.6) +
        ggplot2::scale_y_continuous(labels=scales::percent_format(accuracy=1), expand=ggplot2::expansion(mult=c(0,0.4))) +
        ggplot2::coord_flip() +
        ggplot2::labs( x=NULL, y="Share of contracts") +
        pa_theme()
      admin$gg_proc_share_count <- p
      p_out <- ggplotly(p, tooltip="text") %>% layout(font=list(size=11), showlegend=FALSE)
      admin$fig_proc_share_count <- p_out %>% pa_config(); admin$fig_proc_share_count
    }, error = function(e) .empty_plotly(paste("Not available:", e$message)))
  })
  
  output$proc_value_dist_plot <- renderPlotly({
    req(admin$filtered_data)
    # Detect best price column (prefer local bid_price when thresholds set, else any available)
    price_col <- if (has_any_price_threshold(admin$price_thresholds) && "bid_price" %in% names(admin$filtered_data))
      "bid_price"
    else
      intersect(c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"),
                names(admin$filtered_data))[1]
    if (is.na(price_col)) return(.empty_plotly("No contract value column found in the data."))
    
    loc_lbl <- (admin$local_currency %||% list(label="NC"))$label
    currency_lbl <- if (price_col == "bid_priceusd") "USD" else loc_lbl
    
    df <- admin$filtered_data %>%
      dplyr::mutate(proc_label = recode_procedure_type(tender_proceduretype),
                    supply_grp = classify_supply(.)) %>%
      dplyr::filter(!is.na(proc_label)) %>%   # keep national types; drop only true NAs
      dplyr::filter(!is.na(.data[[price_col]]), .data[[price_col]] > 1)
    
    selected_procs <- input$proc_value_dist_procs
    if (!is.null(selected_procs) && length(selected_procs) > 0)
      df <- df %>% dplyr::filter(proc_label %in% selected_procs)
    req(nrow(df) > 0)
    
    df       <- df %>% dplyr::mutate(log_val = log10(.data[[price_col]]))
    x_min    <- floor(min(df$log_val,   na.rm=TRUE))
    x_max    <- ceiling(max(df$log_val, na.rm=TRUE))
    bin_size <- 0.1
    
    # Build colour palette dynamically: canonical colours + auto-assign for national types
    canonical_colors <- c(
      "Open Procedure"="#2980b9","Restricted Procedure"="#e67e22",
      "Negotiated with publications"="#8e44ad","Negotiated without publications"="#c0392b",
      "Negotiated (unspecified)"="#d35400","Competitive Dialogue"="#16a085",
      "Innovation Partnership"="#27ae60","Direct Award"="#7f8c8d","Other"="#bdc3c7"
    )
    all_procs    <- sort(unique(df$proc_label))
    extra_procs  <- setdiff(all_procs, names(canonical_colors))
    extra_cols   <- if (length(extra_procs) > 0) {
      palette_extra <- scales::hue_pal()(length(extra_procs))
      setNames(palette_extra, extra_procs)
    } else character(0)
    proc_colors <- c(canonical_colors, extra_cols)
    
    tick_vals <- seq(x_min, x_max)
    tick_text <- sapply(tick_vals, function(v) fmt_value(10^v))
    supply_order <- c("Goods","Works","Services")
    supply_types <- supply_order[supply_order %in% unique(df$supply_grp)]
    if (length(supply_types) == 0) supply_types <- unique(df$supply_grp)
    
    sub_figs <- lapply(seq_along(supply_types), function(i) {
      st <- supply_types[[i]]; d_st <- df %>% dplyr::filter(supply_grp == st)
      fig <- plot_ly()
      for (proc in intersect(names(proc_colors), unique(d_st$proc_label))) {
        d_proc <- d_st %>% dplyr::filter(proc_label == proc) %>% dplyr::pull(log_val)
        if (length(d_proc) < 3) next
        h   <- graphics::hist(d_proc, breaks=seq(x_min, x_max+bin_size, by=bin_size), plot=FALSE)
        bl  <- h$breaks[-length(h$breaks)]
        tip <- paste0("<b>",proc,"</b><br>~",sapply(bl, function(v) fmt_value(10^v)),"<br>",h$counts," contracts")
        fig <- fig %>% add_bars(x=bl, y=h$counts, name=proc, legendgroup=proc, showlegend=(i==1),
                                marker=list(color=proc_colors[[proc]], line=list(color="white",width=0.2)),
                                opacity=0.72, hovertext=tip, hoverinfo="text", width=bin_size*0.9)
      }
      # Panel titles are added AFTER subplot(): paper-referenced annotations
      # inside sub-figures are NOT remapped to the panel's domain, so titles
      # set here would all stack at the centre of the combined figure.
      fig %>% layout(barmode="overlay",
                     xaxis=list(title="",tickvals=tick_vals,ticktext=tick_text,showgrid=TRUE,gridcolor="#ecf0f1"),
                     yaxis=list(title=if(i==1)"Number of contracts"else""))
    })
    # One centred <b>Goods/Works/Services</b> title above each panel, placed
    # at the panel's paper-domain centre (same width/gap maths as subplot()).
    k_pan <- length(supply_types); gap <- 0.06
    w_pan <- (1 - gap * (k_pan - 1)) / k_pan
    panel_titles <- lapply(seq_len(k_pan), function(i) list(
      text = paste0("<b>", supply_types[[i]], "</b>"),
      x = (i - 1) * (w_pan + gap) + w_pan / 2, xref = "paper",
      y = 1.02, yref = "paper", xanchor = "center", yanchor = "bottom",
      showarrow = FALSE, font = list(size = 13, color = "#2c3e50")
    ))
    p_out <- subplot(sub_figs, nrows=1, shareY=FALSE, titleX=FALSE, titleY=TRUE, margin=gap) %>%
      layout(barmode="overlay",
             annotations = panel_titles,
             margin      = list(t = 48),
             xaxis=list(title=paste0("Contract value (",currency_lbl,", log scale)")),
             legend=list(orientation="h",x=0,y=-0.28),
             hovermode="closest", hoverlabel=list(bgcolor="white",font=list(size=12)))
    admin$fig_proc_value_dist <- p_out %>% pa_config(); admin$fig_proc_value_dist
  })
  
  # ── Bunching analysis ────────────────────────────────────────────────
  output$bunching_status_ui <- renderUI({
    if (!has_any_price_threshold(admin$price_thresholds))
      div(class="alert alert-info", style="margin-bottom:12px;", icon("info-circle"),
          " No contract value thresholds are active. For BG data they are pre-filled automatically.",
          " For other countries, enter thresholds in ",
          strong("Configuration \u2192 Section C"), " and click ", strong("Apply Thresholds"), ".")
  })
  
  output$bunching_analysis_plot <- renderPlotly({
    req(admin$filtered_data)
    pt <- admin$price_thresholds
    req(has_any_price_threshold(pt))
    req("bid_price" %in% names(admin$filtered_data))
    proc_label_map <- c(open="Open Procedure",restricted="Restricted Procedure",
                        neg_pub="Negotiated with publications",neg_nopub="Negotiated without publications",
                        neg="Negotiated Procedure",competitive="Competitive Dialogue",
                        innov="Innovation Partnership",direct="Direct Award",other="Other")
    supply_map <- c(goods="Goods",works="Works",services="Services")
    all_thr <- list()
    for (pk in names(pt)) for (sk in names(pt[[pk]])) {
      v <- pt[[pk]][[sk]]
      if (!is.null(v) && !is.na(v) && is.finite(v) && v > 0 && pk %in% names(proc_label_map) && sk %in% names(supply_map)) {
        key <- paste0(sk,"_",round(v))
        if (is.null(all_thr[[key]])) all_thr[[key]] <- list(supply_label=supply_map[[sk]],threshold=v,log_thr=log10(v),proc_labels=proc_label_map[[pk]])
        else all_thr[[key]]$proc_labels <- paste0(all_thr[[key]]$proc_labels,", ",proc_label_map[[pk]])
      }
    }
    panels <- unname(all_thr); req(length(panels) > 0)
    df_all <- admin$filtered_data %>%
      dplyr::mutate(supply_grp=classify_supply(.)) %>%
      dplyr::filter(!is.na(bid_price), bid_price > 1) %>%
      dplyr::mutate(log_val=log10(bid_price))
    sensitivity <- (input$spike_sensitivity %||% 50) / 100
    bin_size    <- 0.05; n_bins <- input$n_search_bins %||% 10
    excl_win    <- n_bins * bin_size; show_win <- max(2.0, excl_win + 1.0)
    sub_figs <- lapply(seq_along(panels), function(i) {
      pn      <- panels[[i]]
      d_win   <- df_all %>% dplyr::filter(supply_grp==pn$supply_label, log_val>=pn$log_thr-show_win, log_val<=pn$log_thr+show_win)
      if (nrow(d_win) < 15) return(plot_ly() %>% layout(xaxis=list(visible=FALSE),yaxis=list(visible=FALSE),
                                                        annotations=list(list(text=paste0("<b>",pn$supply_label,"</b> \u2014 Insufficient data"),x=0.5,y=0.5,xref="paper",yref="paper",showarrow=FALSE,font=list(size=10)))))
      breaks  <- seq(pn$log_thr-show_win, pn$log_thr+show_win+bin_size, by=bin_size)
      h       <- graphics::hist(d_win$log_val, breaks=breaks, plot=FALSE)
      bin_lo  <- h$breaks[-length(h$breaks)]; bin_mid <- bin_lo + bin_size/2; counts <- h$counts
      excl    <- abs(bin_mid - pn$log_thr) <= excl_win
      fit_df  <- data.frame(x=bin_mid[!excl], y=counts[!excl])
      pred    <- rep(NA_real_, length(bin_mid))
      if (nrow(fit_df) >= 8) {
        fit <- tryCatch(lm(y ~ poly(x,4), data=fit_df), error=function(e) NULL)
        if (!is.null(fit)) {
          pred <- pmax(as.numeric(predict(fit, newdata=data.frame(x=bin_mid))), 0)
          pred[bin_mid < min(fit_df$x) | bin_mid > max(fit_df$x)] <- NA_real_
        }
      }
      below_win  <- bin_mid < pn$log_thr & bin_mid >= (pn$log_thr - excl_win)
      is_bunch   <- below_win & !is.na(pred) & pred > 0 & counts > pred * (1 + sensitivity)
      bar_colors <- dplyr::case_when(is_bunch~"#e74c3c", below_win~"#f0b27a", TRUE~"#5dade2")
      has_data   <- counts > 0
      pred_disp  <- pred
      if (any(has_data)) pred_disp[bin_lo < min(bin_lo[has_data]) | bin_lo > max(bin_lo[has_data])] <- NA_real_
      tick_seq <- seq(ceiling((pn$log_thr-show_win)/0.5)*0.5, floor((pn$log_thr+show_win)/0.5)*0.5, by=0.5)
      tick_seq <- sort(c(tick_seq[abs(tick_seq-pn$log_thr)>=0.20], pn$log_thr))
      tick_pos <- tick_seq[tick_seq>=pn$log_thr-show_win & tick_seq<=pn$log_thr+show_win]
      tick_lbl <- sapply(tick_pos, function(v) if(abs(v-pn$log_thr)<0.001) paste0(fmt_value(10^v)," \u2605") else fmt_value(10^v))
      hover_tip <- paste0(sapply(bin_lo,fmt_value_log),": <b>",counts," contracts</b>",
                          ifelse(!is.na(pred),paste0("<br>Expected: ",round(pred)," | Diff: ",ifelse(counts-round(pred)>=0,"+",""),counts-round(pred)),""),
                          ifelse(is_bunch,paste0("<br><b>\u26a0 Exceeds expected by \u2265",round(sensitivity*100),"%</b>"),""))
      fig <- plot_ly()
      if (any(!is.na(pred_disp)))
        fig <- fig %>% add_lines(x=bin_lo, y=pred_disp, name="Expected (counterfactual)", legendgroup="cf",
                                 showlegend=(i==1), line=list(color="#1c2833",width=2,dash="dot"),
                                 connectgaps=FALSE, hoverinfo="skip", inherit=FALSE)
      fig <- fig %>% add_bars(x=bin_lo, y=counts, name="All contracts", legendgroup="bars", showlegend=(i==1),
                              marker=list(color=bar_colors, line=list(color="white",width=0.3)),
                              opacity=0.85, hovertext=hover_tip, hoverinfo="text", width=bin_size*0.92)
      fig %>% layout(barmode="overlay",
                     shapes=list(list(type="rect",xref="x",yref="paper",x0=pn$log_thr-excl_win,x1=pn$log_thr,y0=0,y1=1,fillcolor="#e74c3c",opacity=0.05,line=list(width=0)),
                                 list(type="line",xref="x",yref="paper",x0=pn$log_thr,x1=pn$log_thr,y0=0,y1=1,line=list(color="#922b21",width=2.5,dash="solid"))),
                     annotations=list(list(text=paste0("<b>",pn$supply_label,"</b> | Threshold: <b>",fmt_value(pn$threshold),"</b>"),
                                           x=pn$log_thr+0.04,y=0.98,xref="x",yref="paper",xanchor="left",yanchor="top",showarrow=FALSE,
                                           font=list(size=10,color="#922b21"),bgcolor="rgba(255,255,255,0.85)",borderpad=2)),
                     xaxis=list(tickvals=tick_pos,ticktext=tick_lbl,tickfont=list(size=11),showgrid=TRUE,gridcolor="#ecf0f1",range=c(pn$log_thr-show_win,pn$log_thr+show_win)),
                     yaxis=list(tickfont=list(size=11)))
    })
    n_panels <- length(sub_figs); n_cols <- min(3,n_panels); n_rows <- ceiling(n_panels/n_cols)
    if (n_rows * n_cols > n_panels) {
      blank   <- plot_ly() %>% layout(xaxis=list(visible=FALSE),yaxis=list(visible=FALSE),paper_bgcolor="rgba(0,0,0,0)",plot_bgcolor="rgba(0,0,0,0)")
      sub_figs <- c(sub_figs, rep(list(blank), n_rows*n_cols-n_panels))
    }
    p_out <- subplot(sub_figs, nrows=n_rows, shareY=FALSE, titleX=TRUE, titleY=FALSE,
                     widths=rep(1/n_cols,n_cols), margin=c(0.06,0.06,0.12,0.04)) %>%
      layout(barmode="overlay", hovermode="closest", hoverlabel=list(bgcolor="white",font=list(size=12)),
             legend=list(orientation="h",x=0.5,xanchor="center",y=-0.08,yanchor="top",itemsizing="constant",
                         bgcolor="rgba(255,255,255,0.9)",bordercolor="#cccccc",borderwidth=1),
             margin=list(t=30,b=20,l=70,r=20))
    admin$bunching_fig <- p_out %>% pa_config(); admin$bunching_fig
  })
  
  output$bunching_analysis_plot_ui <- renderUI({
    pt <- admin$price_thresholds
    if (!has_any_price_threshold(pt)) return(plotlyOutput("bunching_analysis_plot", height="80px"))
    supply_map <- c(goods="Goods",works="Works",services="Services")
    seen <- character(0)
    for (pk in names(pt)) for (sk in names(pt[[pk]])) {
      v <- pt[[pk]][[sk]]
      if (!is.null(v) && !is.na(v) && is.finite(v) && v > 0 && sk %in% names(supply_map))
        seen <- union(seen, paste0(sk,"_",round(v)))
    }
    n_panels <- length(seen); n_cols <- min(3, max(n_panels,1)); n_rows <- ceiling(max(n_panels,1)/n_cols)
    plotlyOutput("bunching_analysis_plot", height=paste0(max(320, n_rows*320),"px"))
  })
  
  output$dl_bunching <- downloadHandler(
    filename = function() paste0("bunching_analysis_", admin$country_code, "_", format(Sys.Date(),"%Y%m%d"), ".png"),
    content  = function(file) {
      req(admin$bunching_fig)
      # Match the display height: n_rows * 320px, same logic as bunching_analysis_plot_ui
      pt <- isolate(admin$price_thresholds)
      if (has_any_price_threshold(pt)) {
        supply_map <- c(goods="Goods", works="Works", services="Services")
        seen <- character(0)
        for (pk in names(pt)) for (sk in names(pt[[pk]])) {
          v <- pt[[pk]][[sk]]
          if (!is.null(v) && !is.na(v) && is.finite(v) && v > 0 && sk %in% names(supply_map))
            seen <- union(seen, paste0(sk, "_", round(v)))
        }
        n_panels <- length(seen); n_cols <- min(3, max(n_panels, 1)); n_rows <- ceiling(max(n_panels,1) / n_cols)
        vh <- max(500, n_rows * 450)   # slightly taller than display for better proportions
      } else {
        vh <- 500
      }
      .save_fig_png(admin$bunching_fig, file, vw = 1400, vh = vh)
    }
  )
  
  
  # [APP-SV21] ADMIN SUBMISSION PERIODS OUTPUTS (+ share summary chart) ──────
  # ============================================================
  # ADMIN SUBMISSION PERIODS OUTPUTS
  # ============================================================
  
  output$submission_dist_plot <- renderPlotly({
    req(admin$filtered_data)
    tp   <- compute_tender_days(admin$filtered_data, tender_publications_firstcallfortenderdate, tender_biddeadline, tender_days_open)
    days <- tp$tender_days_open[!is.na(tp$tender_days_open) & tp$tender_days_open>=0 & tp$tender_days_open<=365]
    q    <- quantile(days,probs=c(0.25,0.5,0.75),na.rm=TRUE); mu <- mean(days,na.rm=TRUE)
    p    <- plot_ly() %>%
      add_histogram(x=~days, xbins=list(start=0,end=365,size=5),
                    marker=list(color=PA_NORMAL,line=list(color="white",width=0.5)),
                    name="Contracts", hovertemplate="%{x} days: %{y} contracts<extra></extra>")
    y_max <- max(graphics::hist(days, breaks=seq(0,370,5), plot=FALSE)$counts)*1.05
    q_labels <- c("Q1 (25th)","Median (50th)","Q3 (75th)")
    q_colors <- c(PA_Q_Q1,PA_Q_MEDIAN,PA_Q_Q1); q_dash <- c("dash","solid","dash")
    for (i in seq_along(q))
      p <- p %>% add_segments(x=q[i],xend=q[i],y=0,yend=y_max,
                              line=list(color=q_colors[i],width=2,dash=q_dash[i]),name=q_labels[i],showlegend=TRUE,
                              hovertemplate=paste0("<b>",q_labels[i],"</b><br>",round(q[i],1)," days<extra></extra>"))
    p <- p %>% add_segments(x=mu,xend=mu,y=0,yend=y_max,
                            line=list(color=PA_Q_MEAN,width=2,dash="dot"),name="Mean",
                            hovertemplate=paste0("<b>Mean</b><br>",round(mu,1)," days<extra></extra>"))
    p_out <- p %>% layout(
      xaxis=list(title="Days from call opening to bid deadline",range=c(0,365)),
      yaxis=list(title="Number of contracts"),hovermode="x unified",
      legend=list(orientation="h",y=-0.15),bargap=0.05)
    admin$fig_subm_dist <- p_out %>% pa_config()
    admin$gg_subm_dist <- tryCatch({
      df_hist <- data.frame(days=days)
      ggplot2::ggplot(df_hist, ggplot2::aes(x=days)) +
        ggplot2::geom_histogram(binwidth=5, fill=PA_NORMAL, colour="white") +
        ggplot2::geom_vline(xintercept=q, colour=c(PA_Q_Q1,PA_Q_MEDIAN,PA_Q_Q1),
                            linetype=c("dashed","solid","dashed"), linewidth=1) +
        ggplot2::geom_vline(xintercept=mu, colour=PA_Q_MEAN, linetype="dotted", linewidth=1) +
        ggplot2::coord_cartesian(xlim=c(0,365)) +
        ggplot2::labs(
          x="Days from call opening to bid deadline", y="Number of contracts") +
        pa_theme()
    }, error=function(e) NULL)
    admin$fig_subm_dist
  })
  
  output$submission_proc_plot <- renderPlotly({
    req(admin$filtered_data)
    sel_procs <- if (length(input$subm_proc_filter) == 0) (admin$proc_type_labels %||% PROC_TYPE_LABELS) else input$subm_proc_filter
    tp <- compute_tender_days(admin$filtered_data,
                              tender_publications_firstcallfortenderdate, tender_biddeadline, tender_days_open) %>%
      dplyr::mutate(tender_proceduretype=recode_procedure_type(tender_proceduretype)) %>%
      dplyr::filter(!is.na(tender_proceduretype)) %>%
      dplyr::filter(tender_days_open >= 0, tender_days_open <= 365,
                    tender_proceduretype %in% sel_procs)
    req(nrow(tp) > 0)
    procs <- tp %>%
      dplyr::group_by(tender_proceduretype) %>% dplyr::filter(dplyr::n() >= 5) %>%
      dplyr::summarise(med = median(tender_days_open, na.rm=TRUE), .groups="drop") %>%
      dplyr::arrange(med) %>% dplyr::pull(tender_proceduretype)
    req(length(procs) > 0)
    tp <- tp %>% dplyr::filter(tender_proceduretype %in% procs)
    
    n_proc <- length(procs)
    ncols  <- min(3L, n_proc)
    nrows  <- ceiling(n_proc / ncols)
    subplot_figs <- lapply(procs, function(proc) {
      d    <- tp %>% dplyr::filter(tender_proceduretype == proc) %>% dplyr::pull(tender_days_open)
      q    <- quantile(d, c(0.25, 0.5, 0.75), na.rm=TRUE)
      mu   <- mean(d, na.rm=TRUE)
      x_max <- min(365, quantile(d, 0.99, na.rm=TRUE) * 1.1)
      x_max <- max(x_max, 15)
      # tight bins: 2 days for submission
      binw  <- max(1, min(2, round(x_max / 60)))
      bks   <- seq(0, x_max + binw, by=binw)
      cnts  <- tryCatch(graphics::hist(d[d <= x_max], breaks=bks, plot=FALSE)$counts, error=function(e) c(1))
      y_top <- max(cnts, 1) * 1.15
      plotly::plot_ly() %>%
        plotly::add_histogram(
          x = ~d[d <= x_max],
          xbins = list(start=0, end=x_max + binw, size=binw),
          marker = list(color=PA_NORMAL, line=list(color="white", width=0.4)),
          hovertemplate = "%{x} days: %{y} contracts<extra></extra>",
          showlegend = FALSE
        ) %>%
        plotly::add_segments(x=q[1],xend=q[1],y=0,yend=y_top,
                             line=list(color=PA_Q_Q1,width=1.8,dash="dash"),
                             hovertemplate=paste0("Q1: ",round(q[1],1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::add_segments(x=q[2],xend=q[2],y=0,yend=y_top,
                             line=list(color=PA_Q_MEDIAN,width=2.2,dash="solid"),
                             hovertemplate=paste0("Median: ",round(q[2],1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::add_segments(x=q[3],xend=q[3],y=0,yend=y_top,
                             line=list(color=PA_Q_Q1,width=1.8,dash="dash"),
                             hovertemplate=paste0("Q3: ",round(q[3],1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::add_segments(x=mu,xend=mu,y=0,yend=y_top,
                             line=list(color=PA_Q_MEAN,width=1.5,dash="dot"),
                             hovertemplate=paste0("Mean: ",round(mu,1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::layout(
          annotations=list(list(text=paste0("<b>",proc,"</b>"),
                                x=0.5,y=1.05,xref="paper",yref="paper",
                                xanchor="center",yanchor="bottom",showarrow=FALSE,
                                font=list(size=12,color="#222"))),
          xaxis=list(range=c(0,x_max+binw),tickfont=list(size=13),title=NULL,gridcolor="#eeeeee"),
          yaxis=list(tickfont=list(size=13),title=NULL,rangemode="nonnegative")
        )
    })
    fig <- plotly::subplot(subplot_figs, nrows=nrows, shareX=FALSE, shareY=FALSE,
                           titleX=FALSE, titleY=FALSE, margin=c(0.04,0.04,0.10,0.06))
    fig <- fig %>% plotly::layout(
      font        = list(size=12),
      hoverlabel  = list(bgcolor="white", font=list(size=12)),
      hovermode   = "closest",
      margin      = list(l=40, r=20, t=30, b=50),
      plot_bgcolor  = "#ffffff",
      paper_bgcolor = "#ffffff",
      annotations = list(list(
        text = paste0(
          "<span style='color:",PA_Q_Q1,";'>── Q1/Q3</span>  ",
          "<span style='color:",PA_Q_MEDIAN,";'>—— Median</span>  ",
          "<span style='color:",PA_Q_MEAN,";'>·· Mean</span>"
        ),
        x=0.5, y=-0.06, xref="paper", yref="paper",
        xanchor="center", yanchor="top", showarrow=FALSE,
        font=list(size=12)
      ))
    )
    admin$fig_subm_proc <- fig %>% pa_config(); admin$fig_subm_proc
  })
  
  # ── Submission share summary chart ────────────────────────────────────
  output$subm_share_chart <- renderPlotly({
    req(admin$filtered_data, admin$thresholds)
    sel_procs <- if (length(input$subm_proc_filter) == 0) (admin$proc_type_labels %||% PROC_TYPE_LABELS) else input$subm_proc_filter
    cutoffs   <- admin_subm_cutoffs()
    tp_base   <- admin_subm_open_data() %>%
      dplyr::filter(tender_proceduretype %in% sel_procs)
    req(nrow(tp_base) > 0)
    tp_flagged <- tp_base %>%
      dplyr::left_join(cutoffs, by="tender_proceduretype") %>%
      dplyr::mutate(status = dplyr::case_when(
        tender_days_open < short_cut ~ "Short",
        !no_medium & !is.na(med_min) & !is.na(med_max) &
          tender_days_open >= med_min & tender_days_open <= med_max ~ "Medium",
        TRUE ~ "Normal"
      ), status = factor(status, levels=c("Short","Medium","Normal")))
    share_df <- tp_flagged %>%
      dplyr::group_by(tender_proceduretype) %>%
      dplyr::summarise(
        n_total  = dplyr::n(),
        n_short  = sum(status == "Short",  na.rm=TRUE),
        n_medium = sum(status == "Medium", na.rm=TRUE),
        n_normal = sum(status == "Normal", na.rm=TRUE),
        .groups  = "drop"
      ) %>%
      dplyr::mutate(
        pct_short  = n_short  / n_total,
        pct_medium = n_medium / n_total,
        pct_normal = n_normal / n_total,
        proc_label = paste0(tender_proceduretype, "  (n = ", scales::comma(n_total), ")")
      ) %>%
      dplyr::arrange(dplyr::desc(pct_short))
    
    # Show Medium bar only if at least one procedure actually has medium band active
    has_medium <- any(!cutoffs$no_medium[cutoffs$tender_proceduretype %in% sel_procs], na.rm=TRUE) &&
      any(tp_flagged$status == "Medium", na.rm=TRUE)
    
    n_procs     <- nrow(share_df)
    chart_h_px  <- max(120, n_procs * 38 + 60)  # dynamic height hint (unused in px but guides margin)
    
    fig <- plotly::plot_ly(data = share_df, y = ~proc_label, orientation = "h") %>%
      plotly::add_bars(x = ~pct_short,  name = "Short",
                       marker = list(color = PA_SHORT),
                       hovertemplate = paste0("<b>%{y}</b><br>Short: %{x:.1%}<extra></extra>"))
    if (has_medium)
      fig <- fig %>% plotly::add_bars(x = ~pct_medium, name = "Medium",
                                      marker = list(color = PA_MEDIUM),
                                      hovertemplate = paste0("<b>%{y}</b><br>Medium: %{x:.1%}<extra></extra>"))
    fig <- fig %>%
      plotly::add_bars(x = ~pct_normal, name = "Normal",
                       marker = list(color = PA_NORMAL),
                       hovertemplate = paste0("<b>%{y}</b><br>Normal: %{x:.1%}<extra></extra>")) %>%
      plotly::layout(
        barmode     = "stack",
        xaxis       = list(title = list(text = "Share of contracts", font = list(size = 13)),
                           tickformat = ".0%", range = c(0, 1), gridcolor = "#eeeeee",
                           tickfont = list(size = 13)),
        yaxis       = list(title = "", automargin = TRUE, tickfont = list(size = 13)),
        legend      = list(orientation = "h", yanchor = "bottom", y = 1.02,
                           xanchor = "center", x = 0.5, font = list(size = 13)),
        hovermode   = "y unified",
        margin      = list(l = 10, r = 20, t = 50, b = 40),
        font        = list(size = 13),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
    admin$fig_subm_share <- fig %>% pa_config()
    admin$fig_subm_share
  })
  
  output$submission_short_plot <- renderPlotly({
    req(admin$filtered_data, admin$thresholds)
    cutoffs  <- admin_subm_cutoffs()
    sel_procs <- if (length(input$subm_proc_filter) == 0) (admin$proc_type_labels %||% PROC_TYPE_LABELS) else input$subm_proc_filter
    tp_base  <- admin_subm_open_data() %>%
      dplyr::filter(tender_proceduretype %in% sel_procs)
    req(nrow(tp_base) > 0)
    tp_flagged <- tp_base %>%
      dplyr::left_join(cutoffs, by="tender_proceduretype") %>%
      dplyr::mutate(status = dplyr::case_when(
        tender_days_open < short_cut ~ "Short",
        !no_medium & !is.na(med_min) & !is.na(med_max) &
          tender_days_open >= med_min & tender_days_open <= med_max ~ "Medium",
        TRUE ~ "Normal"
      ), status = factor(status, levels=c("Short","Medium","Normal")))
    
    procs_s <- sort(unique(tp_flagged$tender_proceduretype))
    req(length(procs_s) > 0)
    n_ps    <- length(procs_s)
    ncols_s <- min(3L, n_ps)
    nrows_s <- ceiling(n_ps / ncols_s)
    
    col_map <- c(Short=PA_SHORT, Medium=PA_MEDIUM, Long=PA_LONG, Normal=PA_NORMAL)
    
    # Per-procedure histogram with red shaded zone for the "short" region.
    # x-axis auto-ranges per procedure — works even when days cluster at 3-30.
    sub_figs_s <- lapply(procs_s, function(proc) {
      d_proc  <- tp_flagged %>% dplyr::filter(tender_proceduretype == proc)
      thr_val <- dplyr::first(na.omit(dplyr::pull(
        dplyr::filter(cutoffs, tender_proceduretype == proc), short_cut)))
      if (length(thr_val) == 0) thr_val <- NA_real_
      pct_s   <- mean(d_proc$status == "Short", na.rm=TRUE)
      n_tot   <- nrow(d_proc)
      x_max   <- max(d_proc$tender_days_open, na.rm=TRUE)
      x_max   <- max(x_max, if (!is.na(thr_val)) thr_val * 3 else 30, 15)
      # Hard cap at 1-2 day bins for submission periods
      binw    <- min(2, max(1, round(x_max / 60)))
      
      traces <- plotly::plot_ly()
      
      for (st in c("Normal","Medium","Short")) {
        d_st <- d_proc %>% dplyr::filter(status == st) %>% dplyr::pull(tender_days_open)
        if (length(d_st) == 0) next
        traces <- traces %>% plotly::add_histogram(
          x = d_st,
          xbins = list(start=0, end=x_max + binw, size=binw),
          name  = st, legendgroup = st, showlegend = FALSE,
          marker = list(color=col_map[[st]], line=list(color="white", width=0.3)),
          hovertemplate = paste0("<b>", st, "</b>: %{y} contracts<extra></extra>")
        )
      }
      
      cutrow_s   <- cutoffs %>% dplyr::filter(tender_proceduretype == proc)
      no_med_s   <- if (nrow(cutrow_s) > 0) isTRUE(cutrow_s$no_medium[1]) else TRUE
      med_lo_s   <- if (!no_med_s && nrow(cutrow_s) > 0) cutrow_s$med_min[1] else NA_real_
      med_hi_s   <- if (!no_med_s && nrow(cutrow_s) > 0) cutrow_s$med_max[1] else NA_real_
      pct_m_s    <- mean(d_proc$status == "Medium", na.rm = TRUE)
      
      shape_list <- list()
      if (!is.na(thr_val)) {
        shape_list <- c(shape_list, list(
          list(type="line", x0=thr_val, x1=thr_val, y0=0, y1=1,
               xref="x", yref="paper",
               line=list(color=PA_SHORT, width=1.8, dash="dash")),
          list(type="rect", x0=0, x1=thr_val, y0=0, y1=1,
               xref="x", yref="paper",
               fillcolor="rgba(198,40,40,0.08)", line=list(width=0))
        ))
      }
      if (!no_med_s && !is.na(med_lo_s) && !is.na(med_hi_s)) {
        shape_list <- c(shape_list, list(
          list(type="rect", x0=med_lo_s, x1=med_hi_s, y0=0, y1=1,
               xref="x", yref="paper",
               fillcolor="rgba(245,158,11,0.13)", line=list(width=0))
        ))
      }
      
      sub_txt <- paste0(
        if (!is.na(thr_val)) paste0("< ", round(thr_val), " days short  \u2502  ") else "",
        if (!no_med_s && !is.na(med_lo_s)) paste0(round(med_lo_s), "\u2013", round(med_hi_s), " days medium  \u2502  ") else "",
        scales::percent(pct_s, accuracy=0.1), " short",
        if (pct_m_s > 0) paste0("  ", scales::percent(pct_m_s, accuracy=0.1), " medium") else "",
        "  (n = ", scales::comma(n_tot), ")"
      )
      
      traces %>% plotly::layout(
        barmode = "stack",
        shapes  = shape_list,
        xaxis = list(
          title      = list(text = sub_txt, font = list(size = 11, color = "#555")),
          tickfont   = list(size = 11),
          gridcolor  = "#eeeeee",
          rangemode  = "nonnegative",
          automargin = TRUE
        ),
        yaxis = list(tickfont=list(size=13), title=NULL, rangemode="nonnegative")
      )
    })
    
    row_gap_s <- if (nrows_s == 1) 0.06 else 0.14
    fig <- plotly::subplot(sub_figs_s, nrows=nrows_s, shareX=FALSE, shareY=FALSE,
                           titleX=TRUE, titleY=FALSE,
                           margin=c(0.04, 0.04, row_gap_s, 0.06))
    
    # Per-panel procedure-name titles via domain arithmetic
    col_w_s <- (1 - 0.04 * (ncols_s - 1)) / ncols_s
    row_h_s <- (1 - row_gap_s * (nrows_s - 1)) / nrows_s
    panel_ann_s <- lapply(seq_along(procs_s), function(i) {
      col_i <- ((i - 1) %% ncols_s)
      row_i <- ((i - 1) %/% ncols_s)
      x_mid <- col_i * (col_w_s + 0.04) + col_w_s / 2
      y_top <- 1 - row_i * (row_h_s + row_gap_s)
      list(text=paste0("<b>", procs_s[i], "</b>"),
           x=x_mid, y=y_top + 0.015,
           xref="paper", yref="paper",
           xanchor="center", yanchor="bottom", showarrow=FALSE,
           font=list(size=12, color="#2c3e50"))
    })
    
    has_medium_s <- any(!cutoffs$no_medium[cutoffs$tender_proceduretype %in% procs_s], na.rm=TRUE) &&
      any(tp_flagged$status == "Medium", na.rm=TRUE)
    legend_txt_s <- paste0(
      "<span style='color:", PA_SHORT,  ";'>▪ Short</span>   ",
      if (has_medium_s) paste0("<span style='color:", PA_MEDIUM, ";'>▪ Medium</span>   ") else "",
      "<span style='color:", PA_NORMAL, ";'>▪ Normal</span>   ",
      "<span style='color:", PA_SHORT,  ";'>‒ ‒ threshold</span>"
    )
    legend_ann_s <- list(
      text = legend_txt_s,
      x=0.5, y=-0.03, xref="paper", yref="paper",
      xanchor="center", yanchor="top", showarrow=FALSE,
      font=list(size=12)
    )
    
    fig <- fig %>% plotly::layout(
      font        = list(size=12),
      hoverlabel  = list(bgcolor="white", font=list(size=12)),
      hovermode   = "closest",
      margin      = list(l=45, r=20, t=35, b=55),
      plot_bgcolor  = "#ffffff",
      paper_bgcolor = "#ffffff",
      annotations = c(panel_ann_s, list(legend_ann_s))
    )
    admin$fig_subm_short <- fig %>% pa_config(); admin$fig_subm_short
  })
  
  output$buyer_short_plot <- renderPlotly({
    req(admin$filtered_data, admin$thresholds)
    cutoffs <- admin_subm_cutoffs() %>% dplyr::select(tender_proceduretype, short_cut)
    tp_base <- apply_global_proc_filter(admin_subm_open_data())
    req(nrow(tp_base) > 0)
    tp_buyer <- tp_base %>% dplyr::left_join(cutoffs,by="tender_proceduretype") %>%
      dplyr::mutate(short_deadline=tender_days_open<short_cut, buyer_group=add_buyer_group(buyer_buyertype))
    req(nrow(tp_buyer) > 0)
    by_count <- tp_buyer %>%
      dplyr::group_by(buyer_group,tender_proceduretype) %>%
      dplyr::summarise(n_short=sum(short_deadline,na.rm=TRUE),n_total=dplyr::n(),share_short=mean(short_deadline,na.rm=TRUE),.groups="drop") %>%
      dplyr::mutate(share_other=1-share_short,
                    tip_s=paste0(buyer_group," | ",tender_proceduretype,"<br><b>Short: ",scales::percent(share_short,accuracy=0.1),"</b> (",n_short," of ",n_total," contracts)"),
                    tip_n=paste0(buyer_group," | ",tender_proceduretype,"<br>Normal: ",scales::percent(1-share_short,accuracy=0.1)),metric="Count")
    .short_pc  <- intersect(c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"),
                            names(tp_buyer))[1]
    .short_loc <- (admin$local_currency %||% list(label="NC"))$label
    by_value <- if (!is.na(.short_pc)) {
      tp_buyer %>%
        dplyr::group_by(buyer_group, tender_proceduretype) %>%
        dplyr::summarise(
          total_value = sum(.data[[.short_pc]], na.rm = TRUE),
          short_value = sum(.data[[.short_pc]][short_deadline %in% TRUE], na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::mutate(
          share_short = dplyr::if_else(total_value > 0, short_value / total_value, 0),
          share_other = 1 - share_short,
          tip_s = paste0(buyer_group, " | ", tender_proceduretype,
                         "<br><b>Short: ", scales::percent(share_short, accuracy=0.1), "</b><br>",
                         round(short_value * 1e-6, 1), "M of ", round(total_value * 1e-6, 1), "M ", .short_loc),
          tip_n = paste0(buyer_group, " | ", tender_proceduretype,
                         "<br>Normal: ", scales::percent(1 - share_short, accuracy=0.1)),
          metric = "Contract Value")
    } else {
      tp_buyer %>%
        dplyr::group_by(buyer_group, tender_proceduretype) %>%
        dplyr::summarise(total_value = NA_real_, short_value = NA_real_, .groups = "drop") %>%
        dplyr::mutate(share_short = NA_real_, share_other = NA_real_,
                      tip_s = "No price data", tip_n = "No price data", metric = "Contract Value")
    }
    
    # Perceptually distinct palette — cycles through hue, avoids grey/navy clash
    PA_PROC_PAL <- c(
      "#1A6FAF",  # steel blue     (Open)
      "#2CA02C",  # green          (Restricted)
      "#D62728",  # red            (Neg w/ pub)
      "#FF7F0E",  # orange         (Neg w/o pub)
      "#9467BD",  # purple         (Neg unspec)
      "#17BECF",  # cyan           (Comp. Dialogue)
      "#E377C2",  # pink           (Innovation)
      "#8C564B",  # brown          (Direct Award)
      "#7F7F7F"   # mid-grey       (Other)
    )
    all_procs_s <- sort(unique(by_count$tender_proceduretype))
    proc_pal_s  <- setNames(PA_PROC_PAL[seq_along(all_procs_s)], all_procs_s)
    buyers_ord_s <- sort(unique(by_count$buyer_group))
    
    make_buyer_bar_short <- function(df, share_col, n_col, hover_label, show_legend = TRUE) {
      df <- df %>% dplyr::mutate(
        hover_txt = paste0(
          "<b>", buyer_group, " | ", tender_proceduretype, "</b><br>",
          hover_label, ": ", scales::percent(.data[[share_col]], accuracy=0.1), "<br>",
          "N: ", scales::comma(.data[[n_col]])
        )
      )
      fig <- plotly::plot_ly()
      procs_s2 <- sort(unique(df$tender_proceduretype))
      for (proc in procs_s2) {
        d_p <- df %>% dplyr::filter(tender_proceduretype == proc) %>%
          dplyr::arrange(match(buyer_group, buyers_ord_s))
        fig <- fig %>% plotly::add_bars(
          x           = ~buyer_group, y = ~.data[[share_col]],
          data        = d_p,
          name        = proc, legendgroup = proc,
          showlegend  = show_legend,
          marker      = list(color=proc_pal_s[[proc]], line=list(color="white",width=0.5)),
          hovertext   = ~hover_txt, hoverinfo="text"
        )
      }
      fig %>% plotly::layout(
        barmode = "group",
        xaxis   = list(title = list(text = "Buyer Group", font = list(size = 13)),
                       tickfont = list(size = 13), automargin = TRUE),
        yaxis   = list(title = list(text=hover_label, font=list(size=13)),
                       tickformat=".0%", range=c(0,1),
                       tickfont=list(size=13), gridcolor="#eeeeee"),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff",
        margin        = list(l=65, r=10, t=10, b=10)
      )
    }
    
    p_count_s <- make_buyer_bar_short(
      by_count %>% dplyr::rename(n_col=n_total),
      "share_short", "n_col", "% short by count", show_legend = TRUE)
    p_value_s <- make_buyer_bar_short(
      by_value %>% dplyr::mutate(n_col=round(total_value/1e6)),
      "share_short", "n_col", "% short by value", show_legend = FALSE)
    
    view_sel <- input$subm_buyer_view %||% "count"
    p_out <- if (view_sel == "count") {
      p_count_s %>% plotly::layout(
        hoverlabel = list(bgcolor="white", font=list(size=13)),
        font = list(size=13),
        legend = list(orientation="h", yanchor="top", y=-0.18,
                      xanchor="center", x=0.5, font=list(size=13)),
        margin = list(l=65, r=20, t=40, b=110))
    } else if (view_sel == "value") {
      p_value_s %>% plotly::layout(
        hoverlabel = list(bgcolor="white", font=list(size=13)),
        font = list(size=13),
        legend = list(orientation="h", yanchor="top", y=-0.18,
                      xanchor="center", x=0.5, font=list(size=13)),
        margin = list(l=65, r=20, t=40, b=110))
    } else {
      plotly::subplot(p_count_s, p_value_s, nrows=2,
                      shareX=TRUE, shareY=FALSE,
                      titleX=FALSE, titleY=TRUE, margin=0.08) %>%
        plotly::layout(
          hoverlabel = list(bgcolor="white", font=list(size=13)),
          font = list(size=13),
          legend = list(orientation="h", yanchor="top", y=-0.10,
                        xanchor="center", x=0.5, font=list(size=13)),
          margin = list(l=65, r=20, t=40, b=110))
    }
    admin$fig_buyer_short <- p_out %>% pa_config(); admin$fig_buyer_short
  })
  
  
  # [APP-SV22] ADMIN DECISION PERIODS OUTPUTS (+ share summary chart) ────────
  # ============================================================
  # ADMIN DECISION PERIODS OUTPUTS
  # ============================================================
  
  admin_decision_data <- reactive({
    req(admin$filtered_data)
    df <- admin$filtered_data
    # Ensure both date columns exist before coalescing
    if (!"tender_contractsignaturedate" %in% names(df))
      df <- df %>% dplyr::mutate(tender_contractsignaturedate = as.Date(NA))
    if (!"tender_awarddecisiondate" %in% names(df))
      df <- df %>% dplyr::mutate(tender_awarddecisiondate = as.Date(NA))
    # Primary = tender_awarddecisiondate; fallback = tender_contractsignaturedate
    df %>%
      dplyr::mutate(decision_end_date = dplyr::coalesce(
        as.Date(tender_awarddecisiondate),
        as.Date(tender_contractsignaturedate))) %>%
      compute_tender_days(tender_biddeadline, decision_end_date, tender_days_dec)
  })
  
  admin_subm_open_data <- reactive({
    req(admin$filtered_data)
    compute_tender_days(admin$filtered_data, tender_publications_firstcallfortenderdate, tender_biddeadline, tender_days_open) %>%
      dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
      dplyr::filter(!is.na(tender_proceduretype))   # keep national types; only drop true NAs
  })
  
  # Submission short cutoffs — shared between submission_short_plot and buyer_short_plot
  admin_subm_cutoffs <- reactive({
    req(admin$thresholds)
    tp   <- apply_global_proc_filter(admin_subm_open_data())
    thr  <- admin$thresholds
    purrr::map_dfr(sort(unique(tp$tender_proceduretype)), function(proc) {
      key       <- as.character(proc_to_key(proc)[1])
      # If key resolved to "other" but proc is NOT literally "Other", it's a national
      # proc type that has no dedicated threshold — fall back to statistical cutoff.
      is_national <- (key == "other" && !proc %in% c("Other", "other", NA_character_))
      d         <- tp %>% dplyr::filter(tender_proceduretype==proc) %>% dplyr::pull(tender_days_open)
      # For national procs use the safe-key stored by apply_thresholds observer;
      # for canonical procs use the standard key.
      nat_safe_key <- gsub("[^A-Za-z0-9]", "_", proc)
      thr_entry <- if (!is_national) thr$subm[[key]] else thr$subm[[nat_safe_key]]
      sc <- if (!is.null(thr_entry) && !is.na(thr_entry$days)) thr_entry$days
      else compute_outlier_cutoff(d, thr_entry$outlier_method %||% "iqr")
      nm  <- if (!is.null(thr_entry)) isTRUE(thr_entry$no_medium) else TRUE
      mm  <- if (!nm && !is.null(thr_entry$medium)) thr_entry$medium$min else NA_real_
      mx  <- if (!nm && !is.null(thr_entry$medium)) thr_entry$medium$max else NA_real_
      data.frame(tender_proceduretype=proc, short_cut=sc, no_medium=nm, med_min=mm, med_max=mx,
                 stringsAsFactors=FALSE)
    })
  })
  
  # Decision long cutoffs — shared between decision_long_plot and buyer_long_plot
  admin_dec_cutoffs <- reactive({
    req(admin$thresholds)
    tp  <- admin_decision_data() %>%
      dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
      dplyr::filter(!is.na(tender_proceduretype)) %>%
      dplyr::filter(tender_proceduretype %in% admin$global_proc_filter)
    thr <- admin$thresholds
    purrr::map_dfr(sort(unique(tp$tender_proceduretype)), function(proc) {
      key         <- as.character(proc_to_key(proc)[1])
      is_national <- (key == "other" && !proc %in% c("Other", "other", NA_character_))
      d           <- tp %>% dplyr::filter(tender_proceduretype == proc) %>%
        dplyr::pull(tender_days_dec)
      nat_safe_key <- gsub("[^A-Za-z0-9]", "_", proc)
      thr_entry    <- if (!is_national) thr$dec[[key]] else thr$dec[[nat_safe_key]]
      lc <- if (!is.null(thr_entry) && !is.na(thr_entry$days)) thr_entry$days
      else compute_outlier_cutoff(d, thr_entry$outlier_method %||% "iqr")
      # Short cutoff — default to 0 (no contracts are "too short" unless configured)
      sc        <- if (!is.null(thr_entry) && !is.na(thr_entry$short_days %||% NA_real_))
        thr_entry$short_days else NA_real_
      no_med    <- if (!is.null(thr_entry)) isTRUE(thr_entry$no_medium) else TRUE
      mm        <- if (!no_med && !is.null(thr_entry$medium)) thr_entry$medium$min else NA_real_
      mx        <- if (!no_med && !is.null(thr_entry$medium)) thr_entry$medium$max else NA_real_
      data.frame(tender_proceduretype = proc, long_cut = lc, short_cut = sc,
                 no_medium = no_med, med_min = mm, med_max = mx,
                 stringsAsFactors = FALSE)
    })
  })
  
  output$decision_dist_plot <- renderPlotly({
    tp   <- admin_decision_data(); req(nrow(tp)>0)
    days <- tp$tender_days_dec[!is.na(tp$tender_days_dec) & tp$tender_days_dec>=0 & tp$tender_days_dec<=730]
    req(length(days)>0)
    q  <- quantile(days,probs=c(0.25,0.5,0.75),na.rm=TRUE); mu <- mean(days,na.rm=TRUE)
    p  <- plot_ly() %>%
      add_histogram(x=~days,xbins=list(start=0,end=730,size=10),marker=list(color=PA_NORMAL,line=list(color="white",width=0.5)),
                    name="Contracts",hovertemplate="%{x} days: %{y} contracts<extra></extra>")
    y_max <- max(graphics::hist(days,breaks=seq(0,740,10),plot=FALSE)$counts)*1.05
    q_labels <- c("Q1 (25th)","Median (50th)","Q3 (75th)")
    q_colors <- c(PA_Q_Q1,PA_Q_MEDIAN,PA_Q_Q1); q_dash <- c("dash","solid","dash")
    for (i in seq_along(q))
      p <- p %>% add_segments(x=q[i],xend=q[i],y=0,yend=y_max,line=list(color=q_colors[i],width=2,dash=q_dash[i]),name=q_labels[i],showlegend=TRUE,
                              hovertemplate=paste0("<b>",q_labels[i],"</b><br>",round(q[i],1)," days<extra></extra>"))
    p <- p %>% add_segments(x=mu,xend=mu,y=0,yend=y_max,line=list(color=PA_Q_MEAN,width=2,dash="dot"),name="Mean",
                            hovertemplate=paste0("<b>Mean</b><br>",round(mu,1)," days<extra></extra>"))
    p_out <- p %>% layout(
      xaxis=list(title="Days from bid deadline to contract award",range=c(0,730)),
      yaxis=list(title="Number of contracts"),hovermode="x unified",legend=list(orientation="h",y=-0.15),bargap=0.05)
    admin$fig_dec_dist <- p_out %>% pa_config()
    admin$gg_dec_dist <- tryCatch({
      df_hist <- data.frame(days=days)
      ggplot2::ggplot(df_hist, ggplot2::aes(x=days)) +
        ggplot2::geom_histogram(binwidth=10, fill=PA_NORMAL, colour="white") +
        ggplot2::geom_vline(xintercept=q, colour=c(PA_Q_Q1,PA_Q_MEDIAN,PA_Q_Q1),
                            linetype=c("dashed","solid","dashed"), linewidth=1) +
        ggplot2::geom_vline(xintercept=mu, colour=PA_Q_MEAN, linetype="dotted", linewidth=1) +
        ggplot2::coord_cartesian(xlim=c(0,730)) +
        ggplot2::labs(
          x="Days from bid deadline to contract award", y="Number of contracts") +
        pa_theme()
    }, error=function(e) NULL)
    admin$fig_dec_dist
  })
  
  output$decision_proc_plot <- renderPlotly({
    sel_procs <- if (length(input$dec_proc_filter) == 0) (admin$proc_type_labels %||% PROC_TYPE_LABELS) else input$dec_proc_filter
    tp <- admin_decision_data() %>%
      dplyr::filter(recode_procedure_type(tender_proceduretype) %in% sel_procs) %>%
      dplyr::mutate(tender_proceduretype=recode_procedure_type(tender_proceduretype)) %>%
      dplyr::filter(!is.na(tender_proceduretype)) %>%
      dplyr::filter(tender_days_dec >= 0, tender_days_dec <= 730)
    req(nrow(tp) > 0)
    procs <- tp %>%
      dplyr::group_by(tender_proceduretype) %>% dplyr::filter(dplyr::n() >= 5) %>%
      dplyr::summarise(med = median(tender_days_dec, na.rm=TRUE), .groups="drop") %>%
      dplyr::arrange(med) %>% dplyr::pull(tender_proceduretype)
    req(length(procs) > 0)
    tp <- tp %>% dplyr::filter(tender_proceduretype %in% procs)
    
    n_proc <- length(procs)
    ncols  <- min(3L, n_proc)
    nrows  <- ceiling(n_proc / ncols)
    subplot_figs <- lapply(procs, function(proc) {
      d   <- tp %>% dplyr::filter(tender_proceduretype == proc) %>% dplyr::pull(tender_days_dec)
      q   <- quantile(d, c(0.25, 0.5, 0.75), na.rm=TRUE)
      mu  <- mean(d, na.rm=TRUE)
      bks <- seq(0, 730, by=10)
      cnts <- graphics::hist(d, breaks=bks, plot=FALSE)$counts
      y_top <- max(cnts, 1) * 1.15
      plotly::plot_ly() %>%
        plotly::add_histogram(
          x = ~d, xbins = list(start=0, end=730, size=10),
          marker = list(color=PA_NORMAL, line=list(color="white", width=0.4)),
          hovertemplate = "%{x} days: %{y} contracts<extra></extra>",
          showlegend = FALSE
        ) %>%
        plotly::add_segments(x=q[1],xend=q[1],y=0,yend=y_top,
                             line=list(color=PA_Q_Q1,width=1.8,dash="dash"),
                             hovertemplate=paste0("Q1: ",round(q[1],1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::add_segments(x=q[2],xend=q[2],y=0,yend=y_top,
                             line=list(color=PA_Q_MEDIAN,width=2.2,dash="solid"),
                             hovertemplate=paste0("Median: ",round(q[2],1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::add_segments(x=q[3],xend=q[3],y=0,yend=y_top,
                             line=list(color=PA_Q_Q1,width=1.8,dash="dash"),
                             hovertemplate=paste0("Q3: ",round(q[3],1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::add_segments(x=mu,xend=mu,y=0,yend=y_top,
                             line=list(color=PA_Q_MEAN,width=1.5,dash="dot"),
                             hovertemplate=paste0("Mean: ",round(mu,1)," days<extra></extra>"),showlegend=FALSE) %>%
        plotly::layout(
          annotations=list(list(text=paste0("<b>",proc,"</b>"),
                                x=0.5,y=1.05,xref="paper",yref="paper",
                                xanchor="center",yanchor="bottom",showarrow=FALSE,
                                font=list(size=11,color="#222"))),
          xaxis=list(range=c(0,730),tickfont=list(size=10),title=NULL,gridcolor="#eeeeee"),
          yaxis=list(tickfont=list(size=10),title=NULL,rangemode="nonnegative")
        )
    })
    fig <- plotly::subplot(subplot_figs, nrows=nrows, shareX=FALSE, shareY=FALSE,
                           titleX=FALSE, titleY=FALSE, margin=c(0.04,0.04,0.10,0.06))
    fig <- fig %>% plotly::layout(
      font        = list(size=11),
      hoverlabel  = list(bgcolor="white", font=list(size=12)),
      hovermode   = "closest",
      margin      = list(l=40, r=20, t=30, b=50),
      plot_bgcolor  = "#ffffff",
      paper_bgcolor = "#ffffff",
      annotations = list(list(
        text = paste0(
          "<span style='color:",PA_Q_Q1,";'>── Q1/Q3</span>  ",
          "<span style='color:",PA_Q_MEDIAN,";'>—— Median</span>  ",
          "<span style='color:",PA_Q_MEAN,";'>·· Mean</span>"
        ),
        x=0.5, y=-0.06, xref="paper", yref="paper",
        xanchor="center", yanchor="top", showarrow=FALSE,
        font=list(size=11)
      ))
    )
    admin$fig_dec_proc <- fig %>% pa_config(); admin$fig_dec_proc
  })
  
  # ── Decision share summary chart ──────────────────────────────────────
  output$dec_share_chart <- renderPlotly({
    req(admin$thresholds)
    sel_procs   <- if (length(input$dec_proc_filter) == 0) (admin$proc_type_labels %||% PROC_TYPE_LABELS) else input$dec_proc_filter
    cutoffs_dec <- admin_dec_cutoffs()
    tp_base     <- admin_decision_data() %>%
      dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
      dplyr::filter(tender_proceduretype %in% sel_procs, tender_days_dec >= 0)
    req(nrow(tp_base) > 0)
    tp_flagged <- tp_base %>%
      dplyr::left_join(cutoffs_dec, by = "tender_proceduretype") %>%
      dplyr::mutate(status = dplyr::case_when(
        !is.na(short_cut) & tender_days_dec <= short_cut                         ~ "Short",
        !no_medium & !is.na(med_min) & !is.na(med_max) &
          tender_days_dec >= med_min & tender_days_dec <= med_max                ~ "Medium",
        !is.na(long_cut)  & tender_days_dec >= long_cut                          ~ "Long",
        TRUE                                                                     ~ "Normal"
      ), status = factor(status, levels = c("Short", "Long", "Medium", "Normal")))
    share_df <- tp_flagged %>%
      dplyr::group_by(tender_proceduretype) %>%
      dplyr::summarise(
        n_total  = dplyr::n(),
        n_short  = sum(status == "Short",  na.rm = TRUE),
        n_long   = sum(status == "Long",   na.rm = TRUE),
        n_medium = sum(status == "Medium", na.rm = TRUE),
        n_norm   = sum(status == "Normal", na.rm = TRUE),
        .groups  = "drop"
      ) %>%
      dplyr::mutate(
        pct_short  = n_short  / n_total,
        pct_long   = n_long   / n_total,
        pct_medium = n_medium / n_total,
        pct_normal = n_norm   / n_total,
        proc_label = paste0(tender_proceduretype, " (n=", scales::comma(n_total), ")")
      ) %>%
      dplyr::arrange(dplyr::desc(pct_long))
    
    has_short_dec  <- any(!is.na(cutoffs_dec$short_cut)  & cutoffs_dec$tender_proceduretype %in% sel_procs) &&
      any(tp_flagged$status == "Short",  na.rm = TRUE)
    has_medium_dec <- any(!cutoffs_dec$no_medium[cutoffs_dec$tender_proceduretype %in% sel_procs], na.rm = TRUE) &&
      any(tp_flagged$status == "Medium", na.rm = TRUE)
    
    fig <- plotly::plot_ly(data = share_df, y = ~proc_label, orientation = "h")
    if (has_short_dec)
      fig <- fig %>% plotly::add_bars(x = ~pct_short,  name = "Short (too fast)",
                                      marker = list(color = PA_SHORT),
                                      hovertemplate = paste0("<b>%{y}</b><br>Short: %{x:.1%}<extra></extra>"))
    fig <- fig %>%
      plotly::add_bars(x = ~pct_long,   name = "Long",
                       marker = list(color = PA_LONG),
                       hovertemplate = paste0("<b>%{y}</b><br>Long: %{x:.1%}<extra></extra>"))
    if (has_medium_dec)
      fig <- fig %>% plotly::add_bars(x = ~pct_medium, name = "Medium",
                                      marker = list(color = PA_MEDIUM),
                                      hovertemplate = paste0("<b>%{y}</b><br>Medium: %{x:.1%}<extra></extra>"))
    fig <- fig %>%
      plotly::add_bars(x = ~pct_normal, name = "Normal",
                       marker = list(color = PA_NORMAL),
                       hovertemplate = paste0("<b>%{y}</b><br>Normal: %{x:.1%}<extra></extra>")) %>%
      plotly::layout(
        barmode     = "stack",
        xaxis       = list(title = list(text = "Share of contracts", font = list(size = 13)),
                           tickformat = ".0%", range = c(0, 1), gridcolor = "#eeeeee",
                           tickfont = list(size = 13)),
        yaxis       = list(title = "", automargin = TRUE, tickfont = list(size = 13)),
        legend      = list(orientation = "h", yanchor = "bottom", y = 1.02,
                           xanchor = "center", x = 0.5, font = list(size = 13)),
        hovermode   = "y unified",
        margin      = list(l = 10, r = 20, t = 50, b = 40),
        font        = list(size = 13),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
    admin$fig_dec_share <- fig %>% pa_config()
    admin$fig_dec_share
  })
  
  output$decision_long_plot <- renderPlotly({
    req(admin$thresholds)
    sel_procs   <- if (length(input$dec_proc_filter) == 0) (admin$proc_type_labels %||% PROC_TYPE_LABELS) else input$dec_proc_filter
    cutoffs_dec <- admin_dec_cutoffs()
    
    # Use decision days (bid deadline → award) — NOT submission days
    tp_base <- admin_decision_data() %>%
      dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
      dplyr::filter(tender_proceduretype %in% sel_procs,
                    !is.na(tender_days_dec), tender_days_dec >= 0)
    req(nrow(tp_base) > 0)
    
    tp_flagged_l <- tp_base %>%
      dplyr::left_join(cutoffs_dec, by = "tender_proceduretype") %>%
      dplyr::mutate(status = factor(dplyr::case_when(
        !is.na(short_cut) & tender_days_dec <= short_cut                         ~ "Short",
        !is.na(long_cut)  & tender_days_dec >= long_cut                          ~ "Long",
        !no_medium & !is.na(med_min) & !is.na(med_max) &
          tender_days_dec >= med_min & tender_days_dec <= med_max                ~ "Medium",
        TRUE                                                                     ~ "Normal"
      ), levels = c("Short", "Long", "Medium", "Normal")))
    
    procs_l <- sort(unique(tp_flagged_l$tender_proceduretype))
    req(length(procs_l) > 0)
    ncols_l <- min(3L, length(procs_l))
    nrows_l <- ceiling(length(procs_l) / ncols_l)
    
    # ── Build one subplot per procedure ───────────────────────────────────
    sub_figs_l <- lapply(procs_l, function(proc) {
      d_proc  <- tp_flagged_l %>% dplyr::filter(tender_proceduretype == proc)
      thr_val <- dplyr::first(na.omit(
        dplyr::pull(dplyr::filter(cutoffs_dec, tender_proceduretype == proc), long_cut)))
      if (length(thr_val) == 0) thr_val <- NA_real_
      
      pct_l <- mean(d_proc$status == "Long", na.rm = TRUE)
      n_tot <- nrow(d_proc)
      
      # x-range: 99th percentile, but always at least 1.5× threshold
      x_max <- quantile(d_proc$tender_days_dec, 0.99, na.rm = TRUE)
      x_max <- max(x_max, if (!is.na(thr_val)) thr_val * 1.5 else 100, 50)
      
      # Tight bins: 2-3 days for decision periods
      binw <- min(3, max(1, round(x_max / 80)))
      
      cutrow     <- cutoffs_dec %>% dplyr::filter(tender_proceduretype == proc)
      short_val  <- if (nrow(cutrow) > 0 && !is.na(cutrow$short_cut[1]))  cutrow$short_cut[1]  else NA_real_
      no_med_val <- if (nrow(cutrow) > 0) isTRUE(cutrow$no_medium[1]) else TRUE
      med_lo     <- if (!no_med_val && nrow(cutrow) > 0) cutrow$med_min[1] else NA_real_
      med_hi     <- if (!no_med_val && nrow(cutrow) > 0) cutrow$med_max[1] else NA_real_
      
      STATUS_COLS <- c(
        Short  = PA_SHORT,   # deep red  — too short/fast (same flag colour as Long)
        Long   = PA_LONG,    # deep red  — too long/slow
        Medium = PA_MEDIUM,  # amber     — medium band
        Normal = PA_NORMAL   # steel blue — normal
      )
      pct_l   <- mean(d_proc$status == "Long",  na.rm = TRUE)
      pct_s   <- mean(d_proc$status == "Short", na.rm = TRUE)
      n_tot   <- nrow(d_proc)
      
      traces <- plotly::plot_ly()
      for (st in c("Normal", "Medium", "Long", "Short")) {
        d_st <- d_proc %>% dplyr::filter(status == st) %>%
          dplyr::pull(tender_days_dec) %>% .[. <= x_max]
        if (length(d_st) == 0) next
        traces <- traces %>% plotly::add_histogram(
          x      = d_st,
          xbins  = list(start = 0, end = x_max + binw, size = binw),
          name   = st, legendgroup = st, showlegend = FALSE,
          marker = list(color = STATUS_COLS[[st]], line = list(color = "white", width = 0.3)),
          hovertemplate = paste0("<b>", st, "</b>: %{y} contracts<extra></extra>")
        )
      }
      
      shape_list <- list()
      if (!is.na(thr_val)) {
        shape_list <- c(shape_list, list(
          list(type = "line", x0 = thr_val, x1 = thr_val, y0 = 0, y1 = 1,
               xref = "x", yref = "paper",
               line = list(color = PA_LONG,  width = 1.8, dash = "dash")),
          list(type = "rect", x0 = thr_val, x1 = x_max + binw, y0 = 0, y1 = 1,
               xref = "x", yref = "paper",
               fillcolor = "rgba(198,40,40,0.08)", line = list(width = 0))
        ))
      }
      if (!is.na(short_val)) {
        shape_list <- c(shape_list, list(
          list(type = "line", x0 = short_val, x1 = short_val, y0 = 0, y1 = 1,
               xref = "x", yref = "paper",
               line = list(color = PA_SHORT, width = 1.5, dash = "dash")),
          list(type = "rect", x0 = 0, x1 = short_val, y0 = 0, y1 = 1,
               xref = "x", yref = "paper",
               fillcolor = "rgba(198,40,40,0.08)", line = list(width = 0))
        ))
      }
      if (!no_med_val && !is.na(med_lo) && !is.na(med_hi)) {
        shape_list <- c(shape_list, list(
          list(type = "rect", x0 = med_lo, x1 = med_hi, y0 = 0, y1 = 1,
               xref = "x", yref = "paper",
               fillcolor = "rgba(245,158,11,0.13)", line = list(width = 0))
        ))
      }
      
      sub_txt <- paste0(
        if (!is.na(thr_val))   paste0("\u2265", round(thr_val),   "d too-long  \u2502  ") else "",
        if (!is.na(short_val)) paste0("\u2264", round(short_val), "d too-short  \u2502  ") else "",
        scales::percent(pct_l, accuracy = 0.1), " long",
        if (pct_s > 0) paste0("  ", scales::percent(pct_s, accuracy = 0.1), " short") else "",
        "  (n=", scales::comma(n_tot), ")"
      )
      
      traces %>% plotly::layout(
        barmode = "stack",
        shapes  = shape_list,
        # Title baked into xaxis title so it sits below the panel, not above —
        # avoids subplot annotation coordinate collision entirely
        xaxis = list(
          title      = list(text = sub_txt, font = list(size = 11, color = "#555")),
          tickfont   = list(size = 11),
          gridcolor  = "#eeeeee",
          rangemode  = "nonnegative",
          automargin = TRUE
        ),
        yaxis = list(tickfont = list(size = 13), title = NULL, rangemode = "nonnegative")
      )
    })
    
    # ── Combine subplots ─────────────────────────────────────────────────
    # Use a generous row gap so titles don't bleed into neighbour panels
    row_gap <- if (nrows_l == 1) 0.06 else 0.14
    fig <- plotly::subplot(
      sub_figs_l,
      nrows   = nrows_l,
      shareX  = FALSE, shareY = FALSE,
      titleX  = TRUE,  titleY = FALSE,
      margin  = c(0.04, 0.04, row_gap, 0.06)
    )
    
    # ── Add per-panel procedure-name titles via domain arithmetic ─────────
    # subplot() lays panels left-to-right, top-to-bottom.
    # Domain of axis i (1-based) can be read from fig$x$layout.
    # We compute it manually: equal columns, equal rows.
    col_w  <- (1 - 0.04 * (ncols_l - 1)) / ncols_l
    row_h  <- (1 - row_gap * (nrows_l - 1)) / nrows_l
    panel_annotations <- lapply(seq_along(procs_l), function(i) {
      col_i  <- ((i - 1) %% ncols_l)          # 0-based
      row_i  <- ((i - 1) %/% ncols_l)          # 0-based, 0 = top
      x_mid  <- col_i * (col_w + 0.04) + col_w / 2
      # rows go top-to-bottom: row 0 has y_top near 1
      y_top  <- 1 - row_i * (row_h + row_gap)
      list(
        text      = paste0("<b>", procs_l[i], "</b>"),
        x         = x_mid,
        y         = y_top + 0.015,
        xref      = "paper", yref = "paper",
        xanchor   = "center", yanchor = "bottom",
        showarrow = FALSE,
        font      = list(size = 12, color = "#2c3e50")
      )
    })
    
    legend_ann <- list(
      text      = paste0(
        "<span style='color:", PA_LONG,   ";'>▪ Long (flagged)</span>   ",
        "<span style='color:", PA_NORMAL, ";'>▪ Normal</span>   ",
        "<span style='color:#cc0000;'>‒ ‒ threshold</span>"
      ),
      x = 0.5, y = -0.03, xref = "paper", yref = "paper",
      xanchor = "center", yanchor = "top", showarrow = FALSE,
      font = list(size = 12)
    )
    
    fig <- fig %>% plotly::layout(
      font          = list(size = 12),
      hoverlabel    = list(bgcolor = "white", font = list(size = 12)),
      hovermode     = "closest",
      margin        = list(l = 45, r = 20, t = 35, b = 55),
      plot_bgcolor  = "#ffffff",
      paper_bgcolor = "#ffffff",
      annotations   = c(panel_annotations, list(legend_ann))
    )
    admin$fig_dec_long <- fig %>% pa_config(); admin$fig_dec_long
  })
  
  output$buyer_long_plot <- renderPlotly({
    req(admin$thresholds)
    cutoffs_dec <- admin_dec_cutoffs()
    # DECISION days (award decision − bid deadline) — this chart flags long
    # DECISION periods, so it must not be built from submission days.
    tp_base     <- admin_decision_data() %>%
      dplyr::mutate(tender_proceduretype = recode_procedure_type(tender_proceduretype)) %>%
      dplyr::filter(!is.na(tender_proceduretype),
                    tender_proceduretype %in% admin$global_proc_filter,
                    !is.na(tender_days_dec), tender_days_dec >= 0, tender_days_dec <= 730)
    req(nrow(tp_base) > 0)
    tp_buyer <- tp_base %>% dplyr::left_join(cutoffs_dec,by="tender_proceduretype") %>%
      dplyr::mutate(long_decision=tender_days_dec>=long_cut, buyer_group=add_buyer_group(buyer_buyertype))
    req(nrow(tp_buyer)>0)
    by_count <- tp_buyer %>%
      dplyr::group_by(buyer_group,tender_proceduretype) %>%
      dplyr::summarise(n_long=sum(long_decision,na.rm=TRUE),n_total=dplyr::n(),share_long=mean(long_decision,na.rm=TRUE),.groups="drop") %>%
      dplyr::mutate(share_other=1-share_long,
                    tip_l=paste0(buyer_group," | ",tender_proceduretype,"<br><b>Long: ",scales::percent(share_long,accuracy=0.1),"</b> (",n_long," of ",n_total,")"),
                    tip_n=paste0(buyer_group," | ",tender_proceduretype,"<br>Normal: ",scales::percent(1-share_long,accuracy=0.1)),metric="Count")
    .long_pc  <- intersect(c("bid_priceusd","bid_price","lot_estimatedpriceusd","lot_estimatedprice"),
                           names(tp_buyer))[1]
    .long_loc <- (admin$local_currency %||% list(label="NC"))$label
    by_value <- if (!is.na(.long_pc)) {
      tp_buyer %>%
        dplyr::group_by(buyer_group, tender_proceduretype) %>%
        dplyr::summarise(
          total_value = sum(.data[[.long_pc]], na.rm = TRUE),
          long_value  = sum(.data[[.long_pc]][long_decision %in% TRUE], na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::mutate(
          share_long  = dplyr::if_else(total_value > 0, long_value / total_value, 0),
          share_other = 1 - share_long,
          tip_l = paste0(buyer_group, " | ", tender_proceduretype,
                         "<br><b>Long: ", scales::percent(share_long, accuracy=0.1), "</b><br>",
                         round(long_value * 1e-6, 1), "M of ", round(total_value * 1e-6, 1), "M ", .long_loc),
          tip_n = paste0(buyer_group, " | ", tender_proceduretype,
                         "<br>Normal: ", scales::percent(1 - share_long, accuracy=0.1)),
          metric = "Contract Value")
    } else {
      tp_buyer %>%
        dplyr::group_by(buyer_group, tender_proceduretype) %>%
        dplyr::summarise(total_value = NA_real_, long_value = NA_real_, .groups = "drop") %>%
        dplyr::mutate(share_long = NA_real_, share_other = NA_real_,
                      tip_l = "No price data", tip_n = "No price data", metric = "Contract Value")
    }
    
    # Perceptually distinct palette — same as buyer_short_plot for consistency
    PA_PROC_PAL <- c(
      "#1A6FAF",  # steel blue
      "#2CA02C",  # green
      "#D62728",  # red
      "#FF7F0E",  # orange
      "#9467BD",  # purple
      "#17BECF",  # cyan
      "#E377C2",  # pink
      "#8C564B",  # brown
      "#7F7F7F"   # grey
    )
    all_procs_l <- sort(unique(by_count$tender_proceduretype))
    proc_pal_l  <- setNames(PA_PROC_PAL[seq_along(all_procs_l)], all_procs_l)
    buyers_ord_l <- sort(unique(by_count$buyer_group))
    
    make_buyer_bar_long <- function(df, share_col, n_col, hover_label, show_legend = TRUE) {
      df <- df %>% dplyr::mutate(
        hover_txt = paste0(
          "<b>", buyer_group, " | ", tender_proceduretype, "</b><br>",
          hover_label, ": ", scales::percent(.data[[share_col]], accuracy=0.1), "<br>",
          "N: ", scales::comma(.data[[n_col]])
        )
      )
      fig <- plotly::plot_ly()
      procs_l3 <- sort(unique(df$tender_proceduretype))
      for (proc in procs_l3) {
        d_p <- df %>% dplyr::filter(tender_proceduretype == proc) %>%
          dplyr::arrange(match(buyer_group, buyers_ord_l))
        fig <- fig %>% plotly::add_bars(
          x           = ~buyer_group, y = ~.data[[share_col]],
          data        = d_p,
          name        = proc, legendgroup = proc,
          showlegend  = show_legend,
          marker      = list(color=proc_pal_l[[proc]], line=list(color="white",width=0.5)),
          hovertext   = ~hover_txt, hoverinfo="text"
        )
      }
      fig %>% plotly::layout(
        barmode = "group",
        xaxis   = list(title = list(text = "Buyer Group", font = list(size = 13)),
                       tickfont = list(size = 13), automargin = TRUE),
        yaxis   = list(title = list(text=hover_label, font=list(size=13)),
                       tickformat=".0%", range=c(0,1),
                       tickfont=list(size=13), gridcolor="#eeeeee"),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff",
        margin        = list(l=65, r=10, t=10, b=10)
      )
    }
    
    p_count_l3 <- make_buyer_bar_long(
      by_count %>% dplyr::rename(n_col=n_total),
      "share_long", "n_col", "% long by count", show_legend = TRUE)
    p_value_l3 <- make_buyer_bar_long(
      by_value %>% dplyr::mutate(n_col=round(total_value/1e6)),
      "share_long", "n_col", "% long by value", show_legend = FALSE)
    
    view_sel <- input$dec_buyer_view %||% "count"
    p_out <- if (view_sel == "count") {
      p_count_l3 %>% plotly::layout(
        hoverlabel = list(bgcolor="white", font=list(size=13)),
        font = list(size=13),
        legend = list(orientation="h", yanchor="top", y=-0.18,
                      xanchor="center", x=0.5, font=list(size=13)),
        margin = list(l=65, r=20, t=40, b=110))
    } else if (view_sel == "value") {
      p_value_l3 %>% plotly::layout(
        hoverlabel = list(bgcolor="white", font=list(size=13)),
        font = list(size=13),
        legend = list(orientation="h", yanchor="top", y=-0.18,
                      xanchor="center", x=0.5, font=list(size=13)),
        margin = list(l=65, r=20, t=40, b=110))
    } else {
      plotly::subplot(p_count_l3, p_value_l3, nrows=2,
                      shareX=TRUE, shareY=FALSE,
                      titleX=FALSE, titleY=TRUE, margin=0.08) %>%
        plotly::layout(
          hoverlabel = list(bgcolor="white", font=list(size=13)),
          font = list(size=13),
          legend = list(orientation="h", yanchor="top", y=-0.10,
                        xanchor="center", x=0.5, font=list(size=13)),
          margin = list(l=65, r=20, t=40, b=110))
    }
    admin$fig_buyer_long <- p_out %>% pa_config(); admin$fig_buyer_long
  })
  
  
  # [APP-SV23] ADMIN REGRESSION OUTPUTS ──────────────────────────────────────
  # ============================================================
  # ADMIN REGRESSION OUTPUTS
  # ============================================================
  
  output$short_reg_plot_ui <- renderUI({
    if (!is.null(admin$filtered_analysis$plot_short_reg)) plotOutput("short_reg_plot", height="600px")
    else p("No regression results available. Click 'Run / Re-run Regressions' above.")
  })
  output$short_reg_plot <- renderPlot({ req(admin$filtered_analysis$plot_short_reg); print(admin$filtered_analysis$plot_short_reg) })
  output$dl_short_reg_ui <- renderUI({
    if (!is.null(admin$filtered_analysis$plot_short_reg))
      downloadButton("dl_short_reg", "Download Figure", class="download-btn btn-sm")
  })
  
  output$long_reg_plot_ui <- renderUI({
    if (!is.null(admin$filtered_analysis$plot_long_reg)) plotOutput("long_reg_plot", height="600px")
    else p("No regression results available.")
  })
  output$long_reg_plot <- renderPlot({ req(admin$filtered_analysis$plot_long_reg); print(admin$filtered_analysis$plot_long_reg) })
  output$dl_long_reg_ui <- renderUI({
    if (!is.null(admin$filtered_analysis$plot_long_reg))
      downloadButton("dl_long_reg", "Download Figure", class="download-btn btn-sm")
  })
  
  
  # [APP-SV24] ROBUSTNESS CHECKS — shared spec-plot/table/verdict builders ────
  # ============================================================
  # ROBUSTNESS CHECKS — shared helpers
  # ============================================================
  
  # Pretty-print FE / cluster / controls labels
  .fe_label <- function(x) dplyr::case_when(
    x == "0"          ~ "None",
    x == "buyer"      ~ "Buyer",
    x == "year"       ~ "Year",
    x == "buyer+year" ~ "Buyer + Year",
    x == "buyer#year" ~ "Buyer \u00d7 Year",
    TRUE ~ x)
  .cl_label <- function(x) dplyr::case_when(
    x == "none"            ~ "None",
    x == "buyer"           ~ "Buyer",
    x == "year"            ~ "Year",
    x == "buyer_year"      ~ "Buyer + Year",
    x == "buyer_buyertype" ~ "Buyer type",
    TRUE ~ x)
  .ctrl_label <- function(x) dplyr::case_when(
    x == "x_only"     ~ "None",
    x == "base"       ~ "Base",
    x == "base_extra" ~ "Full",
    TRUE ~ x)
  
  # Build specification coefficient plot (dot per spec, sorted by estimate)
  .build_spec_coeff_plot <- function(specs) {
    if (is.null(specs) || nrow(specs) == 0) return(plotly::plot_ly())
    d <- specs %>%
      dplyr::mutate(
        FE_l   = .fe_label(fe),
        Cl_l   = .cl_label(cluster),
        Ct_l   = .ctrl_label(controls),
        model_l = if ("model_type" %in% names(specs)) as.character(model_type) else "",
        spec_label = if ("model_type" %in% names(specs))
          paste0(model_l, " | FE: ", FE_l, " | Cluster: ", Cl_l, " | Controls: ", Ct_l)
        else
          paste0("FE: ", FE_l, " | Cluster: ", Cl_l, " | Controls: ", Ct_l),
        sig_p10  = pvalue <= 0.10,
        sig_p05  = pvalue <= 0.05,
        dot_col  = dplyr::case_when(
          sig_p05  ~ "#00695C",   # dark teal = p<=0.05
          sig_p10  ~ "#26A69A",   # mid teal  = p<=0.10
          TRUE     ~ "#94A3B8"    # grey = not significant
        ),
        sig_text = dplyr::case_when(
          sig_p05  ~ "\u2713\u2713 p \u2264 0.05",
          sig_p10  ~ "\u2713 p \u2264 0.10",
          TRUE     ~ "\u2717 p > 0.10"
        ),
        nobs_fmt = if ("nobs" %in% names(specs)) scales::comma(nobs) else "N/A",
        tip = paste0(
          "<b>", spec_label, "</b><br>",
          "Estimate: <b>", round(estimate, 4), "</b><br>",
          "P-value: <b>", round(pvalue, 3), "</b><br>",
          "N obs: ", nobs_fmt, "<br>",
          sig_text
        )
      ) %>%
      dplyr::arrange(estimate)
    
    plotly::plot_ly(
      d,
      x = ~estimate, y = ~factor(spec_label, levels = spec_label),
      type    = "scatter", mode = "markers",
      marker  = list(color = ~dot_col, size = 11,
                     line = list(color = "white", width = 1.5)),
      text    = ~tip, hoverinfo = "text"
    ) %>%
      plotly::layout(
        shapes = list(list(
          type  = "line", x0 = 0, x1 = 0, y0 = 0, y1 = 1, yref = "paper",
          line  = list(color = "#DC2626", width = 1.5, dash = "dash")
        )),
        xaxis = list(title = "Coefficient estimate", zeroline = FALSE,
                     gridcolor = "#F1F5F9"),
        yaxis = list(title = "", tickfont = list(size = 10), automargin = TRUE),
        hoverlabel = list(bgcolor = "white", font = list(size = 11)),
        hovermode  = "closest",
        margin     = list(l = 10, r = 20, t = 10, b = 50),
        paper_bgcolor = "#ffffff", plot_bgcolor = "#ffffff"
      ) %>%
      plotly::config(displayModeBar = FALSE)
  }
  
  # Build specification detail table
  .build_spec_table <- function(specs) {
    if (is.null(specs) || nrow(specs) == 0)
      return(DT::datatable(data.frame(Message = "No specifications available."),
                           rownames = FALSE, options = list(dom = "t")))
    tbl <- specs %>%
      dplyr::mutate(
        `Model`    = if ("model_type" %in% names(specs)) as.character(model_type) else "",
        `FE`       = .fe_label(fe),
        `Cluster`  = .cl_label(cluster),
        `Controls` = .ctrl_label(controls),
        `Estimate` = round(estimate, 4),
        `P-value`  = round(pvalue, 3),
        `Sig.`     = dplyr::case_when(
          pvalue <= 0.05 ~ "\u2713\u2713",
          pvalue <= 0.10 ~ "\u2713",
          TRUE           ~ ""),
        `N obs`    = if ("nobs" %in% names(specs)) scales::comma(nobs) else NA_character_,
        `Collinear` = if ("n_collinear" %in% names(specs)) as.character(n_collinear) else NA_character_,
        `% Retained` = if ("pct_retained" %in% names(specs))
          ifelse(is.na(pct_retained), NA_character_, paste0(round(pct_retained * 100), "%")) else NA_character_,
        `OOR %` = if ("out_of_range_pct" %in% names(specs))
          ifelse(is.na(out_of_range_pct), "\u2014", paste0(round(out_of_range_pct * 100, 1), "%")) else NA_character_,
        `Conv.` = if ("converged" %in% names(specs))
          ifelse(is.na(converged) | converged, "\u2713", "\u2717") else NA_character_
      ) %>%
      dplyr::arrange(pvalue) %>%
      dplyr::select(dplyr::any_of(c("Model","FE","Cluster","Controls",
                                    "Estimate","P-value","Sig.","N obs",
                                    "Collinear","% Retained","OOR %","Conv.")))
    
    # Drop Model column if all blank
    if ("Model" %in% names(tbl) && all(nchar(trimws(tbl$Model)) == 0))
      tbl <- dplyr::select(tbl, -Model)
    # Drop diagnostic columns if all NA
    for (dc in c("Collinear", "% Retained", "OOR %", "Conv."))
      if (dc %in% names(tbl) && all(is.na(tbl[[dc]])))
        tbl[[dc]] <- NULL
    
    DT::datatable(
      tbl,
      rownames = FALSE,
      options  = list(pageLength = 20, scrollX = TRUE, dom = "tip",
                      columnDefs = list(list(className = "dt-center", targets = "_all"))),
      style    = "bootstrap"
    ) %>%
      DT::formatStyle("P-value",
                      backgroundColor = DT::styleInterval(
                        c(0.05, 0.10), c("#C8E6C9", "#FFF9C4", "white"))) %>%
      DT::formatStyle("Sig.",
                      color      = DT::styleEqual(c("\u2713\u2713", "\u2713", ""),
                                                  c("#1B5E20",     "#00695C", "#94A3B8")),
                      fontWeight = "bold")
  }
  
  # Summary verdict card + chart link + table link — used in renderUI
  build_robustness_ui <- function(bundle, plot_output_id, table_output_id, n_specs_hint = 20L) {
    has_rows   <- function(tbl) !is.null(tbl) && is.data.frame(tbl) && nrow(tbl) > 0
    share_pos  <- if (has_rows(bundle$overall)) bundle$overall$share_positive else NA
    share_p10  <- if (has_rows(bundle$overall)) {
      cn  <- names(bundle$overall)
      col <- cn[grepl("share_p_le_0.1", cn, fixed = TRUE)]
      if (length(col) > 0) bundle$overall[[col[1]]] else NA
    } else NA
    share_p05  <- if (has_rows(bundle$overall)) {
      cn  <- names(bundle$overall)
      col <- cn[grepl("share_p_le_0.05", cn, fixed = TRUE)]
      if (length(col) > 0) bundle$overall[[col[1]]] else NA
    } else NA
    sign_stable <- if (has_rows(bundle$sign)) bundle$sign$share_sign_stable else NA
    median_est  <- if (has_rows(bundle$overall)) bundle$overall$median_estimate else NA
    median_p    <- if (has_rows(bundle$overall)) bundle$overall$median_pvalue   else NA
    n_specs_val <- if (has_rows(bundle$overall)) bundle$overall$n_specs else n_specs_hint
    
    if (!is.na(share_pos) && !is.na(share_p10) && !is.na(sign_stable)) {
      if      (share_pos >= 0.7 && share_p10 >= 0.6 && sign_stable == 1)
      { verdict <- "\u2713 Strong and robust evidence."; vcol <- "success" }
      else if (share_pos >= 0.6 && share_p10 >= 0.3)
      { verdict <- "\u26a0 Moderate evidence."; vcol <- "warning" }
      else
      { verdict <- "\u2717 Weak or mixed evidence \u2014 best available model shown."; vcol <- "danger" }
    } else {
      verdict <- "\u2139 Robustness summary not available."; vcol <- "info"
    }
    
    chart_h <- paste0(max(260, min(680, as.integer(n_specs_val) * 24 + 70)), "px")
    
    tagList(
      # ── Summary verdict card ──────────────────────────────────────────────
      div(class = paste0("alert alert-", vcol), style = "margin-top:10px; margin-bottom:18px;",
          h4(style = "margin-top:0; font-size:15px;", "Summary for Decision-Makers"),
          p(strong(verdict)),
          fluidRow(
            column(6, tags$ul(style = "margin-bottom:0;",
                              if (!is.na(n_specs_val)) tags$li(strong(n_specs_val), " model specifications tested"),
                              if (!is.na(share_pos))   tags$li(scales::percent(share_pos,  accuracy = 1),
                                                               " of specs show a positive estimate"),
                              if (!is.na(share_p10))   tags$li(scales::percent(share_p10,  accuracy = 1),
                                                               " significant at p \u2264 0.10")
            )),
            column(6, tags$ul(style = "margin-bottom:0;",
                              if (!is.na(share_p05))   tags$li(scales::percent(share_p05,  accuracy = 1),
                                                               " significant at p \u2264 0.05"),
                              if (!is.na(sign_stable)) tags$li("Sign stable across all specs: ",
                                                               strong(if (isTRUE(sign_stable == 1)) "Yes \u2713" else "No \u2717")),
                              if (!is.na(median_est))  tags$li("Median estimate: ", strong(sprintf("%.4f", median_est))),
                              if (!is.na(median_p))    tags$li("Median p-value:  ", strong(sprintf("%.3f", median_p)))
            ))
          )
      ),
      # ── Coefficient chart ─────────────────────────────────────────────────
      h5(style = "font-weight:700; color:var(--navy); margin-bottom:4px;",
         "All Specifications — Coefficient Chart"),
      div(class = "description-box",
          p(style = "margin:0; font-size:12px;",
            "Each dot is one model specification.",
            " \U0001F7E2 Dark teal = p \u2264 0.05; ",
            "\U0001F7E1 mid-teal = p \u2264 0.10; ",
            "\u26AA grey = not significant.",
            " Hover for exact values. Red dashed line = zero effect.")),
      plotlyOutput(plot_output_id, height = chart_h),
      br(),
      # ── Specification table ───────────────────────────────────────────────
      h5(style = "font-weight:700; color:var(--navy); margin-bottom:4px;",
         "All Specifications — Detail Table"),
      p(style = "font-size:12px; color:#64748B; margin-bottom:6px;",
        "Sorted by p-value (best first)."),
      DT::dataTableOutput(table_output_id),
      br(),
      # ── Explainer accordion ───────────────────────────────────────────────
      tags$details(style = "margin-top:12px;",
                   tags$summary(style = "cursor:pointer; font-weight:bold; font-size:13px;",
                                "What are robustness checks?"),
                   div(style = "margin-top:8px; font-size:13px;",
                       p("Robustness checks test whether the headline finding holds across ",
                         "different modelling choices: which fixed effects to include, how to cluster ",
                         "standard errors, and which control variables to add.",
                         " A result is considered ", strong("robust"), " when the sign and significance ",
                         "are consistent across most specifications.",
                         " When evidence is mixed, the best available model is still shown — but you",
                         " should treat the effect size estimate with extra caution.")))
    )
  }
  
  make_formula_ui <- function(m, best_row = NULL, is_robust = NULL, label = "this indicator",
                              marginal_effect = NULL,
                              outcome_label   = "single bidding",
                              interp_override = NULL,
                              formula_text    = NULL) {
    # outcome_label   — outcome name used in the plain-language sentences
    #                   (the default matches the admin panels' wording).
    # interp_override — a fully-built plain-language sentence for models whose
    #                   treatment is continuous (the 0->1 "flagged" phrasing
    #                   only fits binary indicators); the significance clause
    #                   is appended automatically.
    # formula_text    — technical formula string for models where the fitted
    #                   object is not available (integrity regressions pass a
    #                   reconstruction from the best_row specification).
    if (is.null(m) && is.null(best_row)) return(NULL)
    fml   <- if (!is.null(formula_text)) formula_text
    else if (!is.null(m)) tryCatch(paste(deparse(formula(m), width.cutoff = 120), collapse = " "), error = function(e) NULL) else NULL
    n_obs <- if (!is.null(m)) tryCatch(nobs(m), error = function(e) NA) else
      if (!is.null(best_row) && "nobs" %in% names(best_row)) best_row$nobs else NA
    
    # Model type
    mt_label <- if (!is.null(best_row) && "model_type" %in% names(best_row)) {
      switch(as.character(best_row$model_type),
             "fractional_logit" = "Fractional Logit (quasi-binomial, logit link)",
             "lpm"              = "Linear Probability Model (OLS)",
             "probit"           = "Probit (binomial, probit link)",
             "ols_level"        = "OLS (levels)",
             "ols_log"          = "OLS (log-transformed outcome)",
             "gamma_log"        = "Gamma GLM (log link)",
             as.character(best_row$model_type))
    } else "binomial (logit)"
    
    # FE / cluster / controls labels
    fe_label <- if (!is.null(best_row)) {
      switch(as.character(best_row$fe),
             "0" = "None", "buyer" = "Buyer", "year" = "Year",
             "buyer+year" = "Buyer + Year", "buyer#year" = "Buyer \u00d7 Year",
             as.character(best_row$fe))
    } else "N/A"
    cl_label <- if (!is.null(best_row)) {
      switch(as.character(best_row$cluster),
             "none" = "None", "buyer" = "Buyer", "year" = "Year",
             "buyer_year" = "Buyer + Year", "buyer_buyertype" = "Buyer type",
             as.character(best_row$cluster))
    } else "N/A"
    ctrl_label <- if (!is.null(best_row)) {
      switch(as.character(best_row$controls),
             "x_only" = "No controls (indicator only)",
             "base"   = "Base (buyer type + procedure type)",
             "base_extra" = "Full (buyer type + procedure type + contract value)",
             as.character(best_row$controls))
    } else "N/A"
    
    est_val <- if (!is.null(best_row) && "estimate" %in% names(best_row)) round(best_row$estimate, 4) else NA
    p_val   <- if (!is.null(best_row) && "pvalue" %in% names(best_row))  round(best_row$pvalue, 4)   else NA
    
    # Robustness badge
    robust_badge <- if (isTRUE(is_robust))
      span(style = "color:#1B5E20; font-weight:bold;", "\u2713 ROBUST")
    else if (identical(is_robust, FALSE))
      span(style = "color:#C62828; font-weight:bold;", "\u2717 NOT ROBUST")
    else NULL
    
    # ── Real-number interpretation ──────────────────────────────────────
    .sig_clause <- function(p_val) {
      if (!is.na(p_val) && p_val <= 0.05) " This effect is statistically significant (p \u2264 0.05)."
      else if (!is.na(p_val) && p_val <= 0.10) " This effect is marginally significant (p \u2264 0.10)."
      else " This effect is not statistically significant at conventional levels."
    }
    interp_text <- NULL
    if (!is.null(interp_override)) {
      interp_text <- paste0(interp_override, .sig_clause(p_val))
    } else if (!is.null(marginal_effect) && !is.null(marginal_effect$diff)) {
      me  <- marginal_effect
      dir <- if (me$diff > 0) "increases" else "decreases"
      interp_text <- paste0(
        "When ", label, " is flagged (value changes from 0 to 1), ",
        "the predicted probability of ", outcome_label, " ", dir, " from ",
        sprintf("%.1f%%", me$at_0 * 100), " to ", sprintf("%.1f%%", me$at_1 * 100),
        " — a change of ", sprintf("%+.1f", me$diff * 100), " percentage points.",
        if (!is.na(p_val) && p_val <= 0.05) " This effect is statistically significant (p \u2264 0.05)."
        else if (!is.na(p_val) && p_val <= 0.10) " This effect is marginally significant (p \u2264 0.10)."
        else " This effect is not statistically significant at conventional levels."
      )
    } else if (!is.null(best_row) && is.numeric(est_val) && !is.na(est_val)) {
      dir <- if (est_val > 0) "higher" else "lower"
      interp_text <- paste0(
        "The model estimates that ", label,
        " is associated with ", dir, " ", outcome_label, " (coefficient = ", est_val,
        ", p = ", if (!is.na(p_val)) p_val else "N/A", ").",
        if (!is.na(p_val) && p_val <= 0.05) " Statistically significant at the 5% level."
        else if (!is.na(p_val) && p_val <= 0.10) " Marginally significant at the 10% level."
        else " Not statistically significant at conventional levels."
      )
    }
    
    # Selection rationale
    selection_text <- if (isTRUE(is_robust))
      paste0("This model was selected from all significant (p \u2264 0.10) positive specifications ",
             "using econometric diagnostic checks. Models are penalised for: ",
             "(1) inappropriate functional form for the dependent variable type ",
             "(e.g. LPM for binary outcomes produces heteroskedastic errors and out-of-range predictions), ",
             "(2) multicollinearity (variables dropped by the estimator due to perfect collinearity), ",
             "(3) low effective sample (excessive observation loss from fixed-effect singleton removal), ",
             "(4) omitted controls (increases omitted variable bias), ",
             "(5) unclustered standard errors (inappropriate for panel data). ",
             "Models that failed to converge or retained less than 20% of data were excluded entirely. ",
             "Among the top-scoring specifications, the one closest to the median estimate was chosen ",
             "(specification curve analysis; Simonsohn et al., 2020).")
    else
      paste0("No specification met the robustness criteria (\u226570% positive, \u226560% significant, stable sign). ",
             "This model was selected using the same diagnostic scoring without requiring statistical significance: ",
             "convergence, DV-model match, collinearity, sample retention, controls, and clustering. ",
             "It represents the most diagnostically sound specification available, ",
             "but the effect should be interpreted as suggestive evidence only.")
    
    div(style = "margin-top:14px; padding-top:12px; border-top:1px solid #e8e8e8;",
        # Header with robustness badge
        div(style = "display:flex; align-items:center; gap:12px; margin-bottom:10px;",
            h5(style = "margin:0; font-weight:700; color:#334155;", "Selected Model"),
            robust_badge
        ),
        # Plain-language interpretation box
        if (!is.null(interp_text))
          div(style = "background:#F0F9FF; border-left:3px solid #0284C7; padding:10px 14px;
                     margin-bottom:12px; font-size:14.5px; color:#334155; line-height:1.55;",
              icon("lightbulb", style = "color:#0284C7; margin-right:6px;"),
              interp_text)
        else NULL,
        # Model details table
        div(style = "display:grid; grid-template-columns:160px 1fr; gap:4px 12px;
                   font-size:14px; color:#555; margin-bottom:10px;",
            span(style = "font-weight:bold;", "Model type:"),      span(mt_label),
            span(style = "font-weight:bold;", "Fixed effects:"),    span(fe_label),
            span(style = "font-weight:bold;", "Std. error cluster:"), span(cl_label),
            span(style = "font-weight:bold;", "Controls:"),         span(ctrl_label),
            span(style = "font-weight:bold;", "Estimate:"),         span(if (!is.na(est_val)) est_val else "N/A"),
            span(style = "font-weight:bold;", "P-value:"),          span(if (!is.na(p_val)) p_val else "N/A"),
            span(style = "font-weight:bold;", "Observations:"),
            span(if (!is.na(n_obs)) format(n_obs, big.mark = ",") else "N/A")
        ),
        # Selection rationale
        tags$details(style = "margin-top:8px;",
                     tags$summary(style = "cursor:pointer; font-size:13px; color:#666; font-weight:bold;",
                                  "Why was this model selected?"),
                     div(style = "margin-top:6px; font-size:13px; color:#555; line-height:1.55;",
                         p(selection_text))),
        # Formula (technical)
        if (!is.null(fml))
          tags$details(style = "margin-top:6px;",
                       tags$summary(style = "cursor:pointer; font-size:13px; color:#666; font-weight:bold;",
                                    "Technical formula"),
                       div(style = "background:#f8f9fa; border-left:3px solid #f0ad4e; padding:8px 12px;
                       font-family:monospace; font-size:12.5px; margin-top:6px; overflow-x:auto;",
                           fml))
        else NULL
    )
  }
  
  # Reconstruct a display formula from a best_row specification (used by the
  # integrity panels, where the fitted model object is not stored).
  .pa_formula_from_row <- function(y, x, best_row, controls_map) {
    ctrl  <- as.character(best_row$controls %||% "x_only")
    ctrls <- controls_map[[ctrl]] %||% character(0)
    fe    <- as.character(best_row$fe %||% "0")
    fe_p  <- switch(fe,
                    "0"          = "0",
                    "buyer"      = "buyer_masterid",
                    "year"       = "tender_year",
                    "buyer+year" = "buyer_masterid + tender_year",
                    "buyer#year" = "buyer_masterid^tender_year",
                    fe)
    cl <- as.character(best_row$cluster %||% "none")
    paste0(y, " ~ ", paste(c(x, ctrls), collapse = " + "), " | ", fe_p,
           if (cl != "none") paste0("    [SEs clustered by ", cl, "]") else "")
  }
  
  output$short_reg_formula_ui <- renderUI({
    make_formula_ui(
      admin$filtered_analysis$model_short_glm,
      best_row        = admin$filtered_analysis$best_row_short,
      is_robust       = admin$filtered_analysis$is_robust_short,
      label           = "short submission period",
      marginal_effect = admin$filtered_analysis$marginal_short
    )
  })
  output$long_reg_formula_ui <- renderUI({
    make_formula_ui(
      admin$filtered_analysis$model_long_glm,
      best_row        = admin$filtered_analysis$best_row_long,
      is_robust       = admin$filtered_analysis$is_robust_long,
      label           = "long decision period",
      marginal_effect = admin$filtered_analysis$marginal_long
    )
  })
  
  # ── Admin robustness check outputs ────────────────────────────────────────
  output$short_robustness_plot <- renderPlotly({
    req(admin$filtered_analysis$specs_short)
    .build_spec_coeff_plot(admin$filtered_analysis$specs_short)
  })
  output$short_robustness_table <- DT::renderDT({
    req(admin$filtered_analysis$specs_short)
    .build_spec_table(admin$filtered_analysis$specs_short)
  }, server = FALSE)
  
  output$long_robustness_plot <- renderPlotly({
    req(admin$filtered_analysis$specs_long)
    .build_spec_coeff_plot(admin$filtered_analysis$specs_long)
  })
  output$long_robustness_table <- DT::renderDT({
    req(admin$filtered_analysis$specs_long)
    .build_spec_table(admin$filtered_analysis$specs_long)
  }, server = FALSE)
  
  output$sensitivity_short_ui <- renderUI({
    specs  <- admin$filtered_analysis$specs_short
    bundle <- admin$filtered_analysis$sensitivity_short
    if (is.null(specs) || is.null(bundle))
      return(div(class="deferred-box", icon("clock"), " Click 'Run / Re-run Regression Analysis' above to see robustness checks."))
    n_hint <- nrow(specs)
    build_robustness_ui(bundle, "short_robustness_plot", "short_robustness_table", n_hint)
  })
  output$sensitivity_long_ui <- renderUI({
    specs  <- admin$filtered_analysis$specs_long
    bundle <- admin$filtered_analysis$sensitivity_long
    if (is.null(specs) || is.null(bundle))
      return(div(class="deferred-box", icon("clock"), " Click 'Run / Re-run Regression Analysis' above to see robustness checks."))
    n_hint <- nrow(specs)
    build_robustness_ui(bundle, "long_robustness_plot", "long_robustness_table", n_hint)
  })
  
  
  # [APP-SV25] ADMIN FIGURE DOWNLOAD HANDLERS ────────────────────────────────
  # ============================================================
  # ADMIN FIGURE DOWNLOAD HANDLERS (webshot2 for plotly figures)
  # ============================================================
  
  # ============================================================
  # ADMIN FIGURE DOWNLOAD HANDLERS
  # ============================================================
  
  # Alias to the shared helper defined above
  dl_admin_plotly <- dl_plotly_fig
  output$dl_proc_share_value <- dl_admin_plotly(function() admin$fig_proc_share_value, "proc_share_value", 900, 700)
  output$dl_proc_share_count <- dl_admin_plotly(function() admin$fig_proc_share_count, "proc_share_count", 900, 700)
  output$dl_proc_value_dist  <- dl_admin_plotly(function() admin$fig_proc_value_dist,  "proc_value_dist", 1400, 700)
  output$dl_subm_dist        <- dl_admin_plotly(function() admin$fig_subm_dist,        "subm_dist",       1200, 700)
  output$dl_subm_proc        <- dl_admin_plotly(function() admin$fig_subm_proc,        "subm_proc",       1400, 800)
  output$dl_subm_share       <- dl_admin_plotly(function() admin$fig_subm_share,       "subm_share",       900, 400)
  output$dl_subm_short       <- dl_admin_plotly(function() admin$fig_subm_short,       "subm_short",      1400, 900)
  output$dl_buyer_short      <- dl_admin_plotly(function() admin$fig_buyer_short,      "buyer_short",     1400, 800)
  output$dl_dec_dist         <- dl_admin_plotly(function() admin$fig_dec_dist,         "dec_dist",        1200, 700)
  output$dl_dec_proc         <- dl_admin_plotly(function() admin$fig_dec_proc,         "dec_proc",        1400, 800)
  output$dl_dec_share        <- dl_admin_plotly(function() admin$fig_dec_share,        "dec_share",        900, 400)
  output$dl_dec_long         <- dl_admin_plotly(function() admin$fig_dec_long,         "dec_long",        1400, 900)
  output$dl_buyer_long       <- dl_admin_plotly(function() admin$fig_buyer_long,       "buyer_long",      1400, 800)
  
  output$dl_short_reg <- downloadHandler(
    filename = function() paste0("short_reg_", admin$country_code, ".png"),
    content  = function(file) { req(admin$filtered_analysis$plot_short_reg); ggsave(file, admin$filtered_analysis$plot_short_reg, width=10, height=8, dpi=300) }
  )
  output$dl_long_reg <- downloadHandler(
    filename = function() paste0("long_reg_", admin$country_code, ".png"),
    content  = function(file) { req(admin$filtered_analysis$plot_long_reg); ggsave(file, admin$filtered_analysis$plot_long_reg, width=10, height=8, dpi=300) }
  )
  
  
  # [APP-SV26] ADMIN REPORT DOWNLOADS (Word + ZIP) ───────────────────────────
  # ============================================================
  # ADMIN REPORT DOWNLOADS
  # ============================================================
  
  
  output$dl_admin_word <- downloadHandler(
    filename = function() paste0("admin_efficiency_", admin$country_code, "_", format(Sys.Date(), "%Y%m%d"), ".docx"),
    content  = function(file) {
      req(admin$data, admin$analysis, admin$country_code)
      withProgress(message = "Generating administrative efficiency Word report...", value = 0, {
        incProgress(0.2, detail = "Filtering data...")
        exp_data <- admin_get_export_data()
        incProgress(0.5, detail = "Collecting figures...")
        # Use the same ggplot objects the app rendered — these ARE what the user sees.
        # Each renderPlotly block stores its ggplot as admin$gg_* alongside the plotly fig.
        # Fall back to admin_regenerate_plots for any that haven't been rendered yet.
        plots <- admin_build_word_plots(
          filtered_data      = exp_data,
          thresholds         = admin$thresholds,
          global_proc_filter = admin$global_proc_filter,
          subm_cutoffs       = isolate(admin_subm_cutoffs()),
          dec_cutoffs        = isolate(admin_dec_cutoffs()),
          price_thresholds   = admin$price_thresholds
        )
        plots$plot_short_reg  <- admin$filtered_analysis$plot_short_reg %||% admin$analysis$plot_short_reg
        plots$plot_long_reg   <- admin$filtered_analysis$plot_long_reg  %||% admin$analysis$plot_long_reg
        # Stored displayed figs for the native-plotly-only charts; NULLs
        # become explanatory notes in the document
        plots$fig_proc_value_dist <- admin$fig_proc_value_dist
        plots$fig_subm_share      <- admin$fig_subm_share
        plots$fig_dec_share       <- admin$fig_dec_share
        # Fallback: if ggplot bunching panels weren't built, pass the stored plotly fig
        # so generate_admin_word_report can render it via webshot2
        if (is.null(plots$bunching))
          plots$bunching_fig_fallback <- admin$bunching_fig
        message("[word_export] plots$bunching: ",
                if (is.null(plots$bunching)) "NULL (will try plotly fallback)" else paste0("list of ", length(plots$bunching), " ggplots"))
        incProgress(0.7, detail = "Creating document...")
        filter_desc  <- get_filter_description(admin_filters$active)
        filters_text <- if (filter_desc == "No filters applied") "" else paste0("Applied Filters: ", filter_desc)
        ok <- generate_admin_word_report(
          filtered_data     = exp_data,
          filtered_analysis = plots,
          country_code      = admin$country_code,
          output_file       = file,
          filters_text      = filters_text
        )
        output$export_status <- renderText(if (ok) "Administrative efficiency Word report generated!" else "Error generating admin Word report.")
      })
    }
  )
  
  output$dl_admin_zip <- downloadHandler(
    filename = function() paste0("admin_figures_", admin$country_code, "_", format(Sys.Date(), "%Y%m%d"), ".zip"),
    content  = function(file) {
      req(admin$data, admin$analysis, admin$country_code)
      withProgress(message = "Creating admin figures ZIP...", value = 0, {
        incProgress(0.1, detail = "Filtering data...")
        exp_data <- admin_get_export_data()
        temp_dir <- tempfile(); dir.create(temp_dir)
        cc       <- admin$country_code
        regen <- admin_build_word_plots(
          filtered_data      = exp_data,
          thresholds         = admin$thresholds,
          global_proc_filter = admin$global_proc_filter,
          subm_cutoffs       = isolate(admin_subm_cutoffs()),
          dec_cutoffs        = isolate(admin_dec_cutoffs()),
          price_thresholds   = admin$price_thresholds
        )
        view_pt <- "Open the Procedure Types tab once, then re-download."
        view_sp <- "Open the Submission Periods tab once, then re-download."
        view_dp <- "Open the Decision Periods tab once, then re-download."
        no_dates_s <- "Needs publication + bid-deadline dates (or a precomputed days column)."
        no_dates_d <- "Needs bid-deadline + award/signature dates (or a precomputed days column)."
        run_reg <- "Run the regressions in the Regression Analysis tab (re-run after changing filters), then re-download."
        entries <- list(
          list(obj = regen$sh,                name = "proc_share_value",  w = 10, h = 6, note = "Needs tender_proceduretype and a price column."),
          list(obj = regen$p_count,           name = "proc_share_count",  w = 10, h = 6, note = "Needs tender_proceduretype."),
          list(obj = admin$fig_proc_value_dist, name = "proc_value_distribution", w = 10, h = 7, note = view_pt),
          list(obj = admin$bunching_fig,      name = "bunching_analysis", w = 11, h = 8, note = paste(view_pt, "Bunching needs price thresholds set in Setup.")),
          list(obj = regen$subm,              name = "subm_dist",         w = 10, h = 6, note = no_dates_s),
          list(obj = regen$subm_proc_facet_q, name = "subm_proc",         w = 10, h = 6, note = no_dates_s),
          list(obj = regen$subm_r,            name = "subm_short",        w = 10, h = 6, note = no_dates_s),
          list(obj = regen$buyer_short,       name = "buyer_short",       w = 12, h = 8, note = no_dates_s),
          list(obj = admin$fig_subm_share,    name = "subm_share_summary",w = 10, h = 6, note = view_sp),
          list(obj = regen$decp,              name = "dec_dist",          w = 10, h = 6, note = no_dates_d),
          list(obj = regen$decp_proc_facet_q, name = "dec_proc",          w = 10, h = 6, note = no_dates_d),
          list(obj = regen$decp_r,            name = "dec_long",          w = 10, h = 6, note = no_dates_d),
          list(obj = regen$buyer_long,        name = "buyer_long",        w = 12, h = 8, note = no_dates_d),
          list(obj = admin$fig_dec_share,     name = "dec_share_summary", w = 10, h = 6, note = view_dp),
          list(obj = admin$filtered_analysis$plot_short_reg %||% admin$analysis$plot_short_reg,
               name = "short_reg", w = 10, h = 8, note = run_reg),
          list(obj = admin$filtered_analysis$plot_long_reg %||% admin$analysis$plot_long_reg,
               name = "long_reg",  w = 10, h = 8, note = run_reg)
        )
        statuses <- data.frame(figure = character(0), status = character(0),
                               note = character(0), stringsAsFactors = FALSE)
        saved <- 0
        for (i in seq_along(entries)) {
          e <- entries[[i]]
          incProgress(0.2 + i / length(entries) * 0.7, detail = paste0("Saving ", e$name))
          ok <- pa_save_plot_any(e$obj, file.path(temp_dir, paste0(e$name, "_", cc, ".png")),
                                 width_in = e$w, height_in = e$h)
          st <- if (isTRUE(ok)) "saved" else if (identical(attr(ok, "reason"), "not generated")) "skipped" else "failed"
          nt <- if (isTRUE(ok)) "" else if (st == "skipped") e$note else (attr(ok, "reason") %||% "unknown error")
          statuses <- rbind(statuses, data.frame(figure = e$name, status = st, note = nt,
                                                 stringsAsFactors = FALSE))
          if (isTRUE(ok)) saved <- saved + 1
        }
        pa_write_manifest(temp_dir, "Administrative Efficiency", statuses)
        zip::zip(zipfile = file, files = list.files(temp_dir, full.names = TRUE), mode = "cherry-pick")
        output$export_status <- renderText(paste0(
          saved, " of ", nrow(statuses),
          " admin figures saved to ZIP — see MANIFEST.txt inside the ZIP."))
        if (saved < nrow(statuses))
          showNotification(paste0(saved, " of ", nrow(statuses),
                                  " figures saved. MANIFEST.txt inside the ZIP explains how to generate the rest."),
                           type = "warning", duration = 8)
        unlink(temp_dir, recursive = TRUE)
      })
    }
  )
  
  
  # [APP-SV27] EXPORT STATUS BOXES ───────────────────────────────────────────
  # ============================================================
  # EXPORT STATUS
  # ============================================================
  
  output$export_status <- renderText({ "No exports yet. Use the buttons above to generate reports." })
  
  
  
  # [APP-SV28] INTEGRITY — FILTER UI GENERATION + APPLICATION ────────────────
  # ============================================================
  # INTEGRITY — FILTER UI GENERATION
  # ============================================================
  
  integ_tabs <- c("missing", "interop", "risky", "prices")
  
  make_integ_filter_outputs <- function(tabs = integ_tabs) {
    for (tab in tabs) {
      local({
        t <- tab
        p <- "integ_"
        
        output[[paste0(p, "year_filter_", t)]] <- renderUI({
          req(integ$data)
          year_col <- if ("tender_year" %in% names(integ$data)) "tender_year"
          else if ("year" %in% names(integ$data)) "year"
          else if ("cal_year" %in% names(integ$data)) "cal_year" else NULL
          if (!is.null(year_col)) {
            years <- sort(unique(integ$data[[year_col]])); years <- years[!is.na(years)]
            if (length(years) > 0)
              sliderInput(paste0("integ_yr_", t), "Year Range:",
                          min=min(years), max=max(years), value=c(min(years),max(years)), step=1, sep="")
          }
        })
        
        output[[paste0(p, "market_filter_", t)]] <- renderUI({
          src <- if (!is.null(econ$data)) econ$data else econ$filtered_data
          req(!is.null(src))
          if ("cpv_cluster" %in% names(src)) {
            cpv_codes <- sort(unique(src$cpv_cluster))
            cpv_codes <- cpv_codes[!is.na(cpv_codes) & cpv_codes != ""]
            if (length(cpv_codes) > 0) {
              cpv_choices <- setNames(cpv_codes, sapply(cpv_codes, get_cpv_label))
              pickerInput(paste0("integ_mkt_", t), "Market (CPV):",
                          choices  = cpv_choices, selected = character(0),
                          multiple = TRUE,
                          options  = list(`actions-box` = TRUE, `live-search` = TRUE,
                                          `none-selected-text` = "All markets"))
            }
          }
        })
        
        output[[paste0(p, "value_filter_", t)]] <- renderUI({
          req(integ$data)
          price_col <- detect_price_col(integ$data, .PRICE_COLS_ADMIN)
          if (!is.na(price_col) && !is.null(price_col)) {
            prices <- integ$data[[price_col]]; prices <- prices[!is.na(prices) & prices > 0]
            if (length(prices) > 0) {
              # Detect the local currency from the data
              loc_cur <- detect_local_currency(integ$data)
              cur     <- input[[paste0("integ_val_cur_", t)]] %||% "USD"
              rate    <- if (cur == loc_cur$label && cur != "USD") loc_cur$rate else 1
              div     <- 1e3
              integ$value_divisor  <- div / rate
              integ$value_max_k    <- ceiling(max(prices) * rate / div)
              integ$local_currency <- loc_cur
              make_value_filter_widget(prices, paste0("integ_val_cur_", t), paste0("integ_val_rng_", t),
                                       cur, local_currency = loc_cur)
            }
          }
        })
        
        output[[paste0(p, "buyer_type_filter_", t)]] <- renderUI({
          req(integ$data)
          if ("buyer_buyertype" %in% names(integ$data)) {
            bg <- integ$data %>% mutate(bg = add_buyer_group(buyer_buyertype)) %>%
              pull(bg) %>% as.character() %>% unique() %>% sort()
            bg <- bg[!is.na(bg)]
            if (length(bg) > 0)
              pickerInput(paste0("integ_btype_", t), "Buyer Type:",
                          choices  = bg, selected = character(0),
                          multiple = TRUE,
                          options  = list(`actions-box` = TRUE,
                                          `none-selected-text` = "All buyer types"))
          }
        })
        
        output[[paste0(p, "procedure_type_filter_", t)]] <- renderUI({
          req(integ$data)
          if ("tender_proceduretype" %in% names(integ$data)) {
            raw_types <- unique(integ$data$tender_proceduretype)
            raw_types <- raw_types[!is.na(raw_types)]
            if (length(raw_types) > 0) {
              df_map <- data.frame(raw     = raw_types,
                                   cleaned = recode_procedure_type(raw_types),
                                   stringsAsFactors = FALSE)
              types <- sort(unique(df_map$cleaned[!is.na(df_map$cleaned)]))
              pickerInput(paste0("integ_ptype_", t), "Procedure Type:",
                          choices  = types, selected = character(0),
                          multiple = TRUE,
                          options  = list(`actions-box` = TRUE, `live-search` = TRUE,
                                          `none-selected-text` = "All procedure types"))
            }
          }
        })
        
        output[[paste0(p, "filter_status_", t)]] <- renderText({
          paste(" ", get_filter_description(integ_filters[[t]]))
        })
        
        # Per-tab coarse↔fine slider sync for the value filter
        make_slider_sync(
          paste0("integ_val_rng_", t, "_coarse"),
          paste0("integ_val_rng_", t, "_min_k"),
          paste0("integ_val_rng_", t, "_max_k"),
          local({ tt <- t; function() {
            loc <- integ$local_currency %||% list(label = "USD", rate = 1)
            cur <- input[[paste0("integ_val_cur_", tt)]] %||% "USD"
            if (cur == loc$label && cur != "USD") loc$rate else 1
          }})
        )
      })
    }
  }
  make_integ_filter_outputs()
  
  # run_integrity_pipeline_fast_local is defined globally above the UI
  
  apply_integ_filters <- function(tab_name) {
    req(integ$data)
    current_filters <- list(
      year           = input[[paste0("integ_yr_",    tab_name)]],
      market         = input[[paste0("integ_mkt_",   tab_name)]],
      value = {
        mn_k <- input[[paste0("integ_val_rng_", tab_name, "_min_k")]]
        mx_k <- input[[paste0("integ_val_rng_", tab_name, "_max_k")]]
        mn <- if (is.null(mn_k) || is.na(mn_k)) 0 else mn_k
        mx <- if (is.null(mx_k) || is.na(mx_k)) (integ$value_max_k %||% 1e9) else mx_k
        c(mn, mx)
      },
      buyer_type     = input[[paste0("integ_btype_", tab_name)]],
      procedure_type = input[[paste0("integ_ptype_", tab_name)]]
    )
    integ_filters$active      <- current_filters
    integ_filters[[tab_name]] <- current_filters
    filtered_df <- integrity_filter_data(integ$data,
                                         year_range     = current_filters$year,
                                         market         = current_filters$market,
                                         value_range    = current_filters$value,
                                         buyer_type     = current_filters$buyer_type,
                                         procedure_type = current_filters$procedure_type,
                                         value_divisor  = isolate(integ$value_divisor))
    if (nrow(filtered_df) == 0) {
      showNotification("No data matches the selected filters.", type="warning", duration=5)
      return(NULL)
    }
    showNotification(paste0("Filters applied! ", formatC(nrow(filtered_df), format="d", big.mark=","), " contracts."),
                     type="message", duration=3)
    withProgress(message="Re-running integrity analysis with filters...", value=0, {
      incProgress(0.2, detail="Preparing filtered dataset...")
      new_results <- run_integrity_pipeline_fast_local(filtered_df, integ$country_code, tempdir())
      integ$filtered_data     <- new_results$data
      integ$filtered_analysis <- new_results
      integ$network_done      <- FALSE
      integ$regression_done   <- FALSE
      integ$missing_advanced_done <- FALSE
      incProgress(1.0, detail="Complete!")
    })
  }
  
  reset_integ_filters <- function(tab_name) {
    empty <- list(year=NULL, market=NULL, value=NULL, buyer_type=NULL, procedure_type=NULL)
    integ_filters$active      <- empty
    integ_filters[[tab_name]] <- empty
    integ$filtered_data     <- integ$data
    integ$filtered_analysis <- integ$analysis
    showNotification("Filters reset", type="message", duration=2)
  }
  
  for (tn in integ_tabs) {
    local({
      t <- tn
      observeEvent(input[[paste0("integ_apply_filters_", t)]], { apply_integ_filters(t) })
      observeEvent(input[[paste0("integ_reset_filters_",  t)]], { reset_integ_filters(t) })
    })
  }
  
  
  # [APP-SV29] INTEGRITY — DEFERRED: ADVANCED MISSINGNESS (MCAR / MAR) ───────
  # ============================================================
  # INTEGRITY — DEFERRED: MISSING ADVANCED
  # ============================================================
  
  observeEvent(input$integ_run_missing_advanced, {
    req(integ$filtered_data, integ$filtered_analysis)
    withProgress(message="Running advanced missingness tests...", value=0, {
      incProgress(0.1, detail="MCAR test...")
      config <- safe_pipeline_config(integ$country_code)
      adv <- tryCatch(
        run_missing_advanced_tests(integ$filtered_data, config, tempdir()),
        error=function(e) { showNotification(paste("Advanced tests error:", e$message), type="error", duration=10); NULL }
      )
      incProgress(0.9, detail="Updating results...")
      if (!is.null(adv)) {
        integ$filtered_analysis$missing$mcar_test        <- adv$mcar_test
        integ$filtered_analysis$missing$cooccurrence_data <- adv$cooccurrence_data
        integ$filtered_analysis$missing$cooccurrence_plot <- adv$cooccurrence_plot
        integ$filtered_analysis$missing$mar_results      <- adv$mar_results
        integ$filtered_analysis$missing$mar_plot         <- adv$mar_plot
        integ$missing_advanced_done <- TRUE
        showNotification("Advanced missingness tests complete!", type="message", duration=5)
      }
    })
  })
  
  output$integ_mcar_summary_card <- renderUI({
    if (!isTRUE(integ$missing_advanced_done))
      return(div(class="deferred-box", icon("clock"), " Click 'Run Advanced Missingness Tests' above."))
    mcar <- integ$filtered_analysis$missing$mcar_test
    if (is.null(mcar))
      return(div(class="alert alert-info", "MCAR test could not be computed."))
    if (is.na(mcar$p_value))
      return(div(class="alert alert-info",
                 tags$b("Little's MCAR test could not be computed on this data. "),
                 tags$span(mcar$interpretation %||% "")))
    p_val      <- mcar$p_value
    status_col <- if (p_val < 0.05) "#c0392b" else if (p_val < 0.10) "#e67e22" else "#27ae60"
    div(style=paste0("border-left:5px solid ",status_col,"; padding:14px 20px; background:#fafafa; border-radius:4px;"),
        tags$p(tags$b(paste("Little's MCAR Test — p-value:", round(p_val, 4))), style="margin-bottom:6px; font-size:15px;"),
        tags$p(mcar$interpretation, style=paste0("margin-top:10px; color:",status_col,"; font-style:italic;")))
  })
  
  
  # [APP-SV30] INTEGRITY — MISSING VALUES OUTPUTS (+ downloads) ──────────────
  # ============================================================
  # INTEGRITY — MISSING VALUES OUTPUTS
  # ============================================================
  
  output$integ_missing_overall_plot <- renderPlotly({
    req(integ$filtered_analysis$missing$overall_plot)
    n_vars  <- nrow(integ$filtered_analysis$missing$overall_long %||% data.frame())
    h       <- max(250, min(600, n_vars*18+60))
    post_process_plotly(
      ggplotly(integ$filtered_analysis$missing$overall_plot, tooltip="text", height=h)
    ) %>% layout(hoverlabel=list(bgcolor="white",font=list(size=12)),
                 margin=list(l=210,b=50,t=20,r=20),
                 font=list(size=12),
                 xaxis=list(titlefont=list(size=12), tickfont=list(size=13)),
                 yaxis=list(tickfont=list(size=13))) %>%
      pa_config() -> .stored_fig
    integ$fig_miss_overall <- .stored_fig
    .stored_fig
  })
  output$integ_missing_overall_height_spacer <- renderUI({
    req(integ$filtered_analysis$missing$overall_long)
    n <- nrow(integ$filtered_analysis$missing$overall_long)
    # Must match the ggplotly(height=...) formula in the render block above
    h <- max(250, min(600, n*18+60)) + 16
    tags$style(paste0("#integ_missing_overall_plot { height: ",h,"px !important; }"))
  })
  output$integ_missing_buyer_slider_ui <- renderUI({
    req(integ$filtered_analysis$missing$by_buyer_n_vars_max)
    n_max <- integ$filtered_analysis$missing$by_buyer_n_vars_max
    sliderInput("integ_missing_buyer_n_vars","Number of variables to show:", min=5, max=n_max, value=min(15,n_max), step=5, width="70%")
  })
  output$integ_missing_buyer_plot <- renderPlotly({
    req(integ$filtered_analysis$missing$by_buyer, integ$filtered_analysis$missing$by_buyer_var_order)
    n_vars <- input$integ_missing_buyer_n_vars %||% min(15, integ$filtered_analysis$missing$by_buyer_n_vars_max)
    req(n_vars); h <- max(200, n_vars*20+60)
    p <- make_groupvar_heatmap(long_df=integ$filtered_analysis$missing$by_buyer, group_var="buyer_group",
                               var_order=integ$filtered_analysis$missing$by_buyer_var_order, top_n=n_vars,
                               title=paste("Missing share by buyer type -", integ$country_code %||% ""), x_lab="Buyer type")
    post_process_plotly(ggplotly(p, tooltip="text", height=h)) %>% layout(hoverlabel=list(bgcolor="white",font=list(size=12)), font=list(size=12), margin=list(l=210,r=130,b=70,t=30), xaxis=list(tickfont=list(size=13)), yaxis=list(tickfont=list(size=13))) %>%
      pa_config() -> .stored_fig
    integ$fig_miss_buyer <- .stored_fig
    .stored_fig
  })
  output$integ_missing_buyer_plot_height <- renderUI({
    n <- input$integ_missing_buyer_n_vars %||% 15
    # Must match the ggplotly(height=...) formula in the render block above
    h <- max(200, n*20+60) + 16
    tags$style(paste0("#integ_missing_buyer_plot { height: ",h,"px !important; }"))
  })
  output$integ_missing_procedure_slider_ui <- renderUI({
    req(integ$filtered_analysis$missing$by_procedure_n_vars_max)
    n_max <- integ$filtered_analysis$missing$by_procedure_n_vars_max
    sliderInput("integ_missing_procedure_n_vars","Number of variables to show:", min=5, max=n_max, value=min(15,n_max), step=5, width="70%")
  })
  output$integ_missing_procedure_plot <- renderPlotly({
    req(integ$filtered_analysis$missing$by_procedure, integ$filtered_analysis$missing$by_procedure_var_order)
    n_vars <- input$integ_missing_procedure_n_vars %||% min(15, integ$filtered_analysis$missing$by_procedure_n_vars_max)
    req(n_vars); h <- max(200, n_vars*20+60)
    p <- make_groupvar_heatmap(long_df=integ$filtered_analysis$missing$by_procedure, group_var="proc_group_label",
                               var_order=integ$filtered_analysis$missing$by_procedure_var_order, top_n=n_vars,
                               title=paste("Missing share by procedure type -", integ$country_code %||% ""), x_lab="Procedure type")
    post_process_plotly(ggplotly(p, tooltip="text", height=h)) %>% layout(hoverlabel=list(bgcolor="white",font=list(size=12)), font=list(size=12), margin=list(l=210,r=130,b=70,t=30), xaxis=list(tickfont=list(size=13)), yaxis=list(tickfont=list(size=13))) %>%
      pa_config() -> .stored_fig
    integ$fig_miss_proc <- .stored_fig
    .stored_fig
  })
  output$integ_missing_procedure_plot_height <- renderUI({
    n <- input$integ_missing_procedure_n_vars %||% 15
    # Must match the ggplotly(height=...) formula in the render block above
    h <- max(200, n*20+60) + 16
    tags$style(paste0("#integ_missing_procedure_plot { height: ",h,"px !important; }"))
  })
  output$integ_missing_time_slider_ui <- renderUI({
    req(integ$filtered_analysis$missing$by_year_n_vars_max)
    n_max <- integ$filtered_analysis$missing$by_year_n_vars_max
    s_max <- min(50, n_max); s_max <- ceiling(s_max/5)*5; s_val <- min(15, s_max)
    sliderInput("integ_missing_time_n_vars","Number of variables to show:", min=5, max=s_max, value=s_val, step=5, width="70%")
  })
  output$integ_missing_time_plot <- renderPlotly({
    req(integ$filtered_analysis$missing$by_year, integ$filtered_analysis$missing$by_year_var_order)
    n_vars <- input$integ_missing_time_n_vars %||% min(15, integ$filtered_analysis$missing$by_year_n_vars_max)
    req(n_vars); h <- max(200, n_vars*20+60)
    p <- make_year_heatmap(by_year_df=integ$filtered_analysis$missing$by_year,
                           var_order=integ$filtered_analysis$missing$by_year_var_order,
                           top_n=n_vars, country=integ$country_code %||% "")
    post_process_plotly(ggplotly(p, tooltip="text", height=h)) %>%
      layout(hoverlabel=list(bgcolor="white",font=list(size=12)), font=list(size=12), margin=list(l=210,r=130,b=60,t=40), xaxis=list(tickfont=list(size=13)), yaxis=list(tickfont=list(size=13)),
             coloraxis=list(colorbar=list(len=0.8, thickness=15))) %>%
      pa_config() -> .stored_fig
    integ$fig_miss_time <- .stored_fig
    .stored_fig
  })
  output$integ_missing_time_height_spacer <- renderUI({
    n <- input$integ_missing_time_n_vars %||% 15
    # Must match the ggplotly(height=...) formula in the render block above
    h <- max(200, n*20+60) + 16
    tags$style(paste0("#integ_missing_time_plot { height: ",h,"px !important; }"))
  })
  output$integ_missing_cooccurrence_ui <- renderUI({
    if (!isTRUE(integ$missing_advanced_done))
      div(class="deferred-box", icon("clock"), " Click 'Run Advanced Missingness Tests' above.")
    else if (is.null(integ$filtered_analysis$missing$cooccurrence_plot))
      div(class="alert alert-warning", "Co-occurrence plot could not be generated.")
    else tagList(
      uiOutput("integ_missing_cooc_slider_ui"),
      div(style="overflow-y:auto; max-height:700px;", plotlyOutput("integ_missing_cooccurrence_plot", height="auto"))
    )
  })
  output$integ_missing_cooccurrence_download_ui <- renderUI({
    if (isTRUE(integ$missing_advanced_done) && !is.null(integ$filtered_analysis$missing$cooccurrence_plot))
      downloadButton("integ_dl_missing_cooccurrence", "Download Figure", class="download-btn btn-sm")
  })
  output$integ_missing_cooc_slider_ui <- renderUI({
    req(integ$filtered_analysis$missing$cooccurrence_data)
    co    <- integ$filtered_analysis$missing$cooccurrence_data
    j_min <- floor(min(co$jaccard, na.rm=TRUE)*100/5)*5
    sliderInput("integ_cooc_min_jaccard","Show only pairs with co-occurrence score at or above:",
                min=j_min, max=100, value=50, step=5, post="%", width="55%")
  })
  output$integ_missing_cooccurrence_plot <- renderPlotly({
    req(integ$missing_advanced_done, integ$filtered_analysis$missing$cooccurrence_data)
    min_j <- (input$integ_cooc_min_jaccard %||% 0)/100
    p <- plot_cooccurrence_from_data(co_df=integ$filtered_analysis$missing$cooccurrence_data,
                                     top_n=50, min_jaccard=min_j,
                                     title=paste("Variable Pairs Missing Together -", integ$country_code %||% ""))
    if (is.null(p)) return(plotly::plot_ly(type = "scatter", mode = "markers") %>% plotly::layout(title="No pairs meet the selected threshold."))
    n_pairs <- nrow(integ$filtered_analysis$missing$cooccurrence_data %>% dplyr::filter(jaccard >= min_j))
    h <- max(280, min(700, n_pairs*22+80))
    post_process_plotly(ggplotly(p, tooltip="text", height=h)) %>% layout(hoverlabel=list(bgcolor="white",font=list(size=11)), margin=list(l=220)) %>%
      pa_config() -> .stored_fig
    integ$fig_miss_cooc <- .stored_fig
    .stored_fig
  })
  output$integ_missing_mar_ui <- renderUI({
    if (!isTRUE(integ$missing_advanced_done))
      div(class="deferred-box", icon("clock"), " Click 'Run Advanced Missingness Tests' above.")
    else if (is.null(integ$filtered_analysis$missing$mar_plot))
      div(class="alert alert-warning", "MAR predictability plot could not be generated.")
    else {
      n_vars <- nrow(integ$filtered_analysis$missing$mar_results %||% data.frame())
      h <- max(300, min(520, n_vars*22+80))
      tagList(div(style="width:100%; overflow-x:hidden;",
                  plotlyOutput("integ_missing_mar_plot", height=paste0(h,"px"), width="100%")))
    }
  })
  output$integ_missing_mar_download_ui <- renderUI({
    if (isTRUE(integ$missing_advanced_done) && !is.null(integ$filtered_analysis$missing$mar_plot))
      downloadButton("integ_dl_missing_mar", "Download Figure", class="download-btn btn-sm")
  })
  output$integ_missing_mar_plot <- renderPlotly({
    req(integ$missing_advanced_done, integ$filtered_analysis$missing$mar_plot)
    n_vars <- nrow(integ$filtered_analysis$missing$mar_results %||% data.frame())
    h <- max(300, min(520, n_vars*22+80))
    post_process_plotly(
      ggplotly(integ$filtered_analysis$missing$mar_plot, tooltip="text", height=h)
    ) %>% plotly::config(responsive=TRUE) %>%
      layout(hoverlabel=list(bgcolor="white",font=list(size=10)),
             margin=list(l=180,r=10,t=20,b=50), autosize=TRUE) %>%
      pa_config() -> .stored_fig
    integ$fig_miss_mar <- .stored_fig
    .stored_fig
  })
  
  # ── Missing download handlers ──────────────────────────────────────────
  # ── Integ missing value downloads — download exactly what's displayed ──
  .dl_integ_plotly <- function(fig_expr, fname, vw = 1200, vh = 700) {
    downloadHandler(
      filename = function() paste0(fname, "_", integ$country_code %||% "export",
                                   "_", format(Sys.Date(), "%Y%m%d"), ".png"),
      content  = function(file) {
        fig <- tryCatch(fig_expr(), error = function(e) NULL)
        .require_fig(fig, fname)
        .save_fig_png(fig, file)
      }
    )
  }
  output$integ_dl_missing_overall    <- .dl_integ_plotly(function() integ$fig_miss_overall, "integ_missing_overall",    1200, 700)
  output$integ_dl_missing_buyer      <- .dl_integ_plotly(function() integ$fig_miss_buyer,   "integ_missing_buyer",      1200, 800)
  output$integ_dl_missing_procedure  <- .dl_integ_plotly(function() integ$fig_miss_proc,    "integ_missing_procedure",  1000, 600)
  output$integ_dl_missing_time       <- .dl_integ_plotly(function() integ$fig_miss_time,    "integ_missing_time",       1200, 700)
  output$integ_dl_missing_cooccurrence <- .dl_integ_plotly(function() integ$fig_miss_cooc,  "integ_missing_cooccurrence", 1000, 800)
  output$integ_dl_missing_mar        <- .dl_integ_plotly(function() integ$fig_miss_mar,     "integ_missing_mar",        1000, 800)
  
  
  # [APP-SV31] INTEGRITY — INTEROPERABILITY OUTPUT ───────────────────────────
  # ============================================================
  # INTEGRITY — INTEROPERABILITY OUTPUT
  # ============================================================
  
  output$integ_interoperability_table <- DT::renderDataTable({
    req(integ$filtered_analysis$interoperability$org_missing)
    org_data <- integ$filtered_analysis$interoperability$org_missing %>%
      dplyr::mutate(`Missing share` = ifelse(is.na(missing_share), "Not available",
                                             scales::percent(missing_share, accuracy=1))) %>%
      dplyr::select(`Organization type`=organization_type, `ID type`=id_type, `Missing share`)
    DT::datatable(org_data, options=list(pageLength=10, dom="t"), rownames=FALSE)
  })
  
  
  # [APP-SV32] INTEGRITY — DEFERRED: NETWORK ANALYSIS (+ concentration plot) ────
  # ============================================================
  # INTEGRITY — DEFERRED: NETWORK ANALYSIS
  # ============================================================
  
  observeEvent(input$integ_run_network_analysis, {
    req(integ$filtered_data, integ$country_code)
    withProgress(message="Running network analysis...", value=0, {
      incProgress(0.2, detail="Computing market entry patterns...")
      tryCatch({
        config      <- safe_pipeline_config(integ$country_code)
        net_results <- safely_run_module(analyze_markets, integ$filtered_data, config, tempdir())
        integ$filtered_analysis$markets <- net_results
        integ$network_done <- TRUE
        incProgress(1.0, detail="Done.")
        # Honest status: safely_run_module swallows module errors, so a bare
        # "complete!" would be misleading when nothing was produced.
        if (!is.null(net_results$error)) {
          showNotification(paste0("Network analysis failed: ", net_results$error,
                                  " (details in the R console)"),
                           type="error", duration=12)
        } else if (is.null(net_results$unusual_matrix) ||
                   nrow(net_results$unusual_matrix) == 0) {
          showNotification("Network analysis ran, but no unusual market entries were detected in this dataset.",
                           type="warning", duration=10)
        } else {
          showNotification("Network analysis complete!", type="message", duration=5)
        }
      }, error=function(e) showNotification(paste("Network error:", e$message), type="error", duration=10))
    })
  })
  
  output$integ_network_status_ui <- renderUI({
    if (isTRUE(integ$network_done))
      div(class="alert alert-success", icon("check-circle"), tags$strong(" Network analysis complete. Plots shown below."))
    else
      div(class="alert alert-warning", icon("info-circle"), tags$strong(" Network analysis not yet run."), " Click the button below to compute.")
  })
  output$integ_network_done_flag <- reactive({ isTRUE(integ$network_done) })
  outputOptions(output, "integ_network_done_flag", suspendWhenHidden=FALSE)
  
  output$integ_net_cluster_filter_ui <- renderUI({
    req(integ$filtered_analysis$markets$unusual_matrix)
    mat <- integ$filtered_analysis$markets$unusual_matrix
    clusters <- sort(unique(c(mat$home_cpv_cluster, mat$target_cpv_cluster)))
    selectInput("integ_net_cluster_filter","Filter to specific clusters (leave blank = all):",
                choices=clusters, selected=NULL, multiple=TRUE, selectize=TRUE, width="100%")
  })
  output$integ_net_min_bidders_ui <- renderUI({
    req(integ$filtered_analysis$markets$unusual_matrix)
    mat <- integ$filtered_analysis$markets$unusual_matrix
    max_bid <- max(mat$n_bidders, na.rm=TRUE)
    sliderInput("integ_net_min_bidders","Min suppliers to show a route:", min=1, max=max(20,ceiling(max_bid/2)),
                value=min(4,ceiling(max_bid*0.1)), step=1, ticks=FALSE, width="100%")
  })
  output$integ_net_top_clusters_ui <- renderUI({
    req(integ$filtered_analysis$markets$unusual_matrix)
    mat <- integ$filtered_analysis$markets$unusual_matrix
    n_cl <- dplyr::n_distinct(c(mat$home_cpv_cluster, mat$target_cpv_cluster))
    sliderInput("integ_net_top_clusters","Max market clusters to show:", min=5, max=max(50,n_cl),
                value=min(20,n_cl), step=5, ticks=FALSE, width="100%")
  })
  
  integ_matrix_df <- reactive({
    req(integ$filtered_analysis$markets$unusual_matrix)
    mat       <- integ$filtered_analysis$markets$unusual_matrix
    min_bid   <- input$integ_net_min_bidders  %||% 4
    top_n     <- input$integ_net_top_clusters %||% 20
    cl_filter <- input$integ_net_cluster_filter
    edges <- mat %>% dplyr::rename(from=home_cpv_cluster, to=target_cpv_cluster) %>%
      dplyr::filter(n_bidders >= min_bid, from != to)
    if (!is.null(cl_filter) && length(cl_filter) > 0)
      edges <- edges %>% dplyr::filter(from %in% cl_filter | to %in% cl_filter)
    top_clusters <- edges %>%
      tidyr::pivot_longer(c(from,to), values_to="cluster") %>%
      dplyr::count(cluster, wt=n_bidders, sort=TRUE) %>%
      dplyr::slice_head(n=top_n) %>% dplyr::pull(cluster)
    edges %>%
      dplyr::filter(from %in% top_clusters, to %in% top_clusters) %>%
      dplyr::mutate(from=factor(from,levels=rev(top_clusters)), to=factor(to,levels=top_clusters),
                    tooltip=paste0("<b>",from," → ",to,"</b><br>Suppliers: <b>",n_bidders,"</b><br>Avg surprise (z): ",round(mean_surprise,2)))
  })
  
  output$integ_flow_matrix_plot_ui <- renderUI({
    req(integ$network_done, integ$filtered_analysis$markets$unusual_matrix)
    df <- tryCatch(integ_matrix_df(), error=function(e) NULL)
    if (is.null(df) || nrow(df)==0)
      return(div(class="alert alert-warning","No routes meet the current filter settings."))
    n <- dplyr::n_distinct(levels(df$from)); h <- max(280, min(600, n*26+80))
    plotlyOutput("integ_flow_matrix_plot", height=paste0(h,"px"), width="100%")
  })
  output$integ_flow_matrix_plot <- renderPlotly({
    df <- integ_matrix_df(); req(nrow(df) > 0)
    n_cl <- dplyr::n_distinct(levels(df$from))
    txt_size  <- max(3.2, min(6.0, 56/max(n_cl,1)))
    axis_size <- max(9,   min(14, 120/max(n_cl,1)))
    h <- max(280, min(600, n_cl*26+80))
    p <- ggplot2::ggplot(df, ggplot2::aes(x=to, y=from, fill=n_bidders, text=tooltip)) +
      ggplot2::geom_tile(colour="white", linewidth=0.6) +
      ggplot2::geom_text(ggplot2::aes(label=n_bidders,
                                      colour=dplyr::if_else(n_bidders>max(n_bidders,na.rm=TRUE)*0.55,"l","d")),
                         size=txt_size, fontface="bold", show.legend=FALSE) +
      ggplot2::scale_colour_manual(values=c(l="white",d="#1a252f"), guide="none") +
      ggplot2::scale_fill_gradientn(colours=c("#f0f7ff","#93c6e0","#2471a3","#1a5276"), na.value="grey95",
                                    name="Suppliers crossing") +
      ggplot2::scale_x_discrete(position="top") +
      ggplot2::labs(x="↓ Target market", y="Home market →") +
      pa_theme() +
      ggplot2::theme(axis.text.x=ggplot2::element_text(angle=40,hjust=0,size=axis_size,face="bold"),
                     axis.text.y=ggplot2::element_text(size=axis_size,face="bold"),
                     panel.grid=ggplot2::element_blank(), legend.position="right")
    ggplotly(p, tooltip="text", height=h) %>%
      plotly::config(responsive=TRUE) %>%
      layout(hoverlabel=list(bgcolor="white",font=list(size=12)),
             xaxis=list(automargin=TRUE), yaxis=list(automargin=TRUE),
             # top-positioned 40-degree labels overhang up and to the right
             margin=list(l=10,r=70,b=10,t=45), autosize=TRUE) %>%
      pa_config()
  })
  output$integ_network_plot_ui <- renderUI({
    req(integ$network_done, integ$filtered_analysis$markets$unusual_matrix)
    plotOutput("integ_network_plot", height="720px")
  })
  output$integ_network_plot <- renderPlot({
    req(integ$filtered_analysis$markets$unusual_matrix)
    set.seed(42)
    build_network_graph_from_matrix(
      unusual_matrix = integ$filtered_analysis$markets$unusual_matrix,
      min_bidders    = input$integ_net_min_bidders  %||% 4,
      top_n          = input$integ_net_top_clusters %||% 20,
      cl_filter      = if (length(input$integ_net_cluster_filter)==0) NULL else input$integ_net_cluster_filter,
      country        = integ$country_code %||% ""
    )
  }, res=110)
  output$integ_download_network_ui <- renderUI({
    req(integ$network_done)
    downloadButton("integ_dl_network", "Download Flow Matrix", class="download-btn btn-sm")
  })
  output$integ_download_network_graph_ui <- renderUI({
    req(integ$network_done, integ$filtered_analysis$markets$unusual_matrix)
    downloadButton("integ_dl_network_graph", "Download Network Graph", class="download-btn btn-sm")
  })
  output$integ_supplier_unusual_plot_ui <- renderUI({
    if (isTRUE(integ$network_done) && !is.null(integ$filtered_analysis$markets$supplier_unusual_plot)) {
      n_sup <- tryCatch(nrow(integ$filtered_analysis$markets$supplier_unusual_plot$data),
                        error = function(e) NULL)
      h <- max(380, min(720, 150 + 34 * max(n_sup %||% 8, 4)))
      plotlyOutput("integ_supplier_unusual_plot", height=paste0(h,"px"))
    } else div(class="deferred-box", icon("clock"), " Run Network Analysis above to see this plot.")
  })
  output$integ_supplier_unusual_plot <- renderPlotly({
    req(integ$network_done, integ$filtered_analysis$markets$supplier_unusual_plot)
    post_process_plotly(
      ggplotly(integ$filtered_analysis$markets$supplier_unusual_plot, tooltip="text")
    ) %>% layout(hoverlabel=list(bgcolor="white",font=list(size=10)),
                 xaxis=list(automargin=TRUE), yaxis=list(automargin=TRUE),
                 margin=list(r=70,b=50,t=25)) %>%
      pa_config() -> .stored_fig
    integ$fig_supp_unusual <- .stored_fig
    .stored_fig
  })
  output$integ_download_supplier_unusual_ui <- renderUI({
    req(integ$network_done)
    downloadButton("integ_dl_supplier_unusual", "Download Figure", class="download-btn btn-sm")
  })
  output$integ_market_unusual_plot_ui <- renderUI({
    if (isTRUE(integ$network_done) && !is.null(integ$filtered_analysis$markets$market_unusual_plot))
      plotlyOutput("integ_market_unusual_plot", height="470px")
    else div(class="deferred-box", icon("clock"), " Run Network Analysis above to see this plot.")
  })
  output$integ_market_unusual_plot <- renderPlotly({
    req(integ$network_done, integ$filtered_analysis$markets$market_unusual_plot)
    post_process_plotly(
      ggplotly(integ$filtered_analysis$markets$market_unusual_plot, tooltip="text")
    ) %>% layout(hoverlabel=list(bgcolor="white",font=list(size=10)),
                 xaxis=list(automargin=TRUE), yaxis=list(automargin=TRUE),
                 margin=list(r=70,b=50,t=25)) %>%
      pa_config() -> .stored_fig
    integ$fig_mkt_unusual <- .stored_fig
    .stored_fig
  })
  output$integ_download_market_unusual_ui <- renderUI({
    req(integ$network_done)
    downloadButton("integ_dl_market_unusual", "Download Figure", class="download-btn btn-sm")
  })
  
  # ============================================================
  # INTEGRITY — CONCENTRATION PLOT
  # ============================================================
  
  output$integ_conc_n_buyers_slider_ui <- renderUI({
    req(integ$filtered_analysis$competition$concentration_yearly_data)
    sliderInput("integ_conc_n_buyers","Buyers per year to show:", min=5, max=30, value=10, step=1, ticks=FALSE, width="90%")
  })
  output$integ_conc_min_contracts_slider_ui <- renderUI({
    req(integ$filtered_analysis$competition$concentration_yearly_data)
    d <- integ$filtered_analysis$competition$concentration_yearly_data
    mean_c <- max(1L, round(mean(d$total_contracts, na.rm = TRUE)))
    sliderInput("integ_conc_min_contracts",
                paste0("Min contracts per buyer-year (dataset mean: ", scales::comma(mean_c), "):"),
                min=1, max=max(200, mean_c * 4), value=min(50, max(1, mean_c)), step=1, ticks=FALSE, width="90%")
  })
  output$integ_concentration_plot <- renderPlotly({
    req(integ$filtered_analysis$competition$concentration_yearly_data)
    d         <- integ$filtered_analysis$competition$concentration_yearly_data
    n_buyers  <- input$integ_conc_n_buyers      %||% 10
    min_contr <- input$integ_conc_min_contracts %||% 1
    
    # build_concentration_yearly_plot now returns a native plotly object directly —
    # no ggplotly() conversion needed, buyer names are already resolved inside.
    fig <- build_concentration_yearly_plot(
      yearly_data   = d,
      n_buyers      = n_buyers,
      min_contracts = min_contr,
      country       = integ$country_code %||% ""
    )
    if (is.null(fig))
      return(plotly::plot_ly() %>%
               plotly::layout(title = "No data meets the current filters."))
    
    fig <- fig %>% pa_config()
    integ$fig_concentration <- fig
    fig
  })
  output$integ_concentration_plot_ui <- renderUI({
    req(integ$filtered_analysis$competition$concentration_yearly_data)
    d         <- integ$filtered_analysis$competition$concentration_yearly_data
    n_buyers  <- input$integ_conc_n_buyers      %||% 10
    min_contr <- input$integ_conc_min_contracts %||% 1
    n_years   <- dplyr::n_distinct(
      d %>% dplyr::filter(total_contracts >= min_contr) %>% dplyr::pull(tender_year))
    n_cols <- min(max(n_years, 1), 2)   # must match build_concentration_yearly_plot
    n_rows <- ceiling(n_years / n_cols)
    h      <- max(420, n_rows * (n_buyers * 21 + 104) + 50)
    plotlyOutput("integ_concentration_plot", height = paste0(h, "px"))
  })
  output$integ_dl_concentration <- .dl_integ_plotly(
    function() integ$fig_concentration, "integ_concentration", 1400, 900
  )
  
  
  # [APP-SV33] INTEGRITY — DEFERRED: REGRESSION ANALYSIS (+ robustness panels) ────
  # ============================================================
  # INTEGRITY — DEFERRED: REGRESSION ANALYSIS
  # ============================================================
  
  output$integ_regression_status_box <- renderUI({
    if (isTRUE(integ$regression_done))
      div(class = "reg-status-ok", icon("check-circle"), " Regression results available and up to date.")
    else
      div(class = "reg-status-wait", icon("clock"), " No results yet. Set your filters, then click Run.")
  })
  observeEvent(input$integ_run_regressions_now, {
    req(integ$filtered_data, integ$country_code)
    withProgress(message="Running integrity regression analysis...", value=0, {
      tryCatch({
        config <- safe_pipeline_config(integ$country_code)
        incProgress(0.1, detail="Single-bidding panel data...")
        comp_results <- tryCatch(
          analyze_competition(integ$filtered_data, config, tempdir(),
                              run_regressions=TRUE, save_plots=FALSE),
          error = function(e) {
            showNotification(paste("Single-bidding error:", e$message), type="warning", duration=15)
            message("analyze_competition error: ", e$message)
            NULL
          })
        if (!is.null(comp_results)) {
          # Ensure competition sub-list exists (initial pipeline may have returned NULL)
          if (is.null(integ$filtered_analysis$competition))
            integ$filtered_analysis$competition <- list()
          integ$filtered_analysis$competition$singleb_data        <- comp_results$singleb_data
          integ$filtered_analysis$competition$singleb_specs       <- comp_results$singleb_specs
          integ$filtered_analysis$competition$singleb_sensitivity <- comp_results$singleb_sensitivity
          integ$filtered_analysis$competition$singleb_plot        <- comp_results$singleb_plot
          integ$filtered_analysis$competition$singleb_best_row    <- comp_results$singleb_best_row
          integ$filtered_analysis$competition$singleb_is_robust   <- comp_results$singleb_is_robust
        }
        incProgress(0.5, detail="Price regressions...")
        price_results <- tryCatch(
          analyze_prices(integ$filtered_data, config, tempdir()),
          error = function(e) {
            showNotification(paste("Price regression error:", e$message), type="warning", duration=15)
            message("analyze_prices error: ", e$message)
            NULL
          })
        integ$filtered_analysis$prices <- price_results
        integ$regression_done <- TRUE
        incProgress(1.0, detail="Done.")
        showNotification("Regression analysis complete!", type="message", duration=5)
      }, error=function(e) showNotification(paste("Regression error:", e$message), type="error", duration=10))
    })
  })
  
  output$integ_singleb_plot_ui <- renderUI({
    if (isTRUE(integ$regression_done) && !is.null(integ$filtered_analysis$competition$singleb_plot))
      plotOutput("integ_singleb_plot", height="500px")
    else if (isTRUE(integ$regression_done))
      div(class="alert alert-warning", icon("info-circle"), " The single-bidding model could not be produced with the current filters.")
    else div(class="deferred-box", icon("clock"), " Click 'Run / Re-run Regression Analysis' above.")
  })
  output$integ_singleb_plot <- renderPlot({
    req(integ$regression_done, integ$filtered_analysis$competition$singleb_plot)
    print(integ$filtered_analysis$competition$singleb_plot)
  })
  output$integ_download_singleb_ui <- renderUI({
    req(integ$regression_done, integ$filtered_analysis$competition$singleb_plot)
    downloadButton("integ_dl_singleb", "Download Figure", class="download-btn btn-sm")
  })
  output$integ_relprice_plot_ui <- renderUI({
    if (isTRUE(integ$regression_done) && !is.null(integ$filtered_analysis$prices$rel_price_plot))
      plotOutput("integ_relprice_plot", height="500px")
    else if (isTRUE(integ$regression_done))
      div(class="alert alert-warning", icon("info-circle"), " The relative price model could not be produced with the current filters.")
    else div(class="deferred-box", icon("clock"), " Click 'Run / Re-run Regression Analysis' above.")
  })
  output$integ_relprice_plot <- renderPlot({
    req(integ$regression_done, integ$filtered_analysis$prices$rel_price_plot)
    print(integ$filtered_analysis$prices$rel_price_plot)
  })
  output$integ_download_relprice_ui <- renderUI({
    req(integ$regression_done, integ$filtered_analysis$prices$rel_price_plot)
    downloadButton("integ_dl_relprice", "Download Figure", class="download-btn btn-sm")
  })
  
  # ── Integrity model specification panels ──────────────────────────────────
  output$integ_singleb_formula_ui <- renderUI({
    req(integ$regression_done)
    best_row  <- integ$filtered_analysis$competition$singleb_best_row
    is_robust <- integ$filtered_analysis$competition$singleb_is_robust
    if (is.null(best_row)) return(NULL)
    # Plain-language effect: the treatment is CONTINUOUS (a share, not a 0/1
    # flag), so the admin "flagged: 0 -> 1" phrasing does not apply. The
    # specs already store effect_strength = the p10 -> p90 change in the
    # predicted single-bidding rate at otherwise-typical values.
    effs   <- suppressWarnings(as.numeric(best_row$effect_strength %||% NA))
    interp <- if (is.finite(effs))
      paste0("Moving a buyer's cumulative missing-data share from a low level ",
             "(10th percentile) to a high level (90th percentile) changes the ",
             "predicted single-bidding rate by ", sprintf("%+.1f", effs * 100),
             " percentage points, holding other buyer characteristics at ",
             "typical values.")
    else NULL
    ftext <- .pa_formula_from_row(
      "cumulative_singleb_rate", "cumulative_missing_share", best_row,
      controls_map = list(
        x_only     = character(0),
        base       = c("log1p(n_contracts)", "log1p(avg_contract_value)"),
        base_extra = c("log1p(n_contracts)", "log1p(avg_contract_value)",
                       "buyer_buyertype")))
    make_formula_ui(m = NULL, best_row = best_row, is_robust = is_robust,
                    label           = "the buyer's cumulative missing-data share",
                    outcome_label   = "single bidding",
                    interp_override = interp,
                    formula_text    = ftext)
  })
  output$integ_relprice_formula_ui <- renderUI({
    req(integ$regression_done)
    best_row  <- integ$filtered_analysis$prices$relprice_best_row
    is_robust <- integ$filtered_analysis$prices$relprice_is_robust
    if (is.null(best_row)) return(NULL)
    est <- suppressWarnings(as.numeric(best_row$estimate %||% NA))
    mt  <- as.character(best_row$model_type %||% "")
    # Plain-language effect per model family: log-link/log-outcome models are
    # interpreted as approximate percentage changes; level models as changes
    # in the price ratio (= percentage points of the cost estimate). Scaled
    # to a 10-percentage-point increase in the missing-data share.
    interp <- if (is.finite(est)) {
      if (mt %in% c("ols_log", "gamma_log")) {
        pct <- (exp(est * 0.10) - 1) * 100
        paste0("A 10-percentage-point increase in a contract's missing-data ",
               "share is associated with a ", sprintf("%+.1f%%", pct),
               " change in the relative price (contract \u00f7 estimate), ",
               "holding other contract characteristics constant.")
      } else {
        paste0("A 10-percentage-point increase in a contract's missing-data ",
               "share is associated with a ", sprintf("%+.3f", est * 0.10),
               " change in the relative price (contract \u00f7 estimate) \u2014 ",
               "about ", sprintf("%+.1f", est * 10),
               " percentage points of the cost estimate, holding other ",
               "contract characteristics constant.")
      }
    } else NULL
    ftext <- .pa_formula_from_row(
      if (mt == "ols_log") "log(relative_price)" else "relative_price",
      "total_missing_share", best_row,
      controls_map = list(
        x_only = character(0),
        base   = c("log_contract_value", "buyer_buyertype", "tender_proceduretype")))
    make_formula_ui(m = NULL, best_row = best_row, is_robust = is_robust,
                    label           = "the contract's missing-data share",
                    outcome_label   = "the relative price (contract \u00f7 estimate)",
                    interp_override = interp,
                    formula_text    = ftext)
  })
  
  # ── Integrity robustness check outputs ───────────────────────────────────
  output$integ_singleb_robustness_plot <- renderPlotly({
    req(integ$filtered_analysis$competition$singleb_specs)
    .build_spec_coeff_plot(integ$filtered_analysis$competition$singleb_specs)
  })
  output$integ_singleb_robustness_table <- DT::renderDT({
    req(integ$filtered_analysis$competition$singleb_specs)
    .build_spec_table(integ$filtered_analysis$competition$singleb_specs)
  }, server = FALSE)
  
  output$integ_relprice_robustness_plot <- renderPlotly({
    req(integ$filtered_analysis$prices$specs)
    .build_spec_coeff_plot(integ$filtered_analysis$prices$specs)
  })
  output$integ_relprice_robustness_table <- DT::renderDT({
    req(integ$filtered_analysis$prices$specs)
    .build_spec_table(integ$filtered_analysis$prices$specs)
  }, server = FALSE)
  
  output$integ_singleb_sensitivity_table <- renderUI({
    specs  <- integ$filtered_analysis$competition$singleb_specs
    bundle <- integ$filtered_analysis$competition$singleb_sensitivity
    if (is.null(specs) || is.null(bundle))
      return(div(class="deferred-box", icon("clock"), " Click 'Run / Re-run Regression Analysis' above to see robustness checks."))
    n_hint <- nrow(specs)
    build_robustness_ui(bundle, "integ_singleb_robustness_plot",
                        "integ_singleb_robustness_table", n_hint)
  })
  output$integ_relprice_sensitivity_table <- renderUI({
    specs  <- integ$filtered_analysis$prices$specs
    bundle <- integ$filtered_analysis$prices$relprice_sensitivity
    if (is.null(specs) || is.null(bundle))
      return(div(class="deferred-box", icon("clock"), " Click 'Run / Re-run Regression Analysis' above to see robustness checks."))
    n_hint <- nrow(specs)
    build_robustness_ui(bundle, "integ_relprice_robustness_plot",
                        "integ_relprice_robustness_table", n_hint)
  })
  
  
  # [APP-SV34] INTEGRITY — FIGURE DOWNLOAD HANDLERS (stored plotly figs) ─────
  # ── Integrity download handlers — all use stored plotly figs ──────────
  # The regression figures are ggplots stored in filtered_analysis (the old
  # handlers pointed at integ$fig_singleb / fig_relprice, which were never
  # assigned — downloads always failed with "view first").
  output$integ_dl_singleb <- downloadHandler(
    filename = function() paste0("integ_singleb_", integ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      p <- integ$filtered_analysis$competition$singleb_plot
      if (is.null(p)) {
        showNotification("Run the integrity regressions first, then download.",
                         type = "warning", duration = 5); req(FALSE)
      }
      ok <- pa_save_plot_any(p, file, width_in = 10, height_in = 7)
      if (!isTRUE(ok)) {
        showNotification(paste0("Download failed: ", attr(ok, "reason") %||% "unknown error"),
                         type = "error", duration = 8); req(FALSE)
      }
    })
  output$integ_dl_relprice <- downloadHandler(
    filename = function() paste0("integ_relprice_", integ$country_code %||% "export",
                                 "_", format(Sys.Date(), "%Y%m%d"), ".png"),
    content  = function(file) {
      p <- integ$filtered_analysis$prices$rel_price_plot
      if (is.null(p)) {
        showNotification("Run the integrity regressions first, then download.",
                         type = "warning", duration = 5); req(FALSE)
      }
      ok <- pa_save_plot_any(p, file, width_in = 10, height_in = 7)
      if (!isTRUE(ok)) {
        showNotification(paste0("Download failed: ", attr(ok, "reason") %||% "unknown error"),
                         type = "error", duration = 8); req(FALSE)
      }
    })
  output$integ_dl_supplier_unusual <- .dl_integ_plotly(function() integ$fig_supp_unusual,  "integ_supplier_unusual", 1000, 700)
  output$integ_dl_market_unusual   <- .dl_integ_plotly(function() integ$fig_mkt_unusual,   "integ_market_unusual",   1000, 700)
  output$integ_dl_network <- downloadHandler(
    filename = function() paste0("integ_market_flow_matrix_", integ$country_code, ".png"),
    content  = function(file) {
      req(integ$filtered_analysis$markets$unusual_matrix)
      df <- tryCatch(integ_matrix_df(), error=function(e) NULL); req(df, nrow(df)>0)
      n_cl <- dplyr::n_distinct(levels(df$from)); axis_size <- max(9, min(14, 120/max(n_cl,1))); txt_size <- max(3.2, min(6.0, 56/max(n_cl,1)))
      p <- ggplot2::ggplot(df, ggplot2::aes(x=to, y=from, fill=n_bidders)) +
        ggplot2::geom_tile(colour="white", linewidth=0.6) +
        ggplot2::geom_text(ggplot2::aes(label=n_bidders, colour=dplyr::if_else(n_bidders>max(n_bidders,na.rm=TRUE)*0.55,"l","d")),
                           size=txt_size, fontface="bold", show.legend=FALSE) +
        ggplot2::scale_colour_manual(values=c(l="white",d="#1a252f"), guide="none") +
        ggplot2::scale_fill_gradientn(colours=c("#f0f7ff","#93c6e0","#2471a3","#1a5276"), na.value="grey95") +
        ggplot2::scale_x_discrete(position="top") +
        ggplot2::labs(x="↓ Target market", y="Home market →",
                      title=paste("Unusual Market Entry Flow -", integ$country_code %||% "")) +
        pa_theme() +
        ggplot2::theme(axis.text.x=ggplot2::element_text(angle=40,hjust=0,size=axis_size,face="bold"),
                       axis.text.y=ggplot2::element_text(size=axis_size,face="bold"),
                       panel.grid=ggplot2::element_blank(), plot.background=ggplot2::element_rect(fill="white",colour=NA))
      h_in <- max(6, min(16, n_cl*0.55+3)); ggplot2::ggsave(file, p, width=14, height=h_in, dpi=300, bg="white")
    }
  )
  output$integ_dl_network_graph <- downloadHandler(
    filename = function() paste0("integ_market_network_", integ$country_code, ".png"),
    content  = function(file) {
      req(integ$filtered_analysis$markets$unusual_matrix)
      set.seed(42)
      p <- build_network_graph_from_matrix(unusual_matrix=integ$filtered_analysis$markets$unusual_matrix,
                                           min_bidders=isolate(input$integ_net_min_bidders) %||% 4,
                                           top_n=isolate(input$integ_net_top_clusters) %||% 20,
                                           cl_filter=isolate(input$integ_net_cluster_filter), country=integ$country_code %||% "")
      ggplot2::ggsave(file, p, width=14, height=11, dpi=300, bg="white")
    }
  )
  
  
  # [APP-SV35] INTEGRITY — EXPORT (Word report + ZIP) ────────────────────────
  # ============================================================
  # INTEGRITY — EXPORT (Word report + ZIP)
  # ============================================================
  
  output$integ_dl_word_report <- downloadHandler(
    filename = function() paste0("procurement_integrity_", integ$country_code,
                                 "_", format(Sys.Date(), "%Y%m%d"), ".docx"),
    content  = function(file) {
      req(integ$data, integ$filtered_analysis, integ$country_code)
      withProgress(message = "Generating procurement integrity Word report...", value = 0, {
        incProgress(0.3, detail = "Preparing data...")
        filter_desc  <- get_filter_description(integ_filters$active)
        filters_text <- if (filter_desc == "No filters applied") "" else paste0("Applied Filters: ", filter_desc)
        incProgress(0.6, detail = "Creating document...")
        ok <- generate_integrity_word_report(
          filtered_data     = integ$filtered_data,
          filtered_analysis = integ$filtered_analysis,
          country_code      = integ$country_code,
          output_file       = file,
          filters_text      = filters_text
        )
        output$export_status <- renderText(if (ok) "Procurement integrity Word report generated!" else "Error generating integrity Word report.")
      })
    }
  )
  output$integ_dl_all_figures <- downloadHandler(
    filename = function() paste0("integ_all_figures_", integ$country_code, "_", format(Sys.Date(), "%Y%m%d"), ".zip"),
    content  = function(file) {
      req(integ$data, integ$filtered_analysis, integ$country_code)
      withProgress(message = "Creating integrity figures ZIP...", value = 0, {
        incProgress(0.1, detail = "Collecting figures...")
        temp_dir <- tempfile(); dir.create(temp_dir)
        cc <- integ$country_code
        
        # Stored plotly figs (exactly what is displayed) + a note per figure
        # telling the user how to generate anything that is still missing.
        view_do <- "Open the integrity Data Overview tab once, then re-download."
        view_mv <- "Open the Missing Values tab once, then re-download."
        run_adv <- "Run the advanced missingness tests (Missing Values tab), then re-download."
        run_net <- "Generate the network analysis (Risky Profiles tab), then re-download."
        run_reg <- "Run the integrity regressions (Regression tab) — note that applying filters resets them — then re-download."
        unusual_mat_zip <- integ$filtered_analysis$markets$unusual_matrix
        fm_zip <- pa_build_flow_matrix(unusual_mat_zip)
        net_gg <- if (!is.null(unusual_mat_zip) && nrow(unusual_mat_zip) > 0) tryCatch({
          set.seed(42)
          build_network_graph_from_matrix(
            unusual_matrix = unusual_mat_zip, min_bidders = 4, top_n = 20,
            cl_filter = NULL, country = integ$country_code %||% "")
        }, error = function(e) NULL) else NULL
        entries <- list(
          list(obj = integ$fig_miss_overall,   name = "integ_missing_overall",       w = 9,  h = 6, note = view_mv),
          list(obj = integ$fig_miss_buyer,     name = "integ_missing_buyer",         w = 9,  h = 7, note = view_mv),
          list(obj = integ$fig_miss_time,      name = "integ_missing_time",          w = 9,  h = 6, note = view_mv),
          list(obj = integ$fig_miss_proc,      name = "integ_missing_procedure",     w = 8,  h = 5, note = view_mv),
          list(obj = integ$fig_miss_cooc,      name = "integ_missing_cooccurrence",  w = 8,  h = 7, note = run_adv),
          list(obj = integ$fig_miss_mar,       name = "integ_missing_mar",           w = 8,  h = 7, note = run_adv),
          list(obj = integ$fig_supp_unusual,   name = "integ_supplier_unusual",      w = 8,  h = 6, note = run_net),
          list(obj = integ$fig_mkt_unusual,    name = "integ_market_unusual",        w = 8,  h = 6, note = run_net),
          list(obj = if (is.null(fm_zip)) NULL else fm_zip$plot,
               name = "integ_flow_matrix",   w = 10, h = 7, note = run_net),
          list(obj = net_gg,
               name = "integ_network_graph", w = 11, h = 8, note = run_net),
          list(obj = integ$fig_concentration,  name = "integ_concentration",         w = 11, h = 7, note = run_net),
          list(obj = integ$filtered_analysis$competition$singleb_plot,
               name = "integ_singleb",  w = 10, h = 7, note = run_reg),
          list(obj = integ$filtered_analysis$prices$rel_price_plot,
               name = "integ_relprice", w = 10, h = 7, note = run_reg)
        )
        statuses <- data.frame(figure = character(0), status = character(0),
                               note = character(0), stringsAsFactors = FALSE)
        n_figs <- length(entries); saved <- 0
        for (i in seq_along(entries)) {
          e <- entries[[i]]
          incProgress(0.1 + i / n_figs * 0.85, detail = paste("Saving figure", i, "of", n_figs))
          ok <- pa_save_plot_any(e$obj, file.path(temp_dir, paste0(e$name, "_", cc, ".png")),
                                 width_in = e$w, height_in = e$h)
          st <- if (isTRUE(ok)) "saved" else if (identical(attr(ok, "reason"), "not generated")) "skipped" else "failed"
          nt <- if (isTRUE(ok)) "" else if (st == "skipped") e$note else (attr(ok, "reason") %||% "unknown error")
          statuses <- rbind(statuses, data.frame(figure = e$name, status = st, note = nt,
                                                 stringsAsFactors = FALSE))
          if (isTRUE(ok)) saved <- saved + 1
        }
        pa_write_manifest(temp_dir, "Procurement Integrity", statuses)
        zip::zip(zipfile = file, files = list.files(temp_dir, full.names = TRUE), mode = "cherry-pick")
        output$export_status <- renderText(paste0(
          saved, " of ", nrow(statuses),
          " integrity figures saved to ZIP — see MANIFEST.txt inside the ZIP."))
        if (saved < nrow(statuses))
          showNotification(paste0(saved, " of ", nrow(statuses),
                                  " figures saved. MANIFEST.txt inside the ZIP explains how to generate the rest."),
                           type = "warning", duration = 8)
        unlink(temp_dir, recursive = TRUE)
      })
    }
  )
  
} # close server

server