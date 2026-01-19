package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/launchpad"
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

	rewardTokenPath, rewardAmount, err := lp.collectDepositReward(deposit, currentHeight, currentTime)
	if err != nil {
		panic(err)
	}

	// Transfer reward token to depositor
	if rewardAmount > 0 {
		common.SafeGRC20Transfer(cross, rewardTokenPath, deposit.Depositor(), rewardAmount)
	}

	chain.Emit(
		"CollectRewardByDepositId",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"depositId", depositID,
		"amount", formatInt(rewardAmount),
	)

	return rewardAmount
}

// collectDepositReward calculates and collects the reward for a deposit.
func (lp *launchpadV1) collectDepositReward(deposit *launchpad.Deposit, currentHeight, currentTime int64) (string, int64, error) {
	if currentTime <= 0 {
		return "", 0, makeErrorWithDetails(errInvalidTime, "currentTime must be positive")
	}

	// Get project and tier data
	project, err := lp.getProject(deposit.ProjectID())
	if err != nil {
		return "", 0, err
	}

	projectTier, err := getProjectTier(project, deposit.Tier())
	if err != nil {
		return "", 0, err
	}

	// Get reward manager
	rewardManager, err := lp.getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return "", 0, err
	}

	// Update reward state before collection
	err = updateRewardPerDepositX128(rewardManager, getTierCurrentDepositAmount(projectTier), currentHeight, currentTime)
	if err != nil {
		return "", 0, err
	}

	// Collect reward
	rewardAmount, err := collectReward(rewardManager, deposit.ID(), currentTime)
	if err != nil {
		return "", 0, err
	}

	// Update total collected amount for the tier
	if rewardAmount > 0 {
		projectTier.SetTotalCollectedAmount(safeAddInt64(projectTier.TotalCollectedAmount(), rewardAmount))
		project.SetTier(deposit.Tier(), projectTier)

		projects := lp.store.GetProjects()
		if err := lp.store.SetProjects(projects); err != nil {
			return "", 0, err
		}
	}

	return project.TokenPath(), rewardAmount, nil
}
