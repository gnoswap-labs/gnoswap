package staker

import "testing"

func TestUintTreeCodec(t *testing.T) {
	values := []uint64{0, 1, 255, 256, 12345, 9223372036854775807, 18446744073709551615}
	previous := ""
	for _, value := range values {
		key := EncodeUint(value)
		if len(key) != 8 {
			t.Errorf("EncodeUint(%d) length = %d; want 8", value, len(key))
		}
		if decoded := DecodeUint(key); decoded != value {
			t.Errorf("DecodeUint(EncodeUint(%d)) = %d", value, decoded)
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
