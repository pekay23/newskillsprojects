# Multi-Language Project Portfolio — Master Plan

> **Goal:** Learn 10+ programming languages by building **real, commercial software** for Raymond Gray IFM, Aerojet Aviation Training Academy, and supporting systems — all interconnected through shared services.

> [!NOTE]
> **Project 1 (Raymond Gray IFM)** has its own comprehensive, canonical plan at **[PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)**. That document supersedes the Project 1 sections below for all architecture, technology, and implementation details. This file remains the overarching portfolio-level vision covering all 5 projects.

---

## Your Current Position

| Asset | Status |
|-------|--------|
| **TypeScript/Next.js/React** | Expert — [raymond-gray-platform](file:///c:/Projects/raymond-gray-platform), [aerojet-academy](file:///c:/Projects/aerojet-academy), 6+ deployed projects |
| **Python** | Intermediate — ML, scripting, security |
| **Prisma/PostgreSQL** | Solid — production databases |
| **Existing RG Platform** | Next.js + Prisma + Supabase — website & basic management |
| **Existing Aerojet Academy** | Next.js + Prisma — aviation training portal |

**What's missing:** Backend diversity (Go, .NET, Java, Ruby, Rust), systems programming (C, C++), native mobile (Swift, Kotlin), and enterprise architecture patterns.

---

## The Master Architecture — 5 Interconnected Project Systems

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        PROJECT 1: RAYMOND GRAY IFM PLATFORM                 │
│  Full facility management SaaS — the flagship commercial product            │
│  Languages: Go · C#/.NET · Python · Ruby · TypeScript/React                 │
└──────────┬───────────────────────────────────┬───────────────────────────────┘
           │                                   │
           ▼                                   ▼
┌──────────────────────────┐    ┌──────────────────────────────────────────────┐
│  PROJECT 2: AEROJET      │    │  PROJECT 3: FINOPS FINANCIAL SUITE           │
│  AVIATION ACADEMY        │    │  Shared financial engine for all projects    │
│  Languages: Java · .NET  │    │  Languages: Rust · Go · Java · Python · C++ │
│  · Python · Go           │    │                                              │
└──────────┬───────────────┘    └──────────┬───────────────────────────────────┘
           │                               │
           ▼                               ▼
┌──────────────────────────┐    ┌──────────────────────────────────────────────┐
│  PROJECT 4: FIELD OPS    │    │  PROJECT 5: ANALYTICS & INTELLIGENCE HUB    │
│  MOBILE PLATFORM         │    │  Data pipeline, ML, predictive maintenance  │
│  Languages: Swift ·      │    │  Languages: Python · R · Go · Ruby · Rust   │
│  Kotlin · C · C++ · Dart │    │                                              │
└──────────────────────────┘    └──────────────────────────────────────────────┘
```

---

## PROJECT 1: Raymond Gray IFM Platform (The Flagship)

### Business Context (from [RG Proposal](file:///C:/Users/Pekay/OneDrive%20-%20Ghana%20Communication%20Technology%20University/Raymond%20Gray/Docs/RG_Residential_FM_Proposal_2026.pdf))

Raymond Gray manages 6+ active residential contracts, 60+ properties at peak, offering:
- **Hard Services:** PPM scheduling, asset registers, MEP maintenance
- **Soft Services:** Cleaning, security, landscaping, waste
- **Financial:** HOA fee collection, vendor invoicing, budgeting, reserve funds
- **Resident Experience:** Helpdesk, satisfaction surveys, amenity booking
- **Rental Management:** Tenant sourcing, lease management, rent collection
- **Compliance:** HSE, fire safety, statutory compliance
- **Reporting:** Monthly operations, quarterly reviews, annual asset surveys

### Architecture — Polyglot Microservices

```
┌──────────────────────────────────────────────────────────────────┐
│                    WEB FRONTEND (TypeScript/React)               │
│  Client Dashboard · Resident Portal · Admin Console             │
│  You already know this — extend your existing RG platform       │
└──────────────────────────┬───────────────────────────────────────┘
                           │ REST / gRPC / WebSocket
┌──────────────────────────▼───────────────────────────────────────┐
│                 API GATEWAY (Go)                                  │
│  Rate limiting · JWT validation · Request routing · Load balance │
│  Health checks · Circuit breaker · Request logging               │
└───┬──────────┬──────────┬──────────┬──────────┬─────────────────┘
    │          │          │          │          │
┌───▼────┐ ┌──▼────┐ ┌───▼────┐ ┌──▼─────┐ ┌─▼──────────┐
│ .NET   │ │  Go   │ │ Python │ │  Ruby  │ │  Rust      │
│ C#     │ │       │ │        │ │        │ │            │
│        │ │ Work  │ │ Resi-  │ │ Report │ │ Financial  │
│ Asset  │ │ Order │ │ dent   │ │ Engine │ │ Engine     │
│ & CMMS │ │ & PPM │ │ Help-  │ │        │ │ (from      │
│ Svc    │ │ Svc   │ │ desk   │ │        │ │ Project 3) │
└───┬────┘ └──┬────┘ └───┬────┘ └──┬─────┘ └─┬──────────┘
    │         │          │         │          │
┌───▼─────────▼──────────▼─────────▼──────────▼────────────┐
│              DATA LAYER                                    │
│  PostgreSQL (primary) · Redis (cache/pub-sub)             │
│  RabbitMQ (async tasks) · S3/MinIO (documents/photos)     │
└───────────────────────────────────────────────────────────┘
```

### Service Breakdown — What You Build & Learn

#### 1. API Gateway — **Go**
**What:** Central entry point for all client requests
**Learn:**
- `net/http`, `chi` or `gin` router
- JWT middleware, rate limiting
- gRPC proxying, circuit breaker pattern
- Prometheus metrics, structured logging
- Docker containerization

**Key endpoints:**
```
/api/v1/properties/*     → routes to .NET Asset Service
/api/v1/workorders/*     → routes to Go Work Order Service
/api/v1/helpdesk/*       → routes to Python Resident Helpdesk
/api/v1/reports/*        → routes to Ruby Report Engine
/api/v1/finance/*        → routes to Rust Financial Engine
```

---

#### 2. Asset & CMMS Service — **C# / .NET**
**What:** Asset register, equipment lifecycle, PPM scheduling, compliance tracking
**Maps to RG operations:** *"All PPM tasks scheduled, assigned and tracked digitally. Every task has a due date, assigned technician, completion timestamp and photo evidence."*

**Learn:**
- ASP.NET Core Web API, EF Core (Code First + Migrations)
- Dependency injection, repository pattern
- xUnit testing, FluentValidation
- Background services (PPM schedule generator)
- Swagger/OpenAPI documentation

**Data model highlights:**
```csharp
// Example entities
Property { Id, Name, Address, Type, Units, HOA_Board }
Asset { Id, PropertyId, Category, Make, Model, SerialNo, InstallDate, WarrantyExpiry, Condition }
PPMSchedule { Id, AssetId, TaskDescription, Frequency, NextDueDate, AssignedTechnicianId }
PPMCompletion { Id, ScheduleId, CompletedAt, TechnicianId, PhotoEvidence[], Notes, Status }
ComplianceRecord { Id, PropertyId, Type, InspectionDate, ExpiryDate, CertificateUrl }
```

**KPIs this service powers:**
- PPM schedule compliance ≥ 95%
- Generator/utility uptime ≥ 99.5%
- Asset condition scoring

---

#### 3. Work Order & Reactive Maintenance Service — **Go**
**What:** Reactive maintenance requests, SLA tracking, technician dispatch, resolution workflow
**Maps to RG operations:** *"All reactive requests logged, triaged and closed. Automated SLA timers flag breaches before they become client issues."*

**Learn:**
- Go concurrency: goroutines for SLA timer monitoring
- Channels for real-time notifications
- GORM or sqlx for PostgreSQL
- WebSocket for live updates to dashboard
- Redis pub/sub for cross-service events

**SLA tiers (from proposal):**
```go
var SLATiers = map[string]time.Duration{
    "emergency":  1 * time.Hour,   // ≤ 1 hour on-site
    "priority_1": 24 * time.Hour,  // ≤ 4-24 hours
    "priority_2": 72 * time.Hour,  // ≤ 72 hours
    "routine":    168 * time.Hour, // ≤ 7 days
}
```

**Key features:**
- Work order lifecycle: Created → Triaged → Assigned → In Progress → Completed → Verified
- SLA breach prediction (warns before breaching)
- Technician location tracking & dispatch optimization
- Photo evidence upload & verification
- Full audit trail

---

#### 4. Resident Helpdesk & Satisfaction Service — **Python (FastAPI)**
**What:** Resident request portal, satisfaction surveys, communication, amenity booking
**Maps to RG operations:** *"Residents log requests digitally. Every request tracked from submission to resolution. Monthly satisfaction scores captured automatically."*

**Learn:**
- FastAPI with async/await
- SQLAlchemy ORM, Alembic migrations
- Celery for async tasks (email notifications, survey scheduling)
- NLP for sentiment analysis on feedback (spaCy/transformers)
- WebSocket for real-time chat

**Key features:**
- Resident self-service portal (request logging, status tracking)
- Monthly satisfaction surveys with automated scoring
- Amenity booking (pool, gym, lounge)
- Community notices & announcements
- Resident communication log
- Sentiment trend analysis

---

#### 5. Report Engine — **Ruby (Rails API)**
**What:** Monthly operations reports, quarterly reviews, annual asset reports, KPI dashboards
**Maps to RG operations:** *Monthly, quarterly, annual, and ad-hoc reporting framework*

**Learn:**
- Ruby on Rails API mode
- ActiveRecord, migrations
- Background jobs (Sidekiq)
- PDF generation (Prawn gem)
- Template engine for report layouts
- REST API design in Ruby

**Report types (from proposal):**
```ruby
# Monthly Operations Report
# — PPM completion & reactive log
# — SLA compliance scorecard
# — Resident satisfaction score
# — Utility & incident status

# Quarterly Performance Review
# — KPI scorecard vs. targets
# — Trend analysis
# — Capital works planning
# — Budget vs. actual

# Annual Asset Review
# — Full asset condition report
# — Lifecycle planning
# — Annual budget forecast
```

---

### Raymond Gray KPI Dashboard (Real-time)

From the proposal, the live dashboard must display:

| KPI | Target | Frequency |
|-----|--------|-----------|
| Emergency response time | ≤ 1 hour on-site | Real-time |
| Priority 1 fault resolution | ≤ 4–24 hours | Monthly |
| Priority 2 fault resolution | ≤ 72 hours | Monthly |
| PPM schedule compliance | ≥ 95% monthly | Monthly |
| Resident satisfaction score | ≥ 4.0 / 5.0 | Monthly |
| Common area presentation audit | ≥ 98% pass rate | Weekly |
| Generator / utility uptime | ≥ 99.5% | Monthly |
| Rent collection rate (Model B) | ≥ 98% of rent due | Monthly |

---

## PROJECT 2: Aerojet Aviation Training Academy System

### Business Context
Aviation training management covering EASA Part-66 modules, student lifecycle, instructor management, and regulatory compliance.

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                WEB PORTAL (TypeScript/React)                     │
│  Student Portal · Instructor Dashboard · Admin · Exam Center    │
│  Extend your existing aerojet-academy project                   │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│              CORE BACKEND (Java / Spring Boot)                   │
│  Student enrollment · Module tracking · Scheduling · Compliance │
│  ───────────────────────────────────────────────────────────     │
│  LEARN: Spring Boot, Maven, JPA/Hibernate, Spring Security,     │
│  REST, Bean Validation, Spring Batch (report generation)        │
└───┬──────────┬──────────┬───────────────────────────────────────┘
    │          │          │
┌───▼────┐ ┌──▼─────┐ ┌──▼──────────┐
│  .NET  │ │ Python │ │    Go       │
│  Exam  │ │ ML &   │ │ Notifica-  │
│ Engine │ │ Analy- │ │ tion Svc   │
│ & Cert │ │ tics   │ │ (email,    │
│        │ │        │ │ SMS, push) │
└────────┘ └────────┘ └────────────┘
```

### Service Breakdown

#### Core Academic Service — **Java / Spring Boot**
**Learn:** Spring Boot, Maven/Gradle, JPA/Hibernate, Spring Security, REST controllers, Bean Validation, Spring Batch

**Key modules:**
- **Student Management:** Enrollment, profiles, cohorts, attendance, progression
- **EASA Part-66 Module Tracking:** Module completion, grades, prerequisites, certification readiness
- **Instructor Management:** Qualifications, availability, scheduling, load balancing
- **Timetable & Scheduling:** Class schedules, room allocation, instructor assignment
- **Flight Hours Logging:** Practical training hours, simulator time, instructor sign-off

#### Exam Engine — **C# / .NET**
**Learn:** Blazor or ASP.NET Core, SignalR for real-time exam proctoring, EF Core

**Key features:**
- Question bank management (MCQ, essay, practical assessment)
- Timed exam sessions with anti-cheat
- Auto-grading for MCQ, manual grading workflow
- Certificate generation (PDF)
- EASA compliance reporting

#### Analytics & Predictions — **Python**
- Student performance prediction (who's at risk of failing?)
- Optimal scheduling using constraint satisfaction
- Attendance pattern analysis
- Cost-per-student analytics

#### Notification Service — **Go**
- Email (SMTP), SMS (Twilio/Hubtel), Push notifications
- Event-driven: enrollment confirmations, exam reminders, grade releases
- Template engine for multi-channel messages

---

## PROJECT 3: FinOps Financial Management Suite

### Why a Separate Financial System?

Both Raymond Gray and Aerojet need robust financial operations:
- **RG:** HOA fee collection, vendor invoicing, reserve fund management, per-unit charging ($550–$750/unit/month)
- **Aerojet:** Tuition billing, installment plans, instructor payroll

Building this as a **shared, multi-tenant financial engine** means you write it once and both platforms consume it.

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│              FINANCIAL ENGINE CORE (Rust)                         │
│  Double-entry ledger · Transaction processing · Currency         │
│  ─────────────────────────────────────────────────────────       │
│  LEARN: Rust ownership, error handling, serde, actix-web,        │
│  diesel ORM, decimal precision, financial data integrity         │
└───┬──────────┬──────────┬───────────────────────────────────────┘
    │          │          │
┌───▼─────┐ ┌─▼────────┐ ┌▼───────────┐
│  Go     │ │  Java    │ │  Python    │
│ Payment │ │ Invoic-  │ │ Budget     │
│ Gateway │ │ ing &    │ │ Forecast   │
│ Proxy   │ │ Billing  │ │ & Tax      │
└─────────┘ └──────────┘ └────────────┘
```

#### Financial Engine — **Rust**
**What:** Core double-entry accounting ledger, transaction integrity, multi-currency
**Learn:** Ownership/borrowing, Result/Option, `actix-web`, `diesel`, `rust_decimal`, testing

**Why Rust:** Financial calculations demand correctness — Rust's type system prevents entire categories of bugs (no null, no data races, precise decimal handling).

**Features:**
- Double-entry ledger (every transaction has debit + credit)
- Multi-tenant: isolate RG properties, Aerojet, etc.
- Reserve fund tracking (per the RG pricing proposal: $200/unit/month ringfenced)
- Audit trail (immutable transaction log)
- Currency support (GHS, USD)

#### Payment Gateway Proxy — **Go**
- Integration with MTN Mobile Money, Vodafone Cash, bank transfers
- Stripe/PayPal for international
- Webhook handling, retry logic, reconciliation
- PCI compliance considerations

#### Invoicing & Billing — **Java**
- Recurring invoice generation (monthly service charges)
- Payment plan management (Aerojet tuition installments)
- Arrears tracking and automated reminders
- PDF invoice generation

#### Budget Forecasting — **Python**
- Annual budget vs. actual tracking
- Capital works programme costing
- Cash flow forecasting
- Tax computation helpers

---

## PROJECT 4: Field Operations Mobile Platform

### Architecture

```
┌────────────────────────┐  ┌────────────────────────┐
│   iOS App (Swift)      │  │  Android App (Kotlin)  │
│   SwiftUI · CoreData   │  │  Jetpack Compose       │
│   AVFoundation (camera)│  │  CameraX · Room DB     │
│   Offline-first sync   │  │  Offline-first sync    │
└───────────┬────────────┘  └───────────┬────────────┘
            │                           │
            ▼                           ▼
┌───────────────────────────────────────────────────────┐
│             SYNC SERVER (Go)                           │
│   Conflict resolution · Delta sync · Push triggers    │
└───────────────────────┬───────────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────────┐
│           IoT GATEWAY (C / C++)                        │
│   ESP32 sensor data collection · MQTT broker           │
│   Building monitoring: temp, humidity, power, water    │
│   ──────────────────────────────────────────────       │
│   LEARN: C sockets, MQTT protocol, embedded concepts,  │
│   C++ for data aggregation & protocol parsing          │
└───────────────────────────────────────────────────────┘
```

#### iOS App — **Swift**
**Learn:** SwiftUI, CoreData, URLSession, Combine, AVFoundation
- Technician work order execution
- Photo evidence capture with GPS tagging
- Barcode/QR scanning for asset identification
- Offline work order completion + sync
- Push notifications for new assignments

#### Android App — **Kotlin**
**Learn:** Jetpack Compose, Room, Retrofit, CameraX, Coroutines
- Same features as iOS — different language, same backend
- Material Design 3 components

#### IoT Gateway — **C / C++**
**Learn:** C sockets, MQTT, embedded programming concepts, C++ OOP
- Simulated building sensors (temperature, humidity, power usage, water flow)
- MQTT message broker integration
- Data aggregation and forwarding to cloud
- Alert generation (e.g., power outage, water leak, temperature anomaly)

> [!TIP]
> Even without physical hardware, you can simulate IoT sensors in C/C++ that generate realistic data and communicate via MQTT — this teaches the same skills.

---

## PROJECT 5: Analytics & Intelligence Hub

### Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                   DATA PIPELINE (Python)                           │
│   ETL from all services · pandas · data cleaning · scheduling     │
└───────────────────────┬────────────────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────────────────┐
│              STREAM PROCESSOR (Go)                                  │
│   Kafka/Redis streams · real-time aggregation · event sourcing    │
└───────────────────────┬────────────────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────────────────┐
│              ML MODELS (Python)                                     │
│   Predictive maintenance · Anomaly detection · NLP sentiment      │
│   ─────────────────────────────────────────────────────────        │
│   scikit-learn · TensorFlow · spaCy · prophet (forecasting)       │
└───────────────────────┬────────────────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────────────────┐
│          STATISTICAL ANALYSIS (R)                                   │
│   LEARN: R language, tidyverse, ggplot2, statistical testing      │
│   Warranty claim analysis · lifecycle cost modeling                │
└───────────────────────┬────────────────────────────────────────────┘
                        │
┌───────────────────────▼────────────────────────────────────────────┐
│         HIGH-PERFORMANCE COMPUTATION (Rust)                        │
│   Large dataset processing · parallel analysis · data export      │
└────────────────────────────────────────────────────────────────────┘
```

**ML use cases for Raymond Gray:**
- **Predictive Maintenance:** Predict equipment failure before it happens (based on PPM history, asset age, environmental data)
- **Anomaly Detection:** Spot unusual patterns in utility consumption, work order volumes
- **NLP Sentiment Analysis:** Auto-analyze resident feedback for satisfaction trends
- **Budget Forecasting:** Predict capital expenditure needs

**ML use cases for Aerojet:**
- **Student Risk Prediction:** Identify students likely to fail based on attendance, grades, engagement
- **Optimal Scheduling:** Constraint satisfaction for timetable generation
- **Pass Rate Analysis:** Which teaching methods produce better outcomes?

---

## Language Coverage Summary

| # | Language | Projects Used In | What You Learn |
|---|----------|-----------------|----------------|
| 1 | **TypeScript/React** | All (frontends) | Already expert — extend skills |
| 2 | **Go** | P1 (API Gateway, Work Orders), P2 (Notifications), P3 (Payments), P4 (Sync Server), P5 (Streaming) | Concurrency, microservices, CLI tools |
| 3 | **C# / .NET** | P1 (CMMS), P2 (Exam Engine), P3 (part of billing) | Enterprise patterns, EF Core, DI |
| 4 | **Java** | P2 (Core Academic), P3 (Invoicing) | Spring Boot, JPA, enterprise |
| 5 | **Python** | P1 (Helpdesk), P2 (Analytics), P3 (Forecasting), P5 (ML Pipeline) | FastAPI, ML, data science |
| 6 | **Ruby** | P1 (Report Engine) | Rails, rapid development |
| 7 | **Rust** | P3 (Financial Engine), P5 (HPC) | Safety, performance, type system |
| 8 | **Swift** | P4 (iOS App) | Native iOS, SwiftUI |
| 9 | **Kotlin** | P4 (Android App) | Native Android, Compose |
| 10 | **C** | P4 (IoT Gateway) | Systems programming, embedded |
| 11 | **C++** | P4 (IoT Data Aggregation) | OOP, performance |
| 12 | **R** | P5 (Statistical Analysis) | Statistics, data science |
| 13 | **SQL** | All projects | Advanced queries, optimization |

**Total: 13 languages across 5 interconnected projects**

---

## 12-Month Phased Roadmap

### Phase 1: Foundation (Months 1–3)
> Build the core services that everything else depends on

| Month | Project | Component | Language | Deliverable |
|-------|---------|-----------|----------|-------------|
| 1 | P1 | API Gateway | **Go** | Working gateway with JWT auth, routing, rate limiting |
| 1 | P1 | Asset & CMMS Service | **C# / .NET** | Asset register CRUD, PPM schedule creation |
| 2 | P1 | Work Order Service | **Go** | Work order lifecycle, SLA timers, WebSocket updates |
| 2 | P3 | Financial Engine (core) | **Rust** | Double-entry ledger, transaction processing |
| 3 | P1 | Resident Helpdesk | **Python** | Request portal, satisfaction surveys, basic NLP |
| 3 | P1 | Frontend Dashboard | **TypeScript** | KPI dashboard connecting to all services |

### Phase 2: Expansion (Months 4–6)
> Add the second major system and financial capabilities

| Month | Project | Component | Language | Deliverable |
|-------|---------|-----------|----------|-------------|
| 4 | P2 | Core Academic Service | **Java** | Student enrollment, module tracking, scheduling |
| 4 | P3 | Payment Gateway | **Go** | Mobile Money + card integration |
| 5 | P2 | Exam Engine | **C# / .NET** | Question bank, timed exams, auto-grading |
| 5 | P3 | Invoicing & Billing | **Java** | Recurring invoices, arrears tracking |
| 6 | P1 | Report Engine | **Ruby** | Monthly/quarterly/annual reports with PDF generation |
| 6 | P2 | Notification Service | **Go** | Multi-channel notifications |

### Phase 3: Mobile & IoT (Months 7–9)
> Learn native mobile development and systems programming

| Month | Project | Component | Language | Deliverable |
|-------|---------|-----------|----------|-------------|
| 7 | P4 | iOS Technician App | **Swift** | Work orders, photo evidence, offline sync |
| 7 | P4 | Sync Server | **Go** | Offline-first sync with conflict resolution |
| 8 | P4 | Android Technician App | **Kotlin** | Same features as iOS |
| 8 | P4 | IoT Gateway (simulated) | **C / C++** | MQTT sensor data, alerts |
| 9 | P4 | Integration | All | End-to-end: sensor → alert → work order → mobile app |

### Phase 4: Intelligence & Polish (Months 10–12)
> Add ML, analytics, and production hardening

| Month | Project | Component | Language | Deliverable |
|-------|---------|-----------|----------|-------------|
| 10 | P5 | Data Pipeline | **Python** | ETL from all services into analytics warehouse |
| 10 | P5 | Stream Processor | **Go** | Real-time event aggregation |
| 11 | P5 | ML Models | **Python** | Predictive maintenance, sentiment analysis |
| 11 | P5 | Statistical Analysis | **R** | Warranty analysis, lifecycle cost modeling |
| 12 | All | Production Hardening | All | Docker Compose, CI/CD, monitoring, load testing |
| 12 | P5 | HPC Processing | **Rust** | High-performance batch analysis |

---

## Infrastructure & DevOps (Across All Projects)

```
┌─────────────────────────────────────────────────────────┐
│  CONTAINERIZATION: Docker + Docker Compose               │
│  Each service = 1 container, all orchestrated together  │
├─────────────────────────────────────────────────────────┤
│  CI/CD: GitHub Actions                                   │
│  Build → Test → Lint → Deploy per-service               │
├─────────────────────────────────────────────────────────┤
│  DATABASES: PostgreSQL (per-service DBs) + Redis        │
├─────────────────────────────────────────────────────────┤
│  MESSAGING: RabbitMQ (async tasks) or Redis Streams     │
├─────────────────────────────────────────────────────────┤
│  MONITORING: Prometheus + Grafana (metrics)             │
│  LOGGING: ELK Stack or Loki (centralized logs)          │
│  TRACING: OpenTelemetry (distributed tracing)           │
├─────────────────────────────────────────────────────────┤
│  DEPLOYMENT: Railway / Fly.io / DigitalOcean            │
└─────────────────────────────────────────────────────────┘
```

---

## Team Collaboration Structure

If working with a team, here's how to divide:

| Developer | Primary Languages | Ownership |
|-----------|------------------|-----------|
| **You (Lead)** | TypeScript, Go, Python | Architecture, API Gateway, Frontend, Data Pipeline |
| **Dev 2** | C#/.NET, Java | CMMS, Exam Engine, Academic Service, Invoicing |
| **Dev 3** | Rust, C/C++ | Financial Engine, IoT Gateway, HPC |
| **Dev 4** | Swift, Kotlin | iOS and Android mobile apps |
| **Dev 5** | Ruby, Python, R | Report Engine, Helpdesk, Analytics, ML |

---

## Project Directory Structure

```
C:\Projects\newskillsprojects\
├── rg-api-gateway/              # Go — API Gateway
├── rg-cmms-service/             # C#/.NET — Asset & CMMS
├── rg-workorder-service/        # Go — Work Orders & PPM
├── rg-helpdesk-service/         # Python — Resident Helpdesk
├── rg-report-engine/            # Ruby — Reporting
├── aerojet-academic-service/    # Java — Core Academic
├── aerojet-exam-engine/         # C#/.NET — Exam System
├── aerojet-notifications/       # Go — Notification Service
├── finops-ledger/               # Rust — Financial Engine
├── finops-payments/             # Go — Payment Gateway
├── finops-invoicing/            # Java — Invoicing
├── finops-forecasting/          # Python — Budget Forecasting
├── fieldops-ios/                # Swift — iOS App
├── fieldops-android/            # Kotlin — Android App
├── fieldops-sync-server/        # Go — Sync Server
├── fieldops-iot-gateway/        # C/C++ — IoT Gateway
├── analytics-pipeline/          # Python — ETL Pipeline
├── analytics-stream/            # Go — Stream Processor
├── analytics-ml/                # Python — ML Models
├── analytics-stats/             # R — Statistical Analysis
├── analytics-hpc/               # Rust — High-Performance
├── infrastructure/              # Docker, CI/CD, monitoring
│   ├── docker-compose.yml
│   ├── .github/workflows/
│   └── monitoring/
└── shared/
    ├── proto/                   # gRPC protobuf definitions
    ├── docs/                    # API docs, architecture decisions
    └── contracts/               # OpenAPI specs, shared types
```

---

## User Review Required

> [!IMPORTANT]
> **Scope Decision:** This plan covers 5 major project systems with 20+ individual services. We should decide:
> 1. **Start with Project 1 (Raymond Gray IFM) only?** — This alone covers Go, .NET, Python, Ruby, and TypeScript.
> 2. **Start with Projects 1 + 3 (RG + FinOps)?** — Adds Rust and Java.
> 3. **Go all-in from Month 1?** — All 5 projects in parallel (team recommended).

> [!IMPORTANT]
> **Existing Code:** Your [raymond-gray-platform](file:///c:/Projects/raymond-gray-platform) is already a Next.js + Prisma app. Should we:
> - **A)** Keep it as the frontend and build the new backend services behind it?
> - **B)** Rebuild the frontend fresh alongside the new backend?
> - **C)** Gradually migrate the existing monolith to microservices?

## Open Questions

> [!WARNING]
> 1. **Deployment target:** Where will these run? Self-hosted (DigitalOcean/Hetzner), cloud PaaS (Railway/Fly.io), or on-premise for RG?
> 2. **Mobile priority:** Is the iOS/Swift and Android/Kotlin learning a high priority, or would you prefer to use **Flutter/Dart** (one codebase, two platforms) or **Capacitor** (which you already know)?
> 3. **Hardware/IoT:** For Project 4's IoT component — do you have access to ESP32/Raspberry Pi hardware, or should we design this as a pure software simulation?
> 4. **Team:** Are you building solo or do you have team members? This affects the timeline significantly.
> 5. **Which project should we build first?** I recommend starting with **P1: Raymond Gray IFM** → specifically the **Go API Gateway** as your first service (Month 1, Week 1).

## Verification Plan

### Automated Tests
- Each service has unit tests in its native language (xUnit, go test, pytest, RSpec, cargo test)
- Integration tests via Docker Compose (spin up all services, run end-to-end)
- API contract tests (OpenAPI spec validation)

### Manual Verification
- Deploy to staging environment
- Run through Raymond Gray operational workflows end-to-end
- Test offline mobile sync
- Load test with simulated multi-property data
