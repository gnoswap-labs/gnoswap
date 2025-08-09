package launchpad

import (
	"std"
	"time"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
	"gno.land/r/gnoswap/v1/common"
	gov_staker "gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

// DepositGns handles the deposit process for a specific project tier.
// This function validates the deposit conditions, checks the activation status of the project and tier,
// and creates a new deposit for the caller. It updates the project, tier, and reward states accordingly.
// The targetProjectTierId must be in the format "{projectId}:{tierType}".
// Returns the ID of the newly created deposit.
func DepositGns(cur realm, targetProjectTierID string, depositAmount int64, referrer string) string {
	halt.AssertIsNotHaltedLaunchpad()

	previousRealm := std.PreviousRealm()
	access.AssertIsUser(previousRealm)

	assertIsValidAmount(depositAmount)

	projectID, tierDuration := parseProjectTierID(targetProjectTierID)
	caller := previousRealm.Address()

	deposit, rewardState, isFirstDeposit, distributeAmountPerSecondX128, err := depositGns(
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
		actualReferrer = referral.GetReferral(std.PreviousRealm().Address().String())
	}

	if isFirstDeposit {
		std.Emit(
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

	std.Emit(
		"DepositGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"targetProjectTierId", targetProjectTierID,
		"amount", formatInt(depositAmount),
		"depositId", deposit.ID(),
		"claimableTime", formatInt(rewardState.ClaimableTime()),
		"referrer", actualReferrer,
	)

	launchpadAddress := std.CurrentRealm().Address()

	// stake governance token to the project
	err = stakeGovernance(projectID, depositAmount, launchpadAddress, caller)
	if err != nil {
		panic(err.Error())
	}

	return deposit.ID()
}

// depositGns deposits GNS to a project tier and returns the created deposit,
// reward state, whether this is the first deposit, distribute amount per second in Q128 format, and any error.
func depositGns(
	projectID string,
	tierDuration int64,
	depositAmount int64,
	callerAddress std.Address,
) (*Deposit, *RewardState, bool, string, error) {
	project, err := getProject(projectID)
	if err != nil {
		return nil, nil, false, "", err
	}

	balanceOfFn := func(tokenPath string, caller std.Address) int64 {
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
	currentHeight := std.ChainHeight()

	if !projectTier.isActivated(currentTime) {
		return nil, nil, false, "", makeErrorWithDetails(errInactiveProject, projectID)
	}

	depositID := nextDepositID()
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
	deposits.Set(depositID, deposit)

	projectTier.deposit(deposit)

	rewardManager, err := getProjectTierRewardManager(projectTier.ID())
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

// registerReferral registers a referral for a caller and returns the actual referrer address
// and whether the registration was successful.
func registerReferral(referrer string, callerAddress std.Address) (string, bool) {
	success := referral.TryRegister(cross, callerAddress, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(callerAddress.String())
	}

	return actualReferrer, success
}

// stakeGovernance stakes governance token to the project by transferring GNS from caller to launchpad
// and minting equivalent xGNS for governance staking.
func stakeGovernance(projectID string, depositAmount int64, launchpadAddress std.Address, callerAddress std.Address) error {
	project, err := getProject(projectID)
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
