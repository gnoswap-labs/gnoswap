// position collect fee

// PKGPATH: gno.land/r/demo/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/gnft"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm   = testing.NewUserRealm(routerAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = testing.NewUserRealm(user1Addr)
	user2Addr  = testutils.TestAddress("user2")
	user2Realm = testing.NewUserRealm(user2Addr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	fee     = uint32(3000)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint same positions")
	testing.SkipHeights(1)
	mintPositions()
	println()

	ufmt.Println("[SCENARIO] 3. Execute swaps for swap fee")
	testing.SkipHeights(1)
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 4. Transfer positions")
	testing.SkipHeights(1)
	transferPositions("user2", user1Addr, user2Addr, 2)
	println()

	ufmt.Println("[SCENARIO] 5. Collect fees for user1 and user2")
	testing.SkipHeights(1)
	CollectFee("user1", user1Addr, "1")
	CollectFee("user2", user2Addr, "2")
	println()

	ufmt.Println("[SCENARIO] 6. Swap positions")
	testing.SkipHeights(1)
	executeSwap()
	println()

	ufmt.Println("[SCENARIO] 7. transfer back positions")
	testing.SkipHeights(1)
	transferPositions("user1", user2Addr, user1Addr, 2)
	println()

	ufmt.Println("[SCENARIO] 8. Collect fees for user1")
	testing.SkipHeights(1)
	CollectFee("user1", user1Addr, "1")
	CollectFee("user1", user1Addr, "2")
	println()

}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(10000000000)

	ufmt.Println("[INFO] Distributing Atom tokens")
	atom.Transfer(cross, user1Addr, defaultTokenAmount)
	atom.Transfer(cross, user2Addr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Btc tokens")
	btc.Transfer(cross, user1Addr, defaultTokenAmount)
	btc.Transfer(cross, user2Addr, defaultTokenAmount)

	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		atomPath,
		btcPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintPositions() {
	testing.SetRealm(user1Realm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position 01 (minTick: -960, maxTick: 960)")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		user1Addr,
		"",
	)

	ufmt.Println("[INFO] Minting position 02 (minTick: -960, maxTick: 960)")
	positionId2, liquidity2, amount20, amount21 := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		user1Addr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
	ufmt.Printf("[EXPECTED] Position 2 ID should be %d\n", positionId2)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity2)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount20)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount21)
}

func transferPositions(name string, from address, to address, id int64) {
	testing.SetRealm(testing.NewUserRealm(from))
	positionID := positionIdFrom(id)
	gnft.Approve(cross, to, positionID)

	ufmt.Printf("[INFO] Transferring position to %s (positionID: %s)\n", name, positionID)
	gnft.SafeTransferFrom(cross, from, to, positionID)
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing swap ATOM -> BTC")
	amount0, amount1 := pool.Swap(
		cross,
		atomPath,
		btcPath,
		fee,
		adminAddr,
		true,
		"5000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[EXPECTED] Swap amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap amount1 should be %s\n", amount1)
}

func CollectFee(userName string, userAddr address, positionID string) {
	testing.SetRealm(testing.NewUserRealm(userAddr))

	beforeAtomBalance := atom.BalanceOf(userAddr)
	beforeBtcBalance := btc.BalanceOf(userAddr)

	positionIDInt, _ := strconv.ParseInt(positionID, 10, 64)
	position.CollectFee(cross, uint64(positionIDInt))

	afterAtomBalance := atom.BalanceOf(userAddr)
	afterBtcBalance := btc.BalanceOf(userAddr)

	ufmt.Printf("[EXPECTED] %s's position %s collect fee ATOM changes: %d\n", userName, positionID, afterAtomBalance-beforeAtomBalance)
	ufmt.Printf("[EXPECTED] %s's position %s collect fee BTC changes: %d\n", userName, positionID, afterBtcBalance-beforeBtcBalance)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}

	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case int64:
		return grc721.TokenID(strconv.FormatInt(positionId.(int64), 10))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Distributing Atom tokens
// [INFO] Distributing Btc tokens
// [INFO] Creating pool
//
// [SCENARIO] 2. Mint same positions
// [INFO] Minting position 01 (minTick: -960, maxTick: 960)
// [INFO] Minting position 02 (minTick: -960, maxTick: 960)
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 1066918731
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
// [EXPECTED] Position 2 ID should be 2
// [EXPECTED] Liquidity should be 1066918731
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Execute swaps for swap fee
// [INFO] Executing swap ATOM -> BTC
// [EXPECTED] Swap amount0 should be 5000000
// [EXPECTED] Swap amount1 should be -4973381
//
// [SCENARIO] 4. Transfer positions
// [INFO] Transferring position to user2 (positionID: 2)
//
// [SCENARIO] 5. Collect fees for user1 and user2
// [EXPECTED] user1's position 1 collect fee ATOM changes: 7425
// [EXPECTED] user1's position 1 collect fee BTC changes: 0
// [EXPECTED] user2's position 2 collect fee ATOM changes: 7425
// [EXPECTED] user2's position 2 collect fee BTC changes: 0
//
// [SCENARIO] 6. Swap positions
// [INFO] Executing swap ATOM -> BTC
// [EXPECTED] Swap amount0 should be 5000000
// [EXPECTED] Swap amount1 should be -4950252
//
// [SCENARIO] 7. transfer back positions
// [INFO] Transferring position to user1 (positionID: 2)
//
// [SCENARIO] 8. Collect fees for user1
// [EXPECTED] user1's position 1 collect fee ATOM changes: 7425
// [EXPECTED] user1's position 1 collect fee BTC changes: 0
// [EXPECTED] user1's position 2 collect fee ATOM changes: 7425
// [EXPECTED] user1's position 2 collect fee BTC changes: 0
