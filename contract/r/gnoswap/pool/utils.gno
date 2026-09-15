package pool

import (
	"strconv"
	"strings"

	"gno.land/p/gnoswap/utils"
)

const MAX_TICK int32 = 887272

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path + ":" + token1Path + ":" + strconv.FormatUint(uint64(fee), 10)
}

// EncodeTickKey encodes a tick as a fixed-width 4-byte key whose
// lexicographic order matches the signed numeric order.
func EncodeTickKey(tick int32) string {
	return utils.EncodeInt32(tick)
}

// EncodePositionKey encodes a position range as two ordered tick keys.
func EncodePositionKey(tickLower, tickUpper int32) string {
	return utils.EncodeInt32(tickLower) + utils.EncodeInt32(tickUpper)
}

// DecodeTickKey decodes a fixed-width ordered tick key.
func DecodeTickKey(key string) int32 {
	return utils.DecodeInt32(key)
}
