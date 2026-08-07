# Storage Strategy
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** File and photo storage architecture, upload flows, offline queuing, and backend alternatives

---

## 1. Core Principle

> **Photos and documents are NEVER stored as BLOBs in SQLite or in the database.**  
> The database (Neon or SQLite) stores only the **file path/reference**.  
> The actual binary data lives in MinIO (or equivalent S3-compatible store).

This keeps the database lean, the sync payload small, and the storage backend swappable.

---

## 2. Storage Architecture

```
Field Technician captures photo (mobile or desktop camera)
│
▼
Local device temp file (e.g., C:\Temp\rg_photo_abc123.jpg)
│
▼
[ONLINE PATH]                          [OFFLINE PATH]
│                                       │
▼                                       ▼
POST /files/upload                  Store in _pending_uploads (SQLite)
  streams to MinIO                  { local_file_path, target_bucket,
  returns { file_id, url }            target_key, entity, entity_id }
│                                       │
▼                                       ▼ (when online)
Store url in Neon                   Sync agent uploads to MinIO
  work_order_photo.file_path           marks _pending_uploads.uploaded_at
│                                       │
└──────────────────┬────────────────────┘
                   │
                   ▼
          File available on MinIO
          Reference available in Neon
```

---

## 3. Upload API

### Endpoint: `POST /files/upload`

**Request** (multipart/form-data):
```
Content-Type: multipart/form-data
Authorization: Bearer <jwt>

Fields:
  entity: "work_order"
  entity_id: "uuid"
  field: "photo"               // what kind of file
  file: <binary>
```

**Processing:**
```
1. API Gateway receives multipart upload
2. Streams directly to MinIO (no disk buffering on server)
3. MinIO stores at: {bucket}/{property_id}/{entity}/{entity_id}/{timestamp}_{filename}
4. Server generates thumbnail for image files (using Go imaging library)
5. Thumbnail stored at: {bucket}/{property_id}/{entity}/{entity_id}/thumbs/{filename}
6. Returns:
   {
     "file_id": "uuid",
     "file_path": "rg-workorder-photos/prop-uuid/wo-uuid/2026-08-04_photo.jpg",
     "thumbnail_path": "rg-workorder-photos/prop-uuid/wo-uuid/thumbs/2026-08-04_photo.jpg",
     "file_url": "https://minio.local/rg-workorder-photos/..."  // signed URL, 1hr expiry
   }
```

### Endpoint: `GET /files/{file_id}/url`

Returns a fresh signed URL for download (1 hour expiry). Clients should never hard-code the URL — always refresh via this endpoint.

---

## 4. MinIO Bucket Structure

```
MinIO (S3-compatible)
├── rg-workorder-photos/
│   └── {property_id}/
│       └── {work_order_id}/
│           ├── 2026-08-04T1700_site.jpg
│           ├── 2026-08-04T1700_issue.jpg
│           └── thumbs/
│               ├── 2026-08-04T1700_site.jpg
│               └── 2026-08-04T1700_issue.jpg
│
├── rg-documents/
│   └── {property_id}/
│       ├── contracts/
│       ├── warranties/
│       ├── manuals/
│       └── inspections/
│
├── rg-exports/
│   └── {report_type}/
│       └── {period}/
│           └── report.pdf
│
└── rg-avatars/
    └── {user_id}/
        └── avatar.jpg
```

### MinIO Policies

```json
// rg-workorder-photos: write by facility_manager/technician; read by admin/facility_manager
// rg-exports: write by report-engine service; read by report_viewer+
// rg-avatars: each user can read/write their own avatar only
```

---

## 5. Offline Upload Queue (Desktop)

When a desktop user takes a photo while offline:

```sql
-- SQLite: _pending_uploads table
INSERT INTO _pending_uploads (local_file_path, target_bucket, target_key, entity, entity_id)
VALUES (
    'C:\Temp\rg_photo_abc.jpg',
    'rg-workorder-photos',
    'prop-uuid/wo-uuid/2026-08-04_photo.jpg',
    'work_order',
    'wo-uuid'
);

-- Work order photo reference (set immediately, file will catch up)
INSERT INTO work_order_photo (work_order_id, file_path, status)
VALUES ('wo-uuid', 'PENDING:rg-workorder-photos/prop-uuid/wo-uuid/2026-08-04_photo.jpg', 'pending_upload');
```

When sync agent detects network:
```
1. Query _pending_uploads WHERE uploaded_at IS NULL
2. For each: stream local file to MinIO via S3 SDK
3. On success: UPDATE work_order_photo SET status='uploaded', file_path=<final_path>
4. Update Neon via sync endpoint
5. Mark _pending_uploads.uploaded_at = now()
6. Delete temp local file
```

---

## 6. Storage Backend Options

| Backend | Type | Use Case | Migration Effort |
|---------|------|----------|----------------|
| **MinIO** (primary) | Self-hosted, S3-compatible | On-premise, full control | — |
| **Cloudflare R2** | Cloud, S3-compatible, no egress fees | Cost-optimised cloud | Change endpoint + credentials |
| **AWS S3** | Cloud, reference implementation | Enterprise scale | Change endpoint + credentials |
| **Supabase Storage** | Cloud, managed | Already available if staying in Supabase | Change SDK call only |
| **Backblaze B2** | Cloud, S3-compatible, cheap | Budget cloud backup | Change endpoint + credentials |

**All options use the S3 SDK.** Switching between them requires only configuration changes — no application code changes.

### MinIO → AWS S3 Migration

```go
// Before (MinIO):
s3Client := minio.New("minio.local:9000", &minio.Options{
    Creds: credentials.NewStaticV4("minioadmin", "minioadmin", ""),
    Secure: false,
})

// After (AWS S3):
cfg, _ := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
s3Client := s3.NewFromConfig(cfg)

// Application upload code: UNCHANGED
// Only the client initialization changes
```

---

## 7. File Size Limits & Validation

| File Type | Max Size | Allowed MIME Types |
|-----------|----------|--------------------|
| Photos | 10 MB | image/jpeg, image/png, image/webp, image/heic |
| Documents | 25 MB | application/pdf, application/msword, application/vnd.openxmlformats-officedocument.* |
| Exports (PDF) | 50 MB | application/pdf |
| Avatars | 2 MB | image/jpeg, image/png |

Validation enforced at the API Gateway level before streaming to MinIO.

---

## 8. Backup & Retention

| File Type | Retention | Backup Strategy |
|-----------|-----------|----------------|
| Work order photos | 7 years (legal/compliance) | MinIO → secondary bucket (daily sync) |
| PPM documents | 7 years | Same as above |
| Exported reports | 5 years | MinIO → secondary bucket |
| Avatars | Until user deleted | No separate backup (re-uploadable) |
| Pending offline uploads | Until uploaded + 7 days | Local device only |

### MinIO Backup Script (daily, via TeamCity)

```powershell
# Run mc (MinIO client) mirror to backup location
mc mirror minio/rg-workorder-photos backup/rg-workorder-photos --overwrite
mc mirror minio/rg-documents backup/rg-documents --overwrite
mc mirror minio/rg-exports backup/rg-exports --overwrite
```

---

## 9. Security Considerations

- All MinIO buckets are **private by default** — no public access
- Files served via **signed URLs** with short expiry (1 hour)
- File uploads go through the API Gateway — not directly to MinIO — enabling virus scan integration (future: ClamAV)
- Filenames are sanitised (strip special characters, replace spaces with underscores)
- File content validated by MIME type inspection (not just extension)
- MinIO access credentials stored in `.env`, never in code
