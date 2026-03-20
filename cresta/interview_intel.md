# Interview Intel: Cresta Data Scientist, Customer Analytics

What we know about Cresta's interview process from Glassdoor, Blind, Prachub, Levels.fyi, and 1Point3Acres.

---

## Process Overview

- **Average timeline**: ~21 days
- **Difficulty**: 3/5 on Glassdoor (moderate)
- **Platform**: CoderPad (async assessments + live coding) and Zoom (camera on)
- **Glassdoor positive experience rate**: 28.6% — some candidates love it, others report scheduling issues and recruiter communication gaps

---

## Likely Interview Stages (for DS, Customer Analytics)

Based on reported processes for technical roles, adapted for DS:

| Round | Format | Duration | Focus |
|-------|--------|----------|-------|
| 1. **Recruiter Screen** | Phone/Zoom | ~20 min | Background, role fit, logistics, comp expectations |
| 2. **Technical Screen** | CoderPad + Zoom (camera on) | ~60 min | Live coding in Python + SQL, conceptual stats/AI questions |
| 3. **Second Technical / Case** | CoderPad or presentation | ~60 min | Deeper analytics problem — likely pilot measurement or experiment design |
| 4. **Customer-Facing Round** | Zoom | ~45 min | Communication skills, explaining results to non-technical stakeholders |
| 5. **Hiring Manager / Leadership** | Zoom | ~45 min | Role fit, ambiguity tolerance, cross-functional collaboration |

**Note**: Some roles also include async CoderPad assessments (45 min, 3 questions) before the live rounds.

---

## Reported Technical Questions (from real candidates)

### Coding (Python)

**Balanced Class Sampling** (confirmed Cresta question):
> Given a dataset with labeled classes, you want to randomly sample an n-element subset such that classes are as balanced as possible. Write a function which, given n and the number of examples in each class, computes how many examples should be sampled from each class.

**Pool Orchestrator with Round-Robin** (SWE role, but tests same skills):
> Implement Pool and Orchestrator classes where the Orchestrator distributes jobs across named pools using round-robin scheduling. Key challenge: `remove_pool` method where jobs must be redistributed across remaining pools.

**AI Agent Sequence Generation** (ML Engineer role):
> Implement greedy and beam search strategies for AI agent sequence generation.

### Conceptual Questions

- "What is RAG (Retrieval-Augmented Generation)?"
- "How do you prevent hallucination in LLM outputs?"
- Conceptual questions on RAG pipelines — expected to keep answers practical, not theoretical

### System Design (SWE roles — less likely for DS but worth knowing)

- "Design a web app editor where multiple people can write/edit one document. How would you scale it?"

---

## What They're Testing For (DS Role)

Based on the JD and interview reports:

### Technical Screen — Expect These Topics:
1. **SQL**: Window functions, cohort analysis, pre/post comparisons, data quality checks — all on contact center data
2. **Python**: Pandas data wrangling, statistical testing (t-tests, chi-square, bootstrap), effect size calculation
3. **Statistics**: Hypothesis testing, power analysis, confidence intervals, A/B test design
4. **Experimental Design**: DiD, propensity score matching, handling selection bias in pilot measurement
5. **Light NLP**: Not deep ML — more like "how would you classify customer intents?" or "how would you measure coaching effectiveness from transcripts?"
6. **AI/Product Awareness**: Basic understanding of RAG, LLMs, real-time AI — you don't need to build models, but you need to know how the product works

### Customer-Facing Round — Expect:
- "Explain this A/B test result to a CSM who has no stats background"
- "The customer says Cresta didn't help. How do you investigate?"
- "Walk me through how you'd build a QBR package"
- Communication clarity, storytelling with data, stakeholder empathy

### Leadership Round — Expect:
- "Tell me about a time you turned ambiguity into a structured analysis"
- "How do you prioritize when multiple teams need your work?"
- "What does 'customer value realization' mean to you?"

---

## Format Tips

### CoderPad specifics:
- Camera on during live rounds
- Python is the expected language for DS
- Time pressure is real — practice writing clean code under 45-60 minute constraints
- They value clean, readable code over clever one-liners
- Expect follow-up questions: "What are the edge cases?" "How would you test this?" "What if the data was 100x larger?"

### General tips from candidates:
- **Be hypothesis-first**: Always start with the business question before touching data
- **Translate for your audience**: Technical rigor + plain English is the combo they want
- **Know the product**: Reference specific Cresta features (Agent Assist, Conversation Intelligence, Automation Discovery) in your answers
- **Quantify everything**: Don't say "AHT improved" — say "AHT improved by 35 seconds, translating to $1.5M in annual savings"
- **Show repeatability**: They want someone who builds templates, pipelines, and reusable frameworks — not one-off analyses

---

## Compensation Context (from Levels.fyi)

- Median total comp at Cresta: ~$163K/year
- DS roles in the 1-3 YOE range likely in the $130-180K total comp range (base + equity)
- Cresta is pre-IPO — equity component matters

---

## Red Flags to Watch For

From negative Glassdoor reviews:
- Some candidates reported recruiter rescheduling issues — be patient but follow up proactively
- "Unnecessarily complicated process" complaints — likely for roles with 6+ steps
- For DS, expect a more streamlined 4-5 round process

---

## Questions to Ask (Researched & Tailored)

These show you've done your homework:

1. "Cresta just launched Knowledge Agent and Automation Discovery — how does the Customer Analytics DS team support measurement for these newer product lines?"
2. "With Ocean-1 using LoRA adapters per customer, does the DS team ever work on model evaluation or performance benchmarking, or is that purely engineering?"
3. "What's the current state of the pilot measurement framework — is it standardized across accounts, or still being built?"
4. "How does the team handle accounts where there's no clean control group for measuring Cresta's impact?"
5. "What does the data infrastructure look like — is conversation data flowing into Snowflake/Redshift, and what's the latency from raw events to analytics-ready tables?"
6. "What would make someone in this role a clear success at 6 months?"
