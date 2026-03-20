package pool

import (
	"strconv"
	"strings"

	"gno.land/p/nt/seqid/v0"
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
// Uses seqid (cford32) encoding for compact, lexicographically ordered keys (7 bytes).
func EncodeTickKey(tick int32) string {
	adjustTick := tick + ENCODED_TICK_OFFSET
	if adjustTick < 0 {
		panic(ufmt.Sprintf("tick(%d) + ENCODED_TICK_OFFSET(%d) < 0", tick, ENCODED_TICK_OFFSET))
	}

	return seqid.ID(uint64(adjustTick)).String()
}

// DecodeTickKey decodes a string key to a tick.
func DecodeTickKey(s string) int32 {
	id, err := seqid.FromString(s)
	if err != nil {
		panic(ufmt.Sprintf("invalid tick key: %s", s))
	}

	return int32(uint64(id)) - ENCODED_TICK_OFFSET
}
