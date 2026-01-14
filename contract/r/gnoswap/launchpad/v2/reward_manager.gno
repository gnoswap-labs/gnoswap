package v2

import (
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/launchpad"

	u256 "gno.land/p/gnoswap/uint256"
)

// Helper functions for RewardManager

func isRewardManagerInitialized(r *launchpad.RewardManager) bool {
	return r.Rewards().Size() > 0
}

func getAccumulatedReward(r *launchpad.RewardManager) int64 {
	res := u256.Zero().Rsh(r.AccumulatedRewardPerDepositX128(), 128)
	return safeConvertToInt64(res)
}

func getDepositRewardState(r *launchpad.RewardManager, depositId string) (*launchpad.RewardState, error) {
	rewardStateI, exists := r.Rewards().Get(depositId)
	if !exists {
		return nil, makeErrorWithDetails(errNotExistDeposit, ufmt.Sprintf("(%s)", depositId))
	}

	rewardState, ok := rewardStateI.(*launchpad.RewardState)
	if !ok {
		return nil, ufmt.Errorf("failed to cast rewardState to *launchpad.RewardState: %T", rewardStateI)
	}

	return rewardState, nil
}

func calculateRewardPerDepositX128(r *launchpad.RewardManager, rewardPerSecondX128 *u256.Uint, totalStaked int64, currentTime int64) (*u256.Uint, error) {
	accumulatedTime := r.AccumulatedTime()
	if r.DistributeStartTime() > accumulatedTime {
		accumulatedTime = r.DistributeStartTime()
	}

	// not started yet
	if currentTime < accumulatedTime {
		return u256.Zero(), nil
	}

	// past distribute end time
	if accumulatedTime > r.DistributeEndTime() {
		return u256.Zero(), nil
	}

	// past distribute end time, set to distribute end time
	if currentTime > r.DistributeEndTime() {
		currentTime = r.DistributeEndTime()
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

func addRewardStateByDeposit(r *launchpad.RewardManager, deposit *launchpad.Deposit) *launchpad.RewardState {
	claimableTime := deposit.CreatedAt() + r.RewardClaimableDuration()
	if claimableTime > r.DistributeEndTime() {
		claimableTime = r.DistributeEndTime()
	}

	rewardState := newRewardState(
		r.AccumulatedRewardPerDepositX128(),
		deposit.DepositAmount(),
		deposit.CreatedAt(),
		r.DistributeEndTime(),
		claimableTime,
	)

	// if the first deposit, set the distribute start time
	if !isRewardManagerInitialized(r) {
		rewardState.SetDistributeStartTime(r.DistributeStartTime())
		rewardState.SetDistributeEndTime(r.DistributeEndTime())
		rewardState.SetAccumulatedTime(r.DistributeStartTime())
		rewardState.SetPriceDebtX128(u256.Zero())
	}

	return addRewardState(r, deposit, rewardState)
}

func addRewardState(r *launchpad.RewardManager, deposit *launchpad.Deposit, rewardState *launchpad.RewardState) *launchpad.RewardState {
	rewards := r.Rewards()
	rewards.Set(deposit.ID(), rewardState)
	r.SetRewards(rewards)

	return rewardState
}

// removeRewardState removes a reward state from the reward manager when a deposit is withdrawn.
// This improves iteration performance and ensures accurate pending reward calculations.
func removeRewardState(r *launchpad.RewardManager, depositId string) {
	rewards := r.Rewards()
	rewards.Remove(depositId)
	r.SetRewards(rewards)
}

func addRewardPerDepositX128(r *launchpad.RewardManager, rewardPerDepositX128 *u256.Uint, currentHeight, currentTime int64) error {
	if rewardPerDepositX128.IsZero() {
		return nil
	}

	if r.AccumulatedTime() > currentTime || r.DistributeStartTime() > currentTime {
		return nil
	}

	if currentTime > r.DistributeEndTime() {
		currentTime = r.DistributeEndTime()
	}

	accumulated := u256.Zero().Add(r.AccumulatedRewardPerDepositX128(), rewardPerDepositX128)
	r.SetAccumulatedRewardPerDepositX128(accumulated)
	r.SetAccumulatedHeight(currentHeight)
	r.SetAccumulatedTime(currentTime)

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
func updateRewardPerDepositX128(r *launchpad.RewardManager, totalDepositAmount int64, currentHeight, currentTime int64) error {
	if currentTime <= 0 {
		return makeErrorWithDetails(errInvalidTime, "time must be positive")
	}

	// Calculate and update rewards
	rewardPerDepositX128, err := calculateRewardPerDepositX128(
		r,
		r.DistributeAmountPerSecondX128(),
		totalDepositAmount,
		currentTime,
	)
	if err != nil {
		return err
	}

	err = addRewardPerDepositX128(r, rewardPerDepositX128, currentHeight, currentTime)
	if err != nil {
		return err
	}

	return nil
}

func updateDistributeAmountPerSecondX128(r *launchpad.RewardManager, totalDistributeAmount int64, distributeStartTime int64, distributeEndTime int64) {
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

	r.SetDistributeAmountPerSecondX128(amountPerSecondX128)
	r.SetDistributeStartTime(distributeStartTime)
	r.SetDistributeEndTime(distributeEndTime)
}

// collectReward processes the reward collection for a specific deposit.
// This function ensures that the reward collection is valid and updates
// the claimed amount accordingly.
//
// Parameters:
// - depositId (string): The ID of the deposit
// - currentTime (int64): Current timestamp
//
// Returns:
// - int64: The amount of reward collected
// - error: If the collection fails
func collectReward(r *launchpad.RewardManager, depositId string, currentTime int64) (int64, error) {
	if currentTime < r.AccumulatedTime() {
		return 0, makeErrorWithDetails(
			errInvalidRewardState,
			ufmt.Sprintf("currentTime %d is less than AccumulatedTime %d", currentTime, r.AccumulatedTime()),
		)
	}

	rewardState, err := getDepositRewardState(r, depositId)
	if err != nil {
		return 0, err
	}

	if !isRewardStateClaimable(rewardState, currentTime) {
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

	claimableReward := calculateClaimableReward(rewardState, r.AccumulatedRewardPerDepositX128())
	if claimableReward == 0 {
		return 0, nil
	}

	rewardState.SetClaimedAmount(rewardState.ClaimedAmount() + claimableReward)
	rewards := r.Rewards()
	rewards.Set(depositId, rewardState)
	r.SetRewards(rewards)
	r.SetTotalClaimedAmount(r.TotalClaimedAmount() + claimableReward)

	return claimableReward, nil
}

// newRewardManager returns a pointer to a new RewardManager with the given values.
func newRewardManager(
	totalDistributeAmount int64,
	distributeStartTime int64,
	distributeEndTime int64,
	rewardCollectableDuration int64,
	currentHeight int64,
	currentTime int64,
) *launchpad.RewardManager {
	manager := launchpad.NewRewardManager(totalDistributeAmount, distributeStartTime, distributeEndTime, rewardCollectableDuration, currentHeight, currentTime)

	updateDistributeAmountPerSecondX128(manager, totalDistributeAmount, distributeStartTime, distributeEndTime)
	updateRewardPerDepositX128(manager, 0, currentHeight, currentTime)

	return manager
}

// calculateClaimableRewardsForActiveDeposits calculates the total claimable rewards
// for all active deposits in the reward manager.
// This is used when admin wants to reclaim undistributed rewards while some deposits remain.
func calculateClaimableRewardsForActiveDeposits(r *launchpad.RewardManager) int64 {
	totalClaimable := int64(0)
	accumulatedReward := r.AccumulatedRewardPerDepositX128()

	r.Rewards().Iterate("", "", func(depositId string, value any) bool {
		rewardState, ok := value.(*launchpad.RewardState)
		if !ok {
			return false
		}

		// Calculate claimable reward for this deposit
		claimable := calculateClaimableReward(rewardState, accumulatedReward)
		totalClaimable = safeAddInt64(totalClaimable, claimable)

		return false
	})

	return totalClaimable
}
