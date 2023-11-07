package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"

	gns "gno.land/r/gns"
)

var (
	pc01 = testutils.TestAddress("pc01") // pool creator
	gsa  = testutils.TestAddress("gsa")

	poolAddr = std.DerivePkgAddr("gno.land/r/pool")
	posAddr  = std.DerivePkgAddr("gno.land/r/position")
)

var (
	fooPath          = "gno.land/r/foo" // token1
	barPath          = "gno.land/r/bar" // token2
	bazPath          = "gno.land/r/baz"
	sqrtPrice bigint = 130621891405341611593710811006

	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = bigint(100_000_000)

	currentTick = int32(10000)
)

func init() {
	std.TestSetOrigCaller(gsa)
	InitManual()
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pc01Before := gns.BalanceOf(a2u(pc01))
	gsaBefore := gns.BalanceOf(a2u(gsa))
	shouldEQ(t, gsaBefore, 0)

	CreatePool(fooPath, barPath, uint16(100), sqrtPrice)
	CreatePool(fooPath, barPath, uint16(500), sqrtPrice)
	CreatePool(fooPath, barPath, uint16(3000), sqrtPrice)
	CreatePool(fooPath, barPath, uint16(10000), sqrtPrice)

	pc01After := gns.BalanceOf(a2u(pc01))
	gsaAfter := gns.BalanceOf(a2u(gsa))

	shouldEQ(t, gsaAfter-gsaBefore, 2000)
	shouldEQ(t, pc01Before-pc01After, 2000)
	shouldEQ(t, len(pools), 4)
}

func TestCreatePoolNotEnoughGNS(t *testing.T) {
	shouldPanicWithMsg(t, func() { CreatePool(fooPath, bazPath, uint16(100), sqrtPrice) }, "insufficient balance")
	shouldEQ(t, len(pools), 4)
}

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}
