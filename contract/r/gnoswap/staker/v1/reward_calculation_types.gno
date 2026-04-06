package v1

import utree "gno.land/p/gnoswap/uinttree"

func EncodeUint(num uint64) string {
	return utree.EncodeUint(num)
}

func DecodeUint(s string) uint64 {
	return utree.DecodeUint(s)
}

type UintTree struct {
	*utree.UintTree
}

func NewUintTree() *UintTree {
	return &UintTree{UintTree: utree.NewUintTree()}
}

func (self *UintTree) set(key uint64, value any) {
	self.Set(key, value)
}

func (self *UintTree) remove(key uint64) {
	self.Remove(key)
}

func (self *UintTree) Get(key uint64) (any, bool) {
	return self.UintTree.Get(key)
}

func (self *UintTree) GetByInt64(key int64) (any, bool) {
	return self.UintTree.GetByInt64(key)
}

func (self *UintTree) Set(key uint64, value any) {
	self.UintTree.Set(key, value)
}

func (self *UintTree) SetByInt64(key int64, value any) {
	self.UintTree.SetByInt64(key, value)
}

func (self *UintTree) Has(key uint64) bool {
	return self.UintTree.Has(key)
}

func (self *UintTree) Remove(key uint64) {
	self.UintTree.Remove(key)
}

func (self *UintTree) RemoveByInt64(key int64) {
	self.UintTree.RemoveByInt64(key)
}

func (self *UintTree) Iterate(start, end uint64, fn func(key uint64, value any) bool) {
	self.UintTree.Iterate(start, end, fn)
}

func (self *UintTree) IterateByInt64(start, end int64, fn func(key uint64, value any) bool) {
	self.UintTree.IterateByInt64(start, end, fn)
}

func (self *UintTree) ReverseIterate(start, end uint64, fn func(key uint64, value any) bool) {
	self.UintTree.ReverseIterate(start, end, fn)
}

func (self *UintTree) ReverseIterateByInt64(start, end int64, fn func(key uint64, value any) bool) {
	self.UintTree.ReverseIterateByInt64(start, end, fn)
}
