package uint256

import (
	"testing"
)

const (
	MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
)

// for original tests
func parseUint(s string) *Uint {
	return MustFromDecimal(s)
}

// for testing.T
func parseUintT(t *testing.T, s string) *Uint {
	return parseUint(s)
}
