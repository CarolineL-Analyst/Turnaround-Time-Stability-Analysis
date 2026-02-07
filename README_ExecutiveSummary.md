## Executive Summary (Non-Technical)

### Purpose

This analysis provides a structured, repeatable way to review **Turnaround Time (TRT)** behavior for the same **Part No** and **Workscope** over time.

Its purpose is not to judge performance in isolation, but to highlight periods where TRT behavior deviates from recent historical patterns and may warrant further review.  
The focus is on identifying **stability and change over time**, rather than evaluating individual jobs or assigning accountability.

---

### What the Analysis Does

The analysis compares project-level TRT across reporting periods against each **Part No + Workscope** combination’s own recent history using rolling statistics.

This allows stakeholders to quickly assess whether TRT has remained broadly stable, or whether unusual shifts have occurred relative to prior behavior.  
The intent is to **surface signals that help prioritize attention**, not to provide automated conclusions.

---

### Data Source (Summary)

Project lifecycle data is sourced from the operational project management system, including project creation and completion timestamps, along with associated **Part No** and **Workscope** attributes.

---

### Data Description

- **Part number** – identifies the component or item being serviced  
- **Work scope** – the type of work performed (e.g., inspection, repair, overhaul)  
- **Project start date** – when the work was initiated  
- **Project completion date** – when the work was finished and recorded by the system  
- **TRT (Turnaround Time)** – the number of business days between project start and completion  

Each data point represents a completed job: what was worked on, what type of work it was, and how long it remained in the system.

---

### How Results Should Be Used

Results are intended to support **operational review discussions**.

When unusual periods are identified, users are encouraged to examine contextual factors such as workload volume, staffing capacity, process or routing changes, or data-entry practices before drawing conclusions.  
This approach helps narrow attention to a manageable set of periods or **Part No / Workscope** combinations, enabling more effective follow-up without requiring detailed inspection of every individual work order.

---

### Intended Use & Limitations

This analysis does **not** replace operational judgment, nor does it attempt to automatically explain root causes.  
It is designed as an **early-signal and prioritization tool**, not a performance scorecard.
