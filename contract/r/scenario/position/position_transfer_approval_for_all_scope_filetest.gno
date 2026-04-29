// position transfer approval-for-all scope
// Verify operator-for-all approval remains scoped to the original owner only.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"

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
	"gno.land/r/gnoswap/gnft"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	aliceAddr   = testutils.TestAddress("alice")
	aliceRealm  = testing.NewUserRealm(aliceAddr)
	bobAddr     = testutils.TestAddress("bob")
	bobRealm    = testing.NewUserRealm(bobAddr)
	charlieAddr = testutils.TestAddress("charlie")
	charlieRealm = testing.NewUserRealm(charlieAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500     uint32 = 500
	maxTimeout int64  = 9999999999
	maxInt64   int64  = 9223372036854775807

	t *testing.T
	position1 uint64
	position2 uint64
)

func main() {
	println("[SCENARIO] 1. Create pool and mint two positions for alice")
	setupAndMintTwoPositions()
	println()

	println("[SCENARIO] 2. Alice approves charlie for all NFTs")
	approveOperatorForAll()
	println()

	println("[SCENARIO] 3. Alice transfers one position to bob")
	transferOnePositionToBob()
	println()

	println("[SCENARIO] 4. Charlie can still manage alice-owned position only")
	verifyOperatorScope()
	println()
}

func setupAndMintTwoPositions() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	bar.Transfer(cross, aliceAddr, 2_000_000)
	foo.Transfer(cross, aliceAddr, 2_000_000)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	position1, _, _, _ = pn.Mint(cross, barPath, fooPath, fee500, -5000, 5000, "100000", "100000", "1", "1", maxTimeout, aliceAddr, aliceAddr, "")
	position2, _, _, _ = pn.Mint(cross, barPath, fooPath, fee500, -3000, 3000, "100000", "100000", "1", "1", maxTimeout, aliceAddr, aliceAddr, "")
	println("[EXPECTED] positions minted for alice:", position1, position2)
}

func approveOperatorForAll() {
	testing.SetRealm(aliceRealm)
	gnft.SetApprovalForAll(cross, charlieAddr, true)
	println("[EXPECTED] approval-for-all set for charlie:", gnft.IsApprovedForAll(aliceAddr, charlieAddr))
}

func transferOnePositionToBob() {
	testing.SetRealm(aliceRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, positionIdToTokenId(position1))
	println("[EXPECTED] owner of transferred position:", pn.GetPositionOwner(position1).String())
	println("[EXPECTED] owner of remaining alice position:", pn.GetPositionOwner(position2).String())
}

func verifyOperatorScope() {
	testing.SetRealm(charlieRealm)
	uassert.AbortsContains(t, "caller is not token owner or approved", func() {
		gnft.TransferFrom(cross, bobAddr, charlieAddr, positionIdToTokenId(position1))
	})
	println("[EXPECTED] charlie cannot transfer bob-owned position")

	gnft.TransferFrom(cross, aliceAddr, charlieAddr, positionIdToTokenId(position2))
	println("[EXPECTED] charlie can still transfer alice-owned position")
	println("[EXPECTED] new owner of alice-owned position:", pn.GetPositionOwner(position2).String())

	_ = bobRealm
	_ = charlieRealm
	_ = bobAddr
}

func positionIdToTokenId(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(id)))
}

// Output:
// [SCENARIO] 1. Create pool and mint two positions for alice
// [EXPECTED] positions minted for alice: 1 2
//
// [SCENARIO] 2. Alice approves charlie for all NFTs
// [EXPECTED] approval-for-all set for charlie: true
//
// [SCENARIO] 3. Alice transfers one position to bob
// [EXPECTED] owner of transferred position: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
// [EXPECTED] owner of remaining alice position: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 4. Charlie can still manage alice-owned position only
// [EXPECTED] charlie cannot transfer bob-owned position
// [EXPECTED] charlie can still transfer alice-owned position
// [EXPECTED] new owner of alice-owned position: g1vd5xzunvd9j47h6lta047h6lta047h6l6a3cm8
