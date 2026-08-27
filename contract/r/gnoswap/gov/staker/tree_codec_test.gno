package staker

import "testing"

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
