package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestNumericValueFieldsPreserveIsolationAndBoundaries(t *testing.T) {
	maxLiquidity := u256.MaxUint256()
	maxLiquidityString := maxLiquidity.ToString()
	deposit := NewDeposit(adminAddr, "test-pool", maxLiquidity, 10, -10, 10, nil)

	// Constructors copy caller values rather than retaining mutable input pointers.
	maxLiquidity.Clear()
	uassert.Equal(t, maxLiquidityString, deposit.Liquidity().ToString())

	// Getters return detached values; mutating the result does not mutate the record.
	liquidityResult := deposit.Liquidity()
	liquidityResult.Clear()
	uassert.Equal(t, maxLiquidityString, deposit.Liquidity().ToString())

	// Setters copy inputs and clones retain independent numeric values.
	zeroLiquidity := u256.Zero()
	deposit.SetLiquidity(zeroLiquidity)
	zeroLiquidity.Set(u256.One())
	uassert.Equal(t, "0", deposit.Liquidity().ToString())

	deposit.SetLiquidity(u256.MaxUint256())
	depositClone := deposit.Clone()
	depositClone.SetLiquidity(u256.Zero())
	uassert.Equal(t, maxLiquidityString, deposit.Liquidity().ToString())

	tick := NewTick(-10)
	maxGross := u256.MaxUint256()
	minDelta := i256.MinInt256()
	minDeltaString := minDelta.ToString()
	tick.SetStakedLiquidityGross(maxGross)
	tick.SetStakedLiquidityDelta(minDelta)
	maxGross.Clear()
	minDelta.SetInt64(0)

	uassert.Equal(t, maxLiquidityString, tick.StakedLiquidityGross().ToString())
	uassert.Equal(t, minDeltaString, tick.StakedLiquidityDelta().ToString())

	grossResult := tick.StakedLiquidityGross()
	deltaResult := tick.StakedLiquidityDelta()
	grossResult.Clear()
	deltaResult.SetInt64(0)
	uassert.Equal(t, maxLiquidityString, tick.StakedLiquidityGross().ToString())
	uassert.Equal(t, minDeltaString, tick.StakedLiquidityDelta().ToString())

	tickClone := tick.Clone()
	tickClone.SetStakedLiquidityGross(u256.Zero())
	tickClone.SetStakedLiquidityDelta(i256.Zero())
	uassert.Equal(t, maxLiquidityString, tick.StakedLiquidityGross().ToString())
	uassert.Equal(t, minDeltaString, tick.StakedLiquidityDelta().ToString())

	incentive := NewExternalIncentive("numeric", "test-pool", "token", 0, 100, 101, adminAddr, 0, 0, 100)
	zeroRate := u256.Zero()
	incentive.SetRewardPerSecondX128(zeroRate)
	zeroRate.Set(u256.One())
	uassert.Equal(t, "0", incentive.RewardPerSecondX128().ToString())

	maxRate := u256.MaxUint256()
	incentive.SetRewardPerSecondX128(maxRate)
	maxRate.Clear()
	uassert.Equal(t, maxLiquidityString, incentive.RewardPerSecondX128().ToString())

	rateResult := incentive.RewardPerSecondX128()
	rateResult.Clear()
	uassert.Equal(t, maxLiquidityString, incentive.RewardPerSecondX128().ToString())

	incentiveClone := incentive.Clone()
	incentiveClone.SetRewardPerSecondX128(u256.Zero())
	uassert.Equal(t, maxLiquidityString, incentive.RewardPerSecondX128().ToString())
}
