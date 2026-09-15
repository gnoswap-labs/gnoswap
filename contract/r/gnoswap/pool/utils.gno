package pool

import (
	"strconv"
	"strings"

	"gno.land/p/gnoswap/utils"
)

const MAX_TICK int32 = 887272

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
// Parameters:
//   - token0Path: path of the first token contract; it is reordered with
//     token1Path when needed to form canonical pool order.
//   - token1Path: path of the second token contract; it is reordered with
//     token0Path when it sorts earlier.
//   - fee: pool fee tier encoded as its decimal uint32 value in the path.
//
// Returns:
//   - poolPath: canonical token0:token1:fee identifier with token paths in
//     lexicographical order.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path + ":" + token1Path + ":" + strconv.FormatUint(uint64(fee), 10)
}

// EncodeTickKey encodes a tick as a fixed-width 4-byte key whose
// lexicographic order matches the signed numeric order.
// Parameters:
//   - tick: signed tick index to encode.
//
// Returns:
//   - key: fixed-width ordered key whose lexicographical ordering matches the
//     signed numeric ordering of tick.
func EncodeTickKey(tick int32) string {
	return utils.EncodeInt32(tick)
}

// EncodePositionKey encodes a position range as two ordered tick keys.
// Parameters:
//   - tickLower: lower signed tick index of the position range.
//   - tickUpper: upper signed tick index of the position range.
//
// Returns:
//   - key: concatenation of the ordered encodings of tickLower and tickUpper.
func EncodePositionKey(tickLower, tickUpper int32) string {
	return utils.EncodeInt32(tickLower) + utils.EncodeInt32(tickUpper)
}

// DecodeTickKey decodes a fixed-width ordered tick key.
// Parameters:
//   - key: fixed-width ordered tick key produced by EncodeTickKey.
//
// Returns:
//   - tick: signed tick index decoded from key.
func DecodeTickKey(key string) int32 {
	return utils.DecodeInt32(key)
}
