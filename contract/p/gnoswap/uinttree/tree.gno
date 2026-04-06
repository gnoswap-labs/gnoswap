package uinttree

import (
	"strconv"
	"strings"

	avl "gno.land/p/nt/avl/v0"
)

type UintTree struct {
	tree *avl.Tree
}

func NewUintTree() *UintTree {
	return &UintTree{tree: avl.NewTree()}
}

func (self *UintTree) Get(key uint64) (any, bool) {
	v, ok := self.tree.Get(EncodeUint(key))
	if !ok {
		return nil, false
	}
	return v, true
}

func (self *UintTree) GetByInt64(key int64) (any, bool) {
	return self.Get(SafeConvertInt64ToUint64(key))
}

func (self *UintTree) Set(key uint64, value any) {
	self.tree.Set(EncodeUint(key), value)
}

func (self *UintTree) SetByInt64(key int64, value any) {
	self.Set(SafeConvertInt64ToUint64(key), value)
}

func (self *UintTree) Has(key uint64) bool {
	return self.tree.Has(EncodeUint(key))
}

func (self *UintTree) HasByInt64(key int64) bool {
	return self.Has(SafeConvertInt64ToUint64(key))
}

func (self *UintTree) Remove(key uint64) {
	self.tree.Remove(EncodeUint(key))
}

func (self *UintTree) RemoveByInt64(key int64) {
	self.Remove(SafeConvertInt64ToUint64(key))
}

func (self *UintTree) Iterate(start, end uint64, fn func(key uint64, value any) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(key string, value any) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) IterateByInt64(start, end int64, fn func(key uint64, value any) bool) {
	self.Iterate(SafeConvertInt64ToUint64(start), SafeConvertInt64ToUint64(end), fn)
}

func (self *UintTree) ReverseIterate(start, end uint64, fn func(key uint64, value any) bool) {
	self.tree.ReverseIterate(EncodeUint(start), EncodeUint(end), func(key string, value any) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) ReverseIterateByInt64(start, end int64, fn func(key uint64, value any) bool) {
	self.ReverseIterate(SafeConvertInt64ToUint64(start), SafeConvertInt64ToUint64(end), fn)
}

func (self *UintTree) Size() int {
	return self.tree.Size()
}

func (self *UintTree) IterateByOffset(offset, count int, fn func(key uint64, value any) bool) {
	self.tree.IterateByOffset(offset, count, func(key string, value any) bool {
		return fn(DecodeUint(key), value)
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

func SafeConvertInt64ToUint64(value int64) uint64 {
	if value < 0 {
		panic("value must be non-negative")
	}

	return uint64(value)
}

func EncodeUint(num uint64) string {
	s := strconv.FormatUint(num, 10)
	zerosNeeded := 20 - len(s)
	return strings.Repeat("0", zerosNeeded) + s
}

func DecodeUint(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err)
	}
	return num
}
