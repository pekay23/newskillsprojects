# CI/CD Pipeline Reference
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** TeamCity build configurations, Docker pipeline steps, environment secrets, and deployment procedures

---

## 1. TeamCity Overview

TeamCity is installed at `C:\TeamCity`. Each service has its own **Build Configuration** in a shared **Raymond Gray IFM** project.

### Project Structure in TeamCity

```
Raymond Gray IFM
├── rg-workorder-service
├── rg-cmms-service
├── rg-helpdesk-service
├── rg-report-engine
├── rg-api-gateway
├── rg-sync-agent
├── rg-fieldops-mobile
└── _Infrastructure
    ├── deploy-all (triggers all services)
    └── refresh-views (runs Neon materialized view refresh)
```

---

## 2. Shared Environment Variables (TeamCity Project Parameters)

These are defined at the **project level** and inherited by all build configurations:

| Parameter | Value (Secret) | Used By |
|-----------|---------------|---------|
| `env.NEON_URL` | `postgresql://...@neon.tech/...?sslmode=require` | All services |
| `env.REDIS_URL` | `redis://localhost:6379` | Go, Python services |
| `env.MINIO_ENDPOINT` | `http://localhost:9000` | All services |
| `env.MINIO_ACCESS_KEY` | `<secret>` | All services |
| `env.MINIO_SECRET_KEY` | `<secret>` | All services |
| `env.SUPABASE_JWT_SECRET` | `<secret>` | API Gateway |
| `env.SUPABASE_PROJECT_URL` | `https://<project>.supabase.co` | API Gateway |
| `env.DOCKER_REGISTRY` | `localhost:5000` (local) | All services |

---

## 3. Build Configuration: Go Work Order Service

**VCS Root:** `C:\Projects\newskillsprojects\rg-workorder-service`

### Build Steps

| # | Step Name | Runner | Command |
|---|-----------|--------|---------|
| 1 | Lint | Command Line | `go vet ./... && golangci-lint run` |
| 2 | Test | Go | `go test ./... -race -coverprofile=coverage.out` |
| 3 | Coverage Gate | Command Line | `go tool cover -func=coverage.out | grep total | awk '{print $3}' | cut -d'%' -f1 | awk '{if($1<70) exit 1}'` |
| 4 | Build Binary | Go | `go build -o bin/server ./cmd/server` |
| 5 | Docker Build | Command Line | `docker build -t %env.DOCKER_REGISTRY%/rg-workorder:%build.number% .` |
| 6 | Docker Push | Command Line | `docker push %env.DOCKER_REGISTRY%/rg-workorder:%build.number%` |

### Triggers
- VCS trigger on push to `main` branch (path: `rg-workorder-service/**`)
- Nightly scheduled build (2am) for dependency updates check

---

## 4. Build Configuration: .NET CMMS Service

**VCS Root:** `C:\Projects\newskillsprojects\rg-cmms-service`

### Build Steps

| # | Step Name | Runner | Command |
|---|-----------|--------|---------|
| 1 | Restore | .NET CLI | `dotnet restore` |
| 2 | Build | .NET CLI | `dotnet build --no-restore --configuration Release` |
| 3 | Test | .NET CLI | `dotnet test --no-build --configuration Release --logger trx` |
| 4 | Publish | .NET CLI | `dotnet publish --no-build --configuration Release -o ./publish` |
| 5 | Docker Build | Command Line | `docker build -t %env.DOCKER_REGISTRY%/rg-cmms:%build.number% .` |
| 6 | Docker Push | Command Line | `docker push %env.DOCKER_REGISTRY%/rg-cmms:%build.number%` |

### Artifacts
- `**/*.trx` — test results (TeamCity NUnit format)
- `coverage/` — code coverage report

---

## 5. Build Configuration: Python Helpdesk Service

**VCS Root:** `C:\Projects\newskillsprojects\rg-helpdesk-service`

### Build Steps

| # | Step Name | Runner | Command |
|---|-----------|--------|---------|
| 1 | Install | Command Line | `pip install -r requirements.txt` |
| 2 | Lint | Command Line | `ruff check app/ && mypy app/` |
| 3 | Test | Command Line | `pytest tests/ --cov=app --cov-report=xml -v` |
| 4 | Docker Build | Command Line | `docker build -t %env.DOCKER_REGISTRY%/rg-helpdesk:%build.number% .` |
| 5 | Docker Push | Command Line | `docker push %env.DOCKER_REGISTRY%/rg-helpdesk:%build.number%` |

---

## 6. Build Configuration: Ruby Report Engine

**VCS Root:** `C:\Projects\newskillsprojects\rg-report-engine`

### Build Steps

| # | Step Name | Runner | Command |
|---|-----------|--------|---------|
| 1 | Bundle Install | Command Line | `bundle install` |
| 2 | Lint | Command Line | `bundle exec rubocop` |
| 3 | Test | Command Line | `bundle exec rspec --format documentation` |
| 4 | Docker Build | Command Line | `docker build -t %env.DOCKER_REGISTRY%/rg-reports:%build.number% .` |
| 5 | Docker Push | Command Line | `docker push %env.DOCKER_REGISTRY%/rg-reports:%build.number%` |

---

## 7. Build Configuration: Go API Gateway

Same as rg-workorder-service build steps, targeting `rg-api-gateway/`.

---

## 8. Build Configuration: Go Sync Agent (Cross-Compile)

The sync agent is compiled to native binaries for Windows and macOS:

| # | Step Name | Command |
|---|-----------|---------|
| 1 | Test | `go test ./...` |
| 2 | Build Windows x64 | `GOOS=windows GOARCH=amd64 go build -o bin/rg-sync-agent-windows-x64.exe ./main.go` |
| 3 | Build macOS ARM64 | `GOOS=darwin GOARCH=arm64 go build -o bin/rg-sync-agent-darwin-arm64 ./main.go` |
| 4 | Archive | TeamCity Artifact: `bin/rg-sync-agent-*` |

Binaries are published as TeamCity artifacts and bundled into the desktop app installers.

---

## 9. Build Configuration: Mobile App (Flutter / Expo EAS)

### Flutter Build (if Flutter chosen)

| # | Step Name | Command |
|---|-----------|---------|
| 1 | Get packages | `flutter pub get` |
| 2 | Analyze | `flutter analyze` |
| 3 | Test | `flutter test` |
| 4 | Build Android | `flutter build apk --release` |
| 5 | Build iOS (via Codemagic API) | Trigger Codemagic CI via REST API |

### Expo EAS Build (if React Native chosen)

| # | Step Name | Command |
|---|-----------|---------|
| 1 | Install | `npm ci` |
| 2 | Type Check | `npx tsc --noEmit` |
| 3 | Test | `npm test -- --watchAll=false` |
| 4 | EAS Build Android | `npx eas build --platform android --non-interactive` |
| 5 | EAS Build iOS | `npx eas build --platform ios --non-interactive` |

---

## 10. Docker Compose — Full Stack

```yaml
# infrastructure/docker-compose.yml
version: '3.9'

networks:
  rg-network:
    driver: bridge

services:
  api-gateway:
    image: ${DOCKER_REGISTRY}/rg-api-gateway:latest
    ports: ["8080:8080"]
    environment:
      - SUPABASE_PROJECT_URL=${SUPABASE_PROJECT_URL}
      - SUPABASE_JWT_SECRET=${SUPABASE_JWT_SECRET}
      - WORKORDER_URL=http://workorder:8081
      - CMMS_URL=http://cmms:8082
      - HELPDESK_URL=http://helpdesk:8083
      - REPORTS_URL=http://reports:8084
      - REDIS_URL=${REDIS_URL}
    networks: [rg-network]
    depends_on:
      workorder: { condition: service_healthy }
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  workorder:
    image: ${DOCKER_REGISTRY}/rg-workorder:latest
    ports: ["8081:8081"]
    environment:
      - NEON_URL=${NEON_URL}
      - REDIS_URL=${REDIS_URL}
      - MINIO_ENDPOINT=${MINIO_ENDPOINT}
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
    networks: [rg-network]
    depends_on:
      redis: { condition: service_healthy }
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  cmms:
    image: ${DOCKER_REGISTRY}/rg-cmms:latest
    ports: ["8082:8082"]
    environment:
      - NEON_URL=${NEON_URL}
      - MINIO_ENDPOINT=${MINIO_ENDPOINT}
    networks: [rg-network]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8082/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  helpdesk:
    image: ${DOCKER_REGISTRY}/rg-helpdesk:latest
    ports: ["8083:8083"]
    environment:
      - NEON_URL=${NEON_URL}
      - REDIS_URL=${REDIS_URL}
    networks: [rg-network]
    depends_on:
      redis: { condition: service_healthy }
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8083/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  reports:
    image: ${DOCKER_REGISTRY}/rg-reports:latest
    ports: ["8084:8084"]
    environment:
      - NEON_URL=${NEON_URL}
      - MINIO_ENDPOINT=${MINIO_ENDPOINT}
    networks: [rg-network]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8084/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes:
      - redis-data:/data
    networks: [rg-network]
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"    # API
      - "9001:9001"    # Console
    environment:
      - MINIO_ROOT_USER=${MINIO_ACCESS_KEY}
      - MINIO_ROOT_PASSWORD=${MINIO_SECRET_KEY}
    volumes:
      - minio-data:/data
    networks: [rg-network]
    command: server /data --console-address ":9001"

  mosquitto:
    image: eclipse-mosquitto:2
    ports:
      - "1883:1883"
      - "9002:9001"   # WebSocket
    volumes:
      - ./infrastructure/mosquitto/mosquitto.conf:/mosquitto/config/mosquitto.conf
      - mosquitto-data:/mosquitto/data
    networks: [rg-network]

volumes:
  redis-data:
  minio-data:
  mosquitto-data:
```

---

## 11. Desktop App Release Pipeline

The desktop app (`rg-desktop-windows/`) uses **GitHub Actions** for automated releases, separate from the TeamCity pipeline used for backend services.

### 11.1 Trigger

Push a version tag to trigger the release:

```bash
git tag v1.1.0
git push origin v1.1.0
```

### 11.2 Workflow Steps (`.github/workflows/desktop-release.yml`)

| # | Step | Command |
|---|------|---------|
| 1 | Checkout | `actions/checkout@v4` |
| 2 | Setup Node.js | `actions/setup-node@v4` (Node 20) |
| 3 | Setup Rust | `dtolnay/rust-toolchain@stable` |
| 4 | Setup MSVC | `ilammy/msvc-dev-cmd@v1` |
| 5 | Install deps | `npm ci` |
| 6 | Type check | `npx tsc --noEmit` |
| 7 | Build frontend | `npm run build` |
| 8 | Build Tauri bundle | `npm run tauri build` |
| 9 | Generate `latest.json` | PowerShell script |
| 10 | Create GitHub Release | `softprops/action-gh-release@v2` |

### 11.3 Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `TAURI_SIGNING_PRIVATE_KEY` | Tauri signing private key |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | Key password (if set) |

### 11.4 Manual Release

```powershell
.\scripts\release.ps1 -Version "1.1.0" -SigningKey "C:\path\to\myapp.key"
```

### 11.5 Client Update Flow

1. App checks `latest.json` on GitHub Releases
2. Compares version vs installed version
3. Downloads installer if newer
4. Verifies signature against embedded public key
5. Installs passively → relaunches

---

## 12. Deployment Procedure

### 12.1 Standard Deployment

```powershell
# 1. Pull latest images
docker compose pull

# 2. Apply database migrations (run per service, in order)
docker compose exec workorder migrate up
docker compose exec cmms dotnet ef database update
docker compose exec helpdesk alembic upgrade head
docker compose exec reports rails db:migrate

# 3. Rolling restart (zero downtime)
docker compose up -d --no-deps --build workorder
docker compose up -d --no-deps --build cmms
# etc.

# 4. Verify health
docker compose ps
curl http://localhost:8080/health
```

### 12.2 Rollback

```powershell
# Tag images with build number → rollback = re-deploy previous tag
docker compose pull
# Edit docker-compose.yml to pin previous build number tag
docker compose up -d
```

### 12.3 Environment Files

```
C:\Projects\newskillsprojects\infrastructure\
├── .env                 # Production secrets (NOT committed to Git)
├── .env.dev             # Development overrides (committed with dev defaults)
└── .env.example         # Template (committed — shows all required variables)
```

`.env.example` (committed to Git):
```bash
NEON_URL=postgresql://user:password@project.neon.tech/db?sslmode=require
REDIS_URL=redis://localhost:6379
MINIO_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
SUPABASE_PROJECT_URL=https://yourproject.supabase.co
SUPABASE_JWT_SECRET=your-jwt-secret
DOCKER_REGISTRY=localhost:5000
```
