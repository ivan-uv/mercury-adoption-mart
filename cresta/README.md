# Cresta — Data Scientist, Customer Analytics

Interview prep for the **Data Scientist, Customer Analytics** role at Cresta.

---

## Role Summary

- **Team**: Customer Success organization
- **Focus**: Measuring and storytelling customer impact — ROI, pilots, QBRs, renewals
- **Partners**: Business Value consultants, CSMs, Sales, Product, Engineering
- **Stack signals**: SQL, Python (Pandas, scikit-learn), Hex/Looker/Tableau, Snowflake/Redshift, conversational data

---

## What They're Actually Hiring For

Reading between the lines of the JD:

1. **Experiment design & pilot measurement** — A/B tests and quasi-experiments to prove Cresta's product works for customers. This is the core deliverable. Every renewal conversation depends on it.
2. **Dashboard & reporting infrastructure** — Standardized packages for QBRs. Repeatability and scalability.
3. **EDA on conversational data** — Call transcripts, chat logs. NLP-light work (classification, intent tagging, segmentation).
4. **Statistical rigor translated for non-technical audiences** — CSMs and sales reps need to use your outputs. You're the translator.

---

## Prep Materials

| File | What it covers |
|------|---------------|
| [`cresta_deep_dive.md`](cresta_deep_dive.md) | **START HERE** — Cresta product, tech stack, customers, competitors, market context |
| [`interview_intel.md`](interview_intel.md) | Interview process, reported questions, format tips, what to expect |
| [`schema.md`](schema.md) | Full data schema — 6 tables, column definitions, relationships, ERD |
| [`questions.md`](questions.md) | Full question bank by category |
| [`case_study.md`](case_study.md) | Full realistic case study: pilot measurement for a contact center client |
| [`study_guide.md`](study_guide.md) | Key concepts to review, with quick-reference notes + Cresta-specific AI/LLM concepts |

### SQL (`sql/`)

| File | What it covers |
|------|---------------|
| [`sql/questions.sql`](sql/questions.sql) | 20 problems — prompts only, no answers (includes Cresta-specific scenarios) |
| [`sql/solutions.sql`](sql/solutions.sql) | Full solutions with inline explanations |

### Python (`python/`)

| File | What it covers |
|------|---------------|
| [`python/questions.py`](python/questions.py) | Function stubs + docstrings — implement these |
| [`python/solutions.py`](python/solutions.py) | Full implementations + runnable demo (`python solutions.py`) |

---

## Interview Structure (Likely)

1. **Recruiter screen** — Background, motivation, comp
2. **Hiring manager round** — Role fit, how you think about customer analytics, comfort with ambiguity
3. **Technical screen** — SQL + Python live coding or take-home
4. **Case study / presentation** — Given a dataset or scenario, design an analysis and present findings
5. **Cross-functional panel** — CSM, BV consultant, possibly Product. Focus on communication and collaboration.

---

## Key Themes to Hit in Every Round

- "I think about this through the lens of *what does the CSM need to walk into a renewal confident*"
- Hypothesis-first: always start with the business question before touching data
- Statistical rigor + plain language — know your audience
- Repeatability: templates, automation, reusable pipelines
- Conversational data experience (or clear transferable analogy)
