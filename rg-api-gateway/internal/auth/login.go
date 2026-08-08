package auth

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

// LoginRequest is the JSON body for the login endpoint.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginResponse is returned on successful login.
type LoginResponse struct {
	Token string `json:"token"`
	User  struct {
		ID    string `json:"id"`
		Email string `json:"email"`
		Role  string `json:"role"`
	} `json:"user"`
}

// LoginHandler validates credentials against the Neon DB and issues a JWT.
// It reads NEON_URL for the database connection and NEXTAUTH_SECRET for signing.
func LoginHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, `{"error": {"code": "METHOD_NOT_ALLOWED", "message": "POST required"}}`, http.StatusMethodNotAllowed)
			return
		}

		var req LoginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": {"code": "BAD_REQUEST", "message": "Invalid JSON body"}}`, http.StatusBadRequest)
			return
		}
		if req.Email == "" || req.Password == "" {
			http.Error(w, `{"error": {"code": "BAD_REQUEST", "message": "Email and password are required"}}`, http.StatusBadRequest)
			return
		}

		// Connect to the Neon database
		neonURL := os.Getenv("NEON_URL")
		if neonURL == "" {
			http.Error(w, `{"error": {"code": "SERVER_ERROR", "message": "NEON_URL not configured"}}`, http.StatusInternalServerError)
			return
		}
		db, err := sql.Open("postgres", neonURL)
		if err != nil {
			http.Error(w, `{"error": {"code": "SERVER_ERROR", "message": "Failed to connect to database"}}`, http.StatusInternalServerError)
			return
		}
		defer db.Close()

		// Look up the user by email
		var (
			userID       string
			userEmail    string
			userRole     string
			userStatus   string
			passwordHash string
		)
		// The User table lives in the public schema of the Neon DB (from the original platform's Prisma schema)
		err = db.QueryRow(
			`SELECT id, COALESCE(email,''), role::text, status::text, COALESCE(password,'') FROM "User" WHERE email = $1`,
			req.Email,
		).Scan(&userID, &userEmail, &userRole, &userStatus, &passwordHash)

		if err == sql.ErrNoRows {
			http.Error(w, `{"error": {"code": "UNAUTHORIZED", "message": "Invalid credentials"}}`, http.StatusUnauthorized)
			return
		}
		if err != nil {
			http.Error(w, `{"error": {"code": "SERVER_ERROR", "message": "Database query failed"}}`, http.StatusInternalServerError)
			return
		}

		// Verify the password (bcrypt hash)
		if passwordHash == "" || bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)) != nil {
			http.Error(w, `{"error": {"code": "UNAUTHORIZED", "message": "Invalid credentials"}}`, http.StatusUnauthorized)
			return
		}

		// Check user status (only allow ACTIVE/APPROVED users)
		if userStatus != "" && userStatus != "ACTIVE" && userStatus != "APPROVED" {
			http.Error(w, `{"error": {"code": "FORBIDDEN", "message": "Account is not active"}}`, http.StatusForbidden)
			return
		}

		// Issue a JWT signed with NEXTAUTH_SECRET (HS256)
		secret := os.Getenv("NEXTAUTH_SECRET")
		if secret == "" {
			secret = os.Getenv("AUTH_SECRET")
		}
		if secret == "" {
			http.Error(w, `{"error": {"code": "SERVER_ERROR", "message": "NEXTAUTH_SECRET not configured"}}`, http.StatusInternalServerError)
			return
		}

		claims := jwt.MapClaims{
			"sub":   userID,
			"email": userEmail,
			"role":  userRole,
			"iat":   time.Now().Unix(),
			"exp":   time.Now().Add(24 * time.Hour).Unix(),
		}
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString([]byte(secret))
		if err != nil {
			http.Error(w, `{"error": {"code": "SERVER_ERROR", "message": "Failed to sign token"}}`, http.StatusInternalServerError)
			return
		}

		// Build the response
		resp := LoginResponse{Token: tokenString}
		resp.User.ID = userID
		resp.User.Email = userEmail
		resp.User.Role = userRole

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(resp)
	}
}