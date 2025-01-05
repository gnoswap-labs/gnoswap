package staker

import (
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

// EncodeUint converts a uint64 number into a zero-padded 20-character string.
//
// Parameters:
// - num (uint64): The number to encode.
//
// Returns:
// - string: A zero-padded string representation of the number.
//
// Example:
// Input: 12345
// Output: "00000000000000012345"
func EncodeUint(num uint64) string {
	// Convert the value to a decimal string.
	s := strconv.FormatUint(num, 10)

	// Zero-pad to a total length of 20 characters.
	zerosNeeded := 20 - len(s)
	return strings.Repeat("0", zerosNeeded) + s
}

// DecodeUint converts a zero-padded string back into a uint64 number.
//
// Parameters:
// - s (string): The zero-padded string.
//
// Returns:
// - uint64: The decoded number.
//
// Panics:
// - If the string cannot be parsed into a uint64.
//
// Example:
// Input: "00000000000000012345"
// Output: 12345
func DecodeUint(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(err)
	}
	return num
}

// UintTree is a wrapper around an AVL tree for storing uint64 keys as strings.
//
// Methods:
// - Get: Retrieves a value associated with a uint64 key.
// - Set: Stores a value with a uint64 key.
// - Has: Checks if a uint64 key exists in the tree.
// - Remove: Removes a uint64 key and its associated value.
// - Iterate: Iterates over keys and values in a range.
// - ReverseIterate: Iterates in reverse order over keys and values in a range.
type UintTree struct {
	tree *avl.Tree // blockNumber -> interface{}
}

// NewUintTree creates a new UintTree instance.
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

// RewardCacheTree is a wrapper around an AVL tree for managing reward data.
//
// Methods:
// - Get: Retrieves a reward associated with a uint64 key.
// - Set: Stores a reward with a uint64 key.
// - Has: Checks if a uint64 key exists in the tree.
// - Iterate: Iterates over rewards in a range.
// - CurrentReward: Gets the most recent reward for a given height.
// - CurrentRewardAt: Gets the exact reward for a given height (panics if not found).
// - RewardPerInterval: Calculates rewards over an interval using a callback.
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

func (self *RewardCacheTree) CurrentRewardAt(currentHeight uint64) interface{} {
	result, ok := self.tree.Get(EncodeUint(currentHeight))
	if ok {
		return result
	}
	panic(ufmt.Sprintf("RewardCacheTree.CurrentRewardAt() || currentHeight: %d, not found", currentHeight))
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