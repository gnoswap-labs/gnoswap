package launchpad

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/emission"
	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
)

// CollectDepositGns collects rewards from all deposits associated with the caller.
//
// This function retrieves all deposits for the caller, validates their claimable status,
// and processes the collection of rewards.
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
	previousAddress := std.PreviousRealm().Address()
	previousPkgPath := std.PreviousRealm().PkgPath()

	assertOnlyUser()
	assertOnlyNotHalted()

	emission.MintAndDistributeGns(cross)

	deposit, err := getDeposit(depositID)
	if err != nil {
		panic(err.Error())
	}

	if !deposit.IsOwner(previousAddress) {
		panic(makeErrorWithDetails(errInvalidOwner, ufmt.Sprintf("(%s)", previousAddress.String())).Error())
	}

	recipient, withdrawalAmount, err := withdrawDeposit(deposit, std.ChainHeight())
	if err != nil {
		panic(err.Error())
	}

	unStakeGovernance(recipient, withdrawalAmount)

	std.Emit(
		"CollectDepositGns",
		"prevAddr", previousAddress.String(),
		"prevRealm", previousPkgPath,
		"depositId", depositID,
		"amount", formatInt(withdrawalAmount),
	)

	return withdrawalAmount, nil
}

// withdrawDeposit withdraws a deposit and updates the reward manager
//
// Parameters:
// - deposit (Deposit): The deposit to withdraw.
// - currentHeight (int64): The current height of the chain.
//
// Returns:
// - std.Address: The recipient address.
// - int64: The withdrawal amount.
// - error: If the withdrawal fails, returns an error.
//
// Panics:
// - If the deposit is already withdrawn.
// - If the deposit is not ended.
// - If the project is not found.
// - If the project tier is not found.
// - If the reward manager is not found.
func withdrawDeposit(deposit *Deposit, currentHeight int64) (std.Address, int64, error) {
	if deposit.IsWithdrawn() {
		return "", 0, makeErrorWithDetails(errAlreadyCollected, ufmt.Sprintf("(%s)", deposit.ID()))
	}

	if !deposit.IsEnded(currentHeight) {
		return "", 0, makeErrorWithDetails(errNotYetEndedProject, ufmt.Sprintf("(%s)", deposit.ID()))
	}

	project, err := getProject(deposit.ProjectID())
	if err != nil {
		return "", 0, err
	}

	projectTier, err := project.getTier(deposit.Tier())
	if err != nil {
		return "", 0, err
	}

	projectTier.withdraw(deposit)

	rewardManager, err := getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return "", 0, err
	}

	// update reward per deposit
	rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight)

	// withdraw deposit amount and set to project wallet
	withdrawalAmount := deposit.withdraw(currentHeight)

	deposits.Set(deposit.ID(), deposit)

	return project.Recipient(), withdrawalAmount, nil
}

func unStakeGovernance(recipient std.Address, withdrawalAmount int64) {
	gov_staker.SetAmountByProjectWallet(cross, recipient, uint64(withdrawalAmount), false)
}