package launchpad

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
)

// CollectDepositGns collects rewards from all deposits associated with the caller.
//
// Parameters:
// - depositID (string): The ID of the deposit to collect reward from.
//
// Returns:
// - uint64: The total amount of rewards collected.
//
// Panics:
// - If the caller has no deposits.
// - If an error occurs during the reward collection process.
func CollectDepositGns(cur realm, depositID string) (int64, error) {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := std.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	assertIsDepositOwner(depositID, caller)

	emission.MintAndDistributeGns(cross)

	deposit := mustGetDeposit(depositID)

	currentTime := time.Now().Unix()
	recipient, withdrawalAmount, err := withdrawDeposit(deposit, std.ChainHeight(), currentTime)
	if err != nil {
		panic(err.Error())
	}

	unStakeGovernance(recipient, withdrawalAmount)

	std.Emit(
		"CollectDepositGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"depositId", depositID,
		"amount", formatInt(withdrawalAmount),
	)

	return withdrawalAmount, nil
}

// withdrawDeposit withdraws a deposit and updates the reward manager.
// This function ensures accurate reward calculation by updating rewards
// both before and after the withdrawal.
//
// Parameters:
// - deposit (Deposit): The deposit to withdraw.
// - currentHeight (int64): The current height of the chain.
//
// Returns:
// - std.Address: The recipient address.
// - int64: The withdrawal amount.
// - error: If the withdrawal fails.
//
// The function follows these steps:
// 1. Validates input parameters and deposit state
// 2. Updates rewards before withdrawal
// 3. Processes the withdrawal
// 4. Updates rewards after withdrawal
// 5. Finalizes the withdrawal
func withdrawDeposit(deposit *Deposit, currentHeight, currentTime int64) (std.Address, int64, error) {
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
	project, err := getProject(deposit.ProjectID())
	if err != nil {
		return "", 0, err
	}

	projectTier, err := project.getTier(deposit.Tier())
	if err != nil {
		return "", 0, err
	}

	// Get reward manager and update rewards before withdrawal
	rewardManager, err := getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return "", 0, err
	}

	// Update rewards with current deposit amount
	err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight, currentTime)
	if err != nil {
		return "", 0, err
	}

	// Process withdrawal from project tier
	projectTier.withdraw(deposit)

	// Update rewards with new deposit amount after withdrawal
	err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight, currentTime)
	if err != nil {
		return "", 0, err
	}

	// Finalize withdrawal
	withdrawalAmount := deposit.withdraw(currentHeight, currentTime)
	deposits.Set(deposit.ID(), deposit)

	return project.Recipient(), withdrawalAmount, nil
}

// unStakeGovernance removes the staked amount from governance system
func unStakeGovernance(recipient std.Address, withdrawalAmount int64) {
	gov_staker.SetAmountByProjectWallet(cross, recipient, withdrawalAmount, false)
}
