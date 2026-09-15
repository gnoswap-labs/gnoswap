package position

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/halt"
	positionRoot "gno.land/r/gnoswap/position"
)

func TestRenderShowsStoredStateAndRetainedBurnedRecord(cur realm, t *testing.T) {
	initPositionTest(cur, t)
	instance := mockInstance

	positions := instance.store.GetPositions()
	storedPosition := positionRoot.NewPosition(
		"gno.land/r/gnoswap/pool:token0:token1:500",
		-60,
		60,
		"0",
		"0",
		"0",
		0,
		0,
		true,
		"",
	)
	positions.Set("1", *storedPosition)
	if err := instance.store.SetPositions(0, cur, positions); err != nil {
		panic(err)
	}
	if err := instance.store.SetPositionNextID(0, cur, 2); err != nil {
		panic(err)
	}

	testing.SetRealm(adminRealm)
	previousPositionHalt := halt.IsHaltedPosition()
	previousWithdrawHalt := halt.IsHaltedWithdraw()
	defer func() {
		testing.SetRealm(adminRealm)
		halt.SetOperationStatus(cross(cur), halt.OpTypePosition, previousPositionHalt)
		halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, previousWithdrawHalt)
	}()

	halt.SetOperationStatus(cross(cur), halt.OpTypePosition, true)
	halt.SetOperationStatus(cross(cur), halt.OpTypeWithdraw, true)

	rendered := instance.Render("")
	for _, want := range []string{
		"| Position operations halted | true |",
		"| Withdrawals halted | true |",
		"| Stored position records (including burned) | 1 |",
		"| Next position ID | 2 |",
	} {
		uassert.True(t, strings.Contains(rendered, want), want)
	}
}

func TestRenderUnknownPathReturns404BeforeStateAccess(cur realm, t *testing.T) {
	initPositionTest(cur, t)
	instance := mockInstance
	store := instance.store
	instance.store = nil
	defer func() { instance.store = store }()

	uassert.Equal(t, "404\n", instance.Render("unsupported"))
}
