# MRO Turnaround Time (TRT) Analysis

This project analyzes turnaround time (TRT) performance for MRO (Maintenance, Repair, and Overhaul) operations at the Part Number and Workscope level. Using rolling 12-month statistics — z-scores for anomaly detection and coefficient of variation for stability — it surfaces patterns that distinguish short-term deviations from structurally volatile processes. The output is designed to inform operational review discussions, not to automate decisions.

---

## Project Overview

- Analyze **Turnaround Time (TRT)** performance at the **Part Number + Workscope** level
- Focus on **volatility, anomaly detection, and trend stability** using rolling statistics
- Designed to support **operational review discussions** rather than automate conclusions

---

## Business Questions

- Was the TRT trend stable over time?
- Are there periods that deviate noticeably from recent historical behavior?

---

## Data Description

**PartNumber**
- Identifies the specific part being serviced

**ProjectStartDate**
- The date the project was initiated

**ProjectCompletedDate**
- System-generated timestamp indicating when the project was marked as completed

**WorkscopeCode**
- Identifies the type of work scope associated with the project

---

## Methodology

1. Aggregate TRT at the **Part Number + Workscope** level (project-level aggregation)
2. Compute **12-period rolling average**
3. Compute **12-period rolling standard deviation** (STDEV, STDEVP)
4. Calculate **z-scores** to identify unusual periods relative to recent history
5. Calculate **12-period rolling Coefficient of Variation (CV)** to analyze trend stability
6. Analysis is parameterized by **Part Number, Workscope, and reporting period**

---

## Additional Notes on Interpretation

The following considerations are included to help interpret the rolling metrics in an operational context:

- In addition to average TRT, **monthly project count** and **total TRT workload** are included to provide operational context.
  These metrics help distinguish between structural variability and short-term anomalies, especially in periods with low or uneven project volumes.

- **Z-scores** capture deviations relative to recent historical behavior, while the **rolling Coefficient of Variation (CV)** provides a complementary view of underlying stability by normalizing dispersion against the mean.

- For illustration purposes, the chart aggregates **Workscope 2 and 3**, which represent the most common operational scopes for this Part Number.
  This ensures sufficient project volume for stable rolling estimates.

Together, z-scores and rolling CV provide complementary views:
z-scores highlight short-term deviations from recent history, while rolling CV characterizes the stability of the underlying process itself.

---

## Data Source

This analysis is based on **project-level operational data** extracted from the project management system.

Primary inputs include:
- Project identifiers
- Part Number
- Workscope
- Project start date (ProjectStartDate)
- Project completion date (ProjectCompletedDate)

TRT is approximated as the number of **business days** between project creation and completion, excluding weekends.
Public holidays and partial-day effects are not modeled in this version.

Aggregations and rolling calculations are performed at the **Part Number + Workscope + reporting period** level.

Underlying implementation relies on multiple operational tables; details are intentionally abstracted at this level.

> Table and field names in this repository have been generalized from the original implementation. The SQL logic, statistical methods, and edge case handling reflect the production version.

---

## Scope, Assumptions & Intended Use

This analysis assumes that, for the same **Part Number and Workscope**, TRT behavior is expected to be relatively stable under normal operating conditions.
Observed deviations are therefore interpreted as **signals for review**, not definitive performance issues.

This version intentionally focuses on **project-level TRT** to establish a clear and interpretable baseline.

Potential extensions — such as calendar-complete time series, workload normalization, or operation-level (Ops) analysis — are intentionally **out of scope** for this iteration.

TRT variation may be influenced by factors outside the scope of this analysis, including but not limited to:

- Changes in workload mix or project volume
- Differences between scheduled and unscheduled maintenance activities
- Process or routing changes over time
- Updates (or lack of updates) to estimated time standards
- Data-entry timing and operational practices (e.g., delayed project completion)
- Supplier lead time variability
- Staff capacity constraints and potential new-employee training lag

Accordingly, results should be interpreted in conjunction with operational context and supporting metrics such as **monthly project count** and **total workload**.

This analysis is designed to **guide discussion and prioritization**, not to replace operational judgment.

---

## Interpretation

In this example, **Workscope 2 and Workscope 3** represent the two most common recurring work types for the same Part Number.

### Observed Pattern: Persistent Volatility Across Workscopes

Across both work scopes, TRT exhibits **substantial variability** over time.

### Reading Z-Score and CV Together

In some cases, **z-scores remain within normal ranges** while the **rolling coefficient of variation (CV) remains persistently high**.
This indicates that although no single period deviates sharply from recent history, the underlying process exhibits inherent volatility.

In project-based operational environments, rolling CV values are often structurally elevated due to workload heterogeneity and timing effects.
As a result, interpretation should focus on directional changes in CV over time, rather than absolute CV levels.

A low or moderate z-score combined with a high rolling CV suggests that stability is relative to an **unstable baseline** rather than indicative of a controlled or predictable process.
In other words, current performance may appear "normal" only because historical behavior itself has been highly variable.

### Why This Matters for Operational Decisions

Such patterns point to a need for **process understanding and expectation management** rather than immediate corrective action.
For time-sensitive commitments, this level of variability implies that delivery promises should be made with caution, potentially using broader time ranges or additional buffers.

When rolling CV remains persistently high, **project count alone is insufficient** to explain the observed variability.
A broader operational context should be examined, including concurrent work types, capacity constraints, or cross-workload interactions, to assess whether volatility is intrinsic to the work scope or influenced by parallel activities.

### What CV Direction Tells Us

An increasing rolling CV indicates **rising relative variability**, not a directional increase in TRT.
It reflects growing unpredictability around the mean, not a consistent slowdown in turnaround time.

---

## Skills Demonstrated

**Technical**
- SQL CTEs and window functions for multi-period rolling statistics
- Statistical methods: rolling mean, sample vs population standard deviation, CV, z-score
- Defensive SQL design (guard rules for partial windows, near-zero variance, unstable CV)

**Analytical**
- Translating MRO operations questions into measurable signals
- Distinguishing short-term anomalies (z-score) from structural instability (CV)
- Designing analysis for operational review, with explicit acknowledgment of scope and limitations
