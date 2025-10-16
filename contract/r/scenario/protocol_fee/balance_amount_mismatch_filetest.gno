// PKGPATH: gno.land/r/demo/main
package main

import (
	"testing"

	"gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/rbac"
	prbac "gno.land/p/gnoswap/rbac"

	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/onbloc/bar"
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr, _      = access.GetAddress(prbac.ROLE_DEVOPS.String())
)

var (
	adminRealm     = testing.NewUserRealm(adminAddr)
	stakerRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/v1/staker")
	govStakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/v1/gov/staker")
)

func main() {
	println("[SCENARIO] Testing protocol fee distribution with balance/amount mismatches")
	println()

	println("[TEST CASE 1] Exact match - balance equals recorded amount")
	testExactMatch()
	println()

	println("[TEST CASE 2] External transfer - balance exceeds recorded amount")
	testExternalTransfer()
	println()

	println("[TEST CASE 3] Multiple external transfers - only recorded amount distributed")
	testMultipleExternalTransfers()
	println()

	println("[TEST CASE 4] Zero recorded amount with external balance")
	testZeroRecordedAmount()
	println()

	println("[TEST CASE 5] 100% to DevOps with external transfer")
	test100PercentToDevOps()
	println()
}

func testExactMatch() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 20%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 2000)

	println("[INFO] Admin transfers 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	println("[INFO] Recording 1000 bar protocol fee")
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
}

func testExternalTransfer() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 20%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 2000)

	println("[INFO] Admin transfers 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	println("[INFO] External user sends additional 500 bar tokens")
	bar.Transfer(cross, protocolFeeAddr, 500)

	println("[INFO] Recording only 1000 bar protocol fee (not including external 500)")
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees (only recorded 1000 should be distributed)")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] External 500 tokens remain in protocol_fee")
}

func testMultipleExternalTransfers() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 10%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 1000)

	println("[INFO] Admin transfers 100 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 100)

	println("[INFO] Multiple external transfers: 200 + 300 + 400 = 900 bar tokens")
	bar.Transfer(cross, protocolFeeAddr, 200)
	bar.Transfer(cross, protocolFeeAddr, 300)
	bar.Transfer(cross, protocolFeeAddr, 400)

	println("[INFO] Recording only 100 bar protocol fee")

	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 100)

	println("[INFO] Balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] 900 external tokens remain in protocol_fee")
}

func testZeroRecordedAmount() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 50%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 5000)

	println("[INFO] External user transfers 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	println("[INFO] No amount recorded in protocol fee (0 recorded)")

	println("[INFO] Balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] Nothing distributed as recorded amount is 0")
}

func test100PercentToDevOps() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 100%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 10000)

	println("[INFO] Admin transfers 800 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 800)

	println("[INFO] External transfer of 200 bar tokens")
	bar.Transfer(cross, protocolFeeAddr, 200)

	println("[INFO] Recording 800 bar protocol fee")
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 800)

	println("[INFO] Balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] All recorded amount (800) goes to DevOps, 200 external tokens remain")
}

func resetBalances() {
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
		bar.Transfer(cross, adminAddr, balance)
	}
	if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
		testing.SetRealm(testing.NewUserRealm(devOpsAddr))
		bar.Transfer(cross, adminAddr, balance)
	}
	if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
		testing.SetRealm(testing.NewUserRealm(govStakerAddr))
		bar.Transfer(cross, adminAddr, balance)
	}

	testing.SetRealm(adminRealm)
}

// Output:
// [SCENARIO] Testing protocol fee distribution with balance/amount mismatches
//
// [TEST CASE 1] Exact match - balance equals recorded amount
// [INFO] Setting DevOps percentage to 20%
// [INFO] Admin transfers 1000 bar tokens to protocol_fee
// [INFO] Recording 1000 bar protocol fee
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 0 devOps: 200 govStaker: 800
//
// [TEST CASE 2] External transfer - balance exceeds recorded amount
// [INFO] Setting DevOps percentage to 20%
// [INFO] Admin transfers 1000 bar tokens to protocol_fee
// [INFO] External user sends additional 500 bar tokens
// [INFO] Recording only 1000 bar protocol fee (not including external 500)
// [INFO] Balances - protocol_fee: 1500 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees (only recorded 1000 should be distributed)
// [EXPECTED] After distribution - protocol_fee: 500 devOps: 200 govStaker: 800
// [EXPECTED] External 500 tokens remain in protocol_fee
//
// [TEST CASE 3] Multiple external transfers - only recorded amount distributed
// [INFO] Setting DevOps percentage to 10%
// [INFO] Admin transfers 100 bar tokens to protocol_fee
// [INFO] Multiple external transfers: 200 + 300 + 400 = 900 bar tokens
// [INFO] Recording only 100 bar protocol fee
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 900 devOps: 10 govStaker: 90
// [EXPECTED] 900 external tokens remain in protocol_fee
//
// [TEST CASE 4] Zero recorded amount with external balance
// [INFO] Setting DevOps percentage to 50%
// [INFO] External user transfers 1000 bar tokens to protocol_fee
// [INFO] No amount recorded in protocol fee (0 recorded)
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 1000 devOps: 0 govStaker: 0
// [EXPECTED] Nothing distributed as recorded amount is 0
//
// [TEST CASE 5] 100% to DevOps with external transfer
// [INFO] Setting DevOps percentage to 100%
// [INFO] Admin transfers 800 bar tokens to protocol_fee
// [INFO] External transfer of 200 bar tokens
// [INFO] Recording 800 bar protocol fee
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 200 devOps: 800 govStaker: 0
// [EXPECTED] All recorded amount (800) goes to DevOps, 200 external tokens remain
