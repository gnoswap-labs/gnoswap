// Test partial collection with multiple undelegations at different times

package main

import (
	"math"
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/protocol_fee"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	_ "gno.land/r/gnoswap/test_token/atom"
	_ "gno.land/r/gnoswap/test_token/btc"
)

var (
	admin, _   = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(admin)

	poolAddr, _      = access.GetAddress(prbac.ROLE_POOL.String())
	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"

	delegateeAddr = testutils.TestAddress("delegatee1")

	minAmount = int64(1_000_000)
)

func main() {
	println("[SCENARIO] 1. Setup - Transfer GNS to alice")
	setupGNS()
	println()

	println("[SCENARIO] 2. Alice delegates to delegatee")
	delegateToDelegatee()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 3. Create pool by protocol fee")
	createPoolByProtocolFee()
	testing.SkipHeights(1)
	println()

	println("[SCENARIO] 4. Check and collect claimable reward for alice")
	getClaimableRewardByAddress(aliceAddr)
	println()

	println("[SCENARIO] 5. Collect reward for alice")
	collectReward(aliceAddr)
	println()
}

func setupGNS() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, aliceAddr, 1_000_000_000)
	ufmt.Println("[INFO] Transferred 1,000,000,000 GNS to alice")
}

func delegateToDelegatee() {
	testing.SetRealm(aliceRealm)
	gns.Approve(cross, govStakerAddr, minAmount)
	staker.Delegate(cross, delegateeAddr, minAmount, "")
	ufmt.Printf("[INFO] Alice delegated %d GNS to delegatee\n", minAmount)
}

func createPoolByProtocolFee() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, math.MaxInt64)
	pool.CreatePool(cross, atomPath, btcPath, 3000, common.TickMathGetSqrtRatioAtTick(0).ToString())
	ufmt.Printf("[INFO] Created %s:%s:%d pool\n", atomPath, btcPath, 3000)
}

func getClaimableRewardByAddress(addr address) {
	// alice has not authorized to protocol fee distribution
	// testing.SetRealm(aliceRealm)

	// admin can get claimable reward
	testing.SetRealm(adminRealm)
	emission.MintAndDistributeGns(cross)
	protocol_fee.DistributeProtocolFee(cross)

	previousGovStakerGNSBalance := gns.BalanceOf(govStakerAddr)

	reward, protocolFees, err := staker.GetClaimableRewardByAddress(addr)
	if err != nil {
		panic(err)
	}

	afterGovStakerGNSBalance := gns.BalanceOf(govStakerAddr)

	ufmt.Printf("[EXPECTED] claimable reward: emissionReward=%d\n", reward)

	if len(protocolFees) > 0 {
		for tokenPath, amount := range protocolFees {
			ufmt.Printf("[EXPECTED] claimable protocol fee: %s: %d\n", tokenPath, amount)
		}
	} else {
		ufmt.Printf("[EXPECTED] claimable protocol fee: none\n")
	}

	ufmt.Printf("[EXPECTED] collected gov staker GNS balance: %d\n", afterGovStakerGNSBalance-previousGovStakerGNSBalance)
}

func collectReward(addr address) {
	testing.SetRealm(aliceRealm)
	previousGNSBalance := gns.BalanceOf(addr)
	staker.CollectReward(cross)
	afterGNSBalance := gns.BalanceOf(addr)
	ufmt.Printf("[EXPECTED] collected GNS balance of %s: %d\n", addr, afterGNSBalance-previousGNSBalance)
}

// Output:
// [SCENARIO] 1. Setup - Transfer GNS to alice
// [INFO] Transferred 1,000,000,000 GNS to alice
//
// [SCENARIO] 2. Alice delegates to delegatee
// [INFO] Alice delegated 1000000 GNS to delegatee
//
// [SCENARIO] 3. Create pool by protocol fee
// [INFO] Created gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:3000 pool
//
// [SCENARIO] 4. Check and collect claimable reward for alice
// [EXPECTED] claimable reward: emissionReward=0
// [EXPECTED] claimable protocol fee: gno.land/r/gnoswap/gns: 100000000
// [EXPECTED] collected gov staker GNS balance: 0
//
// [SCENARIO] 5. Collect reward for alice
// [EXPECTED] collected GNS balance of g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh: 100000000
