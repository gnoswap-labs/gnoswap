package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256/v1"
)

func TestUintTreeInt64Codec(t *testing.T) {
	values := []int64{0, 1, 255, 256, 12345, 9223372036854775807}
	previous := ""
	for _, value := range values {
		key := encodeInt64(value)
		if len(key) != 8 {
			t.Errorf("encodeInt64(%d) length = %d; want 8", value, len(key))
		}
		if decoded := decodeInt64(key); decoded != value {
			t.Errorf("decodeInt64(encodeInt64(%d)) = %d", value, decoded)
		}
		if previous != "" && !(previous < key) {
			t.Errorf("EncodeUint keys are not ordered: %d", value)
		}
		previous = key
	}
}

func TestUintTreeIteratesBinaryKeysInNumericOrder(t *testing.T) {
	tree := NewUintTree()
	values := []int64{256, 1, 9223372036854775806, 0, 255}
	for _, value := range values {
		tree.Set(value, value)
	}

	got := make([]int64, 0, len(values))
	tree.Iterate(0, 9223372036854775807, func(key int64, _ any) bool {
		got = append(got, key)
		return false
	})

	want := []int64{0, 1, 255, 256, 9223372036854775806}
	if len(got) != len(want) {
		t.Fatalf("iteration returned %d keys; want %d", len(got), len(want))
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("iteration[%d] = %d; want %d", i, got[i], want[i])
		}
	}
}

func TestTicksIterateInSignedNumericOrder(t *testing.T) {
	ticks := NewTicks()
	inserted := []int32{1, -1, 10, -10, 0}
	for _, tickID := range inserted {
		tick := NewTick(tickID)
		tick.SetStakedLiquidityGross(u256.One())
		ticks.SetTick(tickID, tick)
	}

	got := make([]int32, 0, len(inserted))
	ticks.IterateTicks(func(tickID int32, _ *Tick) bool {
		got = append(got, tickID)
		return false
	})

	want := []int32{-10, -1, 0, 1, 10}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("iteration[%d] = %d; want %d", i, got[i], want[i])
		}
	}
}
