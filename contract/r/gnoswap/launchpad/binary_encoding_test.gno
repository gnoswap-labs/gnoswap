package launchpad

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestRewardManager_DistributeAmountPerSecondX128FixedWidthEncoding(cur realm, t *testing.T) {
	value := &u256.Uint{
		0x0123456789abcdef,
		0x1011121314151617,
		0x8081828384858687,
		0xfedcba9876543210,
	}
	want := utils.EncodeUint256(value)

	manager := NewRewardManager(1000, 100, 200, 0)
	uassert.Equal(t, utils.EncodeUint256(u256.Zero()), manager.distributeAmountPerSecondX128)
	manager.SetDistributeAmountPerSecondX128(value)

	uassert.Equal(t, 32, len(manager.distributeAmountPerSecondX128))
	uassert.Equal(t, want, manager.distributeAmountPerSecondX128)
	uassert.Equal(t, value.ToString(), manager.DistributeAmountPerSecondX128().ToString())

	value[0] = value[0] ^ 1
	got := manager.DistributeAmountPerSecondX128()
	got[0] = got[0] ^ 1
	uassert.Equal(t, want, manager.distributeAmountPerSecondX128)

	clone := manager.Clone()
	uassert.Equal(t, want, clone.distributeAmountPerSecondX128)
	clone.SetDistributeAmountPerSecondX128(u256.Zero())
	uassert.Equal(t, want, manager.distributeAmountPerSecondX128)
}
