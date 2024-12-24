package staker

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/avl"

	u256 "gno.land/p/gnoswap/uint256"
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
		panic(err)
	}
	return num
}

type UintTree struct {
	tree *avl.Tree
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

func (self *RewardCacheTree) EligibleIntervalToReward(interval Interval, warmupIndex int, warmup Warmup, f func(int, Warmup, uint64, *u256.Uint, interface{})) {
	poolReward := self.CurrentReward(interval.StartHeight)
	currentHeight := interval.StartHeight
	self.Iterate(interval.StartHeight, interval.EndHeight, func(height uint64, value interface{}) bool {

		f(warmupIndex, warmup, height-currentHeight, interval.Value, poolReward)
		currentHeight = height
		poolReward = value
		return false
	})
	f(warmupIndex, warmup, interval.EndHeight-currentHeight, interval.Value, poolReward)
}


func (self *RewardCacheTree) EligibleIntervalsToReward(intervals []Interval, deposit *Deposit, f func(int, Warmup, uint64, *u256.Uint, interface{})) {
	currentWarmupIndex := deposit.FindWarmup(intervals[0].StartHeight)
	currentWarmup := deposit.GetWarmup(currentWarmupIndex)

	for _, interval := range intervals {
		for interval.StartHeight >= currentWarmup.NextWarmupHeight {
			currentWarmupIndex++
			currentWarmup = deposit.GetWarmup(currentWarmupIndex)
		}
		if interval.EndHeight < currentWarmup.NextWarmupHeight {
			// fully submerged in the current warmup
			self.EligibleIntervalToReward(interval, currentWarmupIndex, currentWarmup, f)
			continue
		}
		// split
		for currentWarmup.NextWarmupHeight < interval.EndHeight {
			currentInterval, nextInterval := interval.Split(currentWarmup.NextWarmupHeight)
			self.EligibleIntervalToReward(currentInterval, currentWarmupIndex, currentWarmup, f)
			interval = nextInterval
			currentWarmupIndex++
			currentWarmup = deposit.GetWarmup(currentWarmupIndex)
		}
		if !interval.IsEmpty() {
			self.EligibleIntervalToReward(interval, currentWarmupIndex, currentWarmup, f)
		}
	}
}

type Interval struct {
	StartHeight uint64
	EndHeight   uint64
	Value       *u256.Uint
}

func (self Interval) Split(height uint64) (Interval, Interval) {
	return Interval{
		StartHeight: self.StartHeight,
		EndHeight:   height,
		Value:       self.Value,
	}, Interval{
		StartHeight: height,
		EndHeight:   self.EndHeight,
		Value:       self.Value,
	}
}

func (self Interval) IsEmpty() bool {
	return self.StartHeight == self.EndHeight
}

func appendIntervals(intervals []Interval, updatesFn func(uint64, uint64) ([]uint64, []*u256.Uint), value *u256.Uint, startHeight, endHeight uint64) []Interval {
	if startHeight == endHeight {
		return intervals
	}

	heights, updates := updatesFn(startHeight, endHeight)

	if len(updates) == 0 {
		return append(intervals, Interval{
			StartHeight: startHeight,
			EndHeight:   endHeight,
			Value:       value,
		})
	}

	if heights[0] != startHeight {
		intervals = append(intervals, Interval{
			StartHeight: startHeight,
			EndHeight:   heights[0],
			Value:       value,
		})
		startHeight = heights[0]
		value = updates[0]
		heights = heights[1:]
		updates = updates[1:]
	}
	for i := 1; i < len(updates); i++ {
		intervals = append(intervals, Interval{
			StartHeight: startHeight,
			EndHeight:   heights[i],
			Value:       value,
		})
		startHeight = heights[i]
		value = updates[i]
	}
	intervals = append(intervals, Interval{
		StartHeight: startHeight,
		EndHeight:   endHeight,
		Value:       value,
	})

	return intervals
}