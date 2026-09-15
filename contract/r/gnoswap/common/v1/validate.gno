package common

import (
	"errors"

	"gno.land/p/nt/ufmt/v0"
)

// Token keys ("<realm path>.<SYMBOL>") are embedded verbatim in pool paths
// ("<key0>:<key1>:<fee>") and router routes ("<pool>*POOL*<pool>,<route>"),
// so the key charset is an allowlist rather than a blocklist of separators:
// package-path characters plus '.' plus the GRC20 symbol charset.
//
// Parameters:
//   - c: rune to test against the token-key allowlist
//
// Returns:
//   - valid: true when c is permitted in a token key; false otherwise
func isTokenKeyChar(c rune) bool {
	switch {
	case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9':
		return true
	case c == '_', c == '-', c == '.', c == '/':
		return true
	}

	return false
}

func validateTokenKey(tokenKey string) error {
	if tokenKey == "" {
		return errors.New(newErrorWithDetail(errInvalidTokenKey, "empty token key"))
	}

	for _, ch := range tokenKey {
		if !isTokenKeyChar(ch) {
			return errors.New(newErrorWithDetail(
				errInvalidTokenKey,
				ufmt.Sprintf("token key(%s) contains %q", tokenKey, string(ch)),
			))
		}
	}

	return nil
}
