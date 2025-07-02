package main

import (
	"std"
	"testing"

	"gno.land/p/demo/json"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gns"
)

// Constants for fee tiers
const (
	fee500 uint32 = 500
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

var (
	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = "100000000"

	poolCreationFee = int64(100_000_000)
)

// 1. Create Foo:Bar Pool
func main() {
	// call gns faucet to get creation fee
	testing.SetRealm(adminRealm)

	println("[INFO] Create Foo:Bar Pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000
	testing.SkipHeights(1)

	println("[INFO] Create Bar:Baz Pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, bazPath, fee500, "130621891405341611593710811006")
	testing.SkipHeights(1)

	println("[SCENARIO] 1. Mint Foo:Bar Liquidity by admin")
	TestMintFooBarLiquidity()

	println("[SCENARIO] 2. Mint Bar:Baz Liquidity by admin")
	TestMintBarBazLiquidity()

	println("[SCENARIO] 3. Get Pools")
	TestApiGetPools()

	println("[INFO] Passed all tests")
}

// 3. Mint Foo:Bar Liquidity by admin
func TestMintFooBarLiquidity() {
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)
	testing.SkipHeights(4)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		positionAddr,
		-11000,
		-9000,
		liquidityExpect,
		adminAddr,
	)
	println("[EXPECTED] amount0:", amount0, "expected: should be 8040316")
	println("[EXPECTED] amount1:", amount1, "expected: should be 2958015")
	println()
	testing.SkipHeights(1)
}

// 4. Mint Bar:Baz Liquidity by admin
func TestMintBarBazLiquidity() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)
	testing.SkipHeights(2)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		barPath,
		bazPath,
		fee500,
		positionAddr,
		tickLower,
		tickUpper,
		liquidityExpect,
		adminAddr,
	)
	println("[EXPECTED] amount0:", amount0, "expected: should be 2958015")
	println("[EXPECTED] amount1:", amount1, "expected: should be 8040316")
	println()
	testing.SkipHeights(1)
}

// GETTER_API TEST
func TestApiGetPools() {
	gpls := pool.ApiGetPools()

	root, err := json.Unmarshal([]byte(gpls))
	if err != nil {
		panic(err.Error())
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err.Error())
	}

	println("[EXPECTED] response.Size():", response.Size(), "expected: should be 2")
	println()
}

// Output:
// [INFO] Create Foo:Bar Pool
// [INFO] Create Bar:Baz Pool
// [SCENARIO] 1. Mint Foo:Bar Liquidity by admin
// [EXPECTED] amount0: 8040316 expected: should be 8040316
// [EXPECTED] amount1: 2958015 expected: should be 2958015
//
// [SCENARIO] 2. Mint Bar:Baz Liquidity by admin
// [EXPECTED] amount0: 2958015 expected: should be 2958015
// [EXPECTED] amount1: 8040316 expected: should be 8040316
//
// [SCENARIO] 3. Get Pools
// [EXPECTED] response.Size(): 2 expected: should be 2
//
// [INFO] Passed all tests
