package staker

import (
	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"
	rotree "gno.land/p/nt/bptree/rotree/v0"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// UintTree wraps a B+ tree with nonnegative int64 timestamp keys, encoded as
// fixed-width 8-byte big-endian strings to preserve numeric ordering.
//
// Methods:
// - Get: Retrieves a value associated with an int64 key.
// - Set: Stores a value with an int64 key.
// - Has: Checks if an int64 key exists in the tree.
// - Remove: Removes an int64 key and its associated value.
// - Iterate: Iterates over keys and values in a range.
// - ReverseIterate: Iterates in reverse order over keys and values in a range.
type UintTree struct {
	tree   *bptree.BPTree // blockTimestamp -> any
	fanout int
}

// NewBPTreeN allocates a raw BP-tree under /r/gnoswap/staker's realm
// context (the realm that declares Pool/Deposit/ExternalIncentive). The tree's
// PkgID is therefore /r/gnoswap/staker, matching the domain values it stores,
// so tree.Set leaf-slot writes clear the readonly-taint gate regardless of
// which realm (staker/v1, mock) calls Set (borrow rule #2 borrows m.Realm to
// the tree's owning realm). Implementations and mocks must allocate trees that
// hold /r/gnoswap/staker-declared values through here rather than calling
// bptree.NewBPTreeN directly in their own realm.
//
// Parameters:
//   - fanout: Number of child pointers per B+ tree node; controls the tree's branching factor.
//
// Returns:
//   - tree: Mutable raw B+ tree allocated in the staker realm context.
func NewBPTreeN(fanout int) *bptree.BPTree {
	return bptree.NewBPTreeN(fanout)
}

// NewUintTree creates a new UintTree instance with default fanout 64.
//
// Returns:
//   - tree: Empty UintTree using the default fanout of 64.
func NewUintTree() *UintTree {
	return NewUintTreeN(64)
}

// NewUintTreeN creates a new UintTree instance with the specified fanout.
//
// Parameters:
//   - fanout: Number of child pointers per B+ tree node used by the wrapped tree.
//
// Returns:
//   - tree: Empty UintTree configured with the requested fanout.
func NewUintTreeN(fanout int) *UintTree {
	return &UintTree{
		tree:   bptree.NewBPTreeN(fanout),
		fanout: fanout,
	}
}

// Get looks up a value by its nonnegative int64 key.
//
// Parameters:
//   - key: Nonnegative timestamp-like key encoded into the tree's ordered key format.
//
// Returns:
//   - value: Stored value when the key maps to a non-nil entry; nil when absent.
//   - found: True when a non-nil value exists for key, and false otherwise.
func (self *UintTree) Get(key int64) (any, bool) {
	v := self.tree.Get(encodeInt64(key))
	if v == nil {
		return nil, false
	}
	return v, true
}

// Set stores a value under a nonnegative int64 key.
//
// Parameters:
//   - key: Nonnegative timestamp-like key used as the ordered tree key; negative values panic.
//   - value: Value to associate with key.
func (self *UintTree) Set(key int64, value any) {
	self.tree.Set(encodeInt64(key), value)
}

// Has reports whether an encoded key is present in the underlying tree.
//
// Parameters:
//   - key: Nonnegative timestamp-like key to test; negative values panic during encoding.
//
// Returns:
//   - present: True when the underlying tree contains key, including entries whose value may be nil according to the B+ tree.
func (self *UintTree) Has(key int64) bool {
	return self.tree.Has(encodeInt64(key))
}

// Remove deletes the value stored under a key, if any.
//
// Parameters:
//   - key: Nonnegative timestamp-like key to remove; negative values panic during encoding.
func (self *UintTree) Remove(key int64) {
	self.tree.Remove(encodeInt64(key))
}

// Iterate visits entries in ascending key order over the underlying tree range.
//
// Parameters:
//   - start: Nonnegative lower bound for the encoded key range.
//   - end: Nonnegative upper bound for the encoded key range.
//   - fn: Callback receiving each decoded key and value; returning true requests that iteration stop.
func (self *UintTree) Iterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.Iterate(encodeInt64(start), encodeInt64(end), func(key string, value any) bool {
		return fn(decodeInt64(key), value)
	})
}

// ReverseIterate visits entries in descending key order over the underlying tree range.
//
// Parameters:
//   - start: Nonnegative lower bound for the encoded key range.
//   - end: Nonnegative upper bound for the encoded key range.
//   - fn: Callback receiving each decoded key and value; returning true requests that iteration stop.
func (self *UintTree) ReverseIterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.ReverseIterate(encodeInt64(start), encodeInt64(end), func(key string, value any) bool {
		return fn(decodeInt64(key), value)
	})
}

// Size returns the number of entries currently stored in the tree.
//
// Returns:
//   - size: Number of key/value entries in the underlying B+ tree.
func (self *UintTree) Size() int {
	return self.tree.Size()
}

// IterateByOffset visits a page of entries beginning at an offset.
//
// Parameters:
//   - offset: Zero-based number of entries to skip before invoking fn.
//   - count: Maximum number of entries to visit.
//   - fn: Callback receiving each decoded key and value; returning true requests that iteration stop.
func (self *UintTree) IterateByOffset(offset, count int, fn func(key int64, value any) bool) {
	self.tree.IterateByOffset(offset, count, func(key string, value any) bool {
		return fn(decodeInt64(key), value)
	})
}

// ReadOnly returns a read-only view of the underlying tree, so callers can
// paginate it without gaining a handle on the mutable tree.
//
// Keys use utils.EncodeUint64's fixed-width binary encoding, not the int64
// keys this type takes; utils.DecodeUint64 recovers the nonnegative value.
//
// Parameters:
//   - makeEntrySafeFn: Callback that converts each stored value into the representation exposed through the read-only view.
//
// Returns:
//   - tree: Read-only wrapper over the underlying tree for safe pagination.
func (self *UintTree) ReadOnly(makeEntrySafeFn func(any) any) *rotree.ReadOnlyTree {
	return rotree.Wrap(self.tree, makeEntrySafeFn)
}

// Clone returns a new UintTree with the same encoded keys and stored value references.
//
// Returns:
//   - tree: New UintTree preserving this tree's fanout and entries; pointed-to values are not deep-cloned.
func (self *UintTree) Clone() *UintTree {
	if self == nil {
		return nil
	}

	cloned := NewUintTreeN(self.fanout)
	self.tree.Iterate("", "", func(key string, value any) bool {
		cloned.tree.Set(key, value)
		return false
	})

	return cloned
}

// encodeInt64 converts a nonnegative int64 to the fixed-width ordered key encoding.
//
// Parameters:
//   - num: Nonnegative integer to encode; negative values panic because the tree key space is nonnegative.
//
// Returns:
//   - encoded: Fixed-width big-endian string whose lexicographic order matches num order.
func encodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return utils.EncodeUint64(uint64(num))
}

// decodeInt64 converts a fixed-width encoded unsigned key back to int64.
//
// Parameters:
//   - s: Fixed-width big-endian string produced by encodeInt64 or the corresponding unsigned encoder.
//
// Returns:
//   - num: Decoded signed integer value.
func decodeInt64(s string) int64 {
	return gnsmath.SafeUint64ToInt64(utils.DecodeUint64(s))
}
