package pool

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/halt"
)

func TestRenderShowsStoredStateAndConfiguration(cur realm, t *testing.T) {
	resetObject(cur, t)
	instance := getMockInstance()

	pools := instance.store.GetPools()
	pools.Set("pool-1", true)
	pools.Set("pool-2", true)
	if err := instance.store.SetPools(0, cur, pools); err != nil {
		panic(err)
	}
	if err := instance.store.SetPoolCreationFee(0, cur, 250_000_000); err != nil {
		panic(err)
	}
	if err := instance.store.SetWithdrawalFeeBPS(0, cur, 275); err != nil {
		panic(err)
	}
	if err := instance.store.SetSlot0FeeProtocol(0, cur, 84); err != nil {
		panic(err)
	}

	testing.SetRealm(adminRealm)
	previousPoolHalt := halt.IsHaltedPool()
	previousProtocolFeeHalt := halt.IsHaltedProtocolFee()
	previousWithdrawHalt := halt.IsHaltedWithdraw()
	defer func() {
		testing.SetRealm(adminRealm)
		halt.SetOperationStatus(cross(cur), halt.OpTypePool, previousPoolHalt)
		halt.SetOperationStatus(cross(cur), halt.OpTypeProtocolFee, previousProtocolFeeHalt)
		halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, previousWithdrawHalt)
	}()

	halt.SetOperationStatus(cross(cur), halt.OpTypePool, true)
	halt.SetOperationStatus(cross(cur), halt.OpTypeProtocolFee, true)
	halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, true)

	rendered := instance.Render("")
	for _, want := range []string{
		"| Pool operations halted | true |",
		"| Protocol-fee operations halted | true |",
		"| Withdrawals halted | true |",
		"| Stored pool records | 2 |",
		"| Pool creation fee (GNS base units; 6 decimals) | 250000000 |",
		"| Withdrawal fee | 275 bps |",
		"| Protocol fee denominators (token0 / token1) | 4 / 5 |",
	} {
		uassert.True(t, strings.Contains(rendered, want), want)
	}
}

func TestRenderUnknownPathReturns404BeforeStateAccess(cur realm, t *testing.T) {
	resetObject(cur, t)
	instance := getMockInstance()
	store := instance.store
	instance.store = nil
	defer func() { instance.store = store }()

	uassert.Equal(t, "404\n", instance.Render("unsupported"))
}
