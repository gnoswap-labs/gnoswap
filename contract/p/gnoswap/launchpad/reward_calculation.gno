package launchpad

import (
	"errors"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	errInvalidRewardState    = errors.New("invalid reward state")
	errNotExistDeposit       = errors.New("deposit does not exist")
	errAlreadyExistedDeposit = errors.New("deposit already existed")
)

// DepositInfo represents the minimal interface needed for deposit information
type DepositInfo interface {
	ClaimableHeight() uint64
	ID() string
}

// RewardStateStore defines the interface for reward state storage
type RewardStateStore interface {
	Get(pid, tier string) (*RewardState, error)
	Set(pid, tier string, state *RewardState)
	DeleteProject(pid string) uint64
}

// StakerRewardInfo holds staking reward information
type StakerRewardInfo struct {
	startHeight uint64     // height when launchpad started staking
	priceDebt   *u256.Uint // price debt per GNS stake, Q128
	amount      uint64     // amount of GNS staked
	claimed     uint64     // amount of reward claimed so far
}

// Getters for StakerRewardInfo
func (sri *StakerRewardInfo) StartHeight() uint64   { return sri.startHeight }
func (sri *StakerRewardInfo) PriceDebt() *u256.Uint { return sri.priceDebt }
func (sri *StakerRewardInfo) Amount() uint64        { return sri.amount }
func (sri *StakerRewardInfo) Claimed() uint64       { return sri.claimed }

func NewStakerRewardInfo(startHeight uint64, priceDebt *u256.Uint, amount uint64) *StakerRewardInfo {
	return &StakerRewardInfo{
		startHeight: startHeight,
		priceDebt:   priceDebt.Clone(),
		amount:      amount,
		claimed:     0,
	}
}

func (sri *StakerRewardInfo) PriceDebtUint64() uint64 {
	return fromQ128(sri.priceDebt)
}

func (sri *StakerRewardInfo) AddClaimed(amount uint64) {
	sri.claimed += amount
}

// RewardState manages the reward calculation state
type RewardState struct {
	priceAccumulation *u256.Uint // claimable Launchpad reward per xGNS stake, Q128
	totalStake        uint64     // total xGNS staked
	lastHeight        uint64     // last height when reward was calculated
	rewardPerBlock    *u256.Uint // reward per block
	endHeight         uint64
	totalEmptyBlock   uint64
	info              *avl.Tree // depositId -> StakerRewardInfo
}

// Getters for RewardState
func (rs *RewardState) PriceAccumulation() *u256.Uint { return rs.priceAccumulation }
func (rs *RewardState) TotalStake() uint64            { return rs.totalStake }
func (rs *RewardState) LastHeight() uint64            { return rs.lastHeight }
func (rs *RewardState) RewardPerBlock() *u256.Uint    { return rs.rewardPerBlock }
func (rs *RewardState) EndHeight() uint64             { return rs.endHeight }
func (rs *RewardState) TotalEmptyBlock() uint64       { return rs.totalEmptyBlock }

func NewRewardState(rewardPerBlock *u256.Uint, startHeight uint64, endHeight uint64) *RewardState {
	return &RewardState{
		priceAccumulation: u256.Zero(),
		totalStake:        0,
		lastHeight:        startHeight,
		rewardPerBlock:    rewardPerBlock,
		endHeight:         endHeight,
		info:              avl.NewTree(),
	}
}

func (rs *RewardState) PriceAccumulationUint64() uint64 {
	return fromQ128(rs.priceAccumulation)
}

func (rs *RewardState) RewardPerBlockUint64() uint64 {
	return fromQ128(rs.rewardPerBlock)
}

func (rs *RewardState) GetInfo(depositId string) (*StakerRewardInfo, error) {
	infoI, exists := rs.info.Get(depositId)
	if !exists {
		return nil, errNotExistDeposit
	}
	info := infoI.(StakerRewardInfo)
	return &info, nil
}

// CalculateReward calculates the claimable reward for a deposit
func (rs *RewardState) CalculateReward(depositId string) (uint64, error) {
	info, err := rs.GetInfo(depositId)
	if err != nil {
		return 0, err
	}

	stakerPrice := u256.Zero().Sub(rs.priceAccumulation, info.priceDebt)
	reward := stakerPrice.Mul(stakerPrice, u256.NewUint(info.amount))
	reward = reward.Rsh(reward, 128)
	return reward.Uint64() - info.claimed, nil
}

// DeductReward calculates and deducts the reward for a deposit
func (rs *RewardState) DeductReward(deposit DepositInfo, currentHeight uint64) (uint64, error) {
	if currentHeight < rs.lastHeight {
		return 0, errInvalidRewardState
	}

	if deposit.ClaimableHeight() > currentHeight {
		return 0, errInvalidRewardState
	}

	info, err := rs.GetInfo(deposit.ID())
	if err != nil {
		return 0, err
	}

	if info.startHeight > currentHeight {
		return 0, errInvalidRewardState
	}

	reward64, err := rs.CalculateReward(deposit.ID())
	if err != nil {
		return 0, err
	}

	if reward64 == 0 {
		return 0, nil
	}

	info.AddClaimed(reward64)
	rs.info.Set(deposit.ID(), *info)

	return reward64, nil
}

// Finalize updates the reward state for the current height
func (rs *RewardState) Finalize(currentHeight uint64) error {
	if currentHeight <= rs.lastHeight {
		return nil // Not started yet
	}
	if rs.lastHeight >= rs.endHeight {
		return nil // already ended
	}
	if currentHeight > rs.endHeight {
		currentHeight = rs.endHeight
	}

	diff := currentHeight - rs.lastHeight
	delta := u256.NewUint(diff)
	delta = delta.Mul(delta, rs.rewardPerBlock)

	if rs.totalStake == 0 {
		rs.totalEmptyBlock += diff
		rs.lastHeight = currentHeight
		return nil
	}

	price := delta.Div(delta, u256.NewUint(rs.totalStake))
	rs.priceAccumulation = u256.Zero().Add(rs.priceAccumulation, price)
	rs.lastHeight = currentHeight
	return nil
}

// AddStake adds a new stake to the reward state
func (rs *RewardState) AddStake(currentHeight uint64, depositId string, amount uint64) error {
	if rs.info.Has(depositId) {
		return errAlreadyExistedDeposit
	}

	if err := rs.Finalize(currentHeight); err != nil {
		return err
	}

	rs.totalStake += amount

	info := NewStakerRewardInfo(
		currentHeight,
		rs.priceAccumulation,
		amount,
	)

	rs.info.Set(depositId, *info)
	return nil
}

// Claim processes a reward claim for a deposit
func (rs *RewardState) Claim(depositId string, currentHeight uint64) (uint64, error) {
	if !rs.info.Has(depositId) {
		return 0, errNotExistDeposit
	}

	if err := rs.Finalize(currentHeight); err != nil {
		return 0, err
	}

	reward, err := rs.DeductReward(&depositInfo{
		id:              depositId,
		claimableHeight: currentHeight,
	}, currentHeight)
	if err != nil {
		return 0, err
	}

	return reward, nil
}

// RemoveStake removes a stake and returns the final reward
func (rs *RewardState) RemoveStake(depositId string, amount uint64, currentHeight uint64) (uint64, error) {
	if !rs.info.Has(depositId) {
		return 0, errNotExistDeposit
	}

	if err := rs.Finalize(currentHeight); err != nil {
		return 0, err
	}

	dpstInfo := &depositInfo{
		id:              depositId,
		claimableHeight: currentHeight,
	}

	reward, err := rs.DeductReward(dpstInfo, currentHeight)
	if err != nil {
		return 0, err
	}

	rs.info.Remove(depositId)
	rs.totalStake -= amount

	return reward, nil
}

// region: RewardStates

type RewardStates struct {
	states *avl.Tree // projectId:tier string -> RewardState
}

func NewRewardStates() RewardStates {
	return RewardStates{
		states: avl.NewTree(),
	}
}

func (rs *RewardStates) Get(pid, tier string) (*RewardState, error) {
	key := createId(pid, tier)
	statesI, exists := rs.states.Get(key)
	if !exists {
		return nil, ufmt.Errorf("reward state not found for projectId %s and tierStr %s", pid, tier)
	}
	return statesI.(*RewardState), nil
}

func (rs *RewardStates) Set(pid, tier string, state *RewardState) error {
	key := createId(pid, tier)
	ok := rs.states.Set(key, state)
	if !ok {
		return ufmt.Errorf("failed to set reward state for projectId %s and tierStr %s", pid, tier)
	}
	return nil
}

func (rs *RewardStates) DeleteProject(pid string) uint64 {
	totalLeftOver := uint64(0)

	keys := make([]string, 0)
	rs.states.Iterate(pid+":", pid+";", func(key string, value interface{}) bool {
		state := value.(*RewardState)
		totalEmptyBlock := state.TotalEmptyBlock()
		if state.TotalStake() == 0 {
			totalEmptyBlock += state.EndHeight() - state.LastHeight()
		}

		totalEmptyRewards := u256.Zero().Mul(u256.NewUint(totalEmptyBlock), state.RewardPerBlock())
		totalLeftOver += totalEmptyRewards.Uint64()
		keys = append(keys, key)
		return false
	})

	for _, key := range keys {
		rs.states.Remove(key)
	}

	return totalLeftOver
}

// region: depositInfo

// Helper struct for deposit info
type depositInfo struct {
	id              string
	claimableHeight uint64
}

func (d *depositInfo) ID() string              { return d.id }
func (d *depositInfo) ClaimableHeight() uint64 { return d.claimableHeight }

func fromQ128(x *u256.Uint) uint64 {
	return u256.Zero().Rsh(x, 128).Uint64()
}
