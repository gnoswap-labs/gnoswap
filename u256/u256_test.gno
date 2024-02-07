package u256

import (
	"testing"
)

func TestArithmetic(t *testing.T) {
	x := NewUint(1)
	y := NewUint(2)
	NewUint(0).Add(x, y)
}