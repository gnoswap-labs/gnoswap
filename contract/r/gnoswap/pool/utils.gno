package pool

import (
	"strconv"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
)

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
	var buf [10]byte
	encodeTickKeyToBuffer(buf[:], tick)
	return string(buf[:])
}

// EncodePositionKey encodes a position range into a fixed-width 20-byte string.
func EncodePositionKey(tickLower, tickUpper int32) string {
	var buf [20]byte
	encodeTickKeyToBuffer(buf[:10], tickLower)
	encodeTickKeyToBuffer(buf[10:], tickUpper)
	return string(buf[:])
}

func encodeTickKeyToBuffer(dst []byte, tick int32) {
	adjustTick := tick + ENCODED_TICK_OFFSET
	if adjustTick < 0 {
		panic(ufmt.Sprintf("tick(%d) + ENCODED_TICK_OFFSET(%d) < 0", tick, ENCODED_TICK_OFFSET))
	}

	for i := len(dst) - 1; i >= 0; i-- {
		dst[i] = byte('0' + adjustTick%10)
		adjustTick /= 10
	}
}

// DecodeTickKey decodes a string key to a tick.
func DecodeTickKey(s string) int32 {
	adjustTick, err := strconv.ParseInt(s, 10, 32)
	if err != nil {
		panic(ufmt.Sprintf("invalid tick key: %s", s))
	}

	return int32(adjustTick) - ENCODED_TICK_OFFSET
}
