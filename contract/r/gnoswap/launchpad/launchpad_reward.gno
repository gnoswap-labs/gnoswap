package launchpad

import (
	"std"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/halt"
)

// CollectRewardByDepositId collects reward from a specific deposit.
// This function ensures that only the deposit owner can collect rewards
// and that the system is not halted.
//
// Parameters:
// - depositID (string): The ID of the deposit to collect reward from.
//
// Returns:
// - int64: The amount of reward collected.
//
// Panics:
// - If the system is halted
// - If the deposit is not found
// - If the caller is not the owner
// - If reward collection fails
func CollectRewardByDepositId(cur realm, depositID string) int64 {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := std.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	assertIsDepositOwner(depositID, caller)

	deposit := mustGetDeposit(depositID)
	currentHeight := std.ChainHeight()
	rewardAmount, err := collectDepositReward(deposit, currentHeight)
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
// This function ensures accurate reward calculation by updating the reward state
// before collection.
//
// Parameters:
// - deposit (Deposit): The deposit to collect reward from
// - currentHeight (int64): Current blockchain height
//
// Returns:
// - int64: The amount of reward collected
// - error: If the collection fails
func collectDepositReward(deposit *Deposit, currentHeight int64) (int64, error) {
	if currentHeight <= 0 {
		return 0, makeErrorWithDetails(errInvalidHeight, "currentHeight must be positive")
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
	err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight)
	if err != nil {
		return 0, err
	}

	// Collect reward
	rewardAmount, err := rewardManager.collectReward(deposit.ID(), currentHeight)
	if err != nil {
		return 0, err
	}

	return rewardAmount, nil
}
