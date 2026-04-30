package v1

import (
	"strconv"
	"strings"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// stakerDepositKeySeparator separates address and padded deposit id in composite keys.
// Chosen so that the prefix range [addr+sep, addr+sepNext) covers exactly one address's entries.
const (
	stakerDepositKeySeparator         = "|"
	stakerDepositKeySeparatorNextWord = string(int32('|') + 1)
)

// makeStakerDepositKey builds the composite key "addr|paddedDepositId".
func makeStakerDepositKey(addrStr string, depositId uint64) string {
	return addrStr + stakerDepositKeySeparator + EncodeUint(depositId)
}

// stakerDepositKeyRange returns the half-open prefix range covering all composite keys belonging to addrStr.
func stakerDepositKeyRange(addrStr string) (lo, hi string) {
	lo = addrStr + stakerDepositKeySeparator
	hi = addrStr + stakerDepositKeySeparatorNextWord

	return lo, hi
}

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

// formatUint formats an unsigned integer to string.
func formatUint(v any) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type for Unsigned: %T", v))
	}
}

// formatAnyInt formats a signed integer to string.
func formatAnyInt(v any) string {
	switch v := v.(type) {
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case int64:
		return strconv.FormatInt(v, 10)
	case int:
		return strconv.Itoa(v)
	default:
		panic(ufmt.Sprintf("invalid type for Signed: %T", v))
	}
}

// formatBool formats a boolean to string.
func formatBool(v bool) string {
	return strconv.FormatBool(v)
}
