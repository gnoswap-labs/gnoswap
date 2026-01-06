package uint256

import (
	"testing"
)

// for original tests
func parseUint(s string) *Uint {
	return MustFromDecimal(s)
}

// for testing.T
func parseUintT(t *testing.T, s string) *Uint {
	return parseUint(s)
}
