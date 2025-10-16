// PKGPATH: gno.land/r/demo/main
package main

import (
	"testing"

	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

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
	println("[SCENARIO] Testing protocol fee distribution with different DevOps percentages")
	println()

	println("[TEST CASE 1] 0% to DevOps (default)")
	testCase0Percent()
	println()

	println("[TEST CASE 2] 25% to DevOps")
	testCase25Percent()
	println()

	println("[TEST CASE 3] 50% to DevOps")
	testCase50Percent()
	println()

	println("[TEST CASE 4] 100% to DevOps")
	testCase100Percent()
	println()

	println("[TEST CASE 5] 33.33% to DevOps")
	testCase3333Percent()
	println()
}

func testCase0Percent() {
	resetBalances()

	testing.SetRealm(adminRealm)
	println("[INFO] Setting DevOps percentage to 0%")
	pf.SetDevOpsPct(cross, 0)

	println("[INFO] Transferring 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	testing.SetRealm(stakerRealm)
	println("[INFO] Recording 1000 bar protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Initial balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	testing.SetRealm(govStakerRealm)
	println("[INFO] Distributing protocol fees")
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] Final balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
}

func testCase25Percent() {
	resetBalances()

	testing.SetRealm(adminRealm)
	println("[INFO] Setting DevOps percentage to 25%")
	pf.SetDevOpsPct(cross, 2500)

	println("[INFO] Transferring 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	testing.SetRealm(stakerRealm)
	println("[INFO] Recording 1000 bar protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Initial balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	testing.SetRealm(govStakerRealm)
	println("[INFO] Distributing protocol fees")
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] Final balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
}

func testCase50Percent() {
	resetBalances()

	testing.SetRealm(adminRealm)
	println("[INFO] Setting DevOps percentage to 50%")
	pf.SetDevOpsPct(cross, 5000)

	println("[INFO] Transferring 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	testing.SetRealm(stakerRealm)
	println("[INFO] Recording 1000 bar protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Initial balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	testing.SetRealm(govStakerRealm)
	println("[INFO] Distributing protocol fees")
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] Final balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
}

func testCase100Percent() {
	resetBalances()

	testing.SetRealm(adminRealm)
	println("[INFO] Setting DevOps percentage to 100%")
	pf.SetDevOpsPct(cross, 10000)

	println("[INFO] Transferring 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	testing.SetRealm(stakerRealm)
	println("[INFO] Recording 1000 bar protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Initial balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	testing.SetRealm(govStakerRealm)
	println("[INFO] Distributing protocol fees")
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] Final balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
}

func testCase3333Percent() {
	resetBalances()

	testing.SetRealm(adminRealm)
	println("[INFO] Setting DevOps percentage to 33.33%")
	pf.SetDevOpsPct(cross, 3333)

	println("[INFO] Transferring 1000 bar tokens to protocol_fee")
	testing.SetOriginCaller(adminAddr)
	bar.Transfer(cross, protocolFeeAddr, 1000)

	testing.SetRealm(stakerRealm)
	println("[INFO] Recording 1000 bar protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Initial balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))

	testing.SetRealm(govStakerRealm)
	println("[INFO] Distributing protocol fees")
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] Final balances - protocol_fee:", bar.BalanceOf(protocolFeeAddr), "devOps:", bar.BalanceOf(devOpsAddr), "govStaker:", bar.BalanceOf(govStakerAddr))
}

func resetBalances() {
	testing.SetRealm(adminRealm)

	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Transfer(cross, adminAddr, balance)
	}
	if balance := bar.BalanceOf(devOpsAddr); balance > 0 {
		testing.SetRealm(testing.NewUserRealm(devOpsAddr))
		bar.Transfer(cross, adminAddr, balance)
		testing.SetRealm(adminRealm)
	}
	if balance := bar.BalanceOf(govStakerAddr); balance > 0 {
		testing.SetRealm(testing.NewUserRealm(govStakerAddr))
		bar.Transfer(cross, adminAddr, balance)
		testing.SetRealm(adminRealm)
	}
}

// Output:
// [SCENARIO] Testing protocol fee distribution with different DevOps percentages
//
// [TEST CASE 1] 0% to DevOps (default)
// [INFO] Setting DevOps percentage to 0%
// [INFO] Transferring 1000 bar tokens to protocol_fee
// [INFO] Recording 1000 bar protocol fee
// [INFO] Initial balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] Final balances - protocol_fee: 0 devOps: 0 govStaker: 1000
//
// [TEST CASE 2] 25% to DevOps
// [INFO] Setting DevOps percentage to 25%
// [INFO] Transferring 1000 bar tokens to protocol_fee
// [INFO] Recording 1000 bar protocol fee
// [INFO] Initial balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] Final balances - protocol_fee: 0 devOps: 250 govStaker: 750
//
// [TEST CASE 3] 50% to DevOps
// [INFO] Setting DevOps percentage to 50%
// [INFO] Transferring 1000 bar tokens to protocol_fee
// [INFO] Recording 1000 bar protocol fee
// [INFO] Initial balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] Final balances - protocol_fee: 0 devOps: 500 govStaker: 500
//
// [TEST CASE 4] 100% to DevOps
// [INFO] Setting DevOps percentage to 100%
// [INFO] Transferring 1000 bar tokens to protocol_fee
// [INFO] Recording 1000 bar protocol fee
// [INFO] Initial balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] Final balances - protocol_fee: 0 devOps: 1000 govStaker: 0
//
// [TEST CASE 5] 33.33% to DevOps
// [INFO] Setting DevOps percentage to 33.33%
// [INFO] Transferring 1000 bar tokens to protocol_fee
// [INFO] Recording 1000 bar protocol fee
// [INFO] Initial balances - protocol_fee: 1000 devOps: 0 govStaker: 0
// [INFO] Distributing protocol fees
// [EXPECTED] Final balances - protocol_fee: 0 devOps: 333 govStaker: 667
