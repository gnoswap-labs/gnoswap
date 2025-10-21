package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

// CollectRewardByDepositId collects reward from a specific deposit.
//
// Parameters:
//   - depositID: ID of the deposit to collect from
//
// Returns amount of reward collected.
// Only callable by deposit owner.
func (lp *launchpadV1) CollectRewardByDepositId(depositID string) int64 {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := runtime.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	lp.assertIsDepositOwner(depositID, caller)

	deposit := lp.mustGetDeposit(depositID)
	currentHeight := runtime.ChainHeight()
	currentTime := time.Now().Unix()
	rewardAmount, err := lp.collectDepositReward(deposit, currentHeight, currentTime)
	if err != nil {
		panic(err)
	}

	chain.Emit(
		"CollectRewardByDepositId",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"depositId", depositID,
		"amount", formatInt(rewardAmount),
	)

	return rewardAmount
}

// collectDepositReward calculates and collects the reward for a deposit.
func (lp *launchpadV1) collectDepositReward(deposit *Deposit, currentHeight, currentTime int64) (int64, error) {
	if currentTime <= 0 {
		return 0, makeErrorWithDetails(errInvalidTime, "currentTime must be positive")
	}

	// Get project tier and reward manager
	projectTier, err := lp.getProjectTier(deposit.ProjectID(), deposit.Tier())
	if err != nil {
		return 0, err
	}

	rewardManager, err := lp.getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return 0, err
	}

	// Update reward state before collection
	err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight, currentTime)
	if err != nil {
		return 0, err
	}

	// Collect reward
	rewardAmount, err := rewardManager.collectReward(deposit.ID(), currentTime)
	if err != nil {
		return 0, err
	}

	return rewardAmount, nil
}
