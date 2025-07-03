// basic position management

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	poolAddr     = consts.POOL_ADDR
	positionAddr = consts.POSITION_ADDR

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = std.NewUserRealm(bobAddr)
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

func main() {
	println("[SCENARIO] 1. Initialize Pool and Create Position")
	initializePoolAndCreatePosition()
	println()

	println("[SCENARIO] 2. Position Creation and Retrieval")
	testPositionCreationAndRetrieval()
	println()

	println("[SCENARIO] 3. Position Modification")
	testPositionModification()
	println()

	println("[SCENARIO] 4. Position Deletion")
	testPositionDeletion()
	println()
}

func setupPool() {
	if !poolSetup {
		println("[INFO] Setting up pool for position tests")
		testing.SetRealm(adminRealm)
		pl.SetPoolCreationFeeByAdmin(cross, 0)
		gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
		pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
		poolSetup = true
	}
}

func tokenFaucet(tokenPath string, to std.Address) {
	testing.SetRealm(adminRealm)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case barPath:
		bar.Transfer(cross, to, defaultAmount)
	case fooPath:
		foo.Transfer(cross, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func initializePoolAndCreatePosition() {
	// given
	setupPool()
	testing.SetRealm(aliceRealm)

	// when
	println("[INFO] Providing tokens to alice")
	tokenFaucet(barPath, aliceAddr)
	tokenFaucet(fooPath, aliceAddr)

	println("[INFO] Approving tokens for position creation")
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	println("[INFO] Creating initial position")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-10000,
		10000,
		"100000",
		"100000",
		"0",
		"0",
		max_timeout,
		aliceAddr,
		aliceAddr,
		"",
	)

	// then
	println("[EXPECTED] Pool initialized successfully")
	println("[EXPECTED] Initial position created with ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
}

func testPositionCreationAndRetrieval() {
	// given
	setupPool()
	testing.SetRealm(bobRealm)

	// when
	println("[INFO] Providing tokens to bob")
	tokenFaucet(barPath, bobAddr)
	tokenFaucet(fooPath, bobAddr)

	println("[INFO] Approving tokens for bob")
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	println("[INFO] Creating a new position for retrieval test")
	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-5000,
		5000,
		"50000",
		"50000",
		"45000",
		"45000",
		max_timeout,
		bobAddr,
		bobAddr,
		"",
	)

	println("[INFO] Retrieving position details")
	poolKey := pn.PositionGetPositionPoolKey(positionId)
	tickLower := pn.PositionGetPositionTickLower(positionId)
	tickUpper := pn.PositionGetPositionTickUpper(positionId)
	positionLiquidity := pn.PositionGetPositionLiquidity(positionId)
	operator := pn.PositionGetPositionOperator(positionId)

	// then
	println("[EXPECTED] Position created successfully with ID:", positionId)
	println("[EXPECTED] Position pool key:", poolKey)
	println("[EXPECTED] Position tick lower:", tickLower)
	println("[EXPECTED] Position tick upper:", tickUpper)
	println("[EXPECTED] Position liquidity:", positionLiquidity.ToString())
	println("[EXPECTED] Position operator:", operator)
	println("[EXPECTED] Position is not burned:", !pn.PositionGetPositionIsBurned(positionId))
	println("[EXPECTED] Position is in range:", pn.PositionIsInRange(positionId))
}

func testPositionModification() {
	// given
	setupPool()
	testing.SetRealm(aliceRealm)

	// when
	println("[INFO] Creating position for modification test")
	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-8000,
		8000,
		"30000",
		"30000",
		"27000",
		"27000",
		max_timeout,
		aliceAddr,
		aliceAddr,
		"",
	)

	println("[INFO] Increasing liquidity to modify position")
	_, newLiquidity, amount0, amount1, _ := pn.IncreaseLiquidity(
		cross,
		positionId,
		"20000",
		"20000",
		"18000",
		"18000",
		max_timeout,
	)

	println("[INFO] Retrieving modified position details")
	modifiedLiquidity := pn.PositionGetPositionLiquidity(positionId)
	tokensOwed0 := pn.PositionGetPositionTokensOwed0(positionId)
	tokensOwed1 := pn.PositionGetPositionTokensOwed1(positionId)

	// then
	println("[EXPECTED] Position modified successfully")
	println("[EXPECTED] Original position ID:", positionId)
	println("[EXPECTED] New liquidity added:", newLiquidity)
	println("[EXPECTED] Total liquidity after modification:", modifiedLiquidity.ToString())
	println("[EXPECTED] Additional amount0:", amount0)
	println("[EXPECTED] Additional amount1:", amount1)
	println("[EXPECTED] Tokens owed 0:", tokensOwed0.ToString())
	println("[EXPECTED] Tokens owed 1:", tokensOwed1.ToString())
}

func testPositionDeletion() {
	// given
	setupPool()
	testing.SetRealm(aliceRealm)

	// when
	println("[INFO] Creating position for deletion test")
	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-3000,
		3000,
		"10000",
		"10000",
		"9000",
		"9000",
		max_timeout,
		aliceAddr,
		aliceAddr,
		"",
	)

	println("[INFO] Verifying position exists before deletion")
	existsBefore := pn.PositionGetPositionIsBurned(positionId)

	// need to add gnft approve
	// by doing this, we can manage position
	gnft.Approve(cross, positionAddr, positionIdFrom(positionId))

	testing.SetRealm(aliceRealm)
	println("[INFO] Burning position (deleting)")
	_, _, fee0, fee1, amount0, amount1, _ := pn.DecreaseLiquidity(
		cross,
		positionId,
		"100", // Remove all liquidity
		"0",
		"0",
		max_timeout,
		false,
	)

	println("[INFO] Verifying position is burned after deletion")
	existsAfter := pn.PositionGetPositionIsBurned(positionId)

	// then
	println("[EXPECTED] Position existed before deletion:", !existsBefore)
	println("[EXPECTED] Position burned after deletion:", existsAfter)
	println("[EXPECTED] Collected fee0:", fee0)
	println("[EXPECTED] Collected fee1:", fee1)
	println("[EXPECTED] Collected amount0:", amount0)
	println("[EXPECTED] Collected amount1:", amount1)
}

// positionIdFrom converts positionId to grc721.TokenID type
func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Initialize Pool and Create Position
// [INFO] Setting up pool for position tests
// [INFO] Providing tokens to alice
// [INFO] Approving tokens for position creation
// [INFO] Creating initial position
// [EXPECTED] Pool initialized successfully
// [EXPECTED] Initial position created with ID: 1
// [EXPECTED] Liquidity: 254159
// [EXPECTED] Amount0: 100000
// [EXPECTED] Amount1: 100000
//
// [SCENARIO] 2. Position Creation and Retrieval
// [INFO] Providing tokens to bob
// [INFO] Approving tokens for bob
// [INFO] Creating a new position for retrieval test
// [INFO] Retrieving position details
// [EXPECTED] Position created successfully with ID: 2
// [EXPECTED] Position pool key: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Position tick lower: -5000
// [EXPECTED] Position tick upper: 5000
// [EXPECTED] Position liquidity: 226050
// [EXPECTED] Position operator: g100000000000000000000000000000000dnmcnx
// [EXPECTED] Position is not burned: true
// [EXPECTED] Position is in range: true
//
// [SCENARIO] 3. Position Modification
// [INFO] Creating position for modification test
// [INFO] Increasing liquidity to modify position
// [INFO] Retrieving modified position details
// [EXPECTED] Position modified successfully
// [EXPECTED] Original position ID: 3
// [EXPECTED] New liquidity added: 60667
// [EXPECTED] Total liquidity after modification: 151668
// [EXPECTED] Additional amount0: 20000
// [EXPECTED] Additional amount1: 20000
// [EXPECTED] Tokens owed 0: 0
// [EXPECTED] Tokens owed 1: 0
//
// [SCENARIO] 4. Position Deletion
// [INFO] Creating position for deletion test
// [INFO] Verifying position exists before deletion
// [INFO] Burning position (deleting)
// [INFO] Verifying position is burned after deletion
// [EXPECTED] Position existed before deletion: true
// [EXPECTED] Position burned after deletion: false
// [EXPECTED] Collected fee0: 0
// [EXPECTED] Collected fee1: 0
// [EXPECTED] Collected amount0: 13
// [EXPECTED] Collected amount1: 13
