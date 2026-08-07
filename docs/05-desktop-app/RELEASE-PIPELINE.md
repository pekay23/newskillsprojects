# Desktop App — Release & Update Pipeline

> **Location:** `rg-desktop-windows/`
> **Mechanism:** Tauri updater plugin + GitHub Releases

---

## 1. Overview

The desktop app uses **Tauri's built-in updater** to push updates to clients automatically. When a new version is published to GitHub Releases, all installed clients check for updates on startup, download the new version, verify the signature, and install passively.

## 2. Update Flow

```
Developer pushes tag v1.1.0
        │
        ▼
GitHub Actions (desktop-release.yml)
        │
        ├─ 1. Checkout code
        ├─ 2. Setup Node.js + Rust + MSVC
        ├─ 3. npm ci
        ├─ 4. npx tsc --noEmit (type check)
        ├─ 5. npm run build (frontend)
        ├─ 6. npm run tauri build (bundle)
        ├─ 7. Generate latest.json
        └─ 8. Create GitHub Release (installer + .sig + latest.json)
        │
        ▼
Client app starts
        │
        ├─ Checks https://github.com/pekay23/newskillsprojects/releases/latest/download/latest.json
        ├─ Compares version vs installed version
        ├─ If newer: prompts user
        ├─ Downloads installer
        ├─ Verifies signature (against embedded public key)
        └─ Installs passively → relaunches
```

## 3. Configuration

### 3.1 `src-tauri/tauri.conf.json`

```json
{
  "plugins": {
    "updater": {
      "pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IDQ5MzU0RjkyOTQxQjUwQjQKUldTMFVCdVVrazgxU2FiTnVNYkNIK0I3ZFhvMHNiNklZSWcyOWpSTkY1SWNOV2xQNWVuUldHZ3EK",
      "endpoints": [
        "https://github.com/pekay23/newskillsprojects/releases/latest/download/latest.json"
      ],
      "windows": {
        "installMode": "passive"
      }
    }
  }
}
```

### 3.2 `src-tauri/Cargo.toml`

```toml
[dependencies]
tauri-plugin-updater = "2"
tauri-plugin-process = "2"
```

### 3.3 `src-tauri/capabilities/default.json`

```json
{
  "permissions": [
    "updater:allow-check",
    "updater:allow-download-and-install",
    "process:allow-restart",
    "process:allow-exit"
  ]
}
```

## 4. Release Methods

### 4.1 Manual Release (PowerShell)

```powershell
.\scripts\release.ps1 -Version "1.1.0" -SigningKey "C:\path\to\myapp.key"
```

This script:
1. Updates version in `package.json` and `tauri.conf.json`
2. Builds the frontend (`npm run build`)
3. Builds the Tauri bundle (`npm run tauri build`)
4. Signs the installer (`tauri signer sign`)
5. Generates `latest.json`
6. Creates a GitHub Release with all assets

### 4.2 Automated Release (GitHub Actions)

Push a version tag to trigger the CI pipeline:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The workflow `.github/workflows/desktop-release.yml` handles everything automatically.

## 5. Signing Key

### 5.1 Generate a signing key (one-time)

```bash
tauri signer generate -w ~/.tauri/myapp.key
```

This produces:
- `myapp.key` — **private key** (keep secret!)
- `myapp.key.pub` — public key (already in `tauri.conf.json`)

### 5.2 GitHub Secrets

For CI automation, add these secrets to the repository:

| Secret | Value |
|--------|-------|
| `TAURI_SIGNING_PRIVATE_KEY` | Contents of the private key file |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | Key password (if set) |

## 6. `latest.json` Format

```json
{
  "version": "1.1.0",
  "notes": "Raymond Gray IFM v1.1.0",
  "pub_date": "2026-08-07T00:00:00.000Z",
  "platforms": {
    "windows-x86_64": {
      "signature": "<base64-encoded-signature>",
      "url": "https://github.com/pekay23/newskillsprojects/releases/latest/download/Raymond Gray IFM_1.1.0_x64.msi"
    }
  }
}
```

## 7. Client-Side Update Check

The frontend (`src/App.tsx`) checks for updates on startup:

```typescript
useEffect(() => {
  const checkForUpdates = async () => {
    try {
      const update = await check();
      if (update) {
        const confirmed = window.confirm(
          `A new version (${update.version}) is available. Download and install now?`
        );
        if (confirmed) {
          await update.downloadAndInstall();
          await relaunch();
        }
      }
    } catch (err) {
      console.error("Failed to check for updates:", err);
    }
  };
  checkForUpdates();
}, []);
```

## 8. Rollback

To roll back a bad release:
1. Re-publish the previous `latest.json` pointing to the previous installer
2. Or create a new release with the previous version number

## 9. Troubleshooting

| Issue | Fix |
|-------|-----|
| Update check fails | Verify `latest.json` is accessible at the endpoint URL |
| Signature verification fails | Ensure the installer was signed with the same key as the public key in `tauri.conf.json` |
| Update downloads but doesn't install | Check `installMode` is `passive` and the app has write permissions |
| CI build fails | Verify `TAURI_SIGNING_PRIVATE_KEY` secret is set correctly |