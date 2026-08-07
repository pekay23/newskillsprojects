# Technology Alternatives Reference
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** Evaluated alternatives for every technology choice, with trade-off analysis and migration effort

---

## 1. How to Read This Document

Each section covers a technology category. For each:
- **Current Choice** — what the platform uses and why
- **Alternatives** — evaluated options ranked by suitability
- **Migration Effort** — what it takes to switch (Config Only / Low / Medium / High)

**Config Only** = change an env variable or config file  
**Low** = change a library/SDK import, same API pattern  
**Medium** = rewrite a service layer or abstraction  
**High** = architectural redesign required

---

## 2. Cloud Database

### Current: Neon PostgreSQL

**Why chosen:** Serverless PostgreSQL, scale-to-zero, branching for dev/staging, standard wire protocol, free tier sufficient for PoC.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **Supabase PostgreSQL** | Managed PG | Built-in auth, storage, realtime | Vendor lock-in for extras, pricing per project | Config Only (same PG protocol) |
| **CockroachDB Serverless** | Distributed SQL | Multi-region, survives node failure | PG-compatible but not identical, higher latency for single-region | Low (some SQL dialect differences) |
| **PlanetScale** | Managed MySQL | Branching, great DX | MySQL not PostgreSQL — all schemas rewritten | High |
| **AWS RDS PostgreSQL** | Managed PG | Mature, full PG features | No scale-to-zero, always-on billing | Config Only |
| **Google Cloud SQL** | Managed PG | Same as RDS | Same as RDS | Config Only |
| **Self-hosted PostgreSQL** | Docker or bare metal | Full control, no vendor | Operational overhead (backups, upgrades, HA) | Config Only |

### Recommendation
Neon is the best choice for a solo developer building with AI agents. If Neon becomes too expensive or limiting at enterprise scale, migrate to **RDS** or **self-hosted PostgreSQL** — zero application code changes needed.

---

## 3. Local Embedded Database

### Current: SQLite

**Why chosen:** Most widely deployed database engine in the world. Universal compatibility (Windows, macOS, Linux, mobile). Zero-configuration. Single-file database. Excellent Go, .NET, Python, and Ruby driver support.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **LiteDB** | .NET NoSQL file DB | Native .NET, document model | .NET-only — no Go driver, no cross-platform parity | Medium |
| **DuckDB** | Analytical embedded DB | Excellent for analytics queries | Not designed for OLTP workloads (insert/update heavy) | Medium |
| **Realm** | Mobile-first embedded DB | Built-in sync (MongoDB Atlas), reactive | Proprietary sync protocol, vendor lock-in | High |
| **PouchDB/CouchDB** | Document DB with sync | Built-in replication protocol | JavaScript-only (browser/Node), document model | High |
| **Turso (libSQL)** | SQLite fork with sync | Built-in edge replication | Newer project, smaller ecosystem | Low (SQLite compatible) |

### Recommendation
SQLite is the correct choice. If built-in sync becomes important, **Turso (libSQL)** is the most seamless upgrade — it's a SQLite fork with added replication, and existing SQLite databases can be imported directly.

---

## 4. Authentication

### Current: Supabase Auth (auth-only, database moved to Neon)

**Why chosen:** Already integrated with the existing Next.js app. Handles OAuth, email/password, session management, and JWT issuance. Mature and battle-tested.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **Neon Auth (Stack Auth)** | Neon-integrated | Same vendor as DB, reduces dependencies | Newer feature, less mature | Low (update JWKS URL in Gateway) |
| **Keycloak** | Self-hosted OIDC/SAML | Enterprise-grade, LDAP/AD support, full control | Complex to operate, Java-based, heavy | Medium (new auth flow, same JWT pattern) |
| **Auth.js (NextAuth)** | Next.js library | Tight Next.js integration, many providers | No standalone user management UI | Medium |
| **Lucia** | Lightweight auth library | Minimal, session-based, works with any DB | Lower-level, more custom code | Medium |
| **Clerk** | Managed auth SaaS | Beautiful pre-built UI, easy setup | SaaS pricing, vendor dependency | Low (JWT compatible) |
| **Firebase Auth** | Google managed | Reliable, free tier generous | Google ecosystem dependency | Low (JWT compatible) |
| **AWS Cognito** | AWS managed | Enterprise, SAML/OIDC | Complex API, AWS lock-in | Medium |

### Recommendation
Keep Supabase Auth for now. When ready to consolidate vendors, **Neon Auth** is the natural migration — same project, same JWT pattern, only the JWKS endpoint URL changes in the API Gateway.

---

## 5. File Storage

### Current: MinIO (self-hosted, S3-compatible)

**Why chosen:** S3-compatible API means zero lock-in. Self-hosted means full control and no egress fees. Runs in Docker alongside other services.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **Cloudflare R2** | Cloud S3-compatible | No egress fees, global CDN | Cloud dependency | Config Only (change endpoint) |
| **AWS S3** | Cloud reference S3 | Most mature, richest feature set | Egress fees, AWS dependency | Config Only (change endpoint) |
| **Backblaze B2** | Cloud S3-compatible | Cheapest storage ($5/TB) | Less feature-rich | Config Only (change endpoint) |
| **Supabase Storage** | Cloud managed | Already available if using Supabase | Tied to Supabase project | Low (different SDK) |
| **Google Cloud Storage** | Cloud | Uniform/fine-grained ACL | GCP dependency, egress fees | Config Only (S3 interop) |

### Recommendation
MinIO for on-premise. When scaling to cloud, **Cloudflare R2** is the best target — S3-compatible (same SDK), zero egress fees, global edge distribution.

---

## 6. Message Queue / Pub-Sub

### Current: Redis pub/sub + Redis Streams

**Why chosen:** Redis is already in the stack for caching and SLA timers. pub/sub adds no new infrastructure. Simple, fast, and sufficient for the expected event volume.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **RabbitMQ** | Dedicated message broker | Durable queues, routing, DLQ | New infrastructure, more complex | Medium |
| **NATS** | Lightweight message system | Extremely fast, Go-native, JetStream for persistence | Less ecosystem tooling | Medium |
| **Apache Kafka** | Distributed event log | Massive throughput, event sourcing | Heavy, complex, overkill for this scale | High |
| **AWS SQS/SNS** | Managed queue/topic | Serverless, managed | AWS dependency, latency | Medium |
| **Upstash Kafka** | Serverless Kafka | Serverless, REST API | Cloud dependency | Medium |

### Recommendation
Stay with Redis pub/sub. If durable message queuing becomes necessary (e.g., guaranteed delivery for billing events), add **NATS JetStream** — it's lightweight, Go-native, and runs easily in Docker.

---

## 7. API Gateway

### Current: Custom Go API Gateway

**Why chosen:** Lightweight, fast, and gives full control over JWT validation, routing, sync endpoints, and rate limiting. Written in the same language as the primary services.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **Kong** | Open-source gateway | Plugin ecosystem, admin API, enterprise support | Heavier, Lua-based plugins | Medium |
| **Traefik** | Cloud-native reverse proxy | Auto service discovery, Docker/K8s native | Less customizable for sync endpoints | Medium |
| **Nginx** | Reverse proxy | Battle-tested, high performance | Config-file based, less dynamic | Low (can sit in front of Go gateway) |
| **AWS API Gateway** | Managed | Serverless, managed | AWS lock-in, latency, no sync endpoint logic | High |
| **Envoy** | Service mesh proxy | gRPC native, observability | Complex config, overkill at this scale | High |

### Recommendation
The custom Go gateway is the right choice. It hosts the sync endpoint logic which is custom to this platform. Use **Nginx or Traefik** in front of it for TLS termination and load balancing when scaling.

---

## 8. Mobile Framework

### Current: Flutter (planned)

**Why chosen:** Single codebase for iOS and Android. Dart is productive. Builds can run on Windows. Native performance. Growing ecosystem.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **React Native (Expo)** | JS/TS cross-platform | JavaScript familiarity (same as Next.js), Expo EAS for cloud builds | Performance slightly lower than Flutter, larger bundle | High (different language) |
| **.NET MAUI** | .NET cross-platform | Same language as CMMS service (C#) | Less mature mobile ecosystem, limited community | High |
| **Kotlin Multiplatform** | Shared logic, native UI | Native performance, shared business logic | Kotlin learning curve, early ecosystem | High |
| **PWA (Progressive Web App)** | Web-based | No app store, instant updates | Limited offline, no native APIs (camera, NFC) | Medium |

### Recommendation
Flutter is the primary recommendation. If JavaScript/TypeScript consistency is preferred (matching the Next.js frontend), **React Native with Expo** is the alternative — EAS handles iOS builds from Windows.

---

## 9. Desktop Framework

### Current: Tauri (Rust backend + React frontend)

**Why chosen:** Lightweight (~10 MB installer vs ~100 MB Electron). Uses system WebView (no bundled Chromium). Rust backend provides excellent SQLite integration via `rusqlite`. Cross-platform (Windows + macOS).

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **WPF (.NET 8)** | Windows-native | Deep Windows integration, same .NET as CMMS | Windows-only, no macOS support | High |
| **Electron** | Chromium + Node | Largest ecosystem, easiest JS integration | Heavy (~100 MB), high memory usage | Medium |
| **WinUI 3** | Modern Windows | Modern Windows look, MSIX packaging | Windows-only | High |
| **.NET MAUI Desktop** | .NET cross-platform | C# familiar, cross-platform | Less mature desktop support | Medium |
| **Qt** | C++ cross-platform | Mature, native performance | C++ complexity, licensing | High |

### Recommendation
Tauri for cross-platform. If macOS support isn't needed, **WPF (.NET 8)** is a strong Windows-only alternative that reuses C# skills from the CMMS service.

---

## 10. PDF Report Generation

### Current: Prawn (Ruby gem, in Report Engine)

**Why chosen:** Ruby-native, programmatic PDF generation, good for structured reports with tables and charts.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **WeasyPrint** (Python) | HTML → PDF | Write reports as HTML/CSS, render to PDF | Requires Python, heavy dependencies | Medium (move report gen to Python service) |
| **Puppeteer/Playwright** (Node) | Headless browser → PDF | Full HTML/CSS/JS rendering | Heavy (needs Chrome headless), slow | Medium |
| **wkhtmltopdf** | WebKit → PDF | Lightweight, fast | Deprecated, security concerns | Low |
| **gotenberg** | Docker PDF microservice | Language-agnostic, REST API | Additional Docker container | Low |
| **IronPDF (.NET)** | .NET PDF library | Commercial, full-featured | Paid license, .NET only | Medium |

### Recommendation
Prawn is correct for structured reports. If richer visual reports are needed (charts, branded layouts), add **Gotenberg** as a Docker sidecar — it accepts HTML and returns PDF via REST API, usable by any service.

---

## 11. IoT Protocol

### Current: MQTT (Eclipse Mosquitto broker)

**Why chosen:** De facto standard for IoT. Lightweight, low bandwidth, supports QoS levels. Mosquitto is battle-tested and runs in Docker.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **AMQP (RabbitMQ)** | Enterprise messaging | Richer routing, durable | Heavier than MQTT for IoT | Medium |
| **CoAP** | Constrained devices | UDP-based, extremely lightweight | Less tooling, limited broker options | High |
| **HTTP polling** | REST | Simple, familiar | High overhead, not real-time | Low but architecturally inferior |
| **gRPC streaming** | Binary RPC | High performance, typed | Overkill for sensor telemetry | Medium |
| **NATS** | Lightweight messaging | Can replace both MQTT and Redis pub/sub | Different protocol, less IoT ecosystem | Medium |

### Recommendation
MQTT is the correct choice for IoT. Mosquitto is lightweight and battle-tested. If a unified messaging layer is desired (replacing both Redis pub/sub and MQTT), consider **NATS** in a future consolidation.

---

## 12. CI/CD Runner

### Current: TeamCity (self-hosted at C:\TeamCity)

**Why chosen:** Already installed and available. Supports Go, .NET, Python, Ruby build runners. Free Professional tier.

| Alternative | Type | Pros | Cons | Migration |
|------------|------|------|------|-----------|
| **GitHub Actions** | Cloud CI | YAML-based, huge marketplace, free for public repos | Cloud dependency, limited free minutes for private | Medium (rewrite build configs to YAML) |
| **Jenkins** | Self-hosted | Most extensible, huge plugin ecosystem | Old UI, Groovy pipelines, maintenance burden | Medium |
| **GitLab CI** | Self-hosted or cloud | Integrated with GitLab, Docker-native | Requires GitLab for best experience | Medium |
| **Drone CI** | Self-hosted, Docker-native | Lightweight, container-native pipelines | Smaller community | Medium |
| **Buildkite** | Hybrid (cloud control, self-hosted agents) | Fast, scalable, modern | Paid for teams | Medium |

### Recommendation
TeamCity is already running and works. No reason to migrate unless moving to cloud-hosted source control (GitHub/GitLab), at which point **GitHub Actions** or **GitLab CI** would be natural.
