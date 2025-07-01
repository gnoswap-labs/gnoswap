// launchpad protocol fee reward scenario

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/gov/staker"
	lp "gno.land/r/gnoswap/v1/launchpad"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	admin        = consts.ADMIN
	adminRealm   = std.NewUserRealm(admin)
	bobAddr      = testutils.TestAddress("bob")
	bobRealm     = std.NewUserRealm(bobAddr)
	projectAddr  = testutils.TestAddress("projectAddr")
	projectRealm = std.NewUserRealm(projectAddr)
	stakerRealm  = std.NewUserRealm(consts.STAKER_ADDR)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func main() {
	println("[SCENARIO] 1. Mock protocol fee deposit (bar, qux)")
	mockProtocolFeeDeposit()
	println()

	println("[SCENARIO] 2. Skip blocks and distribute protocol fee")
	skipBlocksAndDistribute()
	println()

	println("[SCENARIO] 3. Check and collect protocol fee reward for bob")
	protocolFeeRewardBob()
	println()

	println("[SCENARIO] 4. Check and collect protocol fee reward for project recipient")
	protocolFeeRewardProjectRecipient()
	println()
}

func mockProtocolFeeDeposit() {
	// mock protocol fee deposit (bar, qux)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 1000)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)
	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)
	ufmt.Printf("[INFO] protocol fee deposited: bar(1000), qux(2500)\n")
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	ufmt.Printf("[INFO] skipped 10 blocks\n")
}

func protocolFeeRewardBob() {
	gcr := staker.GetClaimableRewardByAddress(bobAddr)
	ufmt.Printf("[INFO] claimable reward (bob): %s\n", gcr)
	testing.SetRealm(bobRealm)
	staker.CollectReward(cross)
	ufmt.Printf("[INFO] collected protocol fee reward for bob\n")
}

func protocolFeeRewardProjectRecipient() {
	gcr := staker.GetClaimableRewardByAddress(projectAddr)
	ufmt.Printf("[INFO] claimable reward (project recipient): %s\n", gcr)
	testing.SetRealm(projectRealm)
	lp.CollectProtocolFee(cross)
	ufmt.Printf("[INFO] collected protocol fee reward for project recipient\n")
}
