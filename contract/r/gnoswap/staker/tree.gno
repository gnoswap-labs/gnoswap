package staker

import (
	"strconv"
	"strings"

	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/v0/rotree"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"
)

// UintTree is a wrapper around a B+ tree for storing block timestamps as strings.
// Since block timestamps are defined as int64, we take int64 and convert it to uint64 for the tree.
//
// Methods:
// - Get: Retrieves a value associated with a uint64 key.
// - Set: Stores a value with a uint64 key.
// - Has: Checks if a uint64 key exists in the tree.
// - Remove: Removes a uint64 key and its associated value.
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
func NewBPTreeN(fanout int) *bptree.BPTree {
	return bptree.NewBPTreeN(fanout)
}

// NewUintTree creates a new UintTree instance with default fanout 64.
func NewUintTree() *UintTree {
	return NewUintTreeN(64)
}

// NewUintTreeN creates a new UintTree instance with the specified fanout.
func NewUintTreeN(fanout int) *UintTree {
	return &UintTree{
		tree:   bptree.NewBPTreeN(fanout),
		fanout: fanout,
	}
}

func (self *UintTree) Get(key int64) (any, bool) {
	v := self.tree.Get(EncodeInt64(key))
	if v == nil {
		return nil, false
	}
	return v, true
}

func (self *UintTree) Set(key int64, value any) {
	self.tree.Set(EncodeInt64(key), value)
}

func (self *UintTree) Has(key int64) bool {
	return self.tree.Has(EncodeInt64(key))
}

func (self *UintTree) Remove(key int64) {
	self.tree.Remove(EncodeInt64(key))
}

func (self *UintTree) Iterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.Iterate(EncodeInt64(start), EncodeInt64(end), func(key string, value any) bool {
		return fn(DecodeInt64(key), value)
	})
}

func (self *UintTree) ReverseIterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.ReverseIterate(EncodeInt64(start), EncodeInt64(end), func(key string, value any) bool {
		return fn(DecodeInt64(key), value)
	})
}

func (self *UintTree) Size() int {
	return self.tree.Size()
}

func (self *UintTree) IterateByOffset(offset, count int, fn func(key int64, value any) bool) {
	self.tree.IterateByOffset(offset, count, func(key string, value any) bool {
		return fn(DecodeInt64(key), value)
	})
}

// ReadOnly returns a read-only view of the underlying tree, so callers can
// paginate it without gaining a handle on the mutable tree.
//
// Keys are the fixed-width binary encoding produced by EncodeInt64, not the
// int64 keys this type takes; use DecodeInt64 to recover them.
func (self *UintTree) ReadOnly(makeEntrySafeFn func(any) any) *rotree.ReadOnlyTree {
	return rotree.Wrap(self.tree, makeEntrySafeFn)
}

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

func EncodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return utils.EncodeUint64(uint64(num))
}

func DecodeInt64(s string) int64 {
	return gnsmath.SafeUint64ToInt64(utils.DecodeUint64(s))
}

// EncodeInt takes an int32 and returns a zero-padded decimal string
// with up to 10 digits for the absolute value.
// If the number is negative, the '-' sign comes first, followed by zeros, then digits.
func EncodeInt(num int32) string {
	// Convert the absolute value to a decimal string.
	absValue := int64(num)
	isNegative := false
	if num < 0 {
		isNegative = true
		absValue = -absValue // Safely negate into int64 to avoid overflow.
	}

	s := strconv.FormatInt(absValue, 10)

	// Zero-pad to a total of 10 digits for the absolute value.
	// (The '-' sign will be added later if needed.)
	zerosNeeded := 10 - len(s)
	if zerosNeeded < 0 {
		zerosNeeded = 0
	}

	padded := strings.Repeat("0", zerosNeeded) + s

	// If the original number was negative, prepend '-'.
	if isNegative {
		return "-" + padded
	}
	return padded
}
