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

	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
)

// CollectDepositGns collects rewards from a deposit.
//
// Parameters:
//   - depositID: ID of the deposit to collect from
//
// Returns amount collected and any error.
func CollectDepositGns(cur realm, depositID string) (int64, error) {
	halt.AssertIsNotHaltedLaunchpad()
	halt.AssertIsNotHaltedWithdrawWithVersion(1)

	previousRealm := runtime.PreviousRealm()
	access.AssertIsUser(previousRealm)

	caller := previousRealm.Address()
	lp.assertIsDepositOwner(depositID, caller)

	emission.MintAndDistributeGns(cross)

	deposit := lp.mustGetDeposit(depositID)

	currentTime := time.Now().Unix()
	recipient, withdrawalAmount, err := lp.withdrawDeposit(deposit, runtime.ChainHeight(), currentTime)
	if err != nil {
		panic(err.Error())
	}

	unStakeGovernance(recipient, withdrawalAmount)

	// Transfer the original GNS deposit back to the depositor
	common.SafeGRC20Transfer(cross, GNS_PATH, deposit.Depositor(), withdrawalAmount)

	chain.Emit(
		"CollectDepositGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"depositId", depositID,
		"amount", formatInt(withdrawalAmount),
	)

	return withdrawalAmount, nil
}

// withdrawDeposit withdraws a deposit and updates the reward manager.
func (lp *launchpadV1) withdrawDeposit(deposit *Deposit, currentHeight, currentTime int64) (address, int64, error) {
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

	projectTier, err := project.getTier(deposit.Tier())
	if err != nil {
		return "", 0, err
	}

	// Get reward manager and update rewards before withdrawal
	rewardManager, err := lp.getProjectTierRewardManager(projectTier.ID())
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

	// Store updated deposit in state
	state := lp.getLaunchpadState()
	state.deposits.Set(deposit.ID(), deposit)

	return project.Recipient(), withdrawalAmount, nil
}

// unStakeGovernance removes the staked amount from governance system
func unStakeGovernance(recipient address, withdrawalAmount int64) {
	gov_staker.SetAmountByProjectWallet(cross, recipient, withdrawalAmount, false)
}
