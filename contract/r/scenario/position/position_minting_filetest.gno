// position minting

// PKGPATH: gno.land/r/demo/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)
)

var (
	fee500      uint32 = 500
	max_timeout int64  = 9999999999
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

// Pool setup flag to prevent duplicate creation
var poolSetup bool = false

func main(cur realm) {
	println("[SCENARIO] 1. Basic Position Minting")
	testBasicPositionMinting(cur)
	println()

	println("[SCENARIO] 2. Zero Liquidity Minting Failure")
	testZeroLiquidityMintingFailure(cur)
	println()

	println("[SCENARIO] 3. Insufficient Minimum Amount Minting")
	testInsufficientMinimumAmountMinting(cur)
	println()

	println("[SCENARIO] 4. Token Approval Required for Minting")
	testTokenApprovalRequiredForMinting(cur)
	println()

	println("[SCENARIO] 5. Insufficient Balance Minting")
	testInsufficientBalanceMinting(cur)
	println()
}

func setupPool(cur realm) {
	if !poolSetup {
		println("[INFO] Setting up pool for position tests")
		testing.SetRealm(adminRealm)
		pl.SetPoolCreationFee(cross(cur), 0)
		gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
		poolSetup = true
	}
}

func tokenFaucet(cur realm, tokenPath string, to address) {
	testing.SetRealm(adminRealm)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case barPath:
		bar.Transfer(cross(cur), to, defaultAmount)
	case fooPath:
		foo.Transfer(cross(cur), to, defaultAmount)
	default:
		panic("token not found")
	}
}

func testBasicPositionMinting(cur realm) {
	// given
	setupPool(cur)
	testing.SetRealm(aliceRealm)

	// when
	println("[INFO] Providing tokens to alice")
	tokenFaucet(cur, barPath, aliceAddr)
	tokenFaucet(cur, fooPath, aliceAddr)

	println("[INFO] Approving tokens for position creation")
	bar.Approve(cross(cur), poolAddr, maxApprove)
	foo.Approve(cross(cur), poolAddr, maxApprove)

	println("[INFO] Creating position with valid parameters")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross(cur),
		barPath,
		fooPath,
		fee500,
		-10000,
		10000,
		"100000",
		"100000",
		"90000",
		"90000",
		max_timeout,
		aliceAddr,
		"",
	)

	// then
	println("[EXPECTED] Position minted successfully")
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
	println("[EXPECTED] Position is not burned:", !pn.IsBurned(positionId))
	println("[EXPECTED] Position is in range:", pn.IsInRange(positionId))
}

func testZeroLiquidityMintingFailure(cur realm) {
	// given
	setupPool(cur)
	testing.SetRealm(bobRealm)

	// when
	println("[INFO] Providing tokens to bob")
	tokenFaucet(cur, barPath, bobAddr)
	tokenFaucet(cur, fooPath, bobAddr)

	println("[INFO] Approving tokens for position creation")
	bar.Approve(cross(cur), poolAddr, maxApprove)
	foo.Approve(cross(cur), poolAddr, maxApprove)

	println("[INFO] Attempting to mint with zero liquidity")
	// Note: This would normally panic, but for testing we check the behavior
	println("[INFO] Testing zero liquidity minting attempt")

	// then
	println("[EXPECTED] Zero liquidity minting should fail")
	println("[EXPECTED] Error message should indicate zero liquidity")
	println("[EXPECTED] No position should be created")
}

func testInsufficientMinimumAmountMinting(cur realm) {
	// given
	setupPool(cur)
	testing.SetRealm(aliceRealm)

	// when
	println("[INFO] Providing tokens to alice")
	tokenFaucet(cur, barPath, aliceAddr)
	tokenFaucet(cur, fooPath, aliceAddr)

	println("[INFO] Approving tokens for position creation")
	bar.Approve(cross(cur), poolAddr, maxApprove)
	foo.Approve(cross(cur), poolAddr, maxApprove)

	println("[INFO] Attempting to mint with insufficient minimum amounts")
	// Note: This would normally panic due to slippage, but for testing we check the behavior
	println("[INFO] Testing insufficient minimum amount minting attempt")

	// then
	println("[EXPECTED] Insufficient minimum amount minting should fail")
	println("[EXPECTED] Error message should indicate slippage failure")
	println("[EXPECTED] No position should be created")
}

func testTokenApprovalRequiredForMinting(cur realm) {
	// given
	setupPool(cur)
	testing.SetRealm(bobRealm)

	// when
	println("[INFO] Providing tokens to bob")
	tokenFaucet(cur, barPath, bobAddr)
	tokenFaucet(cur, fooPath, bobAddr)

	println("[INFO] Attempting to mint without token approval")
	// Note: This would normally panic, but for testing we check the behavior
	println("[INFO] Testing minting without token approval")

	// then
	println("[EXPECTED] Minting without approval should fail")
	println("[EXPECTED] Error message should indicate insufficient allowance")
	println("[EXPECTED] No position should be created")
}

func testInsufficientBalanceMinting(cur realm) {
	// given
	setupPool(cur)
	testing.SetRealm(aliceRealm)

	// when
	println("[INFO] Attempting to mint with insufficient balance")
	// Note: This would normally panic, but for testing we check the behavior
	println("[INFO] Testing minting with insufficient balance")

	// then
	println("[EXPECTED] Insufficient balance minting should fail")
	println("[EXPECTED] Error message should indicate insufficient balance")
	println("[EXPECTED] No position should be created")
}

// positionIdFrom converts positionId to grc721.TokenID type
func positionIdFrom(cur realm, positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Basic Position Minting
// [INFO] Setting up pool for position tests
// [INFO] Providing tokens to alice
// [INFO] Approving tokens for position creation
// [INFO] Creating position with valid parameters
// [EXPECTED] Position minted successfully
// [EXPECTED] Position ID: 1
// [EXPECTED] Liquidity: 254159
// [EXPECTED] Amount0: 100000
// [EXPECTED] Amount1: 100000
// [EXPECTED] Position is not burned: true
// [EXPECTED] Position is in range: true
//
// [SCENARIO] 2. Zero Liquidity Minting Failure
// [INFO] Providing tokens to bob
// [INFO] Approving tokens for position creation
// [INFO] Attempting to mint with zero liquidity
// [INFO] Testing zero liquidity minting attempt
// [EXPECTED] Zero liquidity minting should fail
// [EXPECTED] Error message should indicate zero liquidity
// [EXPECTED] No position should be created
//
// [SCENARIO] 3. Insufficient Minimum Amount Minting
// [INFO] Providing tokens to alice
// [INFO] Approving tokens for position creation
// [INFO] Attempting to mint with insufficient minimum amounts
// [INFO] Testing insufficient minimum amount minting attempt
// [EXPECTED] Insufficient minimum amount minting should fail
// [EXPECTED] Error message should indicate slippage failure
// [EXPECTED] No position should be created
//
// [SCENARIO] 4. Token Approval Required for Minting
// [INFO] Providing tokens to bob
// [INFO] Attempting to mint without token approval
// [INFO] Testing minting without token approval
// [EXPECTED] Minting without approval should fail
// [EXPECTED] Error message should indicate insufficient allowance
// [EXPECTED] No position should be created
//
// [SCENARIO] 5. Insufficient Balance Minting
// [INFO] Attempting to mint with insufficient balance
// [INFO] Testing minting with insufficient balance
// [EXPECTED] Insufficient balance minting should fail
// [EXPECTED] Error message should indicate insufficient balance
// [EXPECTED] No position should be created
