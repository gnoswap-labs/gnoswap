// Scenario: Safe Mode blocks gov/staker settlement paths

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	"gno.land/r/gnoswap/halt"
	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
)

var t *testing.T

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm        = testing.NewUserRealm(stakerAddr)
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm     = testing.NewUserRealm(govStakerAddr)
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	bobAddr            = testutils.TestAddress("bob")
	bobRealm           = testing.NewUserRealm(bobAddr)
)

func main() {
	println("[SCENARIO] 1. Delegate GNS to Bob")
	delegateToBob()
	println()

	println("[SCENARIO] 2. Add protocol fee and distribute")
	setupProtocolFee()
	println()

	println("[SCENARIO] 3. Set safe mode")
	setSafeMode()
	println()

	println("[SCENARIO] 4. Gov/staker settlement is blocked")
	collectRewardBlocked()
	println()
}

func delegateToBob() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, bobAddr, 5000000)
	testing.SetRealm(bobRealm)
	gns.Approve(cross, govStakerAddr, 5000000)
	staker.Delegate(cross, bobAddr, 5000000, "")
	ufmt.Println("[INFO] delegated to bob")
}

func setupProtocolFee() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, stakerAddr, 1000)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross, protocolFeeAddr, 1000)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)
	testing.SkipHeights(10)
	testing.SetRealm(govStakerRealm)
	emission.MintAndDistributeGns(cross)
	pf.DistributeProtocolFee(cross)
	ufmt.Println("[INFO] protocol fee distributed")
}

func setSafeMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)
	ufmt.Printf("[INFO] GovStaker halted: %t\n", halt.IsHaltedGovStaker())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func collectRewardBlocked() {
	testing.SetRealm(bobRealm)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		staker.CollectReward(cross)
	})
	ufmt.Println("[EXPECTED] Gov/staker CollectReward blocked by withdraw halt")
}

// Output:
// [SCENARIO] 1. Delegate GNS to Bob
// [INFO] delegated to bob
//
// [SCENARIO] 2. Add protocol fee and distribute
// [INFO] protocol fee distributed
//
// [SCENARIO] 3. Set safe mode
// [INFO] GovStaker halted: false
// [INFO] Withdraw halted: true
//
// [SCENARIO] 4. Gov/staker settlement is blocked
// [EXPECTED] Gov/staker CollectReward blocked by withdraw halt
