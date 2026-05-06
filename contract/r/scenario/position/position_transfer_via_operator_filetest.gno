// position transfer via operator (SetApprovalForAll)
// Verifies the GRC721-standard operator path now works for position NFTs.
// An owner can grant blanket approval via SetApprovalForAll, and the operator
// can transfer any of the owner's positions — provided the position is not
// staked (otherwise the staked-token lock applies and is covered by other
// scenarios).

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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
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
	carolAddr  = testutils.TestAddress("carol")

	token0Path = "gno.land/r/onbloc/bar"
	token1Path = "gno.land/r/onbloc/foo"
	fee        = uint32(3000)

	maxInt64    int64 = 9223372036854775807
	maxTimeout  int64 = 9999999999
	positionId1 uint64
	positionId2 uint64
)

func main() {
	println("[SCENARIO] 1. Alice mints two positions")
	setup()
	println()

	println("[SCENARIO] 2. Alice grants Bob SetApprovalForAll, Bob moves both positions")
	operatorTransfersBoth()
	println()

	println("[SCENARIO] 3. After revoking operator, Bob can no longer transfer")
	revokeOperator()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	pool.SetPoolCreationFee(cross, 0)

	bar.Transfer(cross, aliceAddr, int64(200000000))
	foo.Transfer(cross, aliceAddr, int64(200000000))

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)

	pool.CreatePool(
		cross,
		token0Path, token1Path, fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	id1, _, _, _ := position.Mint(
		cross,
		token0Path, token1Path, fee,
		-6960, 6960,
		"10000000", "10000000",
		"1", "1",
		maxTimeout,
		aliceAddr, "")
	positionId1 = id1

	id2, _, _, _ := position.Mint(
		cross,
		token0Path, token1Path, fee,
		-6960, 6960,
		"10000000", "10000000",
		"1", "1",
		maxTimeout,
		aliceAddr, "")
	positionId2 = id2

	println("[EXPECTED] Position 1:", positionId1)
	println("[EXPECTED] Position 2:", positionId2)
}

func operatorTransfersBoth() {
	testing.SetRealm(aliceRealm)
	gnft.SetApprovalForAll(cross, bobAddr, true)
	println("[INFO] Alice set Bob as operator-for-all")

	// Bob, acting as operator, transfers position 1 to himself and position 2
	// to Carol. Both must succeed under the relaxed transfer rules.
	testing.SetRealm(bobRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, tokenIdOf(positionId1))
	gnft.TransferFrom(cross, aliceAddr, carolAddr, tokenIdOf(positionId2))

	owner1 := gnft.MustOwnerOf(tokenIdOf(positionId1))
	owner2 := gnft.MustOwnerOf(tokenIdOf(positionId2))
	println("[EXPECTED] Position 1 owner is bob:", owner1 == bobAddr)
	println("[EXPECTED] Position 2 owner is carol:", owner2 == carolAddr)
}

func revokeOperator() {
	// Bob mints another position so we have something Alice still owns to
	// test the revoked-operator case. We reuse the existing pool.
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, aliceAddr, int64(50000000))
	foo.Transfer(cross, aliceAddr, int64(50000000))

	testing.SetRealm(aliceRealm)
	id, _, _, _ := position.Mint(
		cross,
		token0Path, token1Path, fee,
		-6960, 6960,
		"10000000", "10000000",
		"1", "1",
		maxTimeout,
		aliceAddr, "")

	gnft.SetApprovalForAll(cross, bobAddr, false)
	println("[INFO] Alice revoked Bob's operator status")

	testing.SetRealm(bobRealm)
	uassert.AbortsContains(
		t,
		"caller is not token owner or approved",
		func() {
			gnft.TransferFrom(cross, aliceAddr, bobAddr, tokenIdOf(id))
		},
	)
	println("[EXPECTED] Revoked operator transfer is rejected by GRC721 layer")
}

func tokenIdOf(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}

// Output:
// [SCENARIO] 1. Alice mints two positions
// [EXPECTED] Position 1: 1
// [EXPECTED] Position 2: 2
//
// [SCENARIO] 2. Alice grants Bob SetApprovalForAll, Bob moves both positions
// [INFO] Alice set Bob as operator-for-all
// [EXPECTED] Position 1 owner is bob: true
// [EXPECTED] Position 2 owner is carol: true
//
// [SCENARIO] 3. After revoking operator, Bob can no longer transfer
// [INFO] Alice revoked Bob's operator status
// [EXPECTED] Revoked operator transfer is rejected by GRC721 layer
