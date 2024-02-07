package u256

import (
	"testing"
)

func TestArithmetic(t *testing.T) {
	x := NewInt(1)
	y := NewInt(2)
	z := NewInt(0).Add(x, y)
}