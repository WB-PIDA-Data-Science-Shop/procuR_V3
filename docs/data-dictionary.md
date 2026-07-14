---
title: Data dictionary
nav_order: 7
---

# Data dictionary

Every column of the OpenTender-style input CSV, what it means, and which
analyses use it. The bundled demo dataset follows this schema exactly; real
country datasets in the same schema are available from
[ProAct](https://www.procurementintegrity.org/data).

[📥 Download as Excel](assets/data_dictionary.xlsx){: .btn .btn-primary .fs-5 .mb-4 }

*Unit of observation:* one awarded contract per row (tender × lot × winning
bid). *Indicator convention:* OpenTender risk indicators are coded
**0 = risk flagged, 100 = no risk**.


## Identifiers & keys

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `tender_id` | Identifier | Unique identifier of the tender (procurement procedure). One tender can contain several lots. | All modules — record keys, contract counting, deduplication |
| `lot_number` | Identifier | Sequential number of the lot within its tender. | All modules — record keys; lot-level analyses |
| `bid_number` | Identifier | Sequential number of the bid within its lot. | Record keys; bid-level structure |
| `bid_iswinning` | Binary (TRUE/FALSE) | Whether this bid won the lot. The dataset contains awarded (winning) bids. | Award filtering across all modules |
| `source` | Text | Provenance of the record (publication source system). | Traceability only — not analysed |
| `notice_url` | Text (URL) | Link to the original tender notice. | Traceability only — not analysed |
| `tender_publications_lastcontractawardurl` | Text (URL) | Link to the contract-award publication. | Traceability only — not analysed |

## Dates & periods

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `tender_publications_firstcallfortenderdate` | Date (YYYY-MM-DD) | Date the first call for tenders was published. Missing for outright/direct awards (no call). | Submission periods (Admin); year assignment; no-call-for-tender indicator (Integrity) |
| `tender_biddeadline` | Date (YYYY-MM-DD) | Deadline for submitting bids. | Submission periods = deadline − first call (Admin); decision periods start point |
| `tender_awarddecisiondate` | Date (YYYY-MM-DD) | Date the award decision was taken. | Decision periods = decision − deadline (Admin: Long Decision Periods, regressions); year fallback |
| `tender_contractsignaturedate` | Date (YYYY-MM-DD) | Date the contract was signed. | Context; data-quality checks |
| `tender_publications_firstdcontractawarddate` | Date (YYYY-MM-DD) | Date of the first contract-award publication. | Context; year fallback |
| `submp` | Numeric (days) | Pre-computed submission period: days between first call and bid deadline. | Admin — submission-period distributions, short-window flags; Econ — single bidding vs short windows |
| `decp` | Numeric (days) | Pre-computed decision period: days between bid deadline and award decision. | Admin — decision-period distributions and long-decision flags |

## Procedure & supply type

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `tender_proceduretype` | Categorical | Standardised procedure type (OPEN, RESTRICTED, NEGOTIATED_WITH_PUBLICATION, NEGOTIATED_WITHOUT_PUBLICATION, COMPETITIVE_DIALOG, INNOVATION_PARTNERSHIP, OUTRIGHT_AWARD, OTHER). | Admin — procedure mix, thresholds per procedure; Econ — competition analyses; Integrity — non-open-procedure indicator, regressions |
| `tender_proceduretype.1` | Categorical (duplicate) | Duplicate export of tender_proceduretype (OpenTender artefact). The app drops duplicated column names on load. | Not used (dropped at load) |
| `tender_nationalproceduretype` | Categorical | Procedure type in the national legal nomenclature. | Context for procedure mix |
| `tender_supplytype` | Categorical | What is procured: SUPPLIES, WORKS or SERVICES. | Admin — value bunching thresholds per supply type, value-distribution panels; market context |

## Buyer (contracting authority)

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `buyer_masterid` | Identifier | Deduplicated (master) identifier of the buyer organisation. | Econ — top buyers; Integrity — buyer–supplier concentration over time, opaque-buyer missingness; Admin — regressions (buyer effects) |
| `buyer_id` | Identifier | Raw source identifier of the buyer. | Secondary key |
| `buyer_name` | Text | Official name of the buyer. | Display; buyer-name-missing indicator (Integrity) |
| `buyer_buyertype` | Categorical | Type of authority (e.g. NATIONAL_AUTHORITY, REGIONAL_AUTHORITY, PUBLIC_BODY, UTILITY). | Admin — regressions; Integrity — MAR missingness predictors; utilities decision-period patterns |
| `buyer_mainactivities` | Categorical | Main activity sector(s) of the buyer. | Context |
| `buyer_city` | Text | City of the buyer. | Location-missingness co-occurrence (Integrity) |
| `buyer_postcode` | Text | Postcode of the buyer. | Location-missingness co-occurrence (Integrity) |
| `buyer_nuts` | Categorical | NUTS region code of the buyer. | Location-missingness; regional context |
| `buyer_country` | Categorical | ISO country code of the buyer. | Country detection & thresholds auto-config |
| `tender_country` | Categorical | ISO country code of the tender. | Country detection (drives threshold pre-fill) |
| `tender_addressofimplementation_country` | Categorical | Country where the contract is implemented. | Implementation-location-missing indicator (Integrity) |
| `tender_addressofimplementation_nuts` | Categorical | NUTS region of implementation. | Implementation-location-missing indicator (Integrity) |

## Supplier (bidder)

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `bidder_masterid` | Identifier | Deduplicated (master) identifier of the supplier. | Econ — supplier trends, market entry/exit; Integrity — concentration, risky-profile analyses |
| `bidder_id` | Identifier | Raw source identifier of the supplier. The clustering key for the unusual-market-entry network. | Integrity — Risky Profiles network & flow matrix (atypical market entries) |
| `bidder_name` | Text | Official name of the supplier. | Display; bidder-name-missing indicator (Integrity) |
| `bidder_country` | Categorical | ISO country code of the supplier. | Non-local-bidder indicator; cross-border context |
| `bidder_nuts` | Categorical | NUTS region code of the supplier. | Regional context |

## Values & prices

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `bid_price` | Numeric (national currency) | Winning bid / contract value in national currency (DLK in the demo). | Econ — market sizing, top buyers/suppliers by value; Admin — value bunching below thresholds (uses national currency); relative prices numerator |
| `bid_priceusd` | Numeric (USD) | Contract value converted to US dollars. | Cross-country-comparable values; Risky Profiles value flows |
| `bid_pricecurrency` | Categorical | Currency of bid_price. | Currency detection & labels |
| `lot_estimatedprice` | Numeric (national currency) | Buyer's estimated value of the lot before tendering. | Econ — relative price = bid_price / lot_estimatedprice (trimmed to (0, 5]); Integrity — estimate-missingness (opaque buyers) |
| `lot_estimatedpriceusd` | Numeric (USD) | Estimated lot value in US dollars. | USD-based relative comparisons |
| `lot_estimatedpricecurrency` | Categorical | Currency of lot_estimatedprice. | Currency checks |
| `is_capital` | Binary (0/1) | Whether the buyer is located in the capital city. | Context; optional regression control |

## Market classification (CPV)

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `lot_productcode` | Categorical (CPV 2008, 8 digits) | Common Procurement Vocabulary code of the lot. First 2 digits = division (market); first 3 digits = the cluster used by the network analysis. | Econ — market sizing & dynamics; Integrity — 3-digit CPV clustering for unusual-entry networks; market entry analyses |
| `lot_localproductcode_type` | Categorical | Nomenclature of the local product code (CPV2008 in the demo). | Metadata |
| `lot_localproductcode` | Categorical | Product code in the local nomenclature (equals lot_productcode in the demo). | Metadata |
| `lot_title` | Text | Free-text title of the lot. | Title-missing indicator (Integrity); display |

## Red-flag indicators (0 = flagged risk, 100 = no risk; OpenTender convention)

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `ind_corr_singleb` | Binary indicator (0/100) | Single bidding: 0 if only one bid was received, 100 otherwise. The app converts it to a single-bid share (y = ind_corr_singleb/100 reversed). | Core outcome — Econ single-bidding trends; Admin & Integrity regressions |
| `ind_corr_nocft` | Binary indicator (0/100) | No call for tenders: 0 if the contract was awarded without a prior call (direct/outright award). | Admin — direct awards; Integrity — transparency |
| `ind_corr_subm_period` | Indicator (0–100) | Submission-period risk score (short windows score low). | Admin — cross-checks the raw submp analyses |
| `ind_corr_dec_period` | Indicator (0–100) | Decision-period risk score (very long decisions score low). | Admin — cross-checks the raw decp analyses |
| `ind_corr_nonopen_proc_method` | Binary indicator (0/100) | 0 if a non-open procedure type was used. | Admin — procedure-mix risk |
| `ind_corr_taxhaven` | Binary indicator (0/100) | 0 if the supplier is registered in a tax-haven jurisdiction. | Integrity — supplier risk context |
| `ind_corr_benfords` | Numeric (0–100) | Benford's-law conformity score of the buyer's contract values. | Integrity — value-distribution forensics |
| `ind_winner_share` | Numeric (0–100) | Winner's share of the buyer's contracts in the period. | Integrity — concentration context |

## Transparency (missingness) indicators (0 = missing, 100 = present)

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `ind_tr_buyer_name_missing` | Binary indicator (0/100) | Buyer name present? | Integrity — Missing Data analyses |
| `ind_tr_title_missing` | Binary indicator (0/100) | Lot title present? | Integrity — Missing Data analyses |
| `ind_tr_bidder_name_missing` | Binary indicator (0/100) | Supplier name present? | Integrity — Missing Data analyses |
| `ind_tr_tender_supplytype_missing` | Binary indicator (0/100) | Supply type present? | Integrity — Missing Data analyses |
| `ind_tr_bid_price_missing` | Binary indicator (0/100) | Contract value present? | Integrity — Missing Data analyses |
| `ind_tr_impl_loc_missing` | Binary indicator (0/100) | Implementation location present? | Integrity — Missing Data analyses |
| `ind_tr_proc__method_missing` | Binary indicator (0/100) | Procedure method present? | Integrity — Missing Data analyses |
| `ind_tr_bids_nr_missing` | Binary indicator (0/100) | Number of bids present? | Integrity — Missing Data analyses |
| `ind_tr_aw_date_missing` | Binary indicator (0/100) | Award date present? | Integrity — Missing Data analyses |

## Competition indicators

| Variable | Type | Definition | Used in |
|---|---|---|---|
| `ind_comp_bids_count` | Numeric | Number of bids received for the lot. | Econ — competition intensity; single-bidding cross-check |
| `ind_comp_bidder_mkt_share` | Numeric (0–100) | Supplier's share of its market (CPV division) in the period. | Econ — supplier dominance; Integrity — concentration context |
| `ind_comp_bidder_mkt_entry` | Indicator | Whether the supplier is a new entrant to this market. | Econ — market entry dynamics |
| `ind_comp_bidder_non_local` | Binary indicator (0/100) | 0 if the supplier is from a different region than the buyer. | Econ — non-local participation |
