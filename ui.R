# ============================================================================
# UNIFIED PROCUREMENT ANALYSIS APP — ui.R (dashboard layout, all tabs)
# ============================================================================
# Anchors [APP-UI01..UI19]; the master table of contents lives in global.R.
# This file must evaluate to the UI object — the bare `ui` on the last line
# is what Shiny picks up. Design/CSS lives in www/styles.css.
# ============================================================================

# [APP-UI01] UI ROOT: dashboardPage ──────────────────────────────────────────
ui <- dashboardPage(
  skin = "blue",
  
  dashboardHeader(
    title = tags$span(class = "app-logo",
                      tags$span("procuR",    class = "app-logo-name"),
                      tags$span("Analytics", class = "app-logo-sub")
    ),
    titleWidth = 260
  ),
  
  
  # [APP-UI02] SIDEBAR MENU — tab registry (tabName ↔ tabItem below) ─────────
  dashboardSidebar(
    width = 260,
    sidebarMenu(
      id = "sidebar",
      
      # ── Shared ──────────────────────────────────────────────────────
      menuItem("Setup",        tabName = "setup",        icon = icon("cog")),
      menuItem("Overview",     tabName = "overview",     icon = icon("home")),
      menuItem("Data Overview",tabName = "data_overview",icon = icon("table")),
      
      # ── Economic Outcomes ────────────────────────────────────────────
      tags$li(class = "section-header", "Economic Outcomes"),
      menuItem("Market Sizing",     tabName = "market_sizing",     icon = icon("chart-bar")),
      menuItem("Supplier Dynamics", tabName = "supplier_dynamics", icon = icon("users")),
      menuItem(tags$span("Networks", tags$span("★", style = "margin-left:6px; color:#f0c040; font-size:10px; vertical-align:middle;")),
               tabName = "networks", icon = icon("project-diagram")),
      menuItem("Relative Prices",   tabName = "relative_prices",   icon = icon("dollar-sign")),
      menuItem("Competition",       tabName = "competition",       icon = icon("trophy")),
      
      # ── Administrative Efficiency ────────────────────────────────────
      tags$li(class = "section-header", "Administrative Efficiency"),
      menuItem("Procedure Types",    tabName = "procedures",     icon = icon("list-check")),
      menuItem("Submission Periods", tabName = "submission",     icon = icon("clock")),
      menuItem("Decision Periods",   tabName = "decision",       icon = icon("gavel")),
      menuItem(tags$span("Regression Analysis", tags$span("★", style = "margin-left:6px; color:#f0c040; font-size:10px; vertical-align:middle;")),
               tabName = "regression", icon = icon("chart-line")),
      
      # ── Procurement Integrity ────────────────────────────────────────
      tags$li(class = "section-header", "Procurement Integrity"),
      menuItem(tags$span("Missing Values", tags$span("★", style = "margin-left:6px; color:#f0c040; font-size:10px; vertical-align:middle;")),
               tabName = "integrity_missing", icon = icon("exclamation-triangle")),
      menuItem("Interoperability",   tabName = "integrity_interop", icon = icon("link")),
      menuItem(tags$span("Risky Profiles", tags$span("★", style = "margin-left:6px; color:#f0c040; font-size:10px; vertical-align:middle;")),
               tabName = "integrity_risky", icon = icon("exclamation-circle")),
      menuItem(tags$span("Regression", tags$span("★", style = "margin-left:6px; color:#f0c040; font-size:10px; vertical-align:middle;")),
               tabName = "integrity_prices", icon = icon("chart-line")),
      
      # ── Export ───────────────────────────────────────────────────────
      tags$li(class = "export-sep-li"),
      menuItem("Export & Download", tabName = "export", icon = icon("download"))
    )
  ),
  
  dashboardBody(
    # Design system: read from www/styles.css and INLINED into the page at
    # startup (shiny::includeCSS). Inlining cannot silently fail to load the
    # way a static <link> can if the www/ folder is misplaced; if the file
    # sits next to the .R files instead, it is found there as a fallback.
    tags$head({
      .css_path <- if (file.exists("www/styles.css")) "www/styles.css"
      else if (file.exists("styles.css")) "styles.css"
      else NULL
      if (is.null(.css_path)) {
        warning("styles.css not found (looked in www/ and the app root) — ",
                "the app will render with the default unstyled theme")
        NULL
      } else includeCSS(.css_path)
    }),
    
    tabItems(
      
      
      # [APP-UI03] TAB UI: Setup (upload, country code, run button) ──────────
      # ==================================================================
      # SETUP
      # ==================================================================
      tabItem(tabName = "setup",
              h2("Setup & Data Upload"),
              fluidRow(
                box(title = "Upload Your Data", width = 8,
                    solidHeader = TRUE, status = "primary",
                    fluidRow(
                      column(6,
                             uiOutput("demo_load_ui"),
                             fileInput("datafile", label = tags$div(icon("file-csv"), tags$strong(" Choose CSV File")),
                                       accept = c("text/csv",".csv"), buttonLabel = "Browse..."),
                             textInput("country_code", "Country Code (2 letters — blank = auto-detect)", value = "",
                                       placeholder = "Auto-detecting from data…")
                      ),
                      column(6,
                             h4("Instructions:"),
                             tags$ol(
                               tags$li(tags$b("Fastest start:"), " click ", tags$b("Run Demo"),
                                       " — a bundled synthetic dataset loads with every threshold pre-configured"),
                               tags$li("Or upload your own dataset — or any country dataset from ",
                                       tags$a(href="https://www.procurementintegrity.org/data", target="_blank", "ProAct",
                                              style="color:#009FDA;font-weight:bold;"),
                                       " (choose and download it there), then click 'Run Analysis'"),
                               tags$li("Enter the two-letter country code (or leave blank for auto-detection)"),
                               tags$li("Use the Procedure Types tab to set value thresholds and filter procedure types"),
                               tags$li("Run Network or Regression analyses on demand from their respective tabs"),
                               tags$li("Use the Export tab to download reports and figures")
                             )
                      )
                    ),
                    br(),
                    actionButton("run_analysis",
                                 label = tags$span(icon("play-circle", class = "fa-lg"), " Run Analysis"),
                                 class = "btn-wb-success btn-lg",
                                 style = "width:100%; padding:15px; font-size:18px;"),
                    hr(),
                    verbatimTextOutput("analysis_status")
                ),
                box(title = "What This Tool Does", width = 4,
                    solidHeader = TRUE, status = "info", collapsible = TRUE,
                    h5(icon("chart-bar"), " Economic Outcomes"),
                    tags$ul(
                      tags$li("Market sizing across CPV sectors"),
                      tags$li("Supplier entry and dynamics"),
                      tags$li("Buyer–supplier network maps"),
                      tags$li("Relative price diagnostics"),
                      tags$li("Single-bid competition analysis")
                    ),
                    hr(),
                    h5(icon("gavel"), " Administrative Efficiency"),
                    tags$ul(
                      tags$li("Procedure type distribution"),
                      tags$li("Contract value bunching analysis"),
                      tags$li("Submission period diagnostics"),
                      tags$li("Decision period diagnostics"),
                      tags$li("Regression: admin efficiency → competition (on demand)")
                    ),
                    hr(),
                    h5(icon("shield-alt"), " Procurement Integrity"),
                    tags$ul(
                      tags$li("Data quality & missing value patterns"),
                      tags$li("Interoperability of buyer/supplier IDs"),
                      tags$li("Supplier concentration & unusual market entry"),
                      tags$li("Market flow matrix & supplier network graphs (on demand)"),
                      tags$li("Regression: transparency impact on prices & competition (on demand)")
                    )
                )
              )
      ),
      
      
      # [APP-UI04] TAB UI: Overview (econ headline boxes) ────────────────────
      # ==================================================================
      # OVERVIEW
      # ==================================================================
      tabItem(tabName = "overview",
              h2("Analysis Overview"),
              fluidRow(
                box(title = "Economic Outcomes", width = 4, status = "primary", solidHeader = TRUE,
                    p("Analyses market structure, supplier dynamics, pricing patterns, and competition",
                      " levels across CPV procurement markets."),
                    tags$ul(
                      tags$li(tags$b("Data Overview:"), " How many contracts, buyers, and suppliers are in the data? Which years are covered and where are the gaps?"),
                      tags$li(tags$b("Market Sizing:"), " Which CPV sectors account for the most contracts and the highest spend? Are a few markets driving most of the volume?"),
                      tags$li(tags$b("Supplier Dynamics:"), " How many new suppliers enter each market each year? Are markets dominated by repeat winners or genuinely open to newcomers?"),
                      tags$li(tags$b("Buyer–Supplier Networks:"), " Which buyers and suppliers are most interconnected? Are there tight clusters that may indicate restricted competition?"),
                      tags$li(tags$b("Relative Prices:"), " Are contracts regularly awarded above estimated prices? Which buyers and markets overspend most?"),
                      tags$li(tags$b("Competition:"), " What share of contracts attract only a single bid? Does this vary by procedure type, buyer type, or market?")
                    )
                ),
                box(title = "Administrative Efficiency", width = 4, status = "warning", solidHeader = TRUE,
                    p("Examines procedural compliance, timing efficiency, and their link to competitive outcomes."),
                    tags$ul(
                      tags$li(tags$b("Procedure Mix:"), " Are open procedures used as often as expected? Is there over-reliance on negotiated or direct-award procedures?"),
                      tags$li(tags$b("Contract Value Bunching:"), " Do contract values cluster suspiciously just below procurement thresholds, suggesting strategic splitting?"),
                      tags$li(tags$b("Submission Periods:"), " How many tender calls give bidders less than the legal minimum to prepare? Which procedure types and buyers issue the shortest deadlines?"),
                      tags$li(tags$b("Decision Periods:"), " How long does it take to award a contract after the bid deadline? Are excessively long decisions linked to lower competition?"),
                      tags$li(tags$b("Regression Analysis"), " (on demand): Do short submission windows or slow decisions statistically predict single-bidding, controlling for market and year?")
                    )
                ),
                box(title = "Procurement Integrity", width = 4, status = "primary", solidHeader = TRUE,
                    p("Assesses transparency and accountability, examining data quality, interoperability, and corruption risk indicators."),
                    tags$ul(
                      tags$li(tags$b("Data Quality:"), " Which fields are most often missing? Are reporting gaps concentrated in particular buyers, years, or procedure types?"),
                      tags$li(tags$b("Interoperability:"), " Can buyer and supplier records be matched to external registers? What share of organisations lack standard IDs?"),
                      tags$li(tags$b("Supplier Profiles & Market Entry:"), " Which suppliers bid unusually far outside their home market? Which markets attract the most atypical entrants?"),
                      tags$li(tags$b("Buyer–Supplier Concentration:"), " Which buyers award contracts to a narrow set of suppliers year after year? How has concentration evolved over time?"),
                      tags$li(tags$b("Network Analysis"), " (on demand): How do cross-market bidding flows look as a heatmap matrix and as a supplier network graph?"),
                      tags$li(tags$b("Regression Analysis"), " (on demand): Does missing data or lack of transparency predict higher single-bidding rates or elevated contract prices?")
                    )
                )
              )
      ),
      
      
      # [APP-UI05] TAB UI: Data Overview ─────────────────────────────────────
      # ==================================================================
      # DATA OVERVIEW (shared)
      # ==================================================================
      tabItem(tabName = "data_overview",
              h2("Data Overview"),
              fluidRow(
                box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                    tags$p(style = "color:#666; font-size:12px; margin-bottom:8px;",
                           icon("info-circle"),
                           " Filters here apply to the Data Overview tab only. Each analysis",
                           " section has its own independent filter controls."),
                    filter_bar_ui("econ", "overview")
                )
              ),
              fluidRow(
                valueBoxOutput("n_contracts",  width = 3),
                valueBoxOutput("n_buyers",     width = 3),
                valueBoxOutput("n_suppliers",  width = 3),
                valueBoxOutput("n_years",      width = 3)
              ),
              fluidRow(
                box(title = "Total Contract Number per Year", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Count of procurement contracts awarded each year in the filtered dataset.",
                          " Use this chart to spot sudden drops or spikes — these often indicate data collection gaps,",
                          " changes in reporting obligations, or exceptional procurement events.",
                          " Years with very few contracts should be treated with caution in downstream analyses.")),
                    plotlyOutput("contracts_year_plot", height = "380px"),
                    downloadButton("dl_contracts_year_econ", "Download Figure", class = "download-btn btn-sm")),
                box(title = "Total Contract Value by Year", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Sum of all contract values awarded each year.",
                          " A year with high contract count but low total value may reflect fragmentation into small contracts.",
                          " A year with low count but high value may reflect a small number of large framework awards.",
                          " Use alongside the contract count chart to understand spending concentration.")),
                    plotlyOutput("value_by_year_plot", height = "380px"),
                    downloadButton("dl_value_by_year", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Top Buyers", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("The most active buyers ranked by contract volume or value.",
                          " Uses masterid as identifier when available, falling back to buyer_id or buyer_name.")),
                    fluidRow(
                      column(6, sliderInput("overview_top_buyer_n", "Show top N:",
                                            min=5, max=50, value=15, step=5, width="100%")),
                      column(6, radioButtons("overview_buyer_metric", "Rank by:",
                                             choices=c("Contracts"="n_contracts","Value"="total_value"),
                                             selected="n_contracts", inline=TRUE))
                    ),
                    uiOutput("overview_top_buyers_plot_ui"),
                    downloadButton("dl_overview_top_buyers", "Download Figure", class="download-btn btn-sm")),
                box(title = "Top Suppliers", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("The most active suppliers ranked by contract volume or value.",
                          " Uses masterid as identifier when available, falling back to bidder_id or bidder_name.")),
                    fluidRow(
                      column(6, sliderInput("overview_top_supplier_n", "Show top N:",
                                            min=5, max=50, value=15, step=5, width="100%")),
                      column(6, radioButtons("overview_supplier_metric", "Rank by:",
                                             choices=c("Contracts"="n_contracts","Value"="total_value"),
                                             selected="n_contracts", inline=TRUE))
                    ),
                    uiOutput("overview_top_suppliers_plot_ui"),
                    downloadButton("dl_overview_top_suppliers", "Download Figure", class="download-btn btn-sm"))
              )
      ),
      
      
      # [APP-UI06] TAB UI: Market Sizing ─────────────────────────────────────
      # ==================================================================
      # ECONOMIC OUTCOMES — MARKET SIZING
      # ==================================================================
      tabItem(tabName = "market_sizing",
              h2("Market Sizing Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("econ", "market"))),
              div(class = "question-header", "What is the overall market composition?"),
              div(class = "description-box",
                  p("Market sizing examines how procurement spending is distributed across CPV markets.",
                    " CPV (Common Procurement Vocabulary) codes group contracts by product or service category.",
                    " The two-digit cluster used here groups related categories together for readability.")),
              fluidRow(
                box(title = "Market Size by Number of Contracts", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each bar is one CPV market, ranked by the total number of contracts awarded.",
                          " This shows where procurement activity is most frequent,",
                          " regardless of the monetary value of individual contracts.",
                          " Markets with very high contract counts but low total values (see chart below)",
                          " tend to consist of many small purchases.")),
                    plotlyOutput("market_size_n_plot", height = "450px"),
                    downloadButton("dl_market_size_n", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Market Size by Total Value", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each bar is one CPV market, ranked by the total value (USD) of contracts awarded.",
                          " This shows where the bulk of procurement spending is concentrated.",
                          " Compare with the contract count chart: markets ranking high here but low there",
                          " are dominated by a few large contracts.")),
                    plotlyOutput("market_size_v_plot", height = "450px"),
                    downloadButton("dl_market_size_v", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Market Size Bubble Plot", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each bubble represents one CPV market.",
                          strong(" X-axis"), " (log scale): number of contracts — further right means more activity.",
                          strong(" Y-axis"), " (log scale): average contract value (USD) — higher means larger individual contracts.",
                          strong(" Bubble size"), ": total market value (sum of all contracts).",
                          " Markets in the top-right have both high volume and high average value.",
                          " Markets in the bottom-left are small, low-value niches.",
                          " Hover over any bubble to see the full market name.")),
                    plotlyOutput("market_size_av_plot", height = "500px"),
                    downloadButton("dl_market_size_av", "Download Figure", class = "download-btn btn-sm"))
              )
      ),
      
      
      # [APP-UI07] TAB UI: Supplier Dynamics ─────────────────────────────────
      # ==================================================================
      # ECONOMIC OUTCOMES — SUPPLIER DYNAMICS
      # ==================================================================
      tabItem(tabName = "supplier_dynamics",
              h2("Supplier Dynamics Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("econ", "supplier"))),
              
              # ── Market size filter row ──────────────────────────────────────
              fluidRow(
                box(title = "Market Size Filters", width = 12, solidHeader = FALSE, status = "warning",
                    collapsible = TRUE, collapsed = FALSE,
                    p(style="color:#666;font-size:13px;margin-bottom:10px;",
                      "Narrow to markets of a specific size so small or very large markets don't dominate the charts."),
                    fluidRow(
                      column(6, uiOutput("market_contracts_range_slider")),
                      column(6, uiOutput("market_value_range_slider"))
                    ),
                    fluidRow(
                      column(12,
                             actionButton("apply_market_filters", "Apply",
                                          icon = icon("filter"), class = "btn-primary btn-sm"),
                             actionButton("reset_market_filters", "Reset",
                                          icon = icon("undo"), class = "btn-default btn-sm"),
                             span(style="margin-left:12px;font-size:12px;color:#666;",
                                  textOutput("market_filter_status", inline=TRUE))
                      )
                    )
                )
              ),
              
              # ── Plot 1: Combined bubble grid ────────────────────────────────
              div(class = "question-header", "Which markets are large, and how volatile is their supplier base?"),
              fluidRow(
                box(title = "Supplier Landscape: Size & Volatility", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each cell shows one CPV market in one year.",
                          strong(" Bubble size"), " = total unique suppliers (market depth).",
                          strong(" Colour"), " = % new suppliers that year: red = high churn (many first-time entrants),",
                          " blue = stable base (mostly repeat suppliers).",
                          " Large red cells are both competitive and volatile; small blue cells are shallow and captive.")),
                    fluidRow(
                      column(4,
                             sliderInput("econ_new_threshold", "Red above (% new suppliers):",
                                         min=0, max=100, value=50, step=5, post="%", width="100%")
                      ),
                      
                      column(4,
                             checkboxInput("supp_show_labels", "Show CPV labels on y-axis", value=TRUE),
                             checkboxInput("supp_show_counts", "Show supplier counts in cells", value=FALSE)
                      )
                    ),
                    uiOutput("supplier_bubble_plot_ui"),
                    downloadButton("dl_suppliers_entrance", "Download Figure", class="download-btn btn-sm")
                )
              ),
              
              # ── Plot 2: Market stability scatter ────────────────────────────
              div(class = "question-header", "Which markets are deep and stable vs shallow and churning?"),
              fluidRow(
                box(title = "Market Stability Overview (avg across years)", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("One dot per CPV market, each metric averaged across all observed years.",
                          strong(" X-axis:"), " average % new suppliers — higher means more first-time entrants each year (open / competitive market).",
                          strong(" Y-axis:"), " average number of unique suppliers per year (market depth).",
                          strong(" Bubble size:"), " average number of contracts per year.",
                          strong(" Colour:"), " blue = low entry rate (mostly repeat suppliers), red = high entry rate (many new entrants).",
                          br(),
                          "The dotted lines mark the median of each axis across all markets, splitting the chart into four quadrants:",
                          tags$ul(
                            tags$li(strong("Top-left:"), " deep + high entry — large competitive market with frequent newcomers."),
                            tags$li(strong("Top-right:"), " deep + stable — large market dominated by repeat suppliers (possible incumbency)."),
                            tags$li(strong("Bottom-left:"), " shallow + high entry — small market with high churn (fragile, few contracts)."),
                            tags$li(strong("Bottom-right:"), " shallow + stable — small captive market, same few suppliers repeat (red flag).")
                          ),
                          "Hover over any dot for the entry rate ", strong("volatility (SD)"), " — the year-to-year standard deviation of % new suppliers.",
                          " A market with SD = 20% swings between, say, 10% and 50% new suppliers in different years.",
                          " A market with SD = 2% is consistently predictable regardless of its average.")),
                    plotlyOutput("supplier_stability_plot", height="550px"),
                    downloadButton("dl_unique_supp", "Download Figure", class="download-btn btn-sm")
                )
              ),
              
              # ── Plot 3: Supplier trend for selected markets ──────────────────
              div(class = "question-header", "How has the supplier base evolved over time in key markets?"),
              fluidRow(
                box(title = "New vs Repeat Suppliers Over Time", width = 12,
                    solidHeader = TRUE, status = "info",
                    div(class = "description-box",
                        p("Stacked area chart showing how many suppliers were new (first appearance in that market)",
                          " vs repeat (seen in prior years) for each selected market.",
                          " A growing green area means the market is attracting new entrants.",
                          " A shrinking or flat area dominated by repeat suppliers may indicate barriers to entry.")),
                    fluidRow(
                      column(4, uiOutput("supp_trend_market_picker_ui")),
                      column(4, radioButtons("supp_trend_metric", "Show as:",
                                             choices = c("Count" = "count", "Share (%)" = "share"),
                                             selected = "count", inline = TRUE))
                    ),
                    uiOutput("supplier_trend_plot_ui"),
                    downloadButton("dl_supp_trend", "Download Figure", class="download-btn btn-sm")
                )
              ),
              
              # ── Plot 4: Top Suppliers ───────────────────────────────────────
              div(class = "question-header", "Who are the dominant suppliers?"),
              fluidRow(
                box(title = "Top Suppliers by Contracts Won", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Ranks the top suppliers by number of contracts won in the filtered dataset.",
                          strong(" Bar length"), " = contracts won.",
                          strong(" Dot colour"), " = total contract value won (darker = higher value).",
                          strong(" Right label"), " = number of distinct CPV markets served.",
                          " Suppliers active across many markets may indicate broad dominance or",
                          " potential conflict-of-interest risk.")),
                    fluidRow(
                      column(4,
                             sliderInput("top_supp_n", "Number of suppliers to show:",
                                         min = 5, max = 50, value = 20, step = 5, width = "100%")),
                      column(4,
                             selectInput("top_supp_metric", "Rank by:",
                                         choices = c("Contracts won" = "n_contracts",
                                                     "Total value won" = "total_value",
                                                     "Markets served"  = "n_markets"),
                                         selected = "n_contracts", width = "100%"))
                    ),
                    uiOutput("top_suppliers_plot_ui"),
                    downloadButton("dl_top_suppliers", "Download Figure", class = "download-btn btn-sm")
                )
              )
      ),
      
      
      # [APP-UI08] TAB UI: Networks (on-demand) ──────────────────────────────
      # ==================================================================
      # ECONOMIC OUTCOMES — NETWORKS
      # ==================================================================
      tabItem(tabName = "networks",
              h2("Buyer-Supplier Networks"),
              fluidRow(
                box(title = "Network Generation", width = 12, status = "warning", solidHeader = TRUE, collapsible = TRUE,
                    div(class = "description-box",
                        p(icon("info-circle"), tags$strong(" About networks:"),
                          " These diagrams visualize buyer-supplier relationships in selected CPV markets.",
                          " Dense, well-connected networks suggest diverse sourcing, while star-shaped networks",
                          " around a single supplier may indicate limited competition.",
                          " Networks are memory-intensive — generate only the markets you need.")),
                    fluidRow(
                      column(6,
                             uiOutput("network_cpv_picker_ui"),
                             numericInput("network_top_buyers", "Max buyers per network:", value = 15, min = 5, max = 50, step = 5)
                      ),
                      column(6,
                             uiOutput("network_status_box"),
                             br(),
                             actionButton("run_networks_now",
                                          label = tags$span(icon("play-circle"), " Generate / Re-generate Networks"),
                                          class = "btn-success btn-lg",
                                          style = "width: 100%; margin-top: 10px;")
                      )
                    )
                )
              ),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("econ", "network"))),
              div(class = "question-header", "Are buyers able to choose from a variety of market offerings?"),
              fluidRow(
                box(title = "Network Visualizations", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each diagram shows which buyers (squares) connect to which suppliers (circles) in a CPV market.",
                          " Use the controls above to select markets and click Generate.")),
                    uiOutput("network_plots_ui"))
              )
      ),
      
      
      # [APP-UI09] TAB UI: Relative Prices ───────────────────────────────────
      # ==================================================================
      # ECONOMIC OUTCOMES — RELATIVE PRICES
      # ==================================================================
      tabItem(tabName = "relative_prices",
              h2("Relative Price Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("econ", "price"))),
              div(class = "question-header", "Are there price savings or price overruns prevailing?"),
              fluidRow(
                box(title = "Overall: Under vs Over Budget", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box", p("Distribution of relative prices (contract ÷ estimate).",
                                                     " Blue zone = came in under budget, red zone = over budget.",
                                                     " The dashed line marks the estimate (1.0); the amber line marks the median.")),
                    plotlyOutput("rel_tot_plot", height = "380px"),
                    downloadButton("dl_rel_tot", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Trend Over Time", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each dot is the percentage of contracts that exceeded their estimated price in that year.",
                          " The grey ribbon is the ", strong("95% confidence interval"), " on that proportion.",
                          " The dashed horizontal line marks the overall average across all years.",
                          " Dots coloured ", strong("red"), " sit above the overall average; ",
                          strong("teal"), " dots sit below.",
                          " Hover for exact values and confidence bounds.")),
                    plotlyOutput("rel_year_plot", height = "350px"),
                    downloadButton("dl_rel_year", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "By Market (CPV Sector)", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Every CPV market is shown as one dot, ranked top-to-bottom by",
                          strong(" % of contracts that exceeded their estimated price."),
                          " The horizontal whiskers are ", strong("95% confidence intervals"), " on that proportion.",
                          " The grey number to the right of each whisker is the contract count.",
                          " The dashed vertical line is the cross-market average.",
                          " Colour: ", strong("teal"), " = below average; ",
                          strong("amber"), " = above average; ",
                          strong("red"), " = 10 percentage points or more above average.",
                          " Dot size is proportional to contract count.")),
                    uiOutput("rel_10_plot_ui"),
                    downloadButton("dl_rel_10", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "By Buyer", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Buyers ranked by their ", strong("mean relative price"), " (mean of contract price ÷ estimated price across all their contracts).",
                          " The stick starts at 1.0 (budget line); the dot marks the buyer's mean.",
                          " A dot to the right of 1.0 means the buyer's contracts have, on average, exceeded their estimated prices.",
                          " Dot size is proportional to contract volume.",
                          " Colour: ", strong("teal"), " = at or under budget; ",
                          strong("amber"), " = slightly over (up to 1.2); ",
                          strong("red"), " = clearly over (above 1.2).",
                          " Hover for the % over budget and total contract value.")),
                    fluidRow(
                      column(6, sliderInput("rel_buy_top_n",
                                            "Number of buyers to show:",
                                            min = 5, max = 50, value = 20, step = 5)),
                      column(6, sliderInput("rel_buy_min_contracts",
                                            "Minimum contracts per buyer:",
                                            min = 1, max = 100, value = 10, step = 1))
                    ),
                    uiOutput("rel_buy_plot_ui"),
                    downloadButton("dl_rel_buy", "Download Figure", class = "download-btn btn-sm"))
              ),
              div(class = "question-header", "Do small or large contracts suffer more from price overruns?"),
              fluidRow(
                box(title = "Relative Price by Contract Size", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each box shows the distribution of relative prices within a contract value band.",
                          " Bands are in ", strong("USD"), " and match those in the Competition Analysis tab:",
                          " < $5k \u2022 $5k\u2013$10k \u2022 $10k\u2013$50k \u2022 $50k\u2013$100k \u2022 $100k\u2013$500k \u2022 $500k\u2013$1M \u2022 > $1M.",
                          strong(" Box"), " = 25th\u201375th percentile,",
                          strong(" line"), " = median,",
                          strong(" whiskers"), " = 5th\u201395th percentile.",
                          " The dashed line at 1.0 is the budget. Boxes coloured",
                          strong(" red"), " when median is above budget,",
                          strong(" teal"), " when below.",
                          " The % label above each box = share of contracts in that band that are over budget.")),
                    plotlyOutput("rel_size_plot", height = "420px"),
                    downloadButton("dl_rel_size", "Download Figure", class = "download-btn btn-sm"))
              )
      ),
      
      
      # [APP-UI10] TAB UI: Competition (single-bid) ──────────────────────────
      # ==================================================================
      # ECONOMIC OUTCOMES — COMPETITION
      # ==================================================================
      tabItem(tabName = "competition",
              h2("Competition Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("econ", "competition"))),
              div(class = "question-header", "Is there high competition?"),
              div(class = "description-box", style = "margin: 0 15px 16px 15px;",
                  p(strong("What is a single-bid contract?"),
                    " A single-bid contract is one where only one supplier submitted an offer.",
                    " With no competing offers, the buyer has no leverage on price or quality —",
                    " the awarded price is whatever the sole bidder asked for.",
                    " A persistently high single-bid rate signals weak market competition and",
                    " is a recognised red flag for procurement integrity.",
                    " International benchmarks suggest rates above 20–30% warrant investigation,",
                    " though context matters: some sectors and procedure types are structurally",
                    " less competitive than others.")
              ),
              # Row 1: Trend over time + By Contract Value
              fluidRow(
                box(title = "Single-Bid Rate Over Time", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Each dot shows the percentage of contracts in that year that received",
                          strong(" exactly one bid."),
                          " The grey ribbon is the 95% confidence interval — wider ribbons mean",
                          " fewer contracts in that year and less statistical certainty.",
                          " The dashed line is the all-years average.",
                          br(), br(),
                          strong("How to read it:"),
                          " A rising trend suggests competition is deteriorating over time.",
                          " A spike in a single year may reflect an unusual procurement event or",
                          " a data gap (few contracts recorded).",
                          strong(" Red dots"), " mark years above the overall average;",
                          strong(" teal dots"), " mark years below.",
                          " Hover over any dot for the exact rate, contract count, and confidence bounds.")),
                    radioButtons("sb_overall_metric", label = NULL, inline = TRUE,
                                 choices = c("Rate within year"        = "rate",
                                             "Share of all single bids" = "distribution"),
                                 selected = "rate"),
                    plotlyOutput("single_bid_overall_plot", height = "420px"),
                    downloadButton("dl_single_bid_overall", "Download", class = "download-btn btn-sm")),
                box(title = "By Contract Value", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Single-bid rate broken down by the contract’s awarded value.",
                          " Each bar covers one value band (e.g. $10K–$50K).",
                          " The number above each bar is the count of contracts in that band.",
                          br(), br(),
                          strong("What to look for:"),
                          " A U-shaped pattern — high rates at both extremes — is common.",
                          " Very small contracts (micro-purchases) are often bought without",
                          " advertising widely, so fewer suppliers respond.",
                          " Very large contracts are complex and few suppliers can deliver them.",
                          strong(" The mid-range"), " is where a healthy market should show",
                          " the lowest single-bid rates.",
                          " If the highest rates appear in the", strong(" mid-value bands"),
                          " — where competition should be strongest — that is a red flag.",
                          " Hover for exact rates and contract counts per band.")),
                    radioButtons("sb_price_metric", label = NULL, inline = TRUE,
                                 choices = c("Rate within band"         = "rate",
                                             "Share of all single bids" = "distribution"),
                                 selected = "rate"),
                    plotlyOutput("single_bid_price_plot", height = "420px"),
                    downloadButton("dl_single_bid_price", "Download", class = "download-btn btn-sm"))
              ),
              # Row 2: Procedure + Buyer Group
              fluidRow(
                box(title = "By Procedure Type", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Single-bid rate for each procurement procedure type.",
                          " Each dot is one procedure type; horizontal whiskers are",
                          strong(" 95% confidence intervals"), " on the rate.",
                          " Dot size is proportional to the number of contracts.",
                          br(), br(),
                          strong("What to look for:"),
                          " Open Procedures — the most competitive and transparent route —",
                          " should have the lowest single-bid rate.",
                          " Negotiated and Direct Award procedures are expected to be higher",
                          " because they often involve a pre-selected supplier.",
                          " A concern arises when", strong(" Open Procedures"),
                          " have a high single-bid rate comparable to Negotiated ones:",
                          " it suggests that even nominally open tenders are not attracting",
                          " genuine market interest.",
                          " A very wide confidence interval means few contracts in that category",
                          " — interpret with caution.")),
                    plotlyOutput("single_bid_procedure_plot", height = "420px"),
                    downloadButton("dl_single_bid_procedure", "Download", class = "download-btn btn-sm")),
                box(title = "By Buyer Group", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Single-bid rate grouped by the type of buying institution",
                          " (e.g. national government, local authority, public utility, health body).",
                          " Each dot is one buyer group with 95% confidence intervals.",
                          br(), br(),
                          strong("What to look for:"),
                          " Different buyer types operate in different markets and under different",
                          " legal frameworks, so some variation is expected.",
                          " Local governments and utilities often procure niche services with",
                          " few local suppliers, which can legitimately push rates up.",
                          " A buyer group that sits", strong(" well above all others"),
                          " — especially a central government body that should have the",
                          " most procurement capacity — is worth investigating.",
                          " Compare this chart with the By Procedure Type chart:",
                          " if a high-rate buyer group also over-uses negotiated procedures,",
                          " that is a compounding risk signal.")),
                    plotlyOutput("single_bid_buyer_group_plot", height = "420px"),
                    downloadButton("dl_single_bid_buyer_group", "Download", class = "download-btn btn-sm"))
              ),
              # Row 3: CPV Sector (full width)
              fluidRow(
                box(title = "By Market", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Single-bid rate for each CPV (Common Procurement Vocabulary) sector —",
                          " the two-digit code that classifies what is being purchased.",
                          " Each dot is one sector; horizontal whiskers are",
                          strong(" 95% confidence intervals."),
                          " The grey count to the right is the number of contracts.",
                          " Sectors are ranked from highest to lowest single-bid rate.",
                          " The dashed vertical line is the cross-sector average.",
                          strong(" Teal"), " = below average;",
                          strong(" amber"), " = above average;",
                          strong(" red"), " = 10 percentage points or more above average.",
                          br(), br(),
                          strong("What to look for:"),
                          " Sectors at the top of the chart have the weakest competition.",
                          " Some markets are naturally thin — specialist military equipment",
                          " or highly technical research services may have few qualified suppliers.",
                          " More concerning are everyday goods or construction sectors",
                          " (e.g. office supplies, road works) appearing near the top:",
                          " these markets are competitive globally, so high single-bid rates",
                          " there suggest local barriers, restricted advertising, or collusion.",
                          " Sectors with very wide confidence intervals (few contracts) should",
                          " be interpreted cautiously.",
                          " Use the Market filter above to isolate specific sectors.")),
                    uiOutput("single_bid_market_plot_ui"),
                    downloadButton("dl_single_bid_market", "Download", class = "download-btn btn-sm"))
              ),
              # Row 4: Top buyers (full width)
              fluidRow(
                box(title = "Top Buyers by Single-Bid Rate", width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("The buyers with the highest share of single-bid contracts,",
                          " ranked from worst to best.",
                          " Only buyers with at least the minimum contract count (set by the slider below)",
                          " are included — this filters out buyers who appear to have a 100% rate",
                          " simply because they awarded only one or two contracts ever.",
                          " Each dot is one buyer; the label shows the buyer name and",
                          " total contract count in brackets.",
                          " Dot size is proportional to total contract volume.",
                          strong(" Colour scale:"),
                          " teal = close to the overall average; amber = moderately above; red = well above average.",
                          br(), br(),
                          strong("What to look for:"),
                          " A buyer near the top with a large dot — meaning they are both",
                          " highly active and consistently fail to attract competition —",
                          " is the most important finding.",
                          " Cross-reference with the By Procedure Type chart:",
                          " if a buyer here also over-uses Direct Award or Negotiated procedures,",
                          " the combination is a strong integrity signal.",
                          " Use the sliders to adjust the minimum contract threshold and",
                          " the number of buyers displayed.")),
                    fluidRow(
                      column(6, sliderInput("sb_buy_top_n",
                                            "Number of buyers to show:",
                                            min = 5, max = 50, value = 20, step = 5)),
                      column(6, sliderInput("sb_buy_min_tenders",
                                            "Minimum contracts per buyer:",
                                            min = 0, max = 500, value = 50, step = 10))
                    ),
                    uiOutput("top_buyers_single_bid_plot_ui"),
                    downloadButton("dl_top_buyers_single_bid", "Download", class = "download-btn btn-sm"))
              )
      ),
      
      
      # [APP-UI11] TAB UI: Procedure Types (admin) ───────────────────────────
      # ==================================================================
      # ADMIN — CONFIGURATION
      # ==================================================================
      # ==================================================================
      # ADMIN — PROCEDURE TYPES
      # ==================================================================
      tabItem(tabName = "procedures",
              h2("Procedure Type Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("admin", "proc"))),
              div(class = "question-header", "Is there an overuse of some procedure types?"),
              fluidRow(
                box(title = "Procedure Type Share by Contract Value", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Share of total awarded contract value channelled through each procedure type.",
                          " Open procedures should dominate in well-functioning systems above the relevant value threshold.",
                          " A large share for ", strong("Negotiated without publications"), " or ",
                          strong("Direct Awards"), " — especially for high-value contracts — may indicate",
                          " that competitive tendering requirements are being circumvented.",
                          " Compare with the contract count chart: a procedure type with a small count share",
                          " but a large value share means it is used selectively for large contracts.")),
                    plotlyOutput("procedure_share_value_plot", height = "420px"),
                    downloadButton("dl_proc_share_value", "Download Figure", class = "download-btn btn-sm")),
                box(title = "Procedure Type Share by Contract Count", width = 6, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Share of total contract numbers awarded through each procedure type.",
                          " This captures frequency of use, independently of contract size.",
                          " A high share of non-competitive procedures (Direct Awards, Negotiated without publications)",
                          " even for small-value contracts points to a systemic preference for bypassing competition.",
                          " Use this alongside the value chart to distinguish whether overuse is concentrated",
                          " in a few large contracts or is pervasive across many small ones.")),
                    plotlyOutput("procedure_share_count_plot", height = "420px"),
                    downloadButton("dl_proc_share_count", "Download Figure", class = "download-btn btn-sm"))
              ),
              div(class = "question-header", "Is there bunching of contract values near procedure-type thresholds?"),
              
              # ── Procurement Value Thresholds ────────────────────────────────
              fluidRow(
                box(title = "Procurement Value Thresholds (local currency — bid_price column)",
                    width = 12, solidHeader = TRUE, status = "primary", collapsible = TRUE,
                    p(class = "description-box",
                      "Legal contract-value boundaries that determine which procedure type is required.",
                      " Contracts kept just ", em("below"), " a threshold to avoid the more demanding procedure",
                      " will show up as bunching in the analysis below.",
                      " Enter the value above which ", strong("Open Procedure"), " is legally required,",
                      " separately for each supply type. Leave blank if no threshold applies."),
                    fluidRow(
                      column(3), column(3, strong(icon("box"), " Goods")),
                      column(3, strong(icon("hard-hat"), " Works")),
                      column(3, strong(icon("briefcase"), " Services"))
                    ),
                    hr(style = "margin:6px 0;"),
                    fluidRow(
                      column(3, p(strong("Open Procedure threshold:"))),
                      column(3, numericInput("price_open_goods",    NULL, value = NA, min = 0, step = 1000)),
                      column(3, numericInput("price_open_works",    NULL, value = NA, min = 0, step = 1000)),
                      column(3, numericInput("price_open_services", NULL, value = NA, min = 0, step = 1000))
                    ),
                    tags$div(style = "display:none;",
                             numericInput("price_rest_goods", NULL, value = NA),
                             numericInput("price_rest_works", NULL, value = NA),
                             numericInput("price_rest_services", NULL, value = NA),
                             numericInput("price_neg_pub_goods", NULL, value = NA),
                             numericInput("price_neg_pub_works", NULL, value = NA),
                             numericInput("price_neg_pub_services", NULL, value = NA),
                             numericInput("price_neg_nopub_goods", NULL, value = NA),
                             numericInput("price_neg_nopub_works", NULL, value = NA),
                             numericInput("price_neg_nopub_services", NULL, value = NA),
                             numericInput("price_competitive_goods", NULL, value = NA),
                             numericInput("price_competitive_works", NULL, value = NA),
                             numericInput("price_competitive_services", NULL, value = NA),
                             numericInput("price_innov_goods", NULL, value = NA),
                             numericInput("price_innov_works", NULL, value = NA),
                             numericInput("price_innov_services", NULL, value = NA),
                             numericInput("price_direct_goods", NULL, value = NA),
                             numericInput("price_direct_works", NULL, value = NA),
                             numericInput("price_direct_services", NULL, value = NA),
                             numericInput("price_other_goods", NULL, value = NA),
                             numericInput("price_other_works", NULL, value = NA),
                             numericInput("price_other_services", NULL, value = NA),
                             # hidden inputs kept so server observers remain valid
                             checkboxGroupInput("global_proc_filter", label = NULL,
                                                choices = PROC_TYPE_LABELS, selected = PROC_TYPE_LABELS)
                    ),
                    hr(style = "margin:10px 0;"),
                    fluidRow(
                      column(12,
                             actionButton("apply_thresholds", "Apply Thresholds",
                                          icon = icon("check"), class = "btn-success"),
                             span(style = "margin-left:15px; color:#27ae60; font-weight:bold;",
                                  textOutput("threshold_status", inline = TRUE))
                      )
                    )
                )
              ),
              fluidRow(
                box(title = "Contract Value Distribution by Supply Type",
                    width = 12, solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Log-scale histogram of contract values, with separate panels for",
                          strong(" Goods"), ",", strong(" Works"), ", and", strong(" Services"), ".",
                          " Each coloured series represents one procedure type.",
                          " Use this chart to understand the overall shape and spread of procurement spending.")),
                    fluidRow(
                      column(3,
                             checkboxGroupInput("proc_value_dist_procs", "Show procedure types:",
                                                choices  = PROC_TYPE_LABELS,
                                                selected = c("Open Procedure","Restricted Procedure","Negotiated with publications"),
                                                inline   = FALSE)
                      ),
                      column(9, plotlyOutput("proc_value_dist_plot", height = "420px"))
                    ),
                    downloadButton("dl_proc_value_dist", "Download Figure", class = "download-btn btn-sm")
                )
              ),
              fluidRow(
                box(title = "Bunching Analysis: Are contracts clustered just below legal thresholds?",
                    width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("Each panel shows the", strong("overall distribution of all contracts"),
                          " (across all procedure types) for one supply category,",
                          " zoomed in around one legal value threshold.",
                          " The logic is: a threshold like 30K means Open Procedure is",
                          strong(" required"), " above that value.",
                          " Buyers who want to avoid that requirement may split contracts",
                          " to keep them just below the threshold.",
                          " A spike in", strong(" all contracts"), " just below the threshold",
                          " — regardless of which procedure they formally used —",
                          " is the warning sign.", br(), br(),
                          " The", strong(" dotted line"), " is the statistical counterfactual:",
                          " what the distribution", em("would"), " look like with no manipulation,",
                          " estimated by fitting a smooth curve to the parts of the distribution",
                          " away from the threshold.", br(),
                          strong("Excess mass %"), " = how many more contracts sit just below",
                          " the threshold than the model expects under normal procurement behaviour.",
                          " Red bars and a large positive % are the key warning indicators.")),
                    uiOutput("bunching_status_ui"),
                    fluidRow(
                      column(4,
                             sliderInput("n_search_bins",
                                         "Search zone width (bins below threshold):",
                                         min = 1, max = 25, value = 10, step = 1),
                             helpText(icon("info-circle"),
                                      " Each bin = 0.05 log₁₀ units ≈ 12% of the threshold value.",
                                      " 10 bins covers roughly the 50% of the threshold value",
                                      strong(" below"), " it (e.g. threshold 100K → zone covers ~50K–99K).", br(),
                                      " The polynomial is fitted excluding this zone on both sides",
                                      " of the threshold, then extrapolated through it.", br(),
                                      strong(" Wider zone = more conservative counterfactual"),
                                      " (more data excluded from the fit, curve must extrapolate further).")
                      ),
                      column(4,
                             sliderInput("spike_sensitivity",
                                         "Highlight red: bins exceeding expected by at least:",
                                         min = 0, max = 200, value = 50, step = 10, post = "%"),
                             helpText(icon("info-circle"),
                                      " Controls only which bins turn red inside the search zone.",
                                      " Set to 0% to highlight every bin that exceeds the model.",
                                      " The total excess mass % in the panel titles never changes with this —",
                                      " it always sums the full search zone.")
                      ),
                      column(4,
                             div(style = "font-size:12px;",
                                 div(style = "background:#eaf4fb; border-left:3px solid #3498db; padding:10px; margin-bottom:8px;",
                                     strong(icon("info-circle"), " How to read this chart"), br(),
                                     "The dotted line shows the", strong(" predicted"),
                                     " contract frequency — estimated from the distribution on both sides of the threshold,",
                                     " excluding the zone immediately around it.",
                                     " It represents the baseline: what the distribution would look like absent any strategic behaviour.", br(), br(),
                                     strong("Excess mass"), " is the percentage gap between observed and predicted contracts just below the threshold.",
                                     " A large positive value indicates an unusual concentration of contracts just under the legal limit."
                                 ),
                                 tags$details(
                                   tags$summary(style = "cursor:pointer; color:#2980b9; font-size:11px;",
                                                icon("cog"), " Technical detail"),
                                   div(style = "background:#f8f9fa; border-left:3px solid #aaa; padding:8px; margin-top:4px;",
                                       "A degree-4 polynomial is fitted by OLS to all bins ",
                                       strong("outside"), " the search zone.",
                                       " The zone is excluded symmetrically on both sides of the threshold",
                                       " so the fit is not distorted by bunching below or a gap above.", br(), br(),
                                       "The fitted curve is extrapolated through the excluded zone.",
                                       " Excess mass = Σ(observed − predicted) / Σpredicted,",
                                       " summed only over bins ", strong("below"), " the threshold.", br(), br(),
                                       "Wider search zone → more bins excluded → longer extrapolation → dotted line changes shape."
                                   )
                                 )
                             )
                      )
                    ),
                    uiOutput("bunching_analysis_plot_ui"),
                    div(style = "margin-top:8px;",
                        downloadButton("dl_bunching", "Download Chart",
                                       class = "btn-sm btn-default", icon = icon("download")))
                )
              )
      ),
      
      
      # [APP-UI12] TAB UI: Submission Periods (admin) ────────────────────────
      # ==================================================================
      # ADMIN — SUBMISSION PERIODS
      # ==================================================================
      tabItem(tabName = "submission",
              h2("Submission Period Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("admin", "subm"))),
              
              # ── 1. Overall distribution (no procedure filter) ─────────────────
              div(class = "question-header", "How are submission periods distributed overall?"),
              fluidRow(
                box(title = "Overall Submission Period Distribution", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box", p("Distribution of submission periods (days from publication of call for tender to bid deadline) across all procedure types. Vertical lines mark Q1 (25th), median, Q3 (75th) percentiles and the mean.")),
                    plotlyOutput("submission_dist_plot", height = "400px"),
                    downloadButton("dl_subm_dist", "Download Figure", class = "download-btn btn-sm"))
              ),
              
              # ── 2. Procedure selector + distribution by procedure ─────────────
              div(class = "question-header", "How do submission periods vary by procedure type?"),
              fluidRow(
                box(title = "Procedure Type Selection", width = 12, solidHeader = TRUE, status = "info",
                    p(style = "color:#555; margin-bottom:8px;",
                      "Select which procedure types to display in the distribution and compliance charts below."),
                    checkboxGroupInput("subm_proc_filter", label = NULL,
                                       choices  = PROC_TYPE_LABELS,
                                       selected = "Open Procedure",
                                       inline   = TRUE),
                    fluidRow(column(6,
                                    actionButton("subm_proc_select_all",   "Select All",   class = "btn-xs btn-default"),
                                    actionButton("subm_proc_deselect_all", "Deselect All", class = "btn-xs btn-default")
                    ))
                )
              ),
              fluidRow(
                box(title = "Submission Periods by Procedure Type", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Faceted histograms with ", strong("5-day bins"), " per procedure type.",
                          " Each panel shows the full distribution of submission periods for that procedure.",
                          " Reference lines: ", strong("solid"), " = median; ",
                          strong("dashed"), " = Q1 and Q3 (25th and 75th percentile); ",
                          strong("dotted"), " = mean.",
                          " Only the procedure types selected in the filter above are shown.",
                          " Y-axes are free across panels — focus on distribution shape and the position of the median, not bar heights across panels.")),
                    plotlyOutput("submission_proc_plot", height = "420px"),
                    downloadButton("dl_subm_proc", "Download Figure", class = "download-btn btn-sm"))
              ),
              
              # ── 3. Threshold configuration (inline, collapsible) ──────────────
              div(class = "question-header", "Configure short-deadline thresholds"),
              fluidRow(
                box(title = "Submission Short-Deadline Thresholds", width = 12,
                    solidHeader = TRUE, status = "warning", collapsible = TRUE, collapsed = FALSE,
                    p(style = "color:#555; margin-bottom:8px;",
                      "Set the legal minimum days for bid submission by procedure type.",
                      " Values below this threshold are flagged as 'short'.",
                      " Tick 'No legal threshold' to derive the cutoff statistically.",
                      " You can also enable an optional ", strong("medium band"),
                      " to flag contracts between two day-counts as 'medium'."),
                    TUKEY_EXPLANATION,
                    fluidRow(
                      column(3, div(class="proc-section", proc_threshold_ui("open",        "Open Procedure",                  30, show_medium=TRUE, med_min=30, med_max=60))),
                      column(3, div(class="proc-section", proc_threshold_ui("restricted",  "Restricted Procedure",            30, show_medium=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("neg_pub",     "Negotiated with publications",    30, show_medium=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("neg_nopub",   "Negotiated without publications", NA, show_medium=TRUE)))
                    ),
                    fluidRow(
                      column(3, div(class="proc-section", proc_threshold_ui("neg_unspec",  "Negotiated (unspecified)",        NA, show_medium=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("competitive", "Competitive Dialogue",            NA, show_medium=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("innov",       "Innovation Partnership",          NA, show_medium=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("direct",      "Direct Award",                   NA, show_medium=TRUE)))
                    ),
                    fluidRow(
                      column(3, div(class="proc-section", proc_threshold_ui("other", "Other", NA, show_medium=TRUE)))
                    ),
                    # National/unrecognised proc types detected in the data — shown dynamically
                    uiOutput("national_subm_thresholds_ui"),
                    br(),
                    fluidRow(column(12,
                                    actionButton("apply_thresholds_subm", "Apply Submission Thresholds",
                                                 icon = icon("check"), class = "btn-success"),
                                    span(style = "margin-left:12px; color:#27ae60; font-weight:bold;",
                                         textOutput("threshold_status_subm", inline = TRUE))
                    ))
                )
              ),
              
              # ── 4. Threshold compliance summary ───────────────────────────────
              div(class = "question-header", "What share of contracts have too-short submission periods?"),
              fluidRow(
                box(title = "Short vs Normal Submission Periods — Flagged Shares", width = 12,
                    solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p(strong("Top bar chart:"), " Each bar shows the share of contracts classified as",
                          strong(" Short"), " (red), ",
                          strong("Medium"), " (amber, if a medium band is configured), or ",
                          strong("Normal"), " (blue) within each procedure type,",
                          " sorted by the short share descending.",
                          " Procedure types with no configured threshold are excluded.",
                          br(), br(),
                          strong("Bottom histogram (1-day bins, zoomed to 0–60 days):"),
                          " Per-procedure distribution of submission periods in the short range.",
                          " Bars are colour-coded by status (Short / Medium / Normal).",
                          " The ", strong("dashed red line"), " marks the short-deadline threshold for that procedure.",
                          " The label in each panel title shows the threshold used and the overall short share.",
                          " Threshold values and the optional medium band are set in the panel above.")),
                    plotlyOutput("subm_share_chart",  height = "280px"),
                    downloadButton("dl_subm_share", "Download Share Chart", class = "download-btn btn-sm"),
                    hr(),
                    plotlyOutput("submission_short_plot", height = "500px"),
                    downloadButton("dl_subm_short", "Download Distribution Figure", class = "download-btn btn-sm"))
              ),
              
              # ── 5. Buyer types breakdown ──────────────────────────────────────
              div(class = "question-header", "Which buyer types set the shortest submission periods?"),
              fluidRow(
                box(title = "Short Submission Periods by Buyer Group", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Share of contracts with a ", strong("short submission period"), " by buyer group,",
                          " with one facet panel per procedure type.",
                          " Bars are stacked: ", strong("red"), " = short deadline, ",
                          strong("blue"), " = normal deadline.",
                          " Each bar sums to 100%.",
                          " Toggle between contract count share (default), contract value share, or both panels stacked.",
                          " Buyer groups with fewer than 5 contracts in a procedure type are excluded.",
                          " Use this chart to identify which buyer categories most frequently set very short bid windows.")),
                    fluidRow(
                      column(4,
                             radioButtons("subm_buyer_view", label = "Show metric:",
                                          choices  = c("By contract count" = "count",
                                                       "By contract value" = "value",
                                                       "Both"              = "both"),
                                          selected = "count", inline = TRUE)
                      )
                    ),
                    plotlyOutput("buyer_short_plot", height = "480px"),
                    downloadButton("dl_buyer_short", "Download Figure", class = "download-btn btn-sm"))
              )
      ),
      
      
      # [APP-UI13] TAB UI: Decision Periods (admin) ──────────────────────────
      # ==================================================================
      # ADMIN — DECISION PERIODS
      # ==================================================================
      tabItem(tabName = "decision",
              h2("Decision Period Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("admin", "dec"))),
              
              # ── 1. Overall distribution ───────────────────────────────────────
              div(class = "question-header", "How are decision periods distributed overall?"),
              fluidRow(
                box(title = "Overall Decision Period Distribution", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box", p("Distribution of decision periods (days from bid deadline to contract award or signature) across all procedure types. Vertical lines mark Q1 (25th), median, Q3 (75th) percentiles and the mean.")),
                    plotlyOutput("decision_dist_plot", height = "400px"),
                    downloadButton("dl_dec_dist", "Download Figure", class = "download-btn btn-sm"))
              ),
              
              # ── 2. Procedure selector + distribution by procedure ─────────────
              div(class = "question-header", "How do decision periods vary by procedure type?"),
              fluidRow(
                box(title = "Procedure Type Selection", width = 12, solidHeader = TRUE, status = "info",
                    p(style = "color:#555; margin-bottom:8px;",
                      "Select which procedure types to display in the distribution and compliance charts below."),
                    checkboxGroupInput("dec_proc_filter", label = NULL,
                                       choices  = PROC_TYPE_LABELS,
                                       selected = "Open Procedure",
                                       inline   = TRUE),
                    fluidRow(column(6,
                                    actionButton("dec_proc_select_all",   "Select All",   class = "btn-xs btn-default"),
                                    actionButton("dec_proc_deselect_all", "Deselect All", class = "btn-xs btn-default")
                    ))
                )
              ),
              fluidRow(
                box(title = "Decision Periods by Procedure Type", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Faceted histograms with ", strong("10-day bins"), " per procedure type.",
                          " Each panel shows the full distribution of decision periods — from bid deadline to contract award or signature.",
                          " Reference lines: ", strong("solid"), " = median; ",
                          strong("dashed"), " = Q1 and Q3 (25th and 75th percentile); ",
                          strong("dotted"), " = mean.",
                          " X-axis is capped at 730 days (2 years). Only the procedure types selected above are shown.",
                          " Y-axes are free across panels.")),
                    plotlyOutput("decision_proc_plot", height = "420px"),
                    downloadButton("dl_dec_proc", "Download Figure", class = "download-btn btn-sm"))
              ),
              
              # ── 3. Threshold configuration (inline, collapsible) ──────────────
              div(class = "question-header", "Configure long-decision thresholds"),
              fluidRow(
                box(title = "Decision Long-Period Thresholds", width = 12,
                    solidHeader = TRUE, status = "warning", collapsible = TRUE, collapsed = FALSE,
                    p(style = "color:#555; margin-bottom:8px;",
                      "Maximum acceptable days between bid deadline and contract award per procedure type.",
                      " Decisions above this threshold are flagged as 'long'."),
                    p(style = "color:#555; font-size:12px; margin-bottom:4px;",
                      strong("Too-long threshold:"), " contracts above this are flagged red. ",
                      strong("Too-short threshold:"), " (optional) contracts below this are flagged. ",
                      strong("Medium band:"), " (optional) amber zone between too-short and too-long."),
                    fluidRow(
                      column(3, div(class="proc-section", proc_threshold_ui("dec_open",        "Open Procedure",                  60, is_decision=TRUE, show_medium=TRUE, show_short=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("dec_restricted",  "Restricted Procedure",            60, is_decision=TRUE, show_medium=TRUE, show_short=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("dec_neg_pub",     "Negotiated with publications",    60, is_decision=TRUE, show_medium=TRUE, show_short=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("dec_neg_nopub",   "Negotiated without publications", NA, is_decision=TRUE, show_medium=TRUE, show_short=TRUE)))
                    ),
                    fluidRow(
                      column(3, div(class="proc-section", proc_threshold_ui("dec_neg_unspec",  "Negotiated (unspecified)",        NA, is_decision=TRUE, show_medium=TRUE, show_short=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("dec_competitive", "Competitive Dialogue",            NA, is_decision=TRUE, show_medium=TRUE, show_short=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("dec_innov",       "Innovation Partnership",          NA, is_decision=TRUE, show_medium=TRUE, show_short=TRUE))),
                      column(3, div(class="proc-section", proc_threshold_ui("dec_direct",      "Direct Award",                   NA, is_decision=TRUE, show_medium=TRUE, show_short=TRUE)))
                    ),
                    fluidRow(
                      column(3, div(class="proc-section", proc_threshold_ui("dec_other", "Other", NA, is_decision=TRUE, show_medium=TRUE, show_short=TRUE)))
                    ),
                    # National/unrecognised proc types detected in the data — shown dynamically
                    uiOutput("national_dec_thresholds_ui"),
                    br(),
                    fluidRow(column(12,
                                    actionButton("apply_thresholds_dec", "Apply Decision Thresholds",
                                                 icon = icon("check"), class = "btn-success"),
                                    span(style = "margin-left:12px; color:#27ae60; font-weight:bold;",
                                         textOutput("threshold_status_dec", inline = TRUE))
                    ))
                )
              ),
              
              # ── 4. Threshold compliance summary ───────────────────────────────
              div(class = "question-header", "What share of contracts have too-long decision periods?"),
              fluidRow(
                box(title = "Long vs Normal Decision Periods — Flagged Shares", width = 12,
                    solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p(strong("Top bar chart:"), " Each bar shows the share of contracts classified as",
                          strong(" Long"), " (red) or ",
                          strong("Normal"), " (blue) within each procedure type,",
                          " sorted by the long share descending.",
                          " Procedure types with no configured threshold are excluded.",
                          br(), br(),
                          strong("Bottom histogram (4-day bins, zoomed to 0–300 days):"),
                          " Per-procedure distribution of decision periods in the range around the threshold.",
                          " Bars are colour-coded Long (red) or Normal (blue).",
                          " The ", strong("dashed red line"), " marks the long-decision threshold for that procedure.",
                          " The label in each panel title shows the threshold and the overall long share.",
                          " Threshold values are configured in the panel above.")),
                    plotlyOutput("dec_share_chart",    height = "280px"),
                    downloadButton("dl_dec_share", "Download Share Chart", class = "download-btn btn-sm"),
                    hr(),
                    plotlyOutput("decision_long_plot", height = "500px"),
                    downloadButton("dl_dec_long", "Download Distribution Figure", class = "download-btn btn-sm"))
              ),
              
              # ── 5. Buyer types breakdown ──────────────────────────────────────
              div(class = "question-header", "Which buyer types have the longest decision periods?"),
              fluidRow(
                box(title = "Long Decision Periods by Buyer Group", width = 12,
                    solidHeader = TRUE, status = "primary",
                    div(class = "description-box",
                        p("Share of contracts with a ", strong("long decision period"), " by buyer group,",
                          " with one facet panel per procedure type.",
                          " Bars are stacked: ", strong("red"), " = long decision, ",
                          strong("blue"), " = normal.",
                          " Each bar sums to 100%.",
                          " Toggle between contract count share (default), contract value share, or both panels stacked.",
                          " Use this chart to identify which buyer categories are slowest to award contracts after the bid deadline.")),
                    fluidRow(
                      column(4,
                             radioButtons("dec_buyer_view", label = "Show metric:",
                                          choices  = c("By contract count" = "count",
                                                       "By contract value" = "value",
                                                       "Both"              = "both"),
                                          selected = "count", inline = TRUE)
                      )
                    ),
                    plotlyOutput("buyer_long_plot", height = "480px"),
                    downloadButton("dl_buyer_long", "Download Figure", class = "download-btn btn-sm"))
              )
      ),
      
      
      # [APP-UI14] TAB UI: Regression Analysis (admin) ───────────────────────
      # ==================================================================
      # ADMIN — REGRESSION
      # ==================================================================
      tabItem(tabName = "regression",
              h2("Regression Analysis: Administrative Efficiency & Competition"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("admin", "reg"))),
              div(class = "question-header",
                  icon("chart-line", style = "margin-right:8px;color:var(--amber);"),
                  "Are short submission and long decision periods linked to reduced competition?"),
              div(class = "description-box",
                  p(icon("info-circle"), tags$strong(" About these regressions: "),
                    "Fractional logit models with year fixed effects test whether short submission periods and long decision periods are associated with higher single-bidding rates. ",
                    "Each model is tested across ", tags$strong("~40 specifications"),
                    " (varying fixed effects, clustering, and controls) to assess robustness.")),
              fluidRow(
                box(width = 12, status = "warning",
                    div(class = "reg-run-box",
                        div(class = "reg-status",  uiOutput("regression_status_box")),
                        div(class = "reg-btn-wrap",
                            actionButton("run_regressions_now",
                                         label = tagList(icon("play-circle"), " Run / Re-run Regressions"),
                                         class = "btn-warning reg-run-btn")))
                )
              ),
              fluidRow(box(title = "Effect of Short Submission Periods on Single Bidding", width = 12,
                           solidHeader = TRUE, status = "info",
                           uiOutput("short_reg_plot_ui"), uiOutput("dl_short_reg_ui"),
                           uiOutput("short_reg_formula_ui"))),
              fluidRow(box(title = "Robustness Checks: Short Submission Period Model", width = 12,
                           solidHeader = TRUE, status = "info", collapsible = TRUE, collapsed = TRUE,
                           uiOutput("sensitivity_short_ui"))),
              fluidRow(box(title = "Effect of Long Decision Periods on Single Bidding", width = 12,
                           solidHeader = TRUE, status = "info",
                           uiOutput("long_reg_plot_ui"), uiOutput("dl_long_reg_ui"),
                           uiOutput("long_reg_formula_ui"))),
              fluidRow(box(title = "Robustness Checks: Long Decision Period Model", width = 12,
                           solidHeader = TRUE, status = "info", collapsible = TRUE, collapsed = TRUE,
                           uiOutput("sensitivity_long_ui")))
      ),
      
      
      # [APP-UI15] TAB UI: Missing Values (integrity) ────────────────────────
      # ==================================================================
      # EXPORT
      # ==================================================================
      # ==================================================================
      # INTEGRITY — OVERVIEW
      # ==================================================================
      # ==================================================================
      # INTEGRITY — MISSING VALUES
      # ==================================================================
      tabItem(tabName = "integrity_missing",
              h2("Missing Values Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("integ", "missing"))),
              div(class = "question-header", "Are there observable patterns of underreporting information in the data?"),
              div(class = "description-box",
                  p("Assessment of data completeness by examining missing values across all variables. ",
                    "Each variable contributes to one of the ProAct indicators.")),
              fluidRow(
                box(title = "Advanced Missingness Tests", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        tags$b("Little's MCAR test"), " checks whether values are Missing Completely At Random. ",
                        tags$b("MAR predictability"), " fits a logistic regression per variable to see if missingness is ",
                        "predictable from year, buyer type, procedure, and contract value. ",
                        tags$b("Co-occurrence"), " shows which variable pairs tend to go missing on the same row."),
                    actionButton("integ_run_missing_advanced", "Run Advanced Missingness Tests",
                                 icon = icon("flask"), class = "btn-warning"),
                    br(), br(),
                    uiOutput("integ_mcar_summary_card"))
              ),
              fluidRow(
                box(title = "Overall Missing Values by Variable", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        "Share of missing values for each key variable, sorted by severity. ",
                        "Colour zones: ", tags$b("green < 5%"), " (low), ",
                        tags$b("amber 5-20%"), " (notable), ", tags$b("red >= 20%"), " (high-risk)."),
                    plotlyOutput("integ_missing_overall_plot", height = "auto"),
                    uiOutput("integ_missing_overall_height_spacer"),
                    downloadButton("integ_dl_missing_overall", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Missingness by Buyer Type", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("Heatmap showing the ", strong("share of missing values"), " for each key variable, broken down by buyer type.",
                          " Each cell shows the proportion of records from that buyer type where the variable is absent.",
                          " Colour scale: ", strong("white = 0% missing"), " through ",
                          strong("dark red = 100% missing"), ".",
                          " A column that is uniformly dark across buyer types indicates a structural data gap in that field.",
                          " A column that is dark only for certain buyer types suggests selective non-reporting,",
                          " which may reflect differences in reporting obligations or data entry practices.",
                          " Hover over any cell for the exact missing share.",
                          " Use the slider above to adjust the number of buyer types shown.")),
                    uiOutput("integ_missing_buyer_slider_ui"),
                    plotlyOutput("integ_missing_buyer_plot", height = "auto"),
                    uiOutput("integ_missing_buyer_plot_height"),
                    downloadButton("integ_dl_missing_buyer", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Missingness by Procedure Type", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("Same heatmap structure as the buyer-type breakdown above,",
                          " but grouped by ", strong("procurement procedure type"), ".",
                          " Dark cells for a specific procedure type (e.g. Negotiated without publications)",
                          " suggest that contracts using that procedure are systematically less well-documented.",
                          " This can make those procedures harder to audit and may mask irregularities.",
                          " Hover over any cell for the exact missing share.")),
                    uiOutput("integ_missing_procedure_slider_ui"),
                    plotlyOutput("integ_missing_procedure_plot", height = "auto"),
                    uiOutput("integ_missing_procedure_plot_height"),
                    downloadButton("integ_dl_missing_procedure", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Trends in Missing Shares Over Time", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("Heatmap of missing share per variable, with years on the x-axis.",
                          " Each cell is the proportion of records in that year where the variable is absent.",
                          " Colour scale: white = 0% missing, dark red = 100% missing.",
                          " A ", strong("vertical band of red"), " covering a single year across many variables",
                          " signals a data collection failure or a change in reporting rules in that year.",
                          " A ", strong("horizontal band"), " affecting one variable across many years",
                          " indicates a persistently missing field.",
                          " Use this chart to decide which years to exclude from analysis and to flag",
                          " structural data quality issues to the data provider.")),
                    uiOutput("integ_missing_time_slider_ui"),
                    plotlyOutput("integ_missing_time_plot", height = "auto"),
                    uiOutput("integ_missing_time_height_spacer"),
                    downloadButton("integ_dl_missing_time", "Download Figure", class = "download-btn btn-sm"))
              ),
              fluidRow(
                box(title = "Variable Pairs Missing Together", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("The ", strong("Jaccard co-occurrence index"), " measures how often two variables",
                          " are both missing on the same contract record.",
                          " A value of 1.0 means the two variables ", em("always"), " go missing together;",
                          " 0.0 means they never do.",
                          " Cell pairs coloured ", strong("red"), " share a single root cause —",
                          " for example, both may be populated only when a specific document type is filed.",
                          " If you find a tight cluster of co-missing variables, investigate whether",
                          " those fields come from the same reporting form or system.",
                          " Run the Advanced Missingness Tests above for the statistical MCAR test.")),
                    uiOutput("integ_missing_cooccurrence_ui"),
                    uiOutput("integ_missing_cooccurrence_download_ui"))
              ),
              fluidRow(
                box(title = "Is Missing Data Random? Pattern Analysis per Variable", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        tags$p("For each variable, we test: can we predict which records will have this field missing?"),
                        tags$p(tags$b("Pattern score near 0%"), " means missing data appears random. ",
                               tags$b("Score above 10%"), " means certain contracts systematically skip this field.")),
                    uiOutput("integ_missing_mar_ui"),
                    uiOutput("integ_missing_mar_download_ui"))
              )
      ),
      
      
      # [APP-UI16] TAB UI: Interoperability (integrity) ──────────────────────
      # ==================================================================
      # INTEGRITY — INTEROPERABILITY
      # ==================================================================
      tabItem(tabName = "integrity_interop",
              h2("Interoperability Analysis"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("integ", "interop"))),
              div(class = "question-header",
                  "Can this data be matched to other registers in the country to ensure higher quality monitoring?"),
              div(class = "description-box",
                  p("The ability to match public procurement data with other registers significantly enhances analytical power and auditing capabilities.")),
              fluidRow(
                box(title = "Interoperability Potential at Organization Level",
                    width = 12, solidHeader = TRUE, status = "info",
                    DT::dataTableOutput("integ_interoperability_table"))
              )
      ),
      
      
      # [APP-UI17] TAB UI: Risky Profiles (integrity — flow matrix + network graph) ────
      # ==================================================================
      # INTEGRITY — RISKY PROFILES
      # ==================================================================
      tabItem(tabName = "integrity_risky",
              h2("Companies with Risky Profiles"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("integ", "risky"))),
              div(class = "question-header", "Do companies winning contracts have risky profiles?"),
              div(class = "description-box",
                  p("This analysis seeks to identify potentially suspicious patterns in company behavior, including movements between markets.")),
              fluidRow(
                box(title = "Unusual Market Entry Analysis", width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        h4(icon("info-circle"), " Methodology", style = "margin-top:0; color:#c0392b;"),
                        p(tags$b("What is being detected:"), " Suppliers who systematically win contracts in markets unrelated to their core specialisation."),
                        p(tags$b("Supplier home market:"), " Each supplier's 'home' CPV cluster is the 3-digit product code group where they have the most contract wins."),
                        p(tags$b("Atypicality flag:"), " A supplier-cluster combination is flagged as atypical if the supplier has >= 4 total wins, <= 3 wins in this market, and this market < 5% of their total portfolio."),
                        p(tags$b("Surprise score:"), " Computed as -log[(n_ic+1)/(n_c+n_suppliers_c)], z-scored within each cluster.")
                    ),
                    uiOutput("integ_network_status_ui"),
                    actionButton("integ_run_network_analysis", "Run Network Analysis",
                                 icon = icon("project-diagram"), class = "btn-warning btn-lg run-btn"),
                    br(), br(),
                    conditionalPanel(
                      condition = "output.integ_network_done_flag",
                      fluidRow(
                        column(4, uiOutput("integ_net_min_bidders_ui")),
                        column(4, uiOutput("integ_net_top_clusters_ui")),
                        column(4, uiOutput("integ_net_cluster_filter_ui"))
                      )
                    ),
                    tabsetPanel(id = "integ_network_tabs", type = "tabs",
                                tabPanel("Flow Matrix",
                                         br(),
                                         div(class = "description-box",
                                             tags$b(icon("map"), " How to read:"),
                                             tags$ul(
                                               tags$li("Row = home market, Column = target market where suppliers entered unusually"),
                                               tags$li("Number = how many suppliers crossed that route"),
                                               tags$li("Darker blue = more suppliers — higher concern")
                                             )),
                                         uiOutput("integ_flow_matrix_plot_ui"),
                                         uiOutput("integ_download_network_ui")
                                ),
                                tabPanel("Network Graph",
                                         br(),
                                         div(class = "description-box",
                                             tags$b(icon("project-diagram"), " How to read:"),
                                             tags$ul(
                                               tags$li("Node = CPV market cluster. Arrow A->B = suppliers normally in A winning unusually in B."),
                                               tags$li("Arrow thickness = supplier count. Colour: grey = average, orange = moderate, red = high surprise.")
                                             )),
                                         uiOutput("integ_network_plot_ui"),
                                         uiOutput("integ_download_network_graph_ui")
                                )
                    )
                )
              ),
              fluidRow(
                box(title = "Suppliers with Unusually Diversified Market Entries",
                    width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("Suppliers ranked by their ", strong("mean surprise score"), " across all out-of-portfolio wins.",
                          " The surprise score for a supplier-market combination is high when that supplier wins contracts",
                          " in a market where very few other suppliers in the same home cluster have won,",
                          " relative to how often suppliers typically enter that market.",
                          " A high score does not automatically indicate wrongdoing — some suppliers are legitimately diversified.",
                          " The score is most meaningful when combined with a ", strong("high number of atypical wins"),
                          " (shown on the x-axis): a supplier with one unusual win is less concerning than one",
                          " with many unusual wins across multiple unrelated markets.",
                          " Hover over each bar for the supplier ID, home cluster, and score details.")),
                    uiOutput("integ_supplier_unusual_plot_ui"),
                    uiOutput("integ_download_supplier_unusual_ui"))
              ),
              fluidRow(
                box(title = "Markets Attracting Unusual Supplier Entries",
                    width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("Each bubble is a CPV market, positioned and sized by its ", strong("unusual-entry risk index."),
                          " The index combines two factors: the ", strong("mean surprise score"),
                          " of all unusual entrants into that market (intensity),",
                          " and the ", strong("count of distinct unusual entrants"), " (breadth).",
                          " Markets that score high on both dimensions are the most concerning —",
                          " they are attracting many suppliers from unrelated backgrounds, each with a high degree of unexpectedness.",
                          " Hover over any bubble for the market name, entrant count, and index value.",
                          " Use this chart to prioritise which markets to investigate in depth.")),
                    uiOutput("integ_market_unusual_plot_ui"),
                    uiOutput("integ_download_market_unusual_ui"))
              ),
              div(class = "question-header", "Are there suspicious connections between buyers and suppliers?"),
              fluidRow(
                box(title = "Top Buyers by Supplier Concentration Over Time",
                    width = 12, solidHeader = TRUE, status = "warning",
                    div(class = "description-box",
                        p("Each bar shows the ", strong("maximum single-supplier spending concentration"),
                          " for a buyer in a given year.",
                          " Concentration is defined as the share of that buyer's total spend in the year",
                          " that went to a single supplier (the largest recipient).",
                          " A value of 100% means one supplier received all contracts from that buyer that year.",
                          " Only buyers with at least ",
                          strong("3"), " distinct suppliers in a year are included (configurable with the slider below).",
                          " ", strong("Red bars"), " flag buyers who appear in the top list across", strong(" multiple years"),
                          " — persistent high concentration is a stronger risk signal than a single-year spike.",
                          " Use the sliders to adjust how many buyers to show and the minimum contract count.",
                          " Hover for exact values and the list of years in which the buyer appears.")),
                    fluidRow(
                      column(6, uiOutput("integ_conc_n_buyers_slider_ui")),
                      column(6, uiOutput("integ_conc_min_contracts_slider_ui"))
                    ),
                    uiOutput("integ_concentration_plot_ui"),
                    downloadButton("integ_dl_concentration", "Download Figure", class = "download-btn btn-sm"))
              )
      ),
      
      
      # [APP-UI18] TAB UI: Regression / Prices (integrity) ───────────────────
      # ==================================================================
      # INTEGRITY — PRICES & COMPETITION
      # ==================================================================
      tabItem(tabName = "integrity_prices",
              h2("Regression Analysis: Prices & Competition"),
              fluidRow(box(title = "Filters", width = 12, collapsible = TRUE, status = "info",
                           filter_bar_ui("integ", "prices"))),
              div(class = "question-header",
                  icon("chart-line", style = "margin-right:8px;color:var(--rose);"),
                  "Does data incompleteness correlate with reduced competition and higher prices?"),
              div(class = "description-box",
                  p(icon("info-circle"), tags$strong(" About these regressions: "),
                    "Fractional logit and OLS models explore correlations between data missingness, single-bidding rates, and relative prices. ",
                    "These are observational models — they do not establish causality.")),
              fluidRow(
                box(width = 12, status = "warning",
                    div(class = "reg-run-box",
                        div(class = "reg-status",  uiOutput("integ_regression_status_box")),
                        div(class = "reg-btn-wrap",
                            actionButton("integ_run_regressions_now",
                                         label = tagList(icon("play-circle"), " Run / Re-run Regressions"),
                                         class = "btn-warning reg-run-btn")))
                )
              ),
              fluidRow(
                box(title = "Predicted Single-Bidding by Missing Share", width = 12, solidHeader = TRUE, status = "info",
                    div(class = "description-box",
                        p("The ", strong("x-axis"), " is the buyer-year level share of missing values across key procurement fields.",
                          " The ", strong("y-axis"), " is the predicted share of single-bid tenders for that buyer in that year.",
                          " The ", strong("fitted line"), " comes from the best-performing model specification",
                          " (selected from multiple model types, fixed effects, and controls — see model details below).",
                          " If the line slopes upward, buyers who report less information also tend to run",
                          " less competitive tenders — suggesting that data opacity and low competition go together.",
                          " The shaded band is the ", strong("95% confidence interval"), " around the prediction.",
                          " Note: this is a correlation, not a causal estimate.")),
                    uiOutput("integ_singleb_plot_ui"),
                    uiOutput("integ_download_singleb_ui"),
                    uiOutput("integ_singleb_formula_ui"))
              ),
              fluidRow(
                box(title = "Robustness Checks: Single-Bidding Model", width = 12, solidHeader = TRUE, status = "info",
                    collapsible = TRUE, collapsed = TRUE,
                    uiOutput("integ_singleb_sensitivity_table"))
              ),
              fluidRow(
                box(title = "Predicted Relative Price by Missing Share", width = 12, solidHeader = TRUE, status = "info",
                    div(class = "description-box",
                        p("The ", strong("x-axis"), " is the buyer-year level share of missing values across key procurement fields.",
                          " The ", strong("y-axis"), " is the predicted relative price (contract price ÷ estimated price)",
                          " for contracts awarded by that buyer in that year.",
                          " The ", strong("fitted line"), " comes from a linear fixed-effects model (OLS)",
                          " that controls for buyer and year effects.",
                          " A value above 1.0 on the y-axis means contracts exceed their estimated prices on average.",
                          " If the line slopes upward, buyers with more missing data also tend to pay more",
                          " relative to their own estimates — consistent with weaker procurement discipline.",
                          " The grey band is the ", strong("95% confidence interval"), ".",
                          " Note: this is a correlational estimate. Causality cannot be established from this model alone.")),
                    uiOutput("integ_relprice_plot_ui"),
                    uiOutput("integ_download_relprice_ui"),
                    uiOutput("integ_relprice_formula_ui"))
              ),
              fluidRow(
                box(title = "Robustness Checks: Relative Price Model", width = 12, solidHeader = TRUE, status = "info",
                    collapsible = TRUE, collapsed = TRUE,
                    uiOutput("integ_relprice_sensitivity_table"))
              )
      ),
      
      
      # [APP-UI19] TAB UI: Export & Download ─────────────────────────────────
      # ==================================================================
      # EXPORT (existing)
      # ==================================================================
      tabItem(tabName = "export",
              h2("Export & Download"),
              tags$p(style = "color:var(--slate-600);font-size:13.5px;margin:-8px 0 20px;",
                     "Download analysis reports (Word) or individual figures (ZIP) for any module. ",
                     "Reports include all charts, tables, and narrative generated from your current filters."),
              fluidRow(
                column(4,
                       div(class = "export-card export-card-econ",
                           div(class = "export-card-title",
                               icon("chart-line", style = "color:var(--teal);"),
                               "Economic Outcomes"),
                           div(class = "export-card-desc",
                               "Market sizing, relative prices, single-bidding rates and supplier dynamics."),
                           div(class = "export-card-btns",
                               downloadButton("dl_econ_word", tagList(icon("file-word"), " Word Report"),
                                              class = "btn btn-info"),
                               downloadButton("dl_econ_zip",  tagList(icon("file-archive"), " All Figures (ZIP)"),
                                              class = "btn btn-success")
                           )
                       )
                ),
                column(4,
                       div(class = "export-card export-card-admin",
                           div(class = "export-card-title",
                               icon("clock", style = "color:var(--amber);"),
                               "Administrative Efficiency"),
                           div(class = "export-card-desc",
                               "Procedure types, submission and decision periods, bunching analysis and regressions."),
                           div(class = "export-card-btns",
                               downloadButton("dl_admin_word", tagList(icon("file-word"), " Word Report"),
                                              class = "btn btn-info"),
                               downloadButton("dl_admin_zip",  tagList(icon("file-archive"), " All Figures (ZIP)"),
                                              class = "btn btn-success")
                           )
                       )
                ),
                column(4,
                       div(class = "export-card export-card-integ",
                           div(class = "export-card-title",
                               icon("shield-alt", style = "color:var(--rose);"),
                               "Procurement Integrity"),
                           div(class = "export-card-desc",
                               "Missing values, interoperability, market concentration, network analysis and regressions."),
                           div(class = "export-card-btns",
                               downloadButton("integ_dl_word_report", tagList(icon("file-word"), " Word Report"),
                                              class = "btn btn-info"),
                               downloadButton("integ_dl_all_figures", tagList(icon("file-archive"), " All Figures (ZIP)"),
                                              class = "btn btn-success")
                           )
                       )
                )
              ),
              br(),
              div(class = "export-status-bar",
                  icon("info-circle", style = "color:var(--slate-400);margin-right:6px;"),
                  textOutput("export_status", inline = TRUE))
      )
    )
  )
)

ui