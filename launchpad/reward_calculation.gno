// Copied from gov/staker, extract it out into acommon package?
package launchpad

import (
	"std"

	en "gno.land/r/gnoswap/v1/emission"
	ufmt "gno.land/p/demo/ufmt"
	"gno.land/p/demo/avl"
	u256 "gno.land/p/gnoswap/uint256"
)

type StakerRewardInfo struct {
	StartHeight uint64 // height when staker started staking
	PriceDebt *u256.Uint // price debt per xGNS stake, Q128
	Amount uint64 // amount of xGNS staked
	Claimed uint64 // amount of GNS reward claimed so far
}

func (self *StakerRewardInfo) Debug() string {
	return ufmt.Sprintf("{ StartHeight: %d, PriceDebt: %d, Amount: %d, Claimed: %d }", self.StartHeight, self.PriceDebtUint64(), self.Amount, self.Claimed)
}

func (self *StakerRewardInfo) PriceDebtUint64() uint64 {
	return u256.Zero().Rsh(self.PriceDebt, 128).Uint64()
}

type RewardState struct {
	// CurrentBalance is sum of all the previous balances, including the reward distribution.
	// CurrentBalance uint64 // current balance of gov_staker, used to calculate RewardAccumulation
	PriceAccumulation *u256.Uint // claimable GNS per xGNS stake, Q128
	// RewardAccumulation *u256.Uint // reward accumulated so far, Q128
	TotalStake uint64 // total xGNS staked

	LastHeight uint64 // last height when reward was calculated
	RewardPerBlock *u256.Uint // reward per block, = Tier.tierAmountPerBlockX96
	EndHeight uint64

	info *avl.Tree // depositId -> StakerRewardInfo
}

func NewRewardState(rewardPerBlock *u256.Uint, startHeight uint64, endHeight uint64) *RewardState {
	return &RewardState {
		PriceAccumulation: u256.Zero(),
		TotalStake: 0,
		LastHeight: startHeight,
		RewardPerBlock: rewardPerBlock,
		EndHeight: endHeight,
		info: avl.NewTree(),
	}
}

type RewardStates struct {
	states *avl.Tree // projectId:tier string -> RewardState
}

var rewardStates = RewardStates{
	states: avl.NewTree(),
}

func (states RewardStates) Get(projectId string, tierStr string) *RewardState {
	key := projectId + ":" + tierStr
	statesI, exists := states.states.Get(key)
	if !exists {
		return nil
	}
	return statesI.(*RewardState)
}

func (states RewardStates) Set(projectId string, tierStr string, state *RewardState) {
	key := projectId + ":" + tierStr
	states.states.Set(key, state)
}

func (states RewardStates) Remove(projectId string, tierStr string) {
	key := projectId + ":" + tierStr
	states.states.Remove(key)
}


func (self *RewardState) Debug() string {
	return ufmt.Sprintf("{ PriceAccumulation: %d, TotalStake: %d, info: len(%d) }", self.PriceAccumulationUint64(), self.TotalStake, self.info.Size())
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
	reward = reward.Rsh(reward, 128)
	return reward.Uint64()
}

func (self *RewardState) PriceAccumulationUint64() uint64 {
	return u256.Zero().Rsh(self.PriceAccumulation, 128).Uint64()
}


// amount MUST be less than or equal to the amount of xGNS staked
// This function does not check it
func (self *RewardState) deductReward(depositId string, currentHeight uint64) uint64 {
	info := self.Info(depositId)
	stakerPrice := u256.Zero().Sub(self.PriceAccumulation, info.PriceDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.Amount))
	reward = reward.Rsh(reward, 128)
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
		// no staker
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

	info := StakerRewardInfo {
		StartHeight: currentHeight,
		PriceDebt: self.PriceAccumulation.Clone(),
		Amount: amount,
		Claimed: 0,
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