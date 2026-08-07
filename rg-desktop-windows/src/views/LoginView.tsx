import { useState } from "react";

export default function LoginView() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!email || !password) {
      setError("Email and password are required");
      return;
    }

    setLoading(true);
    try {
      // In production, this would call the NextAuth API endpoint
      // For now, we'll simulate with the gateway's auth endpoint
      const response = await fetch("http://localhost:8080/api/auth/callback/credentials", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.message || "Invalid credentials");
      }

      // Get the session token from the response
      const data = await response.json();
      const token = data.token || data.access_token;

      if (!token) {
        throw new Error("No token received from server");
      }

      // Store token via IPC
      await fetch("http://localhost:8082/api/set-auth-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });

      // Navigate to dashboard
      window.location.href = "/";
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "100vh", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 400, padding: 32, background: "var(--rg-surface)", borderRadius: 12, boxShadow: "var(--shadow-md)" }}>
        <h2 style={{ marginBottom: 8, color: "var(--rg-text)" }}>Sign in to Raymond Gray IFM</h2>
        <p style={{ color: "var(--rg-text-muted)", marginBottom: 24 }}>Enter your credentials to access the desktop app</p>

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

        <p style={{ marginTop: 24, textAlign: "center", fontSize: 13, color: "var(--rg-text-muted)" }}>
          Demo credentials: <br />
          Email: admin@raymondgray.org<br />
          Password: demo123
        </p>
      </div>
    </div>
  );
}
