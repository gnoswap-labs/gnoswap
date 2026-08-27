package staker

import (
	"math"
	"strconv"
	"strings"

	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/v0/rotree"
	ufmt "gno.land/p/nt/ufmt/v0"
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

// EncodeUint converts a uint64 number into a fixed-width 8-byte big-endian string.
//
// Parameters:
// - num (uint64): The number to encode.
//
// Returns:
// - string: An 8-byte binary string representation of the number.
//
// Big-endian encoding preserves numeric ordering under the B+ tree's
// lexicographic key ordering.
func EncodeUint(num uint64) string {
	var buf [8]byte
	buf[0] = byte(num >> 56)
	buf[1] = byte(num >> 48)
	buf[2] = byte(num >> 40)
	buf[3] = byte(num >> 32)
	buf[4] = byte(num >> 24)
	buf[5] = byte(num >> 16)
	buf[6] = byte(num >> 8)
	buf[7] = byte(num)
	return string(buf[:])
}

func EncodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return EncodeUint(uint64(num))
}

// DecodeUint converts an 8-byte big-endian string back into a uint64 number.
//
// Parameters:
// - s (string): The 8-byte binary string to decode.
//
// Returns:
// - uint64: The decoded number.
//
// Panics:
// - If s is not exactly 8 bytes long.
func DecodeUint(s string) uint64 {
	if len(s) != 8 {
		panic(ufmt.Sprintf("invalid uint64 key length: %d", len(s)))
	}
	return uint64(s[0])<<56 |
		uint64(s[1])<<48 |
		uint64(s[2])<<40 |
		uint64(s[3])<<32 |
		uint64(s[4])<<24 |
		uint64(s[5])<<16 |
		uint64(s[6])<<8 |
		uint64(s[7])
}

func DecodeInt64(s string) int64 {
	num := DecodeUint(s)
	if num > uint64(math.MaxInt64) {
		panic(ufmt.Sprintf("uint64 key overflows int64: %d", num))
	}
	return int64(num)
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
