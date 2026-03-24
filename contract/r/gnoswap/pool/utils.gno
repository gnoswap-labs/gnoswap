package pool

import (
	"errors"
	"strconv"
	"strings"

	"gno.land/p/gnoswap/strcodec"
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	MAX_TICK            int32 = 887272
	ENCODED_TICK_OFFSET int32 = MAX_TICK
	poolPathVersion           = "PK1"
)

var errInvalidPoolPathEncoding = errors.New("invalid pool path encoding")

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return poolPathVersion + strcodec.EncodeString(token0Path) + strcodec.EncodeString(token1Path) + strcodec.EncodeUint32(fee)
}

func ParsePoolPath(poolPath string) (string, string, uint32, error) {
	if strings.HasPrefix(poolPath, poolPathVersion) {
		return parseEncodedPoolPath(poolPath)
	}

	return parseLegacyPoolPath(poolPath)
}

func parseEncodedPoolPath(poolPath string) (string, string, uint32, error) {
	offset := len(poolPathVersion)
	token0Path, offset, err := strcodec.DecodeString(poolPath, offset)
	if err != nil {
		return "", "", 0, errInvalidPoolPathEncoding
	}

	token1Path, offset, err := strcodec.DecodeString(poolPath, offset)
	if err != nil {
		return "", "", 0, errInvalidPoolPathEncoding
	}

	fee, offset, err := strcodec.DecodeUint32(poolPath, offset)
	if err != nil {
		return "", "", 0, errInvalidPoolPathEncoding
	}

	if offset != len(poolPath) {
		return "", "", 0, errInvalidPoolPathEncoding
	}

	return token0Path, token1Path, fee, nil
}

func parseLegacyPoolPath(poolPath string) (string, string, uint32, error) {
	poolPathSplit := strings.Split(poolPath, ":")
	if len(poolPathSplit) != 3 {
		return "", "", 0, errInvalidPoolPathEncoding
	}

	fee, err := strconv.ParseUint(poolPathSplit[2], 10, 32)
	if err != nil {
		return "", "", 0, errInvalidPoolPathEncoding
	}

	return poolPathSplit[0], poolPathSplit[1], uint32(fee), nil
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
