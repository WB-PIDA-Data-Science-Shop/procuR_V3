---
title: Home
nav_order: 1
---

# Procurement Analytics Dashboard

An open R Shiny toolkit that turns raw public-procurement award data
(OpenTender-style CSV) into an interactive red-flag analysis across three
lenses:

* **Economic Outcomes** — market sizing, supplier dynamics and entry,
  relative prices against estimates, competition and single bidding.
* **Administrative Efficiency** — procedure mix, value bunching below
  thresholds, submission and decision periods, and regression evidence
  linking administrative shortcuts to reduced competition.
* **Integrity** — missing-data forensics (including Little's MCAR test and
  MAR predictability), buyer–supplier concentration over time, unusual
  market-entry networks, and robustness-checked integrity regressions.

Every figure is exportable individually, as a figures ZIP, or inside an
auto-generated Word report per section.

## Try it

[🚀 Open the live app](https://datanalytics-int.worldbank.org/procur_v3/){: .btn .btn-primary .fs-5 .mb-4 }

* **Live app:** <https://datanalytics-int.worldbank.org/procur_v3/> — click
  **Run Demo** on the Setup page for an instant, fully configured tour.
* **Run locally:** clone the repository, open R in the folder, and run
  `shiny::runApp()`. Click **"Run Demo"** on the
  Setup tab — a fully synthetic 15,674-award dataset loads with every
  threshold pre-configured.

## Documentation

| Page | For |
|---|---|
| [Demo dataset guide](demo-guide.html) | What the bundled synthetic data contains and what each tab should find |
| [Methodology](methodology.html) | Exact formulas and code anchors for every chart and regression |
| [Policy note](policy-note.html) | Non-technical explanation of the indicators |
| [Developer guide](developer-guide.html) | Architecture, reactive graph, extension points |
| [Function reference](function-reference.html) | Every function, by file and anchor |
| [Data dictionary](data-dictionary.html) | Every input column: definition, type, and which analyses use it (Excel download available) |

## Data requirements

The app reads OpenTender-style CSVs (67 columns; see the README's data
requirements section). All analysis is client-configurable: country
thresholds, year windows, and procedure filters.