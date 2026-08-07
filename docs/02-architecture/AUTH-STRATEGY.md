# Authentication & Authorization Strategy
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** Complete auth architecture, RBAC matrix, JWT flow, and migration alternatives

---

## 1. Auth Architecture Decision

**MIGRATED (2026-08-06): NextAuth v5 (JWT strategy) is now the primary auth, backed by Neon PostgreSQL via Prisma. Supabase is secondary/optional.**

The original `raymond-gray-platform` migrated from Supabase auth to **NextAuth v5** with a JWT session strategy:

- NextAuth v5 uses Credentials provider (login tokens) and signs session JWTs with `NEXTAUTH_SECRET` (HS256)
- User data (roles, status, `app_metadata`) lives in Neon PostgreSQL via Prisma — `DATABASE_URL` is the required env var, `NEXT_PUBLIC_SUPABASE_URL` is optional
- The API gateway (`rg-api-gateway`) validates **NextAuth JWTs** (HS256 with `NEXTAUTH_SECRET`), not Supabase JWKS
- Supabase remains available but is no longer required for auth

---

## 2. JWT Flow

### 2.1 Token Structure

Supabase issues JWTs with the following claims:
```json
{
  "sub": "user-uuid",                    // User ID (primary identifier across all services)
  "email": "user@example.com",
  "role": "authenticated",
  "app_metadata": {
    "roles": ["facility_manager"],       // Application roles array
    "property_id": "property-uuid"       // Primary property assignment
  },
  "aud": "authenticated",
  "exp": 1234567890,
  "iat": 1234567890
}
```

### 2.2 API Gateway JWT Validation

The Go API Gateway validates every inbound request:

```go
// Startup: fetch and cache Supabase JWKS
// SUPABASE_PROJECT_URL + "/.well-known/jwks.json"
// Cache for 1 hour, re-fetch on key rotation (kid mismatch)

// Per-request:
// 1. Extract Bearer token from Authorization header
// 2. Parse JWT header → get kid
// 3. Fetch matching key from JWKS cache
// 4. Verify signature using RSA public key
// 5. Verify aud, exp, iss claims
// 6. Extract sub, email, app_metadata.roles, app_metadata.property_id
// 7. Forward as headers to downstream service:
//    X-User-ID: <sub>
//    X-User-Email: <email>
//    X-User-Roles: <comma-separated roles>
//    X-User-Property: <property_id>
```

### 2.3 Service-Level Auth

Each downstream service trusts the headers from the API Gateway (the gateway is the only entry point):
```go
// Go service example
userID := r.Header.Get("X-User-ID")
roles  := strings.Split(r.Header.Get("X-User-Roles"), ",")

// Check role
if !contains(roles, "facility_manager") && !contains(roles, "admin") {
    http.Error(w, "Forbidden", http.StatusForbidden)
    return
}
```

---

## 3. Role-Based Access Control (RBAC)

### 3.1 Role Definitions

| Role | Who Has It | Description |
|------|-----------|-------------|
| `admin` | Platform administrator | Full access to all properties and all features |
| `facility_manager` | Property manager | Full access to their assigned property |
| `technician` | Maintenance staff | Limited to own work orders |
| `resident` | Unit residents | Helpdesk, own bookings, own billing only |
| `report_viewer` | Executive / auditor | Reports read-only |
| `billing_admin` | Finance team | Billing read/write, no operational access |

### 3.2 Permissions Matrix

| Feature | admin | facility_manager | technician | resident | report_viewer | billing_admin |
|---------|-------|-----------------|-----------|---------|--------------|--------------|
| Create Work Order | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View All Work Orders | ✅ | ✅ (own property) | ✅ (own only) | ❌ | ✅ | ❌ |
| Update Work Order | ✅ | ✅ | ✅ (own, status only) | ❌ | ❌ | ❌ |
| Delete Work Order | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Manage Assets | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View Assets | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| PPM Schedules | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| Mark PPM Complete | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Submit Helpdesk Request | ✅ | ✅ | ❌ | ✅ (own unit) | ❌ | ❌ |
| View All Helpdesk | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| Book Amenity | ✅ | ✅ | ❌ | ✅ (own unit) | ❌ | ❌ |
| Manage Billing | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| View Own Billing | ✅ | ✅ | ❌ | ✅ (own unit) | ❌ | ✅ |
| View Reports | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| Manage Users | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Force Sync Override | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### 3.3 Property Scoping

For multi-property scenarios, `facility_manager` and `resident` roles are scoped to a `property_id` from the JWT. All queries in services filter by `property_id` from `X-User-Property` header to prevent cross-property data leakage.

---

## 4. auth_bridge Schema (Neon)

Rather than calling Supabase at runtime to resolve user names and roles, all services query the `auth_bridge.users` table in Neon. This table is populated/updated on each user login via a Next.js API route:

```typescript
// pages/api/auth/[...nextauth].ts (or Supabase auth hook)
// After successful Supabase login:
await db.query(`
  INSERT INTO auth_bridge.users (id, email, full_name, role, property_id, unit_number, synced_at)
  VALUES ($1, $2, $3, $4, $5, $6, NOW())
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    property_id = EXCLUDED.property_id,
    synced_at = NOW()
`, [user.id, user.email, user.full_name, user.role, user.property_id, user.unit_number]);
```

---

## 5. Desktop App Authentication

The desktop sync agent needs a valid JWT to call the sync API. Flow:

```
1. User logs into desktop app (React/Tauri UI)
2. App calls Supabase Auth REST API (same credentials as web)
3. Supabase returns access_token (JWT) + refresh_token
4. Desktop app stores tokens securely:
   - Windows: Windows Credential Manager (via keytar or Windows.Security.Credentials)
   - macOS: Keychain (via keytar)
5. Sync agent reads access_token from secure store
6. On token expiry: agent calls Supabase refresh endpoint with refresh_token
7. Agent updates stored access_token
```

---

## 6. Auth Migration Alternatives

If Supabase Auth is dropped in a future phase, these are the evaluated alternatives:

### Option A: Neon Auth (Recommended Future Migration)
- Neon now offers built-in authentication (Stack Auth integration)
- Same Neon project → reduced vendor count
- OAuth providers + email/password support
- Migration: update JWKS URL + JWT claims mapping in API Gateway only
- **No application code changes required in services**

### Option B: Keycloak (Self-Hosted)
- Enterprise-grade identity provider
- Full SAML 2.0, OIDC, LDAP/Active Directory integration
- Run as Docker container
- More complex to operate but offers full control
- Use case: if Raymond Gray has an existing Active Directory

### Option C: Auth.js (formerly NextAuth) + Custom JWT
- Tightly integrated with Next.js
- Store user sessions in Neon (no Supabase dependency at all)
- More custom code required (no pre-built user management UI)
- Best choice if going fully self-hosted with no external auth dependency

---

## 7. API Security Checklist

| Control | Implementation |
|---------|---------------|
| JWT validation | API Gateway validates on every request |
| HTTPS only | TLS 1.3 enforced by Nginx/Traefik in front of Gateway |
| Rate limiting | Per-user: 1000 req/min, Per-IP: 5000 req/min |
| Input validation | Each service validates request body (Go: validator, .NET: FluentValidation, Python: Pydantic) |
| SQL injection | Parameterised queries only (pgx, EF Core, SQLAlchemy all handle this) |
| CORS | API Gateway allows only known origins (Next.js app domain) |
| Secrets management | All secrets in `.env` files; never committed to Git; injected by TeamCity |
| Audit logging | Every state-changing request logged with user_id, action, timestamp |
