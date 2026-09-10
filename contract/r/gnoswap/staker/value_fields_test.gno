package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestExternalIncentiveRewardRateValueIsolation(t *testing.T) {
	zeroValue := &ExternalIncentive{}
	zeroRateValue := zeroValue.RewardPerSecondX128()
	uassert.Equal(t, "0", zeroRateValue.ToString())

	incentive := NewExternalIncentive("numeric", "test-pool", "token", 100, 0, 100, adminAddr, 0, 0, 0)

	zeroRate := u256.Zero()
	incentive.SetRewardPerSecondX128(zeroRate)
	zeroRate.Set(u256.One())
	rate := incentive.RewardPerSecondX128()
	uassert.Equal(t, "0", rate.ToString())

	maxRate := u256.MaxUint256()
	maxRateString := maxRate.ToString()
	incentive.SetRewardPerSecondX128(maxRate)
	maxRate.Clear()
	rate = incentive.RewardPerSecondX128()
	uassert.Equal(t, maxRateString, rate.ToString())

	result := incentive.RewardPerSecondX128()
	result.Clear()
	rate = incentive.RewardPerSecondX128()
	uassert.Equal(t, maxRateString, rate.ToString())
}
