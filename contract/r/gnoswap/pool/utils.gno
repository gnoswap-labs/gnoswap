package pool

import (
	"strconv"
	"strings"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	ufmt "gno.land/p/nt/ufmt/v0"
)

func encodeU256(v *u256.Uint) string {
	if v == nil {
		return "0"
	}
	return v.ToString()
}

func decodeU256(s string) *u256.Uint {
	if s == "" || s == "0" {
		return u256.Zero()
	}
	return u256.MustFromDecimal(s)
}

func encodeI256(v *i256.Int) string {
	if v == nil {
		return "0"
	}
	return v.ToString()
}

func decodeI256(s string) *i256.Int {
	if s == "" || s == "0" {
		return i256.Zero()
	}
	return i256.MustFromDecimal(s)
}

const (
	MAX_TICK            int32 = 887272
	ENCODED_TICK_OFFSET int32 = MAX_TICK
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path + ":" + token1Path + ":" + strconv.FormatUint(uint64(fee), 10)
}

// EncodeTickKey encodes a tick to a string key for the tick tree.
func EncodeTickKey(tick int32) string {
	adjustTick := tick + ENCODED_TICK_OFFSET
	if adjustTick < 0 {
		panic(ufmt.Sprintf("tick(%d) + ENCODED_TICK_OFFSET(%d) < 0", tick, ENCODED_TICK_OFFSET))
	}

	// Convert the value to a decimal string.
	s := strconv.FormatInt(int64(adjustTick), 10)

	// Zero-pad to a total length of 10 characters.
	zerosNeeded := 10 - len(s)

	return strings.Repeat("0", zerosNeeded) + s
}

// DecodeTickKey decodes a string key to a tick.
func DecodeTickKey(s string) int32 {
	adjustTick, err := strconv.ParseInt(s, 10, 32)
	if err != nil {
		panic(ufmt.Sprintf("invalid tick key: %s", s))
	}

	return int32(adjustTick) - ENCODED_TICK_OFFSET
}
