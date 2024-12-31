package staker

import (
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
)

func EncodeUint(num uint64) string {
	// Convert the value to a decimal string.
	s := strconv.FormatUint(num, 10)

	// Zero-pad to a total length of 20 characters.
	zerosNeeded := 20 - len(s)
	return strings.Repeat("0", zerosNeeded) + s
}

func DecodeUint(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err.Error())
	}
	return num
}

type UintTree struct {
	tree *avl.Tree // blockNumber -> interface{}
}

func NewUintTree() *UintTree {
	return &UintTree{
		tree: avl.NewTree(),
	}
}

func (self *UintTree) Get(key uint64) (interface{}, bool) {
	v, ok := self.tree.Get(EncodeUint(key))
	if !ok {
		return nil, false
	}
	return v, true
}

func (self *UintTree) Set(key uint64, value interface{}) {
	self.tree.Set(EncodeUint(key), value)
}

func (self *UintTree) Has(key uint64) bool {
	return self.tree.Has(EncodeUint(key))
}

func (self *UintTree) Remove(key uint64) {
	self.tree.Remove(EncodeUint(key))
}

func (self *UintTree) Iterate(start, end uint64, fn func(key uint64, value interface{}) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(key string, value interface{}) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) ReverseIterate(start, end uint64, fn func(key uint64, value interface{}) bool) {
	self.tree.ReverseIterate(EncodeUint(start), EncodeUint(end), func(key string, value interface{}) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *UintTree) Size() uint64 {
	return uint64(self.tree.Size())
}

type RewardCacheTree struct {
	tree *avl.Tree
}

func NewRewardCacheTree() *RewardCacheTree {
	return &RewardCacheTree{
		tree: avl.NewTree(),
	}
}

func (self *RewardCacheTree) Get(key uint64) (interface{}, bool) {
	v, ok := self.tree.Get(EncodeUint(key))
	if !ok {
		return nil, false
	}
	return v, true
}

func (self *RewardCacheTree) Set(key uint64, value interface{}) {
	self.tree.Set(EncodeUint(key), value)
}

func (self *RewardCacheTree) Has(key uint64) bool {
	return self.tree.Has(EncodeUint(key))
}

func (self *RewardCacheTree) Iterate(start, end uint64, fn func(key uint64, value interface{}) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(key string, value interface{}) bool {
		return fn(DecodeUint(key), value)
	})
}

func (self *RewardCacheTree) Size() uint64 {
	return uint64(self.tree.Size())
}

func (self *RewardCacheTree) CurrentReward(currentHeight uint64) interface{} {
	result, ok := self.tree.Get(EncodeUint(currentHeight))
	if ok {
		return result
	}
	self.tree.ReverseIterate("", EncodeUint(currentHeight), func(key string, value interface{}) bool {
		result = value
		return true
	})
	return result
}

type RewardCalculationFunc = func(blockNumbers uint64, poolReward interface{})

func (self *RewardCacheTree) RewardPerInterval(startHeight, endHeight uint64, f RewardCalculationFunc) {
	currentPoolReward := self.CurrentReward(startHeight)
	currentHeight := startHeight
	self.Iterate(startHeight, endHeight, func(height uint64, poolReward interface{}) bool {
		f(height-currentHeight, currentPoolReward)
		currentHeight = height
		currentPoolReward = poolReward
		return false
	})
	if endHeight > currentHeight {
		f(endHeight-currentHeight, currentPoolReward)
	}
}
