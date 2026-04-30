// Scenario: Safe Mode blocks protocol fee distribution while keeping accrual/config paths available

package main

import (
	"testing"

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

	println("[SCENARIO] 2. Set safe mode")
	setSafeMode()
	println()

	println("[SCENARIO] 3. AddToProtocolFee remains allowed")
	addProtocolFee()
	println()

	println("[SCENARIO] 4. DistributeProtocolFee is skipped")
	distributeProtocolFeeSkipped()
	println()

	println("[SCENARIO] 5. Protocol fee setter remains allowed")
	setterAllowed()
	println()
}

func setupProtocolFeeBalance() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, stakerAddr, 1000)
	ufmt.Printf("[INFO] staker BAR balance before add: %d\n", bar.BalanceOf(stakerAddr))
}

func setSafeMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)
	ufmt.Printf("[INFO] ProtocolFee halted: %t\n", halt.IsHaltedProtocolFee())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func addProtocolFee() {
	testing.SetRealm(stakerRealm)
	bar.Approve(cross, protocolFeeAddr, 1000)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)
	ufmt.Println("[EXPECTED] AddToProtocolFee succeeded in safe mode")
}

func distributeProtocolFee() {
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)
	ufmt.Printf("[EXPECTED] protocol fee BAR balance after distribution: %d\n", bar.BalanceOf(protocolFeeAddr))
	ufmt.Printf("[EXPECTED] gov staker BAR balance after distribution: %d\n", bar.BalanceOf(govStakerAddr))
}

func distributeProtocolFeeSkipped() {
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)
	ufmt.Printf("[EXPECTED] protocol fee BAR balance after distribution: %d\n", bar.BalanceOf(protocolFeeAddr))
	ufmt.Printf("[EXPECTED] gov staker BAR balance after distribution: %d\n", bar.BalanceOf(govStakerAddr))
}

func setterAllowed() {
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 10)
	ufmt.Println("[EXPECTED] SetDevOpsPct succeeded in safe mode")
}

// Output:
// [SCENARIO] 1. Setup protocol fee balance
// [INFO] staker BAR balance before add: 1000
//
// [SCENARIO] 2. Set safe mode
// [INFO] ProtocolFee halted: false
// [INFO] Withdraw halted: true
//
// [SCENARIO] 3. AddToProtocolFee remains allowed
// [EXPECTED] AddToProtocolFee succeeded in safe mode
//
// [SCENARIO] 4. DistributeProtocolFee is skipped
// [EXPECTED] protocol fee BAR balance after distribution: 1000
// [EXPECTED] gov staker BAR balance after distribution: 0
//
// [SCENARIO] 5. Protocol fee setter remains allowed
// [EXPECTED] SetDevOpsPct succeeded in safe mode
