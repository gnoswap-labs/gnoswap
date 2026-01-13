// PKGPATH: gno.land/r/demo/main
package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	dc "gno.land/r/gnoswap/dust_converter"
	"gno.land/r/gnoswap/gns"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	userAddr  = testutils.TestAddress("dust-user")
	userRealm = testing.NewUserRealm(userAddr)

	dustConverterAddr = testing.NewCodeRealm("gno.land/r/gnoswap/dust_converter").Address()
)

const gnsPath = "gno.land/r/gnoswap/gns"

var t *testing.T

func main() {
	println("[SCENARIO] Dust converter with min/max bounds")
	println()

	println("[SCENARIO] 1. Configure bounds")
	configureBounds()
	println()

	println("[SCENARIO] 2. Below-min dust should be skipped")
	testBelowMin()
	println()

	println("[SCENARIO] 3. Within bounds should convert")
	testWithinBounds()
	println()
}

func configureBounds() {
	testing.SetRealm(adminRealm)
	dc.SetDustMinAmount(cross, 5)
	dc.SetDustMaxAmount(cross, 10)
	println("[EXPECTED] min:", dc.GetDustMinAmount(), "max:", dc.GetDustMaxAmount())
}

func testBelowMin() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, dustConverterAddr, 4)
	println("[EXPECTED] dust_converter gns balance:", gns.BalanceOf(dustConverterAddr))

	testing.SetRealm(userRealm)
	totalGnsOut := dc.ConvertDustToGns(cross, gnsPath+":4", time.Now().Add(time.Hour).Unix(), userAddr)

	println("[EXPECTED] totalGnsOut:", totalGnsOut)
	println("[EXPECTED] dust_converter gns balance after convert:", gns.BalanceOf(dustConverterAddr))
}

func testWithinBounds() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, dustConverterAddr, 7)
	println("[EXPECTED] dust_converter gns balance:", gns.BalanceOf(dustConverterAddr))

	testing.SetRealm(userRealm)
	beforeUserGns := gns.BalanceOf(userAddr)
	totalGnsOut := dc.ConvertDustToGns(cross, gnsPath+":7", time.Now().Add(time.Hour).Unix(), userAddr)

	println("[EXPECTED] totalGnsOut:", totalGnsOut)
	println("[EXPECTED] dust_converter gns balance after convert:", gns.BalanceOf(dustConverterAddr))
	ufmt.Printf("[EXPECTED] user gns delta: %d\n", gns.BalanceOf(userAddr)-beforeUserGns)
}

// Output:
// [SCENARIO] Dust converter with min/max bounds
//
// [SCENARIO] 1. Configure bounds
// [EXPECTED] min: 5 max: 10
//
// [SCENARIO] 2. Below-min dust should be skipped
// [EXPECTED] dust_converter gns balance: 4
// [EXPECTED] totalGnsOut: 0
// [EXPECTED] dust_converter gns balance after convert: 4
//
// [SCENARIO] 3. Within bounds should convert
// [EXPECTED] dust_converter gns balance: 11
// [EXPECTED] totalGnsOut: 7
// [EXPECTED] dust_converter gns balance after convert: 4
// [EXPECTED] user gns delta: 7
