// swap with referral system

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"chain"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/referral"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoland/wugnot"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	wugnotPath = "gno.land/r/gnoland/wugnot"
	gnsPath    = "gno.land/r/gnoswap/gns"

	maxInt64 int64 = 9223372036854775807
)

var t *testing.T

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Create Pool And Mint Position (WUGNOT:GNS:500)")
	createPool(wugnotPath, gnsPath, 500, 0)
	mintPosition(wugnotPath, gnsPath, 500, -6960, 6960, "100000000", "100000000")
	println()

	// Scenario 3: First swap with referrer
	println("[SCENARIO] 3. First User Swap with Referrer (should register referrer)")
	user1Addr := testutils.TestAddress("user1")
	referrerAddr := testutils.TestAddress("referrer1")
	setupUser(user1Addr)

	testing.SetRealm(testing.NewUserRealm(user1Addr))
	beforeReferral := referral.GetReferral(user1Addr.String())
	ufmt.Printf("[INFO] User1 referral before swap: '%s'\n", beforeReferral)

	swapWithReferrer(user1Addr, referrerAddr.String())

	testing.SetRealm(testing.NewUserRealm(user1Addr))
	afterReferral := referral.GetReferral(user1Addr.String())
	ufmt.Printf("[EXPECTED] User1 referral after first swap: '%s'\n", afterReferral)
	println()

	// Scenario 4: Swap with empty referrer - should DELETE existing referrer
	println("[SCENARIO] 4. Same User Swap with Empty Referrer (should delete existing referrer)")
	swapWithReferrer(user1Addr, "")

	testing.SetRealm(testing.NewUserRealm(user1Addr))
	stillReferral := referral.GetReferral(user1Addr.String())
	ufmt.Printf("[EXPECTED] User1 referral after swap with empty referrer: '%s'\n", stillReferral)
	println()

	// Scenario 5: Register again and try with different referrer
	println("[SCENARIO] 5. Register Referrer Again and Swap with Different Referrer")

	// Register referrer again
	swapWithReferrer(user1Addr, referrerAddr.String())

	testing.SetRealm(testing.NewUserRealm(user1Addr))
	reRegisteredReferral := referral.GetReferral(user1Addr.String())
	ufmt.Printf("[INFO] User1 referral after re-registration: '%s'\n", reRegisteredReferral)

	// Try to change to different referrer (should fail due to rate limit)
	differentReferrer := testutils.TestAddress("referrer2")
	swapWithReferrer(user1Addr, differentReferrer.String())

	testing.SetRealm(testing.NewUserRealm(user1Addr))
	unchangedReferral := referral.GetReferral(user1Addr.String())
	ufmt.Printf("[EXPECTED] User1 referral after swap with different referrer: '%s'\n", unchangedReferral)
	println()

	// Scenario 6: New user with referrer
	println("[SCENARIO] 6. New User Swap with Referrer (should register new referrer)")
	user2Addr := testutils.TestAddress("user2")
	referrer2Addr := testutils.TestAddress("referrer3")
	setupUser(user2Addr)

	testing.SetRealm(testing.NewUserRealm(user2Addr))
	beforeUser2Referral := referral.GetReferral(user2Addr.String())
	ufmt.Printf("[INFO] User2 referral before swap: '%s'\n", beforeUser2Referral)

	swapWithReferrer(user2Addr, referrer2Addr.String())

	testing.SetRealm(testing.NewUserRealm(user2Addr))
	afterUser2Referral := referral.GetReferral(user2Addr.String())
	ufmt.Printf("[EXPECTED] User2 referral after swap: '%s'\n", afterUser2Referral)
	println()

	// Scenario 7: Rate limit expiration - successful re-registration after 24 hours
	println("[SCENARIO] 7. Rate Limit Expiration - Re-registration After 24 Hours")

	// Skip 17280 blocks = 24 hours (5 seconds per block)
	// 24 hours * 60 minutes * 60 seconds / 5 seconds = 17280 blocks
	testing.SkipHeights(17280)
	ufmt.Println("[INFO] Skipped 17280 blocks (24 hours)")

	// Now user1 should be able to register a different referrer
	newReferrerAddr := testutils.TestAddress("referrer4")

	testing.SetRealm(testing.NewUserRealm(user1Addr))
	beforeSkipReferral := referral.GetReferral(user1Addr.String())
	ufmt.Printf("[INFO] User1 referral before re-registration: '%s'\n", beforeSkipReferral)

	swapWithReferrer(user1Addr, newReferrerAddr.String())

	testing.SetRealm(testing.NewUserRealm(user1Addr))
	afterSkipReferral := referral.GetReferral(user1Addr.String())
	ufmt.Printf("[EXPECTED] User1 referral after 24h and re-registration: '%s'\n", afterSkipReferral)
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.IssueCoins(adminAddr, chain.Coins{{"ugnot", 100000000000000}})
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000000000}})
	testing.SetRealm(adminRealm)
	wugnot.Deposit(cross)

	testing.IssueCoins(testing.NewCodeRealm(wugnotPath).Address(), chain.Coins{{"ugnot", 100000000000000}})

	println("[INFO] GNS Balance of admin:", gns.BalanceOf(adminAddr))
	println("[INFO] WUGNOT Balance of admin:", wugnot.BalanceOf(adminAddr))

	gns.Approve(cross, poolAddr, maxInt64)
	wugnot.Approve(cross, poolAddr, maxInt64)

	gns.Approve(cross, routerAddr, maxInt64)
	wugnot.Approve(cross, routerAddr, maxInt64)
}

func setupUser(userAddr address) {
	// Issue GNOT to user
	testing.IssueCoins(userAddr, chain.Coins{{"ugnot", 100000000}})

	// Deposit to get WUGNOT
	testing.SetOriginSend(chain.Coins{{"ugnot", 100000000}})
	testing.SetRealm(testing.NewUserRealm(userAddr))
	wugnot.Deposit(cross)

	// Approve router
	wugnot.Approve(cross, routerAddr, maxInt64)
	gns.Approve(cross, routerAddr, maxInt64)

	ufmt.Printf("[INFO] User %s setup complete - WUGNOT: %d\n", userAddr.String(), wugnot.BalanceOf(userAddr))
}

func createPool(token0Path string, token1Path string, fee uint32, startTick int32) {
	testing.SetRealm(adminRealm)
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(startTick).ToString(),
	)

	ufmt.Printf("[EXPECTED] created %s:%s:%d pool at tick %d\n", token0Path, token1Path, fee, startTick)
}

func mintPosition(token0Path string, token1Path string, fee uint32, minTick, maxTick int32, amount0 string, amount1 string) {
	testing.SetRealm(adminRealm)

	ufmt.Println("[INFO] Minting position")

	testing.SetOriginSend(chain.Coins{})
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee,
		minTick,
		maxTick,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] positionId: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s\n", amount0)
	ufmt.Printf("[EXPECTED] amount1: %s\n", amount1)
}

func swapWithReferrer(userAddr address, referrer string) {
	testing.SetRealm(testing.NewUserRealm(userAddr))

	ufmt.Printf("[INFO] Swapping with referrer: '%s'\n", referrer)

	beforeWUGNOT := wugnot.BalanceOf(userAddr)
	beforeGNS := gns.BalanceOf(userAddr)

	testing.SetOriginSend(chain.Coins{})
	inputAmount, outputAmount := router.ExactInSingleSwapRoute(
		cross,
		wugnotPath,
		gnsPath,
		"1000000",
		"gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500",
		"100",
		"0",
		int64(9999999999),
		referrer, // referrer parameter
	)

	afterWUGNOT := wugnot.BalanceOf(userAddr)
	afterGNS := gns.BalanceOf(userAddr)

	ufmt.Printf("[EXPECTED] inputAmount: %s\n", inputAmount)
	ufmt.Printf("[EXPECTED] outputAmount: %s\n", outputAmount)
	ufmt.Printf("[EXPECTED] WUGNOT balance changed: %d\n", afterWUGNOT-beforeWUGNOT)
	ufmt.Printf("[EXPECTED] GNS balance changed: %d\n", afterGNS-beforeGNS)
}

// Output:
//[SCENARIO] 1. Initialize Setup
//[INFO] GNS Balance of admin: 100000000000000
//[INFO] WUGNOT Balance of admin: 100000000000000
//
//[SCENARIO] 2. Create Pool And Mint Position (WUGNOT:GNS:500)
//[EXPECTED] created gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:500 pool at tick 0
//[INFO] Minting position
//[EXPECTED] positionId: 1
//[EXPECTED] liquidity: 340264708
//[EXPECTED] amount0: 100000000
//[EXPECTED] amount1: 100000000
//
//[SCENARIO] 3. First User Swap with Referrer (should register referrer)
//[INFO] User g1w4ek2u33ta047h6lta047h6lta047h6ldvdwpn setup complete - WUGNOT: 100000000
//[INFO] User1 referral before swap: ''
//[INFO] Swapping with referrer: 'g1wfjkvetjwfjhyv2lta047h6lta047h6lf0xcls'
//[EXPECTED] inputAmount: 1000000
//[EXPECTED] outputAmount: -995078
//[EXPECTED] WUGNOT balance changed: -1000000
//[EXPECTED] GNS balance changed: 995078
//[EXPECTED] User1 referral after first swap: 'g1wfjkvetjwfjhyv2lta047h6lta047h6lf0xcls'
//
//[SCENARIO] 4. Same User Swap with Empty Referrer (should delete existing referrer)
//[INFO] Swapping with referrer: ''
//[EXPECTED] inputAmount: 1000000
//[EXPECTED] outputAmount: -989266
//[EXPECTED] WUGNOT balance changed: -1000000
//[EXPECTED] GNS balance changed: 989266
//[EXPECTED] User1 referral after swap with empty referrer: ''
//
//[SCENARIO] 5. Register Referrer Again and Swap with Different Referrer
//[INFO] Swapping with referrer: 'g1wfjkvetjwfjhyv2lta047h6lta047h6lf0xcls'
//[EXPECTED] inputAmount: 1000000
//[EXPECTED] outputAmount: -983505
//[EXPECTED] WUGNOT balance changed: -1000000
//[EXPECTED] GNS balance changed: 983505
//[INFO] User1 referral after re-registration: ''
//[INFO] Swapping with referrer: 'g1wfjkvetjwfjhyvjlta047h6lta047h6l2tdl74'
//[EXPECTED] inputAmount: 1000000
//[EXPECTED] outputAmount: -977795
//[EXPECTED] WUGNOT balance changed: -1000000
//[EXPECTED] GNS balance changed: 977795
//[EXPECTED] User1 referral after swap with different referrer: ''
//
//[SCENARIO] 6. New User Swap with Referrer (should register new referrer)
//[INFO] User g1w4ek2u3jta047h6lta047h6lta047h6l9huexc setup complete - WUGNOT: 100000000
//[INFO] User2 referral before swap: ''
//[INFO] Swapping with referrer: 'g1wfjkvetjwfjhyv6lta047h6lta047h6ltsn9xk'
//[EXPECTED] inputAmount: 1000000
//[EXPECTED] outputAmount: -972133
//[EXPECTED] WUGNOT balance changed: -1000000
//[EXPECTED] GNS balance changed: 972133
//[EXPECTED] User2 referral after swap: 'g1wfjkvetjwfjhyv6lta047h6lta047h6ltsn9xk'
//
//[SCENARIO] 7. Rate Limit Expiration - Re-registration After 24 Hours
//[INFO] Skipped 17280 blocks (24 hours)
//[INFO] User1 referral before re-registration: ''
//[INFO] Swapping with referrer: 'g1wfjkvetjwfjhydzlta047h6lta047h6lk48j6m'
//[EXPECTED] inputAmount: 1000000
//[EXPECTED] outputAmount: -966521
//[EXPECTED] WUGNOT balance changed: -1000000
//[EXPECTED] GNS balance changed: 966521
//[EXPECTED] User1 referral after 24h and re-registration: 'g1wfjkvetjwfjhydzlta047h6lta047h6lk48j6m'
//
