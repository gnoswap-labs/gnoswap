package v1

import (
	"math"
	"strconv"

	avl "gno.land/p/nt/avl/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/p/onbloc/json"
)

// marshal data to json string
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
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
		newValue = safeAddUint64(current, delta)
	} else {
		if current < delta {
			panic(makeErrorWithDetails(
				errNotEnoughBalance,
				ufmt.Sprintf("not enough balance: current(%d) < requested(%d)", current, delta),
			))
		}
		newValue = safeSubUint64(current, delta)
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

// safeAddUint64 performs safe addition of uint64 values, panicking on overflow
func safeAddUint64(a, b uint64) uint64 {
	if a > math.MaxUint64-b {
		panic("uint64 addition overflow")
	}

	return a + b
}

// safeSubUint64 performs safe subtraction of uint64 values, panicking on underflow
func safeSubUint64(a, b uint64) uint64 {
	if a < b {
		panic("uint64 subtraction underflow")
	}

	return a - b
}
