package auth

import (
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

// JWTMiddleware validates NextAuth v5 JWTs (HS256, signed with NEXTAUTH_SECRET).
// The original raymond-gray-platform migrated from Supabase auth to NextAuth v5
// with a JWT session strategy, backed by Neon PostgreSQL via Prisma.
type JWTMiddleware struct {
	secret []byte
}

// NewJWTMiddleware creates a middleware that validates NextAuth JWTs.
// It requires NEXTAUTH_SECRET (or AUTH_SECRET) to be set.
func NewJWTMiddleware() (*JWTMiddleware, error) {
	secret := os.Getenv("NEXTAUTH_SECRET")
	if secret == "" {
		secret = os.Getenv("AUTH_SECRET")
	}
	if secret == "" {
		return nil, fmt.Errorf("NEXTAUTH_SECRET is not set; cannot validate NextAuth JWTs")
	}
	return &JWTMiddleware{secret: []byte(secret)}, nil
}

func (m *JWTMiddleware) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, `{"error": {"code": "UNAUTHORIZED", "message": "Missing or invalid Authorization header"}}`, http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		// Parse and validate the NextAuth JWT (HS256 with NEXTAUTH_SECRET)
		token, err := jwt.Parse(tokenString, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
			}
			return m.secret, nil
		})
		if err != nil || !token.Valid {
			http.Error(w, `{"error": {"code": "UNAUTHORIZED", "message": "Invalid or expired token"}}`, http.StatusUnauthorized)
			return
		}

		// Extract claims and inject into headers for downstream services
		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			if sub, ok := claims["sub"].(string); ok {
				r.Header.Set("X-User-Id", sub)
			}
			if email, ok := claims["email"].(string); ok {
				r.Header.Set("X-User-Email", email)
			}
			if role, ok := claims["role"].(string); ok {
				r.Header.Set("X-User-Roles", role)
			}
			if status, ok := claims["status"].(string); ok {
				r.Header.Set("X-User-Status", status)
			}
		}

		next.ServeHTTP(w, r)
	})
}