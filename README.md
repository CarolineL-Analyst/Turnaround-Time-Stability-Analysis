# Turnaround Time Stability Analysis

While Turnaround Time (TRT) exists across domains (e.g., ticket resolution), this analysis is optimized for production and MRO environments, where variability directly impacts asset availability and delivery commitments.

## Overview
This project analyzes Turnaround Time (TRT) behavior at the **Part No + Workscope** level to assess **process stability, volatility, and anomaly patterns over time**.

Rather than evaluating individual jobs or producing performance scores, the analysis is designed to support **operational review discussions** by highlighting periods where TRT behavior meaningfully deviates from recent historical patterns or exhibits persistent instability.

The focus is on **trend stability and variability**, not on assigning accountability.

## Key Questions
- Has TRT remained broadly stable over time for the same Part No and Workscope?
- Are there periods that deviate noticeably from recent historical behavior?
- Is observed “normal” performance stable, or merely normal relative to an unstable baseline?

## Method Summary
- TRT is calculated as business days between project creation and completion (weekends excluded).
- Metrics are aggregated at the **Part No + Workscope + reporting period** level.
- Rolling statistics are used to contextualize each period against its own recent history.

Key metrics include:
- **Rolling Average TRT** – central tendency
- **Rolling Standard Deviation (STDEV / STDEVP)** – absolute dispersion
- **Rolling Coefficient of Variation (CV)** – relative variability and stability
- **Z-scores** – to identify unusual periods relative to recent behavior

Monthly project count and total TRT workload are included to provide operational context and to avoid over-interpreting low-volume effects.

## Interpretation Framework
Rolling CV is treated as a **primary signal of process stability**, while Z-scores provide context for identifying short-term deviations relative to historical behavior.

Across recurring work scopes, TRT may show:
- **Moderate z-scores with persistently high rolling CV**, indicating that current performance appears “normal” only because historical behavior itself has been highly variable.
- **Stable averages alongside rising variability**, suggesting increasing unpredictability despite no obvious directional trend.

An increasing rolling CV indicates **rising relative variability**, not a directional increase in TRT.
It reflects growing unpredictability around the mean rather than a consistent slowdown.

Such patterns point to a need for **process understanding and expectation management**, rather than immediate corrective action. In time-sensitive environments, sustained variability implies that delivery commitments should be made with caution, potentially using broader ranges or additional buffers.

## Data & Assumptions
- Source: project-level operational data from a project management system
- Each record represents a completed job with Part No, Workscope, start date, and completion date
- Public holidays and partial-day effects are not modeled
- Rolling calculations assume sufficient volume for interpretability

For illustration purposes, Workscope 2 and 3 are occasionally aggregated to ensure stable rolling estimates.

## Scope & Intended Use
This analysis assumes that, under normal operating conditions, TRT for the same Part No and Workscope should exhibit relative stability.

Observed deviations are interpreted as **signals for review**, not definitive performance issues.
The framework is intended as an **early-warning and prioritization tool**, to guide discussion and focus follow-up efforts where they are most valuable.

It does not replace operational judgment, nor does it attempt to automatically infer root causes.

## Technical Implementation
- SQL CTEs
- Window functions
- Rolling averages, standard deviation, and coefficient of variation
- Z-score normalization

Detailed SQL logic and implementation notes are documented in subsequent sections of the repository.
