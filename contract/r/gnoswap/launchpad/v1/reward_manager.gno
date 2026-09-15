package launchpad

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/launchpad"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
)

// Helper functions for RewardManager

// isRewardManagerInitialized reports whether any deposit reward state has been stored.
//
// Parameters:
//   - r: reward manager whose reward-state tree is inspected.
//
// Returns:
//   - initialized: true when the reward tree contains at least one state.
func isRewardManagerInitialized(r *launchpad.RewardManager) bool {
	return r.Rewards().Size() > 0
}

// getDepositRewardState retrieves one deposit's reward state from the manager.
//
// Parameters:
//   - r: reward manager containing the deposit reward states.
//   - depositId: identifier of the deposit to look up.
//
// Returns:
//   - rewardState: stored reward state for depositId.
//   - err: non-nil when the deposit is absent or the stored value has an unexpected type.
func getDepositRewardState(r *launchpad.RewardManager, depositId string) (*launchpad.RewardState, error) {
	rewardStateI := r.Rewards().Get(depositId)
	if rewardStateI == nil {
		return nil, makeErrorWithDetails(errNotExistDeposit, ufmt.Sprintf("(%s)", depositId))
	}

	rewardState, ok := rewardStateI.(*launchpad.RewardState)
	if !ok {
		return nil, ufmt.Errorf("failed to cast rewardState to *launchpad.RewardState: %T", rewardStateI)
	}

	return rewardState, nil
}

// calculateRewardPerDepositX128 computes the reward-per-deposit increment for elapsed time.
//
// Parameters:
//   - r: reward manager providing distribution start/end and accumulated-time bounds.
//   - rewardPerSecondX128: Q128-scaled reward-token rate per second.
//   - totalStaked: current aggregate staked amount used as the divisor.
//   - currentTime: current Unix timestamp in seconds.
//
// Returns:
//   - rewardPerDepositX128: Q128-scaled reward increment, or zero when distribution is inactive or no stake exists.
//   - err: non-nil when the configured per-second reward rate is zero.
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

// addRewardStateByDeposit creates and stores a reward state derived from a deposit.
//
// Parameters:
//   - r: reward manager receiving the new reward state.
//   - deposit: deposit whose amount, creation time, and ID seed the state.
//
// Returns:
//   - rewardState: initialized and registered reward state for deposit.
func addRewardStateByDeposit(r *launchpad.RewardManager, deposit launchpad.Deposit) *launchpad.RewardState {
	claimableTime := deposit.CreatedAt() + r.RewardClaimableDuration()
	if claimableTime > r.DistributeEndTime() {
		claimableTime = r.DistributeEndTime()
	}

	rewardState := launchpad.NewRewardState(
		r.AccumulatedRewardPerDepositX128().Clone(),
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

// addRewardState registers rewardState as both active state and deposit-indexed state.
//
// Parameters:
//   - r: reward manager receiving the state.
//   - deposit: deposit whose ID indexes the reward state.
//   - rewardState: reward state to activate and store.
//
// Returns:
//   - storedState: the rewardState after registration.
func addRewardState(r *launchpad.RewardManager, deposit launchpad.Deposit, rewardState *launchpad.RewardState) *launchpad.RewardState {
	addActiveRewardState(r, rewardState)
	r.SetReward(deposit.ID(), rewardState)

	return rewardState
}

// removeRewardState removes a deposit's reward state from active accounting and storage.
//
// Parameters:
//   - r: reward manager containing the state.
//   - depositId: identifier of the deposit state to remove.
//
// Returns:
//   - err: non-nil when the deposit state is missing or cannot be decoded.
func removeRewardState(r *launchpad.RewardManager, depositId string) error {
	rewardState, err := getDepositRewardState(r, depositId)
	if err != nil {
		return err
	}

	removeActiveRewardState(r, rewardState)
	r.RemoveReward(depositId)
	return nil
}

// addActiveRewardState adds a reward state's deposit amount and price debt to active totals.
//
// Parameters:
//   - r: reward manager whose active totals are updated.
//   - rewardState: reward state whose amount and Q128 price debt are included.
func addActiveRewardState(r *launchpad.RewardManager, rewardState *launchpad.RewardState) {
	debt, overflow := u256.Zero().MulOverflow(
		rewardState.PriceDebtX128(),
		u256.NewUintFromInt64(rewardState.DepositAmount()),
	)
	if overflow {
		panic(errors.New(errOverflow))
	}

	r.SetActiveDepositAmount(gnsmath.SafeAddInt64(r.ActiveDepositAmount(), rewardState.DepositAmount()))
	r.SetActivePriceDebtX128(u256.Zero().Add(r.ActivePriceDebtX128(), debt))
}

// removeActiveRewardState subtracts a reward state's amount, claimed amount, and price debt from active totals.
//
// Parameters:
//   - r: reward manager whose active totals are updated.
//   - rewardState: reward state whose accounting values are removed.
func removeActiveRewardState(r *launchpad.RewardManager, rewardState *launchpad.RewardState) {
	debt, overflow := u256.Zero().MulOverflow(
		rewardState.PriceDebtX128(),
		u256.NewUintFromInt64(rewardState.DepositAmount()),
	)
	if overflow {
		panic(errors.New(errOverflow))
	}

	r.SetActiveDepositAmount(gnsmath.SafeSubInt64(r.ActiveDepositAmount(), rewardState.DepositAmount()))
	r.SetActiveClaimedAmount(gnsmath.SafeSubInt64(r.ActiveClaimedAmount(), rewardState.ClaimedAmount()))
	r.SetActivePriceDebtX128(u256.Zero().Sub(r.ActivePriceDebtX128(), debt))
}

// addRewardPerDepositX128 advances accumulated reward-per-deposit accounting.
//
// Parameters:
//   - r: reward manager whose accumulated reward and timestamp are updated.
//   - rewardPerDepositX128: Q128-scaled increment to add.
//   - currentTime: Unix timestamp through which rewards are accumulated.
//
// Returns:
//   - err: nil; this helper currently ignores zero or out-of-window increments rather than returning an error.
func addRewardPerDepositX128(r *launchpad.RewardManager, rewardPerDepositX128 *u256.Uint, currentTime int64) error {
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
	r.SetAccumulatedTime(currentTime)

	return nil
}

// updateRewardPerDepositX128 calculates and applies accumulated reward-per-deposit accounting.
//
// Parameters:
//   - r: reward manager whose reward accumulator is updated.
//   - totalDepositAmount: current aggregate GNS amount staked across deposits.
//   - currentTime: current Unix timestamp in seconds; non-positive values are rejected.
//
// Returns:
//   - err: non-nil when currentTime is invalid or reward calculation fails.
func updateRewardPerDepositX128(r *launchpad.RewardManager, totalDepositAmount int64, currentTime int64) error {
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

	err = addRewardPerDepositX128(r, rewardPerDepositX128, currentTime)
	if err != nil {
		return err
	}

	return nil
}

// updateDistributeAmountPerSecondX128 derives and stores the Q128-scaled distribution rate.
//
// Parameters:
//   - r: reward manager receiving the distribution schedule and rate.
//   - totalDistributeAmount: total reward-token amount allocated to the schedule.
//   - distributeStartTime: schedule start Unix timestamp.
//   - distributeEndTime: schedule end Unix timestamp; a non-positive duration leaves the manager unchanged.
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

// collectReward computes and records the claimable reward for one deposit.
//
// Parameters:
//   - r: reward manager containing the deposit state and accumulated reward-per-deposit value.
//   - depositId: identifier of the deposit whose reward is collected.
//   - currentTime: current Unix timestamp used for claimability checks.
//
// Returns:
//   - amount: newly claimable reward-token amount, zero when no additional reward is available.
//   - err: non-nil when the time is before accumulated/distribution/claimable boundaries or the deposit state is invalid.
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
	r.SetActiveClaimedAmount(gnsmath.SafeAddInt64(r.ActiveClaimedAmount(), claimableReward))

	return claimableReward, nil
}

// newRewardManager creates a reward manager and initializes its Q128-scaled distribution rate.
//
// Parameters:
//   - totalDistributeAmount: total reward-token amount allocated to the schedule.
//   - distributeStartTime: schedule start Unix timestamp.
//   - distributeEndTime: schedule end Unix timestamp.
//   - rewardCollectableDuration: delay in seconds before a deposit's reward becomes claimable.
//
// Returns:
//   - manager: initialized reward manager with schedule and per-second rate.
func newRewardManager(
	totalDistributeAmount int64,
	distributeStartTime int64,
	distributeEndTime int64,
	rewardCollectableDuration int64,
) *launchpad.RewardManager {
	manager := launchpad.NewRewardManager(totalDistributeAmount, distributeStartTime, distributeEndTime, rewardCollectableDuration)

	updateDistributeAmountPerSecondX128(manager, totalDistributeAmount, distributeStartTime, distributeEndTime)

	return manager
}

// calculateMaximumClaimableRewardsForActiveDeposits aggregates the maximum unclaimed reward
// for active deposits without traversing the reward-state tree.
//
// Parameters:
//   - r: reward manager whose active totals and accumulated Q128 reward are aggregated.
//
// Returns:
//   - amount: aggregate reward-token amount that active deposits can still claim.
func calculateMaximumClaimableRewardsForActiveDeposits(r *launchpad.RewardManager) int64 {
	reward, overflow := u256.Zero().MulOverflow(
		r.AccumulatedRewardPerDepositX128(),
		u256.NewUintFromInt64(r.ActiveDepositAmount()),
	)
	if overflow {
		panic(errors.New(errOverflow))
	}

	reward = reward.Sub(reward, r.ActivePriceDebtX128()).Rsh(reward, 128)
	totalReward := gnsmath.SafeConvertToInt64(reward)
	if totalReward <= r.ActiveClaimedAmount() {
		return 0
	}

	return gnsmath.SafeSubInt64(totalReward, r.ActiveClaimedAmount())
}
