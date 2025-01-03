package launchpad

import (
	"strconv"
	"strings"

	"gno.land/p/demo/avl"

	u256 "gno.land/p/gnoswap/uint256"
)

type Period struct {
	// [start, end)
	// EndHeight is set to 0 if it's not ended
	StartHeight uint64
	EndHeight   uint64

	// total accumulated reward when this distribution period is started,
	// after distribution deduction
	InitReward uint64
	// total accumulated reward when this distribution period is ended
	// set to 0 if it's not ended
	FinalReward uint64
	// distributed amount when this distribution period starts
	// FinalReward(n-1) - Distributed(n) == InitReward(n)
	Distributed uint64 

	// total staked amount for this distribution period
	TotalStake uint64
}

func NewPeriod(startHeight uint64, initReward uint64, distributed uint64, totalStake uint64) Period {
	return Period{
		StartHeight: startHeight,
		InitReward:  initReward,
		Distributed: distributed,
		TotalStake:  totalStake,
	}
}

func (self *Period) Finalize(endHeight uint64, finalReward uint64) {
	self.EndHeight = endHeight
	self.FinalReward = finalReward
}

func (self *Period) IsEnded() bool {
	return self.EndHeight != 0
}

// CONTRACT: must be called only after Finalize
func (self *Period) TotalReward() uint64 {
	return self.FinalReward - self.InitReward
}

// CONTRACT: must be called only after Finalize
func (self *Period) Distribute(stake uint64) uint64 {

}

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

type Periods struct {
	tree *avl.Tree
}

func NewPeriods(currentHeight uint64) *Periods {
	result := &Periods{
		tree: avl.NewTree(),
	}
	result.Set(currentHeight, NewPeriod(currentHeight, 0, 0))
	return result
}

func (self *Periods) Get(key uint64) (Period, bool) {
	v, ok := self.tree.Get(EncodeUint(key))
	if !ok {
		return Period{}, false
	}
	return v.(Period), true
}

func (self *Periods) Set(key uint64, value Period) {
	self.tree.Set(EncodeUint(key), value)
}

func (self *Periods) Remove(key uint64) {
	self.tree.Remove(EncodeUint(key))
}

func (self *Periods) Iterate(start, end uint64, fn func(key uint64, value Period)) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(key string, value interface{}) bool {
		fn(DecodeUint(key), value.(Period))
		return true
	})
}

func (self *Periods) ReverseIterate(start, end uint64, fn func(key uint64, value Period)) {
	self.tree.ReverseIterate(EncodeUint(start), EncodeUint(end), func(key string, value interface{}) bool {
		fn(DecodeUint(key), value.(Period))
		return true
	})
}

func (self *Periods) Size() uint64 {
	return uint64(self.tree.Size())
}

// Period that has equal or less than current height
// There MUST be at least one period
func (self *Periods) CurrentPeriod(currentHeight uint64) Period {
	var period Period
	self.ReverseIterate(0, currentHeight, func(key uint64, value Period) {
		period = value
	})
	return period
}

// NOTE: finalReward may be inconsistent within a single block
// as it is calculated as the current balance of the contract.
// However, if this happens, the value
func (self *Periods) AddStake(currentHeight uint64, finalReward uint64, stake uint64) {
	period := self.CurrentPeriod(currentHeight)
	if period.StartHeight == currentHeight {
		// Period update has been already happened in this block
		// Modify instead of push new period
		period.TotalStake += stake
		self.Set(currentHeight, period)
		return
	}

	period.Finalize(currentHeight, finalReward)
	self.Set(period.StartHeight, period)

	newPeriod := NewPeriod(currentHeight, period.FinalReward, 0, period.TotalStake+stake)
	self.Set(currentHeight, newPeriod)
}

func (self *Periods) RemoveStake(currentHeight uint64, finalReward uint64, stake uint64) uint64 {
	period := self.CurrentPeriod(currentHeight)
	if period.StartHeight == currentHeight {
		// Period update has been already happened in this block
		// Modify instead of push new period
		prevPeriod := self.CurrentPeriod(currentHeight - 1)
		prevTotalReward := prevPeriod.TotalReward()
		toDistribute := prevTotalReward - period.Distributed

		reward := u256.NewUint(toDistribute)
		reward = reward.Mul(reward, u256.NewUint(stake))
		reward = reward.Div(reward, u256.NewUint(period.TotalStake))
		
		reward64 := reward.Uint64()
		period.Distributed += reward64
		period.InitReward -= reward64
		self.Set(currentHeight, period)
		
		return reward64
	}

	period.Finalize(currentHeight, 0)
	self.Set(period.StartHeight, period)

	return 0
}
