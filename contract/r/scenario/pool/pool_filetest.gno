// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"
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
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

var (
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
)

var (
	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = "100000000"

	poolCreationFee = int64(100_000_000)
)

// 1. Create Btc:Atom Pool
func main() {
	// call gns faucet to get creation fee
	testing.SetRealm(adminRealm)

	println("[INFO] Create Btc:Atom Pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atomPath, btcPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000
	testing.SkipHeights(1)

	println("[INFO] Create Atom:Atone Pool")
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atomPath, atonePath, fee500, "130621891405341611593710811006")
	testing.SkipHeights(1)

	println("[SCENARIO] 1. Mint Btc:Atom Liquidity by admin")
	TestMintBtcAtomLiquidity()

	println("[SCENARIO] 2. Mint Atom:Atone Liquidity by admin")
	TestMintAtomAtoneLiquidity()

	println("[INFO] Passed all tests")
}

// 3. Mint Btc:Atom Liquidity by admin
func TestMintBtcAtomLiquidity() {
	testing.SetRealm(adminRealm)
	btc.Approve(cross, poolAddr, maxApprove)
	atom.Approve(cross, poolAddr, maxApprove)
	testing.SkipHeights(4)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		atomPath,
		btcPath,
		fee500,
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

// 4. Mint Atom:Atone Liquidity by admin
func TestMintAtomAtoneLiquidity() {
	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, maxApprove)
	atone.Approve(cross, poolAddr, maxApprove)
	testing.SkipHeights(2)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		atomPath,
		atonePath,
		fee500,
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

// Output:
// [INFO] Create Btc:Atom Pool
// [INFO] Create Atom:Atone Pool
// [SCENARIO] 1. Mint Btc:Atom Liquidity by admin
// [EXPECTED] amount0: 8040316 expected: should be 8040316
// [EXPECTED] amount1: 2958015 expected: should be 2958015
//
// [SCENARIO] 2. Mint Atom:Atone Liquidity by admin
// [EXPECTED] amount0: 2958015 expected: should be 2958015
// [EXPECTED] amount1: 8040316 expected: should be 8040316
//
// [INFO] Passed all tests
