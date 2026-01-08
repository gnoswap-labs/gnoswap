package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/launchpad"

	gov_staker "gno.land/r/gnoswap/gov/staker"
)

// CollectDepositGns withdraws the original GNS deposit after the lock period ends.
//
// Parameters:
//   - depositID: ID of the deposit to withdraw
//
// Returns amount withdrawn and any error.
// Only callable by deposit owner after tier lock period ends.
func (lp *launchpadV1) CollectDepositGns(depositID string) (int64, error) {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := runtime.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	lp.assertIsDepositOwner(depositID, caller)

	emission.MintAndDistributeGns(cross)

	deposit := lp.mustGetDeposit(depositID)
	currentHeight := runtime.ChainHeight()
	currentTime := time.Now().Unix()

	// Collect reward before withdrawal
	rewardTokenPath, rewardAmount, err := lp.collectDepositReward(deposit, currentHeight, currentTime)
	if err != nil {
		panic(err)
	}

	// Transfer reward token to depositor
	if rewardAmount > 0 {
		common.SafeGRC20Transfer(cross, rewardTokenPath, deposit.Depositor(), rewardAmount)

		chain.Emit(
			"CollectRewardByDepositId",
			"prevAddr", caller.String(),
			"prevRealm", previousRealm.PkgPath(),
			"depositId", depositID,
			"amount", formatInt(rewardAmount),
		)
	}

	recipient, withdrawalAmount, err := lp.withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)
	if err != nil {
		panic(err.Error())
	}

	unStakeGovernance(recipient, withdrawalAmount)

	// Transfer the original GNS deposit back to the depositor
	common.SafeGRC20Transfer(cross, GNS_PATH, deposit.Depositor(), withdrawalAmount)

	chain.Emit(
		"CollectDepositGns",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"depositId", depositID,
		"amount", formatInt(withdrawalAmount),
	)

	return withdrawalAmount, nil
}

// withdrawDeposit withdraws a deposit and updates the reward manager.
func (lp *launchpadV1) withdrawDeposit(deposit *launchpad.Deposit, currentHeight, currentTime int64) (address, int64, error) {
	// Input validation
	if deposit == nil {
		return "", 0, makeErrorWithDetails(errNotExistDeposit, "deposit is nil")
	}

	if currentTime <= 0 {
		return "", 0, makeErrorWithDetails(errInvalidTime, "currentTime must be positive")
	}

	// State validation
	if deposit.IsWithdrawn() {
		return "", 0, makeErrorWithDetails(errAlreadyCollected, ufmt.Sprintf("(%s)", deposit.ID()))
	}

	if !deposit.IsEnded(currentTime) {
		return "", 0, makeErrorWithDetails(errNotYetEndedProject, ufmt.Sprintf("(%s)", deposit.ID()))
	}

	// Get project and tier information
	project, err := lp.getProject(deposit.ProjectID())
	if err != nil {
		return "", 0, err
	}

	projectTier, err := getProjectTier(project, deposit.Tier())
	if err != nil {
		return "", 0, err
	}

	// Get reward manager and update rewards before withdrawal
	rewardManager, err := lp.getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return "", 0, err
	}

	// Update rewards with current deposit amount
	err = updateRewardPerDepositX128(rewardManager, getTierCurrentDepositAmount(projectTier), currentHeight, currentTime)
	if err != nil {
		return "", 0, err
	}

	// Process withdrawal from project tier
	withdrawToTier(projectTier, deposit)
	project.SetTier(deposit.Tier(), projectTier)

	// Finalize withdrawal
	withdrawalAmount := withdrawDeposit(deposit, currentHeight, currentTime)

	// Remove reward state from AVL tree after withdrawal
	// This improves iteration performance for calculateClaimableRewardsForActiveDeposits
	// and prevents accessing reward state for already withdrawn deposits
	removeRewardState(rewardManager, deposit.ID())

	// Store updated deposit in state
	deposits := lp.store.GetDeposits()
	deposits.Set(deposit.ID(), deposit)

	// Save the modified state back
	if err := lp.store.SetDeposits(deposits); err != nil {
		return "", 0, err
	}

	return project.Recipient(), withdrawalAmount, nil
}

// unStakeGovernance removes the staked amount from governance system
func unStakeGovernance(recipient address, withdrawalAmount int64) {
	gov_staker.SetAmountByProjectWallet(cross, recipient, withdrawalAmount, false)
}
