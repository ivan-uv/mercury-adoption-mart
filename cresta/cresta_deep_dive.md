# Cresta AI — Deep Dive for Interview Prep

Know this cold. Every interviewer will expect you to understand what Cresta builds and why it matters.

---

## Company Overview

- **Founded**: 2017, spinout of Stanford AI Lab
- **Mission**: Turn every customer conversation into a competitive advantage
- **Employees**: ~559 (as of Jan 2026)
- **HQ**: San Francisco (offices in NYC, Berlin, Toronto, Romania, India)
- **Valuation**: $1.6B (unicorn)
- **Total funding**: $270M+ across 8 rounds
- **Series D**: $125M (Nov 2024) — led by World Innovation Lab (WiL) and Qatar Investment Authority, with Accenture, Sequoia, a16z, Greylock, Tiger Global
- **Board chair**: Sebastian Thrun (Stanford professor, Google X, Udacity)

### Leadership
- **Ping Wu** — CEO (co-founder of Google Contact Center AI)
- **Tim Shi** — CTO & Co-founder (early member of OpenAI, Stanford PhD)
- **Zayd Enam** — Co-founder (Stanford PhD, former CEO)

**Why this matters in your interview**: Cresta's founders come from the intersection of AI research and enterprise contact centers. This isn't a general-purpose AI play — it's deeply vertical.

---

## The Three Product Pillars

### 1. Agent Assist (the original product)
Real-time guidance for human agents during live calls and chats.
- Suggests what to say, nudges best practices, surfaces knowledge
- Learns from top performers and successful outcomes
- Reduces manual typing by 50%+
- **Knowledge Agent** (launched March 2026): Analyzes live conversation + on-screen context to deliver source-backed answers instantly

### 2. AI Agent (virtual agent)
Fully autonomous customer conversations on voice and chat.
- LLM-native hybrid architecture: combines LLMs with structured business logic
- Handles complex, multi-step troubleshooting (Brinks Home case study)
- Real-time translation in 30+ languages
- Sub-second latency engineering (ASR → LLM → TTS pipeline)

### 3. Conversation Intelligence (analytics layer)
Post-conversation analysis at scale.
- **AI Analyst** (launched Jan 2025): Natural language queries over conversation data — ask business questions, get structured answers with evidence links
- **Automation Discovery**: Scores conversations by volume, complexity, and resolution into an automation readiness score with projected ROI
- Powers QBRs, renewal stories, and executive reporting

---

## The AI Stack (know this — it shows technical depth)

### Ocean-1: Contact Center Foundation Model
- First foundation model purpose-built for contact centers
- Based on **Mixtral/Mistral** architecture, fine-tuned with domain-specific data
- Served via **Fireworks AI** partnership
- Uses **LoRA (Low-Rank Adaptation)** adapters — one base model cluster serves thousands of customer-specific adapters
- **100x cost reduction** vs. GPT-4 for production inference
- Better out-of-box performance + instruction-following than generic LLMs for contact center tasks

### RAG (Retrieval-Augmented Generation)
- Powers Knowledge Assist: real-time AI listens to conversation → detects knowledge need → searches knowledge base → LLM generates response
- Grounds responses in customer-specific documentation to prevent hallucination

### Voice AI Stack
- Stitched approach: ASR → LLM → TTS (not voice-to-voice)
- Uses **Cartesia's Sonic** for text-to-speech (human-like, empathetic voice)
- Core challenge: sub-300ms latency for natural conversation feel
- Deep optimizations across telephony, networking, ASR, LLM, and TTS layers

### Cresta Opera
- No-code generative AI platform for customer-facing teams
- Lets non-engineers interact with LLM capabilities
- Prompt Optimizer: guided recommendations for building high-performing AI agents

### Security & Guardrails
- Enterprise-grade: LLM-based evaluation, evidence-based reasoning, simulation testing, regression testing
- Real-time moderation for sensitive data, malicious inputs, harmful outputs

---

## Key Metrics Cresta Tracks (and that you'd measure in this role)

### Customer-reported averages:
| Metric | Improvement |
|--------|-------------|
| CSAT | +20% |
| Agent onboarding/ramp time | 30% faster |
| Average Handle Time (AHT) | -15% |
| Revenue per lead | +25% |
| First Contact Resolution (FCR) | 2.3x better with AI coaching |

### The metrics that matter for renewals:
- **AHT** → cost efficiency (translates directly to $$$)
- **CSAT** → customer experience
- **FCR** → quality and one-touch resolution
- **Agent ramp time** → operational efficiency for new hires
- **Transfer rate** → CX quality signal
- **Revenue per lead** → for sales-oriented contact centers
- **Coaching adherence** → are agents following Cresta's suggestions?

---

## Customers & Industries

### Named customers:
- **CarMax** — shifted operations to cloud, uses Cresta for sales and support
- **Cox Communications** — telecom, large contact center deployment
- **Hilton** — hospitality, customer service
- **Alaska Airlines** — airline customer support
- **Porsche** — automotive
- **Brinks Home** — security, AI Agent for multi-step troubleshooting
- **Optimum** — telecom, sales effectiveness and post-call automation
- **Aptive Environmental** — pest control, residential services

### Industries:
Automotive, retail, telecom, airlines, travel & hospitality, finance, insurance, healthcare

### Ideal customer profile:
Enterprise with a large team of contact center agents (Fortune 500 sweet spot)

---

## Competitive Landscape

### Direct competitors:
| Company | Differentiator |
|---------|---------------|
| **Observe.AI** | Strong QA and conversation intelligence; expanded into voice AI agents |
| **Balto** | Real-time guidance focused; more mid-market accessible |
| **NICE CXone** | Incumbent CCaaS platform bundling AI features at near-zero marginal cost |
| **ASAPP** | Fortune 100 contact centers (Best Buy, American Airlines) |
| **Cogito (Verint)** | Emotion AI signals + generative AI summaries |
| **Level AI** | Conversation intelligence platform |

### Platform threat:
- **Genesys, NICE, Talkdesk, Dialpad** are bundling AI coaching into core offerings
- **AWS Connect, Google CCAI, Microsoft** offer AI features as part of cloud infra deals
- Risk: AI capabilities get commoditized by the CCaaS layer

### Cresta's moat:
1. **Vertical foundation model** (Ocean-1) trained on contact center data — generic LLMs can't match domain-specific performance
2. **Real-time latency engineering** — sub-200ms guidance during live calls
3. **Unified platform** — AI Agent + Agent Assist + Conversation Intelligence in one
4. **Enterprise trust** — Forrester Wave Leader, Fortune 500 customer base

---

## Recent Product Launches (2025–2026)

| Date | Product | What it does |
|------|---------|-------------|
| Jan 2025 | **AI Analyst** | Natural language queries over conversation data |
| Feb 2025 | **AI Voice Agents at scale** | Brinks Home deployment results |
| Aug 2025 | **Email AI** | AI-augmented CX for email support channel |
| Sep 2025 | **Automated AI Agent Testing** | Confidence scoring for AI deployment |
| Oct 2025 | **Aspect Partnership** | Workforce planning with Agentic AI |
| Nov 2025 | **Agent Operations Center** | Unified command hub for human + AI agent supervision |
| Nov 2025 | **Automation Discovery** | Readiness scoring for which conversations to automate |
| Nov 2025 | **Prompt Optimizer** | Best-practice recommendations for AI agent prompts |
| Nov 2025 | **Real-Time Translation** | 30+ languages across voice and chat |
| Mar 2026 | **Knowledge Agent** | Context-aware real-time answers during live interactions |

---

## Market Context

- Global call center AI market: $2.41B (2025) → $13.52B projected (2034), ~21% CAGR
- AI-assisted contact centers average $3.50 return per $1 invested; top performers see 8x ROI
- Cresta recognized as Forbes "America's Best Startup Employers 2026"
- Forrester Wave Leader: Real-Time Revenue Execution Platforms, Q2 2024

---

## "Why Cresta?" Answer Framework

> "Three things stood out. First, the vertical AI approach — Ocean-1 being purpose-built for contact centers rather than relying on generic LLMs means the data science work here actually drives model performance, not just reporting. Second, the measurement challenge is exactly what I find most interesting: proving causal impact of AI on agent performance in real production environments, with all the messiness of selection bias, confounders, and phased rollouts. And third, the business model creates a natural feedback loop — the better we measure and communicate customer value, the stronger the renewal story, which directly funds more product development. I want to be in the room where analytical rigor drives revenue outcomes."
