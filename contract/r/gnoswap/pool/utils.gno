package pool

import (
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path + ":" + token1Path + ":" + strconv.FormatUint(uint64(fee), 10)
}

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
