// dao contract position lifecycle

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807
	MIN_PRICE string = "4295128740"
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	originAddr  = testutils.TestAddress("dao-origin")
	originRealm = testing.NewUserRealm(originAddr)

	daoPath  = "gno.land/r/onbloc/dao"
	daoRealm = testing.NewCodeRealm(daoPath)
	daoAddr  = daoRealm.Address()

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(3000)

	positionID uint64
)

func main() {
	ufmt.Println("[SCENARIO] 1. Setup pool and fund DAO contract")
	setupPoolAndFundDao()
	println()

	ufmt.Println("[SCENARIO] 2. DAO contract mints a position")
	daoMintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Verify DAO contract owns the position")
	verifyDaoOwnership()
	println()

	ufmt.Println("[SCENARIO] 4. Generate fees through swaps")
	generateFees()
	println()

	ufmt.Println("[SCENARIO] 5. DAO contract collects fees")
	daoCollectFees()
	println()

	ufmt.Println("[SCENARIO] 6. DAO contract increases liquidity")
	daoIncreaseLiquidity()
	println()

	ufmt.Println("[SCENARIO] 7. DAO contract decreases all liquidity")
	daoDecreaseAllLiquidity()
	println()
}

func setupPoolAndFundDao() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	bar.Transfer(cross, daoAddr, 150000000)
	foo.Transfer(cross, daoAddr, 150000000)

	ufmt.Printf("[EXPECTED] DAO bar balance after funding: %d\n", bar.BalanceOf(daoAddr))
	ufmt.Printf("[EXPECTED] DAO foo balance after funding: %d\n", foo.BalanceOf(daoAddr))
}

func daoMintPosition() {
	testing.SetRealm(daoRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var liquidity string
	func(cur realm) {
		testing.SetRealm(daoRealm)
		positionID, liquidity, _, _ = position.Mint(
			cross,
			barPath,
			fooPath,
			fee,
			-960,
			960,
			"50000000",
			"50000000",
			"0",
			"0",
			9999999999,
			daoAddr,
			"",
		)
	}(cross)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionID)
	ufmt.Printf("[EXPECTED] minted liquidity is non-zero: %t\n", liquidity != "0")
}

func verifyDaoOwnership() {
	owner := position.GetPositionOwner(positionID)

	ufmt.Printf("[EXPECTED] position owner is DAO contract: %t\n", owner == daoAddr)
	ufmt.Printf("[EXPECTED] position owner is origin user: %t\n", owner == originAddr)
}

func generateFees() {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee,
		adminAddr,
		false,
		"10000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	ufmt.Printf("[EXPECTED] swaps executed: %t\n", true)
}

func daoCollectFees() {
	barBefore := bar.BalanceOf(daoAddr)
	fooBefore := foo.BalanceOf(daoAddr)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var fee0 string
	var fee1 string
	func(cur realm) {
		testing.SetRealm(daoRealm)
		_, fee0, fee1, _, _, _ = position.CollectFee(cross, positionID)
	}(cross)

	barAfter := bar.BalanceOf(daoAddr)
	fooAfter := foo.BalanceOf(daoAddr)

	ufmt.Printf("[EXPECTED] collected any fee: %t\n", fee0 != "0" || fee1 != "0")
	ufmt.Printf("[EXPECTED] DAO token balance changed after collect: %t\n", barBefore != barAfter || fooBefore != fooAfter)
}

func daoIncreaseLiquidity() {
	liquidityBefore := position.GetPositionLiquidity(positionID)

	testing.SetRealm(daoRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	func(cur realm) {
		testing.SetRealm(daoRealm)
		position.IncreaseLiquidity(
			cross,
			positionID,
			"10000000",
			"10000000",
			"0",
			"0",
			9999999999,
		)
	}(cross)

	liquidityAfter := position.GetPositionLiquidity(positionID)

	ufmt.Printf("[EXPECTED] liquidity changed after increase: %t\n", liquidityBefore != liquidityAfter)
	ufmt.Printf("[EXPECTED] owner remains DAO after increase: %t\n", position.GetPositionOwner(positionID) == daoAddr)
}

func daoDecreaseAllLiquidity() {
	liquidityBefore := position.GetPositionLiquidity(positionID)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var removedLiquidity string
	func(cur realm) {
		testing.SetRealm(daoRealm)
		_, removedLiquidity, _, _, _, _, _ = position.DecreaseLiquidity(
			cross,
			positionID,
			liquidityBefore,
			"0",
			"0",
			9999999999,
		)
	}(cross)

	liquidityAfter := position.GetPositionLiquidity(positionID)

	ufmt.Printf("[EXPECTED] removed full liquidity: %t\n", removedLiquidity == liquidityBefore)
	ufmt.Printf("[EXPECTED] remaining liquidity is zero: %t\n", liquidityAfter == "0")
	ufmt.Printf("[EXPECTED] owner remains DAO after decrease: %t\n", position.GetPositionOwner(positionID) == daoAddr)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}

	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] 1. Setup pool and fund DAO contract
// [EXPECTED] DAO bar balance after funding: 150000000
// [EXPECTED] DAO foo balance after funding: 150000000
//
// [SCENARIO] 2. DAO contract mints a position
// [EXPECTED] position ID: 1
// [EXPECTED] minted liquidity is non-zero: true
//
// [SCENARIO] 3. Verify DAO contract owns the position
// [EXPECTED] position owner is DAO contract: true
// [EXPECTED] position owner is origin user: false
//
// [SCENARIO] 4. Generate fees through swaps
// [EXPECTED] swaps executed: true
//
// [SCENARIO] 5. DAO contract collects fees
// [EXPECTED] collected any fee: true
// [EXPECTED] DAO token balance changed after collect: true
//
// [SCENARIO] 6. DAO contract increases liquidity
// [EXPECTED] liquidity changed after increase: true
// [EXPECTED] owner remains DAO after increase: true
//
// [SCENARIO] 7. DAO contract decreases all liquidity
// [EXPECTED] removed full liquidity: true
// [EXPECTED] remaining liquidity is zero: true
// [EXPECTED] owner remains DAO after decrease: true
