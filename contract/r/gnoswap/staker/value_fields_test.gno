package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestExternalIncentiveRewardRateValueIsolation(t *testing.T) {
	absent := &ExternalIncentive{}
	if absent.RewardPerSecondX128() != nil {
		panic("absent reward rate was materialized")
	}

	incentive := NewExternalIncentive("numeric", "test-pool", "token", 100, 0, 100, adminAddr, 0, 0, 0)
	if incentive.RewardPerSecondX128() == nil {
		panic("constructor omitted reward rate")
	}

	zeroRate := u256.Zero()
	incentive.SetRewardPerSecondX128(zeroRate)
	zeroRate.Set(u256.One())
	uassert.Equal(t, "0", incentive.RewardPerSecondX128().ToString())

	maxRate := u256.MaxUint256()
	maxRateString := maxRate.ToString()
	incentive.SetRewardPerSecondX128(maxRate)
	maxRate.Clear()
	uassert.Equal(t, maxRateString, incentive.RewardPerSecondX128().ToString())

	result := incentive.RewardPerSecondX128()
	result.Clear()
	uassert.Equal(t, maxRateString, incentive.RewardPerSecondX128().ToString())

	clone := incentive.Clone()
	clone.SetRewardPerSecondX128(u256.Zero())
	uassert.Equal(t, maxRateString, incentive.RewardPerSecondX128().ToString())
}
