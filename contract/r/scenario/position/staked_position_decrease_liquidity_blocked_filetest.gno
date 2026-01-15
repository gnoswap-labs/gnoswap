// staked position decrease liquidity blocked
// This test verifies that a staked position cannot be burned (decrease liquidity) by the original owner.
// When a position is staked, the NFT ownership is transferred to the staker contract,
// so the original owner should not be able to decrease liquidity.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	t *testing.T

	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	token0Path = "gno.land/r/onbloc/bar"
	token1Path = "gno.land/r/onbloc/foo"
	fee        = uint32(3000)

	maxInt64    int64 = 9223372036854775807
	maxTimeout  int64 = 9999999999
	positionId  uint64
)

func main() {
	println("[SCENARIO] 1. Initialize pool and create position")
	initPoolAndCreatePosition()
	println()

	println("[SCENARIO] 2. Stake position")
	stakePosition()
	println()

	println("[SCENARIO] 3. Verify position is staked (owner is staker contract)")
	verifyPositionIsStaked()
	println()

	println("[SCENARIO] 4. Attempt to decrease liquidity on staked position (should fail)")
	testDecreaseLiquidityOnStakedPosition()
	println()

	println("[SCENARIO] 5. Attempt to collect fee on staked position (should succeed via operator)")
	testCollectFeeOnStakedPosition()
	println()
}

func initPoolAndCreatePosition() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	pool.SetPoolCreationFee(cross, 0)

	defaultTokenAmount := int64(100000000)

	println("[INFO] Distributing Bar tokens to alice")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)

	println("[INFO] Distributing Foo tokens to alice")
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)

	println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	// Setup pool tier for staking
	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	testing.SetRealm(adminRealm)
	staker.SetPoolTier(cross, poolPath, 1)
	println("[INFO] Pool tier set for staking")

	testing.SetRealm(aliceRealm)
	println("[INFO] Minting position for alice")
	id, liquidity, amount0, amount1 := position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-6960,
		6960,
		"10000000",
		"10000000",
		"1",
		"1",
		maxTimeout,
		aliceAddr,
		aliceAddr,
		"",
	)
	positionId = id

	println("[EXPECTED] Position created with ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)

	owner := gnft.MustOwnerOf(positionIdToTokenId(positionId))
	println("[EXPECTED] Position owner before staking:", owner.String())
}

func stakePosition() {
	testing.SetRealm(aliceRealm)

	println("[INFO] Approving GNFT for staker contract")
	gnft.Approve(cross, stakerAddr, positionIdToTokenId(positionId))

	println("[INFO] Staking position")
	staker.StakeToken(cross, positionId, "")

	println("[EXPECTED] Position staked successfully")
}

func verifyPositionIsStaked() {
	owner := gnft.MustOwnerOf(positionIdToTokenId(positionId))

	println("[EXPECTED] Position owner after staking:", owner.String())
	println("[EXPECTED] Staker contract address:", stakerAddr.String())
	println("[EXPECTED] Position is owned by staker contract:", owner == stakerAddr)
}

func testDecreaseLiquidityOnStakedPosition() {
	testing.SetRealm(aliceRealm)

	println("[INFO] Alice attempting to decrease liquidity on staked position")
	println("[INFO] This should fail because alice is no longer the owner (staker contract is)")

	uassert.AbortsContains(
		t,
		"caller has no permission",
		func() {
			position.DecreaseLiquidity(
				cross,
				positionId,
				"1000000",
				"0",
				"0",
				maxTimeout,
				false,
			)
		},
	)

	println("[EXPECTED] DecreaseLiquidity correctly blocked for staked position")
	println("[EXPECTED] Error: caller has no permission (caller is not owner of positionId)")
}

func testCollectFeeOnStakedPosition() {
	testing.SetRealm(aliceRealm)

	println("[INFO] Alice attempting to collect fee on staked position")
	println("[INFO] This should succeed because alice is set as operator when staking")

	_, fee0, fee1, poolPath, _, _ := position.CollectFee(cross, positionId, false)

	println("[EXPECTED] CollectFee succeeded for staked position via operator")
	println("[EXPECTED] Fee0 collected:", fee0)
	println("[EXPECTED] Fee1 collected:", fee1)
	println("[EXPECTED] Pool path:", poolPath)
}

func positionIdToTokenId(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(id)))
}

// Output:
// [SCENARIO] 1. Initialize pool and create position
// [INFO] Distributing Bar tokens to alice
// [INFO] Distributing Foo tokens to alice
// [INFO] Creating pool
// [INFO] Pool tier set for staking
// [INFO] Minting position for alice
// [EXPECTED] Position created with ID: 1
// [EXPECTED] Liquidity: 34026470
// [EXPECTED] Amount0: 10000000
// [EXPECTED] Amount1: 10000000
// [EXPECTED] Position owner before staking: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 2. Stake position
// [INFO] Approving GNFT for staker contract
// [INFO] Staking position
// [EXPECTED] Position staked successfully
//
// [SCENARIO] 3. Verify position is staked (owner is staker contract)
// [EXPECTED] Position owner after staking: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
// [EXPECTED] Staker contract address: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
// [EXPECTED] Position is owned by staker contract: true
//
// [SCENARIO] 4. Attempt to decrease liquidity on staked position (should fail)
// [INFO] Alice attempting to decrease liquidity on staked position
// [INFO] This should fail because alice is no longer the owner (staker contract is)
// [EXPECTED] DecreaseLiquidity correctly blocked for staked position
// [EXPECTED] Error: caller has no permission (caller is not owner of positionId)
//
// [SCENARIO] 5. Attempt to collect fee on staked position (should succeed via operator)
// [INFO] Alice attempting to collect fee on staked position
// [INFO] This should succeed because alice is set as operator when staking
// [EXPECTED] CollectFee succeeded for staked position via operator
// [EXPECTED] Fee0 collected: 0
// [EXPECTED] Fee1 collected: 0
// [EXPECTED] Pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000
