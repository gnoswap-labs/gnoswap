package pool

import (
	"strings"

	"gno.land/p/nt/ufmt"
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}
