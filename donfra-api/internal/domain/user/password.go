package user

import (
	"errors"

	"golang.org/x/crypto/bcrypt"
)

const bcryptCost = 12 // Higher cost = more secure but slower

// HashPassword hashes a plain text password using bcrypt.
func HashPassword(password string) (string, error) {
	if password == "" {
		return "", errors.New("password cannot be empty")
	}

	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
	if err != nil {
		return "", err
	}

	return string(hashedBytes), nil
}

// VerifyPassword compares a hashed password with a plain text password.
// Returns nil if they match, error otherwise.
func VerifyPassword(hashedPassword, password string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
}
