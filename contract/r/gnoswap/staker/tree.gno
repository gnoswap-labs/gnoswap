package staker

import (
	avl "gno.land/p/nt/avl/v0"
	"gno.land/p/nt/seqid/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// UintTree is a wrapper around an AVL tree for storing block timestamps as strings.
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
	tree *avl.Tree // blockTimestamp -> any
}

// NewUintTree creates a new UintTree instance.
func NewUintTree() *UintTree {
	return &UintTree{
		tree: avl.NewTree(),
	}
}

func (self *UintTree) Get(key int64) (any, bool) {
	v, ok := self.tree.Get(EncodeInt64(key))
	if !ok {
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

func (self *UintTree) Clone() *UintTree {
	if self == nil {
		return nil
	}

	cloned := NewUintTree()
	self.tree.Iterate("", "", func(key string, value any) bool {
		cloned.tree.Set(key, value)
		return false
	})

	return cloned
}

// EncodeUint encodes a uint64 as a compact cford32 string via seqid.
// Output is 7 bytes for values < 2^34, 13 bytes otherwise.
// Lexicographically ordered, suitable for AVL tree keys.
func EncodeUint(num uint64) string {
	return seqid.ID(num).String()
}

func EncodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return EncodeUint(uint64(num))
}

// DecodeUint decodes a cford32-encoded string back into a uint64.
func DecodeUint(s string) uint64 {
	id, err := seqid.FromString(s)
	if err != nil {
		panic(err)
	}
	return uint64(id)
}

func DecodeInt64(s string) int64 {
	return int64(DecodeUint(s))
}

// encodedTickOffset must match pool.ENCODED_TICK_OFFSET (= pool.MAX_TICK).
const encodedTickOffset int32 = 887272

// EncodeInt encodes an int32 tick value as a compact seqid (cford32) string.
// Applies a constant offset to map negative ticks into positive space,
// producing 7-byte lexicographically ordered keys.
func EncodeInt(num int32) string {
	adjusted := num + encodedTickOffset
	if adjusted < 0 {
		panic(ufmt.Sprintf("negative adjusted tick: %d (input: %d)", adjusted, num))
	}
	return seqid.ID(uint64(adjusted)).String()
}

// DecodeInt decodes a seqid-encoded string back into an int32 tick value.
func DecodeInt(s string) int32 {
	id, err := seqid.FromString(s)
	if err != nil {
		panic("invalid encoded int: " + s)
	}
	return int32(uint64(id)) - encodedTickOffset
}
