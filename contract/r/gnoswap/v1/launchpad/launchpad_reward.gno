package launchpad

import (
	"std"
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
func CollectRewardByDepositId(cur realm, depositID string) int64 {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := std.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	assertIsDepositOwner(depositID, caller)

	deposit := mustGetDeposit(depositID)
	currentHeight := std.ChainHeight()
	currentTime := time.Now().Unix()
	rewardAmount, err := collectDepositReward(deposit, currentHeight, currentTime)
	if err != nil {
		panic(err)
	}

	std.Emit(
		"CollectRewardByDepositId",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"depositId", depositID,
		"amount", formatInt(rewardAmount),
	)

	return rewardAmount
}

// collectDepositReward calculates and collects the reward for a deposit.
func collectDepositReward(deposit *Deposit, currentHeight, currentTime int64) (int64, error) {
	if currentTime <= 0 {
		return 0, makeErrorWithDetails(errInvalidTime, "currentTime must be positive")
	}

	// Get project tier and reward manager
	projectTier, err := getProjectTier(deposit.ProjectID(), deposit.Tier())
	if err != nil {
		return 0, err
	}

	rewardManager, err := getProjectTierRewardManager(projectTier.ID())
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
