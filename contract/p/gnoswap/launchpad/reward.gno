package launchpad

import (
	"errors"
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// common functions for reward calculation
// TODO: p/reward?
type RewardCalculator interface {
	Finalize(currentHeight, totalStaked uint64, rewardPerBlock *u256.Uint) (*u256.Uint, error)
	Deduct(depositId string, currentHeight uint64, depositState *DepositState) (uint64, error)
}

var _ RewardCalculator = (*Reward)(nil)

// Reward represents the reward information for a specific deposit.
type Reward struct {
	accumRewardPerDeposit *u256.Uint // claimable Launchpad reward per GNS stake, Q128
	lastHeight            uint64     // last height when reward was calculated
	endHeight             uint64     // end height of reward calculation
	info                  *avl.Tree  // depositId -> RewardInfo
}

func (r *Reward) AccumRewardPerDeposit() *u256.Uint {
	return r.accumRewardPerDeposit
}

func (r *Reward) SetAccumRewardPerDeposit(v *u256.Uint) {
	r.accumRewardPerDeposit = v
}

func (r *Reward) LastHeight() uint64     { return r.lastHeight }
func (r *Reward) SetLastHeight(v uint64) { r.lastHeight = v }
func (r *Reward) EndHeight() uint64      { return r.endHeight }
func (r *Reward) SetEndHeight(v uint64)  { r.endHeight = v }

func (r *Reward) InfoOf(depositId string) (*RewardInfo, error) {
	v, exists := r.info.Get(depositId)
	if !exists {
		return nil, ufmt.Errorf("depositId(%s) not found", depositId)
	}

	info, ok := v.(*RewardInfo)
	if !ok {
		return nil, ufmt.Errorf("invalid reward info type")
	}

	return info, nil
}

// NewReward create a new Reward instance.
func NewReward(
	accumulatedRewardPerDeposit *u256.Uint,
	lastHeight, endHeight uint64,
) *Reward {
	return &Reward{
		accumRewardPerDeposit: accumulatedRewardPerDeposit,
		lastHeight:            lastHeight,
		endHeight:             endHeight,
		info:                  avl.NewTree(),
	}
}

func (r *Reward) CalculateRewardPerDeposit(
	rewardPerBlock *u256.Uint,
	totalStaked uint64,
) (*u256.Uint, error) {
	currentHeight := uint64(std.GetHeight())
	lastUpdatedheight := r.LastHeight()
	if currentHeight == lastUpdatedheight {
		return u256.Zero(), nil
	}

	if currentHeight < lastUpdatedheight {
		return nil, ufmt.Errorf("currentHeight(%d) < lastUpdatedheight(%d)", currentHeight, lastUpdatedheight)
	}

	if rewardPerBlock.IsZero() {
		return nil, errors.New("no left reward")
	}

	if totalStaked == 0 {
		return u256.Zero(), nil
	}

	if currentHeight > r.EndHeight() {
		currentHeight = r.EndHeight()
	}

	blockDuration := currentHeight - lastUpdatedheight
	totalReward := u256.Zero().Mul(u256.NewUint(blockDuration), rewardPerBlock)
	rewardPerDeposit := u256.Zero().Div(totalReward, u256.NewUint(totalStaked))
	return rewardPerDeposit, nil
}

func (r *Reward) AddRewardPerDeposit(amount *u256.Uint) {
	if amount.IsZero() {
		return
	}

	r.SetAccumRewardPerDeposit(u256.Zero().Add(r.AccumRewardPerDeposit(), amount))
}

// implement RewardCalculator interface

func (r *Reward) Finalize(
	currentHeight, totalStaked uint64,
	rewardPerBlock *u256.Uint,
) (*u256.Uint, error) {
	lastHeight := r.LastHeight()
	endHeight := r.EndHeight()

	if currentHeight < lastHeight {
		return nil, ufmt.Errorf("currentHeight(%d) < lastHeight(%d)", currentHeight, lastHeight)
	}

	if lastHeight > endHeight {
		return nil, ufmt.Errorf("lastHeight(%d) > endHeight(%d)", lastHeight, endHeight)
	}

	if currentHeight > endHeight {
		currentHeight = endHeight
	}

	return r.CalculateRewardPerDeposit(rewardPerBlock, totalStaked)
}

func (r *Reward) Deduct(depositId string, currentHeight uint64, depositState *DepositState) (uint64, error) {
	if currentHeight < r.LastHeight() {
		return 0, ufmt.Errorf("currentHeight(%d) < lastHeight(%d)", currentHeight, r.LastHeight())
	}

	deposit := depositState.MustGetDeposit(depositId)
	if currentHeight < deposit.ClaimableHeight() {
		return 0, ufmt.Errorf("currentHeight(%d) < claimableHeight(%d)", currentHeight, deposit.ClaimableHeight())
	}

	info, err := r.InfoOf(depositId)
	if err != nil {
		return 0, err
	}

	if currentHeight < info.StartHeight() {
		return 0, ufmt.Errorf("currentHeight(%d) < startHeight(%d)", currentHeight, info.StartHeight())
	}

	reward64 := info.reward(r.AccumRewardPerDeposit())
	if reward64 == 0 {
		return 0, nil
	}

	info.SetClaimed(info.Claimed() + reward64)
	r.info.Set(depositId, info)

	return reward64, nil
}

// RewardInfo represents the reward information for a specific deposit.
type RewardInfo struct {
	priceDebt     *u256.Uint // price debt per GNS stake, Q128
	depositAmount uint64     // amount of GNS staked
	rewardAmount  uint64     // calculated, not collected
	claimed       uint64     // amount of reward claimed so far
	startHeight   uint64     // height when launchpad started staking
	EndHeight     uint64     // end height of reward calculation
	LastHeight    uint64     // last height when reward was calculated
}

func (i *RewardInfo) PriceDebt() *u256.Uint     { return i.priceDebt }
func (i *RewardInfo) SetPriceDebt(v *u256.Uint) { i.priceDebt = v }
func (i *RewardInfo) DepositAmount() uint64     { return i.depositAmount }
func (i *RewardInfo) SetDepositAmount(v uint64) { i.depositAmount = v }
func (i *RewardInfo) RewardAmount() uint64      { return i.rewardAmount }
func (i *RewardInfo) SetRewardAmount(v uint64)  { i.rewardAmount = v }
func (i *RewardInfo) Claimed() uint64           { return i.claimed }
func (i *RewardInfo) SetClaimed(v uint64)       { i.claimed = v }
func (i *RewardInfo) StartHeight() uint64      { return i.startHeight }

func NewRewardInfo(
	priceDebt *u256.Uint,
	depositAmount, rewardAmount, claimed, startHeight, endHeight, lastHeight uint64,
) *RewardInfo {
	return &RewardInfo{
		priceDebt:     priceDebt,
		depositAmount: depositAmount,
		rewardAmount:  rewardAmount,
		claimed:       claimed,
		startHeight:   startHeight,
		EndHeight:     endHeight,
		LastHeight:    lastHeight,
	}
}

func (i *RewardInfo) reward(accumulated *u256.Uint) uint64 {
	actual := u256.Zero().Sub(accumulated, i.PriceDebt())
	reward := u256.Zero().Mul(actual, u256.NewUint(i.DepositAmount()))
	reward = u256.Zero().Rsh(reward, 128)
	return reward.Uint64() - i.Claimed()
}

// CalculateTierRewardRate calculates the reward per block with Q128 precision
func CalculateTierRewardRate(tierAmount uint64, duration uint64) *u256.Uint {
	tierAmountX128 := new(u256.Uint).Mul(u256.NewUint(tierAmount), q128)
	return new(u256.Uint).Div(tierAmountX128, u256.NewUint(duration))
}
