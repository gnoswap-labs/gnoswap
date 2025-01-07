package staker

import (
	"std"

	en "gno.land/r/gnoswap/v1/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/avl"
	ufmt "gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	currentGNSBalance uint64
)

func currentBalance() uint64 {
	// TODO: implement this after checking gns distribution is working
	// pf.DistributeProtocolFee()
	// accuProtocolFee := pf.GetAccuTransferToGovStaker()
	// pf.ClearAccuTransferToGovStaker()

	gotGnsForEmission = en.GetDistributedToGovStaker()
	en.ClearDistributedToGovStaker()

	currentGNSBalance += gotGnsForEmission

	return currentGNSBalance
}

type StakerRewardInfo struct {
	StartHeight uint64     // height when staker started staking
	PriceDebt   *u256.Uint // price debt per xGNS stake, Q128
	Amount      uint64     // amount of xGNS staked
	Claimed     uint64     // amount of GNS reward claimed so far
}

func (self *StakerRewardInfo) Debug() string {
	return ufmt.Sprintf("{ StartHeight: %d, PriceDebt: %d, Amount: %d, Claimed: %d }", self.StartHeight, self.PriceDebtUint64(), self.Amount, self.Claimed)
}

func (self *StakerRewardInfo) PriceDebtUint64() uint64 {
	return u256.Zero().Rsh(self.PriceDebt, 128).Uint64()
}

type RewardState struct {
	// CurrentBalance is sum of all the previous balances, including the reward distribution.
	CurrentBalance    uint64     // current balance of gov_staker, used to calculate RewardAccumulation
	PriceAccumulation *u256.Uint // claimable GNS per xGNS stake, Q128
	// RewardAccumulation *u256.Uint // reward accumulated so far, Q128
	TotalStake uint64 // total xGNS staked

	info *avl.Tree // address -> StakerRewardInfo
}

func NewRewardState() *RewardState {
	return &RewardState{
		info:              avl.NewTree(),
		CurrentBalance:    0,
		PriceAccumulation: u256.Zero(),
		TotalStake:        0,
	}
}

var rewardState = NewRewardState()

func (self *RewardState) Debug() string {
	return ufmt.Sprintf("{ CurrentBalance: %d, PriceAccumulation: %d, TotalStake: %d, info: len(%d) }", self.CurrentBalance, self.PriceAccumulationUint64(), self.TotalStake, self.info.Size())
}

func (self *RewardState) Info(staker std.Address) StakerRewardInfo {
	infoI, exists := self.info.Get(staker.String())
	if !exists {
		panic(ufmt.Sprintf("staker %s not found", staker.String()))
	}
	return infoI.(StakerRewardInfo)
}

func (self *RewardState) CalculateReward(staker std.Address) uint64 {
	info := self.Info(staker)
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
func (self *RewardState) deductReward(staker std.Address, currentBalance uint64) uint64 {
	info := self.Info(staker)
	stakerPrice := u256.Zero().Sub(self.PriceAccumulation, info.PriceDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.Amount))
	reward = reward.Rsh(reward, 128)
	reward64 := reward.Uint64()

	info.Claimed += reward64
	self.info.Set(staker.String(), info)

	self.CurrentBalance = currentBalance - reward64

	return reward64
}

// This function MUST be called as a part of AddStake or RemoveStake
// CurrentBalance / StakeChange / IsRemoveStake will be updated in those functions
func (self *RewardState) finalize(currentBalance uint64) {
	delta := currentBalance - self.CurrentBalance

	if self.TotalStake == uint64(0) {
		// no staker
		return
	}

	price := u256.NewUint(delta)
	price = price.Lsh(price, 128)
	price = price.Div(price, u256.NewUint(self.TotalStake))
	self.PriceAccumulation.Add(self.PriceAccumulation, price)
	self.CurrentBalance = currentBalance
}

func (self *RewardState) AddStake(currentHeight uint64, staker std.Address, amount uint64, currentBalance uint64) {
	self.finalize(currentBalance)

	self.TotalStake += amount

	if self.info.Has(staker.String()) {
		info := self.Info(staker)
		info.PriceDebt.Add(info.PriceDebt, u256.NewUint(info.Amount))
		info.PriceDebt.Add(info.PriceDebt, u256.Zero().Mul(self.PriceAccumulation, u256.NewUint(amount)))
		info.PriceDebt.Div(info.PriceDebt, u256.NewUint(self.TotalStake))
		info.Amount += amount
		self.info.Set(staker.String(), info)
		return
	}

	info := StakerRewardInfo{
		StartHeight: currentHeight,
		PriceDebt:   self.PriceAccumulation.Clone(),
		Amount:      amount,
		Claimed:     0,
	}

	self.info.Set(staker.String(), info)
}

func (self *RewardState) Claim(staker std.Address, currentBalance uint64) uint64 {
	if !self.info.Has(staker.String()) {
		return 0
	}

	self.finalize(currentBalance)

	reward := self.deductReward(staker, currentBalance)

	return reward
}

func (self *RewardState) RemoveStake(staker std.Address, amount uint64, currentBalance uint64) uint64 {
	self.finalize(currentBalance)

	reward := self.deductReward(staker, currentBalance)

	self.info.Remove(staker.String())

	self.TotalStake -= amount

	return reward
}

var (
	q96                  = u256.MustFromDecimal(consts.Q96)
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

// === LAUNCHPAD DEPOSIT
var (
	amountByProjectWallet = avl.NewTree() // recipient wallet => amount
	rewardByProjectWallet = avl.NewTree() // recipient wallet => reward
)

func GetRewardByProjectWallet(addr std.Address) uint64 {
	value, exists := rewardByProjectWallet.Get(addr.String())
	if !exists {
		return 0
	}
	return value.(uint64)
}

func getAmountByProjectWallet(addr std.Address) uint64 {
	value, exists := amountByProjectWallet.Get(addr.String())
	if !exists {
		return 0
	}
	return value.(uint64)
}

func SetAmountByProjectWallet(addr std.Address, amount uint64, add bool) {
	caller := std.PrevRealm().Addr()
	if err := common.LaunchpadOnly(caller); err != nil {
		panic(err)
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	currentAmount := getAmountByProjectWallet(addr)
	if add {
		amountByProjectWallet.Set(addr.String(), currentAmount+amount)
		rewardState.AddStake(uint64(std.GetHeight()), caller, amount, currentBalance())
	} else {
		amountByProjectWallet.Set(addr.String(), currentAmount-amount)
		rewardState.RemoveStake(caller, amount, currentBalance())
	}

}

// LAUCNHAPD DEPOSIT ===
/*
func calculateReward() {
	height := uint64(std.GetHeight())
	if height <= lastCalculatedHeight {
		return
	}

	atLeastOneDelegated := delegatedTo.Size() > 0
	atLeastOneLaunchpadRecipient := amountByProjectWallet.Size() > 0

	if !atLeastOneDelegated && !atLeastOneLaunchpadRecipient {
		return
	}

	// transfer protocol_fee to gov_staker
	pf.DistributeProtocolFee()

	// calculate user's xGNS ratio
	xGnsTotalSupply := xgns.TotalSupply()
	xGnsX96 := new(u256.Uint).Mul(u256.NewUint(xGnsTotalSupply), q96)

	// calculate delegator ratio
	delegatorAmount.Iterate("", "", func(key string, value interface{}) bool {
		amount := value.(uint64)
		ratio := calculateXGnsRatio(amount, xGnsX96)

		userXGnsRatio.Set(key, ratio)
		return false
	})

	// calculate project's recipient's xGNS ratio
	amountByProjectWallet.Iterate("", "", func(key string, value interface{}) bool {
		amount := value.(uint64)
		ratio := calculateXGnsRatio(amount, xGnsX96)

		userXGnsRatio.Set(key, ratio)
		return false
	})

	calculateGNSEmission()
	calculateProtocolFee()

	lastCalculatedHeight = height
}
*/
// calculateXGnsRatio calculates the ratio of user's xGNS amount to total xGNS supply
func calculateXGnsRatio(amount uint64, xGnsX96 *u256.Uint) *u256.Uint {
	xGnsAmountX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96)
	xGnsAmountX96 = new(u256.Uint).Mul(xGnsAmountX96, u256.NewUint(1_000_000_000))

	ratio := new(u256.Uint).Div(xGnsAmountX96, xGnsX96)
	ratio = ratio.Mul(ratio, q96)
	return ratio.Div(ratio, u256.NewUint(1_000_000_000))
}

func calculateGNSEmission() {
	// gov_staker received xgns
	// but no gns has been staked, left amount will be used next time
	if delegatedTo.Size() == 0 {
		return
	}

	gotGnsForEmission = en.GetDistributedToGovStaker()
	en.ClearDistributedToGovStaker()
	gotGnsForEmission += leftGnsEmissionFromLast

	if gotGnsForEmission == uint64(0) {
		return
	}

	calculated := uint64(0)
	userXGnsRatio.Iterate("", "", func(key string, value interface{}) bool {
		ratio := value.(*u256.Uint)
		emissionRewardX96 := new(u256.Uint).Mul(u256.NewUint(gotGnsForEmission), ratio)
		emissionRewardX := new(u256.Uint).Div(emissionRewardX96, q96)
		emissionReward := emissionRewardX.Uint64()
		if emissionReward == uint64(0) {
			return false
		}

		currentReward := uint64(0)
		if val, exists := userEmissionReward.Get(key); exists {
			currentReward = val.(uint64)
		}
		userEmissionReward.Set(key, currentReward+emissionReward)

		calculated += emissionReward
		return false
	})

	alreadyCalculatedGnsEmission += gotGnsForEmission
	leftGnsEmissionFromLast = gotGnsForEmission - calculated
}

func calculateProtocolFee() {
	// gov_staker received protocol_fee
	// but no gns has been staked, left amount will be used next time
	if userXGnsRatio.Size() == 0 {
		return
	}

	accuProtocolFee := pf.GetAccuTransferToGovStaker()
	pf.ClearAccuTransferToGovStaker()
	if accuProtocolFee.Size() == 0 {
		return
	}

	registered := common.ListRegisteredTokens()
	// get gov staker's grc20 balance
	for _, tokenPath := range registered {
		tokenBalance, exists := accuProtocolFee.Get(tokenPath)
		if !exists || tokenBalance == uint64(0) {
			continue
		}

		leftValue, exists := leftProtocolFeeFromLast.Get(tokenPath)
		leftFromLast := uint64(0)
		if exists {
			leftFromLast = leftValue.(uint64)
		}
		tokenBalance = tokenBalance.(uint64) + leftFromLast

		if tokenBalance.(uint64) == uint64(0) {
			continue
		}

		calculated := uint64(0)
		userXGnsRatio.Iterate("", "", func(key string, value interface{}) bool {
			ratio := value.(*u256.Uint)
			protocolFeeX96 := new(u256.Uint).Mul(u256.NewUint(tokenBalance.(uint64)), ratio)
			protocolFeeX := new(u256.Uint).Div(protocolFeeX96, q96)
			protocolFee := protocolFeeX.Uint64()
			if protocolFee == uint64(0) {
				return false
			}

			var userFees *avl.Tree
			if val, exists := userProtocolFeeReward.Get(key); exists {
				userFees = val.(*avl.Tree)
			} else {
				userFees = avl.NewTree()
				userProtocolFeeReward.Set(key, userFees)
			}

			currentFee := uint64(0)
			if val, exists := userFees.Get(tokenPath); exists {
				currentFee = val.(uint64)
			}
			userFees.Set(tokenPath, currentFee+protocolFee)

			calculated += protocolFee
			return false
		})

		current := uint64(0)
		if val, exists := alreadyCalculatedProtocolFee.Get(tokenPath); exists {
			current = val.(uint64)
		}
		alreadyCalculatedProtocolFee.Set(tokenPath, current+tokenBalance.(uint64))
		leftProtocolFeeFromLast.Set(tokenPath, tokenBalance.(uint64)-calculated)
	}
}
