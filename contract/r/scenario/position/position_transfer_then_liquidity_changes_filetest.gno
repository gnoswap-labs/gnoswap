// position transfer then liquidity ops
// Verifies that after a position NFT changes hands the new owner gains all
// position-management rights (IncreaseLiquidity / DecreaseLiquidity) and the
// previous owner loses them. This validates that the relaxed transfer rule
// in `gnft` correctly carries through to the position contract's
// owner-checks, which key off `gnft.OwnerOf`.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

var (
	t *testing.T

	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)

	token0Path = "gno.land/r/gnoswap/test_token/atom"
	token1Path = "gno.land/r/gnoswap/test_token/btc"
	fee        = uint32(3000)

	maxInt64   int64 = 9223372036854775807
	maxTimeout int64 = 9999999999
	positionId uint64
)

func main() {
	println("[SCENARIO] 1. Setup pool and alice's position")
	setup()
	println()

	println("[SCENARIO] 2. Alice transfers NFT to Bob")
	aliceTransfersToBob()
	println()

	println("[SCENARIO] 3. Alice can no longer increase or decrease liquidity")
	aliceLosesRights()
	println()

	println("[SCENARIO] 4. Bob can increase liquidity on the inherited position")
	bobIncreases()
	println()

	println("[SCENARIO] 5. Bob can decrease liquidity on the inherited position")
	bobDecreases()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	pool.SetPoolCreationFee(cross, 0)

	atom.Transfer(cross, aliceAddr, int64(100000000))
	btc.Transfer(cross, aliceAddr, int64(100000000))
	atom.Transfer(cross, bobAddr, int64(100000000))
	btc.Transfer(cross, bobAddr, int64(100000000))

	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, maxInt64)
	btc.Approve(cross, poolAddr, maxInt64)

	pool.CreatePool(
		cross,
		token0Path, token1Path, fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	id, liquidity, _, _ := position.Mint(
		cross,
		token0Path, token1Path, fee,
		-6960, 6960,
		"10000000", "10000000",
		"1", "1",
		maxTimeout,
		aliceAddr, "")
	positionId = id

	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Initial liquidity:", liquidity)
}

func aliceTransfersToBob() {
	testing.SetRealm(aliceRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, tokenIdOf(positionId))

	owner := gnft.MustOwnerOf(tokenIdOf(positionId))
	println("[EXPECTED] Owner after transfer is bob:", owner == bobAddr)
}

func aliceLosesRights() {
	// Alice retained her token approvals to the pool but no longer owns the
	// position NFT. Both IncreaseLiquidity and DecreaseLiquidity must reject
	// her on the ownership check before any token movement.
	testing.SetRealm(aliceRealm)

	uassert.AbortsContains(
		t,
		"caller has no permission",
		func() {
			position.IncreaseLiquidity(
				cross,
				positionId,
				"1000000", "1000000",
				"0", "0",
				maxTimeout,
			)
		},
	)
	println("[EXPECTED] Alice's IncreaseLiquidity blocked")

	uassert.AbortsContains(
		t,
		"caller has no permission",
		func() {
			position.DecreaseLiquidity(
				cross,
				positionId,
				"1000000",
				"0", "0",
				maxTimeout,
			)
		},
	)
	println("[EXPECTED] Alice's DecreaseLiquidity blocked")
}

func bobIncreases() {
	testing.SetRealm(bobRealm)
	atom.Approve(cross, poolAddr, maxInt64)
	btc.Approve(cross, poolAddr, maxInt64)

	liquidityBefore := position.GetPositionLiquidity(positionId)
	_, liquidityAdded, _, _, _ := position.IncreaseLiquidity(
		cross,
		positionId,
		"5000000", "5000000",
		"0", "0",
		maxTimeout,
	)
	liquidityAfter := position.GetPositionLiquidity(positionId)

	println("[EXPECTED] Liquidity before:", liquidityBefore)
	println("[EXPECTED] Liquidity added:", liquidityAdded)
	println("[EXPECTED] Liquidity after:", liquidityAfter)
}

func bobDecreases() {
	testing.SetRealm(bobRealm)

	liquidityBefore := position.GetPositionLiquidity(positionId)
	_, liquidityRemoved, _, _, _, _, _ := position.DecreaseLiquidity(
		cross,
		positionId,
		"1000000",
		"0", "0",
		maxTimeout,
	)
	liquidityAfter := position.GetPositionLiquidity(positionId)

	println("[EXPECTED] Liquidity before:", liquidityBefore)
	println("[EXPECTED] Liquidity removed:", liquidityRemoved)
	println("[EXPECTED] Liquidity after:", liquidityAfter)
}

func tokenIdOf(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}

// Output:
// [SCENARIO] 1. Setup pool and alice's position
// [EXPECTED] Position ID: 1
// [EXPECTED] Initial liquidity: 34026470
//
// [SCENARIO] 2. Alice transfers NFT to Bob
// [EXPECTED] Owner after transfer is bob: true
//
// [SCENARIO] 3. Alice can no longer increase or decrease liquidity
// [EXPECTED] Alice's IncreaseLiquidity blocked
// [EXPECTED] Alice's DecreaseLiquidity blocked
//
// [SCENARIO] 4. Bob can increase liquidity on the inherited position
// [EXPECTED] Liquidity before: 34026470
// [EXPECTED] Liquidity added: 17013235
// [EXPECTED] Liquidity after: 51039705
//
// [SCENARIO] 5. Bob can decrease liquidity on the inherited position
// [EXPECTED] Liquidity before: 51039705
// [EXPECTED] Liquidity removed: 1000000
// [EXPECTED] Liquidity after: 50039705
