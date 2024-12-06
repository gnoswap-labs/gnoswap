package position

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gnft"

	pl "gno.land/r/gnoswap/v1/pool"
)

// resetObject resets the object state(clear or make it default values)
func resetObject(t *testing.T) {
	positions = make(map[uint64]Position)
	nextId = 1
}

// burnAllNFT burns all NFTs
func burnAllNFT(t *testing.T) {
	t.Helper()

	std.TestSetRealm(std.NewCodeRealm(consts.POSITION_PATH))
	for i := uint64(1); i <= gnft.TotalSupply(); i++ {
		gnft.Burn(tid(i))
	}
}

func TestBeforeResetObject(t *testing.T) {
	// make actual data to test resetting not only position's state but also pool's state
	std.TestSetRealm(adminRealm)

	// set pool create fee to 0 for testing
	pl.SetPoolCreationFeeByAdmin(0)
	pl.CreatePool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	// mint position
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := Mint(
		barPath,
		fooPath,
		fee500,
		-887270,
		887270,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		admin,
	)

	uassert.Equal(t, tokenId, uint64(1), "tokenId should be 1")
	uassert.Equal(t, liquidity, "50000", "liquidity should be 50000")
	uassert.Equal(t, amount0, "50000", "amount0 should be 50000")
	uassert.Equal(t, amount1, "50000", "amount1 should be 50000")
	uassert.Equal(t, len(positions), 1, "positions should have 1 position")
	uassert.Equal(t, nextId, uint64(2), "nextId should be 2")
	uassert.Equal(t, gnft.TotalSupply(), uint64(1), "gnft total supply should be 1")
	uassert.Equal(t, pl.PoolGetLiquidity("gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"), "50000", "pool liquidity should be 50000")
}

func TestResetObject(t *testing.T) {
	resetObject(t)

	uassert.Equal(t, len(positions), 0, "positions should be empty")
	uassert.Equal(t, nextId, uint64(1), "nextId should be 1")
}

func TestBurnAllNFT(t *testing.T) {
	burnAllNFT(t)
	uassert.Equal(t, gnft.TotalSupply(), uint64(0), "gnft total supply should be 0")
}
