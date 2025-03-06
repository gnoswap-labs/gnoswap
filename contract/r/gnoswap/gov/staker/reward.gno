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

	// For Launchpad deposit
	q96                   = u256.MustFromDecimal(consts.Q96)
	amountByProjectWallet = avl.NewTree() // recipient wallet => amount
	rewardByProjectWallet = avl.NewTree() // recipient wallet => reward
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
	StartHeight          uint64                // height when staker started staking
	PriceDebt            *u256.Uint            // price debt per xGNS stake, Q128
	ProtocolFeePriceDebt map[string]*u256.Uint // protocol fee debt per xGNS stake, Q128
	Amount               uint64                // amount of xGNS staked
	Claimed              uint64                // amount of GNS reward claimed so far
	ProtocolFeeClaimed   map[string]uint64     // protocol fee amount claimed per token
	LastClaimedHeight    uint64                // last height when the reward was claimed
}

func (self *StakerRewardInfo) Debug() string {
	return ufmt.Sprintf("{ StartHeight: %d, PriceDebt: %d, Amount: %d, Claimed: %d }", self.StartHeight, self.PriceDebtUint64(), self.Amount, self.Claimed)
}

func (self *StakerRewardInfo) PriceDebtUint64() uint64 {
	return u256.Zero().Rsh(self.PriceDebt, 128).Uint64()
}

type RewardState struct {
	// CurrentBalance is sum of all the previous balances, including the reward distribution.
	CurrentBalance               uint64                // current balance of gov/staker, used to calculate RewardAccumulation
	CurrentProtocolFeeBalance    map[string]uint64     // current protocol fee balance per token
	PriceAccumulation            *u256.Uint            // claimable GNS per xGNS stake, Q128
	ProtocolFeePriceAccumulation map[string]*u256.Uint // protocol fee debt per xGNS stake, Q128
	TotalStake                   uint64                // total xGNS staked

	info *avl.Tree // address -> StakerRewardInfo
}

func NewRewardState() *RewardState {
	return &RewardState{
		info:                         avl.NewTree(),
		CurrentBalance:               0,
		CurrentProtocolFeeBalance:    make(map[string]uint64),
		PriceAccumulation:            u256.Zero(),
		ProtocolFeePriceAccumulation: make(map[string]*u256.Uint),
		TotalStake:                   0,
	}
}

var rewardState = NewRewardState()

func (self *RewardState) Debug() string {
	return ufmt.Sprintf("{ CurrentBalance: %d, PriceAccumulation: %d, TotalStake: %d, info: len(%d) }", self.CurrentBalance, self.PriceAccumulationUint64(), self.TotalStake, self.info.Size())
}

func (self *RewardState) Info(staker std.Address) StakerRewardInfo {
	infoI, exists := self.info.Get(staker.String())
	if !exists {
		return StakerRewardInfo{
			StartHeight:          uint64(std.ChainHeight()),
			PriceDebt:            u256.Zero(),
			ProtocolFeePriceDebt: make(map[string]*u256.Uint),
			Amount:               0,
			Claimed:              0,
			ProtocolFeeClaimed:   make(map[string]uint64),
			LastClaimedHeight:    0,
		}
	}
	return infoI.(StakerRewardInfo)
}

func (self *RewardState) CalculateReward(staker std.Address) (uint64, map[string]uint64) {
	info := self.Info(staker)
	stakerPrice := u256.Zero().Sub(self.PriceAccumulation, info.PriceDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.Amount))
	reward = reward.Rsh(reward, 128)

	protocolFeeRewards := make(map[string]uint64)
	for tokenPath, protocolFeePriceAccumulation := range self.ProtocolFeePriceAccumulation {
		protocolFeePriceDebt, ok := info.ProtocolFeePriceDebt[tokenPath]
		if !ok {
			protocolFeePriceDebt = u256.Zero()
		}
		protocolFeePrice := u256.Zero().Sub(protocolFeePriceAccumulation, protocolFeePriceDebt)
		protocolFeeReward := u256.Zero().Mul(protocolFeePrice, u256.NewUint(info.Amount))
		protocolFeeReward = protocolFeeReward.Rsh(protocolFeeReward, 128)
		protocolFeeReward64 := protocolFeeReward.Uint64()
		if protocolFeeReward64 > 0 {
			protocolFeeRewards[tokenPath] = protocolFeeReward64
		}
	}
	return reward.Uint64(), protocolFeeRewards
}

func (self *RewardState) PriceAccumulationUint64() uint64 {
	return u256.Zero().Rsh(self.PriceAccumulation, 128).Uint64()
}

// amount MUST be less than or equal to the amount of xGNS staked
// This function does not check it
func (self *RewardState) deductReward(staker std.Address, currentBalance uint64) (uint64, map[string]uint64) {
	info := self.Info(staker)
	stakerPrice := u256.Zero().Sub(self.PriceAccumulation, info.PriceDebt)
	reward := u256.Zero().Mul(stakerPrice, u256.NewUint(info.Amount))
	reward = reward.Rsh(reward, 128)
	reward64 := reward.Uint64()
	reward64 -= info.Claimed
	info.Claimed += reward64

	protocolFeeRewards := make(map[string]uint64)
	for tokenPath, protocolFeePriceAccumulation := range self.ProtocolFeePriceAccumulation {
		protocolFeePriceDebt, ok := info.ProtocolFeePriceDebt[tokenPath]
		if !ok {
			protocolFeePriceDebt = u256.Zero()
		}
		protocolFeePrice := u256.Zero().Sub(protocolFeePriceAccumulation, protocolFeePriceDebt)
		protocolFeeReward := u256.Zero().Mul(protocolFeePrice, u256.NewUint(info.Amount))
		protocolFeeReward = protocolFeeReward.Rsh(protocolFeeReward, 128)
		protocolFeeReward64 := protocolFeeReward.Uint64()
		if protocolFeeReward64 == 0 {
			continue
		}
		protocolFeeReward64 -= info.ProtocolFeeClaimed[tokenPath]
		protocolFeeRewards[tokenPath] = protocolFeeReward64
		info.ProtocolFeeClaimed[tokenPath] += protocolFeeReward64
	}

	info.LastClaimedHeight = uint64(std.ChainHeight())
	self.info.Set(staker.String(), info)

	self.CurrentBalance = currentBalance - reward64
	for tokenPath, amount := range protocolFeeRewards {
		self.CurrentProtocolFeeBalance[tokenPath] -= amount
	}

	return reward64, protocolFeeRewards
}

// This function MUST be called as a part of addStake or removeStake
// CurrentBalance / StakeChange / IsRemoveStake will be updated in those functions
func (self *RewardState) finalize(currentBalance uint64, currentProtocolFeeBalances map[string]uint64) {
	if self.TotalStake == uint64(0) {
		// no staker
		return
	}

	// emission reward
	delta := currentBalance - self.CurrentBalance
	deltaU256 := u256.NewUint(delta)
	deltaU256Q128 := deltaU256.Lsh(deltaU256, 128)
	emissionRewardPerOneStakedQ128 := u256.Zero().Div(deltaU256Q128, u256.NewUint(self.TotalStake))
	self.PriceAccumulation.Add(self.PriceAccumulation, emissionRewardPerOneStakedQ128)
	self.CurrentBalance = currentBalance

	// protocol fee reward
	for tokenPath, protocolFeeBalance := range currentProtocolFeeBalances {
		protocolFeeDelta := protocolFeeBalance - self.CurrentProtocolFeeBalance[tokenPath]
		if protocolFeeDelta == 0 {
			continue
		}
		protocolFeeDeltaU256 := u256.NewUint(protocolFeeDelta)
		protocolFeeDeltaU256Q128 := protocolFeeDeltaU256.Lsh(protocolFeeDeltaU256, 128)
		protocolFeeRewardPerOneStakedQ128 := u256.Zero().Div(protocolFeeDeltaU256Q128, u256.NewUint(self.TotalStake))
		protocolFeePriceAccumulation, ok := self.ProtocolFeePriceAccumulation[tokenPath]
		if !ok {
			protocolFeePriceAccumulation = u256.Zero()
		}
		self.ProtocolFeePriceAccumulation[tokenPath] = u256.Zero().Add(protocolFeePriceAccumulation, protocolFeeRewardPerOneStakedQ128)
		self.CurrentProtocolFeeBalance[tokenPath] = protocolFeeBalance
	}
}

func (self *RewardState) addStake(currentHeight uint64, staker std.Address, amount uint64, currentBalance uint64, currentProtocolFeeBalances map[string]uint64) {
	self.finalize(currentBalance, currentProtocolFeeBalances)

	self.TotalStake += amount

	if self.info.Has(staker.String()) {
		info := self.Info(staker)
		info.PriceDebt.Add(info.PriceDebt, u256.NewUint(info.Amount))
		info.PriceDebt.Add(info.PriceDebt, u256.Zero().Mul(self.PriceAccumulation, u256.NewUint(amount)))
		info.PriceDebt.Div(info.PriceDebt, u256.NewUint(self.TotalStake))
		for tokenPath, amount := range currentProtocolFeeBalances {
			protocolFeePriceDebt, ok := info.ProtocolFeePriceDebt[tokenPath]
			if !ok {
				info.ProtocolFeePriceDebt[tokenPath] = self.ProtocolFeePriceAccumulation[tokenPath].Clone()
				continue
			}
			protocolFeePriceDebt.Add(protocolFeePriceDebt, u256.NewUint(amount))
			protocolFeePriceDebt.Add(protocolFeePriceDebt, u256.Zero().Mul(self.ProtocolFeePriceAccumulation[tokenPath], u256.NewUint(amount)))
			protocolFeePriceDebt.Div(protocolFeePriceDebt, u256.NewUint(self.TotalStake))
			info.ProtocolFeePriceDebt[tokenPath] = protocolFeePriceDebt
		}
		info.Amount += amount
		self.info.Set(staker.String(), info)
		return
	}

	info := StakerRewardInfo{
		StartHeight:          currentHeight,
		PriceDebt:            self.PriceAccumulation.Clone(),
		Amount:               amount,
		Claimed:              0,
		ProtocolFeeClaimed:   make(map[string]uint64),
		ProtocolFeePriceDebt: make(map[string]*u256.Uint),
		LastClaimedHeight:    0,
	}

	for tokenPath, protocolFeePriceAccumulation := range self.ProtocolFeePriceAccumulation {
		info.ProtocolFeePriceDebt[tokenPath] = protocolFeePriceAccumulation.Clone()
	}

	self.info.Set(staker.String(), info)
}

func (self *RewardState) claim(staker std.Address, currentBalance uint64, currentProtocolFeeBalances map[string]uint64) (uint64, map[string]uint64) {
	if !self.info.Has(staker.String()) {
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

	self.info.Remove(staker.String())

	self.TotalStake -= amount

	return reward, protocolFeeRewards
}

// GetRewardByProjectWallet returns the amount of reward for the project wallet
func GetRewardByProjectWallet(addr std.Address) uint64 {
	// launchpad 의 reward를 계산
	// getAmountByProjectWallet(addr) 로 value를 가져옴
	// reward에서 value만큼 처리 ?
	value, exists := rewardByProjectWallet.Get(addr.String())
	if !exists {
		return 0
	}
	return value.(uint64)
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

	en.MintAndDistributeGns()

	currentAmount := getAmountByProjectWallet(addr)
	if add {
		amountByProjectWallet.Set(addr.String(), currentAmount+amount)
		rewardState.addStake(uint64(std.ChainHeight()), addr, amount, collectAndGetGNSBalance(), updateAndGetProtocolFeeBalance())
	} else {
		amountByProjectWallet.Set(addr.String(), currentAmount-amount)
		rewardState.removeStake(addr, amount, collectAndGetGNSBalance(), updateAndGetProtocolFeeBalance())
	}
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
