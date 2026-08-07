# Desktop App — Authentication

> **Location:** `rg-desktop-windows/`
> **Mechanism:** JWT-based auth with secure in-memory token storage

---

## 1. Overview

The desktop app authenticates users against the API gateway using **NextAuth v5 JWT tokens**. The JWT is stored **in Rust memory** (never in localStorage) and passed to the sync agent via environment variable for authenticated sync requests.

## 2. Authentication Flow

```
┌──────────────┐     ┌──────────────┐     ┌─────────────────┐
│  LoginView   │     │  Rust Backend│     │  API Gateway    │
│  (React)     │     │  (Tauri)     │     │  (:8080)        │
└──────┬───────┘     └──────┬───────┘     └────────┬────────┘
       │                    │                      │
       │ 1. POST credentials│                      │
       │───────────────────►│                      │
       │                    │ 2. POST /api/auth/   │
       │                    │    callback/creds    │
       │                    │─────────────────────►│
       │                    │                      │
       │                    │ 3. JWT token         │
       │                    │◄─────────────────────│
       │                    │                      │
       │ 4. invoke("set_    │                      │
       │    auth_token")    │                      │
       │───────────────────►│                      │
       │                    │ 5. Decode JWT,       │
       │                    │    store in memory   │
       │                    │                      │
       │ 6. UserInfo        │                      │
       │◄───────────────────│                      │
       │                    │                      │
       │ 7. Navigate to     │                      │
       │    dashboard       │                      │
       └────────────────────┘                      │
```

## 3. JWT Storage (Security)

### 3.1 Why not localStorage?

- **XSS risk** — any injected script can read localStorage
- **Persistence** — tokens survive browser restarts (unwanted)
- **Tauri IPC** — the Rust backend is the trusted boundary

### 3.2 How it works

```rust
// In-memory storage in AppState
pub struct AppState {
    pub auth_token: Arc<Mutex<Option<String>>>,  // JWT in memory
    pub user_info: Arc<Mutex<Option<UserInfo>>>, // Decoded user
}
```

The token is:
- Stored in **Rust process memory** only
- Passed to the sync agent via `RG_AUTH_TOKEN` env var on spawn
- Cleared on logout
- Never persisted to disk

## 4. IPC Commands

| Command | Description |
|---------|-------------|
| `set_auth_token(token)` | Validates and stores the JWT, returns decoded UserInfo |
| `get_auth_token()` | Returns the stored JWT (for sync agent) |
| `get_user_info()` | Returns the current user info |
| `logout()` | Clears the stored token and user info |

## 5. JWT Decoding

The Rust backend decodes the JWT payload (without verification for dev convenience):

```rust
fn decode_jwt(token: &str) -> Result<jsonwebtoken::TokenData<serde_json::Value>, String> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        return Err("Invalid JWT format".to_string());
    }
    // Decode payload (middle part) without verification
    let payload = parts[1];
    let padded = match payload.len() % 4 {
        2 => format!("{}==", payload),
        3 => format!("{}=", payload),
        _ => payload.to_string(),
    };
    let decoded = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(padded)
        .map_err(|e| format!("Invalid base64: {}", e))?;
    let claims: serde_json::Value = serde_json::from_slice(&decoded)
        .map_err(|e| format!("Invalid JSON: {}", e))?;
    Ok(jsonwebtoken::TokenData {
        header: Default::default(),
        claims,
    })
}
```

## 6. Frontend Auth State

The React frontend tracks auth state:

```typescript
const [user, setUser] = useState<UserInfo | null>(null);
const [showLogin, setShowLogin] = useState(false);

const checkAuth = useCallback(async () => {
  try {
    const token = await getAuthToken();
    if (token) {
      // Decode token to get user info
      const payload = JSON.parse(atob(token.split('.')[1]));
      setUser({ ... });
      setShowLogin(false);
    } else {
      setUser(null);
      setShowLogin(true);
    }
  } catch (err) {
    setUser(null);
    setShowLogin(true);
  }
}, []);
```

## 7. Login View

The `LoginView` component:
- Collects email/password
- POSTs to the gateway's auth endpoint
- Receives JWT
- Stores it via `set_auth_token` IPC command
- Navigates to the dashboard

## 8. Security Considerations

| Concern | Mitigation |
|---------|------------|
| XSS token theft | JWT in Rust memory, not localStorage |
| Token interception | HTTPS only (except localhost dev) |
| Token expiry | Gateway validates JWT on each request |
| Logout | Clears token from memory |
| Sync agent auth | Token passed via env var on spawn |