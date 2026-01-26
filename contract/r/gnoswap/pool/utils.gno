package pool

import (
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"
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
