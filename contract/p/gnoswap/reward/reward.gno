package reward

import (
	"gno.land/p/demo/avl"

	u256 "gno.land/p/gnoswap/uint256"
)

type RewardInfo interface {
	StartHeight() uint64
	SetStartHeight(h uint64)

	PriceDebt() *u256.Uint
	SetPriceDebt(d *u256.Uint)

	Amount() uint64
	SetAmount(a uint64)

	Claimed() uint64
	SetClaimed(c uint64)
}

type BaseRewardInfo struct {
	startHeight uint64
	priceDebt   *u256.Uint
	amount      uint64
	claimed     uint64
}

func (b *BaseRewardInfo) StartHeight() uint64       { return b.startHeight }
func (b *BaseRewardInfo) SetStartHeight(h uint64)   { b.startHeight = h }
func (b *BaseRewardInfo) PriceDebt() *u256.Uint     { return b.priceDebt }
func (b *BaseRewardInfo) SetPriceDebt(d *u256.Uint) { b.priceDebt = d }
func (b *BaseRewardInfo) Amount() uint64            { return b.amount }
func (b *BaseRewardInfo) SetAmount(a uint64)        { b.amount = a }
func (b *BaseRewardInfo) Claimed() uint64           { return b.claimed }
func (b *BaseRewardInfo) SetClaimed(c uint64)       { b.claimed = c }

type BaseRewardState struct {
	info              *avl.Tree
	TotalStake        uint64
	PriceAccumulation *u256.Uint
}

func NewBaseRewardState() *BaseRewardState {
	return &BaseRewardState{
		info:              avl.NewTree(),
		TotalStake:        0,
		PriceAccumulation: u256.Zero(),
	}
}

func (s *BaseRewardState) Info(key string) (RewardInfo, bool) {
	v, exists := s.info.Get(key)
	if !exists {
		return nil, false
	}

	return v.(RewardInfo), true
}

func (s *BaseRewardState) SetInfo(key string, r RewardInfo) {
	s.info.Set(key, r)
}

func (s *BaseRewardState) PriceAccumulationUint64() uint64 {
	return u256.Zero().Rsh(s.PriceAccumulation, 128).Uint64()
}

func (s *BaseRewardState) CalculateReward(key string) uint64 {
	r, ok := s.Info(key)
	if !ok {
		return 0
	}

	diff := u256.Zero().Sub(s.PriceAccumulation, r.PriceDebt())
	reward := u256.Zero().Mul(diff, u256.NewUint(r.Amount()))
	reward = reward.Rsh(reward, 128)

	alreadyClaimed := r.Claimed()
	calculated := reward.Uint64()
	if calculated <= alreadyClaimed {
		return 0
	}

	return calculated - alreadyClaimed
}

func (s *BaseRewardState) AddStake(key string, amount uint64, currentHeight uint64) {
	s.Finalize(currentHeight)
	s.TotalStake += amount

	if r, ok := s.Info(key); ok {
		newDebt := updatePriceDebt(r.PriceDebt(), s.PriceAccumulation, amount, s.TotalStake)

		r.SetPriceDebt(newDebt)
		r.SetAmount(r.Amount() + amount)

		s.SetInfo(key, r)
		return
	}

	newInfo := &BaseRewardInfo{
		startHeight: currentHeight,
		priceDebt:   s.PriceAccumulation.Clone(),
		amount:      amount,
		claimed:     0,
	}

	s.SetInfo(key, newInfo)
}

func (s *BaseRewardState) RemoveStake(key string, amount uint64, currentHeight uint64) uint64 {
	s.Finalize(currentHeight)

	reward := s.deductReward(key)

	s.info.Remove(key)
	if s.TotalStake < amount {
		s.TotalStake = 0
	} else {
		s.TotalStake -= amount
	}

	return reward
}

func (s *BaseRewardState) Claim(key string, currentHeight uint64) uint64 {
	s.Finalize(currentHeight)
	return s.deductReward(key)
}

func (s *BaseRewardState) Finalize(currentHeight uint64) {
	// no-op: will be override
}

func (s *BaseRewardState) deductReward(key string) uint64 {
	reward := s.CalculateReward(key)
	if reward == 0 {
		return 0
	}

	// update
	r, ok := s.Info(key)
	if !ok {
		return 0
	}

	r.SetClaimed(r.Claimed() + reward)
	s.SetInfo(key, r)

	return reward
}

func updatePriceDebt(
	oldDebt, priceAcc *u256.Uint,
	addedAmount uint64,
	newTotalStake uint64,
) *u256.Uint {
	if newTotalStake == 0 {
		return oldDebt
	}

	add := u256.Zero().Mul(priceAcc, u256.NewUint(addedAmount))
	add = add.Div(add, u256.NewUint(newTotalStake))

	newDebt := oldDebt.Clone()
	newDebt.Add(newDebt, add)

	return newDebt
}
