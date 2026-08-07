# LLM Council Review — Multi-Language Project Portfolio Plan

> **Subject Under Review:** [MASTER-PROJECT-PLAN.md](file:///c:/Projects/newskillsprojects/docs/MASTER-PROJECT-PLAN.md)
> **Council Convened:** 2026-08-04
> **Context:** User is focusing on **Project 1 (Raymond Gray IFM Platform) first**, has **TeamCity installed** at `C:\TeamCity`, wants **free/local deployment**, and will **not change existing projects** — only add to them.

---

## Stage 1: First Opinions (Divergence)

### 🏗️ Council Member 1: The Enterprise Architect

**Overall Assessment: B+ (Strong foundation, needs practical adjustments)**

**Strengths:**
- The polyglot microservices architecture is sound — each language is matched to its strength area (Go for concurrency, .NET for enterprise CRUD, Python for ML, Ruby for rapid report generation)
- Business domain mapping from the actual RG proposal documents is excellent — not a toy project
- The separation between API Gateway, CMMS, Work Orders, Helpdesk, and Reporting is a clean bounded-context decomposition

**Critical Issues:**

1. **Over-engineering for a solo/small team start.** Five microservices + API gateway + message queue from Day 1 is too much. A solo developer will spend more time on inter-service communication, Docker networking, and deployment plumbing than learning the actual languages. **Recommendation: Start with 2-3 services maximum in Month 1, not 5.**

2. **Missing service communication contracts.** The plan shows services but doesn't specify whether they communicate via REST, gRPC, or events. For a learning project, **REST with OpenAPI specs first** — gRPC adds unnecessary complexity initially.

3. **Database per service is premature.** With 5 services each needing their own PostgreSQL database, schema migrations become a coordination nightmare for one person. **Start with a shared database, separate schemas** — move to isolated DBs when (if) you need to.

4. **The existing RG platform (Next.js + Prisma + Supabase) already has auth, user management, and a data model.** The plan should explicitly define the integration boundary: the new Go/C#/Python services should be called BY the existing Next.js app via API routes, not replace its existing functionality.

5. **Missing: API versioning strategy.** If these services will eventually serve the production RG platform, you need `/api/v1/` from the start with clear deprecation policies.

---

### 🔧 Council Member 2: The DevOps & CI/CD Engineer

**Overall Assessment: B (Good vision, deployment strategy needs rework)**

**Strengths:**
- Docker Compose approach is correct for local multi-service development
- Infrastructure-as-code mindset is present

**Critical Issues:**

1. **TeamCity over GitHub Actions — this is the right call for this project.** The user has TeamCity installed at `C:\TeamCity` (v2022.2.x based on BUILD_222647). TeamCity is *far better* for polyglot builds than GitHub Actions because:
   - It has native build runners for .NET, Java/Maven/Gradle, Go, Python, Ruby — no YAML wrestling
   - It supports build chains (Service A → Service B → Integration Tests) visually
   - Local agent means zero CI/CD cost
   - The free tier supports 100 build configs and 3 build agents — more than enough

   **Recommendation: Use TeamCity as primary CI/CD. Use GitHub Actions only for the Next.js frontend (Vercel auto-deploys from GitHub anyway).**

2. **Deployment strategy needs a complete rethink for "free/local":**

   | Service | Recommended Deployment | Cost |
   |---------|----------------------|------|
   | Next.js Frontend (existing) | **Vercel** (already deployed there) | Free tier |
   | Go API Gateway | **Docker on local machine** or **Fly.io** (3 free machines) | Free |
   | .NET CMMS Service | **Docker locally** or **Azure App Service** (free F1 tier) | Free |
   | Python Helpdesk | **Docker locally** or **Render.com** (free tier, sleeps after 15 min) | Free |
   | Ruby Report Engine | **Docker locally** or **Render.com** | Free |
   | PostgreSQL | **Supabase** (already using) or **Neon** (free tier, 0.5GB) | Free |
   | Redis | **Upstash** (already using per package.json) | Free tier |
   | File Storage | **Supabase Storage** or **Cloudflare R2** (10GB free) | Free |

3. **Docker Compose for local development is the right approach.** One `docker-compose.yml` that spins up ALL services + Postgres + Redis locally. This is where the developer will spend 90% of their time. Production deployment to free tiers is secondary.

4. **TeamCity Build Chain recommended:**
   ```
   ┌─────────────┐     ┌──────────────┐     ┌───────────────┐
   │ Build & Test │ ──► │ Docker Build  │ ──► │ Deploy/Push   │
   │ (per-service)│     │ (per-service) │     │ (per-service) │
   └─────────────┘     └──────────────┘     └───────────────┘
   ```
   Each language gets its own build step with the appropriate TeamCity runner.

5. **Missing: Local development workflow.** The plan should include a `Makefile` or `justfile` with commands like:
   ```
   make up          # docker-compose up all services
   make up-go       # just the Go services
   make up-dotnet   # just the .NET service
   make test-all    # run tests across all services
   make logs        # tail all service logs
   ```

---

### 🧑‍💻 Council Member 3: The Solo Developer Realist

**Overall Assessment: C+ (Ambitious plan will lead to burnout without scope reduction)**

**This is the most important critique.** I'm evaluating this as a solo developer who has to learn Go, C#, Python (FastAPI), Ruby, and Rust essentially from scratch while also delivering working software.

**Critical Issues:**

1. **Month 1 timeline is unrealistic.** The plan says: Month 1 = Go API Gateway + .NET CMMS Service. Learning Go from scratch while also building a production-grade API gateway with JWT, rate limiting, circuit breakers, and gRPC proxying is a 2-month job minimum. Learning .NET/C# simultaneously is madness.

   **Recommendation: Month 1 = Go ONLY. Build a simple API service (not a gateway). Month 2 = .NET ONLY. The "gateway" pattern can be added later when you have multiple services to route to.**

2. **You don't need an API Gateway until you have 3+ services.** A Go API Gateway routing to... one .NET service? Just call the .NET service directly from the Next.js frontend. Add the gateway in Month 3-4 when you actually need routing.

3. **The report engine in Ruby is low priority.** You already generate reports in the existing Next.js platform. Ruby/Rails is a nice-to-learn, but it should be Month 4-5, not Month 3. Instead, prioritize the services that add new capabilities the existing platform doesn't have.

4. **Recommended realistic order for Project 1:**

   | Week | Focus | Language | What You Actually Build |
   |------|-------|----------|----------------------|
   | 1-3 | Go basics | **Go** | Simple REST API — CRUD for work orders, learn HTTP, JSON, PostgreSQL in Go |
   | 4-6 | Go intermediate | **Go** | Add SLA timers (goroutines), WebSocket, Redis pub/sub |
   | 7-9 | .NET basics | **C#** | ASP.NET Core API — CRUD for assets/PPM, learn EF Core, DI |
   | 10-12 | .NET intermediate | **C#** | Background services for PPM scheduling, xUnit tests |
   | 13-15 | Python FastAPI | **Python** | Helpdesk service — async, SQLAlchemy, Celery |
   | 16-18 | Integration | **Go + .NET + Python** | Docker Compose, inter-service calls, shared auth |
   | 19-21 | Ruby | **Ruby** | Report engine with Rails API + Prawn PDF |
   | 22-24 | Polish | **All** | API Gateway (Go), KPI dashboard, TeamCity CI/CD |

   **That's ~6 months for Project 1, not 3.**

5. **Each new language needs a "hello world week."** Before building any real service, spend 3-5 days on:
   - Language tour/basics
   - A trivial CRUD app (todo list)
   - Unit testing setup
   - IDE/editor configuration
   
   This ramp-up time is not accounted for in the original plan.

---

### 💰 Council Member 4: The Financial/Business Analyst

**Overall Assessment: B+ (Strong business mapping, missing commercial viability analysis)**

**Strengths:**
- The direct mapping from RG's actual proposal (KPIs, SLA tiers, pricing models) to software features is outstanding
- The plan correctly identifies that RG needs: CMMS, work orders, helpdesk, reporting, and financial management
- Multi-tenant capability would make this sellable to other FM companies

**Critical Issues:**

1. **The Financial Engine in Rust (Project 3) should NOT be in Project 1 scope.** The RG platform needs basic invoicing and HOA fee tracking, not a full double-entry ledger. Build simple financial features directly into the .NET CMMS service first. The Rust financial engine is a great learning project, but it's a Project 3 item — don't let it block Project 1.

2. **Prioritize by Raymond Gray's actual operational pain points:**
   - **Highest pain:** PPM scheduling that falls through cracks → CMMS service (C#/.NET)
   - **Highest pain:** SLA breach tracking → Work order service (Go)
   - **Medium pain:** Resident request tracking → Helpdesk (Python)
   - **Lower pain:** Report generation → Existing Next.js can do this initially
   - **Lowest pain (for now):** Financial engine → Rust is overkill for MVP

3. **The pricing model from the RG proposal gives us real data to work with:**
   - Forster Park: 9 units × $750/unit/month = $6,750/month total collection
   - IFM fee: $550/unit/month; Reserve fund: $200/unit/month
   - 6-month advance payment model
   
   This should be a simple billing module in the CMMS, not a separate Rust service.

4. **Multi-tenant SaaS opportunity:** If the software manages Forster Park, The Rhombus, Crescent 29, Primrose Place, etc. — each as a separate "property" tenant — this becomes a sellable product. **Design for multi-tenancy from Day 1** (property_id on every table).

---

### 🔒 Council Member 5: The Security Auditor

**Overall Assessment: B (Good awareness, missing critical specifics)**

**Strengths:**
- JWT auth is mentioned
- The existing platform already uses Supabase auth + NextAuth
- Rate limiting is planned for the API gateway

**Critical Issues:**

1. **Auth across polyglot services is the #1 security challenge.** The plan doesn't address: How does the Go service validate the same JWT that the .NET service validates? Options:
   - **Option A (recommended):** Keep Supabase as the auth provider. All services validate Supabase JWTs using the shared JWT secret. Each service has a tiny middleware that validates the token — no auth service needed.
   - **Option B:** Add an auth sidecar/proxy (like OAuth2 Proxy) in front of all services.
   
   **Do NOT build a separate auth service.** Use the existing Supabase auth.

2. **Inter-service communication should be authenticated.** Services calling each other need service-to-service auth (API keys or mTLS). Don't leave internal APIs open — even in Docker Compose, services should verify the caller.

3. **Sensitive data handling:** RG manages residential properties — tenant PII (names, phone numbers, unit numbers), financial data (rent amounts, arrears). GDPR-equivalent considerations apply even in Ghana. **Encrypt PII at rest, log access to sensitive endpoints.**

4. **The existing platform uses `@upstash/ratelimit`** — keep using Upstash Redis for rate limiting in the new services too. Don't introduce a second rate-limiting system.

5. **Photo evidence uploads** (from PPM completions and work orders) need:
   - File type validation (no executable uploads)
   - Size limits
   - Virus scanning (optional but recommended)
   - Signed URL access (not public URLs)

---

## Stage 2: Peer Review (Cross-Examination)

### Architect ↔ Solo Dev Realist

**Architect:** "I agree the timeline is too aggressive. But I disagree with skipping the API Gateway entirely. Even with 2 services, having a single entry point simplifies CORS, auth, and logging."

**Solo Dev:** "Fair point on CORS — but you can solve that with a simple Nginx reverse proxy config, not a custom Go gateway. Build the gateway *in* Go as a learning project in Month 3, not as infrastructure on Day 1."

**Consensus:** Start services directly accessible from the Next.js frontend (via API routes as proxy). Add the Go API Gateway as a learning milestone in Month 3-4, when there are 2-3 services to actually route to.

### DevOps ↔ Business Analyst

**DevOps:** "TeamCity is great for building .NET and Java, but the free tier only supports 100 build configs. With 20+ services across all 5 projects, we'll hit the limit."

**Business Analyst:** "But we're only doing Project 1 first — that's 5 services max. 100 build configs is more than enough. We can revisit when we start Project 2."

**Consensus:** TeamCity for Project 1 is perfect. Revisit limits when expanding.

### Security ↔ Architect

**Security:** "I'm concerned about the shared database approach the Architect recommended. If the Go service has a bug that deletes PPM data in the .NET service's schema, that's catastrophic."

**Architect:** "Valid, but database-per-service for a solo dev means managing 5 separate Postgres instances on free tiers. Use PostgreSQL schemas with restricted database roles — each service gets a role that can only access its own schema."

**Consensus:** Single PostgreSQL instance (Supabase or Neon), multiple schemas with restricted roles. Each service's database user can only read/write its own schema, with explicit cross-schema views for read-only access where needed.

### Solo Dev ↔ DevOps

**Solo Dev:** "The Makefile idea is great, but on Windows, Make is a pain. Use PowerShell scripts or better yet, a `justfile` (cross-platform task runner)."

**DevOps:** "Good call. Or even simpler — put common commands in the `docker-compose.yml` with profiles so `docker compose --profile go up` starts only Go services."

**Consensus:** Use Docker Compose profiles + a simple PowerShell script (`dev.ps1`) for common operations on Windows.

---

## Stage 3: Final Synthesis (Chairman's Report)

### Chairman's Verdict: Plan is STRONG but needs 14 key refinements

The plan demonstrates exceptional business-to-technical mapping and a sound polyglot architecture. However, it needs practical adjustments for a solo developer starting out, proper TeamCity integration, and a realistic timeline.

---

### Refinement 1: CRITICAL — Realistic Timeline for Project 1

**Original:** 3 months for 5 services + API Gateway
**Revised:** 6 months for Project 1, phased as follows:

| Phase | Weeks | Language | Service | Key Learning |
|-------|-------|----------|---------|-------------|
| **Go Foundations** | 1-6 | Go | Work Order & SLA Service | HTTP, JSON, PostgreSQL, goroutines, WebSocket |
| **.NET Foundations** | 7-12 | C# / .NET | Asset & CMMS Service | ASP.NET Core, EF Core, DI, background services |
| **Python Foundations** | 13-18 | Python | Resident Helpdesk | FastAPI, SQLAlchemy, Celery, async |
| **Integration** | 19-21 | Go + .NET + Python | Docker Compose + API Gateway | Inter-service calls, shared auth, Docker |
| **Ruby + Polish** | 22-24 | Ruby | Report Engine + CI/CD | Rails API, Prawn PDF, TeamCity setup |

### Refinement 2: CRITICAL — Start Without API Gateway

Build services that the existing Next.js frontend calls directly (via Next.js API routes as proxy). Add the Go API Gateway as a learning project when you have 3+ backend services to route to (around Week 19).

### Refinement 3: CRITICAL — Use Existing Auth (Supabase)

Do NOT build an auth service. All new Go/.NET/Python services validate the existing Supabase JWT. Each service gets a tiny auth middleware:
- Go: `supabase-go` or manual JWT validation
- .NET: `Microsoft.AspNetCore.Authentication.JwtBearer`
- Python: `python-jose` or `PyJWT`

### Refinement 4: HIGH — TeamCity as Primary CI/CD

Replace GitHub Actions with TeamCity for all backend services:
- **TeamCity Server:** `C:\TeamCity` (already installed)
- **Build Agent:** `C:\TeamCity\buildAgent` (already bundled)
- **Free tier:** 100 build configs, 3 agents — more than enough
- Use GitHub Actions ONLY for the Next.js frontend (Vercel auto-deploy)

TeamCity project structure:
```
Raymond Gray IFM
├── rg-workorder-service (Go build runner)
├── rg-cmms-service (.NET build runner)
├── rg-helpdesk-service (Python build runner)
├── rg-report-engine (Ruby build runner)
├── rg-api-gateway (Go build runner)
└── Integration Tests (Docker Compose runner)
```

### Refinement 5: HIGH — Free Deployment Stack

| Component | Service | Free Tier Details |
|-----------|---------|-------------------|
| Next.js Frontend | **Vercel** (existing) | 100GB bandwidth, serverless functions |
| Go Services | **Fly.io** | 3 free shared-cpu machines, 256MB RAM each |
| .NET Service | **Azure App Service F1** | 60 min/day compute, 1GB RAM |
| Python Service | **Render.com** | Free web service (spins down after 15 min inactivity) |
| Ruby Service | **Render.com** | Same free tier |
| PostgreSQL | **Supabase** (existing) or **Neon** | 0.5GB free |
| Redis | **Upstash** (existing) | 10K commands/day free |
| File Storage | **Supabase Storage** (existing) | 1GB free |
| Docker (local dev) | **Docker Desktop** | Free for personal/education |

**Primary development:** All services run locally via Docker Compose. Free cloud tiers for staging/demo only.

### Refinement 6: HIGH — Single Database, Multiple Schemas

Use ONE PostgreSQL instance (Supabase) with isolated schemas:
```sql
CREATE SCHEMA workorders;   -- Go service
CREATE SCHEMA cmms;          -- .NET service
CREATE SCHEMA helpdesk;      -- Python service
CREATE SCHEMA reports;       -- Ruby service (read-only views of other schemas)

-- Restricted roles
CREATE ROLE svc_workorders LOGIN PASSWORD '...';
GRANT USAGE ON SCHEMA workorders TO svc_workorders;
GRANT ALL ON ALL TABLES IN SCHEMA workorders TO svc_workorders;
-- Read-only access to cmms assets (for work order assignment)
GRANT USAGE ON SCHEMA cmms TO svc_workorders;
GRANT SELECT ON cmms.assets, cmms.properties TO svc_workorders;
```

### Refinement 7: HIGH — Preserve Existing Projects

**Principle:** New services live in `C:\Projects\newskillsprojects\` as separate folders. The existing `raymond-gray-platform` is NOT modified until the new services are proven and operational.

**Integration approach:** The existing Next.js app calls new services via its own API routes (acting as BFF — Backend for Frontend):
```
Next.js API Route (/api/workorders) 
  → calls Go Work Order Service (localhost:8081 or Fly.io URL)
  → returns data to the React frontend
```
This way the frontend doesn't change — it just gets new API routes that delegate to the new services.

### Refinement 8: MEDIUM — Financial Features Stay Simple

No Rust financial engine in Project 1. Basic invoicing (HOA fee tracking, payment status per unit) goes directly into the .NET CMMS service. The Rust financial engine is Project 3 — to be started after Project 1 is operational.

### Refinement 9: MEDIUM — Each Language Gets a Ramp-Up Week

Before building any production service in a new language, spend 3-5 days on:
1. Official language tour (go.dev/tour, learn.microsoft.com, etc.)
2. Build a trivial CRUD API (todo list)
3. Set up IDE/editor (VS Code extensions, debugging)
4. Write and run unit tests
5. Set up the TeamCity build runner for that language

### Refinement 10: MEDIUM — Docker Compose Profiles

```yaml
# docker-compose.yml structure
services:
  postgres:
    profiles: ["infra", "all"]
  redis:
    profiles: ["infra", "all"]
  workorder-service:
    profiles: ["go", "all"]
  cmms-service:
    profiles: ["dotnet", "all"]
  helpdesk-service:
    profiles: ["python", "all"]
  report-engine:
    profiles: ["ruby", "all"]
  api-gateway:
    profiles: ["go", "all"]
```
Commands:
```powershell
docker compose --profile infra --profile go up    # Just Go + deps
docker compose --profile all up                    # Everything
```

### Refinement 11: MEDIUM — Windows Development Tooling

Add a `dev.ps1` PowerShell script to the root:
```powershell
# dev.ps1
param([string]$Command)
switch ($Command) {
    "up"       { docker compose --profile all up -d }
    "up-go"    { docker compose --profile infra --profile go up -d }
    "up-dotnet"{ docker compose --profile infra --profile dotnet up -d }
    "down"     { docker compose down }
    "logs"     { docker compose logs -f }
    "test"     { # run tests per-service }
    "tc-start" { & "C:\TeamCity\bin\teamcity-server.bat" start }
}
```

### Refinement 12: MEDIUM — Multi-Tenancy from Day 1

Every table in every schema includes `property_id` as a mandatory column. This supports:
- Forster Park (9 units)
- The Rhombus
- Crescent 29
- Primrose Place
- Future properties

Row-Level Security (RLS) via PostgreSQL or application-level filtering.

### Refinement 13: LOW — API Documentation Standard

All services expose OpenAPI/Swagger specs:
- Go: `swaggo/swag`
- .NET: Built-in Swagger (Swashbuckle)
- Python: FastAPI auto-generates OpenAPI
- Ruby: `rswag` gem

Specs are committed to `shared/contracts/` for cross-service reference.

### Refinement 14: LOW — Monitoring (Add After Integration Phase)

Don't set up Prometheus/Grafana/ELK from Day 1. Use:
- **Phase 1-3:** Docker Compose logs + structured JSON logging
- **Phase 4 (Integration):** Add Prometheus + Grafana via Docker Compose
- **Production:** Consider Grafana Cloud free tier (10K metrics, 50GB logs)

---

### Priority Matrix

| Priority | Refinement | Impact |
|----------|-----------|--------|
| 🔴 CRITICAL | #1 Realistic 6-month timeline | Prevents burnout |
| 🔴 CRITICAL | #2 No API Gateway on Day 1 | Reduces complexity |
| 🔴 CRITICAL | #3 Use existing Supabase auth | No wheel reinvention |
| 🟠 HIGH | #4 TeamCity CI/CD | Free, powerful, already installed |
| 🟠 HIGH | #5 Free deployment stack | Zero cost |
| 🟠 HIGH | #6 Single DB, multiple schemas | Simpler ops |
| 🟠 HIGH | #7 Preserve existing projects | No regressions |
| 🟡 MEDIUM | #8 Simple financials (no Rust in P1) | Focus |
| 🟡 MEDIUM | #9 Language ramp-up weeks | Realistic learning |
| 🟡 MEDIUM | #10 Docker Compose profiles | Dev ergonomics |
| 🟡 MEDIUM | #11 Windows dev tooling | Quality of life |
| 🟡 MEDIUM | #12 Multi-tenancy from Day 1 | Future-proofing |
| 🟢 LOW | #13 API documentation standard | Consistency |
| 🟢 LOW | #14 Monitoring after integration | Right timing |
