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
