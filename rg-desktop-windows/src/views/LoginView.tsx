import { useState } from "react";
import ifmImage from "../assets/ifm.webp";
import iconMark from "../assets/icon-mark.png";

export default function LoginView() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showIntro, setShowIntro] = useState(true);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!email || !password) {
      setError("Email and password are required");
      return;
    }

    setLoading(true);
    try {
      const response = await fetch("http://localhost:8080/api/auth/callback/credentials", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.message || "Invalid credentials");
      }

      const data = await response.json();
      const token = data.token || data.access_token;

      if (!token) {
        throw new Error("No token received from server");
      }

      await fetch("http://localhost:8082/api/set-auth-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });

      window.location.href = "/";
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  // Welcome / intro screen
  if (showIntro) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "100vh", padding: 24, background: "linear-gradient(135deg, #0f172a 0%, #1e293b 100%)" }}>
        <div style={{ width: "100%", maxWidth: 520, background: "var(--rg-surface)", borderRadius: 16, boxShadow: "0 20px 60px rgba(0,0,0,0.4)", overflow: "hidden" }}>
          {/* Hero image */}
          <div style={{ position: "relative", height: 200, overflow: "hidden" }}>
            <img src={ifmImage} alt="Raymond Gray IFM" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg, rgba(15,23,42,0.1) 0%, rgba(15,23,42,0.7) 100%)" }} />
            <div style={{ position: "absolute", bottom: 16, left: 24, display: "flex", alignItems: "center", gap: 12 }}>
              <img src={iconMark} alt="Raymond Gray" style={{ width: 48, height: 48, borderRadius: 8, background: "#fff", padding: 4 }} />
              <div>
                <div style={{ color: "#fff", fontSize: 22, fontWeight: 700 }}>Raymond Gray IFM</div>
                <div style={{ color: "rgba(255,255,255,0.8)", fontSize: 13 }}>Integrated Facility Management</div>
              </div>
            </div>
          </div>

          {/* Intro content */}
          <div style={{ padding: 28 }}>
            <h2 style={{ margin: 0, marginBottom: 12, color: "var(--rg-text)", fontSize: 20 }}>Welcome to Raymond Gray</h2>
            <p style={{ color: "var(--rg-text-muted)", lineHeight: 1.6, marginBottom: 16 }}>
              Raymond Gray provides comprehensive integrated facility management services — from
              planned maintenance and asset management to helpdesk support and resident services.
              This desktop app lets you manage work orders, track assets, and resolve requests
              even when offline, syncing seamlessly with the cloud.
            </p>
            <p style={{ color: "var(--rg-text-muted)", lineHeight: 1.6, marginBottom: 24 }}>
              Sign in to access your facility management dashboard.
            </p>
            <button
              className="btn btn-primary"
              style={{ width: "100%", padding: "12px 16px", fontSize: 15 }}
              onClick={() => setShowIntro(false)}
            >
              Continue to Sign In
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Login screen
  return (
    <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "100vh", padding: 24, background: "linear-gradient(135deg, #0f172a 0%, #1e293b 100%)" }}>
      <div style={{ width: "100%", maxWidth: 400, padding: 32, background: "var(--rg-surface)", borderRadius: 12, boxShadow: "0 20px 60px rgba(0,0,0,0.4)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
          <img src={iconMark} alt="Raymond Gray" style={{ width: 40, height: 40, borderRadius: 8, background: "#fff", padding: 4 }} />
          <div>
            <h2 style={{ margin: 0, color: "var(--rg-text)", fontSize: 18 }}>Sign in to Raymond Gray IFM</h2>
            <p style={{ margin: 0, color: "var(--rg-text-muted)", fontSize: 13 }}>Enter your credentials to continue</p>
          </div>
        </div>

        <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <label className="form-label">Email</label>
            <input
              className="form-input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="e.g. admin@raymondgray.org"
              autoFocus
            />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <label className="form-label">Password</label>
            <input
              className="form-input"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
            />
          </div>

          {error && (
            <div style={{ color: "var(--rg-danger)", fontSize: 13, padding: 8, background: "#fee2e2", borderRadius: 6 }}>
              {error}
            </div>
          )}

          <button className="btn btn-primary" style={{ width: "100%", marginTop: 8 }} disabled={loading} onClick={handleSubmit}>
            {loading ? "Signing in..." : "Sign in"}
          </button>
        </form>

        <button
          className="btn btn-secondary btn-sm"
          style={{ width: "100%", marginTop: 12 }}
          onClick={() => setShowIntro(true)}
        >
          ← Back to Welcome
        </button>

        <p style={{ marginTop: 24, textAlign: "center", fontSize: 13, color: "var(--rg-text-muted)" }}>
          Demo credentials: <br />
          Email: admin@raymondgray.org<br />
          Password: demo123
        </p>
      </div>
    </div>
  );
}