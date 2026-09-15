package staker

import (
	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// UintTree is a wrapper around a BPTree for storing non-negative int64 keys as
// ordered strings. Depending on the caller, keys represent Unix timestamps,
// accrual epochs, or stake-event indexes.
//
// Since keys are int64 values, they are converted to uint64-compatible strings.
//
// Methods:
// - Get: Retrieves a value associated with a non-negative int64 key.
// - set: Stores a value with a non-negative int64 key.
// - Has: Checks if a non-negative int64 key exists in the tree.
// - remove: Removes a non-negative int64 key and its associated value.
// - Iterate: Iterates over keys and values in a range.
// - ReverseIterate: Iterates in reverse order over keys and values in a range.
type UintTree struct {
	tree *bptree.BPTree // non-negative int64 key -> any
}

// NewUintTree creates a new UintTree instance.
//
// Returns:
//   - *UintTree: new tree backed by an empty ordered BPTree
func NewUintTree() *UintTree {
	return &UintTree{
		tree: bptree.NewBPTreeN(64),
	}
}

// Get looks up a value by its non-negative int64 key.
//
// Parameters:
//   - key: non-negative int64 key encoded for the ordered tree lookup; a negative key panics
//
// Returns:
//   - any: value stored at key, or nil when no entry exists
//   - bool: true when key has an entry; false when absent
func (self *UintTree) Get(key int64) (any, bool) {
	v := self.tree.Get(encodeInt64(key))
	if v == nil {
		return nil, false
	}
	return v, true
}

// Set associates a value with a non-negative int64 key, replacing any existing
// value at that key.
//
// Parameters:
//   - key: non-negative int64 key to encode and store; a negative key panics
//   - value: value to associate with key
func (self *UintTree) Set(key int64, value any) {
	self.tree.Set(encodeInt64(key), value)
}

// Has checks whether a non-negative int64 key is present in the tree.
//
// Parameters:
//   - key: non-negative int64 key to encode and test; a negative key panics
//
// Returns:
//   - bool: true when key is present; false when no entry is stored at key
func (self *UintTree) Has(key int64) bool {
	return self.tree.Has(encodeInt64(key))
}

// Remove deletes the entry associated with a non-negative int64 key, if one
// exists.
//
// Parameters:
//   - key: non-negative int64 key to encode and remove; a negative key panics
func (self *UintTree) Remove(key int64) {
	self.tree.Remove(encodeInt64(key))
}

// Iterate visits entries in the half-open [start, end) key range in ascending
// order.
//
// Parameters:
//   - start: non-negative lower-bound key for the iteration range; a negative bound panics
//   - end: non-negative upper-bound key for the iteration range; a negative bound panics
//   - fn: callback receiving each decoded key and value; return true to stop iteration, or false to continue
func (self *UintTree) Iterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.Iterate(encodeInt64(start), encodeInt64(end), func(key string, value any) bool {
		return fn(decodeInt64(key), value)
	})
}

// ReverseIterate visits entries in descending order over the half-open
// [start, end) key range.
//
// Parameters:
//   - start: non-negative lower-bound key for the iteration range; a negative bound panics
//   - end: non-negative upper-bound key for the iteration range; a negative bound panics
//   - fn: callback receiving each decoded key and value; return true to stop iteration, or false to continue
func (self *UintTree) ReverseIterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.ReverseIterate(encodeInt64(start), encodeInt64(end), func(key string, value any) bool {
		return fn(decodeInt64(key), value)
	})
}

// Size returns the number of entries in the tree.
//
// Returns:
//   - int: number of key-value entries currently stored in the tree
func (self *UintTree) Size() int {
	return self.tree.Size()
}

// encodeInt64 converts a non-negative int64 key to the ordered uint64-compatible
// string representation used by UintTree.
//
// Parameters:
//   - num: non-negative int64 key to encode; a negative value panics
//
// Returns:
//   - string: ordered string encoding of num
func encodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return utils.EncodeUint64(uint64(num))
}

// decodeInt64 converts an encoded uint64-compatible tree key back to int64.
//
// Parameters:
//   - s: ordered string representation produced by encodeInt64
//
// Returns:
//   - int64: decoded tree key
func decodeInt64(s string) int64 {
	return gnsmath.SafeUint64ToInt64(utils.DecodeUint64(s))
}
