package staker

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"
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
	v := self.tree.Get(encodeInt64(key))
	if v == nil {
		return nil, false
	}
	return v, true
}

func (self *UintTree) Set(key int64, value any) {
	self.tree.Set(encodeInt64(key), value)
}

func (self *UintTree) Has(key int64) bool {
	return self.tree.Has(encodeInt64(key))
}

func (self *UintTree) Remove(key int64) {
	self.tree.Remove(encodeInt64(key))
}

func (self *UintTree) Iterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.Iterate(encodeInt64(start), encodeInt64(end), func(key string, value any) bool {
		return fn(decodeInt64(key), value)
	})
}

func (self *UintTree) ReverseIterate(start, end int64, fn func(key int64, value any) bool) {
	self.tree.ReverseIterate(encodeInt64(start), encodeInt64(end), func(key string, value any) bool {
		return fn(decodeInt64(key), value)
	})
}

// Size returns the number of entries in the tree.
func (self *UintTree) Size() int {
	return self.tree.Size()
}

func encodeInt64(num int64) string {
	if num < 0 {
		panic(ufmt.Sprintf("negative value not supported: %d", num))
	}
	return utils.EncodeUint64(uint64(num))
}

func decodeInt64(s string) int64 {
	return gnsmath.SafeUint64ToInt64(utils.DecodeUint64(s))
}
