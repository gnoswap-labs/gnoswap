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
