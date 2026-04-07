package v1

import (
	"math"
	"strconv"

	bptree "gno.land/p/nt/bptree/v0"
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
func getUint64FromTree(tree *bptree.BPTree, key string) uint64 {
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
func updateUint64InTree(tree *bptree.BPTree, key string, delta uint64, add bool) uint64 {
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
func getOrCreateInnerTree(tree *bptree.BPTree, key string) *bptree.BPTree {
	value, exists := tree.Get(key)
	if !exists {
		innerTree := bptree.NewBPTreeN(16)
		tree.Set(key, innerTree)
		return innerTree
	}

	v, ok := value.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast value to *bptree.BPTree: %T", value))
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

// userHistoryKeySeparator is chosen to be lexicographically smaller than any
const (
	userHistoryKeySeparator         = "|"
	userHistoryKeySeparatorNextWord = string(int32('|') + 1)
)

// userHistoryTimestampWidth is the zero-padded width that fits the maximum
const userHistoryTimestampWidth = 20

// makeUserHistoryKey builds the composite key "addr|paddedTimestamp" used in the user delegation history BPTree.
func makeUserHistoryKey(addrStr string, timestamp int64) string {
	return addrStr + userHistoryKeySeparator + padTimestamp(timestamp)
}

// userHistoryKeyRange returns the half-open prefix range that covers all composite keys belonging to addrStr.
func userHistoryKeyRange(addrStr string) (lo, hi string) {
	lo = addrStr + userHistoryKeySeparator
	hi = addrStr + userHistoryKeySeparatorNextWord

	return lo, hi
}

// padTimestamp left-pads timestamp with zeros to userHistoryTimestampWidth so
// that lexicographic ordering of the resulting strings matches numeric order.
func padTimestamp(timestamp int64) string {
	s := strconv.FormatInt(timestamp, 10)
	if len(s) >= userHistoryTimestampWidth {
		return s
	}

	pad := make([]byte, userHistoryTimestampWidth-len(s))
	for i := range pad {
		pad[i] = '0'
	}

	return string(pad) + s
}

// parseUserHistoryKey splits a composite key produced by makeUserHistoryKey back into its address and timestamp components.
func parseUserHistoryKey(key string) (addrStr string, timestamp int64, ok bool) {
	for i := len(key) - 1; i >= 0; i-- {
		if key[i] == userHistoryKeySeparator[0] {
			ts, err := strconv.ParseInt(key[i+1:], 10, 64)
			if err != nil {
				return "", 0, false
			}

			return key[:i], ts, true
		}
	}

	return "", 0, false
}
