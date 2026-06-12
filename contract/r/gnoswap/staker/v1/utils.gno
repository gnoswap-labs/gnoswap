package v1

import (
	"strconv"
	"strings"

	"gno.land/p/demo/tokens/grc721"
)

// poolPathDivide splits a pool path into token addresses and fee tier.
func poolPathDivide(poolPath string) (string, string, string) {
	res := strings.Split(poolPath, ":")
	if len(res) != 3 {
		panic(errInvalidPoolPath)
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]
	return pToken0, pToken1, fee
}

// positionIdFrom converts a uint64 position ID to grc721.TokenID.
func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(positionId, 10))
}

// contains checks if a string exists in a slice.
func contains(slice []string, item string) bool {
	// We can use strings.EqualFold here, but this function should be case-sensitive.
	// So, it is better to compare strings directly.
	for _, element := range slice {
		if element == item {
			return true
		}
	}
	return false
}
