// Scenario: Emergency Mode keeps protocol fee settlement available but blocks protocol fee admin changes

package main

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
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
	stakerRealm        = testing.NewCodeRealm("gno.land/r/gnoswap/staker")
	govStakerRealm     = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
)

func main() {
	println("[SCENARIO] 1. Setup protocol fee balance")
	setupProtocolFeeBalance()
	println()

	println("[SCENARIO] 2. Set emergency mode")
	setEmergencyMode()
	println()

	println("[SCENARIO] 3. AddToProtocolFee remains allowed")
	addProtocolFee()
	println()

	println("[SCENARIO] 4. DistributeProtocolFee remains allowed")
	distributeProtocolFee()
	println()

	println("[SCENARIO] 5. Protocol fee setter remains blocked")
	setterBlocked()
	println()
}

func setupProtocolFeeBalance() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, 1000)
	ufmt.Printf("[INFO] protocol fee BAR balance: %d\n", bar.BalanceOf(protocolFeeAddr))
}

func setEmergencyMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] ProtocolFee halted: %t\n", halt.IsHaltedProtocolFee())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func addProtocolFee() {
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)
	ufmt.Println("[EXPECTED] AddToProtocolFee succeeded in emergency")
}

func distributeProtocolFee() {
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)
	ufmt.Printf("[EXPECTED] protocol fee BAR balance after distribution: %d\n", bar.BalanceOf(protocolFeeAddr))
	ufmt.Printf("[EXPECTED] gov staker BAR balance after distribution: %d\n", bar.BalanceOf(govStakerAddr))
}

func setterBlocked() {
	testing.SetRealm(adminRealm)
	uassert.AbortsContains(t, "halted: protocol_fee", func() {
		pf.SetDevOpsPct(cross, 10)
	})
	ufmt.Println("[EXPECTED] SetDevOpsPct blocked by protocol_fee halt")
}

// Output:
// [SCENARIO] 1. Setup protocol fee balance
// [INFO] protocol fee BAR balance: 1000
//
// [SCENARIO] 2. Set emergency mode
// [INFO] ProtocolFee halted: true
// [INFO] Withdraw halted: false
//
// [SCENARIO] 3. AddToProtocolFee remains allowed
// [EXPECTED] AddToProtocolFee succeeded in emergency
//
// [SCENARIO] 4. DistributeProtocolFee remains allowed
// [EXPECTED] protocol fee BAR balance after distribution: 0
// [EXPECTED] gov staker BAR balance after distribution: 1000
//
// [SCENARIO] 5. Protocol fee setter remains blocked
// [EXPECTED] SetDevOpsPct blocked by protocol_fee halt
