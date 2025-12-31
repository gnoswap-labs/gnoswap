package uint256

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestZeroOneReturnsFreshCopies verifies that Zero() and One() return fresh copies
// and not shared instances that can be mutated
func TestZeroOneReturnsFreshCopies(t *testing.T) {
	// Test Zero()
	z1 := Zero()
	z2 := Zero()

	// Modify z1
	z1.SetUint64(42)

	// z2 should still be zero
	if !z2.IsZero() {
		t.Errorf("Zero() returned shared instance: z2 = %s, expected 0", z2.ToString())
	}

	// New Zero() should still return 0
	z3 := Zero()
	if !z3.IsZero() {
		t.Errorf("Zero() corrupted: z3 = %s, expected 0", z3.ToString())
	}

	// Test One()
	o1 := One()
	o2 := One()

	// Modify o1
	o1.SetUint64(42)

	// o2 should still be one
	if o2.Uint64() != 1 {
		t.Errorf("One() returned shared instance: o2 = %s, expected 1", o2.ToString())
	}

	// New One() should still return 1
	o3 := One()
	if o3.Uint64() != 1 {
		t.Errorf("One() corrupted: o3 = %s, expected 1", o3.ToString())
	}
}

// TestZeroOneUsageInArithmetic tests common usage patterns from the codebase
func TestZeroOneUsageInArithmetic(t *testing.T) {
	// Test pattern from bit_math.gno: u256.Zero().Lsh(u256.One(), 128)
	result := Zero().Lsh(One(), 128)
	if result.IsZero() {
		t.Error("Lsh operation failed")
	}

	// Verify Zero() and One() still return correct values after usage
	if !Zero().IsZero() {
		t.Error("Zero() corrupted after Lsh operation")
	}
	if One().Uint64() != 1 {
		t.Error("One() corrupted after Lsh operation")
	}

	// Test multiple operations
	a := Zero()
	a.Add(a, One())
	a.Mul(a, One())

	// Verify globals are still intact
	if !Zero().IsZero() {
		t.Error("Zero() corrupted after arithmetic operations")
	}
	if One().Uint64() != 1 {
		t.Error("One() corrupted after arithmetic operations")
	}
}

func TestSetAllOneAndSetOne(t *testing.T) {
	t.Run("SetAllOne sets max", func(t *testing.T) {
		z := new(Uint).SetAllOne()
		uassert.Equal(t, MAX_UINT256, z.ToString())
	})

	t.Run("SetOne sets one", func(t *testing.T) {
		z := new(Uint).SetAllOne() // start dirty
		z.SetOne()
		uassert.Equal(t, "1", z.ToString())
	})
}
