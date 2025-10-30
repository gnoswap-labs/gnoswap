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
	"gno.land/r/onbloc/qux"
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
)

func main() {
	println("[SCENARIO] 1. Setup: Transfer tokens to protocol fee")
	setupTokens()
	println()

	println("[SCENARIO] 2. Record protocol fees")
	recordProtocolFees()
	println()

	println("[SCENARIO] 3. Distribute protocol fees")
	distributeProtocolFees()
	println()
}

func setupTokens() {
	testing.SetRealm(adminRealm)

	println("[INFO] Transferring bar tokens to protocol_fee")
	bar.Transfer(cross, protocolFeeAddr, 1000)

	println("[INFO] Transferring qux tokens to protocol_fee")
	qux.Transfer(cross, protocolFeeAddr, 1000)

	println("[EXPECTED] Bar balance of protocol_fee:",
		bar.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Qux balance of protocol_fee:",
		qux.BalanceOf(protocolFeeAddr))
}

func recordProtocolFees() {
	testing.SetRealm(stakerRealm)

	println("[INFO] Recording bar protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)

	println("[INFO] Recording qux protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/qux", 1000)
}

func distributeProtocolFees() {
	testing.SetRealm(govStakerRealm)

	println("[INFO] Distributing protocol fees")
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] Bar balance of protocol_fee after distribution:", bar.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Bar balance of govStaker after distribution:", bar.BalanceOf(govStakerAddr))
	println("[EXPECTED] Qux balance of protocol_fee after distribution:", qux.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Qux balance of govStaker after distribution:", qux.BalanceOf(govStakerAddr))
}

// Output:
// [SCENARIO] 1. Setup: Transfer tokens to protocol fee
// [INFO] Transferring bar tokens to protocol_fee
// [INFO] Transferring qux tokens to protocol_fee
// [EXPECTED] Bar balance of protocol_fee: 1000
// [EXPECTED] Qux balance of protocol_fee: 1000
//
// [SCENARIO] 2. Record protocol fees
// [INFO] Recording bar protocol fee
// [INFO] Recording qux protocol fee
//
// [SCENARIO] 3. Distribute protocol fees
// [INFO] Distributing protocol fees
// [EXPECTED] Bar balance of protocol_fee after distribution: 0
// [EXPECTED] Bar balance of govStaker after distribution: 1000
// [EXPECTED] Qux balance of protocol_fee after distribution: 0
// [EXPECTED] Qux balance of govStaker after distribution: 1000
