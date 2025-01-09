// Copied from gov/staker, extract it out into acommon package?
package launchpad

import (
	"gno.land/p/demo/avl"
	ufmt "gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

type StakerRewardInfo struct {
	StartHeight uint64     // height when staker started staking
	PriceDebt   *u256.Uint // price debt per xGNS stake, Q96
	Amount      uint64     // amount of xGNS staked
	Claimed     uint64     // amount of GNS reward claimed so far
}

func (self *StakerRewardInfo) Debug() string {
	return ufmt.Sprintf("{ StartHeight: %d, PriceDebt: %d, Amount: %d, Claimed: %d }", self.StartHeight, self.PriceDebtUint64(), self.Amount, self.Claimed)
}

func (self *StakerRewardInfo) PriceDebtUint64() uint64 {
	return u256.Zero().Rsh(self.PriceDebt, 96).Uint64()
}

type RewardState struct {
	PriceAccumulation *u256.Uint // claimable Launchpad reward per xGNS stake, Q96
	TotalStake        uint64     // total xGNS staked

	LastHeight     uint64     // last height when reward was calculated
	RewardPerBlock *u256.Uint // reward per block, = Tier.tierAmountPerBlockX96
	EndHeight      uint64

	TotalEmptyBlock uint64

	info *avl.Tree // depositId -> StakerRewardInfo
}

func NewRewardState(rewardPerBlock *u256.Uint, startHeight uint64, endHeight uint64) *RewardState {
	return &RewardState{
		PriceAccumulation: u256.Zero(),
		TotalStake:        0,
		LastHeight:        startHeight,
		RewardPerBlock:    rewardPerBlock,
		EndHeight:         endHeight,
		info:              avl.NewTree(),
	}
}

type RewardStates struct {
	states *avl.Tree // projectId:tier string -> RewardState
}

var rewardStates = RewardStates{
	states: avl.NewTree(),
}

func (states RewardStates) Get(projectId string, tierStr string) (*RewardState, error) {
	key := projectId + ":" + tierStr
	statesI, exists := states.states.Get(key)
	if !exists {
		return nil, ufmt.Errorf("reward state not found for projectId %s and tierStr %s", projectId, tierStr)
	}
	return statesI.(*RewardState), nil
}

func (states RewardStates) Set(projectId string, tierStr string, state *RewardState) {
	key := projectId + ":" + tierStr
	states.states.Set(key, state)
}

func (states RewardStates) DeleteProject(projectId string) uint64 {
	totalLeftover := uint64(0)
	keys := []string{}
	states.states.Iterate(projectId+":", projectId+";", func(key string, value interface{}) bool {
		state := value.(*RewardState)
		totalEmptyBlock := state.TotalEmptyBlock
		if state.TotalStake == 0 {
			totalEmptyBlock += state.EndHeight - state.LastHeight
		}
		totalEmptyBlockU256 := u256.NewUint(totalEmptyBlock)
		totalEmptyRewards := totalEmptyBlockU256.Mul(totalEmptyBlockU256, state.RewardPerBlock)
		totalLeftover += totalEmptyRewards.Uint64()
		keys = append(keys, key)
		return false
	})

	for _, key := range keys {
		states.states.Remove(key)
	}

	return totalLeftover
}

func (self *RewardState) Debug() string {
	return ufmt.Sprintf("{ PriceAccumulation: %d, TotalStake: %d, LastHeight: %d, RewardPerBlock: %d, EndHeight: %d, info: len(%d) }", self.PriceAccumulationUint64(), self.TotalStake, self.LastHeight, self.RewardPerBlockUint64(), self.EndHeight, self.info.Size())
}

func (self *RewardState) RewardPerBlockUint64() uint64 {
	return u256.Zero().Rsh(self.RewardPerBlock, 96).Uint64()
}

func (self *RewardState) Info(depositId string) StakerRewardInfo {
	infoI, exists := self.info.Get(depositId)
	if !exists {
		panic(ufmt.Sprintf("depositId %s not found", depositId))
	}
	return infoI.(StakerRewardInfo)
}

func (self *RewardState) CalculateReward(depositId string) uint64 {
	info := self.Info(depositId)
	stakerPrice := u256.Zero().Sub(self.PriceAccumulation, info.PriceDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.Amount))
	reward = reward.Rsh(reward, 96)
	return reward.Uint64() - info.Claimed
}

func (self *RewardState) PriceAccumulationUint64() uint64 {
	return u256.Zero().Rsh(self.PriceAccumulation, 96).Uint64()
}

// amount MUST be less than or equal to the amount of xGNS staked
// This function does not check it
func (self *RewardState) deductReward(depositId string, currentHeight uint64) uint64 {
	info := self.Info(depositId)
	stakerPrice := u256.Zero().Sub(self.PriceAccumulation, info.PriceDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.Amount))
	reward = reward.Rsh(reward, 96)
	reward64 := reward.Uint64() - info.Claimed

	info.Claimed += reward64
	self.info.Set(depositId, info)

	self.LastHeight = currentHeight

	return reward64
}

// This function MUST be called as a part of AddStake or RemoveStake
// CurrentBalance / StakeChange / IsRemoveStake will be updated in those functions
func (self *RewardState) finalize(currentHeight uint64) {
	if currentHeight <= self.LastHeight {
		// Not started yet
		return
	}
	if currentHeight > self.EndHeight {
		currentHeight = self.EndHeight
	}

	delta := u256.NewUint(currentHeight - self.LastHeight)
	delta = delta.Mul(delta, self.RewardPerBlock)

	if self.TotalStake == uint64(0) {
		self.TotalEmptyBlock += currentHeight - self.LastHeight
		self.LastHeight = currentHeight
		return
	}

	price := delta.Div(delta, u256.NewUint(self.TotalStake))
	self.PriceAccumulation.Add(self.PriceAccumulation, price)
	self.LastHeight = currentHeight
}

func (self *RewardState) AddStake(currentHeight uint64, depositId string, amount uint64) {
	if self.info.Has(depositId) {
		panic(ufmt.Sprintf("depositId %s already exists", depositId))
	}

	self.finalize(currentHeight)

	self.TotalStake += amount

	if self.info.Has(depositId) {
		info := self.Info(depositId)
		info.PriceDebt.Add(info.PriceDebt, u256.NewUint(info.Amount))
		info.PriceDebt.Add(info.PriceDebt, u256.Zero().Mul(self.PriceAccumulation, u256.NewUint(amount)))
		info.PriceDebt.Div(info.PriceDebt, u256.NewUint(self.TotalStake))
		info.Amount += amount
		self.info.Set(depositId, info)
		return
	}

	info := StakerRewardInfo{
		StartHeight: currentHeight,
		PriceDebt:   self.PriceAccumulation.Clone(),
		Amount:      amount,
		Claimed:     0,
	}

	self.info.Set(depositId, info)
}

func (self *RewardState) Claim(depositId string, currentHeight uint64) uint64 {
	if !self.info.Has(depositId) {
		return 0
	}

	self.finalize(currentHeight)

	reward := self.deductReward(depositId, currentHeight)

	return reward
}

func (self *RewardState) RemoveStake(depositId string, amount uint64, currentHeight uint64) uint64 {
	self.finalize(currentHeight)

	reward := self.deductReward(depositId, currentHeight)

	self.info.Remove(depositId)

	self.TotalStake -= amount

	return reward
}

/*
var (
	//q96                  = u256.MustFromDecimal(consts.Q96)
	lastCalculatedHeight uint64 // flag to prevent same block calculation
)

var (
	gotGnsForEmission            uint64
	leftGnsEmissionFromLast      uint64
	alreadyCalculatedGnsEmission uint64

	leftProtocolFeeFromLast      = avl.NewTree() // tokenPath -> tokenAmount
	alreadyCalculatedProtocolFee = avl.NewTree() // tokenPath -> tokenAmount
)

var (
	userXGnsRatio         = avl.NewTree() // address -> ratioX96
	userEmissionReward    = avl.NewTree() // address -> gnsAmount
	userProtocolFeeReward = avl.NewTree() // address -> tokenPath -> tokenAmount
)
*/
