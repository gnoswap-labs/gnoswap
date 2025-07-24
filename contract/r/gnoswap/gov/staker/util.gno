package staker

import (
	b64 "encoding/base64"
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
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

	return value.(uint64)
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

	return value.(*avl.Tree)
}

// milliToSec converts milliseconds to seconds
func milliToSec(ms int64) int64 {
	return ms / consts.MILLISECONDS_PER_SECOND
}
