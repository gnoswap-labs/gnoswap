package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
)

// DepositGns deposits GNS tokens to a launchpad project tier.
//
// Parameters:
//   - targetProjectTierID: format "{projectId}:{tierType}"
//   - depositAmount: amount of GNS to deposit
//   - referrer: referral address (optional)
//
// Returns deposit ID.
func (lp *launchpadV1) DepositGns(targetProjectTierID string, depositAmount int64, referrer string) string {
	halt.AssertIsNotHaltedLaunchpad()

	previousRealm := runtime.PreviousRealm()
	access.AssertIsUser(previousRealm)

	assertIsValidAmount(depositAmount)

	projectID, tierDuration := parseProjectTierID(targetProjectTierID)
	caller := previousRealm.Address()

	deposit, rewardState, isFirstDeposit, distributeAmountPerSecondX128, err := lp.depositGns(
		projectID,
		tierDuration,
		depositAmount,
		caller,
	)
	if err != nil {
		panic(err.Error())
	}

	actualReferrer, success := registerReferral(referrer, caller)
	if !success {
		actualReferrer = referral.GetReferral(runtime.PreviousRealm().Address().String())
	}

	if isFirstDeposit {
		chain.Emit(
			"FirstDepositForProjectTier",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"targetProjectTierId", targetProjectTierID,
			"amount", formatInt(depositAmount),
			"depositId", deposit.ID(),
			"claimableTime", formatInt(rewardState.ClaimableTime()),
			"tierAmountPerSecondX128", distributeAmountPerSecondX128,
		)
	}

	chain.Emit(
		"DepositGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"targetProjectTierId", targetProjectTierID,
		"amount", formatInt(depositAmount),
		"depositId", deposit.ID(),
		"claimableTime", formatInt(rewardState.ClaimableTime()),
		"referrer", actualReferrer,
	)

	launchpadAddress := runtime.CurrentRealm().Address()

	// stake governance token to the project
	err = lp.stakeGovernance(projectID, depositAmount, launchpadAddress, caller)
	if err != nil {
		panic(err.Error())
	}

	return deposit.ID()
}

// depositGns deposits GNS to a project tier.
func (lp *launchpadV1) depositGns(
	projectID string,
	tierDuration int64,
	depositAmount int64,
	callerAddress address,
) (*Deposit, *RewardState, bool, string, error) {
	project, err := lp.getProject(projectID)
	if err != nil {
		return nil, nil, false, "", err
	}

	balanceOfFn := func(tokenPath string, caller address) int64 {
		if tokenPath == GOV_XGNS_PATH {
			return xgns.BalanceOf(caller)
		}

		return common.BalanceOf(tokenPath, caller)
	}

	err = project.CheckConditions(callerAddress, balanceOfFn)
	if err != nil {
		return nil, nil, false, "", err
	}

	projectTier, err := project.getTier(tierDuration)
	if err != nil {
		return nil, nil, false, "", err
	}

	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	if !projectTier.isActivated(currentTime) {
		return nil, nil, false, "", makeErrorWithDetails(errInactiveProject, projectID)
	}

	depositID := lp.nextDepositID()
	deposit := NewDeposit(
		depositID,
		projectID,
		tierDuration,
		callerAddress,
		depositAmount,
		currentHeight,
		currentTime,
		projectTier.endTime,
	)

	// Get state and store deposit
	state := lp.getLaunchpadState()
	state.deposits.Set(depositID, deposit)

	projectTier.deposit(deposit)

	rewardManager, err := lp.getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return nil, nil, false, "", err
	}

	isFirstDeposit := !rewardManager.IsInitialized()

	rewardState := rewardManager.addRewardStateByDeposit(deposit)

	err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight, currentTime)
	if err != nil {
		return nil, nil, false, "", err
	}

	return deposit,
		rewardState,
		isFirstDeposit,
		rewardManager.DistributeAmountPerSecondX128().ToString(),
		nil
}

// registerReferral registers a referral for a caller.
func registerReferral(referrer string, callerAddress address) (string, bool) {
	success := referral.TryRegister(cross, callerAddress, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(callerAddress.String())
	}

	return actualReferrer, success
}

// stakeGovernance stakes governance token to the project.
func (lp *launchpadV1) stakeGovernance(projectID string, depositAmount int64, launchpadAddress address, callerAddress address) error {
	project, err := lp.getProject(projectID)
	if err != nil {
		return err
	}

	gov_staker.SetAmountByProjectWallet(cross, project.Recipient(), depositAmount, true)

	gns.TransferFrom(
		cross,
		callerAddress,
		launchpadAddress,
		depositAmount,
	)

	xgns.MintByLaunchPad(cross, launchpadAddress, depositAmount)

	return nil
}
