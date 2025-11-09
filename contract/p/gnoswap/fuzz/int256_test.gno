package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/int256"
	"gno.land/p/gnoswap/uint256"
)

func TestInt256_Uint256(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate uint256 across full range
		val := Uint256().Draw(ft, "val").(*uint256.Uint)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}

		// Just verify it's a valid uint256 value
		_ = val.ToString()
	})
}

func TestInt256_Uint256Max(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate uint256 from 0 to 1000000
		val := Uint256Max("1000000").Draw(ft, "val").(*uint256.Uint)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}

		// Verify it's within expected range [0, 1000000]
		min := uint256.NewUint(0)
		max := uint256.MustFromDecimal("1000000")
		if val.Cmp(min) < 0 || val.Cmp(max) > 0 {
			ft.Fatalf("value %s out of range [0, 1000000]", val.ToString())
		}
	})
}

func TestInt256_Uint256Min(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate uint256 from 1000 to max uint256
		val := Uint256Min("1000").Draw(ft, "val").(*uint256.Uint)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}

		// Verify it's at least 1000
		min := uint256.MustFromDecimal("1000")
		if val.Cmp(min) < 0 {
			ft.Fatalf("value %s less than min 1000", val.ToString())
		}
	})
}

func TestInt256_Uint256Range(t *testing.T) {
	Check(t, func(ft *T) {
		min := uint256.MustFromDecimal("1000")
		max := uint256.MustFromDecimal("999999")

		val := Uint256Range("1000", "999999").Draw(ft, "val").(*uint256.Uint)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}
		if val.Cmp(min) < 0 {
			ft.Fatalf("value %s less than min %s", val.ToString(), min.ToString())
		}
		if val.Cmp(max) > 0 {
			ft.Fatalf("value %s greater than max %s", val.ToString(), max.ToString())
		}
	})
}

func TestInt256_Int256(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate int256 across full range
		val := Int256().Draw(ft, "val").(*int256.Int)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}

		// Just verify it's a valid int256 value
		_ = val.ToString()
	})
}

func TestInt256_Int256Max(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate int256 from min int256 to 1000000
		val := Int256Max("1000000").Draw(ft, "val").(*int256.Int)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}

		// Verify it's within expected range
		max := int256.NewInt(1000000)
		if val.Cmp(max) > 0 {
			ft.Fatalf("value %s greater than max 1000000", val.ToString())
		}
	})
}

func TestInt256_Int256Min(t *testing.T) {
	Check(t, func(ft *T) {
		// Generate int256 from -1000 to max int256
		val := Int256Min("-1000").Draw(ft, "val").(*int256.Int)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}

		// Verify it's at least -1000
		min := int256.NewInt(-1000)
		if val.Cmp(min) < 0 {
			ft.Fatalf("value %s less than min -1000", val.ToString())
		}
	})
}

func TestInt256_Int256Range(t *testing.T) {
	Check(t, func(ft *T) {
		min := int256.MustFromDecimal("-1000")
		max := int256.MustFromDecimal("999999")

		val := Int256Range("-1000", "999999").Draw(ft, "val").(*int256.Int)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}
		if val.Cmp(min) < 0 {
			ft.Fatalf("value %s less than min %s", val.ToString(), min.ToString())
		}
		if val.Cmp(max) > 0 {
			ft.Fatalf("value %s greater than max %s", val.ToString(), max.ToString())
		}
	})
}

func TestInt256_Int256RangeNegativeOnly(t *testing.T) {
	Check(t, func(ft *T) {
		min := int256.MustFromDecimal("-999999")
		max := int256.MustFromDecimal("-1000")

		val := Int256Range("-999999", "-1000").Draw(ft, "val").(*int256.Int)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}
		if val.Cmp(min) < 0 {
			ft.Fatalf("value %s less than min %s", val.ToString(), min.ToString())
		}
		if val.Cmp(max) > 0 {
			ft.Fatalf("value %s greater than max %s", val.ToString(), max.ToString())
		}
		if val.Sign() >= 0 {
			ft.Fatalf("value %s should be negative", val.ToString())
		}
	})
}

func TestInt256_Int256RangePositiveOnly(t *testing.T) {
	Check(t, func(ft *T) {
		min := int256.MustFromDecimal("1000")
		max := int256.MustFromDecimal("999999")

		val := Int256Range("1000", "999999").Draw(ft, "val").(*int256.Int)

		if val == nil {
			ft.Fatalf("expected non-nil value")
		}
		if val.Cmp(min) < 0 {
			ft.Fatalf("value %s less than min %s", val.ToString(), min.ToString())
		}
		if val.Cmp(max) > 0 {
			ft.Fatalf("value %s greater than max %s", val.ToString(), max.ToString())
		}
		if val.Sign() <= 0 {
			ft.Fatalf("value %s should be positive", val.ToString())
		}
	})
}
