package launchpad

import (
	"errors"

	"gno.land/r/gnoswap/launchpad"

	"gno.land/p/gnoswap/consts"
	gnsmath "gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
)

// getTierCurrentDepositCount computes the number of deposits still active in a tier.
//
// Parameters:
//   - t: project tier whose cumulative deposit and withdrawal counts are compared.
//
// Returns:
//   - count: total deposit count minus total withdrawal count.
func getTierCurrentDepositCount(t *launchpad.ProjectTier) int64 {
	return gnsmath.SafeSubInt64(t.TotalDepositCount(), t.TotalWithdrawCount())
}

// getTierCurrentDepositAmount computes the amount still deposited in a tier.
//
// Parameters:
//   - t: project tier whose cumulative deposit and withdrawal amounts are compared.
//
// Returns:
//   - amount: total deposited amount minus total withdrawn amount.
func getTierCurrentDepositAmount(t *launchpad.ProjectTier) int64 {
	return gnsmath.SafeSubInt64(t.TotalDepositAmount(), t.TotalWithdrawAmount())
}

// getCalculatedLeftReward computes the reward allocation not yet collected from a tier.
//
// Parameters:
//   - t: project tier whose allocation and collected amount are compared.
//
// Returns:
//   - amount: total distribute amount minus total collected amount.
func getCalculatedLeftReward(t *launchpad.ProjectTier) int64 {
	return gnsmath.SafeSubInt64(t.TotalDistributeAmount(), t.TotalCollectedAmount())
}

// depositToTier records one deposit's amount and count in a project tier.
//
// Parameters:
//   - t: project tier whose cumulative deposit totals are updated.
//   - deposit: deposit whose GNS amount contributes to the tier total.
func depositToTier(t *launchpad.ProjectTier, deposit launchpad.Deposit) {
	totalDepositAmount := gnsmath.SafeAddInt64(t.TotalDepositAmount(), deposit.DepositAmount())
	totalDepositCount := gnsmath.SafeAddInt64(t.TotalDepositCount(), 1)

	t.SetTotalDepositAmount(totalDepositAmount)
	t.SetTotalDepositCount(totalDepositCount)
}

// withdrawToTier records one withdrawal's amount and count in a project tier.
//
// Parameters:
//   - t: project tier whose cumulative withdrawal totals are updated.
//   - deposit: withdrawn deposit whose amount contributes to the tier total.
func withdrawToTier(t *launchpad.ProjectTier, deposit launchpad.Deposit) {
	totalWithdrawAmount := gnsmath.SafeAddInt64(t.TotalWithdrawAmount(), deposit.DepositAmount())
	totalWithdrawCount := gnsmath.SafeAddInt64(t.TotalWithdrawCount(), 1)

	t.SetTotalWithdrawAmount(totalWithdrawAmount)
	t.SetTotalWithdrawCount(totalWithdrawCount)
}

// updateTierDistributeAmountPerSecond computes and stores a tier's Q128 reward rate.
//
// Parameters:
//   - t: project tier supplying total allocation and start/end timestamps; non-positive duration leaves it unchanged.
func updateTierDistributeAmountPerSecond(t *launchpad.ProjectTier) {
	// Use time duration instead of block count
	distributeTimeDuration := t.EndTime() - t.StartTime()
	if distributeTimeDuration <= 0 {
		return
	}

	totalDistributeAmountX128, overflow := u256.Zero().MulOverflow(u256.NewUintFromInt64(t.TotalDistributeAmount()), consts.Q128())
	if overflow {
		panic(errors.New(errOverflow))
	}

	// Divide by time duration in seconds
	distributeAmountPerSecondX128 := u256.Zero().Div(totalDistributeAmountX128, u256.NewUintFromInt64(distributeTimeDuration))

	t.SetDistributeAmountPerSecondX128(distributeAmountPerSecondX128)
}

// newProjectTier creates a project tier and initializes its Q128-scaled per-second distribution rate.
//
// Parameters:
//   - projectID: identifier of the project owning the tier.
//   - tierDuration: tier duration in seconds.
//   - totalDistributeAmount: total reward-token amount allocated to the tier.
//   - startTime: reward distribution start Unix timestamp.
//   - endTime: reward distribution end Unix timestamp.
//
// Returns:
//   - tier: initialized project tier with its distribution rate calculated.
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
