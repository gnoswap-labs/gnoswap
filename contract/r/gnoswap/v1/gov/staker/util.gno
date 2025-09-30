package staker

import (
	b64 "encoding/base64"
	"strconv"

	"gno.land/p/nt/avl"
	"gno.land/p/onbloc/json"
	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

// marshal data to json string
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

// b64Encode encodes data to base64 string
func b64Encode(data string) string {
	return string(b64.StdEncoding.EncodeToString([]byte(data)))
}

// formatUint formats a uint64 to a string
func formatUint(v uint64) string {
	return strconv.FormatUint(v, 10)
}

// formatInt formats an int64 to a string
func formatInt(v int64) string {
	return strconv.FormatInt(v, 10)
}

// getUint64FromTree returns the uint64 value from the tree
func getUint64FromTree(tree *avl.Tree, key string) uint64 {
	value, exists := tree.Get(key)
	if !exists {
		return 0
	}

	v, ok := value.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast value to uint64: %T", value))
	}

	return v
}

// updateUint64InTree updates the uint64 value in the tree
func updateUint64InTree(tree *avl.Tree, key string, delta uint64, add bool) uint64 {
	current := getUint64FromTree(tree, key)
	var newValue uint64
	if add {
		newValue = current + delta
	} else {
		if current < delta {
			panic(makeErrorWithDetails(
				errNotEnoughBalance,
				ufmt.Sprintf("not enough balance: current(%d) < requested(%d)", current, delta),
			))
		}
		newValue = current - delta
	}

	tree.Set(key, newValue)

	return newValue
}

// getOrCreateInnerTree returns the inner tree for the given key
func getOrCreateInnerTree(tree *avl.Tree, key string) *avl.Tree {
	value, exists := tree.Get(key)
	if !exists {
		innerTree := avl.NewTree()
		tree.Set(key, innerTree)
		return innerTree
	}

	v, ok := value.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast value to *avl.Tree: %T", value))
	}

	return v
}

// milliToSec converts milliseconds to seconds
func milliToSec(ms int64) int64 {
	var msPerSec int64 = 1000
	return ms / msPerSec
}

// safeConvertToInt64 safely converts a *u256.Uint value to an int64, ensuring no overflow.
//
// This function attempts to convert the given *u256.Uint value to an int64. If the value exceeds
// the maximum allowable range for int64 (`2^63 - 1`), it triggers a panic with a descriptive error message.
//
// Parameters:
// - value (*u256.Uint): The unsigned 256-bit integer to be converted.
//
// Returns:
// - int64: The converted value if it falls within the int64 range.
//
// Panics:
//   - If the `value` exceeds the range of int64, the function will panic with an error indicating
//     the overflow and the original value.
func safeConvertToInt64(value *u256.Uint) int64 {
	const INT64_MAX = 9223372036854775807
	const MAX_INT64 = "9223372036854775807"

	res, overflow := value.Uint64WithOverflow()
	if overflow || res > uint64(INT64_MAX) {
		panic(ufmt.Sprintf(
			"amount(%s) overflows int64 range (max %s)",
			value.ToString(),
			MAX_INT64,
		))
	}
	return int64(res)
}
