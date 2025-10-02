package launchpad

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// RewardManager manages the distribution of rewards for a project tier.
//
// This struct contains the necessary data and methods to calculate and track
// rewards for deposits associated with a project tier.
//
// Fields:
// - rewards (avl.Tree): A map of deposit IDs to their associated reward states.
// - distributeAmountPerSecondX128 (u256.Uint): The amount of tokens to be distributed per second, represented as a Q128 fixed-point number.
// - accumulatedRewardPerDepositX128 (u256.Uint): The accumulated reward per GNS stake, represented as a Q128 fixed-point number.
// - totalDistributeAmount (int64): The total amount of tokens to be distributed.
// - totalClaimedAmount (int64): The total amount of tokens claimed.
// - distributeStartTime (int64): The start time of the reward calculation.
// - distributeEndTime (int64): The end time of the reward calculation.
// - accumulatedDistributeAmount (int64): The accumulated amount of tokens distributed.
// - accumulatedHeight (int64): The last height when reward was calculated.
// - rewardClaimableDuration (int64): The duration of reward claimable.
type RewardManager struct {
	rewards *avl.Tree // depositId -> RewardState

	distributeAmountPerSecondX128   *u256.Uint // distribute amount per second, Q128
	accumulatedRewardPerDepositX128 *u256.Uint // accumulated reward per GNS stake, Q128

	totalDistributeAmount       int64 // total distributed amount
	totalClaimedAmount          int64 // total claimed amount
	distributeStartTime         int64 // start time of reward calculation
	distributeEndTime           int64 // end time of reward calculation
	accumulatedDistributeAmount int64 // accumulated distribute amount
	accumulatedHeight           int64 // last height when reward was calculated
	accumulatedTime             int64 // last time when reward was calculated
	rewardClaimableDuration     int64 // duration of reward claimable
}

func (r *RewardManager) IsInitialized() bool {
	return r.rewards.Size() > 0
}

func (r *RewardManager) DistributeAmountPerSecondX128() *u256.Uint {
	return r.distributeAmountPerSecondX128
}

func (r *RewardManager) AccumulatedHeight() int64 {
	return r.accumulatedHeight
}

func (r *RewardManager) AccumulatedTime() int64 {
	return r.accumulatedTime
}

func (r *RewardManager) DistributeEndTime() int64 {
	return r.distributeEndTime
}

func (r *RewardManager) AccumulatedRewardPerDepositX128() *u256.Uint {
	return r.accumulatedRewardPerDepositX128
}

func (r *RewardManager) AccumulatedReward() int64 {
	res := u256.Zero().Rsh(r.accumulatedRewardPerDepositX128, 128)
	return safeConvertToInt64(res)
}

func (r *RewardManager) getDepositRewardState(depositId string) (*RewardState, error) {
	rewardStateI, exists := r.rewards.Get(depositId)
	if !exists {
		return nil, makeErrorWithDetails(errNotExistDeposit, ufmt.Sprintf("(%s)", depositId))
	}

	rewardState, ok := rewardStateI.(*RewardState)
	if !ok {
		return nil, ufmt.Errorf("failed to cast rewardState to *RewardState: %T", rewardStateI)
	}

	return rewardState, nil
}

func (r *RewardManager) calculateRewardPerDepositX128(rewardPerSecondX128 *u256.Uint, totalStaked int64, currentTime int64) (*u256.Uint, error) {
	accumulatedTime := r.accumulatedTime
	if r.distributeStartTime > accumulatedTime {
		accumulatedTime = r.distributeStartTime
	}

	// not started yet
	if currentTime < accumulatedTime {
		return u256.Zero(), nil
	}

	// past distribute end time
	if accumulatedTime > r.distributeEndTime {
		return u256.Zero(), nil
	}

	// past distribute end time, set to distribute end time
	if currentTime > r.distributeEndTime {
		currentTime = r.distributeEndTime
	}

	if rewardPerSecondX128.IsZero() {
		return nil, makeErrorWithDetails(
			errNoLeftReward,
			ufmt.Sprintf("rewardPerSecond(%d)", rewardPerSecondX128),
		)
	}

	// no left reward
	if totalStaked == 0 {
		return u256.Zero(), nil
	}

	// timeDuration * rewardPerSecond / totalStaked
	timeDuration := currentTime - accumulatedTime
	rewardPerDepositX128 := u256.MulDiv(
		u256.NewUintFromInt64(timeDuration),
		rewardPerSecondX128,
		u256.NewUintFromInt64(totalStaked),
	)

	return rewardPerDepositX128, nil
}

func (r *RewardManager) addRewardStateByDeposit(deposit *Deposit) *RewardState {
	claimableTime := deposit.DepositTime() + r.rewardClaimableDuration

	rewardState := NewRewardState(
		r.AccumulatedRewardPerDepositX128(),
		deposit.DepositAmount(),
		deposit.DepositTime(),
		r.distributeEndTime,
		claimableTime,
	)

	// if the first deposit, set the distribute start height
	if !r.IsInitialized() {
		rewardState.setDistributeStartTime(r.distributeStartTime)
		rewardState.setDistributeEndTime(r.distributeEndTime)
		rewardState.setAccumulatedTime(r.distributeStartTime)
		rewardState.setPriceDebtX128(u256.Zero())
	}

	return r.addRewardState(deposit, rewardState)
}

func (r *RewardManager) addRewardState(deposit *Deposit, rewardState *RewardState) *RewardState {
	r.rewards.Set(deposit.ID(), rewardState)

	return rewardState
}

func (r *RewardManager) addRewardPerDepositX128(rewardPerDepositX128 *u256.Uint, currentHeight, currentTime int64) error {
	if rewardPerDepositX128.IsZero() {
		return nil
	}

	if r.accumulatedTime > currentTime || r.distributeStartTime > currentTime {
		return nil
	}

	if currentTime > r.distributeEndTime {
		currentTime = r.distributeEndTime
	}

	accumulated := u256.Zero().Add(r.accumulatedRewardPerDepositX128, rewardPerDepositX128)
	r.accumulatedRewardPerDepositX128 = accumulated
	r.accumulatedHeight = currentHeight
	r.accumulatedTime = currentTime

	return nil
}

// updateRewardPerDepositX128 updates the reward per deposit state.
// This function calculates and updates the accumulated reward per deposit
// based on the current total deposit amount and height.
//
// Parameters:
// - totalDepositAmount (int64): Current total deposit amount
// - height (int64): Current blockchain height
// - time (int64): Current timestamp
//
// Returns:
// - error: If the update fails
func (r *RewardManager) updateRewardPerDepositX128(totalDepositAmount int64, currentHeight, currentTime int64) error {
	if currentTime <= 0 {
		return makeErrorWithDetails(errInvalidTime, "time must be positive")
	}

	// Calculate and update rewards
	rewardPerDepositX128, err := r.calculateRewardPerDepositX128(
		r.distributeAmountPerSecondX128,
		totalDepositAmount,
		currentTime,
	)
	if err != nil {
		return err
	}

	err = r.addRewardPerDepositX128(rewardPerDepositX128, currentHeight, currentTime)
	if err != nil {
		return err
	}

	return nil
}

func (r *RewardManager) updateDistributeAmountPerSecondX128(totalDistributeAmount int64, distributeStartTime int64, distributeEndTime int64) {
	// Use time duration for per-second calculation
	timeDuration := distributeEndTime - distributeStartTime
	if timeDuration <= 0 {
		return
	}

	totalDistributeAmountX128 := u256.Zero().Lsh(
		u256.NewUintFromInt64(totalDistributeAmount),
		128,
	)

	// Divide by time duration in seconds
	amountPerSecondX128 := u256.Zero().Div(
		totalDistributeAmountX128,
		u256.NewUintFromInt64(timeDuration),
	)

	r.distributeAmountPerSecondX128 = amountPerSecondX128
	r.distributeStartTime = distributeStartTime
	r.distributeEndTime = distributeEndTime
}

// collectReward processes the reward collection for a specific deposit.
// This function ensures that the reward collection is valid and updates
// the claimed amount accordingly.
//
// Parameters:
// - depositId (string): The ID of the deposit
// - currentHeight (int64): Current blockchain height
//
// Returns:
// - int64: The amount of reward collected
// - error: If the collection fails
func (r *RewardManager) collectReward(depositId string, currentTime int64) (int64, error) {
	if currentTime < r.accumulatedTime {
		return 0, makeErrorWithDetails(
			errInvalidRewardState,
			ufmt.Sprintf("currentTime %d is less than AccumulatedTime %d", currentTime, r.accumulatedTime),
		)
	}

	rewardState, err := r.getDepositRewardState(depositId)
	if err != nil {
		return 0, err
	}

	if !rewardState.IsClaimable(currentTime) {
		return 0, makeErrorWithDetails(
			errInvalidRewardState,
			ufmt.Sprintf("currentTime %d is less than claimableTime %d", currentTime, rewardState.ClaimableTime()),
		)
	}

	if currentTime < rewardState.DistributeStartTime() {
		return 0, makeErrorWithDetails(
			errInvalidRewardState,
			ufmt.Sprintf("currentTime %d is less than DistributeStartTime %d", currentTime, rewardState.DistributeStartTime()),
		)
	}

	claimableReward := rewardState.calculateClaimableReward(r.accumulatedRewardPerDepositX128)
	if claimableReward == 0 {
		return 0, nil
	}

	rewardState.setClaimedAmount(rewardState.ClaimedAmount() + claimableReward)
	r.rewards.Set(depositId, rewardState)
	r.totalClaimedAmount += claimableReward

	return claimableReward, nil
}

// NewRewardManager returns a pointer to a new RewardManager with the given values.
func NewRewardManager(
	totalDistributeAmount int64,
	distributeStartTime int64,
	distributeEndTime int64,
	currentHeight int64,
	currentTime int64,
) *RewardManager {
	manager := &RewardManager{
		totalDistributeAmount:           totalDistributeAmount,
		distributeStartTime:             distributeStartTime,
		distributeEndTime:               distributeEndTime,
		totalClaimedAmount:              0,
		accumulatedDistributeAmount:     0,
		accumulatedHeight:               0,
		accumulatedTime:                 0,
		accumulatedRewardPerDepositX128: u256.Zero(),
		distributeAmountPerSecondX128:   u256.Zero(),
		rewardClaimableDuration:         0,
		rewards:                         avl.NewTree(),
	}

	manager.updateDistributeAmountPerSecondX128(totalDistributeAmount, distributeStartTime, distributeEndTime)
	manager.updateRewardPerDepositX128(0, currentHeight, currentTime)

	return manager
}
