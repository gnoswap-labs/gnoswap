// PKGPATH: gno.land/r/demo/main
package main

import (
	"testing"

	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/test_token/atom"
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
	stakerRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/staker")
	govStakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")
	protocolFeeV1Realm = testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1")
)

func fundAndApproveAtomFromStaker(amount int64) {
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerRealm.Address(), amount)
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, amount)
	atom.Approve(cross, protocolFeeV1Realm.Address(), amount)
}

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

func prepareRecordedProtocolFee(amount int64) {
	fundAndApproveAtomFromStaker(amount)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", amount)
}

func testExactMatch() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 20%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 2000)

	println("[INFO] Recording 1000 atom protocol fee")
	prepareRecordedProtocolFee(1000)

	println("[INFO] Balances - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))
}

func testExternalTransfer() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 20%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 2000)

	println("[INFO] Admin transfers 1000 atom tokens to staker for recording")
	prepareRecordedProtocolFee(1000)

	println("[INFO] External user sends additional 500 atom tokens")
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, protocolFeeAddr, 500)

	println("[INFO] Recording only 1000 atom protocol fee (not including external 500)")

	println("[INFO] Balances - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees (only recorded 1000 should be distributed)")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))
	println("[EXPECTED] External 500 tokens remain in protocol_fee")
}

func testMultipleExternalTransfers() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 10%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 1000)

	println("[INFO] Admin transfers 100 atom tokens to staker for recording")
	prepareRecordedProtocolFee(100)

	println("[INFO] Multiple external transfers: 200 + 300 + 400 = 900 atom tokens")
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, protocolFeeAddr, 200)
	atom.Transfer(cross, protocolFeeAddr, 300)
	atom.Transfer(cross, protocolFeeAddr, 400)

	println("[INFO] Recording only 100 atom protocol fee")

	println("[INFO] Balances - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))
	println("[EXPECTED] 900 external tokens remain in protocol_fee")
}

func testZeroRecordedAmount() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 50%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 5000)

	println("[INFO] External user transfers 1000 atom tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	atom.Transfer(cross, protocolFeeAddr, 1000)

	println("[INFO] No amount recorded in protocol fee (0 recorded)")

	println("[INFO] Balances - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))
	println("[EXPECTED] Nothing distributed as recorded amount is 0")
}

func test100PercentToDevOps() {
	resetBalances()

	println("[INFO] Setting DevOps percentage to 100%")
	testing.SetRealm(adminRealm)
	pf.SetDevOpsPct(cross, 10000)

	println("[INFO] Admin transfers 800 atom tokens to staker for recording")
	prepareRecordedProtocolFee(800)

	println("[INFO] External transfer of 200 atom tokens")
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, protocolFeeAddr, 200)

	println("[INFO] Recording 800 atom protocol fee")

	println("[INFO] Balances - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))

	println("[INFO] Distributing protocol fees")
	testing.SetRealm(govStakerRealm)
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] After distribution - protocol_fee:", atom.BalanceOf(protocolFeeAddr), "devOps:", atom.BalanceOf(devOpsAddr), "govStaker:", atom.BalanceOf(govStakerAddr))
	println("[EXPECTED] All recorded amount (800) goes to DevOps, 200 external tokens remain")
}

func resetBalances() {
	if balance := atom.BalanceOf(protocolFeeAddr); balance > 0 {
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
		atom.Transfer(cross, adminAddr, balance)
	}
	if balance := atom.BalanceOf(devOpsAddr); balance > 0 {
		testing.SetRealm(testing.NewUserRealm(devOpsAddr))
		atom.Transfer(cross, adminAddr, balance)
	}
	if balance := atom.BalanceOf(govStakerAddr); balance > 0 {
		testing.SetRealm(testing.NewUserRealm(govStakerAddr))
		atom.Transfer(cross, adminAddr, balance)
	}

	testing.SetRealm(adminRealm)
}

// Output:
// [SCENARIO] Testing protocol fee distribution with balance/amount mismatches
//
// [TEST CASE 1] Exact match - balance equals recorded amount
// [INFO] Setting DevOps percentage to 20%
// [INFO] Recording 1000 atom protocol fee
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 0 devOps: 200 govStaker: 800
//
// [TEST CASE 2] External transfer - balance exceeds recorded amount
// [INFO] Setting DevOps percentage to 20%
// [INFO] Admin transfers 1000 atom tokens to staker for recording
// [INFO] External user sends additional 500 atom tokens
// [INFO] Recording only 1000 atom protocol fee (not including external 500)
// [INFO] Balances - protocol_fee: 1500 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees (only recorded 1000 should be distributed)
// [EXPECTED] After distribution - protocol_fee: 500 devOps: 200 govStaker: 800
// [EXPECTED] External 500 tokens remain in protocol_fee
//
// [TEST CASE 3] Multiple external transfers - only recorded amount distributed
// [INFO] Setting DevOps percentage to 10%
// [INFO] Admin transfers 100 atom tokens to staker for recording
// [INFO] Multiple external transfers: 200 + 300 + 400 = 900 atom tokens
// [INFO] Recording only 100 atom protocol fee
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 900 devOps: 10 govStaker: 90
// [EXPECTED] 900 external tokens remain in protocol_fee
//
// [TEST CASE 4] Zero recorded amount with external balance
// [INFO] Setting DevOps percentage to 50%
// [INFO] External user transfers 1000 atom tokens to protocol_fee
// [INFO] No amount recorded in protocol fee (0 recorded)
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 1000 devOps: 0 govStaker: 0
// [EXPECTED] Nothing distributed as recorded amount is 0
//
// [TEST CASE 5] 100% to DevOps with external transfer
// [INFO] Setting DevOps percentage to 100%
// [INFO] Admin transfers 800 atom tokens to staker for recording
// [INFO] External transfer of 200 atom tokens
// [INFO] Recording 800 atom protocol fee
// [INFO] Balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] After distribution - protocol_fee: 200 devOps: 800 govStaker: 0
// [EXPECTED] All recorded amount (800) goes to DevOps, 200 external tokens remain
