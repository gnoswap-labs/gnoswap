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
	"gno.land/r/gnoswap/test_token/sol"
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

func fundAndApproveSolFromStaker(amount int64) {
	testing.SetRealm(adminRealm)
	sol.Transfer(cross, stakerRealm.Address(), amount)
	testing.SetRealm(stakerRealm)
	sol.Approve(cross, protocolFeeAddr, amount)
	sol.Approve(cross, protocolFeeV1Realm.Address(), amount)
}

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
	println("[INFO] Funding and approving atom tokens from staker")
	fundAndApproveAtomFromStaker(1000)

	println("[INFO] Funding and approving sol tokens from staker")
	fundAndApproveSolFromStaker(1000)

	println("[EXPECTED] Atom balance of protocol_fee:", atom.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Sol balance of protocol_fee:", sol.BalanceOf(protocolFeeAddr))
}

func recordProtocolFees() {
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, 1000)
	sol.Approve(cross, protocolFeeAddr, 1000)

	println("[INFO] Recording atom protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/atom", 1000)

	println("[INFO] Recording sol protocol fee")
	pf.AddToProtocolFee(cross, "gno.land/r/gnoswap/test_token/sol", 1000)
}

func distributeProtocolFees() {
	testing.SetRealm(govStakerRealm)

	println("[INFO] Distributing protocol fees")
	pf.DistributeProtocolFee(cross)

	println("[EXPECTED] Atom balance of protocol_fee after distribution:", atom.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Atom balance of govStaker after distribution:", atom.BalanceOf(govStakerAddr))
	println("[EXPECTED] Sol balance of protocol_fee after distribution:", sol.BalanceOf(protocolFeeAddr))
	println("[EXPECTED] Sol balance of govStaker after distribution:", sol.BalanceOf(govStakerAddr))
}

// Output:
// [SCENARIO] 1. Setup: Transfer tokens to protocol fee
// [INFO] Funding and approving atom tokens from staker
// [INFO] Funding and approving sol tokens from staker
// [EXPECTED] Atom balance of protocol_fee: 0
// [EXPECTED] Sol balance of protocol_fee: 0
//
// [SCENARIO] 2. Record protocol fees
// [INFO] Recording atom protocol fee
// [INFO] Recording sol protocol fee
//
// [SCENARIO] 3. Distribute protocol fees
// [INFO] Distributing protocol fees
// [EXPECTED] Atom balance of protocol_fee after distribution: 0
// [EXPECTED] Atom balance of govStaker after distribution: 1000
// [EXPECTED] Sol balance of protocol_fee after distribution: 0
// [EXPECTED] Sol balance of govStaker after distribution: 1000
