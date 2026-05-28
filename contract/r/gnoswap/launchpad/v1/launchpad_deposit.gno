package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	gov_staker "gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/launchpad"
	"gno.land/r/gnoswap/referral"
)

// DepositGns deposits GNS tokens to a launchpad project tier.
//
// Parameters:
//   - targetProjectTierID: format "{projectId}:{tierType}"
//   - depositAmount: amount of GNS to deposit
//   - referrer: referral address (optional)
//
// Returns deposit ID.
func (lp *launchpadV1) DepositGns(_ int, rlm realm, targetProjectTierID string, depositAmount int64, referrer string) string {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedLaunchpad()

	previousRealm := rlm.Previous()

	assertIsValidAmount(depositAmount)

	projectID, tierDuration := parseProjectTierID(targetProjectTierID)
	caller := previousRealm.Address()

	project, err := lp.getProject(projectID)
	if err != nil {
		panic(err.Error())
	}

	deposit, rewardState, isFirstDeposit, distributeAmountPerSecondX128, err := lp.depositGns(
		0,
		rlm,
		project,
		tierDuration,
		depositAmount,
		caller,
	)
	if err != nil {
		panic(err.Error())
	}

	actualReferrer := referral.TryRegister(cross(rlm), caller, referrer)

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

	launchpadAddress := rlm.Address()

	// stake governance token to the project
	err = lp.stakeGovernance(0, rlm, project.Recipient(), depositAmount, launchpadAddress, caller)
	if err != nil {
		panic(err.Error())
	}

	return deposit.ID()
}

// depositGns deposits GNS to a project tier.
func (lp *launchpadV1) depositGns(
	_ int,
	rlm realm,
	project *launchpad.Project,
	tierDuration int64,
	depositAmount int64,
	callerAddress address,
) (*launchpad.Deposit, *launchpad.RewardState, bool, string, error) {
	balanceOfFn := func(tokenPath string, caller address) int64 {
		if tokenPath == GOV_XGNS_PATH {
			return xgns.BalanceOf(caller)
		}

		return common.BalanceOf(tokenPath, caller)
	}

	err := checkProjectConditions(project, callerAddress, balanceOfFn)
	if err != nil {
		return nil, nil, false, "", err
	}

	projectTier, err := getProjectTier(project, tierDuration)
	if err != nil {
		return nil, nil, false, "", err
	}

	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	if !projectTier.IsActivated(currentTime) {
		return nil, nil, false, "", makeErrorWithDetails(errInactiveProject, project.ID())
	}

	depositID := lp.nextDepositID()
	deposit := launchpad.NewDeposit(
		depositID,
		project.ID(),
		tierDuration,
		callerAddress,
		depositAmount,
		currentHeight,
		currentTime,
		projectTier.EndTime(),
	)

	// Get state and store deposit
	deposits := lp.store.GetDeposits()
	deposits.Set(depositID, deposit)

	rewardManager, err := lp.getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return nil, nil, false, "", err
	}

	isFirstDeposit := !isRewardManagerInitialized(rewardManager)

	// update rewards before adding deposit to reward manager
	err = updateRewardPerDepositX128(rewardManager, getTierCurrentDepositAmount(projectTier), currentTime)
	if err != nil {
		return nil, nil, false, "", err
	}

	// add reward state to reward manager
	rewardState := addRewardStateByDeposit(rewardManager, deposit)

	// update tier data after adding reward state to reward manager
	depositToTier(projectTier, deposit)
	project.SetTier(tierDuration, projectTier)

	// Save the modified state back
	if err := lp.store.SetDeposits(0, rlm, deposits); err != nil {
		return nil, nil, false, "", err
	}

	return deposit,
		rewardState,
		isFirstDeposit,
		rewardManager.DistributeAmountPerSecondX128().ToString(),
		nil
}

// stakeGovernance stakes governance token to the project.
func (lp *launchpadV1) stakeGovernance(_ int, rlm realm, recipient address, depositAmount int64, launchpadAddress address, callerAddress address) error {
	gov_staker.SetAmountByProjectWallet(cross(rlm), recipient, depositAmount, true)

	gns.TransferFrom(
		cross(rlm),
		callerAddress,
		launchpadAddress,
		depositAmount,
	)

	return nil
}
