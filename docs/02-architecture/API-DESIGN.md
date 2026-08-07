# API Design Reference
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** All API endpoints, request/response schemas, versioning strategy, and standards

---

## 1. API Standards

### 1.1 URL Convention
```
/api/v{N}/{service}/{resource}
/api/v{N}/{service}/{resource}/{id}
/api/v{N}/{service}/{resource}/{id}/{sub-resource}
```

### 1.2 HTTP Methods
| Method | Action | Idempotent |
|--------|--------|-----------|
| GET | Read resource(s) | Yes |
| POST | Create resource | No |
| PATCH | Partial update | Yes |
| PUT | Full replace | Yes |
| DELETE | Delete resource | Yes |

### 1.3 Standard Response Envelope

**Success:**
```json
{
  "data": { ... },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-08-04T18:00:00Z",
    "version": "1.0"
  },
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

**Error:**
```json
{
  "data": null,
  "meta": { "request_id": "uuid", "timestamp": "..." },
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": [
      { "field": "priority", "message": "must be one of: emergency, high, medium, low" }
    ]
  }
}
```

### 1.4 Standard HTTP Status Codes
| Status | Meaning |
|--------|---------|
| 200 | OK — GET, PATCH, PUT success |
| 201 | Created — POST success |
| 204 | No Content — DELETE success |
| 207 | Multi-Status — partial success (sync endpoint) |
| 400 | Bad Request — validation error |
| 401 | Unauthorized — missing or invalid JWT |
| 403 | Forbidden — valid JWT but insufficient role |
| 404 | Not Found — resource doesn't exist |
| 409 | Conflict — state conflict (sync) |
| 422 | Unprocessable Entity — semantic validation failure |
| 429 | Too Many Requests — rate limit exceeded |
| 500 | Internal Server Error |

### 1.5 Pagination
All list endpoints support:
```
?page=1&per_page=20
?sort=created_at&order=desc
?filter[status]=open&filter[priority]=emergency
```

---

## 2. Work Order Service API (Go :8081)

### Work Orders

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/workorders` | List work orders (paginated, filterable) | admin, facility_manager, technician |
| POST | `/api/v1/workorders` | Create work order | admin, facility_manager |
| GET | `/api/v1/workorders/{id}` | Get work order details | admin, facility_manager, technician (own) |
| PATCH | `/api/v1/workorders/{id}` | Update work order | admin, facility_manager, technician (own, limited fields) |
| DELETE | `/api/v1/workorders/{id}` | Delete (soft delete, sets status=cancelled) | admin |
| GET | `/api/v1/workorders/{id}/notes` | List notes for a work order | admin, facility_manager, technician |
| POST | `/api/v1/workorders/{id}/notes` | Add note | admin, facility_manager, technician |
| POST | `/api/v1/workorders/{id}/photos` | Upload photo (multipart) | admin, facility_manager, technician |
| GET | `/api/v1/workorders/{id}/photos` | List photos | admin, facility_manager, technician |
| POST | `/api/v1/workorders/{id}/assign` | Assign to technician | admin, facility_manager |
| POST | `/api/v1/workorders/{id}/complete` | Mark complete | admin, facility_manager, technician (own) |
| GET | `/api/v1/workorders/dashboard` | SLA summary statistics | admin, facility_manager |

**POST /api/v1/workorders Request:**
```json
{
  "title": "AC unit not cooling - Level 3",
  "description": "The air conditioning on level 3 is not producing cold air.",
  "category": "hvac",
  "priority": "high",
  "property_id": "uuid",
  "asset_id": "uuid"
}
```

**GET /api/v1/workorders Response (list):**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "AC unit not cooling - Level 3",
      "category": "hvac",
      "priority": "high",
      "status": "in_progress",
      "assigned_to": { "id": "uuid", "name": "James Brown" },
      "sla_response_due": "2026-08-04T20:00:00Z",
      "sla_resolve_due": "2026-08-05T14:00:00Z",
      "sla_response_met": true,
      "sla_resolve_met": null,
      "created_at": "2026-08-04T16:00:00Z",
      "last_modified_at": "2026-08-04T18:00:00Z"
    }
  ],
  "meta": { ... },
  "pagination": { "page": 1, "per_page": 20, "total": 43 }
}
```

### SLA Policies

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/workorders/sla-policies` | List SLA policies |
| PATCH | `/api/v1/workorders/sla-policies/{level}` | Update SLA policy |

### Sync (Desktop Agent)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/sync/workorders` | Push changes from desktop |
| GET | `/sync/workorders?since=ISO8601` | Pull changes since timestamp |
| POST | `/sync/workorders/force` | Force-apply (conflict override) |

### WebSocket

| Path | Description |
|------|-------------|
| `WS /api/v1/workorders/live` | Real-time work order updates stream |

WebSocket message format:
```json
{
  "event": "workorder.status_changed",
  "data": {
    "id": "uuid",
    "status": "complete",
    "changed_by": "user-uuid",
    "changed_at": "2026-08-04T18:00:00Z"
  }
}
```

---

## 3. Asset & CMMS Service API (.NET :8082)

### Properties

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/assets/properties` | List properties | admin, facility_manager |
| POST | `/api/v1/assets/properties` | Create property | admin |
| GET | `/api/v1/assets/properties/{id}` | Property details | admin, facility_manager |
| PATCH | `/api/v1/assets/properties/{id}` | Update property | admin |

### Assets

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/assets` | List assets (filterable by property, category, status) | admin, facility_manager, technician, report_viewer |
| POST | `/api/v1/assets` | Create asset | admin, facility_manager |
| GET | `/api/v1/assets/{id}` | Asset details + PPM history | admin, facility_manager, technician |
| PATCH | `/api/v1/assets/{id}` | Update asset | admin, facility_manager |
| GET | `/api/v1/assets/{id}/ppm-schedules` | List PPM schedules for asset | all read roles |
| POST | `/api/v1/assets/{id}/ppm-schedules` | Create PPM schedule | admin, facility_manager |

### PPM

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/assets/ppm/due` | List PPM tasks due today/this week | admin, facility_manager, technician |
| POST | `/api/v1/assets/ppm/{schedule_id}/complete` | Mark PPM complete | admin, facility_manager, technician |
| GET | `/api/v1/assets/ppm/compliance` | PPM compliance summary | admin, facility_manager, report_viewer |

### Billing

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/assets/billing` | List billing records | admin, billing_admin |
| POST | `/api/v1/assets/billing/generate` | Generate monthly billing run | admin, billing_admin |
| GET | `/api/v1/assets/billing/unit/{unit_number}` | Billing history for a unit | admin, billing_admin, resident (own) |
| PATCH | `/api/v1/assets/billing/{id}` | Update billing record (mark paid etc.) | admin, billing_admin |

---

## 4. Resident Helpdesk API (Python :8083)

### Resident Requests

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/helpdesk/requests` | List all requests | admin, facility_manager |
| POST | `/api/v1/helpdesk/requests` | Submit request | resident, facility_manager, admin |
| GET | `/api/v1/helpdesk/requests/{id}` | Request details | admin, facility_manager, resident (own) |
| PATCH | `/api/v1/helpdesk/requests/{id}` | Update status | admin, facility_manager |
| POST | `/api/v1/helpdesk/requests/{id}/link-workorder` | Link to a work order | admin, facility_manager |

**POST /api/v1/helpdesk/requests Request:**
```json
{
  "category": "maintenance",
  "description": "Leaking tap in bathroom",
  "property_id": "uuid",
  "unit_number": "304"
}
```

### Amenity Bookings

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/helpdesk/amenities` | List amenities | all |
| GET | `/api/v1/helpdesk/amenities/{id}/availability` | Availability calendar | all |
| POST | `/api/v1/helpdesk/bookings` | Create booking | resident, admin, facility_manager |
| GET | `/api/v1/helpdesk/bookings` | List bookings (own for resident) | all |
| DELETE | `/api/v1/helpdesk/bookings/{id}` | Cancel booking | resident (own), admin, facility_manager |

### Surveys

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/helpdesk/surveys` | List surveys | admin, facility_manager |
| POST | `/api/v1/helpdesk/surveys` | Create survey | admin, facility_manager |
| POST | `/api/v1/helpdesk/surveys/{id}/send` | Send to all residents | admin, facility_manager |
| POST | `/api/v1/helpdesk/surveys/{id}/respond` | Submit response | resident |
| GET | `/api/v1/helpdesk/surveys/{id}/results` | Survey results + NLP analysis | admin, facility_manager, report_viewer |

---

## 5. Report Engine API (Ruby :8084)

| Method | Path | Description | Roles |
|--------|------|-------------|-------|
| GET | `/api/v1/reports` | List generated reports | admin, facility_manager, report_viewer |
| POST | `/api/v1/reports/generate` | Generate a report | admin, facility_manager |
| GET | `/api/v1/reports/{id}` | Report metadata + download URL | admin, facility_manager, report_viewer |
| GET | `/api/v1/reports/data/work-orders` | Raw WO data for dashboard widgets | admin, facility_manager, report_viewer |
| GET | `/api/v1/reports/data/ppm-compliance` | PPM compliance data | admin, facility_manager, report_viewer |
| GET | `/api/v1/reports/data/resident-satisfaction` | Satisfaction trend data | admin, facility_manager, report_viewer |
| GET | `/api/v1/reports/data/billing-summary` | Billing collection summary | admin, billing_admin |

**POST /api/v1/reports/generate Request:**
```json
{
  "report_type": "monthly_ops",
  "property_id": "uuid",
  "period": "2026-07",
  "format": "pdf"
}
```

---

## 6. File Upload API (API Gateway :8080)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/files/upload` | Upload a file (multipart) |
| GET | `/files/{file_id}/url` | Get fresh signed download URL |
| DELETE | `/files/{file_id}` | Delete file |

---

## 7. API Versioning Strategy

### Rules
- **v1** is current — all new features added here as non-breaking changes
- A change is **non-breaking** if: adding optional fields, adding new endpoints, loosening validation
- A change is **breaking** if: removing fields, renaming fields, changing field types, removing endpoints, tightening validation
- **Breaking changes** require a **v2 endpoint** — v1 remains functional

### Lifecycle
```
v1 active    → v2 introduced    → v1 deprecated (3 month notice)    → v1 removed
```

### Version Headers
All responses include:
```
X-API-Version: 1.0
X-Deprecated: false   (becomes true when version is deprecated)
```

---

## 8. Common Query Parameters

All list endpoints support these parameters:

| Parameter | Type | Example | Description |
|-----------|------|---------|-------------|
| `page` | int | `?page=2` | Page number (1-indexed) |
| `per_page` | int | `?per_page=50` | Items per page (max: 100) |
| `sort` | string | `?sort=created_at` | Sort field |
| `order` | string | `?order=desc` | Sort direction (asc/desc) |
| `filter[field]` | string | `?filter[status]=open` | Filter by field value |
| `filter[field_from]` | string | `?filter[created_at_from]=2026-01-01` | Range start |
| `filter[field_to]` | string | `?filter[created_at_to]=2026-12-31` | Range end |
| `search` | string | `?search=AC+unit` | Full-text search |
| `include` | string | `?include=notes,photos` | Eager-load related resources |
