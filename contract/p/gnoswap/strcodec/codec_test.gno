package strcodec

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestEncodeDecodeString(t *testing.T) {
	encoded := EncodeString("gno.land/r/demo/token:with:anything")
	decoded, next, err := DecodeString(encoded, 0)

	uassert.NoError(t, err)
	uassert.Equal(t, "gno.land/r/demo/token:with:anything", decoded)
	uassert.Equal(t, len(encoded), next)
}

func TestDecodeString_InvalidLengthPrefix(t *testing.T) {
	_, _, err := DecodeString("abc123payload", 0)
	uassert.Error(t, err)
	uassert.Equal(t, ErrInvalidLengthPrefix.Error(), err.Error())
}

func TestEncodeDecodeUint32(t *testing.T) {
	encoded := EncodeUint32(3000)
	decoded, next, err := DecodeUint32(encoded, 0)

	uassert.NoError(t, err)
	uassert.Equal(t, uint32(3000), decoded)
	uassert.Equal(t, len(encoded), next)
	uassert.Equal(t, 10, len(encoded))
}
