package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/router"
	"gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	user1Addr = testutils.TestAddress("user1")
	user2Addr = testutils.TestAddress("user2")

	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())
	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)

	customRouter1Addr = testutils.TestAddress("custom_router1")
	customRouter2Addr = testutils.TestAddress("custom_router2")

	token0Path = "gno.land/r/onbloc/bar"
	token1Path = "gno.land/r/onbloc/foo"

	max_timeout int64 = 9999999999

	maxApprove int64 = 9223372036854775806
)

var t *testing.T

const (
	FEE_MEDIUM uint32 = 3000
)

func main() {
	println("[SCENARIO] Router Whitelist Test")
	println("[INFO] Testing router whitelist functionality: Adding/removing routers and swap access control")
	println()

	// Setup: Create pool and add initial liquidity
	initPool()

	// Test 1: Official router can swap
	testOfficialRouterSwap()

	// Test 2: Non-whitelisted router cannot swap
	testNonWhitelistedRouterFails()

	// Test 3: Add custom router to whitelist
	testAddCustomRouterToWhitelist()

	// // Test 4: Whitelisted custom router can swap
	testWhitelistedCustomRouterSwap()

	// Test 5: Remove custom router from whitelist
	testRemoveCustomRouterFromWhitelist()

	// Test 6: Removed router cannot swap anymore
	testRemovedRouterFails()

	// Test 7: List all whitelisted routers
	testListWhitelistedRouters()

	// println("[RESULT] All router whitelist tests completed successfully!")
}

func initPool() {
	println("[SCENARIO] 1. Setting up pool and initial liquidity")
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	defaultTokenAmount := int64(100000000)

	ufmt.Println("[INFO] Distributing Bar tokens")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Foo tokens")
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, stakerAddr, maxApprove)
	foo.Approve(cross, stakerAddr, maxApprove)

	ufmt.Printf("[INFO] Creating %s:%s:%d pool (tick: %d)\n", token0Path, token1Path, FEE_MEDIUM, 0)
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		FEE_MEDIUM,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	// Setup internal incentive pool
	poolPath := pool.GetPoolPath(token0Path, token1Path, FEE_MEDIUM)
	testing.SetRealm(adminRealm)
	staker.SetPoolTierByAdmin(cross, poolPath, 1)
}

func testOfficialRouterSwap() {
	println("[SCENARIO] 2. Testing official router swap")

	// Mint tokens to user1
	testing.SetRealm(adminRealm)
	bar.Approve(cross, user1Addr, 10000)

	// User1 approves router
	testing.SetRealm(std.NewUserRealm(user1Addr))
	bar.Approve(cross, routerAddr, maxApprove)

	// Execute swap through official router
	inputAmount := "100"
	inputToken, outputToken := router.ExactInSwapRoute(
		cross,
		token0Path,
		token1Path,
		inputAmount,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
		"100",
		"0",
		max_timeout,
		"",
	)

	println("[EXPECTED] Official router swap successful")
	println("[INFO] Input:", inputToken, "BAR")
	println("[INFO] Output:", outputToken, "FOO")
	println()
}

func testNonWhitelistedRouterFails() {
	println("[SCENARIO] 3. Testing non-whitelisted router fails")

	// Try to call pool directly from a non-whitelisted address
	testing.SetRealm(std.NewUserRealm(user2Addr))

	expectedPanicMsg := ufmt.Sprintf("unauthorized: caller %s is not a whitelisted router", user2Addr.String())
	uassert.AbortsWithMessage(t, expectedPanicMsg, func() {
		pool.Swap(cross, token0Path, token1Path, FEE_MEDIUM, user2Addr, true, "100", "4295128740", user2Addr)
	})

	println("[EXPECTED] Non-whitelisted router correctly rejected")
	println("[INFO] Panic message:", expectedPanicMsg)
	println()
}

func testAddCustomRouterToWhitelist() {
	println("[SCENARIO] 4. Adding custom router to whitelist")

	// Admin adds custom router to whitelist
	testing.SetRealm(adminRealm)

	access.AddRouter(cross, customRouter1Addr)
	println("[EXPECTED] Custom router added to whitelist:", customRouter1Addr)

	isWhitelisted := access.IsRouterWhitelisted(customRouter1Addr)
	uassert.True(t, isWhitelisted, "Expected custom router to be whitelisted")

	println("[EXPECTED] Router is whitelisted")
	println()
}

func testWhitelistedCustomRouterSwap() {
	println("[SCENARIO] 5. Testing whitelisted custom router swap")

	// Mint tokens to user2
	testing.SetRealm(adminRealm)
	bar.Approve(cross, user2Addr, 10000)

	// User2 approves custom router
	testing.SetRealm(std.NewUserRealm(user2Addr))
	bar.Approve(cross, customRouter1Addr, maxApprove)

	// Custom router transfers tokens from user
	testing.SetRealm(std.NewUserRealm(customRouter1Addr))
	balance := bar.BalanceOf(user2Addr)
	println("[INFO] Balance of user2:", balance)
	bar.TransferFrom(cross, user2Addr, customRouter1Addr, balance)
	bar.Approve(cross, poolAddr, maxApprove)

	// Execute swap through custom router
	amount0, amount1 := pool.Swap(cross, token0Path, token1Path, FEE_MEDIUM, user2Addr, true, "100", "4295128740", customRouter1Addr)

	println("[EXPECTED] Whitelisted custom router swap successful")
	println("[INFO] Amount0:", amount0)
	println("[INFO] Amount1:", amount1)
	println()
}

func testRemoveCustomRouterFromWhitelist() {
	println("[SCENARIO] 6. Removing custom router from whitelist")

	// Admin removes custom router from whitelist
	testing.SetRealm(adminRealm)

	access.RemoveRouter(cross, customRouter1Addr)
	println("[EXPECTED] Custom router removed from whitelist:", customRouter1Addr)

	// Verify it's not whitelisted anymore
	isWhitelisted := access.IsRouterWhitelisted(customRouter1Addr)
	uassert.False(t, isWhitelisted, "Expected custom router to be removed from whitelist")
	println("[EXPECTED] Router is no longer whitelisted")
	println()
}

func testRemovedRouterFails() {
	println("[SCENARIO] 7. Testing removed router fails")

	// Try to call pool from removed router
	testing.SetRealm(std.NewUserRealm(customRouter1Addr))

	// This should panic
	expectedPanicMsg := ufmt.Sprintf("unauthorized: caller %s is not a whitelisted router", customRouter1Addr.String())
	uassert.AbortsWithMessage(t, expectedPanicMsg, func() {
		pool.Swap(cross, token0Path, token1Path, FEE_MEDIUM, user2Addr, true, "100", "4295128740", user2Addr)
	})
	println("[EXPECTED] Removed router correctly rejected")
	println("[INFO] Panic message:", expectedPanicMsg)
	println()
}

func testListWhitelistedRouters() {
	println("[SCENARIO] 8. Listing all whitelisted routers")

	// Add another custom router for testing
	testing.SetRealm(adminRealm)
	access.AddRouter(cross, customRouter2Addr)

	// Get all whitelisted routers
	routers := access.GetWhitelistedRouters()

	println("[EXPECTED] Total whitelisted routers:", len(routers))
	for i, router := range routers {
		println("[INFO] Router", i+1, ":", router)
	}

	// Verify official router is always included
	foundOfficial := false
	for _, router := range routers {
		if router == routerAddr {
			foundOfficial = true
			break
		}
	}

	if !foundOfficial {
		panic("Expected official router to be in whitelist")
	}
	println("[EXPECTED] Official router is included in whitelist")
	println()
}

// Output:
// [SCENARIO] Router Whitelist Test
// [INFO] Testing router whitelist functionality: Adding/removing routers and swap access control
//
// [SCENARIO] 1. Setting up pool and initial liquidity
// [INFO] Distributing Bar tokens
// [INFO] Distributing Foo tokens
// [INFO] Creating gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000 pool (tick: 0)
// [SCENARIO] 2. Testing official router swap
// [EXPECTED] Official router swap successful
// [INFO] Input: 0 BAR
// [INFO] Output: 0 FOO
//
// [SCENARIO] 3. Testing non-whitelisted router fails
// [EXPECTED] Non-whitelisted router correctly rejected
// [INFO] Panic message: unauthorized: caller g1w4ek2u3jta047h6lta047h6lta047h6l9huexc is not a whitelisted router
//
// [SCENARIO] 4. Adding custom router to whitelist
// [EXPECTED] Custom router added to whitelist: g1vd6hxar0d40hymm4w3jhyv2lta047h6lh4k3sw
// [EXPECTED] Router is whitelisted
//
// [SCENARIO] 5. Testing whitelisted custom router swap
// [INFO] Balance of user2: 0
// [EXPECTED] Whitelisted custom router swap successful
// [INFO] Amount0: 0
// [INFO] Amount1: 0
//
// [SCENARIO] 6. Removing custom router from whitelist
// [EXPECTED] Custom router removed from whitelist: g1vd6hxar0d40hymm4w3jhyv2lta047h6lh4k3sw
// [EXPECTED] Router is no longer whitelisted
//
// [SCENARIO] 7. Testing removed router fails
// [EXPECTED] Removed router correctly rejected
// [INFO] Panic message: unauthorized: caller g1vd6hxar0d40hymm4w3jhyv2lta047h6lh4k3sw is not a whitelisted router
//
// [SCENARIO] 8. Listing all whitelisted routers
// [EXPECTED] Total whitelisted routers: 2
// [INFO] Router 1 : g1lm2l7tf49h3mykesct7rhfml30yx8dw5xrval7
// [INFO] Router 2 : g1vd6hxar0d40hymm4w3jhyvjlta047h6lrwjypr
// [EXPECTED] Official router is included in whitelist
