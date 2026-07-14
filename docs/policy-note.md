---
title: Policy note
nav_order: 4
---

# Measuring Performance and Integrity in Public Procurement
## Methodological Note for Policy and Analytical Audiences

*This note explains, in non-technical terms, how the Procurement Analysis
Dashboard transforms raw contract-level data into indicators of market
performance, administrative efficiency, and procurement integrity. It is
intended for policymakers, oversight bodies, and researchers who use the
dashboard's outputs but do not work with its underlying code. A companion
technical document (`METHODOLOGY.md`) specifies every formula and parameter
for readers who wish to verify or extend the calculations.*

---

## 1. Purpose and analytical framework

Public procurement typically accounts for a large share of government
expenditure, and its performance is difficult to observe directly. The
dashboard therefore follows the approach now standard in the empirical
procurement literature: it derives **observable, comparable indicators** from
administrative contract records and organises them under three complementary
lenses.

1. **Economic outcomes** — Is the procurement market open and contested?
   Which markets attract spending, do new suppliers enter, and are prices in
   line with expectations?
2. **Administrative efficiency** — Does the procurement *process* enable
   competition? Are competitive procedures used, are bidding windows long
   enough for firms to respond, and are award decisions taken without undue
   delay?
3. **Integrity** — Are there patterns consistent with elevated corruption or
   favouritism risk? These include poor transparency (systematically missing
   information), concentration of a buyer's spending on single suppliers,
   and suppliers winning contracts far outside their line of business.

Two principles govern the entire framework and should be kept in mind when
reading any chart:

- **Indicators are screening devices, not verdicts.** Every measure below has
  legitimate explanations as well as problematic ones. The dashboard's role
  is to direct scarce audit and analytical attention to where risk indicators
  cluster; establishing wrongdoing requires case-level review.
- **All results describe the data as filtered.** Users can restrict any view
  by year, market, contract value, buyer type, and procedure type. Every
  chart caption records the filters in force, and exported reports always
  reflect exactly what was on screen.

---

## 2. The data and how it is prepared

The dashboard analyses a single dataset of contract (tender/lot) records, one
row per contract or bid, of the kind published by national e-procurement
systems and international transparency initiatives.

**Standardisation.** Because national exports name their fields differently,
the dashboard maps common variants onto a standard set of variables: buyer
and supplier identifiers and names, buyer type, product classification,
prices, dates, procedure type, and the number of bids received. Empty cells,
dashes, and the text "NA" are all treated as missing information.

**Key constructed concepts:**

- **Year.** Each contract is assigned to the year of its first call for
  tenders; where that date is unavailable, the award-decision date and then
  the bid deadline are used. Yearly figures should be read with caution at
  the edges of the observed period, where publication lags and changing data
  sources can create artificial rises or falls.
- **Market.** Contracts are grouped into markets using the first two digits
  of the CPV product classification — the "division" level, e.g.
  *Construction work*, *Medical equipment and pharmaceuticals*, *IT
  services*. This is the standard resolution for market-level procurement
  analysis: fine enough to distinguish sectors, coarse enough to yield
  meaningful samples. Throughout this note, "market" means a CPV division.
- **Procedure type.** National procedure labels are harmonised into standard
  categories (Open, Restricted, Negotiated with/without publication,
  Competitive Dialogue, Direct Award, etc.). Labels that cannot be mapped
  are retained under their original name rather than being hidden in an
  "Other" category, so country-specific procedures remain visible.
- **Single bidding.** A contract is classified as single-bid when exactly
  one offer was received. Single bidding is the most widely used
  contract-level indicator of weak competition in the procurement
  literature, because it is objectively measurable and strongly associated
  with higher prices and integrity risk.
- **Prices and currency.** Where several price fields exist, the dashboard
  prefers final contract prices and falls back to estimated prices; charts
  are explicit about which is shown. **No currency conversion is
  performed** — values are displayed in the units of the source data (an
  optional toggle re-labels axes in local currency). Absolute values are
  therefore not comparable across countries.
- **Buyer categories.** Buyers are grouped into national bodies, regional or
  local bodies, utilities, EU-level agencies, and other public bodies, based
  on the buyer-type field.

---

## 3. Economic outcomes: market structure, entry, and prices

### 3.1 Market size

Contracts and spending are summed by market and year. Three views are
provided: number of contracts per market, total value per market, and a
combined view that also displays the average contract size. Together they
answer a basic allocation question — *where does public money go, and in what
form?* Markets with few but very large contracts (typical of infrastructure)
raise different competition and oversight questions than markets with
thousands of small purchases.

### 3.2 Supplier entry and market openness

A healthy procurement market continuously admits new suppliers. The
dashboard measures this directly: within each market, a supplier is counted
as **new** in the first year it wins (or bids for) a contract in that market
during the observed period; thereafter it is a **repeat** supplier. For every
market and year the dashboard reports the number of distinct suppliers and
the share of them that are new.

- The **entry overview** shows, for each market over time, how many
  suppliers are active and what proportion are newcomers. Markets whose
  supplier base is shrinking *and* closed to entry deserve attention: they
  may reflect entrenchment of incumbents.
- The **market stability view** condenses this into one point per market —
  average supplier numbers against average entry rates, with the year-to-year
  variability of entry as an additional signal. The most policy-relevant
  corner is *few suppliers combined with little or no entry*.
- A **top suppliers** ranking identifies the firms winning the largest value
  (or number) of contracts, together with the market each is most active in.

*Reading caution.* By construction, **every** supplier is "new" in the first
observed year, so the first year of any period should be disregarded when
reading entry rates. Moreover, entry statistics are only as reliable as
supplier identification: where harmonised identifiers are missing and names
must be used, spelling variants make the market look more open than it is
(the Integrity section reports identifier quality precisely for this reason).

### 3.3 Buyer–supplier networks

For selected markets, the dashboard draws the network of contracting
relationships: buyers and suppliers as nodes, contracts as connections,
year by year. Networks make certain structures visible that tables hide —
for instance, a buyer connected to a single supplier year after year in a
market where many alternative suppliers are active. Distances and positions
in these diagrams are a drawing convenience; only the *connections* carry
meaning.

### 3.4 Relative prices

Where both the contract price and the buyer's prior cost estimate are
recorded, the dashboard computes the **relative price** — the ratio of the
two. Implausible ratios (non-positive, or more than five times the estimate)
are excluded as likely recording errors.

- A ratio below 1 indicates the contract came in under the estimate; above 1,
  over it. The distribution of ratios, its evolution over time, and the
  markets and buyers with the highest *share of contracts priced above
  estimate* are all reported.
- A pronounced spike **exactly at 1.0** is itself informative: it typically
  means estimates are administratively set equal to contract prices, i.e. it
  reveals an estimation practice rather than a market outcome.

*Reading caution.* Relative prices measure outcomes **against the buyer's own
expectations**. If estimates are systematically inflated or deflated, the
whole picture shifts without any change in market conditions. The indicator
speaks to budgeting accuracy and negotiation outcomes, not to absolute value
for money.

### 3.5 Competition: the single-bidding suite

The share of single-bid contracts is reported overall and broken down by
procedure type, contract-value band, buyer category, market, and individual
buyer, always against the overall average as a reference line. This
decomposition matters for policy: a high aggregate rate driven by small,
routine purchases calls for different remedies than high rates concentrated
in large contracts, specific markets, or specific buyers. Group sizes are
displayed alongside each rate; small groups should be read as indicative
only.

---

## 4. Administrative efficiency: procedures, deadlines, decisions

### 4.1 Choice of procedure

For each year, the dashboard reports the share of contract **value** and of
contract **count** awarded under each procedure type. Competitive procedures
(Open, Restricted) are the benchmark. A pattern worth particular attention
is a rising share of non-competitive procedures *by value* while their share
by count stays flat — a small number of large contracts moving outside
competition.

### 4.2 Bunching of contract values below thresholds

Procurement rules typically prescribe more competitive procedures above
certain contract-value thresholds. This creates an incentive to price — or
split — contracts *just below* the threshold. The dashboard tests for this
with a standard **bunching analysis**:

1. Contract values are examined on a logarithmic scale around each threshold
   configured for the country (separately for goods, works and services).
2. A smooth statistical benchmark (the *counterfactual*) is fitted to the
   value distribution **away from** the threshold — an estimate of what the
   distribution would look like if the threshold had no behavioural effect.
3. Value ranges just below the threshold where the observed number of
   contracts exceeds this benchmark by a wide margin (by default, more than
   50 per cent) are flagged.

An excess mass of contracts just under a threshold is consistent with
strategic pricing or contract splitting to avoid competitive procedures. It
is not proof by itself — budget ceilings and honest cost targeting can
produce mild bunching — and should be corroborated by examining which
procedures and how many bidders those just-below-threshold contracts had.
The sensitivity of the benchmark and of the flagging rule can be adjusted,
and reports record the settings used.

### 4.3 Submission periods (bidding windows)

The **submission period** is the number of days between the publication of
the call for tenders and the bid deadline — the time firms have to prepare an
offer. Implausible values (negative, or a year and longer) are excluded as
recording errors. The dashboard shows the full distribution of submission
periods with its quartiles, the same distribution separately by procedure
type, and the share of tenders with **short** windows — below the legal
minimum where one is configured for the country, or below the national
median for that procedure where no legal minimum exists. An intermediate
"reduced but lawful" band can also be configured for open procedures.
Finally, short-deadline shares are compared across buyer categories.

Short bidding windows are among the most direct administrative restrictions
on competition: they mechanically reduce the set of firms able to respond,
and are a recognised red flag when used selectively. Where medians are used
as the reference (in the absence of legal minima), the "short" share is a
*relative* measure — meaningful for comparisons across procedures, buyers
and years, but not as an absolute compliance rate.

### 4.4 Decision periods

The **decision period** is the number of days between the bid deadline and
the award decision (or, failing that, contract signature). Long decision
periods — beyond a configurable number of days — indicate process
inefficiency, raise costs for bidders, and lengthen the window in which
outcomes can be influenced after bids are known. The same set of views is
provided as for submission periods.

### 4.5 From description to statistical association

Do short bidding windows and long decision periods actually coincide with
weaker competition? The dashboard tests this formally by relating the
probability that a tender receives a single bid to the short-window and
long-decision indicators, using the regression framework described in
Section 6.

---

## 5. Integrity: transparency, concentration, and anomalous behaviour

### 5.1 Completeness of the record (missing data as an indicator)

Transparency is measured directly: for a fixed list of essential fields
(identifiers, dates, procedure type, number of bids, prices, publication
links, and so on) the dashboard reports the share of records in which each
field is empty, overall and broken down by buyer category, procedure type,
and year. As a reading convention, below 5 per cent is treated as low,
5–20 per cent as moderate, and above 20 per cent as high.

Beyond *how much* is missing, the dashboard characterises *how structured*
the gaps are:

- **Co-occurrence analysis** measures whether fields tend to be missing
  *together* — the signature of whole form sections or data sources being
  absent, rather than random omissions.
- A formal statistical test (**Little's test**) assesses whether the data
  could plausibly be "missing completely at random". In administrative data
  of this size the hypothesis is almost always rejected; the test's value is
  to confirm that gaps are patterned.
- A **predictability analysis** then asks how well the *fact that a field is
  missing* can be predicted from observable characteristics such as the
  year, buyer type, or procedure. Highly predictable missingness means
  specific categories of records are systematically less transparent.

This matters twice over. Substantively, selective non-publication is itself
an integrity risk indicator: international evidence links poorer publication
practices to weaker competition and higher prices. Methodologically,
patterned gaps warn the reader that comparisons across the affected
categories rest on unequal information.

A companion **interoperability table** reports, for buyers and suppliers
separately, how often identifiers, names and addresses are missing — i.e.
whether records can be reliably linked across years and registers. Poor
identifier coverage directly weakens all supplier-level analyses.

### 5.2 Supplier concentration within buyers

For each buyer and year, the dashboard computes the largest share of that
buyer's annual spending captured by a single supplier. Buyers whose spending
is (nearly) fully captured by one supplier — especially **repeatedly across
years and over a substantial number of contracts** — are listed. A minimum
contracts-per-year control excludes buyers who simply made very few
purchases, for whom high concentration is arithmetically inevitable.

Concentration is a *dependency* measure. Legitimate sole suppliers exist
(utilities, patented products, framework agreements), so the indicator's
value lies in identifying persistent, high-volume dependencies that merit
explanation, and in tracking their evolution after policy interventions.

### 5.3 Unusual market entries and cross-market patterns

Suppliers occasionally win contracts far outside their established line of
business. The dashboard flags a supplier–market combination as **atypical**
when three conditions hold simultaneously: the supplier has an established
track record overall (at least four awards), the market in question is
marginal for it (under 5 per cent of its awards), and its presence there is
occasional (at most three awards). Individually such entries are usually
benign — diversification, conglomerates, trading firms, or simply
misclassified product codes. The analysis therefore emphasises **systematic
routes**: a flow matrix and a network diagram show, for the most connected
markets, how many suppliers cross from each "home" market into each target
market (only routes shared by at least four suppliers are drawn). Recurrent
flows of many unrelated-sector suppliers into the same market are a
recognised pattern associated with bid rotation and front companies — and
also, more mundanely, with poor product-code discipline, which should be
ruled out first.

### 5.4 Does opacity correlate with worse outcomes?

The integrity section closes the loop with two statistical analyses (see
Section 6 for the method): whether buyers whose records are less complete
also experience **more single bidding**, and whether contracts with more
missing information settle at **higher prices relative to estimates**.
Positive, robust associations support the interpretation of missing data as
a substantive risk indicator rather than a clerical nuisance.

---

## 6. The statistical approach: multi-model estimation and robustness

Wherever the dashboard moves from description to statistical association —
short deadlines and single bidding, long decisions and single bidding,
missing information and single bidding, missing information and relative
prices — it deliberately avoids resting conclusions on a single, hand-picked
model. The concern is well known in applied research: results can depend on
seemingly innocuous modelling choices. The dashboard's answer is a
**specification-grid** design:

1. **Many reasonable models are estimated, not one.** The same relationship
   is estimated under every combination of: several statistical model types
   suited to the outcome; several ways of holding constant stable
   differences between buyers and between years (so that, for example, a
   buyer is effectively compared with *itself* over time rather than with
   very different buyers); several ways of computing appropriately cautious
   uncertainty margins; and with and without control variables such as
   buyer type, procedure type, and contract volume/value.
2. **A preferred estimate is displayed** — the most defensible single model —
   together with its confidence interval and a translation into practical
   magnitude: the predicted change in the outcome when the explanatory
   factor moves from a low (10th percentile) to a high (90th percentile)
   level, holding other characteristics at typical values.
3. **The full grid is summarised in a robustness panel**: a chart showing
   every estimate from every model, and breakdowns of how often the effect
   is statistically significant under each modelling choice. An automatic
   verdict condenses this: the evidence is labelled **strong and robust**
   when at least 70 per cent of models agree on the direction, at least
   60 per cent are statistically significant, and the direction never flips;
   **moderate** under weaker but still substantial agreement; and **weak or
   mixed** otherwise. The verdict criteria are fixed and reported, so the
   label cannot be tuned to a desired conclusion.

**A necessary word on causality.** These are observational data; no deadline
or disclosure practice was varied experimentally. The estimates therefore
measure **associations**, purged of stable buyer and year differences but
not of everything (contract complexity or urgency, for instance, may move
together with both deadlines and bidding). A "strong and robust" verdict
means the correlation is stable across the space of reasonable models — the
appropriate evidentiary standard for a risk-screening and monitoring tool,
and deliberately short of a causal claim.

---

## 7. Principles for interpretation and known limitations

1. **Screening, not adjudication.** Each indicator flags patterns that merit
   scrutiny. Innocent explanations exist for all of them; conclusions about
   individual entities require document- and case-level review.
2. **Triangulate.** The framework is designed so that indicators corroborate
   one another: e.g., bunching below a threshold gains significance if the
   same contracts also show non-competitive procedures and single bids;
   concentration gains significance alongside closed entry in the same
   market. Single-indicator conclusions are discouraged.
3. **Data quality bounds the analysis.** Entity-level results inherit the
   quality of buyer/supplier identifiers; value results inherit the coverage
   of price fields; yearly trends are least reliable at the edges of the
   observed period. The Integrity section quantifies these limitations and
   should be read *first*.
4. **Thresholds and settings are explicit and adjustable.** Legal minimum
   deadlines, procedure value thresholds, analysis year windows, and
   flagging sensitivities are configured per country; where legal values are
   absent, data-driven medians are used and flags become relative measures.
   Exported reports record the settings in force, ensuring reproducibility.
5. **Comparability.** Because no currency conversion is performed and data
   coverage differs across systems, indicators are designed for comparisons
   *within* a country over time, across markets, procedures and buyers — not
   for cross-country league tables of absolute values.
6. **Missing data cuts both ways.** It is treated as a substantive
   transparency indicator, but it also mechanically weakens every other
   statistic computed on the affected records.

---

## 8. Glossary

| Term | Meaning in this framework |
|---|---|
| **Market** | A CPV division (2-digit product classification), e.g. construction, pharmaceuticals, IT services. |
| **Single bidding** | A tender that received exactly one offer; the core competition red flag. |
| **New supplier / entry** | A supplier winning in a market for the first time within the observed period. |
| **Relative price** | Contract price divided by the buyer's prior estimate; 1.0 = exactly on estimate. |
| **Submission period** | Days from call-for-tenders publication to the bid deadline. |
| **Decision period** | Days from the bid deadline to the award decision (or contract signature). |
| **Bunching** | Excess frequency of contract values just below a procedural threshold, relative to a smooth statistical benchmark. |
| **Buyer concentration** | The largest share of a buyer's annual spending won by a single supplier. |
| **Atypical market entry** | An established supplier's occasional, marginal wins far outside its main line of business. |
| **Missing share** | The proportion of records in which a given field is empty. |
| **Fixed effects (plain meaning)** | A statistical device that compares each buyer (or year) with itself, removing stable differences between buyers (or years). |
| **Confidence interval** | The range of estimates consistent with the data at a conventional level of statistical certainty. |
| **Robustness** | The degree to which a result survives across many reasonable modelling choices. |

---

*Prepared as companion documentation to the Procurement Analysis Dashboard.
Technical specifications for every calculation, including exact parameters
and code references, are provided in `METHODOLOGY.md`.*
