package pool

import (
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"
)

const (
	MAX_TICK            int32 = 887272
	ENCODED_TICK_OFFSET int32 = MAX_TICK
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
//
// Parameters:
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//
// Returns:
//   - poolPath: deterministic pool path in token0:token1:fee form
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path + ":" + token1Path + ":" + strconv.FormatUint(uint64(fee), 10)
}

// ParsePoolPath splits a pool path into token paths and fee tier.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - token0Path: token0 path
//   - token1Path: token1 path
//   - fee: fee tier
//
// Panics if the poolPath is malformed or fee cannot be parsed.
func ParsePoolPath(poolPath string) (string, string, uint32) {
	parts := strings.Split(poolPath, ":")
	if len(parts) != 3 {
		panic(ufmt.Sprintf("invalid pool path: %s", poolPath))
	}

	fee, err := strconv.ParseUint(parts[2], 10, 32)
	if err != nil {
		panic(ufmt.Sprintf("invalid fee: %s", parts[2]))
	}

	return parts[0], parts[1], uint32(fee)
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
