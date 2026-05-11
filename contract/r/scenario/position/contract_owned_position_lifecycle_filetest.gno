// contract-owned position lifecycle

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
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
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"

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
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())

	originAddr  = testutils.TestAddress("vault-origin")
	originRealm = testing.NewUserRealm(originAddr)

	vaultPath  = "gno.land/r/onbloc/liquidity_vault"
	vaultRealm = testing.NewCodeRealm(vaultPath)
	vaultAddr  = vaultRealm.Address()

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(3000)

	positionID uint64
)

func main() {
	ufmt.Println("[SCENARIO] 1. Setup pool and fund vault contract")
	setupPoolAndFundVault()
	println()

	ufmt.Println("[SCENARIO] 2. Vault contract mints a position")
	vaultMintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Verify vault contract owns the position")
	verifyVaultOwnership()
	println()

	ufmt.Println("[SCENARIO] 4. Generate fees through swaps")
	generateFees()
	println()

	ufmt.Println("[SCENARIO] 5. Vault contract collects fees")
	vaultCollectFees()
	println()

	ufmt.Println("[SCENARIO] 6. Vault contract increases liquidity")
	vaultIncreaseLiquidity()
	println()

	ufmt.Println("[SCENARIO] 7. Vault contract decreases all liquidity")
	vaultDecreaseAllLiquidity()
	println()

	ufmt.Println("[SCENARIO] 8. Vault contract repositions the cleared position")
	vaultReposition()
	println()

	ufmt.Println("[SCENARIO] 9. Vault contract stakes the position")
	vaultStakePosition()
	println()

	ufmt.Println("[SCENARIO] 10. Vault contract collects fees while staked")
	vaultCollectFeesWhileStaked()
	println()

	ufmt.Println("[SCENARIO] 11. Vault contract collects staking rewards")
	vaultCollectStakingReward()
	println()

	ufmt.Println("[SCENARIO] 12. Vault contract unstakes the position")
	vaultUnstakePosition()
	println()
}

func setupPoolAndFundVault() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee)

	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	staker.SetPoolTier(cross, poolPath, 1)

	bar.Transfer(cross, vaultAddr, 150000000)
	foo.Transfer(cross, vaultAddr, 150000000)

	ufmt.Printf("[EXPECTED] pool path: %s\n", poolPath)
	ufmt.Printf("[EXPECTED] pool tier after setup: %d\n", staker.GetPoolTier(poolPath))
	ufmt.Printf("[EXPECTED] vault bar balance after funding: %d\n", bar.BalanceOf(vaultAddr))
	ufmt.Printf("[EXPECTED] vault foo balance after funding: %d\n", foo.BalanceOf(vaultAddr))
}

func vaultMintPosition() {
	testing.SetRealm(vaultRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var liquidity string
	func(cur realm) {
		testing.SetRealm(vaultRealm)
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
			vaultAddr,
			"",
		)
	}(cross)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionID)
	ufmt.Printf("[EXPECTED] minted liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] vault bar balance after mint: %d\n", bar.BalanceOf(vaultAddr))
	ufmt.Printf("[EXPECTED] vault foo balance after mint: %d\n", foo.BalanceOf(vaultAddr))
}

func verifyVaultOwnership() {
	owner := position.GetPositionOwner(positionID)

	ufmt.Printf("[EXPECTED] position owner: %s\n", owner.String())
	ufmt.Printf("[EXPECTED] vault contract address: %s\n", vaultAddr.String())
	ufmt.Printf("[EXPECTED] origin user address: %s\n", originAddr.String())
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

	poolPath := pool.GetPoolPath(barPath, fooPath, fee)
	ufmt.Printf("[EXPECTED] pool tick after swaps: %d\n", pool.GetSlot0Tick(poolPath))
	ufmt.Printf("[EXPECTED] pool token0 balance after swaps: %d\n", pool.GetBalanceToken0(poolPath))
	ufmt.Printf("[EXPECTED] pool token1 balance after swaps: %d\n", pool.GetBalanceToken1(poolPath))
}

func vaultCollectFees() {
	barBefore := bar.BalanceOf(vaultAddr)
	fooBefore := foo.BalanceOf(vaultAddr)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var fee0 string
	var fee1 string
	func(cur realm) {
		testing.SetRealm(vaultRealm)
		_, fee0, fee1, _, _, _ = position.CollectFee(cross, positionID)
	}(cross)

	barAfter := bar.BalanceOf(vaultAddr)
	fooAfter := foo.BalanceOf(vaultAddr)

	ufmt.Printf("[EXPECTED] collected fee0: %s\n", fee0)
	ufmt.Printf("[EXPECTED] collected fee1: %s\n", fee1)
	ufmt.Printf("[EXPECTED] vault bar balance before collect: %d\n", barBefore)
	ufmt.Printf("[EXPECTED] vault bar balance after collect: %d\n", barAfter)
	ufmt.Printf("[EXPECTED] vault foo balance before collect: %d\n", fooBefore)
	ufmt.Printf("[EXPECTED] vault foo balance after collect: %d\n", fooAfter)
}

func vaultIncreaseLiquidity() {
	liquidityBefore := position.GetPositionLiquidity(positionID)

	testing.SetRealm(vaultRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	func(cur realm) {
		testing.SetRealm(vaultRealm)
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

	ufmt.Printf("[EXPECTED] liquidity before increase: %s\n", liquidityBefore)
	ufmt.Printf("[EXPECTED] liquidity after increase: %s\n", liquidityAfter)
	ufmt.Printf("[EXPECTED] owner after increase: %s\n", position.GetPositionOwner(positionID).String())
}

func vaultDecreaseAllLiquidity() {
	liquidityBefore := position.GetPositionLiquidity(positionID)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var removedLiquidity string
	func(cur realm) {
		testing.SetRealm(vaultRealm)
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

	ufmt.Printf("[EXPECTED] liquidity before decrease: %s\n", liquidityBefore)
	ufmt.Printf("[EXPECTED] removed liquidity: %s\n", removedLiquidity)
	ufmt.Printf("[EXPECTED] liquidity after decrease: %s\n", liquidityAfter)
	ufmt.Printf("[EXPECTED] owner after decrease: %s\n", position.GetPositionOwner(positionID).String())
}

func vaultReposition() {
	testing.SetRealm(vaultRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var liquidity string
	var tickLower int32
	var tickUpper int32
	func(cur realm) {
		testing.SetRealm(vaultRealm)
		_, liquidity, tickLower, tickUpper, _, _ = position.Reposition(
			cross,
			positionID,
			-600,
			600,
			"30000000",
			"30000000",
			"0",
			"0",
			9999999999,
		)
	}(cross)

	ufmt.Printf("[EXPECTED] repositioned liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] repositioned tick range: [%d, %d]\n", tickLower, tickUpper)
	ufmt.Printf("[EXPECTED] owner after reposition: %s\n", position.GetPositionOwner(positionID).String())
}

func vaultStakePosition() {
	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var poolPath string
	func(cur realm) {
		testing.SetRealm(vaultRealm)
		gnft.Approve(cross, stakerAddr, positionIdToTokenId(positionID))
		poolPath = staker.StakeToken(cross, positionID, "")
	}(cross)

	owner := gnft.MustOwnerOf(positionIdToTokenId(positionID))

	ufmt.Printf("[EXPECTED] staked pool path: %s\n", poolPath)
	ufmt.Printf("[EXPECTED] position owner after stake: %s\n", owner.String())
	ufmt.Printf("[EXPECTED] staker contract address: %s\n", stakerAddr.String())
	ufmt.Printf("[EXPECTED] deposit owner after stake: %s\n", staker.GetDepositOwner(positionID).String())
}

func vaultCollectFeesWhileStaked() {
	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var poolPath string
	func(cur realm) {
		testing.SetRealm(vaultRealm)
		_, _, _, poolPath, _, _ = position.CollectFee(cross, positionID)
	}(cross)

	ufmt.Printf("[EXPECTED] staked collect fee pool path: %s\n", poolPath)
}

func vaultCollectStakingReward() {
	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var rewardToUser string
	var gnsReward string
	var externalRewards map[string]int64
	var externalPenalties map[string]int64
	func(cur realm) {
		testing.SetRealm(vaultRealm)
		rewardToUser, gnsReward, externalRewards, externalPenalties = staker.CollectReward(cross, positionID)
	}(cross)

	ufmt.Printf("[EXPECTED] staking reward to user: %s\n", rewardToUser)
	ufmt.Printf("[EXPECTED] staking reward penalty: %s\n", gnsReward)
	ufmt.Printf("[EXPECTED] staking external reward entries: %d\n", len(externalRewards))
	ufmt.Printf("[EXPECTED] staking external penalty entries: %d\n", len(externalPenalties))
}

func vaultUnstakePosition() {
	testing.SetRealm(originRealm)
	testing.SetOriginCaller(originAddr)

	var poolPath string
	func(cur realm) {
		testing.SetRealm(vaultRealm)
		poolPath = staker.UnStakeToken(cross, positionID)
	}(cross)

	owner := gnft.MustOwnerOf(positionIdToTokenId(positionID))

	ufmt.Printf("[EXPECTED] unstaked pool path: %s\n", poolPath)
	ufmt.Printf("[EXPECTED] position owner after unstake: %s\n", owner.String())
}

func positionIdToTokenId(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(id)))
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
// [SCENARIO] 1. Setup pool and fund vault contract
// [EXPECTED] pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [EXPECTED] pool tier after setup: 1
// [EXPECTED] vault bar balance after funding: 150000000
// [EXPECTED] vault foo balance after funding: 150000000
//
// [SCENARIO] 2. Vault contract mints a position
// [EXPECTED] position ID: 1
// [EXPECTED] minted liquidity: 1066918731
// [EXPECTED] vault bar balance after mint: 100000000
// [EXPECTED] vault foo balance after mint: 100000000
//
// [SCENARIO] 3. Verify vault contract owns the position
// [EXPECTED] position owner: g10s2vtg08cmqe4rdu37zm2ar4lmqh2q9w9j2a2v
// [EXPECTED] vault contract address: g10s2vtg08cmqe4rdu37zm2ar4lmqh2q9w9j2a2v
// [EXPECTED] origin user address: g1wesh2mr594hhy6t8d9h97h6lta047h6l0sax53
//
// [SCENARIO] 4. Generate fees through swaps
// [EXPECTED] pool tick after swaps: 1
// [EXPECTED] pool token0 balance after swaps: 49937706
// [EXPECTED] pool token1 balance after swaps: 50122304
//
// [SCENARIO] 5. Vault contract collects fees
// [EXPECTED] collected fee0: 29700
// [EXPECTED] collected fee1: 29700
// [EXPECTED] vault bar balance before collect: 100000000
// [EXPECTED] vault bar balance after collect: 100029700
// [EXPECTED] vault foo balance before collect: 100000000
// [EXPECTED] vault foo balance after collect: 100029700
//
// [SCENARIO] 6. Vault contract increases liquidity
// [EXPECTED] liquidity before increase: 1066918731
// [EXPECTED] liquidity after increase: 1279909285
// [EXPECTED] owner after increase: g10s2vtg08cmqe4rdu37zm2ar4lmqh2q9w9j2a2v
//
// [SCENARIO] 7. Vault contract decreases all liquidity
// [EXPECTED] liquidity before decrease: 1279909285
// [EXPECTED] removed liquidity: 1279909285
// [EXPECTED] liquidity after decrease: 0
// [EXPECTED] owner after decrease: g10s2vtg08cmqe4rdu37zm2ar4lmqh2q9w9j2a2v
//
// [SCENARIO] 8. Vault contract repositions the cleared position
// [EXPECTED] repositioned liquidity: 1012161996
// [EXPECTED] repositioned tick range: [-600, 600]
// [EXPECTED] owner after reposition: g10s2vtg08cmqe4rdu37zm2ar4lmqh2q9w9j2a2v
//
// [SCENARIO] 9. Vault contract stakes the position
// [EXPECTED] staked pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [EXPECTED] position owner after stake: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
// [EXPECTED] staker contract address: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
// [EXPECTED] deposit owner after stake: g10s2vtg08cmqe4rdu37zm2ar4lmqh2q9w9j2a2v
//
// [SCENARIO] 10. Vault contract collects fees while staked
// [EXPECTED] staked collect fee pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
//
// [SCENARIO] 11. Vault contract collects staking rewards
// [EXPECTED] staking reward to user: 0
// [EXPECTED] staking reward penalty: 0
// [EXPECTED] staking external reward entries: 0
// [EXPECTED] staking external penalty entries: 0
//
// [SCENARIO] 12. Vault contract unstakes the position
// [EXPECTED] unstaked pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
// [EXPECTED] position owner after unstake: g10s2vtg08cmqe4rdu37zm2ar4lmqh2q9w9j2a2v
