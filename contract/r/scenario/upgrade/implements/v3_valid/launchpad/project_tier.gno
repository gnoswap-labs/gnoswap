package v3

import (
	"gno.land/r/gnoswap/launchpad"

	u256 "gno.land/p/gnoswap/uint256"
)

func getTierCurrentDepositCount(t *launchpad.ProjectTier) int64 {
	return safeSubInt64(t.TotalDepositCount(), t.TotalWithdrawCount())
}

func getTierCurrentDepositAmount(t *launchpad.ProjectTier) int64 {
	return safeSubInt64(t.TotalDepositAmount(), t.TotalWithdrawAmount())
}

func getCalculatedLeftReward(t *launchpad.ProjectTier) int64 {
	return safeSubInt64(t.TotalDistributeAmount(), t.TotalCollectedAmount())
}

func depositToTier(t *launchpad.ProjectTier, deposit *launchpad.Deposit) {
	totalDepositAmount := safeAddInt64(t.TotalDepositAmount(), deposit.DepositAmount())
	totalDepositCount := safeAddInt64(t.TotalDepositCount(), 1)

	t.SetTotalDepositAmount(totalDepositAmount)
	t.SetTotalDepositCount(totalDepositCount)
}

func withdrawToTier(t *launchpad.ProjectTier, deposit *launchpad.Deposit) {
	totalWithdrawAmount := safeAddInt64(t.TotalWithdrawAmount(), deposit.DepositAmount())
	totalWithdrawCount := safeAddInt64(t.TotalWithdrawCount(), 1)

	t.SetTotalWithdrawAmount(totalWithdrawAmount)
	t.SetTotalWithdrawCount(totalWithdrawCount)
}

func updateTierDistributeAmountPerSecond(t *launchpad.ProjectTier) {
	// Use time duration instead of block count
	distributeTimeDuration := t.EndTime() - t.StartTime()
	if distributeTimeDuration <= 0 {
		return
	}

	totalDistributeAmountX128, overflow := u256.Zero().MulOverflow(u256.NewUintFromInt64(t.TotalDistributeAmount()), q128.Clone())
	if overflow {
		panic(errOverflow)
	}

	// Divide by time duration in seconds
	distributeAmountPerSecondX128 := u256.Zero().Div(totalDistributeAmountX128, u256.NewUintFromInt64(distributeTimeDuration))

	t.SetDistributeAmountPerSecondX128(distributeAmountPerSecondX128)
}

// newProjectTier returns a pointer to a new ProjectTier with the given values.
func newProjectTier(
	projectID string,
	tierDuration int64,
	totalDistributeAmount int64,
	startTime int64,
	endTime int64,
) *launchpad.ProjectTier {
	tier := launchpad.NewProjectTier(projectID, tierDuration, totalDistributeAmount, startTime, endTime)

	updateTierDistributeAmountPerSecond(tier)

	return tier
}
