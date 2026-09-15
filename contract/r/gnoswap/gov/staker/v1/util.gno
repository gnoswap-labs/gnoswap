package staker

import (
	"strconv"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/p/onbloc/json/v0"
)

// marshal serializes a JSON node to its compact JSON string representation.
//
// Parameters:
//   - data: JSON node to serialize; serialization failures panic
//
// Returns:
//   - string: serialized JSON document
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

// getUint64FromTree reads a uint64 value from tree at key.
// A missing key returns zero; a stored value of another type panics.
//
// Parameters:
//   - tree: B+ tree containing uint64 values keyed by strings
//   - key: string key whose value is read
//
// Returns:
//   - uint64: stored value, or zero when key is absent
func getUint64FromTree(tree *bptree.BPTree, key string) uint64 {
	value := tree.Get(key)
	if value == nil {
		return 0
	}

	v, ok := value.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast value to uint64: %T", value))
	}

	return v
}

// updateUint64InTree adds or subtracts delta from the uint64 value at key,
// stores the result, and returns it. Subtraction below zero panics.
//
// Parameters:
//   - tree: B+ tree containing the value to update
//   - key: string key whose value is changed
//   - delta: nonnegative uint64 amount to add or subtract
//   - add: true to add delta; false to subtract delta after checking the balance
//
// Returns:
//   - uint64: updated value stored at key
func updateUint64InTree(tree *bptree.BPTree, key string, delta uint64, add bool) uint64 {
	current := getUint64FromTree(tree, key)
	var newValue uint64
	if add {
		newValue = gnsmath.SafeAddUint64(current, delta)
	} else {
		if current < delta {
			panic(makeErrorWithDetails(
				errNotEnoughBalance,
				ufmt.Sprintf("not enough balance: current(%d) < requested(%d)", current, delta),
			))
		}
		newValue = gnsmath.SafeSubUint64(current, delta)
	}

	tree.Set(key, newValue)

	return newValue
}

// milliToSec converts milliseconds to whole seconds using integer division.
//
// Parameters:
//   - ms: duration in milliseconds; fractional seconds are truncated toward zero
//
// Returns:
//   - int64: whole-second result of dividing ms by 1000
func milliToSec(ms int64) int64 {
	var msPerSec int64 = 1000
	return ms / msPerSec
}

// userHistoryKeySeparator is chosen to be lexicographically smaller than any
const (
	userHistoryKeySeparator         = "|"
	userHistoryKeySeparatorNextWord = string(int32('|') + 1)
)

// userHistoryTimestampWidth is the zero-padded width that fits the maximum
const userHistoryTimestampWidth = 20

// makeUserHistoryKey builds the composite key "addr|paddedTimestamp" used in the user delegation history BPTree.
//
// Parameters:
//   - addrStr: address string used as the key prefix
//   - timestamp: history timestamp encoded with padTimestamp
//
// Returns:
//   - string: address, separator, and zero-padded timestamp concatenated as one key
func makeUserHistoryKey(addrStr string, timestamp int64) string {
	return addrStr + userHistoryKeySeparator + padTimestamp(timestamp)
}

// userHistoryKeyRange returns the half-open prefix range that covers all composite keys belonging to addrStr.
//
// Parameters:
//   - addrStr: address string whose history keys form the prefix range
//
// Returns:
//   - lo: inclusive lower bound ending with the history key separator
//   - hi: exclusive upper bound immediately after that separator prefix
func userHistoryKeyRange(addrStr string) (lo, hi string) {
	lo = addrStr + userHistoryKeySeparator
	hi = addrStr + userHistoryKeySeparatorNextWord

	return lo, hi
}

// padTimestamp left-pads timestamp with zeros to userHistoryTimestampWidth so
// that lexicographic ordering of the resulting strings matches numeric order.
//
// Parameters:
//   - timestamp: int64 timestamp to format in base ten
//
// Returns:
//   - string: decimal timestamp padded to width 20 when shorter, otherwise unchanged
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
//
// Parameters:
//   - key: composite address-and-timestamp key to parse
//
// Returns:
//   - addrStr: address prefix before the final separator
//   - timestamp: parsed base-ten timestamp suffix, or zero when parsing fails
//   - ok: true when a separator exists and the suffix parses as int64; false otherwise
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
