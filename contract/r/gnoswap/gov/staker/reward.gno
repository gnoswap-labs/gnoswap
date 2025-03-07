package staker

import (
	"std"

	en "gno.land/r/gnoswap/v1/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/p/demo/avl"
	ufmt "gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/halt"
)

var (
	currentGNSBalance         uint64            = 0                       // GNS balance of gov/staker minted by emission
	currentProtocolFeeBalance map[string]uint64 = make(map[string]uint64) // protocol fee balance of gov/staker (tokenPath -> balance)

	q96         = u256.MustFromDecimal(consts.Q96)
	q128        = uint(128)
	rewardState = NewRewardState() // reward state of gov/staker

	// For Launchpad deposit
	amountByProjectWallet = avl.NewTree() // recipient wallet => amount
)

// collectAndGetGNSBalance gets the acuumulated GNS balance from emission to gov/staker
// Need to clear the distributed GNS to gov/staker in emission to get the latest accumulated GNS balance
func collectAndGetGNSBalance() uint64 {
	gotGnsForEmission := en.GetDistributedToGovStaker()
	en.ClearDistributedToGovStaker()

	currentGNSBalance += gotGnsForEmission

	return currentGNSBalance
}

// updateAndGetProtocolFeeBalance gets the accumulated protocol fee balance from protocol_fee to gov/staker
// Need to clear the accumulated protocol fee to gov/staker in protocol fee to get the latest accumulated protocol fee balance
func updateAndGetProtocolFeeBalance() map[string]uint64 {
	pf.DistributeProtocolFee()
	gotAccuProtocolFee := pf.GetAccuTransferToGovStaker()

	gotAccuProtocolFee.Iterate("", "", func(key string, value interface{}) bool {
		amount := value.(uint64)
		currentProtocolFeeBalance[key] += amount
		return false
	})

	pf.ClearAccuTransferToGovStaker()

	return currentProtocolFeeBalance
}

type StakerRewardInfo struct {
	StartHeight              uint64                // height when staker started staking
	RewardDebt               *u256.Uint            // price debt per xGNS stake, Q128
	ProtocolFeeDebt          map[string]*u256.Uint // protocol fee debt per xGNS stake, Q128
	StakedAmount             uint64                // amount of xGNS staked
	PendingGnsReward         uint64                // amount of GNS reward pending
	PendingProtocolFeeReward map[string]uint64     // protocol fee amount pending per token
	GnsRewardClaimed         uint64                // amount of GNS reward claimed so far
	ProtocolFeeClaimed       map[string]uint64     // protocol fee amount claimed per token
	LastClaimedHeight        uint64                // last height when the reward was claimed
}

func (self *StakerRewardInfo) PriceDebtUint64() uint64 {
	return u256.Zero().Rsh(self.RewardDebt, q128).Uint64()
}

type RewardState struct {
	// CurrentBalance is sum of all the previous balances, including the reward distribution.
	totalXGNSStake                 uint64                // total xGNS staked in the system
	currentGNSBalance              uint64                // current GNS balance of gov/staker, used to calculate GNSRewardAccumulation
	currentProtocolFeeBalance      map[string]uint64     // current protocol fee balance per token path
	accumulatedGNSRewardPerStake   *u256.Uint            // accumulated claimable GNS per xGNS stake, Q128 format
	accumulatedProtocolFeePerStake map[string]*u256.Uint // accumulated claimable protocol fee per xGNS stake, Q128 format
	stakerInfos                    *avl.Tree             // address -> StakerRewardInfo
}

func NewRewardState() *RewardState {
	return &RewardState{
		totalXGNSStake:                 0,
		currentGNSBalance:              0,
		currentProtocolFeeBalance:      make(map[string]uint64),
		accumulatedGNSRewardPerStake:   u256.Zero(),
		accumulatedProtocolFeePerStake: make(map[string]*u256.Uint),
		stakerInfos:                    avl.NewTree(),
	}
}

func (self *RewardState) Info(staker std.Address) StakerRewardInfo {
	infoI, exists := self.stakerInfos.Get(staker.String())
	if !exists {
		return StakerRewardInfo{
			StartHeight:              uint64(std.ChainHeight()),
			RewardDebt:               u256.Zero(),
			ProtocolFeeDebt:          make(map[string]*u256.Uint),
			StakedAmount:             0,
			PendingGnsReward:         0,
			PendingProtocolFeeReward: make(map[string]uint64),
			GnsRewardClaimed:         0,
			ProtocolFeeClaimed:       make(map[string]uint64),
			LastClaimedHeight:        0,
		}
	}
	return infoI.(StakerRewardInfo)
}

func (self *RewardState) CalculateReward(staker std.Address) (uint64, map[string]uint64) {
	info := self.Info(staker)
	stakerPrice := u256.Zero().Sub(self.accumulatedGNSRewardPerStake, info.RewardDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.StakedAmount))
	reward = reward.Rsh(reward, q128)
	calcReward := reward.Uint64() + info.PendingGnsReward

	protocolFeeRewards := make(map[string]uint64)
	for tokenPath, protocolFeePriceAccumulation := range self.accumulatedProtocolFeePerStake {
		protocolFeePriceDebt, ok := info.ProtocolFeeDebt[tokenPath]
		if !ok {
			protocolFeePriceDebt = u256.Zero()
		}
		protocolFeePrice := u256.Zero().Sub(protocolFeePriceAccumulation, protocolFeePriceDebt)
		protocolFeeReward := u256.Zero().Mul(protocolFeePrice, u256.NewUint(info.StakedAmount))
		protocolFeeReward = protocolFeeReward.Rsh(protocolFeeReward, q128)
		protocolFeeReward64 := protocolFeeReward.Uint64()
		pendingReward, exist := info.PendingProtocolFeeReward[tokenPath]
		if exist {
			protocolFeeReward64 += pendingReward
		}
		if protocolFeeReward64 > 0 {
			protocolFeeRewards[tokenPath] = protocolFeeReward64
		}
	}
	return calcReward, protocolFeeRewards
}

func (self *RewardState) PriceAccumulationUint64() uint64 {
	return u256.Zero().Rsh(self.accumulatedGNSRewardPerStake, q128).Uint64()
}

// amount MUST be less than or equal to the amount of xGNS staked
// This function does not check it
func (self *RewardState) deductReward(staker std.Address, currentBalance uint64) (uint64, map[string]uint64) {
	info := self.Info(staker)
	if info.LastClaimedHeight == uint64(std.ChainHeight()) {
		return 0, make(map[string]uint64)
	}

	stakerPrice := u256.Zero().Sub(self.accumulatedGNSRewardPerStake, info.RewardDebt)
	reward := u256.Zero().Mul(stakerPrice, u256.NewUint(info.StakedAmount))
	reward = reward.Rsh(reward, q128)
	collectableReward := reward.Uint64() + info.PendingGnsReward - info.GnsRewardClaimed
	info.PendingGnsReward = 0
	info.GnsRewardClaimed += collectableReward
	self.currentGNSBalance = currentBalance - collectableReward

	protocolFeeRewards := make(map[string]uint64)
	for tokenPath, protocolFeePerStakeAccumulation := range self.accumulatedProtocolFeePerStake {
		protocolFeePriceDebt, ok := info.ProtocolFeeDebt[tokenPath]
		if !ok {
			protocolFeePriceDebt = u256.Zero()
		}
		protocolFeePerStakeDelta := u256.Zero().Sub(protocolFeePerStakeAccumulation, protocolFeePriceDebt)
		protocolFeeRewardQ128 := u256.Zero().Mul(protocolFeePerStakeDelta, u256.NewUint(info.StakedAmount))
		protocolFeeReward := u256.Zero().Rsh(protocolFeeRewardQ128, q128)
		collectableProtocolFeeReward := protocolFeeReward.Uint64()
		pendingReward, exist := info.PendingProtocolFeeReward[tokenPath]
		if exist {
			collectableProtocolFeeReward += pendingReward
			info.PendingProtocolFeeReward[tokenPath] = 0
		}
		alreadyClaimed, exist := info.ProtocolFeeClaimed[tokenPath]
		if exist {
			collectableProtocolFeeReward -= alreadyClaimed
		}
		if !(collectableProtocolFeeReward > 0) {
			continue
		}
		protocolFeeRewards[tokenPath] = collectableProtocolFeeReward
		info.ProtocolFeeClaimed[tokenPath] += collectableProtocolFeeReward
		self.currentProtocolFeeBalance[tokenPath] -= collectableProtocolFeeReward
	}

	info.LastClaimedHeight = uint64(std.ChainHeight())
	self.stakerInfos.Set(staker.String(), info)

	return collectableReward, protocolFeeRewards
}

// This function MUST be called as a part of addStake or removeStake
// currentGNSBalance / StakeChange / IsRemoveStake will be updated in those functions
func (self *RewardState) finalize(currentBalance uint64, currentProtocolFeeBalances map[string]uint64) {
	if self.totalXGNSStake == uint64(0) {
		// no staker
		return
	}

	// emission reward
	delta := currentBalance - self.currentGNSBalance
	if delta > 0 {
		deltaU256 := u256.NewUint(delta)
		deltaU256Q128 := deltaU256.Lsh(deltaU256, q128)
		emissionRewardPerOneStakedQ128 := u256.Zero().Div(deltaU256Q128, u256.NewUint(self.totalXGNSStake))
		self.accumulatedGNSRewardPerStake = u256.Zero().Add(self.accumulatedGNSRewardPerStake, emissionRewardPerOneStakedQ128)
		self.currentGNSBalance = currentBalance
	}

	// protocol fee reward
	for tokenPath, protocolFeeBalance := range currentProtocolFeeBalances {
		protocolFeeDelta := protocolFeeBalance - self.currentProtocolFeeBalance[tokenPath]
		if protocolFeeDelta == 0 {
			continue
		}
		protocolFeeDeltaU256 := u256.NewUint(protocolFeeDelta)
		protocolFeeDeltaU256Q128 := protocolFeeDeltaU256.Lsh(protocolFeeDeltaU256, q128)
		protocolFeeRewardPerOneStakedQ128 := u256.Zero().Div(protocolFeeDeltaU256Q128, u256.NewUint(self.totalXGNSStake))
		protocolFeePriceAccumulation, ok := self.accumulatedProtocolFeePerStake[tokenPath]
		if !ok {
			protocolFeePriceAccumulation = u256.Zero()
		}
		self.accumulatedProtocolFeePerStake[tokenPath] = u256.Zero().Add(protocolFeePriceAccumulation, protocolFeeRewardPerOneStakedQ128)
		self.currentProtocolFeeBalance[tokenPath] = protocolFeeBalance
	}
}

// addStake adds the staker's stake to the reward state
func (self *RewardState) addStake(currentHeight uint64, staker std.Address, amount uint64, currentBalance uint64, currentProtocolFeeBalances map[string]uint64) {
	self.finalize(currentBalance, currentProtocolFeeBalances)

	self.totalXGNSStake += amount
	if self.stakerInfos.Has(staker.String()) {
		info := self.Info(staker)
		reward, protocolFeeRewards := self.deductReward(staker, currentBalance)
		if reward > 0 {
			info.PendingGnsReward += reward
		}
		for tokenPath, amount := range protocolFeeRewards {
			if amount > 0 {
				info.PendingProtocolFeeReward[tokenPath] += amount
			}
		}

		info.RewardDebt = self.accumulatedGNSRewardPerStake.Clone()
		info.StakedAmount += amount
		for tokenPath, protocolFeePriceAccumulation := range self.accumulatedProtocolFeePerStake {
			info.ProtocolFeeDebt[tokenPath] = protocolFeePriceAccumulation.Clone()
		}
		self.stakerInfos.Set(staker.String(), info)
		return
	}

	info := StakerRewardInfo{
		StartHeight:        currentHeight,
		RewardDebt:         self.accumulatedGNSRewardPerStake.Clone(),
		StakedAmount:       amount,
		GnsRewardClaimed:   0,
		ProtocolFeeClaimed: make(map[string]uint64),
		ProtocolFeeDebt:    make(map[string]*u256.Uint),
		LastClaimedHeight:  0,
	}

	for tokenPath, protocolFeePriceAccumulation := range self.accumulatedProtocolFeePerStake {
		info.ProtocolFeeDebt[tokenPath] = protocolFeePriceAccumulation.Clone()
	}

	self.stakerInfos.Set(staker.String(), info)
}

func (self *RewardState) claim(staker std.Address, currentBalance uint64, currentProtocolFeeBalances map[string]uint64) (uint64, map[string]uint64) {
	if !self.stakerInfos.Has(staker.String()) {
		return 0, make(map[string]uint64)
	}

	stakerRewardInfo := self.Info(staker)
	currentHeight := uint64(std.ChainHeight())
	if stakerRewardInfo.LastClaimedHeight == currentHeight {
		return 0, make(map[string]uint64)
	}

	self.finalize(currentBalance, currentProtocolFeeBalances)

	reward, protocolFeeRewards := self.deductReward(staker, currentBalance)

	return reward, protocolFeeRewards
}

func (self *RewardState) removeStake(staker std.Address, amount uint64, currentBalance uint64, currentProtocolFeeBalances map[string]uint64) (uint64, map[string]uint64) {
	self.finalize(currentBalance, currentProtocolFeeBalances)

	reward, protocolFeeRewards := self.deductReward(staker, currentBalance)

	self.stakerInfos.Remove(staker.String())

	self.totalXGNSStake -= amount

	return reward, protocolFeeRewards
}

// GetRewardByProjectWallet returns the amount of reward for the project wallet
func GetRewardByProjectWallet(addr std.Address) (uint64, map[string]uint64) {
	rewardState.finalize(collectAndGetGNSBalance(), updateAndGetProtocolFeeBalance())
	emissionReward, protocolFeeRewards := rewardState.CalculateReward(addr)
	return emissionReward, protocolFeeRewards
}

// SetAmountByProjectWallet sets the amount of reward for the project wallet
func SetAmountByProjectWallet(addr std.Address, amount uint64, add bool) {
	caller := std.PreviousRealm().Address()
	if err := common.LaunchpadOnly(caller); err != nil {
		panic(err)
	}
	if err := halt.IsHalted(); err != nil {
		panic(err)
	}

	currentAmount := getAmountByProjectWallet(addr)
	if add {
		amountByProjectWallet.Set(addr.String(), currentAmount+amount)
		rewardState.addStake(uint64(std.ChainHeight()), addr, amount, collectAndGetGNSBalance(), updateAndGetProtocolFeeBalance())
	} else {
		amountByProjectWallet.Set(addr.String(), currentAmount-amount)
		rewardState.removeStake(addr, amount, collectAndGetGNSBalance(), updateAndGetProtocolFeeBalance())
	}
}

// isLaunchpadProjectWallet returns true if the address is a project wallet
func isLaunchpadProjectWallet(addr std.Address) bool {
	if amountByProjectWallet.Has(addr.String()) {
		return true
	}
	return false
}

// getAmountByProjectWallet returns the amount of xGNS staked by the project wallet
func getAmountByProjectWallet(addr std.Address) uint64 {
	value, exists := amountByProjectWallet.Get(addr.String())
	if !exists {
		return 0
	}
	return value.(uint64)
}

// calculateXGnsRatio calculates the ratio of user's xGNS amount to total xGNS supply
func calculateXGnsRatio(amount uint64, xGnsX96 *u256.Uint) *u256.Uint {
	xGnsAmountX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96)
	xGnsAmountX96 = new(u256.Uint).Mul(xGnsAmountX96, u256.NewUint(1_000_000_000))

	ratio := new(u256.Uint).Div(xGnsAmountX96, xGnsX96)
	ratio = ratio.Mul(ratio, q96)
	return ratio.Div(ratio, u256.NewUint(1_000_000_000))
}
