package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestEmissionRewardManager_UsesFixedWidthAccumulator(cur realm, t *testing.T) {
	manager := NewEmissionRewardManager()
	maxValue := u256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935")

	manager.SetAccumulatedRewardX128PerStake(maxValue)

	uassert.Equal(t, len(manager.accumulatedRewardX128PerStake), 32)
	uassert.Equal(t, manager.GetAccumulatedRewardX128PerStake().ToString(), maxValue.ToString())
}
