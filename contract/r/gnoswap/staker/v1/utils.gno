package staker

import (
	"errors"
	"strconv"
	"strings"

	"gno.land/p/nt/grc721/v0"
)

// poolPathDivide splits a pool path into token addresses and fee tier.
//
// Parameters:
//   - poolPath: Pool path encoded as token0:token1:fee with exactly three colon-separated components.
//
// Returns:
//   - token0Path: First token component from poolPath.
//   - token1Path: Second token component from poolPath.
//   - feeTier: Third component from poolPath representing the fee tier.
func poolPathDivide(poolPath string) (string, string, string) {
	res := strings.Split(poolPath, ":")
	if len(res) != 3 {
		panic(errors.New(errInvalidPoolPath))
	}

	pToken0, pToken1, fee := res[0], res[1], res[2]
	return pToken0, pToken1, fee
}

// positionIdFrom converts a uint64 position ID to grc721.TokenID.
//
// Parameters:
//   - positionId: Numeric position identifier to encode as a decimal token ID.
//
// Returns:
//   - tokenId: GRC-721 token identifier containing the base-10 representation of positionId.
func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(positionId, 10))
}

// contains checks if a string exists in a slice using case-sensitive equality.
//
// Parameters:
//   - slice: String values to search.
//   - item: Exact string to find in slice.
//
// Returns:
//   - found: True when an element equals item byte-for-byte; false when no element matches.
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
