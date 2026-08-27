package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/p/gnoswap/gnsmath"
)

// UintTree is a wrapper around a BPTree for storing block timestamps as strings.
// Since block timestamps are defined as int64, we take int64 and convert it to uint64 for the tree.
//
// Methods:
// - Get: Retrieves a value associated with a uint64 key.
// - set: Stores a value with a uint64 key.
// - Has: Checks if a uint64 key exists in the tree.
// - remove: Removes a uint64 key and its associated value.
// - Iterate: Iterates over keys and values in a range.
// - ReverseIterate: Iterates in reverse order over keys and values in a range.
type UintTree struct {
	tree *bptree.BPTree // blockTimestamp -> any
}

// NewUintTree creates a new UintTree instance.
func NewUintTree() *UintTree {
	return &UintTree{
		tree: bptree.NewBPTreeN(64),
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

// Size returns the number of entries in the tree.
func (self *UintTree) Size() int {
	return self.tree.Size()
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
	return gnsmath.SafeUint64ToInt64(DecodeUint(s))
}
