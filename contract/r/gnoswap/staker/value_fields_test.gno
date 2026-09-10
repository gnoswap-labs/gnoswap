package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestDepositLiquidityValueIsolation(t *testing.T) {
	absent := NewDeposit(adminAddr, "test-pool", nil, 10, -10, 10, nil)
	if absent.Liquidity() != nil {
		panic("absent liquidity was materialized")
	}

	maxLiquidity := u256.MaxUint256()
	maxLiquidityString := maxLiquidity.ToString()
	deposit := NewDeposit(adminAddr, "test-pool", maxLiquidity, 10, -10, 10, nil)

	maxLiquidity.Clear()
	uassert.Equal(t, maxLiquidityString, deposit.Liquidity().ToString())

	result := deposit.Liquidity()
	result.Clear()
	uassert.Equal(t, maxLiquidityString, deposit.Liquidity().ToString())

	zeroLiquidity := u256.Zero()
	deposit.SetLiquidity(zeroLiquidity)
	zeroLiquidity.Set(u256.One())
	uassert.Equal(t, "0", deposit.Liquidity().ToString())

	deposit.SetLiquidity(u256.MaxUint256())
	clone := deposit.Clone()
	clone.SetLiquidity(u256.Zero())
	uassert.Equal(t, maxLiquidityString, deposit.Liquidity().ToString())
}
