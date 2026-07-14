// position transfer then new owner stakes
// Verifies that once a position NFT changes hands, only the new owner can
// stake it. The original minter must not be able to stake a position they no
// longer own. This protects against a stale-approval attack where the
// previous owner still holds an unrevoked staker approval after transfer.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
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
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)

	token0Path = "gno.land/r/onbloc/bar"
	token1Path = "gno.land/r/onbloc/foo"
	fee        = uint32(3000)

	maxInt64   int64 = 9223372036854775807
	maxTimeout int64 = 9999999999
	positionId uint64
)

func main(cur realm) {
	println("[SCENARIO] 1. Setup pool and alice's position")
	setup(cur)
	println()

	println("[SCENARIO] 2. Alice pre-approves staker, then transfers NFT to bob")
	transferToBob(cur)
	println()

	println("[SCENARIO] 3. Alice cannot stake (no longer owner)")
	aliceCannotStake(cur)
	println()

	println("[SCENARIO] 4. Bob stakes successfully and becomes the depositor")
	bobStakes(cur)
	println()
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	pool.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), aliceAddr, int64(100000000))
	foo.Transfer(cross(cur), aliceAddr, int64(100000000))

	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, maxInt64)
	foo.Approve(cross(cur), poolAddr, maxInt64)

	pool.CreatePool(
		cross(cur),
		token0Path, token1Path, fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	testing.SetRealm(adminRealm)
	staker.SetPoolTier(cross(cur), poolPath, 1)

	testing.SetRealm(aliceRealm)
	id, _, _, _ := position.Mint(
		cross(cur),
		token0Path, token1Path, fee,
		-6960, 6960,
		"10000000", "10000000",
		"1", "1",
		maxTimeout,
		aliceAddr, "")
	positionId = id

	owner := gnft.MustOwnerOf(tokenIdOf(cur, positionId))
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Owner after mint is alice:", owner == aliceAddr)
}

func transferToBob(cur realm) {
	testing.SetRealm(aliceRealm)
	// Pre-approve the staker — this is the stale approval that survives the
	// transfer. The new permission model must not let it be exploited.
	gnft.Approve(cross(cur), stakerAddr, tokenIdOf(cur, positionId))
	println("[INFO] Alice approved staker on positionId")

	gnft.TransferFrom(cross(cur), aliceAddr, bobAddr, tokenIdOf(cur, positionId))
	owner := gnft.MustOwnerOf(tokenIdOf(cur, positionId))
	println("[EXPECTED] Owner after transfer is bob:", owner == bobAddr)
}

func aliceCannotStake(cur realm) {
	testing.SetRealm(aliceRealm)

	// Alice is no longer the NFT owner. StakeToken's ownership check must
	// reject her attempt even though her old approval lingers on-chain.
	uassert.AbortsContains(
		t,
		cur,
		"caller has no permission",
		func() {
			staker.StakeToken(cross(cur), positionId, "")
		},
	)
	println("[EXPECTED] Alice cannot stake a position she no longer owns")
}

func bobStakes(cur realm) {
	testing.SetRealm(bobRealm)
	gnft.Approve(cross(cur), stakerAddr, tokenIdOf(cur, positionId))
	staker.StakeToken(cross(cur), positionId, "")

	owner := gnft.MustOwnerOf(tokenIdOf(cur, positionId))
	println("[EXPECTED] Owner after stake is staker:", owner == stakerAddr)

	depositOwner := staker.GetDepositOwner(positionId)
	println("[EXPECTED] Deposit owner is bob:", depositOwner == bobAddr)
}

func tokenIdOf(cur realm, id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}

// Output:
// [SCENARIO] 1. Setup pool and alice's position
// [EXPECTED] Position ID: 1
// [EXPECTED] Owner after mint is alice: true
//
// [SCENARIO] 2. Alice pre-approves staker, then transfers NFT to bob
// [INFO] Alice approved staker on positionId
// [EXPECTED] Owner after transfer is bob: true
//
// [SCENARIO] 3. Alice cannot stake (no longer owner)
// [EXPECTED] Alice cannot stake a position she no longer owns
//
// [SCENARIO] 4. Bob stakes successfully and becomes the depositor
// [EXPECTED] Owner after stake is staker: true
// [EXPECTED] Deposit owner is bob: true
