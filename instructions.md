# Multi-Model Orchestration & Governance — Master Build Instructions

## 0. One-line Vision

A smart routing + governance layer that apps call instead of individual AI models. It decides which model to use for each request (cost, latency, accuracy, compliance), enforces policies, provides fallbacks, and exposes auditable cost/lineage/metrics.

## 1. Elevator Pitch

### What it is and why it exists

- **Today's Problem**: Teams hard-code calls to GPT-4/Claude/etc. This is brittle, expensive, and non-compliant for some data.
- **Our Solution**: We provide one API (`/predict`) that:
  1. Picks the right model per request
  2. Fails over when a provider degrades
  3. Enforces rules (e.g., "no PII to external providers")
  4. Measures cost/latency/accuracy
  5. Produces lineage & audit trails
- **Think**: "Kubernetes for models": a control plane for LLMs and classic ML.

## 2. Non-goals (explicitly out of scope for v1)

- ❌ Not building an LLM from scratch
- ❌ Not a full RAG system (we integrate with your RAG app; we don't index docs)
- ❌ Not an IDE/coding assistant; this is horizontal infra, not a vertical app
- ❌ Not a marketplace of prompts or model fine-tuning service (later phases)

## 3. Primary User Roles & Top Use-cases

### Roles

- **Platform Admin/ML Ops**: connects providers, sets policies, observes spend/SLOs
- **App Developers**: call a single SDK/API; receive results + routing metadata
- **Compliance/Finance**: view lineage, export audit reports, get cost analytics

### Use-cases

1. **Cost control**: route simple prompts to cheap internal model; complex ones to GPT-4o
2. **Reliability**: automatic failover if a provider throttles/outages
3. **Compliance**: block external providers for PII-tagged requests
4. **Experimentation**: canary new models/policies with guardrails and auto-rollback

## 4. High-level Architecture (3 Planes)

### Serving Plane
- API Gateway/Router (FastAPI or Go): `/predict`, `/embeddings`, `/moderate`
- Result Cache (Redis) and token/cost metering

### Control Plane
- Policy Engine (policy-as-code YAML → compiled decision graph)
- Model/Provider Registry (metadata, health, quotas, region)
- Experiment Manager (A/B, canary, bandits)
- Governance (RBAC, tenant isolation, audit logs, lineage)

### Data/Observability Plane
- Postgres (tenants, apps, policies, lineage, bills)
- Object store (S3) for reports/exports
- Prometheus + Grafana (metrics), OpenTelemetry (traces), Loki (logs)

## 5. Component Responsibilities (Detailed)

### 5.1 API Gateway/Router
- Validate auth (App API key / OIDC)
- Enrich request context (tenant, app, tags)
- Call Policy Engine for route decision
- Apply guardrails (output token cap, blocklists)
- Make provider call via Adapter with timeouts + retries
- Emit route metadata (model, version, latency, cost, rule_id)
- Write lineage event to Postgres and metrics to Prometheus
- Circuit breakers per provider + fallback chain

### 5.2 Policy Engine
- **Input**: request context (prompt_tokens, pii_level, language, app, user_role, business tags), live provider health/cost limits
- **Output**: ordered candidate model list with constraints
- **Supports**:
  - Rules (when clauses), weighted choices, in-order fallbacks
  - Per-app budgets, per-tenant routing, compliance gates
  - Validation (schema + static checks; fail closed on invalid)

### 5.3 Provider Adapters
- Pluggable adapters for OpenAI, Anthropic, Mistral, vLLM (internal), etc.
- Uniform interface: `invoke(request) -> {text/choices, tokens, latency, provider_raw}`
- Handle provider-specific retries, streamed/non-streamed responses, rate limits
- Support embeddings and moderation endpoints (where available)

### 5.4 Health/Quota Service
- Probes provider latency/error rate; exposes health score and quotas (RPS, tokens/s)
- Router consults health before final route; demotes unhealthy providers

### 5.5 Cost Metering
- Maintain price tables ($/1k tokens, per request minimums)
- Estimate cost per call and aggregate per app/team/tenant/model
- Budget alarms and policy auto-throttle (e.g., pause premium routes when budget hit)

### 5.6 Experimentation
- **Canary**: route N% traffic to new model/policy variant
- **Success metrics**: latency_p95, cost/query, win rate (LLM judge / user rating)
- Auto-promote/rollback logic with cool-down and error budgets

### 5.7 Governance/Compliance
- RBAC (Admin/Developer/Finance/Compliance)
- RLS (Row-Level Security) per tenant in Postgres
- PII/Secrets tags accepted from caller (or optional inline DLP pre-filter)
- Policy "deny" paths (e.g., "external_blocked" reason)

### 5.8 UI Console
- Connections (providers, keys, regions)
- Models (visibility, cost, health)
- Policies: visual + YAML editor with validation and dry-run
- Experiments: create/monitor/promote
- Dashboards: cost, latency, accuracy (if provided), violations
- Lineage Browser: search requests, drill into full decision/routing trace
- Exports: CSV/PDF model cards, decision logs, invoices

### 5.9 CLI
- `mmctl providers add …`, `mmctl policies apply …`, `mmctl experiments start …`, `mmctl reports export …`

## 6. Storage Layout & Schemas

### 6.1 Datastores
- **Postgres**: core metadata, policies, lineage, billing
- **Redis**: result cache (prompt→completion), rate limiting tokens
- **Prometheus**: time-series metrics; Grafana dashboards
- **S3**: reports, exports, archived policies
- **Loki** (optional): logs

### 6.2 Core Tables (Postgres)

```sql
TENANT(id, name, kms_key, created_at)
APP(id, tenant_id, name, role_scope, created_at)
API_KEY(id, app_id, hash, scopes, created_at, last_used_at)

PROVIDER(id, tenant_id, name, kind, region, status, quotas_json)
MODEL(id, provider_id, name, version, price_per_1k_tokens, capabilities, compliance_tag, enabled)

POLICY(id, app_id, version, yaml, compiled_json, status, created_by, created_at)
EXPERIMENT(id, app_id, name, variant_yaml, traffic_pct, state, metrics_json)

LINEAGE(id, tenant_id, app_id, request_id, model_id, policy_rule_id, latency_ms, tokens_prompt, tokens_completion,
        cost_usd, status, pii_level, fallback_chain_json, ts)

BILLING_ROLLUP(id, tenant_id, app_id, model_id, day, requests, tokens, cost_usd)
```

- Enforce RLS on `TENANT`, `APP`, `LINEAGE`, `BILLING_ROLLUP`

## 7. API Design (Minimum Set)

### 7.1 Public Inference

#### POST /v1/predict

**Request:**
```json
{
  "app": "support-bot",
  "input": "Summarize the refund policy.",
  "context": {
    "tenant": "acme-us",
    "user_role": "agent",
    "pii_level": "low",
    "prompt_tokens": 92,
    "language": "en",
    "tags": ["customer_support","prod"]
  },
  "options": {
    "grounding_required": true,
    "max_tokens": 400,
    "temperature": 0.2
  }
}
```

**Response:**
```json
{
  "output": "For annual plans, refunds are prorated within 30 days...",
  "route": {
    "model": "llama-3.1-70b",
    "version": "2025-09-01",
    "policy_rule_id": "support.short_lowrisk_weighted",
    "fell_back": false,
    "latency_ms": 471,
    "token_usage": {"prompt":120,"completion":210},
    "cost_usd": 0.0028
  },
  "audit_id": "req_01J8PVK6T4W"
}
```

#### POST /v1/embeddings
Similar shape with input array; returns vectors + routing meta.

### 7.2 Admin
- `POST /admin/providers` (add), `GET /admin/providers`
- `POST /admin/models` (register), `GET /admin/models`
- `POST /admin/policies` (validate/apply), `GET /admin/policies/:id`
- `POST /admin/experiments/start|stop|promote`
- `GET /admin/costs?by=app|model|tenant&period=…`
- `GET /admin/lineage/:audit_id`

### 7.3 Error Model
- **4xx**: auth, quota exceeded, policy deny (include deny_reason)
- **5xx**: router/provider errors; include provider_error_code, retry_after if known
- Always return audit_id

## 8. Policy Language (YAML Spec)

### Schema (abridged)

```yaml
app: <string>
slo:
  latency_p95_ms: <int>
  grounding_required: <bool>
budget:
  monthly_usd_limit: <float>
routing:
  - when: { pii_level: "high" }
    choose: ["internal-llama"]
  - when: { prompt_tokens_lt: 200 }
    choose_weighted:
      - { model: "internal-llama", weight: 0.7 }
      - { model: "gpt-4o", weight: 0.3 }
  - when: { prompt_tokens_gte: 200 }
    choose_in_order: ["gpt-4o", "claude-3-opus", "internal-llama"]
fallback:
  on_error: ["claude-3-opus", "internal-llama"]
guardrails:
  block_external_for_tags: ["payment_card","customer_ssn"]
  max_output_tokens: 800
observability:
  log_fields: ["model","latency_ms","token_usage","cost_usd","policy_rule_id","pii_level"]
```

### Validation Rules
- Models referenced must exist & be enabled
- `choose_weighted` weights sum to 1
- No cyclic fallbacks
- If `budget.monthly_usd_limit` exceeded → downgrade to cheapest compliant route or return policy-deny with budget_exceeded

## 9. Routing Algorithm (Pseudocode)

```python
function route(request):
  ctx = enrich(request)  # app, tenant, pii, tokens, language, tags
  policy = fetch_policy(ctx.app)

  candidates = match_rules(policy.routing, ctx)
  candidates = filter_by_compliance(candidates, ctx)
  candidates = apply_health_and_quota(candidates)   # drop degraded
  if candidates empty: return deny("no_eligible_model")

  # Experiment overrides (canary/bandit)
  candidates = apply_experiment(ctx.app, candidates)

  chosen = pick(candidates)  # weighted or first-in-order
  result = invoke_with_fallbacks(chosen, policy.fallback.on_error)

  if result.error and no more fallbacks:
     return error(…)
  else:
     compute_cost_tokens(result)
     log_lineage(ctx, chosen, policy_rule_id, result)
     return format_response(result, chosen, policy_rule_id)
```

## 10. Fallbacks, Retries, Circuit Breakers

- Retry transient 5xx/429 with jittered backoff (provider-specific)
- Circuit breaker per provider/model: open after N failures or p95 latency > threshold for M seconds
- Fallback chain from policy; annotate `fell_back: true` and the chain tried
- Degrade mode: if all fail, optional "cheapest minimal completion" (configurable) or explicit error with remediation hint

## 11. Caching

- Prompt/result cache (Redis) keyed by normalized prompt + options + app + policy version. TTL configurable; cache bypass flag
- Embedding cache keyed by text hash + model
- Provider response cache (short TTL) to reduce duplicate calls under spikes

## 12. SLOs & KPIs (Enforced and Reported)

- **Latency**: p95 < 2s for LLM completions; < 300ms for embeddings
- **Availability**: 99.9% router uptime
- **Compliance**: < 0.01% policy-violation attempts reaching external providers
- **Cost KPIs**: $/1k tokens by app; weekly spend variance < 20% unless approved
- **Experiment guardrails**: no promotion if latency p95 or grounding rate regresses beyond threshold

## 13. Security & Compliance

- **AuthN/AuthZ**: OIDC for admins; App API keys for apps (scoped to app & tenant)
- **Tenant isolation**: RLS in Postgres; per-tenant namespaces on caches if needed
- **Secrets**: KMS-encrypted; rotate provider keys
- **PII handling**: accept pii_level from caller; optional in-router DLP (regex + NER) to auto-set tag; enforce policy gates
- **Audit**: immutable lineage records; tamper-evident hashing of decision logs (optional Merkle chain)

## 14. CI/CD & Environments

- **Repos**: mono-repo with apps/router, apps/console, libs/sdk, infra/terraform, .github/workflows
- **Pipelines**: lint → unit tests → build Docker → integration tests (docker-compose) → Helm chart render → deploy to staging → smoke tests → promote
- **Policies as code**: PR-reviewed YAML, validated on CI, versioned and signed
- **Feature flags**: experiments & model toggles via config service

## 15. Testing Strategy

- **Unit**: policy matcher, cost calc, adapter mocks
- **Integration**: end-to-end calls using local mock providers; record/replay fixtures
- **Chaos tests**: provider returns 429/5xx/timeouts → ensure fallback path works
- **Load tests**: open-loop RPS ramp; confirm SLOs and circuit-breaker behavior
- **Security tests**: RBAC, RLS leak checks, key/secret scans

## 16. Deployment Options

- **SaaS**: multi-tenant; per-tenant encryption; regional data residency option
- **Private/VPC**: Helm chart + Terraform; customers supply VPC, Postgres, Redis, KMS; no keys leave their cloud

## 17. Runbooks (Abbreviated)

- **Provider outage**: circuit opens → traffic shifts via fallback; postmortem records health metrics deltas and added cost
- **Budget breach**: auto-downgrade route; notify admins; export cost report
- **Policy regression**: rollback to previous policy version; dry-run simulator to validate

## 18. Observability (What to Emit)

- **Metrics**: requests_total, errors_total {app, model, provider, reason}; latency_ms histogram; tokens_prompt/completion; cost_usd; cache_hit_ratio; circuit_breaker_state
- **Traces**: route decision span → adapter invoke span → provider span; include policy_rule_id
- **Logs**: structured JSON with audit_id, tenant, app, model, rule_id, latency_ms, cost_usd, fallback_chain

## 19. Versioning Strategy

- **Models**: semantic version (provider+name+date); keep price & capability metadata for historical queries
- **Policies**: immutable versions; embed hash in lineage entries
- **SDKs**: semver; deprecate older major versions with compatibility shims

## 20. Example: Full Policy YAML (Copy-paste)

```yaml
app: support-bot
slo:
  latency_p95_ms: 2000
  grounding_required: true
budget:
  monthly_usd_limit: 5000
routing:
  - when: { pii_level: "high" }
    choose: ["internal-llama"]
  - when: { prompt_tokens_lt: 200, language: "en" }
    choose_weighted:
      - { model: "internal-llama", weight: 0.75 }
      - { model: "gpt-4o", weight: 0.25 }
  - when: { prompt_tokens_gte: 200 }
    choose_in_order: ["gpt-4o", "claude-3-opus", "internal-llama"]
fallback:
  on_error: ["claude-3-opus", "internal-llama"]
guardrails:
  block_external_for_tags: ["payment_card","customer_ssn"]
  max_output_tokens: 800
observability:
  log_fields: ["model","latency_ms","token_usage","cost_usd","policy_rule_id","pii_level","fell_back"]
```

## 21. SDK Stubs (Python & TypeScript)

### Python

```python
# pip install mmops-client
from mmops_client import Client

client = Client(base_url="https://router.example.com", api_key="APP_KEY")

resp = client.predict({
    "app": "support-bot",
    "input": "What is our refund policy?",
    "context": {"tenant":"acme-us","pii_level":"low","prompt_tokens":92,"language":"en"},
    "options": {"grounding_required": True, "max_tokens": 400}
})
print(resp["output"], resp["route"]["model"], resp["route"]["latency_ms"])
```

### TypeScript

```typescript
// npm i @mmops/client
import { MmopsClient } from "@mmops/client";

const client = new MmopsClient({ baseUrl: "https://router.example.com", apiKey: process.env.APP_KEY! });

const resp = await client.predict({
  app: "support-bot",
  input: "Summarize ticket #4837 in 4 bullets.",
  context: { tenant: "acme-us", pii_level: "low", prompt_tokens: 120, language: "en" },
  options: { max_tokens: 400, temperature: 0.2 }
});

console.log(resp.output, resp.route.model, resp.route.latency_ms);
```

## 22. "Day-0 to Running" Quickstart

1. Deploy infra with Terraform (Postgres, Redis, Prometheus, S3)
2. `helm install mmops charts/router` (values: env URLs, secrets)
3. Add providers: `mmctl providers add openai --key $OPENAI_KEY`
4. Register models: `mmctl models add gpt-4o …`; `models add internal-llama …`
5. Apply policy: `mmctl policies apply policies/support-bot.yaml`
6. Create app key: `mmctl apps create support-bot --tenant acme-us`
7. Integrate SDK in app; make one `/predict` call; confirm response + route metadata
8. Open Console: verify cost/latency dashboards and lineage search

## 23. Acceptance Criteria (MVP)

- ✅ One public `/predict` endpoint with request/response schema above
- ✅ Policy engine implements when, choose_weighted, choose_in_order, fallback
- ✅ Adapters: OpenAI, Anthropic, internal vLLM (mock ok)
- ✅ Fallback works (provable via chaos tests)
- ✅ Cost metering per request and aggregated per app & model
- ✅ Lineage persisted with audit_id; retrievable via console/endpoint
- ✅ Dashboards show latency p50/p95, cost by model/app
- ✅ RBAC with Admin/Developer; API key scoping
- ✅ 20+ unit tests; 5+ integration tests incl. provider 429/5xx handling
- ✅ Load test to 500 RPS sustained with documented p95

## 24. Risks & Mitigations

- **Provider API changes**: abstraction in adapters; smoke tests nightly
- **Latency overhead**: keep routing decision in-memory; cache policy; use async I/O; Redis for caches
- **Policy complexity**: start with minimal schema; provide clear validation + examples
- **Cost spikes**: budgets + alarms + auto-downgrade routes

## 25. Roadmap (Post-MVP)

- Policy simulator (dry-run a day of logs against new policy)
- Bandit router (auto-optimize cost/quality)
- Fine-grained RBAC (per-model, per-route)
- PII auto-tagger plug-in (Presidio/NER)
- Billing exporter (Stripe/QuickBooks)
- Embeddings & reranker orchestration with the same policy engine

## 26. Glossary (Short)

- **Policy**: rules that map request context → candidate models
- **Lineage**: auditable record of which model/route produced an output
- **RLS**: Row-Level Security in Postgres for tenant isolation
- **Canary**: small % of traffic to a new variant to test safely

---

## How to Use This Document

- Treat it as the source of truth for your ChatGPT project
- When you ask for code, reference the relevant section (e.g., "Implement 7.1 /v1/predict in FastAPI as specified")
- When you ask for tests or dashboards, point to sections 15 and 18
- For policies, copy from 20 and ask for validators from 8

If you want, I can also generate:
- a repo skeleton (folders, Dockerfiles, Helm chart, Terraform)
- a policy validator (JSON Schema + tests)
- or a minimal FastAPI router implementing /predict + OpenAI/Anthropic mocks

---

# ✨ Feature Pack: Model Recommendation + User Subscriptions + Sensitive-Output Firewall

## A) Product Behavior (Plain English)

### 1. Model Recommendation + Redirect
- When an app calls `/v1/predict`, the router first recommends the best eligible model (by policy, health, budget, and user subscriptions), and then invokes that model
- The response includes both:
  - `route.recommended_model` (what the router decided up front)
  - `route.final_model` (what actually served the request—may differ if we had to fallback)

### 2. User/Team Model Subscriptions
- Admins toggle which models are available to a tenant/app/team
- Routing will only consider subscribed models (after compliance filters)
- Users can manage subscriptions in the Console (and via API). Subscriptions can be scoped:
  - tenant-wide
  - per app
  - or per role/team (e.g., "Support" gets GPT-4o mini + internal Llama; "Research" also gets Claude Opus)

### 3. Sensitive-Output Validation Plugin (Firewall)
- Every completion flows through a post-inference validator:
  - If sensitive content (PII, secrets, banned entities) is detected:
    - **Action = flag** → return the original model output but mark `sensitive_flag=true` and include violations
    - **Action = redraft** → automatically request a sanitized rewrite (using internal policy-safe model) and return the redrafted output instead of the original
  - The action is configurable per app/policy; all incidents are audited

## B) Architecture Deltas

### B.1 New Components
- **Recommendation Engine** (inside Policy Engine)
  - Computes `recommended_model` before invocation. Factors:
  - policy rules, health/quotas, user/app subscriptions, budgets, latency/price tables
- **Subscription Gate**
  - Filters candidate models by tenant/app/team subscriptions
- **Sensitive Output Firewall** (post-processor)
  - Runs a chain of detectors (regex, NER/Presidio, secret scanners, custom lists)
  - Optional LLM judge for contextual leakage (e.g., combines name+DOB+address)
  - Action executor: flag or redraft (calls a pre-approved sanitizing model)
- **Sanitizing Model Adapter**
  - A safe model or deterministic template that rewrites outputs to remove/replace sensitive spans

### B.2 Request Flow (Updated)
1. API Gateway receives request → enrich context
2. Policy Engine recommends `recommended_model` (subscriptions + compliance + health + budget)
3. Router invokes provider; on failure, applies fallback chain → `final_model`
4. Firewall inspects `final_model` output:
   - If clean → return
   - If violations:
     - **flag**: return original output with `sensitive_flag=true`
     - **redraft**: call sanitizing model → replace output → return with `redrafted=true`
5. Emit lineage with `recommended_model`, `final_model`, firewall decision, and violation summary

## C) API & SDK Changes

### C.1 Public Inference

#### POST /v1/predict

**Request (additions):**
```json
{
  "app": "support-bot",
  "input": "Explain our refund policy with an example using customer data ...",
  "context": {
    "tenant": "acme-us",
    "user_role": "agent",
    "pii_level": "low",
    "prompt_tokens": 118,
    "language": "en",
    "team": "support"
  },
  "options": {
    "grounding_required": true,
    "max_tokens": 400,
    "temperature": 0.2,
    "sensitive_output_action": "redraft"   // "flag" | "redraft" | "off" (policy may override)
  }
}
```

**Response (additions):**
```json
{
  "output": "For annual plans, refunds are prorated within 30 days ...",
  "route": {
    "recommended_model": "llama-3.1-70b",
    "final_model": "llama-3.1-70b",
    "fell_back": false,
    "latency_ms": 471,
    "token_usage": {"prompt":120,"completion":210},
    "cost_usd": 0.0028,
    "policy_rule_id": "support.short_lowrisk_weighted",
    "subscription_scope": "app"           // "tenant" | "app" | "team"
  },
  "safety": {
    "sensitive_flag": false,
    "redrafted": false,
    "violations": []                      // if present: [{"type":"PII_SSN","span":[..], "sample":"***-**-1234"}]
  },
  "audit_id": "req_01J9..."
}
```

**When redrafted:**
```json
"safety": {
  "sensitive_flag": true,
  "redrafted": true,
  "violations": [{"type":"SECRET_API_KEY"}],
  "sanitizing_model": "internal-guard-7b",
  "note": "Original output contained sensitive data; response was rewritten to remove it."
}
```

### C.2 Subscriptions API
- `POST /admin/subscriptions`
  ```json
  { "scope": "app", "tenant":"acme-us", "app":"support-bot", "team": null,
    "models": ["internal-llama","gpt-4o-mini"], "enabled": true }
  ```
- `GET /admin/subscriptions?tenant=acme-us&app=support-bot`
- `DELETE /admin/subscriptions/:id`

### C.3 Recommendation-only (Optional Helper)
- `POST /v1/recommend-model` (does not invoke)
  ```json
  { "app":"support-bot", "context":{...} } -> { "recommended_model":"internal-llama", "candidates":[...], "explain":"short_en_lowrisk" }
  ```

### C.4 SDK Additions
- Expose `recommended_model`, `final_model`, `safety.redrafted`, `safety.violations`
- Provide a helper `client.recommend({...})`

## D) Policy & Config Extensions

### D.1 Policy YAML (New Fields)

```yaml
app: support-bot
subscriptions:
  scope_precedence: ["app","team","tenant"]   # which subscription scope to check first
sensitive_output:
  default_action: redraft                     # flag | redraft | off
  detectors:
    - preset: pii_basic                       # email, phone, ssn
    - preset: secrets                         # api keys, tokens
    - preset: gdpr_names
    - regex: "(?i)credit\\s?card\\s?number[:\\s]*([0-9- ]{12,19})"
  redraft:
    model: "internal-guard-7b"
    system_prompt: |
      You are a safety editor. Rewrite the assistant output to remove or mask any sensitive information:
      - Replace SSNs with "[REDACTED-SSN]".
      - Replace API keys with "[REDACTED-KEY]".
      Keep meaning intact; do not add new facts.
routing:
  - when: { pii_level: "high" }          # still honored during recommendation
    choose: ["internal-llama"]
  - when: { prompt_tokens_lt: 200, language: "en" }
    choose_weighted:
      - { model: "internal-llama", weight: 0.75 }
      - { model: "gpt-4o-mini", weight: 0.25 }
fallback:
  on_error: ["gpt-4o-mini","claude-3-haiku"]
```

### D.2 Recommendation Rules
- Recommendation step must pass through:
  - Subscription filter (eligible for this tenant/app/team)
  - Compliance filter (e.g., PII → internal only)
  - Health/quota/budget gates

## E) Data Model Changes (Postgres)

**Add tables:**

```sql
SUBSCRIPTION(
  id, tenant_id, app_id NULL, team NULL,
  scope ENUM('tenant','app','team'),
  models TEXT[], enabled BOOL, created_at, created_by
)

RECOMMENDATION_LOG(
  id, audit_id, tenant_id, app_id,
  recommended_model, candidate_set JSONB,
  subscription_scope, policy_version, ts
)

FIREWALL_EVENT(
  id, audit_id, tenant_id, app_id,
  action ENUM('none','flag','redraft'),
  detectors JSONB, violations JSONB, sanitizing_model NULL,
  redraft_latency_ms NULL, ts
)
```

**Extend LINEAGE with:**
- `recommended_model`, `final_model` (keeping existing model_id for backward compat)
- `subscription_scope`, `sensitive_flag BOOL`, `redrafted BOOL`

RLS applies to new tables (by tenant).

## F) Routing & Firewall Pseudocode

```python
def handle_predict(req):
    ctx = enrich(req)  # tenant, app, team, language, pii_level, tokens, tags
    policy = load_policy(ctx.app)

    # --- Recommendation phase ---
    candidates = match_rules(policy.routing, ctx)
    candidates = filter_by_subscriptions(candidates, ctx)         # NEW
    candidates = filter_by_compliance(candidates, ctx)
    candidates = filter_by_health_quota_budget(candidates, ctx)
    if not candidates:
        return deny("no_eligible_model")

    recommended = pick_candidate(candidates)                      # weighted/ordered
    log_recommendation(audit_id, ctx, recommended, candidates)    # NEW

    # --- Invocation + fallback ---
    final_model, raw_output, meta = invoke_with_fallbacks(recommended, policy.fallback)

    # --- Sensitive-output firewall ---
    fw_cfg = resolve_firewall_config(policy, req.options)
    violations = detect_sensitive(raw_output, fw_cfg.detectors)
    if not violations:
        return respond(raw_output, recommended, final_model, safety=clean)

    if fw_cfg.default_action == "flag" or req.options.sensitive_output_action == "flag":
        return respond(raw_output, recommended, final_model,
                       safety=flag(violations))

    if fw_cfg.default_action == "redraft" or req.options.sensitive_output_action == "redraft":
        safe_output, redraft_meta = sanitize_output(raw_output, fw_cfg.redraft)
        return respond(safe_output, recommended, final_model,
                       safety=redrafted(violations, redraft_meta))

    # action=off
    return respond(raw_output, recommended, final_model, safety=flag(violations))
```

## G) Console (UI) Updates

- **Subscriptions page**
  - Scope toggle: Tenant / App / Team
  - Model list with checkboxes, search, bulk enable/disable
  - Preview panel: "Effective models for Support team" (after precedence rules)
- **Policy editor**
  - New "Sensitive Output" tab (detectors, action, sanitizing prompt)
- **Runs / Lineage**
  - Columns: Recommended vs Final model, Subscription scope, Firewall action, Violations, Redraft latency
- **Reports**
  - Monthly: usage & cost by subscribed model; top violations; % redrafted

## H) Detectors (Firewall) — Implementation Notes

- **Fast path (deterministic):**
  - Regex patterns: phone, email, SSN, credit card (Luhn)
  - Presidio or similar NER for PII
  - Secret scanners: JWT, API key formats (prefix lists, entropy checks)
- **Contextual path (optional):**
  - LLM judge with system prompt: "Does this reply expose private identity or financial details?"
  - Use internal, policy-safe model and cap tokens
- **Performance:**
  - Run deterministic detectors first; only invoke LLM judge if borderline
  - Cache detector results for identical outputs within a run window

## I) Testing Plan (New/Updated)

### 1. Unit
- `filter_by_subscriptions()` (scopes, precedence)
- Recommendation logger
- Firewall detectors: regex/NER/secret patterns
- Redraft prompt: ensures sensitive spans are removed/masked

### 2. Integration
- Scenario: allowed models = {internal, gpt-mini}; recommend internal; fallback to gpt-mini on health down
- Scenario: policy says external OK, but subscription disables external → must pick internal
- Scenario: model returns API key → flag path
- Scenario: model returns SSN → redraft replaces with [REDACTED-SSN]

### 3. Chaos
- Provider throttling → ensure recommended ≠ final (fallback) is recorded
- Firewall LLM judge timeout → degrade to deterministic detectors (still block if regex hits)

### 4. Load
- Ensure firewall adds ≤ 150ms p95 with mixed content (measure with/without LLM judge)

## J) SLOs & Alerts (Additions)

- **Recommendation latency**: ≤ 10 ms p95 (policy eval + filters, in-memory)
- **Firewall overhead:**
  - Deterministic detectors: ≤ 30 ms p95
  - With LLM judge enabled: ≤ 150 ms p95 (configurable; alert on breach)
- **Redraft success rate**: ≥ 99% of flagged outputs are successfully sanitized within one attempt
- **Subscription violations**: 0 requests routed to non-subscribed models (alert if > 0)
- **Audit completeness**: 100% of requests log `recommended_model` AND `final_model`

## K) Security & Compliance Notes

- Subscriptions are allow-lists; default state is deny all until explicitly enabled
- Sanitizing/redraft uses internal or approved models only
- For flag action, never include the original sensitive span in logs or UI; show masked sample (•••1234)
- All firewall incidents are tamper-evident (hash chain optional)

## L) Acceptance Criteria (For These Features)

- ✅ `/v1/predict` returns `route.recommended_model` and `route.final_model`
- ✅ Subscriptions enforce eligibility at tenant/app/team scope with precedence
- ✅ Console pages to manage subscriptions; API endpoints documented
- ✅ Firewall detects PII/secrets via deterministic detectors and (optionally) LLM judge
- ✅ Policy supports `sensitive_output.default_action = flag|redraft|off`
- ✅ Redraft path produces sanitized output using configured sanitizing model, with latency and incident recorded
- ✅ Lineage records recommendation, final route, firewall action, violations
- ✅ Tests cover subscription gating, recommendation logging, firewall (flag + redraft), and fallbacks
- ✅ Dashboards include: % redrafted, top violation types, recommendation→final divergence rate

## M) Developer Snippets

### Subscribe Models (CLI)
```bash
mmctl subscriptions add \
  --scope app --tenant acme-us --app support-bot \
  --models internal-llama,gpt-4o-mini --enabled true
```

### Read Recommendation (SDK)
```python
rec = client.recommend({"app":"support-bot", "context":{"tenant":"acme-us","team":"support","prompt_tokens":80}})
print(rec["recommended_model"], rec["candidates"])
```

### Inspect Safety Result
```python
resp = client.predict({...})
if resp["safety"]["redrafted"]:
    print("Returned sanitized output; violations:", resp["safety"]["violations"])
```

---

This extension keeps your platform's core promise (smart routing + governance) while adding:
- transparent recommendations
- customer-controlled allow-lists (subscriptions)
- a runtime safety firewall that flags or redrafts sensitive outputs

If you want, I can now generate:
- a JSON Schema for the updated Policy YAML (including sensitive_output)
- a Postgres migration for the new tables
- and FastAPI route stubs for Subscriptions + updated /v1/predict
