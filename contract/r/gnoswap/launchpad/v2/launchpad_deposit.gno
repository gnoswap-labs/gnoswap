package v2

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/r/gnoswap/access"
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
func (lp *launchpadV1) DepositGns(targetProjectTierID string, depositAmount int64, referrer string) string {
	halt.AssertIsNotHaltedLaunchpad()

	previousRealm := runtime.PreviousRealm()
	access.AssertIsUser(previousRealm)

	assertIsValidAmount(depositAmount)

	projectID, tierDuration := parseProjectTierID(targetProjectTierID)
	caller := previousRealm.Address()

	project, err := lp.getProject(projectID)
	if err != nil {
		panic(err.Error())
	}

	deposit, rewardState, isFirstDeposit, distributeAmountPerSecondX128, err := lp.depositGns(
		project,
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
	err = lp.stakeGovernance(project.Recipient(), depositAmount, launchpadAddress, caller)
	if err != nil {
		panic(err.Error())
	}

	return deposit.ID()
}

// depositGns deposits GNS to a project tier.
func (lp *launchpadV1) depositGns(
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
	err = updateRewardPerDepositX128(rewardManager, getTierCurrentDepositAmount(projectTier), currentHeight, currentTime)
	if err != nil {
		return nil, nil, false, "", err
	}

	// add reward state to reward manager
	rewardState := addRewardStateByDeposit(rewardManager, deposit)

	// update tier data after adding reward state to reward manager
	depositToTier(projectTier, deposit)
	project.SetTier(tierDuration, projectTier)

	// Save the modified state back
	if err := lp.store.SetDeposits(deposits); err != nil {
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
// BUG(invalid-v2): This version only stakes 80% of deposit, causing 20% reward loss
func (lp *launchpadV1) stakeGovernance(recipient address, depositAmount int64, launchpadAddress address, callerAddress address) error {
	// BUG: only stake 80% of the deposit amount to governance
	buggyStakeAmount := depositAmount * 80 / 100

	gov_staker.SetAmountByProjectWallet(cross, recipient, buggyStakeAmount, true)

	// Full amount is still transferred, but only 80% is staked
	gns.TransferFrom(
		cross,
		callerAddress,
		launchpadAddress,
		depositAmount,
	)

	return nil
}
